# Debug Overlay Drag Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the owner drag the debug overlay toggle to a new on-screen position without breaking normal click-to-open behavior.

**Architecture:** Keep the behavior inside `engine/scripts/ui/debug.gd`. The overlay column gets a session-only stored position, the red `DEBUG` button becomes the drag handle, and drag release suppresses the click toggle for that gesture.

**Tech Stack:** Godot 4.6 GDScript, existing headless `SceneTree` tests.

## Global Constraints

- The position is session-only debug chrome state, not player save data.
- Normal click still opens/closes the debug action menu.
- Dragging clamps the overlay inside the viewport.
- The dragged position persists across scene reloads in the same app run.

---

### Task 1: Draggable Debug Toggle

**Files:**
- Create: `engine/tests/debug_overlay_tests.gd`
- Modify: `engine/scripts/ui/debug.gd`
- Modify: `Makefile`

**Interfaces:**
- Produces: `Debug._default_panel_position(host: Control) -> Vector2`
- Produces: `Debug._clamp_panel_position(pos: Vector2, panel_size: Vector2, viewport_size: Vector2) -> Vector2`
- Produces: `Debug._on_toggle_gui_input(ev: InputEvent, host: Control, panel: Control) -> void`
- Produces: `Debug._on_toggle_pressed(menu: Control) -> void`
- Produces: `Debug.reset_drag_for_test() -> void`
- Produces: `Debug.drag_position_for_test() -> Vector2`

- [ ] **Step 1: Write failing tests**
Test default position, clamping, drag moves/stores panel position, drag release suppresses menu toggle, and normal click still toggles the menu.

- [ ] **Step 2: Verify RED**
Run `godot --headless --path . -s res://engine/tests/debug_overlay_tests.gd`. Expected: missing helper methods.

- [ ] **Step 3: Implement drag behavior**
Wire the toggle `gui_input` to drag the overlay, persist the static position, clamp to viewport, and suppress the next toggle press after a drag.

- [ ] **Step 4: Verify GREEN**
Run `godot --headless --path . -s res://engine/tests/debug_overlay_tests.gd`, then `make test-fast` and `make test`.
