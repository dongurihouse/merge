# Level Dialog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the polished Level dialog (ref `_originals/ui/lvl.png`) to the UI workbench and hook it to the game: a tap-to-view info popup and an auto level-up celebration whose **Collect** button grants the level-up gift.

**Architecture:** Extract sprites from `lvl_asset.png` into `ui/kit/`. Add four composable kit functions (`progress_bar`, `level_medallion`, `level_frame`, `level_dialog`) + config helpers, mirroring the existing `dialog_*` pattern so the game reads the same `ui_workbench_settings.json`. Add two workbench gallery items. Split the level-up gift out of `earn_stars` so the dialog's Collect grants it; rebuild `level_popup.gd` on the kit with two modes; wire `board.gd`.

**Tech Stack:** Godot 4.6 (GDScript), the project's `@tool` UI workbench, `make` test/intake harness, asset-intake `slice_islands` flow.

**Working dir:** worktree `worktree-level-dialog` at `/Users/xup/dh/merge/.claude/worktrees/level-dialog`. Run all commands there.

**Conventions:** `make test-fast` after every change; `make test` before handoff. Headless logic tests are SceneTree scripts. Visual checks deliver the capture file to the user — never eyeball a thumbnail.

---

### Task 1: Extract the Level assets from `lvl_asset.png`

**Files:**
- Create: `games/grove/assets/_new/lvl_asset.plan.json`
- Source (already present, untracked): `games/grove/assets/_originals/ui/lvl_asset.png`
- Outputs land under: `games/grove/assets/ui/kit/`

- [ ] **Step 1: Slice to scratch and read the island indices**

```bash
mkdir -p /tmp/lvlpeek
godot --headless --path . -s res://games/tools/slice_islands.gd -- \
  games/grove/assets/_originals/ui/lvl_asset.png /tmp/lvlpeek/cell_
```
`slice_islands` prints `n -> x,y wxh (px=count)` top→bottom, left→right. Open each
`/tmp/lvlpeek/cell_<n>.png` (Read tool) and map index → piece. Expected pieces: ornate frame,
gold "Level" title pill, gold medallion ring, laurel wreath, green button, ≥2 progress capsules
(empty track + honey fill), plus small star/sparkle/corner islands to ignore.

**Inspect `level_ring`:** note whether it already includes a cream inner face (if so, `level_medallion`
skips layering the badge disc behind it — Task 3 Step 3 branches on this). Record the finding in the
commit message.

- [ ] **Step 2: Author the plan** at `games/grove/assets/_new/lvl_asset.plan.json` (fill `island`
indices from Step 1; `post: "icon:N"` only on pieces that should be squared — the ring/wreath/star;
the frame/pill/button/bars keep their aspect so they 9-slice/scale cleanly, so NO `post` on those):

```json
{
  "source": "_originals/ui/lvl_asset.png",
  "category": "sheet",
  "params": { "min_area": 400 },
  "outputs": [
    { "island": 0, "name": "level_frame",  "path": "ui/kit/level_frame.png" },
    { "island": 1, "name": "level_title",  "path": "ui/kit/level_title.png" },
    { "island": 2, "name": "level_ring",   "path": "ui/kit/level_ring.png",   "post": "icon:512" },
    { "island": 3, "name": "level_wreath", "path": "ui/kit/level_wreath.png", "post": "icon:512" },
    { "island": 4, "name": "level_btn",    "path": "ui/kit/level_btn.png" },
    { "island": 5, "name": "prog_track",   "path": "ui/kit/prog_track.png" },
    { "island": 6, "name": "prog_fill",    "path": "ui/kit/prog_fill.png" }
  ],
  "archive": "_originals/ui/lvl_asset.png"
}
```
Note: `archive` equals `source` (the raw already lives in `_originals/`). If `intake_apply` errors on
the same-path move, set `"archive": "_originals/ui/lvl_asset_raw.png"` (a rename in place) and re-run.

- [ ] **Step 3: Apply intake**

```bash
make intake PLAN=games/grove/assets/_new/lvl_asset.plan.json 2>&1 | tail -20
```
Expected: outputs written, raw archived, plan moved to `_new/_processed/`.

- [ ] **Step 4: Verify outputs landed**

```bash
ls -1 games/grove/assets/ui/kit/level_*.png games/grove/assets/ui/kit/prog_*.png
ls games/grove/assets/_new/_processed/lvl_asset.plan.json
```
Expected: all seven files exist; the plan moved to `_processed/`. Open 2-3 with the Read tool to
confirm clean cutouts (no neighbor bleed, no leftover background fringe).

