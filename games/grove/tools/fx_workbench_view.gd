@tool
extends Control
## FX Workbench - sidebar list + contextual preview stage for shipped Grove effects.

const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const G = preload("res://engine/scripts/core/content.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Pal = Game.PALETTE

const SIDEBAR_W := 360.0
const PREVIEW_W := 620.0
const PREVIEW_H := 940.0
const COIN_CODE := G.COIN_LINE * 100 + 1
const SAMPLE_ITEM_A := 101
const SAMPLE_ITEM_B := 102
const FX_DEFS := [
	{"id": "coin_pickup", "label": "Coin pickup", "screen": "Board", "context": "board", "icon": "coin", "target": "coin", "source_kind": "coin_piece", "targets": ["coin"], "footer": "Coin pickup routes to wallet"},
	{"id": "board_refill", "label": "Board refill", "screen": "Board", "context": "board", "icon": "water", "target": "water", "source_kind": "button", "source_label": "Refill", "targets": ["water"], "footer": "Refill button sends water to the HUD"},
	{"id": "stash_to_bag", "label": "Stash to bag", "screen": "Board", "context": "board", "icon": "bag", "target": "bag", "source_kind": "item_piece", "source_label": "Stash", "targets": ["bag"], "footer": "Dragged item stores into the bag"},
	{"id": "quest_payout", "label": "Quest payout", "screen": "Board", "context": "board", "icon": "coin", "target": "coin", "source_kind": "quest", "source_label": "Quest", "targets": ["coin"], "footer": "Quest coin reward flies from the giver chip"},
	{"id": "accept_2x", "label": "2x reward accept", "screen": "Board", "context": "board", "icon": "coin", "target": "coin", "source_kind": "offer", "source_label": "2x", "targets": ["coin"], "footer": "Bonus accept pays a second coin grant"},
	{"id": "map_task_reward", "label": "Map task reward", "screen": "Map", "context": "map", "icon": "coin", "target": "coin", "source_kind": "map_card", "source_label": "Restore", "targets": ["gem", "coin"], "footer": "Restored place pays gems and coins"},
	{"id": "sale_payout", "label": "Sale payout", "screen": "Home", "context": "home", "icon": "coin", "target": "coin", "source_kind": "sale_item", "source_label": "Sell", "targets": ["coin"], "footer": "Sold item payout routes to the wallet"},
]

var _selected_fx := "coin_pickup"
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
var _fx_list: VBoxContainer = null
var _controls: VBoxContainer = null
var _preview_stage: CenterContainer = null
var _preview_root: Control = null
var _context_label: Label = null
var _source: Control = null
var _auto_timer: Timer = null
@export var embedded := false

func _ready() -> void:
	if not embedded:
		UiFont.apply()
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(1320, 820) if embedded else Vector2(960, 720)
	_load_global_settings()
	_build()

func _load_global_settings() -> void:
	_settings = {
		"amount": FX.reward_fx_amount(),
		"icon_size": int(round(FX.reward_fx_icon_size())),
		"trail_count": FX.reward_fx_trail_count(),
		"coin_size": int(round(FX.reward_fx_source_size())),
		"auto_replay": FX.reward_fx_auto_replay(),
	}

func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var bg := ColorRect.new()
	bg.name = "FxWorkbenchBackdrop"
	bg.color = Pal.SCREEN_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := HBoxContainer.new()
	root.name = "FxWorkbenchRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_make_sidebar())
	root.add_child(_make_stage())
	_build_fx_list()
	_rebuild_controls()
	_build_selected_preview()

	_auto_timer = Timer.new()
	_auto_timer.name = "AutoReplayTimer"
	_auto_timer.wait_time = 1.8
	_auto_timer.autostart = false
	_auto_timer.timeout.connect(func() -> void:
		if bool(_settings.get("auto_replay", false)):
			_play_selected())
	add_child(_auto_timer)
	if bool(_settings.get("auto_replay", false)):
		_auto_timer.start()

func _make_sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.name = "FxWorkbenchSidebar"
	panel.custom_minimum_size = Vector2(SIDEBAR_W, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color("#6F4D33"), 0, 0, Color.TRANSPARENT, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(body)

	body.add_child(_label("FX Workbench", 28, Pal.CREAM))
	var sub := _label("Pick an effect, tune it, and fire it in its game context.", 14, Color(Pal.CREAM, 0.76))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sub)

	var list_scroll := ScrollContainer.new()
	list_scroll.name = "FxListScroll"
	list_scroll.custom_minimum_size = Vector2(SIDEBAR_W - 36, 255)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(list_scroll)
	_fx_list = VBoxContainer.new()
	_fx_list.name = "FxList"
	_fx_list.add_theme_constant_override("separation", 8)
	_fx_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_fx_list)

	body.add_child(HSeparator.new())
	body.add_child(_label("Effect controls", 22, Pal.CREAM))
	var controls_scroll := ScrollContainer.new()
	controls_scroll.name = "FxControlsScroll"
	controls_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(controls_scroll)
	_controls = VBoxContainer.new()
	_controls.name = "FxControls"
	_controls.add_theme_constant_override("separation", 10)
	_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_scroll.add_child(_controls)
	return panel

