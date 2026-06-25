# HUD Control Sizing Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make wallet currency pills 80% larger and shared HUD/nav controls 50% larger while keeping runtime rendering synced with the UI Workbench settings.

**Architecture:** Add one persisted `overall_scale` percentage to `gold_currency_pill`; the resolver applies it to dimensional layout metrics so the pill grows as a unit. Let map bottom-nav Map/Residents buttons use `home_button.px` from the workbench instead of hard-coding `140`; let board Bag/Home wells derive from the same saved size while preserving their existing optical ratio. Existing settings/rail `0.80 * px` behavior remains intact.

**Tech Stack:** Godot 4 GDScript, Grove UI Workbench kit, existing headless Grove UI/workbench tests.

## Global Constraints

- Keep `games/grove/tools/ui_workbench_settings.json` as the source of truth for live runtime tuning.
- Do not change unrelated user edits already present in the working tree.
- Use TDD: add failing expectations before production changes.
- Run `make test-fast` after the targeted Grove workbench test.

---

### Task 1: Add Scaled Currency Pill And Sync Map Nav Size

**Files:**
- Modify: `games/grove/tests/grove_workbench_tests.gd`
- Modify: `games/grove/tools/ui_workbench_kit.gd`
- Modify: `games/grove/tools/ui_workbench_view.gd`
- Modify: `engine/scripts/scenes/map.gd`
- Modify: `engine/scripts/scenes/board.gd`
- Modify: `games/grove/tools/ui_workbench_settings.json`

**Interfaces:**
- Consumes: `Kit.gold_currency_pill_opts_from_config(cfg: Dictionary) -> Dictionary`
- Produces: `gold_currency_pill.overall_scale` saved as a percent, where `180` means 1.8x.
- Produces: Map/Residents nav buttons and board Bag/Home wells that derive from `home_button.px` in workbench config.

- [ ] **Step 1: Write failing tests**

Add workbench expectations that:

```gdscript
var scaled := Kit.gold_currency_pill_opts_from_config({"gold_currency_pill": {"overall_scale": 180}})
ok(is_equal_approx(float(scaled.pill_w), 525.6) and is_equal_approx(float(scaled.pill_h), 180.0), \
	"gold_currency_pill overall_scale grows the frame as one unit")
ok(is_equal_approx(float(scaled.icon_box), 97.2) and int(scaled.num_size) == 54 and is_equal_approx(float(scaled.plus_button), 180.0), \
	"gold_currency_pill overall_scale grows icon, font, and plus controls together")
ok(view._is_config("gold_currency_pill", "overall_scale"), \
	"gold_currency_pill overall_scale is saved config")
view._selected = "gold_currency_pill"
view._rebuild_sidebar()
ok(_slider_max(view, "Overall Scale") >= 220.0, \
	"gold_currency_pill sidebar exposes overall scaling")
```

Add source guards that fail while map nav overrides the saved button size:

```gdscript
ok(not _source_contains("res://engine/scripts/scenes/map.gd", "opts[\"px\"] = 140.0"), \
	"map bottom-nav buttons use the workbench home_button px instead of hard-coded 140")
ok(not _source_contains("res://engine/scripts/scenes/board.gd", "_build_bag_box(BOTTOM_BTN_PX)") \
	and not _source_contains("res://engine/scripts/scenes/board.gd", "_home_nav_button(BOTTOM_BTN_PX)"), \
	"board Bag/Home wells use the workbench home_button px instead of the old board constant")
```

- [ ] **Step 2: Verify red**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_workbench_tests
```

Expected: FAIL because `overall_scale` is unresolved, `map.gd` still hard-codes `opts["px"] = 140.0`, and the board still builds Bag/Home from `BOTTOM_BTN_PX`.

- [ ] **Step 3: Implement minimal code**

In `gold_currency_pill_opts_from_config`, compute:

```gdscript
var scale := float(g.get("overall_scale", 100.0)) / 100.0
```

Multiply dimensional layout metrics by `scale`: `pill_w`, `pill_h`, `pad_left`, `pad_x`, `pad_y`, `icon_box`, `icon_size`, `icon_x`, `amount_w`, `num_size`, `amount_x`, `gap`, `plus_x`, `plus_stroke`, `plus_font`, `plus_button`, and `plus_label_y`. Keep color, hue, shape ratios, and shadow/intensity values unscaled.

Add `"overall_scale": 100` to the workbench default `gold_currency_pill` block and add `_slider_row(["overall_scale", 60, 220])` to the pill sidebar.

Remove the `opts["px"] = 140.0` overrides from `_make_map_button()` and `_make_residents_button()` so they inherit `home_button.px`. In `board.gd`, add a helper that reads `home_button.px` and derives Bag/Home well size from the existing `130 / 140` board ratio.

- [ ] **Step 4: Update shipped settings**

Edit `games/grove/tools/ui_workbench_settings.json`:

```json
"gold_currency_pill": {
	"overall_scale": 180.0,
	...
},
"home_button": {
	"px": 210.0,
	...
}
```

- [ ] **Step 5: Verify green**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_workbench_tests
make test-fast
```

Expected: both commands exit 0.
