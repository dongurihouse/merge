# Debug Weather Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a debug-only control that cycles map and board ambient weather through auto, clear, breeze, rain, and snow.

**Architecture:** Keep the override state in `engine/scripts/ui/ambient.gd`, where weather selection already lives. Let `engine/scripts/ui/debug.gd` expose one button and call a tiny `debug_refresh_weather()` interface on hosts that can redraw their weather layer.

**Tech Stack:** Godot 4.6 GDScript, existing headless `SceneTree` tests, existing Makefile test runner.

## Global Constraints

- Debug weather override cycle is `auto -> clear -> breeze -> rain -> snow -> auto`.
- `auto` uses the existing empty `Ambient.forced_weather` value.
- The debug action is visible only through the existing `Debug.on()` gate.
- Weather refresh must replace the existing `WeatherLayer`, not stack duplicate layers.
- The map's `_weather` member must remain accurate for place-picker show/hide behavior.

---

### Task 1: Ambient Weather Debug State

**Files:**
- Modify: `engine/scripts/ui/ambient.gd`
- Modify: `engine/tests/debug_overlay_tests.gd`

**Interfaces:**
- Produces: `Ambient.weather_debug_label() -> String`
- Produces: `Ambient.debug_cycle_weather() -> String`
- Produces: `Ambient.reset_weather_debug_for_test() -> void`

- [ ] **Step 1: Write the failing test**

Add assertions to `engine/tests/debug_overlay_tests.gd`:

```gdscript
var Ambient = load("res://engine/scripts/ui/ambient.gd")
Ambient.reset_weather_debug_for_test()
ok(Ambient.weather_debug_label() == "Weather: auto", "weather debug starts in auto mode")
ok(Ambient.debug_cycle_weather() == "clear", "weather debug cycles to clear")
ok(Ambient.weather_debug_label() == "Weather: clear", "weather debug label shows clear")
ok(Ambient.debug_cycle_weather() == "breeze", "weather debug cycles to breeze")
ok(Ambient.debug_cycle_weather() == "rain", "weather debug cycles to rain")
ok(Ambient.debug_cycle_weather() == "snow", "weather debug cycles to snow")
ok(Ambient.debug_cycle_weather() == "", "weather debug cycles back to auto")
ok(Ambient.weather_debug_label() == "Weather: auto", "weather debug label returns to auto")
```

- [ ] **Step 2: Verify RED**

Run: `godot --headless --path . -s res://engine/tests/debug_overlay_tests.gd`
Expected: failure because `reset_weather_debug_for_test` does not exist.

- [ ] **Step 3: Implement minimal state helpers**

Add `WEATHER_DEBUG_STATES`, `weather_debug_label`, `debug_cycle_weather`, and
`reset_weather_debug_for_test` in `engine/scripts/ui/ambient.gd`.

- [ ] **Step 4: Verify GREEN**

Run: `godot --headless --path . -s res://engine/tests/debug_overlay_tests.gd`
Expected: all debug overlay tests pass.

### Task 2: Debug Button and Live Weather Refresh

**Files:**
- Modify: `engine/scripts/ui/debug.gd`
- Modify: `engine/scripts/scenes/map.gd`
- Modify: `engine/scripts/scenes/board.gd`
- Modify: `engine/tests/debug_overlay_tests.gd`

**Interfaces:**
- Consumes: `Ambient.debug_cycle_weather() -> String`
- Consumes: `Ambient.weather_debug_label() -> String`
- Produces: `debug_refresh_weather() -> void` on map and board hosts
- Produces: `Debug._weather_action_text() -> String`

- [ ] **Step 1: Write the failing test**

Add assertions to `engine/tests/debug_overlay_tests.gd`:

```gdscript
ok(Debug._weather_action_text() == "Weather: auto", "debug weather action starts at auto")
Ambient.debug_cycle_weather()
ok(Debug._weather_action_text() == "Weather: clear", "debug weather action reflects forced weather")
Ambient.reset_weather_debug_for_test()
```

- [ ] **Step 2: Verify RED**

Run: `godot --headless --path . -s res://engine/tests/debug_overlay_tests.gd`
Expected: failure because `Debug._weather_action_text` does not exist.

- [ ] **Step 3: Implement debug action**

Preload `Ambient` in `engine/scripts/ui/debug.gd`, add `_weather_action_text()`,
mount an action using that label, and implement `_act_weather(host)` to cycle the
override and call `host.debug_refresh_weather()` when present.

- [ ] **Step 4: Implement host refresh**

Add `debug_refresh_weather()` to map and board. Each method removes existing
`WeatherLayer` children and adds a new `Ambient.build_weather(...)` node.

- [ ] **Step 5: Verify GREEN**

Run: `godot --headless --path . -s res://engine/tests/debug_overlay_tests.gd`
Expected: all debug overlay tests pass.

### Task 3: Project Verification

**Files:**
- No new files.

**Interfaces:**
- Consumes all changes from Tasks 1 and 2.

- [ ] **Step 1: Run fast project tests**

Run: `make test-fast`
Expected: engine suite reports zero failures.

- [ ] **Step 2: Inspect diff**

Run: `git diff -- engine/scripts/ui/ambient.gd engine/scripts/ui/debug.gd engine/scripts/scenes/map.gd engine/scripts/scenes/board.gd engine/tests/debug_overlay_tests.gd`
Expected: only the weather toggle and test changes are present, plus pre-existing local edits preserved.
