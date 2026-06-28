# Game Center leaderboards — design

Date: 2026-06-27
Branch: `gc-leaderboards` (proposed)
Status: pending user review of spec
Depends on: `game-center-service` spec (shared `core/game_center.gd`); the
`settings-gc-id-and-reset` spec for the kit `action` row kind reused by the entry
point (or that row kind is introduced here if leaderboards ships first).

## Goal

Two Game Center leaderboards, plus a button that opens Apple's native Game Center
overlay to view them:

1. **Progression level** — the player's current level.
2. **Lifetime merges** — cumulative merges across all play.

Score submission is fire-and-forget, like achievements. Display is Apple's native UI;
no custom ranking screen.

## Non-goals

- **No custom leaderboard UI.** `GKGameCenterViewController` renders the standings;
  we only provide an entry point that opens it.
- **No competitive framing in-game** (no rival callouts, no score popups). This stays
  a cozy game; the boards are an opt-in vanity surface behind a button.
- **No server.** Scores are client-submitted; Game Center owns ranking.

## Architecture

New module **`engine/scripts/core/leaderboards.gd`** — a `RefCounted` static library
over the shared service.

API:

- `submit(board_id: String, value: int)` — submits via the manager's `submitScore`.
  No-op unless `GameCenter.authenticated()`. Errors logged, never propagated.
- `show()` — opens the native `GKGameCenterViewController` (via the manager's
  `show_leaderboard` / dashboard call). No-op off iOS.
- Internal: constants for the two **ASC leaderboard ids** (must match App Store
  Connect).

### Board 1 — progression level

The number already exists: `level_for_exp(Save.exp_total())`
(`content.gd:1015` / `:1078`). Submit it in `content.gd::earn_exp`, right after the
level advances (the function already computes the new level). Idempotent re-submits
are fine; throttle to "only when the level actually increased."

### Board 2 — lifetime merges (needs a new counter)

There is **no lifetime merge counter today** — only a *daily* `merges` field in the
daily bundle (`save.gd:287`). This spec adds a monotonic counter:

- New save field **`stats.lifetime_merges`** (a new top-level `stats` blob in the save
  default, so future lifetime stats have a home). Missing in old saves → defaults to
  `0` on read (right-pad pattern already used by `save.gd`).
- A single accessor pair on `save.gd`: `lifetime_merges()` and
  `bump_lifetime_merges(n := 1)` (writes through `save_now`, batched if needed).
- Bumped **once** at the board merge chokepoint (`board.gd` /
  `board_model.merge()`), the same single place daily `merges` is counted, so it can
  never double-count.
- Submitted to the board on increment, **throttled** (e.g. submit at most every N
  merges or on scene exit) to avoid a native call per merge.

`stats.lifetime_merges` is whatever the spec adds; if other lifetime stats are wanted
later (coins earned, etc.) they join the same blob.

## Entry point

For v1, a row in the **Settings dialog** (next to the debug GC id row) — reusing the
`action` row kind introduced in the `settings-gc-id-and-reset` spec — labelled e.g.
"Game Center" that calls `Leaderboards.show()`. Unlike the id/reset rows, this entry
is **not** debug-gated: viewing leaderboards is a legitimate player action on iOS.
It is shown only when `GameCenter.available()` (so it never appears off iOS).

(If a more prominent placement is wanted later — a map button — that is an additive
follow-up. Settings is the cheapest correct home for v1.)

## Data flow

- Level: read-through from `Save.exp_total()`; no new persistence.
- Lifetime merges: new `stats.lifetime_merges` in the save, incremented at the merge
  chokepoint, read for submission.

## Error handling

All native calls guarded by `available()` / `authenticated()`; off iOS the submit and
show functions are no-ops and the Settings entry is hidden. Score submission failure
is logged, never surfaced.

## Testing

Headless, faked manager stub recording submitted (board_id, value) and `show()`:

- `submit` / `show` are no-ops when unauthenticated (no crash off iOS).
- `save.lifetime_merges()` defaults to 0 on a fresh / old save and increments via
  `bump_lifetime_merges`.
- Driving a merge through the model bumps `lifetime_merges` exactly once.
- `earn_exp` past a level boundary triggers a level submit with the new level;
  no submit when the level is unchanged.
- The Settings entry is present only when `GameCenter.available()` (stub it true in
  the test) and calls `Leaderboards.show()`.

Run `make test-fast` during the loop, `make test` before handoff.

## External work (owner, in App Store Connect)

Create two leaderboards: progression level and lifetime merges (id, format = integer,
sort = high-to-low, localized titles). The code's two id constants must match.
