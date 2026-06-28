# Game Center cloud save (iCloud SavedGame) — design

Date: 2026-06-27
Branch: `gc-cloud-save` (proposed)
Status: pending user review of spec
Depends on: `game-center-service` spec (shared `core/game_center.gd`)

## Goal

Sync the player's save across their devices via Game Center's iCloud-backed
`SavedGame`, so reinstalling or switching iPads restores progress. When two devices
have genuinely diverged, **prompt the player** to choose which save to keep.

This is the highest-risk of the Game Center features: it touches the authoritative
`user://save.json`. The guiding rule is **never silently lose or demote progress** —
the local atomic save stays the source of truth on-device; cloud sync layers on top
and only ever overwrites local after an unambiguous adopt or an explicit player pick.

## Non-goals

- **No real-time / continuous sync.** Pull on boot, push on save/background. Not a
  live multiplayer-style state channel.
- **No partial / field-level merge.** A save is adopted whole; we never splice two
  saves together (that risks incoherent state). The player picks one *or* the
  newer-only case is adopted whole.
- **No server.** This is device↔iCloud↔device via GameKit; no backend.
- **No change to the local save format or the existing atomic write path.** Cloud
  save serializes the *same* blob.

## Background: the existing save

`core/save.gd` holds `data: Dictionary`, serialized with `JSON.stringify` and written
atomically (temp → verify re-parse → rename, keeping a `.bak`). `SCHEMA_VERSION = 3`;
a save whose `schema_version` mismatches is **discarded and recreated** (no
migration). `reset()` rebuilds `_default()`.

Cloud save reuses this: serialize `Save.data` to bytes for the cloud blob; on adopt,
parse bytes → `Save._merge(_default(), parsed)` → assign `Save.data` → `save_now()`,
applying the *same* schema-mismatch discard rule (a cloud save from a newer/older
schema than this build is ignored, never adopted).

## New save metadata (needed to compare saves)

To compare two saves and to render a human-readable conflict prompt, add to the save
default (right-pad on read for old saves):

- `stats.last_played` (unix seconds) — updated on each `save_now`.
- `stats.save_rev` (monotonic int) — incremented on each local mutation-save; lets us
  detect "same lineage, one is strictly ahead" vs "diverged."
- `stats.lifetime_merges` — already added by the leaderboards spec; reused as a
  progression summary in the prompt. (If leaderboards ships first, this exists; the
  cloud-save spec depends on the same `stats` blob.)

Progression level for the summary comes from `level_for_exp(Save.exp_total())`.

## Architecture

New module **`engine/scripts/core/cloud_save.gd`** — `RefCounted` static, over the
shared service (`ClassDB` access, gated on `GameCenter.available()` and
`authenticated()`; full no-op off iOS).

API:

- `pull(on_done: Callable)` — fetch the named SavedGame(s); decide and apply per the
  resolution model below; report the outcome.
- `push()` — serialize `Save.data` and write the named SavedGame (`save`).
  Fire-and-forget; errors logged.
- `_summarize(bytes) -> Dictionary` — parse a save blob to a summary
  `{level, lifetime_merges, last_played, save_rev, schema_ok}` for comparison and the
  prompt.

### Sync points

- **Boot:** after auth resolves (chained off `GameCenter.authenticate`), call
  `pull`. This is the restore-on-new-device path.
- **Save / background:** `push` on `save_now` (throttled) and on
  `NOTIFICATION_APPLICATION_PAUSED` / focus-out, so the latest local state reaches
  iCloud.

### Resolution model (pull)

Let L = local summary, C = cloud summary (the fetched SavedGame; on a GKSavedGame
*conflict* GameKit returns several with the same name — treat the set as "diverged").

1. **No cloud save** → `push()` local. (First device.)
2. **Cloud save, schema mismatch** → ignore cloud (do not adopt); optionally `push()`
   local if local schema is current. Never adopt an incompatible blob.
3. **Local is fresh** (no progression: `exp_total == 0` and `lifetime_merges == 0`)
   **and cloud has progress** → **adopt cloud** silently. (New-device restore — the
   common, safe case; a fresh default never wins over real progress.)
4. **Same lineage, one strictly ahead** (`save_rev` comparable, no divergence) →
   adopt the higher `save_rev`, no prompt.
5. **Diverged** (both have progress and neither is a clean ancestor — including a true
   GKSavedGame conflict set) → **prompt the player** (below), then adopt the chosen
   save and, for a GameKit conflict, call `resolveConflictingSavedGames` with the
   winner so the cloud converges.

This keeps the prompt for the genuinely ambiguous case only; routine restores and
"this device is just behind" resolve automatically without ever demoting progress.

### Conflict prompt (the one custom UI)

A modal built from the shared MAIL KIT frame (same family as Settings/mail), showing
two cards — **This device** vs **iCloud** — each with: level, lifetime merges, and
last-played (relative time). Two buttons: "Keep this device" / "Keep iCloud". The pick
adopts that save (and resolves the GameKit conflict to it). No silent default; the
dialog must be answered. (A visual mockup is worth producing during this spec's
implementation — flag for the visual companion then.)

## Error handling

Every native call guarded by `available()` / `authenticated()`. Fetch/write failures
are logged and leave the local save untouched (degrade to local-only, exactly as
today). A parse failure on a cloud blob is treated as "no usable cloud save" (case 1),
never as data to adopt. The local atomic write + `.bak` remain the on-device safety
net independent of cloud state.

## Testing

This feature gets the heaviest coverage. Headless, with a **faked SavedGame
provider** (an in-memory store injected like `Save.configure_for_test`, recording
written blobs and returning scripted fetch results):

- Off iOS / unauthenticated: `pull` / `push` are no-ops; the game runs local-only.
- Case 1 (no cloud): `pull` pushes local up.
- Case 2 (schema mismatch): cloud is never adopted; local survives.
- Case 3 (fresh local + cloud progress): cloud is adopted, no prompt; `Save.data`
  reflects the cloud blob.
- Case 4 (same lineage, cloud ahead): adopt cloud; (local ahead): keep local.
- Case 5 (diverged): the resolver requests a prompt and does **not** mutate the save
  until a choice is supplied; supplying each choice adopts the right blob and (for a
  conflict set) records the resolve call.
- Round-trip: `push` then `pull` on a second faked device adopts identical `Save.data`.
- Schema-discard parity: a cloud blob with a wrong `schema_version` is ignored, same
  as the local read path.

Run `make test-fast` during the loop, `make test` before handoff. Given the risk,
also do a real two-device (or two sandbox-account) manual pass before shipping.

## External work (owner)

- App Store Connect / entitlements: Game Center capability already enabled; iCloud
  SavedGame rides on Game Center auth (confirm no extra entitlement is required for
  the GodotApplePlugins `SavedGame` path during implementation).
- A real-device sandbox test of the new-device restore and the diverged-conflict
  prompt.

## Sequencing

Do this **last** of the three features. It depends on the shared service and reuses
the `stats` blob introduced by leaderboards; its risk profile warrants landing the
low-risk reporting features first.
