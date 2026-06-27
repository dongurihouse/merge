# Item Info Descriptions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show player-useful item names and descriptions in the board info bar, including special drops that currently fall back to `Item`.

**Architecture:** Store item copy with the Grove data that already owns item lines and special definitions. Expose small content helpers for display name and description, then let the board info bar render a title plus a compact hint line.

**Tech Stack:** Godot 4 GDScript, existing Grove test harness, `make test-one`, `make test-fast`, `make test`.

## Global Constraints

- Keep the bottom bar compact; do not add a separate modal or new navigation surface.
- Preserve the existing selected-item title format: `<name> · Tier N`.
- Special drops must no longer show as generic `Item`.
- Use `make test-fast` after changes and run the focused Grove suite for this behavior.

---

### Task 1: Data-backed Info-Bar Copy

**Files:**
- Create: `games/grove/tests/grove_info_bar_tests.gd`
- Modify: `Makefile`
- Modify: `games/grove/grove_data.gd`
- Modify: `engine/scripts/core/content.gd`
- Modify: `games/grove/tools/ui_workbench_kit.gd`
- Modify: `engine/scripts/scenes/board.gd`

**Interfaces:**
- Produces: `G.item_display_name(code: int) -> String`
- Produces: `G.item_description(code: int) -> String`
- Produces: info-bar meta `desc_label: Label`
- Consumes: `G.LINES`, `G.SPECIAL_ITEMS`, `G.special_collect(code)`, `G.coin_value(code)`

- [ ] **Step 1: Write the failing test**

Create `games/grove/tests/grove_info_bar_tests.gd` with assertions that special drops have real names and selected items populate a description label.

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_info_bar_tests`

Expected: FAIL because `item_display_name` / `item_description` and `_info_desc_label` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Add `desc` fields to line data and `name` / `desc` fields to special item data. Add the two `G` helper methods. Add a smaller second label to the shared info-bar kit, expose it as `desc_label`, and update board selection to fill or hide it.

- [ ] **Step 4: Run focused verification**

Run: `make test-one SUITE=games/grove/tests/grove_info_bar_tests`

Expected: PASS.

- [ ] **Step 5: Run repo verification**

Run: `make test-fast`

Expected: PASS.

Run: `make test`

Expected: PASS, or report any pre-existing unrelated baseline failures with exact suite names.
