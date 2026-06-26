# Vase Droplet Shape Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the round water drop with a teardrop-shaped droplet that subtly shape-shifts while falling.

**Architecture:** Keep droplet state and rendering inside `engine/scripts/ui/vase_water_effect.gd`. Extend the existing `_drop_state()` dictionary with shape metadata so tests can verify a real teardrop silhouette and changing squash/stretch without inspecting pixels. Draw the drop as a polygon with a rounded base and tapered top, plus the existing highlight.

**Tech Stack:** Godot 4.6 GDScript, existing headless water suite, existing Grove screenshot helper.

## Global Constraints

- No new image assets.
- Keep existing drop timing and impact behavior.
- Keep the drop large enough to read on the acorn vase.
- Keep the water fill, mask, and Purge card behavior unchanged.

---

### Task 1: Teardrop State And Rendering

**Files:**
- Modify: `engine/tests/water_fill_effect_tests.gd`
- Modify: `engine/scripts/ui/vase_water_effect.gd`

**Interfaces:**
- Consumes: `VaseWaterEffect.drop_state_for_test() -> Dictionary`
- Produces: `VaseWaterEffect.drop_shape_points_for_test() -> PackedVector2Array`

- [x] **Step 1: Write failing tests**

Update `engine/tests/water_fill_effect_tests.gd` to assert that a visible vase drop reports `shape == "teardrop"`, has `width_scale` and `height_scale`, changes those values between growing and falling timestamps, and exposes at least 8 shape points whose top is above the center and bottom is below the center.

- [x] **Step 2: Run focused suite to verify RED**

Run: `godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd`
Expected: FAIL because the current drop is a circle and does not expose shape metadata or points.

- [x] **Step 3: Implement minimal teardrop shape**

Extend `_drop_state()` with `shape`, `width_scale`, `height_scale`, and `wobble`. Add a helper that builds a teardrop polygon from that state. Change `_draw_drop()` to draw the polygon instead of a circle and keep the small highlight.

- [x] **Step 4: Run focused suite to verify GREEN**

Run: `godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd`
Expected: all tests pass.

### Task 2: Verify And Commit

**Files:**
- Modify: `docs/superpowers/plans/2026-06-25-vase-droplet-shape.md`

**Interfaces:**
- Consumes: Task 1 implementation.

- [x] **Step 1: Run full tests**

Run: `make test`
Expected: all suites pass.

- [x] **Step 2: Capture and inspect screenshot**

Run: `make shot-grove MODE=gate OUT=/tmp/grove_vase_droplet_shape.png`
Expected: screenshot saved; visible drop reads as a water droplet rather than a dot.

- [x] **Step 3: Mark checklist complete**

Update this file so completed steps are checked.

- [x] **Step 4: Commit**

Run:
```bash
git add docs/superpowers/plans/2026-06-25-vase-droplet-shape.md engine/scripts/ui/vase_water_effect.gd engine/tests/water_fill_effect_tests.gd
git commit -m "fx: shape vase water droplet"
```
