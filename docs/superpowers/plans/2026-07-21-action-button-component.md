# Action Button Component Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the baked `nav_<x>.png` nav tiles with one shared, code-drawn rugged-edge action button — a `CutPaperPanel` surface + a centered icon glyph — driven by a single workbench component, used by both the home bottom bar and the board's Home/Bag wells.

**Architecture:** A new `Kit.action_button(role, size, action, opts)` static draws the rugged edge in code (reusing `engine/scripts/ui/cut_paper.gd`, exactly as `_apply_deckle_button_surface` already does) and composites a transparent icon glyph on top. A new workbench component `action_button` (replacing the `home_button` component) owns the shared cut-paper edge config + a per-button paper-role tint palette, and previews every tile through the same builder the game uses. `map.gd` and `board.gd` swap their `SpriteButton.build(load(nav_<x>.png), …)` calls for `Kit.action_button(…)`. A fresh transparent icon glyph set is generated in one batch.

**Tech Stack:** Godot 4.6 (GDScript), headless SceneTree test suites, `make test` runner, the `generating-images-with-codex` skill for art, the art-style-guide intake pipeline.

## Global Constraints

- **Worktree:** all work happens in `/Users/xup/dh/merge-worktrees/action-button` (branch `feat/action-button-component`). Main-tree edits are blocked by a hook.
- **Test after every change:** `make test-fast` (engine suites, seconds). Full `make test` (adds grove suites) before hand-off. The runner fails on any FAIL/crash — never trust exit code alone.
- **Never open a focused window in tests:** headless SceneTree scripts only (`godot --headless … -s res://…`). Visual captures go through `make shot-workbench` / `quiet_godot.sh` (never a foreground `godot -s`, which times out at 2min).
- **Art canvas contract (art-style-guide §5):** UI icon master = `512²` transparent PNG, flat front-on glyph, interior gaps cut through; runtime glyph = `256²` via the bake/clean path. Read `docs/design/art-style-guide.md` before generating or processing any asset.
- **Archive, never delete raws/retired art.**
- **Commit message trailer:** end every commit with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **The `home_button` FUNCTION stays.** Only the workbench `home_button` COMPONENT is removed. `Kit.home_button` is still the fallback in `map.gd`/`board.gd` and is used elsewhere.

---

## File Structure

- **Create** `games/grove/assets/ui/nav/glyphs/glyph_<id>.png` (×8) — transparent icon glyphs (map, residents, daily, vault, mail, play, home, bag).
- **Modify** `games/grove/tools/ui_workbench_kit.gd` — add `action_button` builder, `action_button_opts_from_config`, `ACTION_BUTTON_CP_DEFAULTS`, `ACTION_GLYPHS`, `ACTION_ROLES` constants.
- **Modify** `games/grove/tools/ui_workbench_view.gd` — register the `action_button` component; remove the `home_button` component.
- **Modify** `engine/scripts/scenes/map.gd` — `_build_bottom_bar` builds tiles via `Kit.action_button`.
- **Modify** `engine/scripts/scenes/board.gd` — Home + Bag wells build via `Kit.action_button`.
- **Create** `engine/tests/action_button_tests.gd` — headless unit suite for the builder + config round-trip.
- **Modify** `engine/tests/… list in Makefile` — register the new suite in `ENGINE_TESTS`.
- **Modify** `games/grove/tests/grove_explore_tests.gd` — update the bottom-bar tile assertions.
- **Archive** `games/grove/assets/ui/nav/nav_map.png`, `nav_residents.png`, `nav_daily.png`, `nav_vault.png`, `nav_mail.png`, `nav_board.png`, `nav_home.png`, `nav_bag.png` (retired baked tiles).

---

## Task 1: Generate the icon glyph set

**Files:**
- Create: `games/grove/assets/_new/action_button_glyphs_v1/` (raw drop + `plan.json`)
- Create (via intake): `games/grove/assets/ui/nav/glyphs/glyph_map.png`, `glyph_residents.png`, `glyph_daily.png`, `glyph_vault.png`, `glyph_mail.png`, `glyph_play.png`, `glyph_home.png`, `glyph_bag.png`

**Interfaces:**
- Produces: 8 transparent `256²` runtime glyph PNGs (from `512²` masters) at `res://games/grove/assets/ui/nav/glyphs/glyph_<id>.png`, resolvable via `Game.art("ui/nav/glyphs/glyph_<id>.png")`. Consumed by Task 2's builder (`ACTION_GLYPHS`).

- [ ] **Step 1: Read the art authorities**

Read `docs/design/art-style-guide.md` in full (palette, material, canvas §5, the UI-icon prompt scaffold §10d, the intake workflow §9). The existing baked tiles (`games/grove/assets/ui/nav/nav_*.png`) and the `cutpaper_storybook_ui_v1` concept screens are the visual reference for the cozy cut-paper direction. The glyphs must be **edge-free** (no deckle, no paper backing — the button draws that in code), transparent, flat front-on.

- [ ] **Step 2: Generate the 8 masters in one batch**

Invoke the `generating-images-with-codex` skill. Generate all 8 glyphs in a single batch/session so they share lighting, line weight, palette, and scale (the whole point of "generate at once"). Per glyph use the §10d scaffold, e.g. for map:

```
A folded paper map with a location pin, a single game UI icon, centered, chunky
readable silhouette, flat front-on glyph — no horizon, no scene, no perspective;
interior gaps fully cut through (transparent), not filled; on a flat #FF00FF
background. Output 512x512, no text or numerals.
```

