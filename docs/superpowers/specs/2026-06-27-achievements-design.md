# Game Center achievements — design

Date: 2026-06-27
Branch: `gc-achievements` (proposed)
Status: pending user review of spec
Depends on: `game-center-service` spec (shared `core/game_center.gd`)

## Goal

A small, curated set (~8–12) of Game Center achievements that unlock on existing
progression beats. Fire-and-forget reporting: unlocking is a side effect of events
the game already emits; a failed report never blocks or alters gameplay.

## Non-goals

- **No custom achievement UI.** Apple shows its own unlock banner, and the native
  Game Center overlay (specced in `leaderboards`) lists earned/locked achievements.
  No in-game achievement screen this pass.
- **No retroactive grant of past play.** Achievements unlock going forward from the
  build that ships them. (A one-time backfill on first launch is a possible later
  addition, parked.)
- **No server involvement.** Unlike the mail player-id, achievements need no
  signature verification.

## Architecture

New module **`engine/scripts/core/achievements.gd`** — a `RefCounted` static library
over the shared service.

API:

- `unlock(id: String)` — reports the achievement at 100% via the manager's
  `reportAchievements` (`GKAchievement`). No-op unless `GameCenter.authenticated()`.
  Idempotent: re-reporting an already-earned achievement is harmless (Game Center
  dedupes), and a local "already reported this session" guard avoids redundant native
  calls.
- `progress(id: String, pct: float)` — for the count-based ones (e.g. residents
  collected), reports partial completion so the player sees progress in the native UI.
- Internal: a constant table mapping a stable local key → the **ASC achievement id**
  string. The ids must match what is created in App Store Connect.

Reporting is centralized in `achievements.gd`; callers emit semantic events.

### Where unlocks are wired (hook points, all already in the codebase)

- **Level milestones** — `content.gd::earn_exp` already computes before/after level.
  After it advances, check thresholds (reach level 5 / 15 / 30) and `unlock`.
- **Tier milestone** — at the board merge chokepoint (`board.gd` /
  `board_model.merge()`): first merge to `MAX_TIER`.
- **Map progress** — where a map is restored / finished
  (`content.gd::map_spots_restored` / map-finish path): first map restored, all maps
  restored.
- **Residents** — at resident collection: first resident; collect N residents
  (count-based → `progress`).
- **Streak** — the daily login streak (already tracked in the daily bundle): play 7
  days.

The exact chokepoints are confirmed during implementation; each hook is a single
`Achievements.unlock(...)` call guarded by nothing more than the module's own
`authenticated()` check.

## Proposed achievement slate (finalize in implementation)

| Key | Trigger | Type |
|---|---|---|
| `first_max_tier` | first merge to MAX_TIER | one-shot |
| `first_resident` | first resident collected | one-shot |
| `residents_10` | 10 residents collected | progress |
| `first_map_restored` | first map fully restored | one-shot |
| `all_maps_restored` | every map restored | one-shot |
| `level_5` | reach level 5 | one-shot |
| `level_15` | reach level 15 | one-shot |
| `level_30` | reach level 30 | one-shot |
| `streak_7` | 7-day login streak | one-shot |

(~9 to start; trim/extend during the spec's implementation. Owner may swap any.)

## Data flow

No new save state required for the one-shots (Game Center is the source of truth for
earned state; the session guard is in-memory). Count-based progress reads existing
counters (resident count). If a needed count is not already persisted, it is added in
the relevant feature's save blob — called out per-hook in implementation.

## Error handling

Every native call is wrapped: no-op off iOS / unauthenticated, `push_warning` on
report error, never propagated to gameplay. Order of operations always does the game
state change first, then the (optional) achievement report.

## Testing

Headless, with a faked manager (the service returns a stub recording reported ids):

- `Achievements.unlock(id)` is a no-op when unauthenticated (no crash off iOS).
- Each hook calls `unlock` with the right id when its event fires (drive the event
  through the existing model APIs — e.g. `earn_exp` past a level threshold — and
  assert the stub recorded the id).
- The session guard suppresses a duplicate `unlock` in the same run.

Run `make test-fast` during the loop, `make test` before handoff.

## External work (owner, in App Store Connect)

Create each achievement id above in App Store Connect (id, title, description,
point value, hidden/shown). The code's id table must match these strings.
