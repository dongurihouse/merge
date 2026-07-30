extends Control
## The board's NEXT UNLOCK strip (UI redesign direction B) — replaces the fence-row water jar.
## A full-width paper band under the HUD pills: the lock-flower badge, a "NEXT UNLOCK / LEVEL n"
## text column, a green fill bar toward the next level threshold, and the percent read-out.
## The board owns the DATA (progress / next level / ready) and pushes it in via the setters;
## this control only lays out and animates. Mock: ui_redesign_direction_b/board_next_unlock_v1.

const Game = preload("res://engine/scripts/core/game.gd")
const Strings = preload("res://engine/scripts/core/strings.gd")
const Paper = preload("res://engine/scripts/ui/paper_button.gd")     # the shared paper-button MATERIAL
const PaperProgress = preload("res://engine/scripts/ui/paper_progress.gd")   # …and the bar's own
const Pal = Game.PALETTE

const BADGE_PATH := "ui/meadow_v2/maps_lock_flower.png"
# THE BAND'S SURFACE is the shared paper-button material (engine/scripts/ui/paper_button.gd) — the same
# smooth feathered edge, directional cast shadow and lit hairline the nav tabs and the board's bottom row
# wear. It used to be the torn deckle plus a cream rim plus a second stacked backer sheet; the mock this
# strip is named after draws none of those. Its band is ONE smooth rounded sheet floating on the sky, and
# measured against the sky beside it (board_next_unlock_v1, stepping out from the band's own edge) it
# carries exactly the material's own directional light:
#     left  0.175 at 1px · 0.065 at 2 · 0.052 at 3 · gone by 5     (the LIT side)
#     right 0.104 at 1px · 0.383 at 2 · 0.227 at 3 · 0.084 at 6 · 0.019 at 9 · gone by 10
#     below 0.078 at 1px · 0.383 at 2 · 0.390 at 3 · 0.234 at 6 · 0.130 at 9 · gone by 15
# — the same split the mock's nav tabs read (0.168 lit / 0.388 shadow), which is the scene's own light and
# not this band's quirk. Hence the shared module, not a local tuning.
#
# NO TAB GEOMETRY. The band floats: it touches no screen edge, so it must not bleed and must not flare
# (engine/scripts/ui/edge_tab.gd is deliberately absent here).
#
# THE MATERIAL IS SCALED FROM THE BAND'S HEIGHT, not its width. Every reach in paper_button.gd is a
# fraction of a button's face WIDTH because a button is roughly square; this sheet is ~1030 x 130, and its
# own width would ask for a 108px halo reach against the ~14px its neighbours cast. Passing the short
# dimension is the same `material_w` separation EdgeTab.sheet_cp makes for the board's wide info tray.
const PAPER_FILL := Pal.CREAM
const PAPER_CORNER_FRAC := 0.28             # band corner radius as a fraction of the band height
# THE MATERIAL'S OWN SCALE. paper_button spends its reaches as fractions of a face WIDTH, so the number
# handed to it is "how big a button is this sheet made like", not "how wide is it". The band's height is
# the right order of magnitude and still too big: measured on the rig, surface_cp(131) left the shadow
# side at 0.050 at 10px where the mock is already down to 0.007, and the lit side at 0.039 at 6px against
# 0.007. paper_button spends 0.1189 W on the shadow side and the mock's band is gone by 10px, so the face
# width this sheet is made like is ~84px at its 131px height.
const MATERIAL_H_FRAC := 0.64
# THE STRAIGHT-DOWN DROP, re-derived here. See surface_cp: at the config's own button figures this band
# was nearly twice the mock's darkness below. Fitted on the rig against the mock's bottom profile.
const DROP_REACH_FRAC := 0.092              # px of reach per px of band height (12px at h=131)
const DROP_ALPHA_PCT := 1.0                 # …at this per-copy alpha; the stack is ~1px-stepped
const FILL_TWEEN_S := 0.55
const DECKLE_SURFACE_NODE := "UnlockDeckleSurface"
const BAR_NAME := "UnlockBar"    # the SHARED Kit.progress_bar (same component as the level dialog)

