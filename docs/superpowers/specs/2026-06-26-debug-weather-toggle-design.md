# Debug Weather Toggle Design

Date: 2026-06-26
Worktree: `/Users/xup/dh/merge`
Status: approved

## Goal

In debug mode, let the owner cycle the ambient weather effect on demand so map
and board weather can be inspected without waiting for the hourly deterministic
roll.

## Non-goals

- No production-facing settings.
- No player save-data persistence.
- No new weather effects beyond the existing `clear`, `breeze`, `rain`, and
  `snow` states.
- No changes to calm-mode behavior outside the explicit debug override.

## Approach

Use the existing `Ambient.forced_weather` hook as the single source of truth for
debug overrides. Add a debug-overlay action that cycles:

`auto -> clear -> breeze -> rain -> snow -> auto`

`auto` is represented by an empty forced-weather string, preserving the existing
hourly roll and win-back rain behavior. Non-auto states override calm mode, which
matches the current shot-tool behavior.

## Components

### `engine/scripts/ui/ambient.gd`

Own the weather override cycle. Add small pure helpers so tests can verify the
sequence without building scenes:

- `weather_debug_label() -> String`
- `debug_cycle_weather() -> String`
- `reset_weather_debug_for_test() -> void`

### `engine/scripts/ui/debug.gd`

Add one debug action, `Weather: <state>`, visible only when the existing debug
panel is visible. Pressing it cycles the override and asks the current host to
refresh its visible weather layer when supported.

### `engine/scripts/scenes/map.gd` and `engine/scripts/scenes/board.gd`

Expose `debug_refresh_weather() -> void`. Each host removes its current
`WeatherLayer` and adds a freshly built one using `Ambient.weather_now(FX.calm())`.
The map stores the refreshed node in `_weather` so place-picker visibility keeps
working.

## Testing

- Extend `engine/tests/debug_overlay_tests.gd` with the pure weather cycle and
  label behavior.
- Run the debug overlay test directly and verify it fails before implementation.
- After implementation, run the debug overlay test directly, then `make test-fast`.

## Risks

- Duplicate weather layers: refresh must remove existing `WeatherLayer` nodes
  before adding the replacement.
- Place-picker visibility: map refresh should keep `_weather` accurate so
  `_set_map_chrome_visible(false)` still hides weather.
- Debug leakage: the action is mounted only through the existing `Debug.on()`
  gate, so release, headless suites, and quiet captures stay clean.
