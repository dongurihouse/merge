@tool
extends Control
## Standalone, reference-sized reconstruction of the Maps mock's three currency pills.
##
## This study deliberately does not import the live HUD or the UI Workbench kit. The currency
## glyphs, plus token, and flat paper grain are authored Meadow Sky art; the pill geometry,
## edge, shadow, fixed layout, and live amounts remain native Godot controls.

const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Look = preload("res://engine/scripts/ui/skin.gd")
const DESIGN_SIZE := Vector2(941, 160)
const PAPER_ROOT := "res://games/grove/assets/ui/meadow_v2/"
const PAPER_TEXTURE_PATH := PAPER_ROOT + "texture_cream.png"
const PLUS_PATH := PAPER_ROOT + "button_plus.png"
const INK := Color("#243B4B")
const SHELL_FILL := Color("#F6EBDD")
const SHELL_EDGE := Color("#3F6D7D", 0.35)
const SHELL_RADIUS := 28
const PAPER_INSET := 2.0
const PAPER_RADIUS := 26.0
const AMOUNT_FONT_SIZE := FS.TITLE

const PAPER_MASK_SHADER := """
shader_type canvas_item;

uniform vec2 control_size = vec2(1.0);
uniform float radius_px = 1.0;
uniform float feather_px = 1.0;

float rounded_box_distance(vec2 point, vec2 half_size, float radius) {
	vec2 q = abs(point) - half_size + vec2(radius);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}

void fragment() {
	vec4 paper = texture(TEXTURE, UV);
	float distance_to_edge = rounded_box_distance(
		(UV - vec2(0.5)) * control_size,
		control_size * 0.5,
		radius_px
	);
	float mask = 1.0 - smoothstep(-feather_px, feather_px, distance_to_edge);
	COLOR = vec4(paper.rgb, paper.a * mask);
}
"""

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
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(shell)

	var paper := _paper_texture(spec.size)
	pill.add_child(paper)

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
	Look.apply_box_shadow(style)
	style.set_corner_radius_all(SHELL_RADIUS)
	return style


func _shell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SHELL_FILL
	style.border_color = SHELL_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(SHELL_RADIUS)
	style.anti_aliasing = true
	return style


func _paper_texture(pill_size: Vector2) -> TextureRect:
	var paper := TextureRect.new()
	paper.name = "PaperTexture"
	paper.texture = load(PAPER_TEXTURE_PATH) as Texture2D
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.position = Vector2.ONE * PAPER_INSET
	paper.size = pill_size - Vector2.ONE * PAPER_INSET * 2.0
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = PAPER_MASK_SHADER
	var mask := ShaderMaterial.new()
	mask.shader = shader
	mask.set_shader_parameter("control_size", paper.size)
	mask.set_shader_parameter("radius_px", PAPER_RADIUS)
	mask.set_shader_parameter("feather_px", 1.0)
	paper.material = mask
	return paper


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