Subjects: **map** = folded map + pin · **residents** = cozy house · **daily** = calendar/gift day · **vault** = piggy bank · **mail** = envelope · **play** = merge board / play arrow · **home** = house door · **bag** = satchel. Keep every glyph's visual weight consistent (same silhouette footprint on the 512² canvas).

- [ ] **Step 3: Author the intake plan**

Drop the raws in `games/grove/assets/_new/action_button_glyphs_v1/` and write `action_button_glyphs_v1.plan.json` next to them, classifying each as `icon`, targeting `ui/nav/glyphs/glyph_<id>.png` with `post: "icon:512"` (trim/center to a square master), per art-style-guide §9. Example island entry:

```json
{ "island": 1, "name": "glyph_map", "path": "ui/nav/glyphs/glyph_map.png", "post": "icon:512" }
```

- [ ] **Step 4: Run intake + import + bake**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
make intake PLAN=games/grove/assets/_new/action_button_glyphs_v1/action_button_glyphs_v1.plan.json
make import
make bake-textures
```
Expected: 8 outputs written to `ui/nav/glyphs/`, raws moved to `archive`, plan moved to `_new/_processed/`.

- [ ] **Step 5: Verify the glyphs load + are transparent, edge-free, consistent**

Verify each file exists and is a transparent square with no opaque edge rows (art-style-guide containment rule):

```bash
cd /Users/xup/dh/merge-worktrees/action-button
ls games/grove/assets/ui/nav/glyphs/
python3 -c "from PIL import Image; import glob
for f in sorted(glob.glob('games/grove/assets/ui/nav/glyphs/glyph_*.png')):
    im=Image.open(f).convert('RGBA'); a=im.getchannel('A')
    print(f, im.size, 'edge_opaque=', any(a.getpixel((x,0))>16 or a.getpixel((x,im.size[1]-1))>16 for x in range(im.size[0])))"
