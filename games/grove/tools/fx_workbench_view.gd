@tool
extends Control
## The COIN FLOW PREVIEW — the staged screen the FX workbench flies a reward across.
##
## This is a COMPONENT, not a screen: `fx_gallery_view.gd` (the live FxWorkbench.tscn view)
## mounts one of these as the "fx" gallery element and owns the whole sidebar. Its own
## standalone chrome — backdrop, sidebar, stage shell and a second copy of every slider and
## action row — was superseded when the gallery took over and is gone; nothing ever
## instantiated this class standalone, so an `embedded` flag that was always true went with it.
##
## The gallery drives it through the PUBLIC methods below (select_action / set_fx_enabled /
## set_global_setting / set_auto_replay / play_selected) — they are the component's contract,
## not private methods reached by string dispatch.
##
## The action table it stages lives in fx_defs.gd so the sidebar reads it without reaching
## into this view class.

const Game = preload("res://engine/scripts/core/game.gd")
const G = preload("res://engine/scripts/core/content.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const FxDefs = preload("res://games/grove/tools/fx_defs.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Pal = Game.PALETTE

const PREVIEW_W := 620.0
const PREVIEW_H := 940.0
const EMBEDDED_PREVIEW_SCALE := 0.68
const COIN_CODE := G.COIN_LINE * 100 + 1
const SAMPLE_ITEM_A := 101
const SAMPLE_ITEM_B := 102


var _preview_action := "coin_pickup"
var _settings := {
	"amount": FX.REWARD_FX_DEFAULT_AMOUNT,
	"icon_size": int(FX.REWARD_FX_DEFAULT_ICON_SIZE),
	"trail_count": FX.REWARD_FX_DEFAULT_TRAIL_COUNT,
	"coin_size": int(FX.REWARD_FX_DEFAULT_SOURCE_SIZE),
	"auto_replay": false,
}
var _totals: Dictionary = {"coin": 120, "gem": 8, "water": 0, "bag": 3}
var _targets: Dictionary = {}
var _target_labels: Dictionary = {}
var _preview_stage: CenterContainer = null
var _preview_root: Control = null
var _source: Control = null
var _auto_timer: Timer = null
@export var preview_scale := EMBEDDED_PREVIEW_SCALE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(540, 760)
	_load_settings()
	_build()

func _load_settings() -> void:
	_settings["icon_size"] = int(round(FX.reward_fx_icon_size()))
	_settings["trail_count"] = FX.reward_fx_trail_count()
	_settings["amount"] = FX.REWARD_FX_DEFAULT_AMOUNT
	_settings["coin_size"] = int(round(FX.REWARD_FX_DEFAULT_SOURCE_SIZE))
	_settings["auto_replay"] = false

func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_targets.clear()
	_target_labels.clear()
	_source = null

	var cc := CenterContainer.new()
	cc.name = "CoinFlowEmbeddedRoot"
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	_preview_stage = cc
	_build_selected_preview()

	_auto_timer = Timer.new()
	_auto_timer.name = "AutoReplayTimer"
	_auto_timer.wait_time = 1.8
	_auto_timer.autostart = false
	_auto_timer.timeout.connect(func() -> void:
		if bool(_settings.get("auto_replay", false)):
			play_selected())
	add_child(_auto_timer)
	if bool(_settings.get("auto_replay", false)):
		_auto_timer.start()

## --- the gallery's control surface (public: the sidebar drives the component) ------

func set_global_setting(key: String, value: int) -> void:
	_settings[key] = value
	match key:
		"icon_size":
			FX.set_reward_fx_icon_size(float(value))
		"trail_count":
			FX.set_reward_fx_trail_count(value)
		"coin_size":
			_build_selected_preview()

func set_auto_replay(on: bool) -> void:
	_settings["auto_replay"] = on
	if _auto_timer != null:
		if on:
			_auto_timer.start()
		else:
			_auto_timer.stop()

func select_action(id: String) -> void:
	if id == _preview_action:
		return
	_preview_action = id
	_build_selected_preview()

func set_fx_enabled(id: String, on: bool) -> void:
	FX.set_reward_fx_enabled(id, on)
	if id == _preview_action:
		_build_selected_preview()

## The live settings the gallery's sliders read back (icon_size / trail_count / amount /
## coin_size / auto_replay).
func settings() -> Dictionary:
	return _settings.duplicate()

func preview_action() -> String:
	return _preview_action

func _build_selected_preview() -> void:
	if _preview_stage == null:
		return
	for c in _preview_stage.get_children():
		_preview_stage.remove_child(c)
		c.queue_free()
	_targets.clear()
	_target_labels.clear()
	_source = null

	_preview_root = Control.new()
	_preview_root.name = "CoinFlowPreview"
	_preview_root.custom_minimum_size = Vector2(PREVIEW_W, PREVIEW_H)
	_preview_root.size = Vector2(PREVIEW_W, PREVIEW_H)
	_preview_root.clip_contents = true

	var scale := clampf(preview_scale, 0.25, 1.0)
	if scale < 0.999:
		var wrap := Control.new()
		wrap.name = "CoinFlowScaledPreviewWrap"
		wrap.custom_minimum_size = Vector2(PREVIEW_W, PREVIEW_H) * scale
		wrap.size = wrap.custom_minimum_size
		wrap.clip_contents = true
		_preview_stage.add_child(wrap)
		_preview_root.scale = Vector2(scale, scale)
		wrap.add_child(_preview_root)
	else:
		_preview_stage.add_child(_preview_root)

	var def := FxDefs.def(_preview_action)
	match String(def.get("context", "board")):
		"map":
			_preview_root.add_child(_map_backdrop())
			_add_preview_hud("Map", def.get("targets", []))
			_add_map_surface(def)
		"home":
			_preview_root.add_child(_home_backdrop())
			_add_preview_hud("Home", def.get("targets", []))
			_add_home_surface(def)
		_:
			_preview_root.add_child(_field_backdrop())
			_add_preview_hud("Board", def.get("targets", []))
			_add_board_surface(def)
	_add_bottom_bar(String(def.get("footer", "")))
	if not FX.reward_fx_enabled(_preview_action):
		_show_disabled_badge()

func _field_backdrop() -> Control:
	var path := Game.art("ui/board2_bg.png")
	if ResourceLoader.exists(path):
		var bg := TextureRect.new()
		bg.name = "BoardFieldBackdrop"
		bg.texture = load(path)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return bg
	var c := ColorRect.new()
	c.color = Pal.SURFACE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _map_backdrop() -> Control:
	var c := ColorRect.new()
	c.color = Color("#A8C37A")
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _home_backdrop() -> Control:
	var c := ColorRect.new()
	c.color = Color("#D7C89F")
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _add_preview_hud(title_text: String, target_ids: Array) -> void:
	var title := Look.title_ribbon("Coin Flow - %s" % title_text, FS.BODY)
	title.name = "PreviewTitle"
	title.position = Vector2(26, 24)
	_preview_root.add_child(title)

	var x := PREVIEW_W - 34.0
	for target in target_ids:
		var id := String(target)
		var chip := _wallet_chip(id)
		chip.position = Vector2(x - chip.size.x, 24)
		x -= chip.size.x + 12.0
		_preview_root.add_child(chip)
		_targets[id] = chip

func _wallet_chip(id: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "%sWalletTarget" % _pascal_id(id)
	chip.size = Vector2(176, 70)
	chip.add_theme_stylebox_override("panel", _box(Pal.PILL, 26, 2, Pal.PILL_EDGE, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(row)
	row.add_child(Look.icon(id, 36))
	var total := int(_totals.get(id, 0))
	var lbl := _label(str(total), FS.FINE, Pal.INK)
	lbl.name = "%sWalletAmount" % _pascal_id(id)
	row.add_child(lbl)
	_target_labels[id] = lbl
	return chip

func _add_board_surface(def: Dictionary) -> void:
	var holder := Control.new()
	holder.name = "CoinFlowBoardSurface"
	holder.position = Vector2(42, 170)
	holder.size = Vector2(PREVIEW_W - 84, 610)
	_preview_root.add_child(holder)

	var mat := PieceView.make_board_mat(holder.size.x - 28, holder.size.y - 28)
	mat.position += Vector2(14, 14)
	holder.add_child(mat)

	var grid := Control.new()
	grid.name = "CoinFlowBoardGrid"
	grid.position = Vector2(40, 58)
	grid.size = Vector2(holder.size.x - 80, holder.size.y - 116)
	holder.add_child(grid)
	_add_board_cells(grid, 4, 5)

	var source_kind := String(def.get("source_kind", "coin_piece"))
	var source_pos := Vector2(grid.size.x * 0.5, grid.size.y * 0.52)
	match source_kind:
		"coin_piece":
			_source = _make_piece_source(COIN_CODE)
		"item_piece":
			_source = _make_piece_source(SAMPLE_ITEM_A)
		"quest":
			_source = _make_action_card("Quest", "coin", "Claim")
		"offer":
			_source = _make_action_card("2x", "coin", "Accept")
		_:
			_source = _make_source_button(String(def.get("source_label", "Play")))
	if _source != null:
		_source.name = "CoinFlowSource"
		_source.position = source_pos - _source.size / 2.0
		_wire_source(_source)
		grid.add_child(_source)

func _add_board_cells(grid: Control, cols: int, rows: int) -> void:
	var gap := 10.0
	var source_px := float(_settings.get("coin_size", FX.REWARD_FX_DEFAULT_SOURCE_SIZE))
	var cell := clampf(source_px + 16.0, 92.0, 134.0)
	var grid_w := cols * cell + (cols - 1) * gap
	var grid_h := rows * cell + (rows - 1) * gap
	var start := (grid.size - Vector2(grid_w, grid_h)) / 2.0
	for y in rows:
		for x in cols:
			var well := Panel.new()
			well.position = start + Vector2(x * (cell + gap), y * (cell + gap))
			well.size = Vector2(cell, cell)
			well.add_theme_stylebox_override("panel", _cell_box())
			well.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(well)

func _add_map_surface(_def: Dictionary) -> void:
	var trail := Panel.new()
	trail.name = "CoinFlowMapSurface"
	trail.position = Vector2(70, 156)
	trail.size = Vector2(PREVIEW_W - 140, 650)
	trail.add_theme_stylebox_override("panel", _box(Color("#DDE6B9"), 34, 3, Color(Pal.LEAF, 0.34), 6))
	_preview_root.add_child(trail)
	for i in 4:
		var card := _map_place_card("Place %d" % (i + 1), i == 2)
		card.position = Vector2(48, 58 + i * 142)
		trail.add_child(card)
		if i == 2:
			_source = card
			_source.name = "CoinFlowSource"
			_wire_source(_source)

func _map_place_card(text: String, active: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.size = Vector2(PREVIEW_W - 236, 108)
	card.add_theme_stylebox_override("panel", _box(Pal.PILL if active else Color(Pal.PILL, 0.64), 24, 2, Pal.PILL_EDGE if active else Color(Pal.PILL_EDGE, 0.44), 5 if active else 1))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(Look.icon("leaf", 38))
	row.add_child(_label(text, FS.FINE, Pal.INK))
	if active:
		row.add_child(_label("Ready", FS.TOOL, Pal.BTN_PRIMARY))
	return card

func _add_home_surface(_def: Dictionary) -> void:
	var floor := Panel.new()
	floor.name = "CoinFlowHomeSurface"
	floor.position = Vector2(70, 156)
	floor.size = Vector2(PREVIEW_W - 140, 650)
	floor.add_theme_stylebox_override("panel", _box(Color("#E6D7AD"), 34, 3, Color(Pal.BARK, 0.34), 6))
	_preview_root.add_child(floor)
	var stall := _make_action_card("Market", "cart", "Sell basket")
	stall.position = Vector2(72, 64)
	floor.add_child(stall)
	_source = _make_piece_source(SAMPLE_ITEM_B)
	_source.name = "CoinFlowSource"
	_source.position = Vector2((floor.size.x - _source.size.x) / 2.0, 298)
	_wire_source(_source)
	floor.add_child(_source)

func _make_piece_source(code: int) -> Control:
	var px := float(_settings.get("coin_size", FX.REWARD_FX_DEFAULT_SOURCE_SIZE))
	var piece := PieceView.make_piece(code, px)
	piece.size = Vector2(px, px)
	piece.custom_minimum_size = Vector2(px, px)
	piece.mouse_filter = Control.MOUSE_FILTER_STOP
	return piece

func _make_source_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size = Vector2(164, 72)
	b.custom_minimum_size = b.size
	b.add_theme_font_size_override("font_size", FS.FINE)
	b.add_theme_stylebox_override("normal", _box(Pal.BTN_PRIMARY, 22, 2, Pal.BTN_PRIMARY_EDGE, 6))
	b.add_theme_color_override("font_color", Pal.CREAM)
	return b

func _make_action_card(title: String, icon_id: String, caption: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size = Vector2(188, 128)
	card.custom_minimum_size = card.size
	card.add_theme_stylebox_override("panel", _box(Pal.PILL, 24, 2, Pal.PILL_EDGE, 6))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	top.add_child(Look.icon(icon_id, 34))
	top.add_child(_label(title, FS.FINE, Pal.INK))
	var cap := _label(caption, FS.TOOL, Color(Pal.INK, 0.72))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	return card

func _wire_source(source: Control) -> void:
	if source is Button:
		(source as Button).pressed.connect(play_selected)
	else:
		source.mouse_filter = Control.MOUSE_FILTER_STOP
		source.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				play_selected())

func _add_bottom_bar(text: String) -> void:
	var bar := PanelContainer.new()
	bar.name = "PreviewInfoBar"
	bar.position = Vector2(44, PREVIEW_H - 118)
	bar.size = Vector2(PREVIEW_W - 88, 74)
	bar.add_theme_stylebox_override("panel", _box(Color(Pal.PILL, 0.94), 24, 2, Pal.PILL_EDGE, 7))
	_preview_root.add_child(bar)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	row.add_child(Look.icon(String(FxDefs.def(_preview_action).get("target", "coin")), 30))
	row.add_child(_label(text, FS.TOOL, Pal.INK))

func play_selected() -> void:
	if not FX.reward_fx_enabled(_preview_action):
		_show_disabled_badge()
		return
	var def := FxDefs.def(_preview_action)
	match _preview_action:
		"map_task_reward":
			_play_reward("gem", 1, FX.reward_color("gem"), "gem", Vector2(0, -12))
			_play_reward("coin", int(_settings.get("amount", 25)), FX.reward_color("coin"), "coin", Vector2(0, 28))
		"stash_to_bag":
			_play_reward("bag", 1, FX.reward_color("bag"), "bag")
		_:
			var icon_id := String(def.get("icon", "coin"))
			var target_id := String(def.get("target", "coin"))
			_play_reward(icon_id, _reward_amount_for(_preview_action), FX.reward_color(icon_id), target_id)

func _play_reward(icon_id: String, amount: int, color: Color, target_id: String, offset: Vector2 = Vector2.ZERO) -> void:
	if _preview_root == null or _source == null:
		return
	_clear_disabled_badges()
	var target: Control = _targets.get(target_id, null) as Control
	var from := _source.get_global_rect().get_center() + offset
	var icon_size := float(_settings.get("icon_size", FX.REWARD_FX_DEFAULT_ICON_SIZE))
	var trail_count := int(_settings.get("trail_count", FX.REWARD_FX_DEFAULT_TRAIL_COUNT))
	var self_ref: WeakRef = weakref(self) as WeakRef
	var done: Callable = func() -> void:
		var live: Object = self_ref.get_ref() as Object
		if live != null and is_instance_valid(live):
			live.call("_finish_reward", target_id, amount)
	FX.reward_arrival(self, from, icon_id, amount, color, target, done, icon_size, "+", trail_count, _preview_action)

func _finish_reward(target_id: String, amount: int) -> void:
	_totals[target_id] = int(_totals.get(target_id, 0)) + amount
	var lbl: Label = _target_labels.get(target_id, null) as Label
	if lbl != null and is_instance_valid(lbl):
		lbl.text = str(int(_totals.get(target_id, 0)))
	if _source != null and is_instance_valid(_source):
		FX.pop(_source)

func _reward_amount_for(id: String) -> int:
	return 1 if id == "stash_to_bag" else int(_settings.get("amount", FX.REWARD_FX_DEFAULT_AMOUNT))

func _show_disabled_badge() -> void:
	_clear_disabled_badges()
	if _preview_root == null:
		return
	var badge := PanelContainer.new()
	badge.name = "FxDisabledBadge"
	badge.position = Vector2((PREVIEW_W - 210) / 2.0, 114)
	badge.size = Vector2(210, 56)
	badge.add_theme_stylebox_override("panel", _box(Color(Pal.INK, 0.82), 20, 2, Color(Pal.CREAM, 0.22), 8))
	var label := _label("Effect off", FS.TOOL, Pal.CREAM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)
	_preview_root.add_child(badge)
	if _source != null and is_instance_valid(_source):
		FX.wobble(_source)

func _clear_disabled_badges() -> void:
	if _preview_root == null:
		return
	for n in _preview_root.find_children("FxDisabledBadge", "PanelContainer", true, false):
		(n as Node).queue_free()

func _clear_runtime_fx() -> void:
	for n in find_children("RewardArrival*", "Control", true, false):
		(n as Node).queue_free()
	_clear_disabled_badges()

func _label(text: String, px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	return l

func _box(color: Color, radius: int, border_w := 0, border := Color.TRANSPARENT, shadow := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = border_w
	sb.border_width_right = border_w
	sb.border_width_top = border_w
	sb.border_width_bottom = border_w
	sb.border_color = border
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = shadow
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _cell_box() -> StyleBoxFlat:
	return _box(Color(Pal.PILL, 0.72), 14, 2, Color(Pal.PILL_EDGE, 0.46), 2)

func _pascal_id(id: String) -> String:
	var out := ""
	for part in id.split("_"):
		out += String(part).capitalize()
	return out
