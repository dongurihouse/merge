# Purge Vase Visual Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Purge vase fill the full card height, move the progress percent into the vase, and replace the hard two-ring glow with a softer gold breathing aura.

**Architecture:** Keep layout ownership in `engine/scripts/scenes/board.gd`, where the Purge slot sizes the vase and positions the percent label. Keep all glow rendering details in `engine/scripts/ui/vase_water_effect.gd`, with small test hooks that expose layout-relevant state without coupling tests to draw calls.

**Tech Stack:** Godot 4.6 GDScript, existing headless SceneTree tests, existing Grove screenshot helper.

## Global Constraints

- Do not reintroduce the Purge card background/frame.
- Do not reintroduce the star/exp count beside the vase.
- Keep the Purge slot tappable and keep the EXP-driven water progress behavior.
- Use the existing acorn vase and mask assets.

---

### Task 1: Pin Layout And Glow Contracts

**Files:**
- Modify: `engine/tests/water_fill_effect_tests.gd`
- Modify: `engine/scripts/ui/vase_water_effect.gd`
- Modify: `engine/scripts/scenes/board.gd`

**Interfaces:**
- Produces: `VaseWaterEffect.ready_glow_style_for_test() -> Dictionary`
- Consumes: `BoardScene._make_purge_card(stand_w: float) -> Control`

- [x] **Step 1: Verify clean baseline**

Run: `godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd`
Expected: `== 35 passed, 0 failed ==`

- [x] **Step 2: Write failing tests**

Add assertions that the Purge vase is nearly the full internal card height, the `%` label is centered inside the vase bounds, and the ready glow test style reports gold soft layers with no hard ring.

- [x] **Step 3: Run focused suite to verify RED**

Run: `godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd`
Expected: FAIL because the vase is still 78% height, the label sits above the vase, and the glow still exposes a hard ring style.

- [x] **Step 4: Implement minimal layout and glow changes**

Set `PurgeVaseWater` to `cardH` tall, center it vertically, place `PurgeProgressLabel` inside the vase bounds, and draw layered gold filled circles behind the vase instead of the current cyan circle plus gold arc.

- [x] **Step 5: Run focused suite to verify GREEN**

Run: `godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd`
Expected: all tests pass.

### Task 2: Verify Screenshot And Commit

**Files:**
- Modify: `docs/superpowers/plans/2026-06-25-purge-vase-visual-polish.md`

**Interfaces:**
- Consumes: Task 1 implementation.

- [x] **Step 1: Run full tests**

Run: `make test`
Expected: all suites pass.

- [x] **Step 2: Capture screenshot**

Run: `make shot-grove MODE=gate OUT=/tmp/grove_purge_vase_visual_polish.png`
Expected: screenshot saved; inspect visually for full-height vase, readable internal percent, and soft gold glow.

- [x] **Step 3: Mark checklist complete**

Update this plan checklist to checked items after verification.

- [x] **Step 4: Commit**

Run:
```bash
git add docs/superpowers/plans/2026-06-25-purge-vase-visual-polish.md engine/scripts/scenes/board.gd engine/scripts/ui/vase_water_effect.gd engine/tests/water_fill_effect_tests.gd
git commit -m "fx: polish purge vase layout"
```