func _make_stage() -> Control:
	var shell := PanelContainer.new()
	shell.name = "FxStageShell"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_stylebox_override("panel", _box(Pal.SCREEN_BG, 0, 0, Color.TRANSPARENT, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	shell.add_child(margin)

	var body := VBoxContainer.new()
	body.name = "FxStageBody"
	body.add_theme_constant_override("separation", 16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	body.add_child(header)
	header.add_child(_label("Live preview", 30, Pal.INK))
	var pill := PanelContainer.new()
	pill.name = "FxContextPill"
	pill.add_theme_stylebox_override("panel", _box(Pal.PILL, 16, 2, Pal.PILL_EDGE, 4))
	_context_label = _label("Board context", 16, Pal.INK)
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(_context_label)
	header.add_child(pill)

	var stage_panel := PanelContainer.new()
	stage_panel.name = "FxPreviewPanel"
	stage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_panel.add_theme_stylebox_override("panel", _box(Color("#E8DFC8"), 22, 2, Color(Pal.BARK, 0.18), 6))
	body.add_child(stage_panel)
	_preview_stage = CenterContainer.new()
	_preview_stage.name = "FxPreviewStage"
	_preview_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_panel.add_child(_preview_stage)
	return shell

func _build_fx_list() -> void:
	if _fx_list == null:
		return
	for c in _fx_list.get_children():
		_fx_list.remove_child(c)
		c.queue_free()
	for entry in FX_DEFS:
		var def: Dictionary = entry
		var fx_id: String = String(def["id"])
		var row := HBoxContainer.new()
		row.name = "FxRow_%s" % fx_id
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fx_list.add_child(row)

		var b := Button.new()
		b.text = String(def["label"])
		b.name = "FxList_%s" % fx_id
		b.tooltip_text = "%s preview" % String(def["screen"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 46)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_stylebox_override("normal", _button_box(fx_id == _selected_fx, false, not _is_fx_enabled(fx_id)))
		b.add_theme_stylebox_override("hover", _button_box(true, false, not _is_fx_enabled(fx_id)))
		b.add_theme_stylebox_override("pressed", _button_box(true, true, not _is_fx_enabled(fx_id)))
		b.add_theme_color_override("font_color", Pal.INK if _is_fx_enabled(fx_id) else Color(Pal.INK, 0.56))
		b.pressed.connect(func() -> void:
			_select_fx(fx_id))
		row.add_child(b)

		var toggle := CheckButton.new()
		toggle.name = "FxToggle_%s" % fx_id
		toggle.tooltip_text = "Toggle %s" % String(def["label"])
		toggle.button_pressed = _is_fx_enabled(fx_id)
		toggle.custom_minimum_size = Vector2(58, 42)
		toggle.toggled.connect(func(on: bool) -> void:
			_set_fx_enabled(fx_id, on))
		row.add_child(toggle)

func _rebuild_controls() -> void:
	if _controls == null:
		return
	for c in _controls.get_children():
		_controls.remove_child(c)
		c.queue_free()
	var selected: Dictionary = _fx_def(_selected_fx)
	var meta := _label("%s / %s" % [String(selected.get("label", "Effect")), String(selected.get("screen", "Preview"))], 14, Color(Pal.CREAM, 0.78))
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls.add_child(meta)

	var selected_toggle := CheckButton.new()
	selected_toggle.name = "SelectedFxToggle"
	selected_toggle.text = "Effect on"
	selected_toggle.button_pressed = _is_fx_enabled(_selected_fx)
	selected_toggle.add_theme_color_override("font_color", Pal.CREAM)
	selected_toggle.add_theme_font_size_override("font_size", 16)
	selected_toggle.toggled.connect(func(on: bool) -> void:
		_set_fx_enabled(_selected_fx, on))
	_controls.add_child(selected_toggle)

	var replay := Button.new()
	replay.name = "ReplayButton"
	replay.text = "Replay"
	replay.disabled = not _is_fx_enabled(_selected_fx)
	replay.custom_minimum_size = Vector2(0, 44)
	replay.add_theme_font_size_override("font_size", 18)
	replay.add_theme_stylebox_override("normal", _box(Pal.BTN_PRIMARY if not replay.disabled else Color(Pal.CREAM, 0.18), 18, 2, Pal.BTN_PRIMARY_EDGE if not replay.disabled else Color(Pal.CREAM, 0.22), 5))
	replay.add_theme_stylebox_override("hover", _box(Pal.BTN_PRIMARY.lightened(0.08), 18, 2, Pal.BTN_PRIMARY_EDGE, 5))
	replay.add_theme_stylebox_override("pressed", _box(Pal.BTN_PRIMARY.darkened(0.12), 18, 2, Pal.BTN_PRIMARY_EDGE, 2))
	replay.add_theme_color_override("font_color", Pal.CREAM)
	replay.add_theme_color_override("font_disabled_color", Color(Pal.CREAM, 0.42))
	replay.pressed.connect(_play_selected)
	_controls.add_child(replay)

	_controls.add_child(_slider_row("Amount", "amount", FX.REWARD_FX_MIN_AMOUNT, FX.REWARD_FX_MAX_AMOUNT, 1))
	_controls.add_child(_slider_row("Icon size", "icon_size", FX.REWARD_FX_MIN_ICON_SIZE, FX.REWARD_FX_MAX_ICON_SIZE, 1))
	_controls.add_child(_slider_row("Trail count", "trail_count", FX.REWARD_FX_MIN_TRAIL_COUNT, FX.REWARD_FX_MAX_TRAIL_COUNT, 1))
	_controls.add_child(_slider_row("Source size", "coin_size", FX.REWARD_FX_MIN_SOURCE_SIZE, FX.REWARD_FX_MAX_SOURCE_SIZE, 1))
	var auto := CheckButton.new()
	auto.name = "AutoReplayToggle"
	auto.text = "Auto replay"
	auto.button_pressed = bool(_settings.get("auto_replay", false))
	auto.add_theme_color_override("font_color", Pal.CREAM)
	auto.add_theme_font_size_override("font_size", 16)
	auto.toggled.connect(func(on: bool) -> void:
		_settings["auto_replay"] = on
		FX.set_reward_fx_auto_replay(on)
		if _auto_timer != null:
			if on:
				_auto_timer.start()
			else:
				_auto_timer.stop())
	_controls.add_child(auto)

func _slider_row(label: String, key: String, min_value: float, max_value: float, step: float) -> Control:
	var row := VBoxContainer.new()
	row.name = "%sSliderRow" % _pascal_id(key)
	row.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	row.add_child(top)
	var l := _label(label, 15, Pal.CREAM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(l)
	var current_value: int = int(_settings.get(key, min_value))
	var value := _label(str(current_value), 15, Color(Pal.STRAW, 0.95))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(54, 0)
	top.add_child(value)
	var slider := HSlider.new()
	slider.name = "%sSlider" % _pascal_id(key)
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(current_value)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void:
		_set_global_setting(key, int(round(v)))
		value.text = str(int(_settings[key])))
	row.add_child(slider)
	return row

func _set_global_setting(key: String, value: int) -> void:
	_settings[key] = value
	match key:
		"amount":
			FX.set_reward_fx_amount(value)
		"icon_size":
			FX.set_reward_fx_icon_size(float(value))
		"trail_count":
			FX.set_reward_fx_trail_count(value)
		"coin_size":
			FX.set_reward_fx_source_size(float(value))
			_build_selected_preview()

func _select_fx(id: String) -> void:
	if id == _selected_fx:
		return
	_selected_fx = id
	_build_fx_list()
	_rebuild_controls()
	_build_selected_preview()

func _set_fx_enabled(id: String, on: bool) -> void:
	FX.set_reward_fx_enabled(id, on)
	_build_fx_list()
	_rebuild_controls()
	if id == _selected_fx:
		_build_selected_preview()

func _is_fx_enabled(id: String) -> bool:
	return FX.reward_fx_enabled(id)

func _build_selected_preview() -> void:
	var def: Dictionary = _fx_def(_selected_fx)
	if _context_label != null:
		_context_label.text = "%s context" % String(def.get("screen", "Preview"))
	_reset_preview(_pascal_id(_selected_fx) + "Preview")
	var context: String = String(def.get("context", "board"))
	match context:
		"map":
			_preview_root.add_child(_map_backdrop())
			_add_preview_hud("FX Map", _targets_for(def))
			_add_map_surface(def)
		"home":
			_preview_root.add_child(_home_backdrop())
			_add_preview_hud("FX Home", _targets_for(def))
			_add_home_surface(def)
		_:
			_preview_root.add_child(_field_backdrop())
			_add_preview_hud("FX Board", _targets_for(def))
			_add_board_surface(def)
	_add_bottom_bar(String(def.get("footer", "")))
	if not _is_fx_enabled(_selected_fx):
		_show_disabled_badge()

func _reset_preview(name_text: String) -> void:
	if _preview_stage == null:
		return
	for c in _preview_stage.get_children():
		_preview_stage.remove_child(c)
		c.queue_free()
	_targets.clear()
	_target_labels.clear()
	_source = null
	_preview_root = Control.new()
	_preview_root.name = name_text
	_preview_root.custom_minimum_size = Vector2(PREVIEW_W, PREVIEW_H)
	_preview_root.size = Vector2(PREVIEW_W, PREVIEW_H)
	_preview_root.clip_contents = true
	_preview_stage.add_child(_preview_root)

func _targets_for(def: Dictionary) -> Array:
	var targets: Array = def.get("targets", [])
	return targets

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
	c.name = "BoardFieldBackdrop"
	c.color = Pal.SURFACE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _map_backdrop() -> Control:
	var c := ColorRect.new()
	c.name = "MapPreviewBackdrop"
	c.color = Color("#A8C37A")
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _home_backdrop() -> Control:
	var c := ColorRect.new()
	c.name = "HomePreviewBackdrop"
	c.color = Color("#D7C89F")
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _add_preview_hud(title_text: String, target_ids: Array) -> void:
	var title := Look.title_ribbon(title_text, 24)
	title.name = "PreviewTitle"
	title.position = Vector2(26, 24)
	_preview_root.add_child(title)

	var x := PREVIEW_W - 34.0
	for target in target_ids:
		var id: String = String(target)
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
	var total: int = int(_totals.get(id, 0))
	var lbl := _label(str(total), 25, Pal.INK)
	lbl.name = "%sWalletAmount" % _pascal_id(id)
	row.add_child(lbl)
	_target_labels[id] = lbl
	return chip

func _add_board_surface(def: Dictionary) -> void:
	var holder := Control.new()
	holder.name = "FxBoardSurface"
	holder.position = Vector2(42, 170)
	holder.size = Vector2(PREVIEW_W - 84, 610)
	_preview_root.add_child(holder)

	var mat := PieceView.make_board_mat(holder.size.x - 28, holder.size.y - 28)
	mat.name = "FxBoardMat"
	mat.position += Vector2(14, 14)
	holder.add_child(mat)

	var grid := Control.new()
	grid.name = "FxBoardGrid"
	grid.position = Vector2(40, 58)
	grid.size = Vector2(holder.size.x - 80, holder.size.y - 116)
	holder.add_child(grid)
	_add_board_cells(grid, 4, 5)

	var source_kind: String = String(def.get("source_kind", "coin_piece"))
	var source_pos := Vector2(grid.size.x * 0.5, grid.size.y * 0.52)
	match source_kind:
		"coin_piece":
			_source = _make_piece_source("CoinPickupPiece", COIN_CODE, float(_settings.get("coin_size", 112)))
		"item_piece":
			_source = _make_piece_source("StashToBagPiece", SAMPLE_ITEM_A, float(_settings.get("coin_size", 112)))
		"quest":
			_source = _make_action_card("FxSource_%s" % _selected_fx, "Quest", "coin", "Claim")
		"offer":
			_source = _make_action_card("FxSource_%s" % _selected_fx, "2x", "coin", "Accept")
		_:
			_source = _make_source_button("FxSource_%s" % _selected_fx, String(def.get("source_label", "Play")))
	if _source != null:
		_source.position = source_pos - _source.size / 2.0
		_wire_source(_source)
		grid.add_child(_source)

	var hint := _label(_hint_for(def), 18, Pal.INK)
	hint.name = "FxPreviewHint"
	hint.position = Vector2(0, holder.size.y - 28)
	hint.size = Vector2(holder.size.x, 28)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(hint)

func _add_board_cells(grid: Control, cols: int, rows: int) -> void:
	var gap := 10.0
	var source_px := float(_settings.get("coin_size", 112))
	var cell := clampf(source_px + 16.0, 92.0, 134.0)
	var grid_w := cols * cell + (cols - 1) * gap
	var grid_h := rows * cell + (rows - 1) * gap
	var start := (grid.size - Vector2(grid_w, grid_h)) / 2.0
	for y in rows:
		for x in cols:
			var well := Panel.new()
			well.name = "FxBoardCell_%d_%d" % [x, y]
			well.position = start + Vector2(x * (cell + gap), y * (cell + gap))
			well.size = Vector2(cell, cell)
			well.add_theme_stylebox_override("panel", _cell_box())
			well.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(well)

func _add_map_surface(def: Dictionary) -> void:
	var trail := Panel.new()
	trail.name = "FxMapTrail"
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
			_source.name = "FxSource_%s" % _selected_fx
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
	row.add_child(_label(text, 22, Pal.INK))
	if active:
		row.add_child(_label("Ready", 18, Pal.BTN_PRIMARY))
	return card

func _add_home_surface(def: Dictionary) -> void:
	var floor := Panel.new()
	floor.name = "FxHomeFloor"
	floor.position = Vector2(70, 156)
	floor.size = Vector2(PREVIEW_W - 140, 650)
	floor.add_theme_stylebox_override("panel", _box(Color("#E6D7AD"), 34, 3, Color(Pal.BARK, 0.34), 6))
	_preview_root.add_child(floor)

	var stall := _make_action_card("FxShopStall", "Market", "cart", "Sell basket")
	stall.position = Vector2(72, 64)
	floor.add_child(stall)
	var item := _make_piece_source("SalePayoutItem", SAMPLE_ITEM_B, float(_settings.get("coin_size", 112)))
	item.position = Vector2((floor.size.x - item.size.x) / 2.0, 298)
	_source = item
	_wire_source(_source)
	floor.add_child(_source)

func _make_piece_source(name_text: String, code: int, px: float) -> Control:
	var piece := PieceView.make_piece(code, px)
	piece.name = name_text
	piece.size = Vector2(px, px)
	piece.custom_minimum_size = Vector2(px, px)
	piece.mouse_filter = Control.MOUSE_FILTER_STOP
	return piece

func _make_source_button(name_text: String, text: String) -> Button:
	var b := Button.new()
	b.name = name_text
	b.text = text
	b.size = Vector2(164, 72)
	b.custom_minimum_size = b.size
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_stylebox_override("normal", _box(Pal.BTN_PRIMARY, 22, 2, Pal.BTN_PRIMARY_EDGE, 6))
	b.add_theme_stylebox_override("hover", _box(Pal.BTN_PRIMARY.lightened(0.08), 22, 2, Pal.BTN_PRIMARY_EDGE, 6))
	b.add_theme_stylebox_override("pressed", _box(Pal.BTN_PRIMARY.darkened(0.12), 22, 2, Pal.BTN_PRIMARY_EDGE, 3))
	b.add_theme_color_override("font_color", Pal.CREAM)
	return b

func _make_action_card(name_text: String, title: String, icon_id: String, caption: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = name_text
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
	top.add_child(_label(title, 25, Pal.INK))
	var cap := _label(caption, 16, Color(Pal.INK, 0.72))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	return card

func _wire_source(source: Control) -> void:
	if source is Button:
		(source as Button).pressed.connect(_play_selected)
	else:
		source.mouse_filter = Control.MOUSE_FILTER_STOP
		source.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_play_selected())

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
	row.add_child(Look.icon(String(_fx_def(_selected_fx).get("target", "coin")), 30))
	var txt := _label(text, 20, Pal.INK)
	row.add_child(txt)

func _hint_for(def: Dictionary) -> String:
	var kind: String = String(def.get("source_kind", ""))
	match kind:
		"coin_piece":
			return "Tap the coin"
		"item_piece":
			return "Tap the item"
		"quest":
			return "Tap the quest chip"
		"offer":
			return "Tap the 2x offer"
		_:
			return "Tap the source"

func _play_selected() -> void:
	if not _is_fx_enabled(_selected_fx):
		_show_disabled_badge()
		return
	var def: Dictionary = _fx_def(_selected_fx)
	match _selected_fx:
		"map_task_reward":
			_play_reward("gem", 1, Color("#A9C7E8"), "gem", Vector2(0, -12))
			_play_reward("coin", int(_settings.get("amount", 25)), Color("#E3B23C"), "coin", Vector2(0, 28))
		"stash_to_bag":
			_play_reward("bag", 1, Pal.STRAW, "bag")
		_:
			var icon_id: String = String(def.get("icon", "coin"))
			var target_id: String = String(def.get("target", "coin"))
			var amount: int = _reward_amount_for(_selected_fx)
			_play_reward(icon_id, amount, _reward_color(icon_id), target_id)

func _play_coin_pickup() -> void:
	_select_fx("coin_pickup")
	_play_selected()

func _play_reward(icon_id: String, amount: int, color: Color, target_id: String, offset: Vector2 = Vector2.ZERO) -> void:
	if _preview_root == null or _source == null:
		return
	_clear_disabled_badges()
	var target: Control = _targets.get(target_id, null) as Control
	var from := _source.get_global_rect().get_center() + offset
	var icon_size := float(_settings.get("icon_size", 42))
	var trail_count := int(_settings.get("trail_count", 2))
	var self_ref: WeakRef = weakref(self)
	var done: Callable = func() -> void:
		var live: Object = self_ref.get_ref()
		if live != null and is_instance_valid(live):
			live.call("_finish_reward", target_id, amount)
	FX.reward_arrival(self, from, icon_id, amount, color, target, done, icon_size, "+", trail_count, _selected_fx)

func _finish_reward(target_id: String, amount: int) -> void:
	var current: int = int(_totals.get(target_id, 0))
	_totals[target_id] = current + amount
	_update_target_label(target_id)
	if _source != null and is_instance_valid(_source):
		FX.pop(_source)

func _update_target_label(target_id: String) -> void:
	var lbl: Label = _target_labels.get(target_id, null) as Label
	if lbl != null and is_instance_valid(lbl):
		lbl.text = str(int(_totals.get(target_id, 0)))

func _reward_amount_for(id: String) -> int:
	match id:
		"stash_to_bag":
			return 1
		_:
			return int(_settings.get("amount", 25))

func _reward_color(icon_id: String) -> Color:
	match icon_id:
		"gem":
			return Color("#A9C7E8")
		"water":
			return Color("#9CCDE8")
		"bag":
			return Pal.STRAW
		_:
			return Color("#E3B23C")

func _show_disabled_badge() -> void:
	_clear_disabled_badges()
	if _preview_root == null:
		return
	var badge := PanelContainer.new()
	badge.name = "FxDisabledBadge"
	badge.position = Vector2((PREVIEW_W - 210) / 2.0, 114)
	badge.size = Vector2(210, 56)
	badge.add_theme_stylebox_override("panel", _box(Color(Pal.INK, 0.82), 20, 2, Color(Pal.CREAM, 0.22), 8))
	var label := _label("Effect off", 20, Pal.CREAM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)
	_preview_root.add_child(badge)
	if _source != null and is_instance_valid(_source):
		FX.wobble(_source)

func _clear_disabled_badges() -> void:
	if _preview_root == null:
		return
	for n in _preview_root.find_children("FxDisabledBadge", "PanelContainer", true, false):
		var node := n as Node
		var parent := node.get_parent()
		if parent != null:
			parent.remove_child(node)
		node.queue_free()

func _clear_runtime_fx() -> void:
	for n in find_children("RewardArrival*", "Control", true, false):
		var node := n as Node
		var parent := node.get_parent()
		if parent != null:
			parent.remove_child(node)
		node.queue_free()

func _fx_def(id: String) -> Dictionary:
	for entry in FX_DEFS:
		var def: Dictionary = entry
		if String(def["id"]) == id:
			return def
	var fallback: Dictionary = FX_DEFS[0]
	return fallback

func _label(text: String, px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _box(bg: Color, radius: int, border_w: int, border: Color, shadow: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.18)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, maxf(2.0, shadow * 0.45))
	return sb

func _button_box(selected: bool, pressed: bool, off: bool = false) -> StyleBoxFlat:
	if off:
		return _box(Color("#B8A68F") if selected else Color("#8A6D52"), 16, 1, Color(Pal.CREAM, 0.16), 0)
	if selected:
		return _box(Pal.PILL if not pressed else Pal.PILL.darkened(0.08), 16, 2, Pal.STRAW, 4)
	return _box(Color(Pal.CREAM, 0.13), 16, 1, Color(Pal.CREAM, 0.18), 0)

func _cell_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.CELL_EMPTY
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(Pal.GROUND_EDGE, 0.9)
	sb.shadow_color = Color(0, 0, 0, 0.08)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(0, 1)
	return sb

func _pascal_id(id: String) -> String:
	var out := ""
	for part in id.split("_"):
		out += String(part).capitalize().replace(" ", "")
	return out