```
Expected: 8 files, each square, `edge_opaque= False`. **Look at the rendered glyphs** (do not eyeball a thumbnail — compose them into a strip and view) to confirm they read as one family. If any drifts, regenerate that one glyph and re-run intake for it.

- [ ] **Step 6: Commit**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
git add games/grove/assets/ui/nav/glyphs games/grove/assets/_new/_processed baked
git commit -m "art: cohesive transparent nav glyph set (map/residents/daily/vault/mail/play/home/bag)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `Kit.action_button` builder + config reader

**Files:**
- Modify: `games/grove/tools/ui_workbench_kit.gd` (add constants near `PAPER_SURFACES`/`BUTTON_CP_DEFAULTS`; add builder near `_apply_deckle_button_surface`; add reader near `cut_paper_opts_from_config`)
- Create: `engine/tests/action_button_tests.gd`
- Modify: `Makefile` (register the suite)

**Interfaces:**
- Consumes: `Game.art`, `clean_tex_path`, `_icon_rect`, `_meadow_shadow_rect`, `cut_paper_tile`, `cut_paper_opts_from_config`, `load_config`, `CONFIG_PATH`, `PAPER_SURFACES`, `CUT_PAPER` (const path), `Look.SHADOW_CORNER_META`, `Look.shape_corner`, `Look.shadow_params`, `Look.add_press_juice` — all already in this file/`skin.gd`. The glyph PNGs from Task 1.
- Produces:
  - `const ACTION_ROLES := ["map","residents","daily","vault","mail","play","home","bag"]`
  - `const ACTION_GLYPHS := {role: "ui/nav/glyphs/glyph_<id>.png", …}`
  - `const ACTION_BUTTON_CP_DEFAULTS := {"deckle": true, "corner": 20, "deckle_amp": 5, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true}`
  - `static func action_button(role: String, size: Vector2, action: Callable, opts: Dictionary = {}) -> Button`
  - `static func action_button_opts_from_config(cfg: Dictionary) -> Dictionary` returning `{"cp": Dictionary, "tints": Dictionary, "icon_scale": float, "shadow": bool, "shadow_params": Dictionary}`

- [ ] **Step 1: Write the failing test**

Create `engine/tests/action_button_tests.gd`:

```gdscript
extends SceneTree
## Headless unit tests for the shared code-drawn action button (Kit.action_button) and its config
## reader. The button draws the rugged cut-paper edge in code (a CutPaperPanel surface) + a centered
## glyph — one source for the home bottom bar and the board Home/Bag wells.
##   godot --headless --path . -s res://engine/tests/action_button_tests.gd

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _initialize() -> void:
	var root := get_root()

	# 1) the builder returns a Button carrying the code-drawn deckle surface (a CutPaperPanel), NOT a baked sprite
	var opts := {
		"cp": {"deckle": true, "corner": 20.0, "deckle_amp": 5.0, "deckle_freq": 0.05, "rim_width": 2.0, "edge_shadow": true},
		"tints": {"map": "sky"},
		"icon_scale": 0.5,
	}
	var b := Kit.action_button("map", Vector2(120, 120), Callable(), opts)
	root.add_child(b)
	ok(b is Button, "action_button returns a Button")
	var surface := b.find_child("ActionButtonDeckleSurface", true, false)
	ok(surface != null, "the button wears a code-drawn CutPaperPanel surface")
	ok(surface != null and surface.get_script() == load(Kit.CUT_PAPER),
		"the surface is the shared cut_paper.gd panel")

	# 2) the per-button tint resolves the sky paper-role fill onto the panel
	ok(surface != null and surface.paper_color.is_equal_approx(Kit.PAPER_SURFACES["sky"]["fill"]),
		"the map tile fills with its sky paper-role tint")

	# 3) the glyph sits centered on top (a TextureRect wearing the map glyph)
	var rects: Array = b.find_children("*", "TextureRect", true, false)
	var wears_glyph := rects.any(func(tr: TextureRect) -> bool:
		return tr.texture != null and String(tr.texture.resource_path).findn("glyph_map") != -1)
	ok(wears_glyph, "the map tile composites its transparent glyph in the middle")

	# 4) config reader round-trips the cut-paper edge knobs + the tint palette
	var cfg := {"action_button": {"deckle": true, "corner": 24, "deckle_amp": 6, "deckle_freq": 5,
		"rim_width": 3, "edge_shadow": true, "icon_scale": 55,
		"tint_map": "sky", "tint_home": "cream"}}
	var ro := Kit.action_button_opts_from_config(cfg)
	ok(float(ro["cp"]["corner"]) == 24.0, "reader round-trips the edge corner")
	ok(is_equal_approx(float(ro["cp"]["deckle_freq"]), 0.05), "reader normalizes deckle_freq (5 → 0.05)")
	ok(String(ro["tints"].get("map", "")) == "sky", "reader round-trips the per-button tint palette")
	ok(is_equal_approx(float(ro["icon_scale"]), 0.55), "reader normalizes icon_scale (55 → 0.55)")

	print("\n  action_button: %d passed, %d failed" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
```

- [ ] **Step 2: Register the suite + run it to verify it fails**

In `Makefile` line 11, append ` engine/tests/action_button_tests` to `ENGINE_TESTS`.

Run:
```bash
cd /Users/xup/dh/merge-worktrees/action-button
make test-one SUITE=engine/tests/action_button_tests
```
Expected: FAIL/parse error — `action_button` / `action_button_opts_from_config` / the `ACTION_*` constants don't exist yet.

- [ ] **Step 3: Add the constants**

In `ui_workbench_kit.gd`, immediately after the `PAPER_SURFACES` block (ends line 51), add:

```gdscript
# The core NAV/action set — one shared code-drawn rugged-edge button per role. The glyph is the only
# differentiator between tiles (the edge + paper role are shared config). Roles map to the transparent,
# edge-free glyph sprites generated as one family (no baked deckle — the button draws that in code).
const ACTION_ROLES := ["map", "residents", "daily", "vault", "mail", "play", "home", "bag"]
const ACTION_GLYPHS := {
	"map": "ui/nav/glyphs/glyph_map.png",
	"residents": "ui/nav/glyphs/glyph_residents.png",
	"daily": "ui/nav/glyphs/glyph_daily.png",
	"vault": "ui/nav/glyphs/glyph_vault.png",
	"mail": "ui/nav/glyphs/glyph_mail.png",
	"play": "ui/nav/glyphs/glyph_play.png",
	"home": "ui/nav/glyphs/glyph_home.png",
	"bag": "ui/nav/glyphs/glyph_bag.png",
}
# Calm default paper role per button (flatten — no warm accent for Play; the glyph carries the identity).
# The workbench palette overrides any of these; the live game reads the saved palette.
const ACTION_TINT_DEFAULTS := {
	"map": "cream", "residents": "cream", "daily": "cream", "vault": "cream",
	"mail": "cream", "play": "cream", "home": "cream", "bag": "cream",
}
# The shared cut-paper edge defaults for the action button (same knob SET as button/frame; own corner).
const ACTION_BUTTON_CP_DEFAULTS := {"deckle": true, "corner": 20, "deckle_amp": 5, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true}
```

- [ ] **Step 4: Add the builder**

In `ui_workbench_kit.gd`, immediately after `_apply_deckle_button_surface` (ends line 286), add:

```gdscript
## The shared ACTION BUTTON: a flat Button wearing the code-drawn rugged cut-paper edge (a CutPaperPanel,
## the SAME applier the pill/frame/rows use) filled by its per-button paper-role tint, with a centered
## transparent glyph on top. ONE source for the home bottom bar and the board Home/Bag wells — the baked
## nav_<x>.png tiles are retired. `opts`: cp (cut-paper opts) · tints (role→paper-role map) · icon_scale ·
## shadow · shadow_params · fill (explicit override) · glyph_rel (explicit override) · name · tooltip.
static func action_button(role: String, size: Vector2, action: Callable, opts: Dictionary = {}) -> Button:
	var b := Button.new()
	b.name = String(opts.get("name", "ActionButton_" + role))
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.size = size
	if String(opts.get("tooltip", "")) != "":
		b.tooltip_text = String(opts["tooltip"])
	if action.is_valid():
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pressed.connect(action)
	else:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# transparent styleboxes: the deckle panel behind is the visible face (identical to the pill/row path)
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	clear.draw_center = false
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, clear)
	# resolve the per-button fill from its paper role (explicit `fill` wins)
	var tints: Dictionary = opts.get("tints", ACTION_TINT_DEFAULTS)
	var paper_role := String(tints.get(role, "cream"))
	var surface: Dictionary = PAPER_SURFACES.get(paper_role, PAPER_SURFACES["cream"])
	var fill: Color = opts.get("fill", surface.get("fill", Color("#F6EBDD")))
	var cp: Dictionary = opts.get("cp", cut_paper_opts_from_config(load_config(CONFIG_PATH), "action_button", ACTION_BUTTON_CP_DEFAULTS))
	var corner := float(cp.get("corner", 20.0))
	b.set_meta(Look.SHADOW_CORNER_META, corner)
	# the SHARED drop shadow behind the tile (on when asked)
	if bool(opts.get("shadow", false)):
		var sh: Panel = _meadow_shadow_rect(Look.shape_corner(b, corner), opts.get("shadow_params", {}))
		sh.show_behind_parent = true
		b.add_child(sh)
	# the code-drawn rugged edge — the ONE shared applier
	var panel: Control = load(CUT_PAPER).new()
	panel.name = "ActionButtonDeckleSurface"
	panel.show_behind_parent = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.configure(cp, fill, null, cut_paper_tile())
	panel.corner = corner
	b.add_child(panel)
	# the centered glyph (mouse-transparent, globally polished) — only if its sprite exists
	var glyph_rel := String(opts.get("glyph_rel", ACTION_GLYPHS.get(role, "")))
	if glyph_rel != "" and ResourceLoader.exists(Game.art(glyph_rel)):
		var icwrap := CenterContainer.new()
		icwrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icwrap.add_child(_icon_rect(clean_tex_path(Game.art(glyph_rel), 192), size.y * float(opts.get("icon_scale", 0.5))))
		b.add_child(icwrap)
	# press feedback: darken the paper while held, restore on release (matches _apply_deckle_button_surface)
	b.button_down.connect(func() -> void:
		if is_instance_valid(panel):
			panel.paper_color = fill.darkened(0.08)
			panel.queue_redraw())
	b.button_up.connect(func() -> void:
		if is_instance_valid(panel):
			panel.paper_color = fill
			panel.queue_redraw())
	Look.add_press_juice(b)
	return b
