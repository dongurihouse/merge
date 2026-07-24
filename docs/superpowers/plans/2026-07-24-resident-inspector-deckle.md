# Resident Inspector Deckle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Resident inspector bar's baked background asset with the shared code-drawn jagged paper surface without changing its layout or interactions.

**Architecture:** Keep the existing pinned `ResidentsInspector` container and rebuild flow. Replace only its visual background layer with `Kit.rugged_paper_surface`, configured from the shared row-scale cut-paper settings; validate the live scene tree and selected-state raster.

**Tech Stack:** Godot 4.6, GDScript, Grove UI workbench kit, existing SceneTree test harness.

## Global Constraints

- Preserve the Resident footer dimensions and Expedition visibility.
- Preserve portrait, name, info, Sell, empty hint, padding, and callbacks.
- Use `toggle_card` cut-paper tuning with `Kit.ROW_CP_DEFAULTS`.
- Do not delete the existing asset file; only stop using it for this surface.
- Run `make test-fast` after production changes and `make test` before integration.

---

### Task 1: Replace the Inspector Background

**Files:**
- Modify: `games/grove/tests/grove_explore_tests.gd:1094`
- Modify: `engine/scripts/ui/residents.gd:310`
- Modify: `engine/scripts/ui/residents.gd:924`

**Interfaces:**
- Consumes: `Kit.rugged_paper_surface(host, node_name, size_px, fill, rim, corner_px, cp)`
- Consumes: `Kit.cut_paper_opts_from_config(cfg, "toggle_card", Kit.ROW_CP_DEFAULTS)`
- Produces: a live `Control` named `ResidentsInspectorDeckleSurface` using `res://engine/scripts/ui/cut_paper.gd`

- [ ] **Step 1: Write the failing live-tree assertions**

Extend `_test_residents_dialog_uses_shared_frame()` after the existing shared-panel assertions:

```gdscript
	var inspector := overlay.find_child("ResidentsInspector", true, false) as Control if overlay != null else null
	var deckle := inspector.find_child("ResidentsInspectorDeckleSurface", true, false) as Control \
		if inspector != null else null
	var deckle_script := deckle.get_script() as Script if deckle != null else null
	ok(deckle_script != null and String(deckle_script.resource_path).ends_with("/cut_paper.gd"),
		"resident inspector uses the shared code-drawn cut-paper surface")
	var uses_strip_asset := false
	if inspector != null:
		for node in inspector.find_children("*", "TextureRect", true, false):
			var tex := (node as TextureRect).texture
			if tex != null and String(tex.resource_path).ends_with("/strip_bg.png"):
				uses_strip_asset = true
	ok(not uses_strip_asset, "resident inspector no longer renders the baked strip background")
```

- [ ] **Step 2: Run the focused suite and verify RED**

Run:

```sh
make test-one SUITE=games/grove/tests/grove_explore_tests
```

Expected: the new cut-paper assertion fails because `ResidentsInspectorDeckleSurface` does not exist; the baked-strip assertion also fails while `strip_bg.png` remains in the tree.

- [ ] **Step 3: Replace the baked inspector face**

In `open()`, keep `ResidentsInspector` transparent unconditionally:

```gdscript
	var insp := PanelContainer.new()
	insp.name = "ResidentsInspector"
	insp.custom_minimum_size = Vector2(0, INSPECTOR_H * scale)
	insp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
```

In `_rebuild_inspector()`, replace the `strip_bg` texture and manual rounded shadow block with:

```gdscript
	var bar_h := INSPECTOR_H * s
	var cp: Dictionary = Kit.cut_paper_opts_from_config(ctx.cfg, "toggle_card", Kit.ROW_CP_DEFAULTS)
	Kit.rugged_paper_surface(
		body,
		"ResidentsInspectorDeckleSurface",
		Vector2.ZERO,
		Pal.CREAM.darkened(0.05),
		Kit.PAPER_EDGE,
		bar_h * 0.5,
		cp)
```

Leave every content and callback line below that block unchanged.

- [ ] **Step 4: Run the focused suite and verify GREEN**

Run:

```sh
make test-one SUITE=games/grove/tests/grove_explore_tests
```

Expected: all assertions pass, including the generated-surface and no-baked-strip checks.

- [ ] **Step 5: Run the fast suite**

Run:

```sh
make test-fast
```

Expected: every fast suite passes with zero failures.

- [ ] **Step 6: Capture and inspect the selected inspector**

Run:

```sh
out_dir=$(mktemp -d /tmp/resident-inspector-deckle.XXXXXX)
engine/tools/quiet_godot.sh --path . \
	-s res://games/grove/tools/residents_dialog_shot.gd -- "$out_dir"
```

Inspect `"$out_dir/residents_dialog_selected.png"` and confirm:

- The inspector has a visible jagged perimeter and paper fibre.
- The old smooth baked strip is absent.
- Portrait, name, info, and Sell remain aligned and readable.
- Expedition remains above the inspector and fully visible.

- [ ] **Step 7: Run full verification**

Run:

```sh
make test
```

Expected: every suite passes with zero failures.

- [ ] **Step 8: Commit the implementation**

```sh
git add engine/scripts/ui/residents.gd games/grove/tests/grove_explore_tests.gd
git commit -m "fix(residents): draw inspector bar in code"
```