- [ ] **Step 5: Run fast tests (intake shouldn't affect them) and commit**

```bash
make test-fast 2>&1 | tail -3
git add games/grove/assets/ui/kit/level_*.png games/grove/assets/ui/kit/prog_*.png \
        games/grove/assets/_new/_processed/lvl_asset.plan.json games/grove/assets/_originals/ui/lvl*.png
git commit -m "Level assets: slice lvl_asset.png into ui/kit (frame, title, ring, wreath, button, bars)

Note: level_ring [does|does not] include a cream inner face.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `progress_bar` kit component + config + workbench item

**Files:**
- Modify: `games/grove/tools/ui_workbench_kit.gd` (add `progress_bar` + `progress_bar_opts_from_config`)
- Modify: `games/grove/tools/ui_workbench_view.gd` (add the `progress_bar` gallery item)
- Modify: `games/grove/tools/ui_workbench_settings.json` (add a `"progress_bar"` section)
- Test: `games/grove/tests/grove_ui_tests.gd`

- [ ] **Step 1: Write the failing test.** Append a sub-test call + function to `grove_ui_tests.gd`
(find the `func _run()`/list of `_test_*` calls and add `_test_progress_bar()` alongside the others):

```gdscript
func _test_progress_bar() -> void:
	const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
	for frac in [0.0, 0.5, 1.0]:
		var bar := Kit.progress_bar(frac, {"height": 20.0, "art": false})
		ok(bar != null and bar is Control, "progress_bar builds at frac=%.1f" % frac)
		bar.free()
	var labelled := Kit.progress_bar(0.75, {"height": 22.0, "art": false, "label": "75%"})
	var found := _find_label_text(labelled, "75%")
	ok(found, "progress_bar shows its centered label")
	labelled.free()
```
If `_find_label_text` does not already exist in the suite/base, add this helper to `grove_test_base.gd`:

```gdscript
# Recursively search a built UI tree for a Label whose text contains `needle`.
func _find_label_text(node: Node, needle: String) -> bool:
	if node is Label and String((node as Label).text).find(needle) != -1:
		return true
	for c in node.get_children():
		if _find_label_text(c, needle):
			return true
	return false
```

- [ ] **Step 2: Run it; verify it fails**

```bash
make test-one SUITE=games/grove/tests/grove_ui_tests 2>&1 | tail -15
```
Expected: FAIL/crash — `Kit.progress_bar` does not exist yet.

- [ ] **Step 3: Implement `progress_bar` in `ui_workbench_kit.gd`** (place it near the other small
builders, e.g. after `_ribbon_badge`). Capsule track + clipped honey fill, art with code fallback,
optional centered label and a star knob at the fill head:

```gdscript
## A reusable PROGRESS BAR — a rounded track with a honey fill clipped to `frac` (0..1). Art mode
## uses the kit's prog_track / prog_fill capsules (scaled whole); else a code-drawn StyleBoxFlat
## track + fill (the legacy look). opts: height (px), art (bool), label ("" = none; centered, e.g.
## "75%"), star_knob (bool — a star sprite at the fill head). Used by the Level dialog AND (later)
## the home-screen unlock %. Standalone so improving it lifts every site.
static func progress_bar(frac: float, opts: Dictionary = {}) -> Control:
	var h: float = float(opts.get("height", 20.0))
	var f: float = clampf(frac, 0.0, 1.0)
	var use_art: bool = bool(opts.get("art", true))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(float(opts.get("width", 280.0)), h)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# --- track ---
	var track_tex: Texture2D = clean_tex_path(Look.kit("kit/prog_track.png"), 256) if use_art else null
	if track_tex != null:
		var t := TextureRect.new()
		t.texture = track_tex
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(t)
	else:
		var track := Panel.new()
		track.set_anchors_preset(Control.PRESET_FULL_RECT)
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(Pal.INK, 0.12)
		tsb.set_corner_radius_all(int(h * 0.5))
		track.add_theme_stylebox_override("panel", tsb)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(track)
	# --- fill (clipped to frac; at least a rounded nub so 0% still reads) ---
	var fill_clip := Control.new()
	fill_clip.clip_contents = true
	fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fill_clip)
	var fill_tex: Texture2D = clean_tex_path(Look.kit("kit/prog_fill.png"), 256) if use_art else null
	var fill: Control
	if fill_tex != null:
		var fr := TextureRect.new()
		fr.texture = fill_tex
		fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fr.stretch_mode = TextureRect.STRETCH_SCALE
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill = fr
	else:
		var fp := Panel.new()
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = Pal.STRAW
		fsb.set_corner_radius_all(int(h * 0.5))
		fp.add_theme_stylebox_override("panel", fsb)
		fp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill = fp
	fill_clip.add_child(fill)
	# size the clip+fill on layout (frac of the holder width; fill keeps full width so its right cap
	# stays rounded, the clip reveals only `frac` of it)
	var lay := func() -> void:
		if not (is_instance_valid(holder) and is_instance_valid(fill_clip) and is_instance_valid(fill)):
			return
		var w := holder.size.x
		var fw := maxf(h, w * f)            # min a nub
		fill_clip.position = Vector2.ZERO
		fill_clip.size = Vector2(fw, h)
		fill.position = Vector2.ZERO
		fill.size = Vector2(w, h)
	holder.resized.connect(lay)
	holder.ready.connect(lay)
	lay.call_deferred()
	# --- optional star knob at the fill head ---
	if bool(opts.get("star_knob", false)):
		var knob := make_icon("star", h * 1.4)
		knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(knob)
		var place := func() -> void:
			if is_instance_valid(knob) and is_instance_valid(holder):
				knob.position = Vector2(maxf(0.0, holder.size.x * f - h * 0.7), -h * 0.2)
		holder.resized.connect(place)
		place.call_deferred()
	# --- optional centered label (e.g. "75%") ---
	var label := String(opts.get("label", ""))
	if label != "":
		var l := Label.new()
		l.text = label
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", int(h * 0.7))
		l.add_theme_color_override("font_color", Pal.INK)
		l.add_theme_constant_override("outline_size", 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(l)
	return holder

## The progress bar's saved STYLE from config (height / art / label / star knob). The Level dialog and
## the workbench preview read it from here.
static func progress_bar_opts_from_config(cfg: Dictionary) -> Dictionary:
	var p: Dictionary = cfg.get("progress_bar", {})
	return {
		"height": float(p.get("height", 20)),
		"art": bool(p.get("art", true)),
		"star_knob": bool(p.get("star_knob", false)),
	}
```

- [ ] **Step 4: Run the test; verify it passes**

```bash
make test-one SUITE=games/grove/tests/grove_ui_tests 2>&1 | tail -8
```
Expected: the three `progress_bar builds…` + `centered label` asserts PASS.

- [ ] **Step 5: Add the `progress_bar` workbench item** in `ui_workbench_view.gd`. Make these edits:

1. `const IDS` — add `"progress_bar"`.
2. `const COLUMNS` — add `["progress_bar"]` to the building-blocks (first) column, e.g. after `["frame"]`.
3. `const TEST_KEYS` — add `"progress_bar": ["frac"],` (frac is preview-only).
4. `const CAPTIONS` — add `"progress_bar": "Progress bar — track + fill (reusable)",`.
5. `_params` — add:
```gdscript
	"progress_bar": {"height": 20, "art": true, "star_knob": false, "frac": 50},
```
6. `_make_element` — add a `"progress_bar"` case:
```gdscript
			"progress_bar":
				var po := Kit.progress_bar_opts_from_config({"progress_bar": p})
				var bar := Kit.progress_bar(float(p.frac) / 100.0, po)
				bar.custom_minimum_size.x = 320
				return bar
```
7. `_rebuild_sidebar` `match` — add a `"progress_bar"` arm:
```gdscript
			"progress_bar":
				_group_header("Saved to config", true)
				_sidebar_body.add_child(_slider_row(["height", 8, 48]))
				_sidebar_body.add_child(_toggle_row("Use art", "art"))
				_sidebar_body.add_child(_toggle_row("Star knob", "star_knob"))
				_group_header("Test only — not saved", false)
				_sidebar_body.add_child(_slider_row(["frac", 0, 100]))
```

- [ ] **Step 6: Seed the settings JSON.** Add a `"progress_bar"` block to
`games/grove/tools/ui_workbench_settings.json` (alongside the others) so the game has defaults:
```json
	"progress_bar": {
		"height": 20,
		"art": true,
		"star_knob": false
	},
```

- [ ] **Step 7: Re-run tests + smoke the workbench loads, then commit**

```bash
make test-one SUITE=games/grove/tests/grove_ui_tests 2>&1 | tail -5
godot --headless --editor --quit --path . 2>&1 | grep -i "ui_workbench" || echo "no workbench parse errors"
git add -A && git commit -m "Kit: add reusable progress_bar component + workbench item

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `level_medallion` kit component

**Files:**
- Modify: `games/grove/tools/ui_workbench_kit.gd`
- Test: `games/grove/tests/grove_ui_tests.gd`

- [ ] **Step 1: Write the failing test** (add `_test_level_medallion` + its call):

```gdscript
func _test_level_medallion() -> void:
	const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
	var med := Kit.level_medallion(7, 120.0, {})
	ok(med != null and med is Control, "level_medallion builds")
	ok(_find_label_text(med, "7"), "level_medallion shows the level number")
	med.free()
```

- [ ] **Step 2: Run it; verify it fails**

```bash
make test-one SUITE=games/grove/tests/grove_ui_tests 2>&1 | tail -8
```
Expected: FAIL — `Kit.level_medallion` undefined.

- [ ] **Step 3: Implement `level_medallion`.** Compose, back-to-front: the laurel wreath (behind,
larger), the gold ring (the medallion border) optionally over the badge disc inner face, and the
number centered. If Task 1 found `level_ring` already has a cream face, set `RING_HAS_FACE := true`
to skip the disc layer.

```gdscript
## The Level MEDALLION — the laurel wreath behind a gold ring with the level NUMBER centered. REUSES
## the badge disc (shell_texture) as the cream inner face UNLESS the ring sprite already carries one.
## px is the ring diameter; the wreath frames it a touch larger. opts: number_font, ink (Color).
static func level_medallion(level: int, px: float = 120.0, opts: Dictionary = {}) -> Control:
	const RING_HAS_FACE := false   # set true if intake found level_ring.png includes a cream inner disc
	var root := Control.new()
	var wreath_px := px * 1.55
	root.custom_minimum_size = Vector2(wreath_px, wreath_px)
	root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# wreath behind, centered
	var wreath := clean_tex_path(Look.kit("kit/level_wreath.png"), 512)
	if wreath != null:
		var wr := TextureRect.new()
		wr.texture = wreath
		wr.set_anchors_preset(Control.PRESET_FULL_RECT)
		wr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(wr)
	# the ring (+ optional badge-disc face) centered, at px
	var ring_wrap := CenterContainer.new()
	ring_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ring_wrap)
	var ring := Control.new()
	ring.custom_minimum_size = Vector2(px, px)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_wrap.add_child(ring)
	if not RING_HAS_FACE:
		var face := shell_texture(HOME_SHELL, {})   # reuse the badge disc as the cream inner face
		if face != null:
			var fr := TextureRect.new()
			fr.texture = face
			fr.set_anchors_preset(Control.PRESET_FULL_RECT)
			fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			fr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# inset the face so the ring border frames it
			fr.set_anchor_and_offset(SIDE_LEFT, 0.0, px * 0.12)
			fr.set_anchor_and_offset(SIDE_TOP, 0.0, px * 0.12)
			fr.set_anchor_and_offset(SIDE_RIGHT, 1.0, -px * 0.12)
			fr.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -px * 0.12)
			ring.add_child(fr)
	var ring_tex := clean_tex_path(Look.kit("kit/level_ring.png"), 512)
	if ring_tex != null:
		var rt := TextureRect.new()
		rt.texture = ring_tex
		rt.set_anchors_preset(Control.PRESET_FULL_RECT)
		rt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.add_child(rt)
	# the number, centered on the ring
	var num := Label.new()
	num.text = str(level)
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", int(opts.get("number_font", px * 0.42)))
	num.add_theme_color_override("font_color", opts.get("ink", Pal.INK))
	num.add_theme_constant_override("outline_size", 0)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(num)
	return root
```

- [ ] **Step 4: Run the test; verify it passes**

```bash
make test-one SUITE=games/grove/tests/grove_ui_tests 2>&1 | tail -6
```
Expected: `level_medallion builds` + `shows the level number` PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Kit: level_medallion — wreath + ring (reusing badge disc) + number

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `level_frame` + `level_dialog` kit components + config helper

**Files:**
- Modify: `games/grove/tools/ui_workbench_kit.gd`
- Test: `games/grove/tests/grove_ui_tests.gd`

- [ ] **Step 1: Write the failing test** (add `_test_level_dialog` + its call):

```gdscript
func _test_level_dialog() -> void:
	const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
	var info := {"level": 1, "earned": 0, "next": 6, "into": 0, "span": 6, "remaining": 6, "mode": "info"}
	var di := Kit.level_dialog(info, 460.0, {})
	ok(di != null and di is Control, "level_dialog builds in info mode")
	ok(_find_label_text(di, "Got it"), "info mode shows the Got it button")
	di.free()
	var up := {"level": 2, "earned": 6, "next": 18, "into": 0, "span": 12, "remaining": 12,
		"mode": "levelup", "gift": {"water": 30, "gems": 1}}
	var du := Kit.level_dialog(up, 460.0, {})
	ok(du != null, "level_dialog builds in levelup mode")
	ok(_find_label_text(du, "Collect"), "levelup mode shows the Collect button")
	du.free()
```

- [ ] **Step 2: Run it; verify it fails**

```bash
make test-one SUITE=games/grove/tests/grove_ui_tests 2>&1 | tail -8
```
Expected: FAIL — `Kit.level_dialog` undefined.

- [ ] **Step 3: Implement `level_frame`, `level_dialog`, and `level_opts_from_config`.** The frame is a
dedicated parchment card with the title-pill banner; the dialog stacks the medallion, tally, progress
bar, bottom line, optional reward row, and the button (reusing `pill_button` with the green bg).

```gdscript
## A dedicated FRAME for the Level dialog (NOT the shared dialog_frame): the level_frame parchment,
## the level_title pill banner overlaying the top, inner padding, NO scroll / NO ✕. `content` is laid
## out statically (the dialog is short). opts: banner_text, width, title_font, slices (l/t/r/b), pad.
static func level_frame(content: Control, width: float = 460.0, opts: Dictionary = {}) -> Control:
	var banner_text := String(opts.get("banner_text", "Level"))
	var title_font := int(opts.get("title_font", 30))
	var sl := float(opts.get("slice", 56.0))
	var pad := float(opts.get("pad", 26.0))
	var top_pad := float(opts.get("top_pad", 70.0))   # room under the title pill
	var card := PanelContainer.new()
	var fp := Look.kit("kit/level_frame.png")
	if ResourceLoader.exists(fp):
		var st := StyleBoxTexture.new()
		st.texture = load(fp)
		st.set_texture_margin(SIDE_LEFT, sl); st.set_texture_margin(SIDE_TOP, sl)
		st.set_texture_margin(SIDE_RIGHT, sl); st.set_texture_margin(SIDE_BOTTOM, sl)
		st.content_margin_left = pad; st.content_margin_right = pad
		st.content_margin_top = top_pad; st.content_margin_bottom = pad
		card.add_theme_stylebox_override("panel", st)
	else:
		var cf := StyleBoxFlat.new()
		cf.bg_color = Pal.CREAM; cf.border_color = Pal.BARK
		cf.set_corner_radius_all(28); cf.set_border_width_all(3)
		cf.content_margin_left = pad; cf.content_margin_right = pad
		cf.content_margin_top = top_pad; cf.content_margin_bottom = pad
		card.add_theme_stylebox_override("panel", cf)
	card.custom_minimum_size = Vector2(width, 0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(content)
	# the title pill, centered over the top edge
	var wrap := Control.new()
	wrap.custom_minimum_size.x = width
	wrap.add_child(card)
	var title := _level_title_pill(banner_text, title_font, width)
	wrap.add_child(title)
	var dock := func() -> void:
		if is_instance_valid(title) and is_instance_valid(card):
			title.position = Vector2((card.size.x - title.size.x) * 0.5, -title.size.y * 0.5)
			wrap.custom_minimum_size = card.size
	card.resized.connect(dock)
	title.resized.connect(dock)
	dock.call_deferred()
	return wrap

## The gold "Level N" title pill (the level_title sprite scaled whole with the text centered). Falls
## back to a code STRAW pill. Named so it reads as the banner.
static func _level_title_pill(text: String, font: int, width: float) -> Control:
	var pill := PanelContainer.new()
	pill.name = "LevelTitle"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tp := clean_tex_path(Look.kit("kit/level_title.png"), 480)
	if tp != null:
		var stx := StyleBoxTexture.new()
		stx.texture = tp
		stx.content_margin_left = 40; stx.content_margin_right = 40
		stx.content_margin_top = 10; stx.content_margin_bottom = 14
		pill.add_theme_stylebox_override("panel", stx)
	else:
		var ps := StyleBoxFlat.new()
		ps.bg_color = Pal.STRAW; ps.set_corner_radius_all(18)
		ps.content_margin_left = 28; ps.content_margin_right = 28
		ps.content_margin_top = 6; ps.content_margin_bottom = 8
		pill.add_theme_stylebox_override("panel", ps)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", Color("#4A2E14"))
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(l)
	return pill

## The whole LEVEL dialog: the dedicated frame + medallion + "X / Y ★ earned" + progress_bar + the
## "N more ★ to reach Level N+1" line + (levelup mode) a reward row + the bottom button. `data` keys:
## level, earned, next, into, span, remaining, mode ("info"|"levelup"), gift ({water,gems}), on_button
## (Callable). opts merges the saved frame/progress/button style (see level_opts_from_config).
static func level_dialog(data: Dictionary, width: float = 460.0, opts: Dictionary = {}) -> Control:
	var mode := String(data.get("mode", "info"))
	var lvl := int(data.get("level", 1))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(opts.get("gap", 14)))
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	# medallion
	var med := level_medallion(lvl, float(opts.get("medallion_px", 120.0)), opts)
	med.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(med)
	# tally "X / Y ★ earned"
	var tally := Label.new()
	tally.text = TranslationServer.translate("%d / %d ★ earned") % [int(data.get("earned", 0)), int(data.get("next", 0))]
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally.add_theme_font_size_override("font_size", int(opts.get("tally_font", 28)))
	tally.add_theme_color_override("font_color", Pal.INK)
	tally.add_theme_constant_override("outline_size", 0)
	col.add_child(tally)
	# progress bar
	var span: int = maxi(1, int(data.get("span", 1)))
	var frac: float = clampf(float(int(data.get("into", 0))) / float(span), 0.0, 1.0)
	var bar := progress_bar(frac, opts.get("progress", {}))
	bar.custom_minimum_size.x = width * 0.66
	col.add_child(bar)
	# levelup: the reward row (cream chips) — info: the "N more ★" line
	if mode == "levelup":
		var gift: Dictionary = data.get("gift", {})
		var reward := {"water": int(gift.get("water", 0)), "gems": int(gift.get("gems", 0))}
		if _reward_total(reward) > 0:
			var rrow := reward_chip(reward, opts.get("btn", {}))
			rrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(rrow)
	else:
		var nxt := Label.new()
		nxt.text = TranslationServer.translate("%d more ★ to reach Level %d") % [int(data.get("remaining", 0)), lvl + 1]
		nxt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nxt.add_theme_font_size_override("font_size", int(opts.get("hint_font", 22)))
		nxt.add_theme_color_override("font_color", Pal.BARK)
		nxt.add_theme_constant_override("outline_size", 0)
		col.add_child(nxt)
	# the bottom button (reuse pill_button + the green level_btn bg)
	var bo: Dictionary = (opts.get("btn", {}) as Dictionary).duplicate()
	bo["bg"] = "green"; bo["art"] = true; bo["art_rel"] = "kit/level_btn.png"
	bo["icon"] = ""
	var btn_text := TranslationServer.translate("Collect") if mode == "levelup" else TranslationServer.translate("Got it")
	var btn := pill_button(btn_text, bo)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cb: Callable = data.get("on_button", Callable())
	if cb.is_valid():
		btn.pressed.connect(func() -> void: cb.call())
	col.add_child(btn)
	return level_frame(col, width, opts)

## The Level dialog's saved STYLE opts from config — the dedicated frame + progress + button style.
## Used by BOTH the workbench preview and the game (level_popup.gd).
static func level_opts_from_config(cfg: Dictionary) -> Dictionary:
	var lv: Dictionary = cfg.get("level", {})
	return {
		"banner_text": String(lv.get("banner_text", "Level")),
		"title_font": int(lv.get("title_font", 30)),
		"slice": float(lv.get("frame_slice", 56)),
		"pad": float(lv.get("frame_pad", 26)),
		"top_pad": float(lv.get("frame_top_pad", 70)),
		"medallion_px": float(lv.get("medallion_px", 120)),
		"tally_font": int(lv.get("tally_font", 28)),
		"hint_font": int(lv.get("hint_font", 22)),
		"gap": int(lv.get("gap", 14)),
		"progress": progress_bar_opts_from_config(cfg),
		"btn": card_btn_opts(cfg),
	}
```

- [ ] **Step 4: Run the test; verify it passes**

```bash
make test-one SUITE=games/grove/tests/grove_ui_tests 2>&1 | tail -8
```
Expected: all four `level_dialog…` asserts PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Kit: level_frame + level_dialog (two modes) + level_opts_from_config

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: `level` workbench gallery item

**Files:**
- Modify: `games/grove/tools/ui_workbench_view.gd`
- Modify: `games/grove/tools/ui_workbench_settings.json`

- [ ] **Step 1: Add the item to `ui_workbench_view.gd`.** Edits:

1. `const IDS` — add `"level"`.
2. `const COLUMNS` — add `["level"]` to the dialog (second) column.
3. `const TEST_KEYS` — add `"level": ["preview_level", "into", "span", "mode"],`.
4. `const CAPTIONS` — add `"level": "Level — dialog (medallion · bar · collect)",`.
5. `_params` — add:
```gdscript
	"level": {"width_pct": 80, "banner_text": "Level", "title_font": 30,
		"frame_slice": 56, "frame_pad": 26, "frame_top_pad": 70,
		"medallion_px": 120, "tally_font": 28, "hint_font": 22, "gap": 14,
		"preview_level": 1, "into": 0, "span": 6, "mode": "info"},
```
6. `_make_element` — add a `"level"` case (build from the SAME config transform the game uses):
```gdscript
			"level":
				var lo := Kit.level_opts_from_config(_params_as_cfg())
				lo["banner_text"] = String(p.banner_text)
				var into: int = int(p.into)
				var span: int = maxi(1, int(p.span))
				var data := {
					"level": int(p.preview_level), "earned": into, "next": span,
					"into": into, "span": span, "remaining": maxi(0, span - into),
					"mode": String(p.mode), "gift": {"water": 30, "gems": 1},
				}
				return Kit.level_dialog(data, _dlg_px("level"), lo)
```
If a `_params_as_cfg()` helper does not already exist, add it near `_btn_opts`:
```gdscript
## The live `_params` reshaped as the saved-config dict the kit's *_from_config helpers expect.
func _params_as_cfg() -> Dictionary:
	return _params
```
(`_params` is already keyed `button`/`card`/`level`/`progress_bar`/… so it doubles as the cfg dict.)

7. `_dlg_px` already reads `width_pct` from `_params[id]` — `level` has `width_pct`, so it works as-is.
8. `_rebuild_sidebar` `match` — add a `"level"` arm:
```gdscript
			"level":
				_group_header("Saved to config", true)
				_sidebar_body.add_child(_slider_row(["width_pct", 40, 100]))
				_sidebar_body.add_child(_text_row("Banner text", "banner_text"))
				_sidebar_body.add_child(_slider_row(["title_font", 16, 48]))
				_sidebar_body.add_child(_slider_row(["medallion_px", 80, 180]))
				_sidebar_body.add_child(_slider_row(["tally_font", 16, 40]))
				_sidebar_body.add_child(_slider_row(["hint_font", 12, 32]))
				_sidebar_body.add_child(_slider_row(["frame_slice", 0, 160]))
				_sidebar_body.add_child(_slider_row(["frame_pad", 8, 60]))
				_sidebar_body.add_child(_slider_row(["frame_top_pad", 20, 140]))
				_sidebar_body.add_child(_slider_row(["gap", 4, 40]))
				_group_header("Test only — not saved", false)
				_sidebar_body.add_child(_option_row("Mode", "mode", ["info", "levelup"]))
				_sidebar_body.add_child(_slider_row(["preview_level", 1, 50]))
				_sidebar_body.add_child(_slider_row(["into", 0, 30]))
				_sidebar_body.add_child(_slider_row(["span", 1, 30]))
```

- [ ] **Step 2: Seed the settings JSON** with a `"level"` block:
```json
	"level": {
		"width_pct": 80,
		"banner_text": "Level",
		"title_font": 30,
		"frame_slice": 56,
		"frame_pad": 26,
		"frame_top_pad": 70,
		"medallion_px": 120,
		"tally_font": 28,
		"hint_font": 22,
		"gap": 14
	},
```

- [ ] **Step 3: Smoke the workbench parses + tests green, then commit**

```bash
godot --headless --editor --quit --path . 2>&1 | grep -iE "error|ui_workbench" | grep -v "no errors" || echo "workbench parses clean"
make test-fast 2>&1 | tail -3
git add -A && git commit -m "Workbench: add the Level dialog gallery item (info + levelup preview)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Defer the level-up gift out of `earn_stars`

**Files:**
- Modify: `engine/scripts/core/content.gd:586-600` (`earn_stars`) + add `level_gift` / `grant_level_gift`
- Test: `games/grove/tests/grove_economy_tests.gd` (update L255-267 and L545-550)

- [ ] **Step 1: Update the failing economy assertions.** In `grove_economy_tests.gd`, around L255-267,
replace the "earn_stars gifts water+gems" expectations with the deferred model. Set the scene the same
way (earn into L2), then assert the gift is NOT applied by `earn_stars`, and IS applied by
`grant_level_gift(level_gift(gained))`:

```gdscript
	# earn_stars advances level + the spendable balance, but NO LONGER grants the gift (deferred to Collect)
	var water0 := int(Save.grove().get("water", 0))
	var dia0 := Save.diamonds()
	var gained := G.earn_stars(2)              # 5 -> 7 crosses the L2 line (6)
	ok(gained == 1, "earn_stars returns the number of levels gained")
	ok(int(Save.grove().get("stars_earned", 0)) == 7 and Save.stars() == 7, \
		"earn_stars accrues BOTH the earned clock and the spendable balance")
	ok(int(Save.grove()["water"]) == water0 and Save.diamonds() == dia0, \
		"earn_stars does NOT grant the level-up gift (deferred to the dialog's Collect)")
	# the gift is computed + granted separately (what the Collect button does)
	var gift := G.level_gift(gained)
	ok(int(gift.get("water", 0)) == G.LEVEL_WATER_GIFT and int(gift.get("gems", 0)) == G.LEVEL_DIAMONDS, \
		"level_gift returns water+gems per level gained")
	G.grant_level_gift(gift)
	ok(int(Save.grove()["water"]) == water0 + G.LEVEL_WATER_GIFT and Save.diamonds() == dia0 + G.LEVEL_DIAMONDS, \
		"grant_level_gift applies the water+gems")
	ok(G.earn_stars(1) == 0, "earning within a level gains no level")
```
And around L545-550 (the skim-site test), drive the skim through the new grant path:

```gdscript
	var d0 := Save.diamonds()
	var vault0 := Vault.banked_units()
	var gained2 := G.earn_stars(1)                            # crosses into L2
	G.grant_level_gift(G.level_gift(gained2))                 # Collect grants + skims
	ok(Save.diamonds() == d0 + G.LEVEL_DIAMONDS, "a level-up pays diamonds on grant")
	var vault1 := Vault.banked_units()
	ok(vault1 - vault0 == G.LEVEL_DIAMONDS * Vault.skim_num(), "granting the gift SKIMS its premium into the piggy bank (§10)")
```
(If the existing code reads `Vault.banked_units()` differently — e.g. via a local `vault0`/`vault1` already
present — keep the existing variable wiring and only move the grant call.)

- [ ] **Step 2: Run economy tests; verify they fail**

```bash
make test-one SUITE=games/grove/tests/grove_economy_tests 2>&1 | tail -12
```
Expected: FAIL — `level_gift`/`grant_level_gift` undefined, and the old auto-grant assertions changed.

- [ ] **Step 3: Refactor `content.gd`.** Replace the gift block inside `earn_stars` with a no-grant
return, and add the two new functions right after:

```gdscript
static func earn_stars(n: int) -> int:
	Save.add_stars(n)
	var g := Save.grove()
	var earned := int(g.get("stars_earned", 0))
	var before := level_for_stars(earned)
	earned += n
	g["stars_earned"] = earned
	var gained := level_for_stars(earned) - before
	Save.grove_write()
	return gained                              # gift is granted separately (grant_level_gift), via the dialog Collect

# The water+diamond gift for `levels` levels gained (pure — no side effects). The Level dialog shows it.
static func level_gift(levels: int) -> Dictionary:
	var n := maxi(0, levels)
	return {"water": LEVEL_WATER_GIFT * n, "gems": LEVEL_DIAMONDS * n}

# Apply a level_gift: water (capped), diamonds, and the piggy-bank skim. Called by the dialog's Collect.
static func grant_level_gift(gift: Dictionary) -> void:
	var water := int(gift.get("water", 0))
	var gems := int(gift.get("gems", 0))
	if water <= 0 and gems <= 0:
		return
	var g := Save.grove()
	g["water"] = mini(WATER_CAP, int(g.get("water", WATER_CAP)) + water)
	Save.grove_write()
	if gems > 0:
		Save.add_diamonds(gems)
		Vault.skim(gems)                       # T44 SKIM-SITE 1/3 (level-up): the piggy bank skims the premium (§10)
```

- [ ] **Step 4: Run economy tests; verify they pass**

```bash
make test-one SUITE=games/grove/tests/grove_economy_tests 2>&1 | tail -8
```
Expected: PASS — the deferred-gift assertions hold.

- [ ] **Step 5: Run the full fast + grove sweep (catch any other earn_stars caller), then commit**

```bash
make test-fast 2>&1 | tail -3
make test-grove 2>&1 | tail -6
git add -A && git commit -m "Economy: defer the level-up gift out of earn_stars (level_gift / grant_level_gift)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Rebuild `level_popup.gd` on the kit (info + levelup modes)

**Files:**
- Rewrite: `engine/scripts/ui/level_popup.gd`
- Test: `games/grove/tests/grove_ui_tests.gd`

- [ ] **Step 1: Write the failing test** (add `_test_level_popup` + its call). It needs a host in-tree;
follow the suite's existing host pattern (a `Control` added to `get_root()`), then assert both entry
points build and Collect grants exactly once:

```gdscript
func _test_level_popup() -> void:
	const LevelPopup = preload("res://engine/scripts/ui/level_popup.gd")
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	# info mode
	var ov := LevelPopup.open(host)
	ok(ov != null and is_instance_valid(ov), "LevelPopup.open builds the info overlay")
	ok(_find_label_text(ov, "Got it"), "info overlay shows Got it")
	ov.free()
	# levelup mode grants the gift exactly once on Collect
	var dia0 := Save.diamonds()
	var ov2 := LevelPopup.open_levelup(host, 1)
	ok(ov2 != null and _find_label_text(ov2, "Collect"), "levelup overlay shows Collect")
	var btn := _find_button_text(ov2, "Collect")
	ok(btn != null, "found the Collect button")
	if btn != null:
		btn.emit_signal("pressed")
	ok(Save.diamonds() == dia0 + G.LEVEL_DIAMONDS, "Collect grants the diamond gift once")
	host.free()
```
Add `_find_button_text` to `grove_test_base.gd` if absent:

```gdscript
# Recursively find the first Button whose text contains `needle` (or null).
func _find_button_text(node: Node, needle: String) -> Button:
	if node is Button and String((node as Button).text).find(needle) != -1:
		return node as Button
	for c in node.get_children():
		var f := _find_button_text(c, needle)
		if f != null:
			return f
	return null
```

- [ ] **Step 2: Run it; verify it fails**

```bash
make test-one SUITE=games/grove/tests/grove_ui_tests 2>&1 | tail -10
```
Expected: FAIL — `open_levelup` undefined / overlay built the old (non-kit) way.

- [ ] **Step 3: Rewrite `engine/scripts/ui/level_popup.gd`** to render via the kit with two modes. The
shared overlay/veil scaffolding stays; the card body is `Kit.level_dialog`. info is veil-dismissable;
levelup is NOT (only Collect closes, after granting):

```gdscript
extends RefCounted
## Level dialog — the kit-built parchment dialog (ref lvl.png). Two modes:
##   LevelPopup.open(host)              — INFO: tap-to-view (HUD level badge / locked cell). "Got it".
##   LevelPopup.open_levelup(host, n)   — LEVELUP: auto on a level gain. Shows the earned gift; the
##                                        "Collect" button GRANTS it (grant_level_gift) then closes.
## Self-contained; builds into `host`. Info dismisses on a veil tap or Got it; levelup ONLY via Collect
## (so the reward can't be lost).

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Pal = Game.PALETTE
const CFG := "res://games/grove/tools/ui_workbench_settings.json"
const OVERLAY_NAME = "LevelPopupOverlay"

static func open(host: Control) -> Control:
	return _build(host, "info", 0)

static func open_levelup(host: Control, levels_up: int) -> Control:
	return _build(host, "levelup", maxi(1, levels_up))

static func _build(host: Control, mode: String, levels_up: int) -> Control:
	# Idempotent: one popup per host (emulate_touch fires the trigger twice in a frame).
	var live := host.get_node_or_null(NodePath(OVERLAY_NAME))
	if live is Control and not (live as Node).is_queued_for_deletion():
		return live as Control

	var earned := int(Save.grove().get("stars_earned", 0))
	var lvl := G.level_for_stars(earned)
	var base := G.stars_at_level(lvl)
	var nxt := G.stars_at_level(lvl + 1)
	var into := clampi(earned - base, 0, nxt - base)
	var span := maxi(1, nxt - base)
	var remaining := maxi(0, nxt - earned)

	var overlay := Control.new()
	overlay.name = OVERLAY_NAME
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(Pal.INK, 0.5)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	if mode == "info":
		veil.gui_input.connect(func(ev: InputEvent) -> void:
			if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
				overlay.queue_free())

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	var cfg := Kit.load_config(CFG)
	var opts := Kit.level_opts_from_config(cfg)
	opts["banner_text"] = TranslationServer.translate("Level %d") % lvl
	var width := Game.SCREEN_W * float((cfg.get("level", {}) as Dictionary).get("width_pct", 80)) / 100.0 \
		if "SCREEN_W" in Game else 460.0

	var gift := G.level_gift(levels_up) if mode == "levelup" else {}
	var data := {
		"level": lvl, "earned": earned, "next": nxt, "into": into, "span": span,
		"remaining": remaining, "mode": mode, "gift": gift,
		"on_button": func() -> void:
			if mode == "levelup":
				G.grant_level_gift(gift)
			overlay.queue_free(),
	}
	var dialog := Kit.level_dialog(data, width, opts)
	cc.add_child(dialog)
	FX.pop_in(dialog)
	return overlay
```
Note: confirm the screen-width source the other dialogs use (e.g. `inbox.gd` reads the live viewport
width). Match that exact expression instead of the `Game.SCREEN_W` guess above — grep
`engine/scripts/ui/inbox.gd` for how it computes dialog width and mirror it.

- [ ] **Step 4: Run the test; verify it passes**

```bash
make test-one SUITE=games/grove/tests/grove_ui_tests 2>&1 | tail -10
```
Expected: PASS — both overlays build; Collect grants exactly once.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Level popup: rebuild on the kit; info + levelup (Collect) modes

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: Wire `board.gd` level-up to open the dialog

**Files:**
- Modify: `engine/scripts/scenes/board.gd:1887-1897` (the `if levels_up > 0:` block in `_on_giver_tap`)

- [ ] **Step 1: Replace the floater block.** Swap the `FX.celebrate_at` / `FX.floating_reward` ×2 /
`Audio.play("level_complete")` block for opening the dialog. Keep `_refresh_locked_cells()`; the
water/HUD re-sync moves into the Collect callback path. Find the existing block:

```gdscript
	if levels_up > 0:
		water = int(Save.grove().get("water", water))   # re-sync the local after the level-up gift
		_update_water_hud()
		_refresh_locked_cells()   # a level-up may make deeper frontier cells unlockable now
		var lv := G.level_for_stars(int(Save.grove().get("stars_earned", 0)))
		FX.celebrate_at(self, Vector2(get_global_rect().get_center().x, 240), tr("Level %d!") % lv, STRAW)
		FX.floating_reward(self, Vector2(get_global_rect().get_center().x - 130, 320),
			"water", G.LEVEL_WATER_GIFT * levels_up, Color("#9CCDE8"), 36)
		FX.floating_reward(self, Vector2(get_global_rect().get_center().x + 40, 320),
			"gem", G.LEVEL_DIAMONDS * levels_up, Color("#BFE6F2"), 36)
		Audio.play("level_complete", -1.0)
```
Replace it with (the dialog now owns the celebration + the reward grant; sync after Collect via a
deferred refresh — the overlay frees on Collect, so poll-free we re-sync on its tree_exited):

```gdscript
	if levels_up > 0:
		_refresh_locked_cells()   # a level-up may make deeper frontier cells unlockable now
		Audio.play("level_complete", -1.0)
		var lvlup_ov := LevelPopup.open_levelup(self, levels_up)
		if lvlup_ov != null:
			lvlup_ov.tree_exited.connect(func() -> void:
				if not is_instance_valid(self):
					return
				water = int(Save.grove().get("water", water))   # re-sync after Collect granted the gift
				_update_water_hud()
				_update_hud())
```
Verify `LevelPopup` is preloaded at the top of `board.gd` (grep `const LevelPopup`). If absent, add:
```gdscript
const LevelPopup = preload("res://engine/scripts/ui/level_popup.gd")
```

- [ ] **Step 2: Tests green (board instantiates in grove suites)**

```bash
make test-fast 2>&1 | tail -3
make test-grove 2>&1 | tail -6
```
Expected: all PASS.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "Board: level-up opens the Level dialog (Collect grants the gift)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 9: Full sweep + visual verification

**Files:** none (verification only)

- [ ] **Step 1: Full test sweep**

```bash
make test 2>&1 | tail -12
```
Expected: ALL SUITES PASSED.

- [ ] **Step 2: Capture the Level dialog from the workbench.** The workbench preview is the fastest way
to render the dialog at real resolution. Use the quiet-godot capture against the workbench scene (per
the project's screenshot rule — minimized, no focus steal). If a workbench capture helper does not
exist, capture via `make shot` of a tiny harness that opens `LevelPopup.open(host)` on the board, e.g.:

```bash
make shot-grove MODE=hud OUT=/tmp/board.png 2>&1 | tail -3
```
Then a dedicated capture: add a transient `override.cfg` (window minimized + no_focus, per CLAUDE.md),
run `godot --path . -s <a small script that builds Kit.level_dialog info+levelup and saves a PNG>`,
remove `override.cfg` after (trap EXIT). Save info mode to `/tmp/level_info.png` and levelup to
`/tmp/level_up.png`.

- [ ] **Step 3: Deliver the captures to the user** (do NOT self-judge the thumbnail — send the files):

Use SendUserFile with `/tmp/level_info.png` and `/tmp/level_up.png`, captioned "info vs level-up mode —
compare against lvl.png". Ask for sign-off on the look (medallion framing, title pill, bar, button).

- [ ] **Step 4: Finalize.** Once the look is approved, the branch is ready to merge back to `main`
(use the finishing-a-development-branch skill). Tests green + visual approved = done.

---

## Self-review notes

- **Spec coverage:** assets (T1), progress_bar component+workbench (T2), medallion (T3), frame+dialog (T4),
  level workbench item (T5), economy defer-to-Collect (T6), two-mode popup (T7), board wiring (T8),
  test+visual (T9). Home-screen unlock % is explicitly out of scope per the spec — `progress_bar` ships
  label-ready (T2) but is not wired.
- **Known build-time unknowns (resolve in-task, not placeholders):** exact island indices + whether
  `level_ring` carries a cream face (T1 → flips `RING_HAS_FACE` in T3); the precise responsive-width
  expression the other dialogs use (T7 Step 3 mirrors `inbox.gd`); the grove suites' host-in-tree idiom
  (T7 Step 1 follows the suite's existing pattern). Each names exactly what to check and where.
- **Type consistency:** `level_gift`/`grant_level_gift` (T6) match their uses in T7/economy tests;
  `level_dialog` data keys (level/earned/next/into/span/remaining/mode/gift/on_button) are identical in
  T4 (def), T5 (workbench), and T7 (game). `progress_bar(frac, opts)` signature identical across T2/T4.
