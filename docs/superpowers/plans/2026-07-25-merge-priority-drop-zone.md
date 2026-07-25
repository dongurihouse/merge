# Merge-Priority Drop Zone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every compatible board merge a larger, priority drop area while leaving non-merge drops unchanged.

**Architecture:** Add one scene-level helper that searches enlarged rectangles around compatible merge targets and chooses the nearest. Reuse it from item telegraph and item/generator release before the existing exact-cell action chain.

**Tech Stack:** Godot 4.6, GDScript, the existing headless SceneTree test harness.

## Global Constraints

- Matching items, recipe pairs, and same-tier matching generators all qualify.
- A nearby compatible merge takes precedence over move or swap.
- Without a nearby compatible merge, existing drop behavior is unchanged.
- Keep tuning reversible through one named constant.

---

### Task 1: Merge-priority scene targeting

**Files:**
- Modify: `engine/tests/mechanics_tests.gd`
- Modify: `engine/scripts/scenes/board.gd`

**Interfaces:**
- Produces: `_merge_target_at(from: Vector2i, pos: Vector2, drag_is_gen: bool) -> Vector2i`
- Consumes: `BoardModel.can_merge`, `_recipe_merge_code`, generator id/tier state, `_cell_pos`, and `csz`

- [ ] **Step 1: Write the failing player-path regression**

Add board-scene fixtures that call `_on_press` and `_on_release` with a release point inside a competing cell but also inside an enlarged compatible target area. Assert that matching items merge instead of swapping, valid recipe pairs craft instead of swapping, and matching generators merge instead of moving or swapping.

- [ ] **Step 2: Verify the regression fails for the intended reason**

Run `make test-one SUITE=engine/tests/mechanics_tests`.

Expected: the new assertions fail because `_on_release` uses only `_pos_to_cell(pos)` and resolves the competing exact cell.

- [ ] **Step 3: Implement the minimal resolver**

Add a named grow fraction, scan occupied candidate cells, reject incompatible pairs, test the enlarged target rectangle, and return the nearest compatible cell. Use that result before the existing item/generator action chain; use it for item telegraph targeting as well.

- [ ] **Step 4: Verify focused and broad behavior**

Run `make test-one T=engine/tests/mechanics_tests.gd`, then `make test-fast`, then `make test`.

Expected: all commands exit zero with no failed assertions.

- [ ] **Step 5: Review and commit**

Inspect `git diff --check` and the focused diff for accidental scope growth, then commit the implementation and tests.
