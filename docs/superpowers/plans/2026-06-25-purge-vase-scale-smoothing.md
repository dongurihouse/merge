# Purge Vase Scale Smoothing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Purge vase fill the whole card slot top-to-bottom, keep it full color while not ready, and smooth jagged vase rendering.

**Architecture:** Keep Purge slot sizing and disabled-state behavior in `engine/scripts/scenes/board.gd`. Keep texture filtering ownership in `engine/scripts/ui/vase_water_effect.gd` and use Godot import metadata for mipmaps on the visible vase asset. Tests stay in the focused water suite.

**Tech Stack:** Godot 4.6 GDScript, Godot texture import metadata, existing headless SceneTree tests, existing Grove screenshot helper.

## Global Constraints

- Keep the acorn vase and mask assets.
- Keep the percent label inside the vase.
- Keep ready glow/sparkles only for unlock-ready state.
- Do not reintroduce the old Purge card frame, text button, or star count.

---

### Task 1: Pin Layout, Readiness, And Import Behavior

**Files:**
- Modify: `engine/tests/water_fill_effect_tests.gd`
- Modify: `engine/scripts/scenes/board.gd`
- Modify: `engine/scripts/ui/vase_water_effect.gd`
- Modify: `games/grove/assets/ui/vase/vase_acorn.png.import`

**Interfaces:**
- Consumes: `BoardScene._make_purge_card(stand_w: float) -> Control`
- Consumes: `VaseWaterEffect.VASE_PATH`
- Produces: `VaseWaterEffect.get_texture_for_test() -> Texture2D`

- [x] **Step 1: Write failing tests**

Update `engine/tests/water_fill_effect_tests.gd` to assert:
- `PurgeVaseWater.size.y >= purge_card.custom_minimum_size.y * 0.96`
- `PurgeVaseWater.position.y <= purge_card.custom_minimum_size.y * 0.02`
- a not-ready Purge card and its vase keep `Color.WHITE` modulation
- `games/grove/assets/ui/vase/vase_acorn.png.import` contains `mipmaps/generate=true`

- [x] **Step 2: Run focused suite to verify RED**

Run: `godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd`
Expected: FAIL because the vase currently uses the inner card height, the not-ready slot is dimmed by `PURGE_DIM`, and the visible vase import has `mipmaps/generate=false`.

- [x] **Step 3: Implement minimal changes**

In `board.gd`, set the Purge vase height to the whole `FENCE_H` slot and leave the not-ready Purge slot at `Color.WHITE`. In `vase_water_effect.gd`, set `texture_filter` to linear mipmap filtering. In `vase_acorn.png.import`, enable mipmap generation for the visible vase texture.

- [x] **Step 4: Run focused suite to verify GREEN**

Run: `godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd`
Expected: all tests pass.

### Task 2: Visual And Full Verification

**Files:**
- Modify: `docs/superpowers/plans/2026-06-25-purge-vase-scale-smoothing.md`

**Interfaces:**
- Consumes: Task 1 implementation.

- [x] **Step 1: Run full tests**

Run: `make test`
Expected: all suites pass.

- [x] **Step 2: Capture and inspect screenshot**

Run: `make shot-grove MODE=gate OUT=/tmp/grove_purge_vase_scale_smoothing.png`
Expected: screenshot saved; visually confirm the vase fills the slot, remains full color, and looks smoother.

- [x] **Step 3: Mark checklist complete**

Update this file so completed steps are checked.

- [x] **Step 4: Commit**

Run:
```bash
git add docs/superpowers/plans/2026-06-25-purge-vase-scale-smoothing.md engine/scripts/scenes/board.gd engine/scripts/ui/vase_water_effect.gd engine/tests/water_fill_effect_tests.gd games/grove/assets/ui/vase/vase_acorn.png.import
git commit -m "fx: smooth and enlarge purge vase"
```
