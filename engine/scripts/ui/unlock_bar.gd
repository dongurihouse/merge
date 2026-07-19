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
const CARD_PATH := "ui/meadow_v2/card_generic.png"
const TRACK_BG := Color("#E0CFB6")          # the empty track — CREAM knocked back a step (must read at 0%)
const FILL_TWEEN_S := 0.55

var _progress := 0.0
var _ready_fx := false
var _bg: Panel
var _badge: TextureRect
var _title: Label
var _level: Label
var _track: Panel
var _fill: Panel
var _pct: Label
var _fill_tween: Tween

# Built in _init (not _ready) so a headless test can drive the strip without a scene tree.
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # the whole strip is the tap target (board wires the action)
	_bg = Panel.new()
	_bg.name = "UnlockBg"
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_theme_stylebox_override("panel", _band_style())
	add_child(_bg)
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
	_track = Panel.new()
	_track.name = "UnlockTrack"
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_track)
	_fill = Panel.new()
	_fill.name = "UnlockFill"
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_fill)
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

# The same paper-card band the quest fence wall uses, so the strip sits in the HUD's family.
func _band_style() -> StyleBox:
	var path := Game.art(CARD_PATH)
	if ResourceLoader.exists(path):
		var sb := StyleBoxTexture.new()
		sb.texture = load(path)
		sb.set_texture_margin(SIDE_LEFT, 34)
		sb.set_texture_margin(SIDE_TOP, 28)
		sb.set_texture_margin(SIDE_RIGHT, 34)
		sb.set_texture_margin(SIDE_BOTTOM, 28)
		return sb
	var flat := StyleBoxFlat.new()
	flat.bg_color = Pal.SURFACE
	flat.set_corner_radius_all(18)
	flat.set_border_width_all(2)
	flat.border_color = Color(Pal.BARK, 0.22)
	flat.shadow_color = Color("#294654", 0.16)
	flat.shadow_size = 4
	flat.shadow_offset = Vector2(0, 2)
	return flat

func _rounded(color: Color, radius: float, outlined: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	if outlined:   # a quiet rim so the EMPTY track still reads on the cream card
		sb.set_border_width_all(1)
		sb.border_color = Color(Pal.BARK, 0.22)
	return sb

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
# also breathes the strip, mirroring the old jar's cue).
func set_ready(on: bool) -> void:
	_ready_fx = on
	_apply_progress()

func progress_for_test() -> float:
	return _progress

func _apply_progress() -> void:
	var h := size.y
	var track_w := _track.size.x
	var bar_h := _track.size.y
	_fill.add_theme_stylebox_override("panel", _rounded(Pal.STRAW if _ready_fx else Pal.LEAF, bar_h * 0.5))
	var w := track_w * _progress
	if _progress > 0.0:
		w = maxf(w, bar_h)   # keep the rounded cap round at the low end
	_fill.size = Vector2(w, bar_h)
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
	var bar_h := h * 0.30
	# mock proportions: the text column ends ~40% in; clamp so a long localized title can't
	# squeeze the track away and a short one doesn't drag it off the mock's column
	var track_left := clampf(text_x + _title_w() + h * 0.24, w * 0.34, w * 0.48)
	var track_right := _pct.position.x - h * 0.16
	_track.position = Vector2(track_left, (h - bar_h) * 0.5)
	_track.size = Vector2(maxf(1.0, track_right - track_left), bar_h)
	_track.add_theme_stylebox_override("panel", _rounded(TRACK_BG, bar_h * 0.5, true))
	_fill.position = Vector2.ZERO
	_apply_progress()

func _title_w() -> float:
	var f := _title.get_theme_font("font")
	var fs := _title.get_theme_font_size("font_size")
	if f == null:
		return size.x * 0.20
	return maxf(f.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x,
		f.get_string_size(_level.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.85)
