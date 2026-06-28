# Game Center service — shared manager owner — design

Date: 2026-06-27
Branch: `game-center-service` (proposed)
Status: pending user review of spec

## Goal

Extract a single owner of the authenticated `GameCenterManager` so that
**leaderboards, achievements, and saved-games** all reuse one signed-in session,
instead of each feature newing its own native manager. This is the foundation the
three Game Center feature specs build on.

Today `core/identity.gd` instantiates its *own* `GameCenterManager` (`_gc`) purely to
get the player id. The new service hoists that ownership up one level; `identity.gd`
becomes a consumer.

## Non-goals

- **No new player-facing behavior.** This is an internal refactor. Sign-in still
  happens exactly when it does now (`Identity.boot` at home open), and the game
  behaves identically off iOS.
- **No leaderboard / achievement / saved-game logic here** — those land in their own
  specs. This spec only ships the shared manager + auth state.
- **No change to the `game_center` feature flag** or the `available()` gating rule.

## Architecture

New module **`engine/scripts/core/game_center.gd`** — a `RefCounted` static service
mirroring the `identity.gd` / `store.gd` idiom (reach native classes via `ClassDB`,
never a direct symbol; gate every native touch on `available()`).

API:

- `available() -> bool` — `ClassDB.class_exists("GameCenterManager") and
  OS.has_feature("ios")`. The single gate; identical to today's `Identity.available`.
- `manager() -> Object` — lazily instantiates and caches the one `GameCenterManager`
  (the current `_gc`), or `null` off iOS. Kept as a `static var` so its signal
  connections survive.
- `authenticate(on_done: Callable = Callable())` — connects
  `authentication_result` / `authentication_error` and calls `authenticate` on the
  manager once. Idempotent: a second call while authenticated (or in flight) is a
  no-op. Invokes `on_done` (if valid) when auth resolves.
- `authenticated() -> bool` — reads `manager().local_player.is_authenticated`,
  guarded; `false` off iOS or before sign-in.
- `local_player() -> Object` — the `GKLocalPlayer`, or `null`.

The service owns the manager lifecycle; feature modules (`identity`, `achievements`,
`leaderboards`, `cloud_save`) call `GameCenter.manager()` / `authenticated()` and
issue their own native calls against it.

### `identity.gd` refactor

`identity.gd` keeps its public surface (`available`, `player_id`, `verification`,
`boot`) unchanged so existing callers (`map.gd`, `inbox_sync.gd`, tests) are
untouched. Internally:

- `available()` delegates to `GameCenter.available()`.
- `boot(host)` delegates to `GameCenter.authenticate(_on_auth)` instead of newing its
  own manager. The early-out (already has an id) stays.
- `_on_auth` reads `GameCenter.local_player()` for `game_player_id` and the
  verification signature, caching to the save exactly as today.

## Data flow

Unchanged from today: on auth, the player id and verification payload are cached into
`Save.grove()` (`gc_player_id`, `gc_verify`). The service adds no new persistence.

## Error handling

`authentication_error` is logged via `push_warning` (as today) and leaves
`authenticated()` false; consumers degrade to their off-iOS path. No native call is
made unless `available()`.

## Testing

Extend `engine/tests/identity_tests.gd` (and add `game_center_tests.gd` if it grows):

- Off iOS / headless: `GameCenter.available()` is false, `manager()` returns null,
  `authenticate()` is a safe no-op, `authenticated()` is false.
- `identity.gd` still degrades correctly: `player_id()` falls back to the cached save
  value; `boot()` is a no-op without the plugin.
- The existing identity tests continue to pass unchanged (the public surface is
  stable) — this is the primary regression guard for the refactor.

Run `make test-fast` during the loop, `make test` before handoff.

## Sequencing

Ship this **first**; achievements, leaderboards, and cloud save each depend on
`GameCenter.manager()` / `authenticated()`.