```

- [ ] **Step 5: Add the config reader**

In `ui_workbench_kit.gd`, immediately after `cut_paper_opts_from_config` (ends line 2029), add:

```gdscript
## Read the `action_button` config block into the opts the shared builder consumes: the cut-paper edge
## opts (shared parser), the per-button paper-role tint palette (tint_<role> keys), the icon scale, and
## the shared shadow. The home bar + board wells both build from this — one source, no drift.
static func action_button_opts_from_config(cfg: Dictionary) -> Dictionary:
	var d: Dictionary = cfg.get("action_button", {}) if cfg is Dictionary else {}
	var tints := {}
	for role in ACTION_ROLES:
		tints[role] = String(d.get("tint_" + role, ACTION_TINT_DEFAULTS.get(role, "cream")))
	return {
		"cp": cut_paper_opts_from_config(cfg, "action_button", ACTION_BUTTON_CP_DEFAULTS),
		"tints": tints,
		"icon_scale": clampf(float(d.get("icon_scale", 50)) / 100.0, 0.10, 1.0),
		"shadow": bool(d.get("shadow", true)),
		"shadow_params": Look.shadow_params(cfg),
	}
```

- [ ] **Step 6: Run the suite to verify it passes**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
make test-one SUITE=engine/tests/action_button_tests
```
Expected: `action_button: 9 passed, 0 failed`, exit 0.

- [ ] **Step 7: Run the fast sweep**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
make test-fast
```
Expected: ALL SUITES PASSED (now includes `action_button_tests`).

- [ ] **Step 8: Commit**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
git add games/grove/tools/ui_workbench_kit.gd engine/tests/action_button_tests.gd Makefile
git commit -m "feat(kit): shared code-drawn action_button (rugged edge + centered glyph) + config reader

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Workbench `action_button` component (replace `home_button`)

**Files:**
- Modify: `games/grove/tools/ui_workbench_view.gd` (register `action_button`, remove `home_button` component)

**Interfaces:**
- Consumes: `Kit.action_button`, `Kit.action_button_opts_from_config`, `Kit.ACTION_ROLES`, `Kit.PAPER_SURFACES`, `Kit.CUT_PAPER_KNOBS`, the `_cut_paper_section` sidebar helper, `_slider_row`/`_option_row` helpers.
- Produces: a new gallery component `action_button` with a saved config block; the `home_button` component (id, column entry, caption, defaults, test-keys, dependents, sidebar case, preview builder `_home_bar_preview`, `HOME_BAR_TILES`) removed.

- [ ] **Step 1: Add a headless assertion for the component swap (failing)**

Append to `engine/tests/action_button_tests.gd` inside `_initialize()` before the summary `print`:

```gdscript
	# 5) the workbench registers the action_button component and drops the old home_button component
	var View := load("res://games/grove/tools/ui_workbench_view.gd")
	ok(View.IDS.has("action_button"), "the workbench registers the action_button component")
	ok(not View.IDS.has("home_button"), "the workbench no longer registers the home_button component")
	ok(View.DEFAULTS().has("action_button"), "action_button ships a saved config block")
	ok(not View.DEFAULTS().has("home_button"), "the home_button config block is gone")
