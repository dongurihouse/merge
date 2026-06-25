# Purge Vase Exp Fill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Purge vase show current exp progress toward the next map unlock, animate upward on quest/debug exp gain, and replace the Purge text button with glowing/breathing/sparkling vase affordance.

**Architecture:** Keep the unlock percentage pure in `engine/scripts/core/quests.gd`, keep water rendering/animation inside `engine/scripts/ui/vase_water_effect.gd`, and let `engine/scripts/scenes/board.gd` bridge exp gain events to the visible Purge card. Debug exp gain calls a board method when the debug host is the board; other debug hosts keep the current scene reload behavior.

**Tech Stack:** Godot 4.6 GDScript, existing headless `SceneTree` suites, existing board/debug UI helpers.

## Global Constraints

- Do not add a global Save event system for this feature.
- The Purge water percentage is `0.0` at the previous claimed spot threshold and `1.0` at the next unclaimed spot threshold.
- Quest exp gain and board debug exp gain must use the same board-level animation path.
- The Purge text button is removed; the card remains tappable and navigates to the map restore screen as before.
- Ready Purge state gets visible glow/sparkle/breath affordance.

---

### Task 1: Test Exp Progress And Vase API

**Files:**
- Modify: `engine/tests/quest_fence_tests.gd`
- Modify: `engine/tests/water_fill_effect_tests.gd`
- Modify: `engine/scripts/core/quests.gd`
- Modify: `engine/scripts/ui/vase_water_effect.gd`

**Interfaces:**
- Produces: `Quests.purge_progress(z: int, exp: int, unlocks: Dictionary) -> float`
- Produces: `VaseWaterEffect.set_progress_for_test(value: float) -> void`
- Produces: `VaseWaterEffect.animate_progress_for_test(value: float) -> void`
- Produces: `VaseWaterEffect.progress_for_test() -> float`
- Produces: `VaseWaterEffect.waterline_y_for_test() -> float`

- [ ] **Step 1: Write failing tests**
Add tests proving fresh progress is `0.0`, next-threshold progress is `1.0`, a claimed first spot resets the baseline, and vase progress moves the waterline upward.

- [ ] **Step 2: Run focused tests to verify RED**
Run: `godot --headless --path . -s res://engine/tests/quest_fence_tests.gd` and `godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd`.

- [ ] **Step 3: Implement minimal progress helpers**
Add the pure quest progress helper and drive `_waterline_y()` from vase progress.

- [ ] **Step 4: Run focused tests to verify GREEN**
Run both focused suites again.

### Task 2: Replace Button With Tappable Progress Vase

**Files:**
- Modify: `engine/tests/water_fill_effect_tests.gd`
- Modify: `engine/scripts/scenes/board.gd`

**Interfaces:**
- Produces: `Board._purge_progress() -> float`
- Produces: `Board.debug_add_exp(amount: int = 5) -> void`
- Consumes: `VaseWaterEffect.set_progress(value: float) -> void`
- Consumes: `VaseWaterEffect.animate_progress_to(value: float) -> void`
- Consumes: `VaseWaterEffect.set_ready(value: bool) -> void`

- [ ] **Step 1: Write failing tests**
Update the Purge card test so it expects a `PurgeVaseWater` child with progress initialized from Save exp, no `Button` descendants, and a tappable card.

- [ ] **Step 2: Run water test to verify RED**
Run: `godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd`.

- [ ] **Step 3: Implement card changes**
Remove the Purge button, wire the card tap to the existing map action, initialize vase progress, and set ready glow/sparkles.

- [ ] **Step 4: Run water test to verify GREEN**
Run the water suite again.

### Task 3: Wire Quest And Debug Exp Gain

**Files:**
- Modify: `engine/tests/water_fill_effect_tests.gd`
- Modify: `engine/scripts/scenes/board.gd`
- Modify: `engine/scripts/ui/debug.gd`

**Interfaces:**
- Consumes: `Board.debug_add_exp(amount: int = 5) -> void`
- Produces: board-level exp gain path that records old Purge progress, updates exp, rebuilds givers, and animates the new Purge vase from the old progress.

- [ ] **Step 1: Write failing test**
Add a board-script test that calls `debug_add_exp()` and asserts Save exp increases while the Purge vase progress increases.

- [ ] **Step 2: Run water test to verify RED**
Run: `godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd`.

- [ ] **Step 3: Implement debug and quest wiring**
Wrap quest exp gain with old/new progress animation. Change debug `+5 stars` so board hosts call `debug_add_exp(5)` without reload; other hosts keep the old reload.

- [ ] **Step 4: Verify**
Run focused suites, `make test-fast`, `make test`, and a `shot-grove MODE=gate` screenshot.