var _progress := 0.0
var _ready_fx := false
var _bg: Panel
var _deckle: Control
var _badge: TextureRect
var _title: Label
var _level: Label
var _bar: Control          # Kit.progress_bar holder — rebuilt on relayout/ready, tweened via set_frac
var _bar_box := Rect2()    # where the bar sits (computed by relayout)
var _pct: Label
var _fill_tween: Tween

# Built in _init (not _ready) so a headless test can drive the strip without a scene tree.
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # the whole strip is the tap target (board wires the action)
	_bg = Panel.new()
	_bg.name = "UnlockBg"
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_theme_stylebox_override("panel", _clear_style())
	add_child(_bg)
	_deckle = _make_deckle_surface(DECKLE_SURFACE_NODE)
	_bg.add_child(_deckle)
	_badge = TextureRect.new()
	_badge.name = "UnlockBadge"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var badge_path := Game.art(BADGE_PATH)
	if ResourceLoader.exists(badge_path):
		_badge.texture = load(badge_path)
	add_child(_badge)
	_title = _label("UnlockTitle", Pal.INK)
	_level = _label("UnlockLevel", Color(Pal.INK, 0.55))
	_pct = _label("UnlockPct", Pal.INK)
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	resized.connect(relayout)
	relayout()

func _label(lname: String, color: Color) -> Label:
	var l := Label.new()
	l.name = lname
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l

func _clear_style() -> StyleBox:
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.draw_center = false
	return flat

func _make_deckle_surface(node_name: String) -> Control:
	var Kit: GDScript = Game.kit_script()
	if Kit == null:
		return Control.new()
	var panel: Control = load(Kit.CUT_PAPER).new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return panel

## The band's cut-paper knobs — a static so the mock-compare rig configures the SAME surface the board
## draws instead of re-spelling it (games/grove/tools/mock_elements.gd).
##
## The shared material goes on LAST, so it wins over the config's torn-edge knobs: deckle_amp 0, the
## feathered silhouette, the directional halo, the lit hairline, and rim_width 0 — a plain paper sheet's
## edge just ends. Scaled from the band's HEIGHT (see the header).
static func surface_cp(Kit: GDScript, cfg: Dictionary, h: float) -> Dictionary:
	var cp: Dictionary = Kit.cut_paper_opts_from_config(cfg, "action_button", Kit.ACTION_BUTTON_CP_DEFAULTS)
	cp.merge(Paper.surface_cp(h * MATERIAL_H_FRAC), true)
	cp["corner"] = maxf(12.0, h * PAPER_CORNER_FRAC)
	# THE STRAIGHT-DOWN DROP SHADOW, re-derived rather than inherited. It arrives from the `action_button`
	# config block in absolute px at a button's own alpha, and on every OTHER wearer of this material it is
	# invisible: a nav tab and the board's wells bleed off the bottom of the screen, so nothing of theirs
	# is ever drawn below the sheet. This band FLOATS, so it draws in full and lands on top of the halo's
	# own shadow side. Measured on the rig with the config's figures, the bottom profile ran 0.582 at 3px
	# and 0.643 at 4 against the mock's 0.375 and 0.282 — an rms of 0.209 against a 0.017 grain floor,
	# while the RIGHT side (halo only) was already inside 0.05. The mock does carry more shadow below than
	# beside (0.229 vs 0.085 at 6px, and it is still 0.092 at 10px where the side is 0.007), so what it
	# wants is a LONGER, LIGHTER drop and not a shorter one: fitted, reach 12px at 1% per copy takes the
	# bottom to rms 0.075.
	cp["shadow_reach"] = h * DROP_REACH_FRAC
	cp["shadow_strength"] = DROP_ALPHA_PCT
	return cp