```

Note: if `DEFAULTS` is a `const` dict rather than a `func`, replace `View.DEFAULTS()` with `View.DEFAULTS` and `View.IDS` access accordingly. Check the actual declaration in `ui_workbench_view.gd` (search `func _defaults` / `const DEFAULTS` / how `_params` is seeded) and match it. Run to confirm it FAILS:
```bash
cd /Users/xup/dh/merge-worktrees/action-button
make test-one SUITE=engine/tests/action_button_tests
```
Expected: FAIL on the new assertions (`home_button` still present, `action_button` absent).

- [ ] **Step 2: Register `action_button` in the keyed structures**

In `ui_workbench_view.gd`:

- `IDS` (line 27): replace `"home_button"` with `"action_button"`.
- `COLUMNS` (line 35): replace `["home_button"]` with `["action_button"]`.
- `DEPENDENTS` (line 53): replace the `"home_button": ["info_bar"]` entry with `"action_button": ["info_bar"]` (keep the `"hud_layout": ["info_bar"]` line).
- `TEST_KEYS` (line 82): replace `"home_button": ["icon", "caption", "sparkle", "badge_count", "count"]` with `"action_button": ["preview_role"]` (a preview-only selector for which single tile to spotlight; the full row is always shown).
- `CAPTIONS` (line 122): replace the `home_button` caption with:
  `"action_button": "Action buttons — the shared rugged-edge nav tiles (map · residents · daily · vault · mail · play · home · bag) as map.gd + board.gd build them",`
- `SHADOW_WIRED` (line 866): replace the `"home_button": true` key with `"action_button": true`.
- `on_by_default` (line 357): replace `"home_button": true` with `"action_button": true`.

- [ ] **Step 3: Add the `action_button` config-block default**

In the `DEFAULTS` block (near line 218 where `"home_button": {…}` lives), **remove** the `"home_button": {…}` block and add:

```gdscript
		# the ACTION BUTTON — the shared rugged-edge nav tile. px / icon_scale / shadow + the shared
		# cut-paper edge knobs (CUT_PAPER_KNOBS) are the saved style; tint_<role> is the per-button paper
		# role (flattened to calm roles by default). map.gd + board.gd read this via action_button_opts_from_config.
		"action_button": {"px": 158, "icon_scale": 50, "shadow": true,
			# the SHARED cut-paper edge knob set — same keys as button + frame.
			"deckle": true, "corner": 20, "deckle_amp": 5, "deckle_freq": 5, "rim_width": 2, "edge_shadow": true,
			# per-button paper-role tint palette (calm/flattened defaults)
			"tint_map": "cream", "tint_residents": "cream", "tint_daily": "cream", "tint_vault": "cream",
			"tint_mail": "cream", "tint_play": "cream", "tint_home": "cream", "tint_bag": "cream",
			"preview_role": "map"},
```

- [ ] **Step 4: Replace the preview builder**

Remove `HOME_BAR_TILES` (line 602) and `_home_bar_preview` (line 610). In `_make_element` (line 448), replace the `"home_button": return _home_bar_preview(p)` case with `"action_button": return _action_bar_preview(p)`. Add the new preview builder (place where `_home_bar_preview` was):

```gdscript
# The shared ACTION BUTTONS, built through the EXACT Kit.action_button the game uses, so the preview and
# the live home bar / board wells render off one source. A horizontal row of every role, each wearing its
# glyph + per-button paper-role tint + the shared rugged edge.
func _action_bar_preview(p: Dictionary) -> Control:
	var opts := Kit.action_button_opts_from_config({"action_button": p})
	var tile := float(p.get("px", 158))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for role in Kit.ACTION_ROLES:
		var o := opts.duplicate(true)
		o["name"] = "ActionPreview_" + role
		o["tooltip"] = role
		row.add_child(Kit.action_button(role, Vector2(tile, tile), Callable(), o))
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_top", 20)
	mc.add_theme_constant_override("margin_bottom", 20)
	mc.add_child(row)
	return mc
```

- [ ] **Step 5: Replace the sidebar case**

In `_element_sidebar` (the `match id` around line 1505), remove the whole `"home_button":` case (lines ~1505-1537) and add:

```gdscript
			"action_button":
				_group_header("Saved to config", true)
				_section_header("Geometry")
				_sidebar_body.add_child(_slider_row(["px", 90, 220]))          # tile size
				_sidebar_body.add_child(_slider_row(["icon_scale", 30, 80]))   # glyph as % of the tile
				_sidebar_body.add_child(_toggle_row("Shadow", "shadow"))
				_cut_paper_section("action_button")                            # the SHARED rugged edge knobs
				_section_header("Per-button paper role (tint)")
				for role in Kit.ACTION_ROLES:
					_sidebar_body.add_child(_option_row(String(role).capitalize(), "tint_" + String(role), Kit.PAPER_SURFACES.keys()))
				_group_header("Test only — not saved", false)
				_sidebar_body.add_child(_option_row("Spotlight role", "preview_role", Kit.ACTION_ROLES))
```

Note: confirm `_cut_paper_section`, `_option_row`, `_slider_row`, `_toggle_row`, `_group_header`, `_section_header` signatures against their definitions (they're used verbatim elsewhere in this file — `_cut_paper_section("frame")` at line 1800, `_option_row(...)` at 1501/1534). `Kit.PAPER_SURFACES.keys()` yields the role names for the dropdown.

- [ ] **Step 6: Verify the workbench headless assertions pass**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
make test-one SUITE=engine/tests/action_button_tests
```
Expected: all assertions pass (now 13), exit 0. If `DEFAULTS`/`IDS` access differs (const vs func), fix the test's access form to match and re-run.

