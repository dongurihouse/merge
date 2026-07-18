@tool
extends Control
## Standalone, reference-sized reconstruction of the Maps mock's three currency pills.
##
## This study deliberately does not import the live HUD or the UI Workbench kit. The shell,
## currency glyphs, plus token, and paper background are authored Meadow Sky art; fixed layout,
## live amounts, and the shallow structural-slate shadow remain native Godot controls.

const DESIGN_SIZE := Vector2(941, 160)
const PAPER_ROOT := "res://games/grove/assets/ui/meadow_v2/"
const SHELL_PATH := PAPER_ROOT + "resource_pill.png"
const PLUS_PATH := PAPER_ROOT + "button_plus.png"
const INK := Color("#243B4B")
const SHADOW_TINT := Color("#294654", 0.20)
const PATCH_MARGIN := 52
const AMOUNT_FONT_SIZE := 42

const PILL_SPECS := [
	{
		"name": "WaterPill",
		"position": Vector2(133, 20),
		"size": Vector2(234, 80),
		"icon": PAPER_ROOT + "water_drop.png",
		"icon_rect": Rect2(27, 3, 70, 70),
		"plus_rect": Rect2(67, 41, 35, 35),
		"amount": "100",
		"amount_rect": Rect2(98, 7, 96, 68),
	},
	{
		"name": "CoinPill",
		"position": Vector2(382, 20),
		"size": Vector2(227, 80),
		"icon": PAPER_ROOT + "coin.png",
		"icon_rect": Rect2(26, 3, 70, 70),
		"plus_rect": Rect2(68, 41, 35, 35),
		"amount": "50",
		"amount_rect": Rect2(107, 7, 84, 68),
	},
	{
		"name": "AcornPill",
		"position": Vector2(624, 20),
		"size": Vector2(226, 80),
		"icon": PAPER_ROOT + "acorn.png",
		"icon_rect": Rect2(26, 3, 70, 70),
		"plus_rect": Rect2(67, 41, 35, 35),
		"amount": "5",
		"amount_rect": Rect2(107, 7, 62, 68),
	},
]

@onready var _stage: Control = $Stage
@onready var _wallet: Control = $Stage/Wallet


func _ready() -> void:
	theme = _make_study_theme()
	_build_wallet()
	_fit_stage()
	if not resized.is_connected(_fit_stage):
		resized.connect(_fit_stage)


func canvas_size() -> Vector2:
	return DESIGN_SIZE


func pill_specs() -> Array:
	return PILL_SPECS.duplicate(true)


func _build_wallet() -> void:
	for child in _wallet.get_children():
		child.free()
	for spec in PILL_SPECS:
		_wallet.add_child(_make_pill(spec))


func _make_pill(spec: Dictionary) -> Control:
	var pill := Control.new()
	pill.name = String(spec.name)
	pill.position = spec.position
	pill.size = spec.size
	pill.custom_minimum_size = spec.size
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shadow := Panel.new()
	shadow.name = "Shadow"
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", _shadow_style())
	pill.add_child(shadow)

	var shell := Panel.new()
	shell.name = "Shell"
	shell.add_theme_stylebox_override("panel", _shell_style())
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(shell)

	var icon := _art_rect("Icon", String(spec.icon), spec.icon_rect)
	pill.add_child(icon)

	var plus := _art_rect("Plus", PLUS_PATH, spec.plus_rect)
	plus.z_index = 2
	pill.add_child(plus)

	var amount_rect: Rect2 = spec.amount_rect
	var amount := Label.new()
	amount.name = "Amount"
	amount.text = String(spec.amount)
	amount.position = amount_rect.position
	amount.size = amount_rect.size
	amount.add_theme_font_size_override("font_size", AMOUNT_FONT_SIZE)
	amount.add_theme_color_override("font_color", INK)
	amount.add_theme_constant_override("outline_size", 0)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(amount)
	return pill


func _art_rect(node_name: String, path: String, rect: Rect2) -> TextureRect:
	var art := TextureRect.new()
	art.name = node_name
	art.texture = load(path) as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = rect.position
	art.size = rect.size
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


func _shadow_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.shadow_color = SHADOW_TINT
	style.shadow_size = 3
	style.shadow_offset = Vector2(1, 4)
	style.set_corner_radius_all(40)
	return style


func _shell_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(SHELL_PATH) as Texture2D
	style.set_texture_margin(SIDE_LEFT, PATCH_MARGIN)
	style.set_texture_margin(SIDE_TOP, PATCH_MARGIN)
	style.set_texture_margin(SIDE_RIGHT, PATCH_MARGIN)
	style.set_texture_margin(SIDE_BOTTOM, PATCH_MARGIN)
	return style


func _make_study_theme() -> Theme:
	var face := SystemFont.new()
	face.font_names = PackedStringArray([
		"Arial Rounded MT Bold", "SF Pro Rounded", "Chalkboard SE", "Verdana", "Arial",
	])
	face.font_weight = 700
	face.generate_mipmaps = true
	var study_theme := Theme.new()
	study_theme.default_font = face
	study_theme.default_font_size = AMOUNT_FONT_SIZE
	return study_theme


func _fit_stage() -> void:
	if _stage == null:
		return
	var available := size
	if available.x <= 0.0 or available.y <= 0.0:
		available = DESIGN_SIZE
	var factor := minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y)
	_stage.size = DESIGN_SIZE
	_stage.scale = Vector2.ONE * factor
	_stage.position = (available - DESIGN_SIZE * factor) * 0.5