func _configure_deckle(_corner: float) -> void:
	var Kit: GDScript = Game.kit_script()
	if Kit == null or _deckle == null:
		return
	var cp := surface_cp(Kit, Game.kit_config(), size.y)
	_deckle.configure(cp, PAPER_FILL, null, Kit.cut_paper_tile())
	_deckle.corner = float(cp["corner"])

# The progress bar IS the shared Kit.progress_bar — the SAME component (and the same workbench
# "progress_bar" knobs) the level dialog wears, so the two bars can never drift apart. Rebuilt when
# the geometry or the ready state changes; the tween moves the fill via Kit.progress_bar_set_frac.
#
# WHAT THIS BAND ASKS FOR ON TOP: the cut-paper WELL (engine/scripts/ui/paper_progress.gd) — a warm cream
# floor sunk into the band with the lip's crease and inner shadow, and a raised green capsule lying in it
# casting the scene's own light. That is what board_next_unlock_v1 draws here, and the slate nine-slice
# capsule the shared config defaults to is what it does NOT: measured off the mock, the track floor is
# (248,225,201) cream where ours was (81,94,113) navy.
#
# IT IS AN OPT AND NOT A NEW DEFAULT, deliberately. `progress_bar_opts_from_config` also dresses the
# level-up dialog, whose bar is drawn from its own asset sheet (kit/level_track.png, matched to the navy
# medallion above it) and which no mock asks to change. `paper` is the only key that moves, so every other
# caller — that dialog, the residents banks, the workbench preview — renders byte-identically.
## The bar's OPTS, as a static so the mock-compare rig can stand the same bar up on a flat field
## (games/grove/tools/mock_elements.gd) without re-spelling any of it. A rig cell that re-implements
## its element measures the re-implementation.
static func bar_opts(Kit: GDScript, cfg: Dictionary, box: Vector2, ready: bool) -> Dictionary:
	var opts: Dictionary = Kit.progress_bar_opts_from_config(cfg)
	opts["name"] = BAR_NAME
	opts["width"] = box.x
	opts["height"] = box.y
	if ready:   # affordable — the fill turns gold as the tap-me cue
		opts["fill_color"] = Pal.STRAW
	opts["shadow"] = false      # a well is SUNK: the raised-sheet drop shadow under the whole bar is wrong
	opts.merge(PaperProgress.fill_geometry(), true)
	# PAPER_FILL is handed in because the well's floor is a RATIO of the sheet it is cut into, not a
	# colour of its own — this band's own face is that sheet.
	opts["paper"] = PaperProgress.opts(box.y, opts.get("fill_color", Pal.LEAF), PAPER_FILL)
	return opts

func _rebuild_bar() -> void:
	var Kit: GDScript = Game.kit_script()
	if Kit == null or _bar_box.size.x <= 0.0:
		return
	if _bar != null and is_instance_valid(_bar):
		_bar.queue_free()
	_bar = Kit.progress_bar(_progress, bar_opts(Kit, Game.kit_config(), _bar_box.size, _ready_fx))
	_bar.position = _bar_box.position
	_bar.size = _bar_box.size
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)

func set_next_level(level: int) -> void:
	_level.text = (Strings.t("level.banner") % level).to_upper()

func set_progress(p: float) -> void:
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()
	_progress = clampf(p, 0.0, 1.0)
	_apply_progress()