- [ ] **Step 7: Visually verify the component renders**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
make shot-workbench OUT=/tmp/action_button.png EL=action_button
```
**Look at `/tmp/action_button.png`.** Confirm: a row of 8 tiles, each with the shared rugged deckled edge, a centered glyph, calm paper fills, and the drop shadow. If a tile is blank/stretched, diagnose (glyph path, `expand_mode` order per the TextureRect min-size gotcha) and fix before committing.

- [ ] **Step 8: Run the fast sweep + commit**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
make test-fast
git add games/grove/tools/ui_workbench_view.gd engine/tests/action_button_tests.gd
git commit -m "feat(workbench): action_button component (shared rugged edge + glyph); retire home_button component

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Swap the home bottom bar (map.gd) to `Kit.action_button`

**Files:**
- Modify: `engine/scripts/scenes/map.gd:_build_bottom_bar` (~line 2540-2585) and the `NAV_SPRITE` map (line 35-40)
- Modify: `games/grove/tests/grove_explore_tests.gd` (bottom-bar tile assertions, ~line 287-304)

**Interfaces:**
- Consumes: `Kit.action_button`, `Kit.action_button_opts_from_config`. The bottom-bar `specs` already carry `{name, icon, caption, surface, action}`; map each spec's tile to an action role.
- Produces: bottom-bar tiles that are code-drawn action buttons (each has an `ActionButtonDeckleSurface` child), keyed by the same node names (`MapTile`, `ResidentsTile`, `DailyTile`, `VaultTile`, `MailTile`, `BoardTile`) so badges + layout are unchanged.

- [ ] **Step 1: Update the failing test first**

In `grove_explore_tests.gd`, replace the baked-sprite assertions (lines 287-304) with the code-drawn-surface assertions:

```gdscript
	# the BOTTOM BAR tiles: each is now the shared CODE-DRAWN action button — a CutPaperPanel rugged edge
	# (games/grove/tools/ui_workbench_kit.gd action_button) with a centered glyph, over the shared drop
	# shadow — NOT a baked nav_<x>.png sprite. Keyed by spec name.
	var tiles := {"MapTile": "glyph_map", "ResidentsTile": "glyph_residents", "DailyTile": "glyph_daily",
		"BoardTile": "glyph_play"}
	# Vault is parked (`piggy_vault` flag OFF) — its tile stays off the bar.
	ok(hx.get_node_or_null("VaultTile") == null, "the parked Vault carries no bottom-bar tile")
	for tile_name in tiles:
		var btn := hx.get_node_or_null(NodePath(tile_name)) as Button
		ok(btn != null, "the bottom bar carries the %s" % tile_name)
		if btn == null:
			continue
		# the tile wears the code-drawn rugged edge (a CutPaperPanel), a centered glyph, and a drop shadow.
		ok(btn.find_child("ActionButtonDeckleSurface", true, false) != null,
			"%s wears the shared code-drawn rugged edge" % tile_name)
		var rects: Array = btn.find_children("*", "TextureRect", true, false)
		var wears_glyph := rects.any(func(tr: TextureRect) -> bool:
			return tr.texture != null and String(tr.texture.resource_path).findn(String(tiles[tile_name])) != -1)
		ok(wears_glyph, "%s composites its transparent glyph in the middle" % tile_name)
```

Run to confirm FAIL (the live bar still builds baked `SpriteButton` tiles — no `ActionButtonDeckleSurface`):
```bash
cd /Users/xup/dh/merge-worktrees/action-button
make test-one SUITE=games/grove/tests/grove_explore_tests
```
Expected: FAIL on the `ActionButtonDeckleSurface` / glyph assertions.

- [ ] **Step 2: Map spec names to action roles in map.gd**

At the top of `map.gd` near `NAV_SPRITE` (line 35), add a spec-name → action-role map:

```gdscript
# The bottom-bar tiles now build through the shared code-drawn Kit.action_button (rugged edge + glyph),
# not baked nav sprites. Map each bottom-bar node name to its action role.
const NAV_ROLE := {
	"HomeTile": "home", "MapTile": "map", "ResidentsTile": "residents",
	"DailyTile": "daily", "VaultTile": "vault", "MailTile": "mail", "BoardTile": "play",
}
```

- [ ] **Step 3: Build tiles via Kit.action_button**

In `_build_bottom_bar` (lines 2551-2571), replace the opts/branch that chooses `SpriteButton` vs `Kit.home_button`. Replace:

```gdscript
	var opts: Dictionary = Kit.home_bar_tile_opts(Kit.load_config(Kit.CONFIG_PATH), tile_w) if Kit != null else {}
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var o := opts.duplicate(true)
		var role := String(spec.get("surface", "cream"))
		o["surface_role"] = role
		if role == "slate":
			o["caption_color"] = Pal.CREAM
		var b: Button
		var sprite_path := String(NAV_SPRITE.get(String(spec.name), ""))
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			b = SpriteButton.build(load(sprite_path), Vector2(tile_w, tile_w), spec.action,
				{"name": String(spec.name), "tooltip": String(spec.caption)})
		elif Kit != null:
			b = Kit.home_button({"icon": String(spec.icon), "caption": String(spec.caption),
				"tooltip": String(spec.caption), "action": spec.action}, o)
		else:
			b = Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.text = String(spec.caption)
			b.custom_minimum_size = Vector2(tile_w, tile_w)
			b.pressed.connect(spec.action)
