extends Control
## The board's NEXT UNLOCK strip (UI redesign direction B) — replaces the fence-row water jar.
## A full-width paper band under the HUD pills: the lock-flower badge, a "NEXT UNLOCK / LEVEL n"
## text column, a green fill bar toward the next level threshold, and the percent read-out.
## The board owns the DATA (progress / next level / ready) and pushes it in via the setters;
## this control only lays out and animates. Mock: ui_redesign_direction_b/board_next_unlock_v1.

const Game = preload("res://engine/scripts/core/game.gd")
const Strings = preload("res://engine/scripts/core/strings.gd")
const Pal = Game.PALETTE

const BADGE_PATH := "ui/meadow_v2/maps_lock_flower.png"
# The band wears the HUD pills' shared paper surface (flat cream + thin PAPER_EDGE rim + a
# texture_cream grain layer from the UI kit) so it reads as one family with the pills above it.
const PAPER_FILL := Pal.CREAM
const PAPER_EDGE := Color(Pal.BARK, 0.35)
const PAPER_CORNER_FRAC := 0.28             # band corner radius as a fraction of the band height
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
var _bar_box := Rect2()    # where the bar sits (computed by _relayout)
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
	resized.connect(_relayout)
	_relayout()

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

func _configure_deckle(corner: float) -> void:
	var Kit: GDScript = Game.kit_script()
	if Kit == null or _deckle == null:
		return
	var cp: Dictionary = Kit.cut_paper_opts_from_config(Game.kit_config(), "action_button", Kit.ACTION_BUTTON_CP_DEFAULTS)
	cp["corner"] = corner
	_deckle.configure(cp, PAPER_FILL, PAPER_EDGE, Kit.cut_paper_tile())
	_deckle.corner = corner

# The progress bar IS the shared Kit.progress_bar — the SAME component (and the same workbench
# "progress_bar" knobs) the level dialog wears, so the two bars can never drift apart. Rebuilt when
# the geometry or the ready state changes; the tween moves the fill via Kit.progress_bar_set_frac.
func _rebuild_bar() -> void:
	var Kit: GDScript = Game.kit_script()
	if Kit == null or _bar_box.size.x <= 0.0:
		return
	if _bar != null and is_instance_valid(_bar):
		_bar.queue_free()
	var opts: Dictionary = Kit.progress_bar_opts_from_config(Game.kit_config())
	opts["name"] = BAR_NAME
	opts["width"] = _bar_box.size.x
	opts["height"] = _bar_box.size.y
	if _ready_fx:   # affordable — the fill turns gold as the tap-me cue
		opts["fill_color"] = Pal.STRAW
	_bar = Kit.progress_bar(_progress, opts)
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
func _relayout() -> void:
	var h := size.y
	var w := size.x
	if h <= 0.0 or w <= 0.0:
		return
	var corner := maxf(12.0, h * PAPER_CORNER_FRAC)
	_configure_deckle(corner)
	_configure_backer(corner)
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

# The stacked-paper BACKER behind the band — the same second-sheet knobs the HUD pills read
# (gold_currency_pill.backer*), so the whole top chrome stacks the same way.
func _configure_backer(corner: float) -> void:
	var Kit: GDScript = Game.kit_script()
	if Kit == null or _bg == null:
		return
	var old := _bg.get_node_or_null("PaperBacker")
	if old != null:
		old.queue_free()
	var cfg: Dictionary = Game.kit_config()
	var pill_opts: Dictionary = Kit.gold_currency_pill_opts_from_config(cfg)
	var cp: Dictionary = Kit.cut_paper_opts_from_config(cfg, "action_button", Kit.ACTION_BUTTON_CP_DEFAULTS)
	cp["corner"] = corner
	var backer: Control = Kit.paper_backer(size, pill_opts, cp)
	if backer != null:
		_bg.add_child(backer)
		_bg.move_child(backer, 0)

func _title_w() -> float:
	var f := _title.get_theme_font("font")
	var fs := _title.get_theme_font_size("font_size")
	if f == null:
		return size.x * 0.20
	return maxf(f.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x,
		f.get_string_size(_level.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.85)