func animate_progress_to(p: float) -> void:
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()
	var target := clampf(p, 0.0, 1.0)
	if not is_inside_tree():
		_progress = target
		_apply_progress()
		return
	_fill_tween = create_tween()
	_fill_tween.tween_method(func(v: float) -> void:
		_progress = v
		_apply_progress(), _progress, target, FILL_TWEEN_S) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ready = the next unlock is affordable — the fill turns gold as the tap-me cue (the board
# also breathes the strip, mirroring the old jar's cue). The fill colour is baked into the built
# bar, so a ready flip rebuilds it (rare — once per affordability change).
func set_ready(on: bool) -> void:
	if on == _ready_fx:
		return
	_ready_fx = on
	_rebuild_bar()
	_apply_progress()

func progress_for_test() -> float:
	return _progress

func _apply_progress() -> void:
	var h := size.y
	if _bar != null and is_instance_valid(_bar):
		var Kit: GDScript = Game.kit_script()
		if Kit != null:
			Kit.progress_bar_set_frac(_bar, _progress)
	_pct.text = "%d%%" % int(round(_progress * 100.0))
	if h > 0.0:
		_pct.add_theme_font_size_override("font_size", int(h * 0.30))

# Everything is proportional to the strip height H (screen-fraction sized by the board) so the
# band scales with the viewport like the rest of the HUD.
#
# PUBLIC (it used to be `_relayout`) because `resized` is not a reliable trigger for a caller that hands
# this control its size BY HAND, outside a container: measured on the mock-compare rig, a band given
# `size = (1028, 131)` before entering the tree never laid out at all, so its surface kept cut_paper.gd's
# raw defaults — a torn 5px deckle, no halo, a straight-down drop shadow — and profiled as a shadow
# DEFECT that was really a layout that never ran. Anything that sizes this band itself must call it.
func relayout() -> void:
	var h := size.y
	var w := size.x
	if h <= 0.0 or w <= 0.0:
		return
	var corner := maxf(12.0, h * PAPER_CORNER_FRAC)
	_configure_deckle(corner)
	var badge_s := h * 1.06
	_badge.size = Vector2(badge_s, badge_s)
	_badge.position = Vector2(h * 0.16, (h - badge_s) * 0.5)
	var text_x := _badge.position.x + badge_s + h * 0.18
	_title.add_theme_font_size_override("font_size", int(h * 0.26))
	_level.add_theme_font_size_override("font_size", int(h * 0.21))
	_title.text = Strings.t("board.unlock.next").to_upper()
	_title.position = Vector2(text_x, h * 0.16)
	_title.size = Vector2(w * 0.30, h * 0.32)
	_level.position = Vector2(text_x, h * 0.52)
	_level.size = Vector2(w * 0.30, h * 0.28)
	var pct_w := h * 1.05
	_pct.size = Vector2(pct_w, h)
	_pct.position = Vector2(w - pct_w - h * 0.26, 0.0)
	var bar_h := h * 0.36            # track thickness, +20% by owner call (was 0.30); the BAND height is unchanged
	# mock proportions: the text column ends ~40% in; clamp so a long localized title can't
	# squeeze the track away and a short one doesn't drag it off the mock's column
	var track_left := clampf(text_x + _title_w() + h * 0.24, w * 0.34, w * 0.48)
	var track_right := _pct.position.x - h * 0.16
	_bar_box = Rect2(Vector2(track_left, (h - bar_h) * 0.5), Vector2(maxf(1.0, track_right - track_left), bar_h))
	_rebuild_bar()
	_apply_progress()

# THE STACKED BACKER IS GONE. The band used to draw a second cut-paper sheet behind itself (the HUD
# pills' `gold_currency_pill.backer*` knobs), so its silhouette was two offset sheets with a cream lip
# showing round the lower one. board_next_unlock_v1 draws ONE sheet: measured across its left edge the
# sky goes straight to band face in 2px with no second cut edge anywhere on the perimeter, and the
# darkening beside it is a plain directional cast shadow. The material's own halo is what raises the
# sheet now. The pills above keep their backer — that knob is untouched.

func _title_w() -> float:
	var f := _title.get_theme_font("font")
	var fs := _title.get_theme_font_size("font_size")
	if f == null:
		return size.x * 0.20
	return maxf(f.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x,
		f.get_string_size(_level.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.85)