```

with:

```gdscript
	var action_opts: Dictionary = Kit.action_button_opts_from_config(Kit.load_config(Kit.CONFIG_PATH)) if Kit != null else {}
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var b: Button
		var role := String(NAV_ROLE.get(String(spec.name), ""))
		if Kit != null and role != "":
			var o := action_opts.duplicate(true)
			o["name"] = String(spec.name)
			o["tooltip"] = String(spec.caption)
			b = Kit.action_button(role, Vector2(tile_w, tile_w), spec.action, o)
		else:
			b = Button.new()                          # defensive fallback (kit absent): a bare tile
			b.focus_mode = Control.FOCUS_NONE
			b.text = String(spec.caption)
			b.custom_minimum_size = Vector2(tile_w, tile_w)
			b.pressed.connect(spec.action)
```

(Leave the `b.name = …`, positioning, `_chrome_nodes` tracking, and `out[…]` lines below unchanged.)

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
make test-one SUITE=games/grove/tests/grove_explore_tests
```
Expected: PASS on the bottom-bar tile assertions. If other assertions in that suite reference tile size/position, they should still hold (the tile is still `tile_w`² at the same position). Fix any that assumed the baked sprite specifically.

- [ ] **Step 5: Visually verify the live home bar**

Render the real home screen (not the workbench preview) and look at it:
```bash
cd /Users/xup/dh/merge-worktrees/action-button
make shot TOOL=games/grove/tools/map_shot ARGS="/tmp/home_bar.png"
```
(Confirm the `map_shot` tool's arg convention first — read `games/grove/tools/map_shot.gd`; adjust ARGS to render the home surface.) **Look at the result:** every bottom-bar tile shares one rugged edge, glyphs read as a family, calm paper fills, badges (Daily dot, Mail pill) still sit correctly.

- [ ] **Step 6: Commit**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
git add engine/scripts/scenes/map.gd games/grove/tests/grove_explore_tests.gd
git commit -m "feat(home): bottom-bar tiles build via shared Kit.action_button (code-drawn rugged edge)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Swap the board Home + Bag wells (board.gd) to `Kit.action_button`

**Files:**
- Modify: `engine/scripts/scenes/board.gd` — `_make_bag_button` (~line 1655-1690) and the Home well builder (~line 1760-1770)
- Modify: `games/grove/tests/grove_board_actions_tests.gd` (or `grove_explore_tests.gd`) — assert the wells wear the code-drawn surface

**Interfaces:**
- Consumes: `Kit.action_button`, `Kit.action_button_opts_from_config`. The Bag well keeps its `BagContent` overlay child + count label + drag-to-stash global-rect semantics unchanged.
- Produces: `BoardHomeTile` and `BagWell` Buttons that wear `ActionButtonDeckleSurface` + the `home`/`bag` glyph, with the Bag's stashed-item overlay intact.

- [ ] **Step 1: Find the board's action-bar test + write the failing assertion**

Determine which suite exercises the board bottom bar (search):
```bash
cd /Users/xup/dh/merge-worktrees/action-button
grep -rn "BagWell\|BoardHomeTile\|nav_home\|nav_bag" games/grove/tests
```
In that suite (likely `grove_board_actions_tests.gd`), add assertions after the board is built:

```gdscript
	var home_tile := bx.get_node_or_null("BoardHomeTile") as Button
	ok(home_tile != null and home_tile.find_child("ActionButtonDeckleSurface", true, false) != null,
		"the board Home well wears the shared code-drawn rugged edge")
	var bag_well := bx.get_node_or_null("BagWell") as Button
	ok(bag_well != null and bag_well.find_child("ActionButtonDeckleSurface", true, false) != null,
		"the board Bag well wears the shared code-drawn rugged edge")
	ok(bag_well != null and bag_well.get_node_or_null("BagContent") != null,
		"the Bag well keeps its stashed-item overlay host")
```

(Match the local scene variable name — `bx`/`board`/etc. — used by that suite for the built board.) Run to confirm FAIL:
```bash
make test-one SUITE=games/grove/tests/grove_board_actions_tests
```
Expected: FAIL (wells still baked `SpriteButton`s).

- [ ] **Step 2: Swap the Home well**

In `board.gd` (~line 1760-1770), replace:

```gdscript
	if ResourceLoader.exists(NAV_HOME):
		b = SpriteButton.build(load(NAV_HOME), Vector2(px, px), go, {"name": "BoardHomeTile"})
```

with:

```gdscript
	var KitH: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
	if KitH != null:
		var ho := KitH.action_button_opts_from_config(KitH.load_config(KitH.CONFIG_PATH))
		ho["name"] = "BoardHomeTile"
		b = KitH.action_button("home", Vector2(px, px), go, ho)
```

(Keep the existing `else`/fallback branch that builds the pre-sprite disc, and everything after, unchanged.)

- [ ] **Step 3: Swap the Bag well (preserve the overlay)**

In `_make_bag_button` (~line 1670), replace:

```gdscript
	var b := SpriteButton.build(load(NAV_BAG), Vector2(px, px), Callable(self, "_open_bag_overlay"), {"name": "BagWell"})
```

with:

```gdscript
	var KitB: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
	var bag_opts := KitB.action_button_opts_from_config(KitB.load_config(KitB.CONFIG_PATH)) if KitB != null else {}
	bag_opts["name"] = "BagWell"
	var b := KitB.action_button("bag", Vector2(px, px), Callable(self, "_open_bag_overlay"), bag_opts)
```

The `BagContent` `CenterContainer` and count label are added as children of `b` in the lines that follow — leave them unchanged; they parent onto the new button identically, and drag-to-stash keys off `b.get_global_rect()`, which is unaffected.

- [ ] **Step 4: Run the board test to verify it passes**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
make test-one SUITE=games/grove/tests/grove_board_actions_tests
```
Expected: PASS on the well assertions. Verify the bag drag/stash tests in that suite still pass (global-rect semantics unchanged).

- [ ] **Step 5: Visually verify the live board bottom bar**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
make shot TOOL=games/grove/tools/grove_shot ARGS="board /tmp/board_bar.png"
```
**Look at `/tmp/board_bar.png`.** Confirm the Home + Bag wells match the home bar's rugged edge, the bag shows its count, and a stashed item overlays the bag glyph correctly (exercise via the suite or a seeded shot if available).

- [ ] **Step 6: Commit**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
git add engine/scripts/scenes/board.gd games/grove/tests/grove_board_actions_tests.gd
git commit -m "feat(board): Home + Bag wells build via shared Kit.action_button

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Retire the baked nav tiles + full sweep

**Files:**
- Archive: `games/grove/assets/ui/nav/nav_map.png`, `nav_residents.png`, `nav_daily.png`, `nav_vault.png`, `nav_mail.png`, `nav_board.png`, `nav_home.png`, `nav_bag.png` (+ their `.import` sidecars)
- Modify: any remaining references (`NAV_SPRITE` in map.gd, `NAV_HOME`/`NAV_BAG` consts in board.gd) — remove if now unused

**Interfaces:**
- Consumes: nothing new.
- Produces: the retired baked tiles moved out of the live path; no code references them for the core nav set.

- [ ] **Step 1: Confirm the retired tiles are no longer loaded**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
grep -rn "nav_map\|nav_residents\|nav_daily\|nav_vault\|nav_mail\|nav_board\|nav_home\|nav_bag" engine games/grove --include=*.gd | grep -v ".godot" | grep -v "glyph"
```
Expected: only the `NAV_SPRITE`/`NAV_HOME`/`NAV_BAG` const declarations (now dead) remain. `nav_back`, `nav_gear`, `nav_play`, `nav_merchant`, `nav_piggy`, `nav_leaf`, `nav_shop`, `nav_settings` are OUT of scope — leave them untouched.

- [ ] **Step 2: Remove the now-dead references**

- `map.gd`: remove the 8 core-set entries from `NAV_SPRITE` (keep `nav_back`/`nav_gear` etc. used by back/settings). If `NAV_SPRITE` becomes empty of live use for the bottom bar, remove the map + the `SpriteButton` import ONLY if no other call site uses it (grep first — back/gear/place-picker still use `SpriteButton`, so keep the import).
- `board.gd`: remove `const NAV_HOME` and `const NAV_BAG` (now unused). Keep the `SpriteButton` import only if still referenced elsewhere in board.gd (grep first).

Verify no dangling references:
```bash
cd /Users/xup/dh/merge-worktrees/action-button
grep -rn "NAV_HOME\|NAV_BAG\|NAV_SPRITE" engine/scripts/scenes/board.gd engine/scripts/scenes/map.gd
```

- [ ] **Step 3: Archive the retired PNGs**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
mkdir -p games/grove/assets/_archive/nav_baked_tiles_v1
git mv games/grove/assets/ui/nav/nav_map.png games/grove/assets/_archive/nav_baked_tiles_v1/
git mv games/grove/assets/ui/nav/nav_map.png.import games/grove/assets/_archive/nav_baked_tiles_v1/
# repeat for nav_residents, nav_daily, nav_vault, nav_mail, nav_board, nav_home, nav_bag (+ .import)
```

- [ ] **Step 4: Reimport + full sweep**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
make import
make test
```
Expected: ALL SUITES PASSED. If a suite still references a moved tile, fix it (it should have been updated in Task 4/5).

- [ ] **Step 5: Final real-path verification**

Render both live surfaces one more time and look at them side by side: `/tmp/home_bar.png` (Task 4) and `/tmp/board_bar.png` (Task 5). Confirm one consistent rugged edge across the home bar and both board wells, a cohesive glyph family, calm paper roles, working badges, and the bag overlay. This is the blocking gate — the change isn't done until the real rendered result is seen.

- [ ] **Step 6: Commit**

```bash
cd /Users/xup/dh/merge-worktrees/action-button
git add -A
git commit -m "chore(nav): retire baked nav tiles (archived); action buttons are code-drawn now

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review notes (spec coverage)

- Shared builder + rugged edge from shared config → Task 2. ✔
- Per-button tint palette in the config block, calm/flattened defaults → Task 2 (`action_button_opts_from_config`, `ACTION_TINT_DEFAULTS`) + Task 3 (palette sidebar). ✔
- Workbench component replaces `home_button`; `Kit.home_button` function kept → Task 3. ✔
- Fresh glyph set generated at once → Task 1. ✔
- Home bar + board Home/Bag route through the component → Tasks 4, 5. ✔
- Baked tiles archived not deleted → Task 6. ✔
- Tests: builder unit + config round-trip (Task 2), workbench registration (Task 3), live bar (Task 4), wells + bag overlay (Task 5), full sweep (Task 6). ✔
- Bag overlay + drag-to-stash preserved → Task 5 (explicit). ✔

**Open verification during execution:** confirm the exact form of `IDS`/`DEFAULTS` access in `ui_workbench_view.gd` (const vs func) for the Task 3 headless assertions, and the `map_shot`/`grove_shot` ARGS conventions for the visual renders — both are called out inline in the steps.
