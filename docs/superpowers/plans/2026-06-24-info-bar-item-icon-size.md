# Info Bar Item Icon Size Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a saved workbench control for the selected item/generator sprite size in the board info bar.

**Architecture:** Keep `inner_scale` as the slot-size knob and add `item_icon_scale` as an artwork-scale knob resolved by `Kit.info_bar_opts_from_config`. `Kit.info_bar` exposes the resolved scale in metadata so both `ui_workbench_view.gd` and `board.gd` render selected previews from one setting.

**Tech Stack:** Godot 4 GDScript, existing Grove UI workbench kit, existing headless Grove workbench tests.

## Global Constraints

- Use the existing `info_bar` config block and workbench sidebar pattern.
- Preserve the current default look with `item_icon_scale = 80`.
- Do not affect Buy/Sell currency icons; those stay on `sell_icon`.
- Run `make test-fast` after changes and a targeted Grove workbench test before merging.

---

### Task 1: Add The Info Bar Item Icon Scale Knob

**Files:**
- Modify: `games/grove/tests/grove_workbench_tests.gd`
- Modify: `games/grove/tools/ui_workbench_kit.gd`
- Modify: `games/grove/tools/ui_workbench_view.gd`
- Modify: `games/grove/tools/ui_workbench_settings.json`
- Modify: `engine/scripts/scenes/board.gd`

**Interfaces:**
- Consumes: `Kit.info_bar_opts_from_config(cfg: Dictionary) -> Dictionary`
- Produces: `opts.item_icon_scale: float`, where `0.80` means 80 percent of the info icon slot
- Produces: `PanelContainer` metadata key `"item_icon_scale"` for `Kit.info_bar`

- [ ] **Step 1: Write the failing test**

Add expectations near the existing info-bar workbench assertions:

```gdscript
var ib: Dictionary = Kit.info_bar_opts_from_config({"info_bar": {"height": 150, "inner_scale": 60, "name_font": 28, "sep": 6, "sell_font": 24, "sell_icon": 40, "item_icon_scale": 115}})
ok(is_equal_approx(float(ib.item_icon_scale), 1.15), "info_bar reads item_icon_scale as a selected item/generator artwork scale")
ok(is_equal_approx(float(Kit.info_bar_opts_from_config({}).item_icon_scale), 0.80), "default info_bar item_icon_scale preserves the shipped selected-item size")
ok(view._is_config("info_bar", "item_icon_scale"), "the info-bar selected item icon scale is saved config")
var scaled_bar: PanelContainer = Kit.info_bar({}, ib)
ok(is_equal_approx(float(scaled_bar.get_meta("item_icon_scale")), 1.15), "info_bar exposes item_icon_scale for live board and preview renderers")
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
make test-one TEST=games/grove/tests/grove_workbench_tests
```

Expected: FAIL because `item_icon_scale` is not resolved, saved, or exposed yet.

- [ ] **Step 3: Implement the minimal code**

Make these exact behavior changes:

```gdscript
# ui_workbench_kit.gd info_bar_opts_from_config return dictionary
"item_icon_scale": float(i.get("item_icon_scale", 80)) / 100.0,

# ui_workbench_kit.gd info_bar before return
pill.set_meta("item_icon_scale", float(opts.get("item_icon_scale", 0.80)))

# ui_workbench_view.gd DEFAULTS["info_bar"]
"item_icon_scale": 80,

# ui_workbench_view.gd _make_element("info_bar")
var item_scale := float(ib.get_meta("item_icon_scale", 0.80))
(ib.get_meta("info_icon") as CenterContainer).add_child(PieceView.make_piece(102, inner * item_scale))

# ui_workbench_view.gd info_bar sidebar
_sidebar_body.add_child(_slider_row(["item_icon_scale", 50, 120]))

# board.gd _build_info_bar
_info_item_icon_scale = float(pill.get_meta("item_icon_scale", 0.80))

# board.gd selected item/generator previews
_info_icon.add_child(_make_piece(code, _info_inner_px * _info_item_icon_scale))
var prev := PieceView.make_generator(gid, _info_inner_px * _info_item_icon_scale, {})
```

Add a `var _info_item_icon_scale := 0.80` member beside the existing `_info_inner_px`.

- [ ] **Step 4: Run tests to verify green**

Run:

```bash
make test-one TEST=games/grove/tests/grove_workbench_tests
make test-fast
```

Expected: both pass.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-06-24-info-bar-item-icon-size-design.md docs/superpowers/plans/2026-06-24-info-bar-item-icon-size.md games/grove/tests/grove_workbench_tests.gd games/grove/tools/ui_workbench_kit.gd games/grove/tools/ui_workbench_view.gd games/grove/tools/ui_workbench_settings.json engine/scripts/scenes/board.gd
git commit -m "feat: tune info bar item icon size"
```

### Task 2: Merge To Main And Clean Up

**Files:**
- No source file changes.

**Interfaces:**
- Consumes: passing feature branch `codex/info-bar-item-icon-size`
- Produces: main branch containing the feature commit

- [ ] **Step 1: Verify final branch state**

Run:

```bash
git status --short
make test-fast
```

Expected: clean status and passing tests.

- [ ] **Step 2: Merge**

Run:

```bash
git switch main
git merge --no-ff codex/info-bar-item-icon-size
```

Expected: merge commit created without conflicts.

- [ ] **Step 3: Verify on main**

Run:

```bash
make test-fast
```

Expected: pass on `main`.

- [ ] **Step 4: Clean branch**

Run:

```bash
git branch -d codex/info-bar-item-icon-size
```

Expected: feature branch deleted after merge.
