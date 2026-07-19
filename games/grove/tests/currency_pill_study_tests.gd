extends SceneTree

const SCENE_PATH := "res://games/grove/tools/CurrencyPillStudy.tscn"
const SCRIPT_PATH := "res://games/grove/tools/currency_pill_study.gd"
const SHOT_PATH := "res://games/grove/tools/currency_pill_study_shot.gd"
const INK := Color("#243B4B")
const SHADOW_TINT := Color("#294654")
const SHELL_FILL := Color("#F6EBDD")
const SHELL_EDGE := Color("#3F6D7D")

var passed := 0
var failed := 0


func ok(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  PASS  %s" % message)
	else:
		failed += 1
		print("  FAIL  %s" % message)


func near_vec(actual: Vector2, expected: Vector2, tolerance := 0.01) -> bool:
	return actual.distance_to(expected) <= tolerance


func same_rgb(actual: Color, expected: Color, tolerance := 0.002) -> bool:
	return absf(actual.r - expected.r) <= tolerance \
		and absf(actual.g - expected.g) <= tolerance \
		and absf(actual.b - expected.b) <= tolerance


func _initialize() -> void:
	print("== Standalone currency-pill study tests ==")
	ok(ResourceLoader.exists(SCENE_PATH), "standalone currency-pill scene exists")
	ok(FileAccess.file_exists(SCRIPT_PATH), "standalone currency-pill scene owns a dedicated script")
	ok(FileAccess.file_exists(SHOT_PATH), "standalone currency-pill scene owns an isolated screenshot runner")
	if not ResourceLoader.exists(SCENE_PATH) or not FileAccess.file_exists(SCRIPT_PATH):
		_finish()
		return

	var source := FileAccess.get_file_as_string(SCRIPT_PATH)
	ok(source.find("ui_workbench_kit") == -1 and source.find("action_bar") == -1 \
		and source.find("engine/scenes/Board") == -1 and source.find("hud.gd") == -1,
		"study is isolated from the existing game wallet and board UI")
	ok(source.find("resource_pill.png") == -1 and source.find("StyleBoxTexture") == -1,
		"pill shell does not reuse or nine-slice a pre-cut capsule image")
	if FileAccess.file_exists(SHOT_PATH):
		var shot_source := FileAccess.get_file_as_string(SHOT_PATH)
		ok(shot_source.find(SCENE_PATH) != -1 and shot_source.find("Vector2i(941, 160)") != -1,
			"screenshot runner captures the scene at its native mock dimensions")

	var scene := load(SCENE_PATH).instantiate() as Control
	root.add_child(scene)
	await process_frame
	await process_frame

	var stage := scene.get_node_or_null("Stage") as Control
	ok(stage != null and near_vec(stage.size, Vector2(941, 160)),
		"study preserves the mock's 941px reference width")
	var sky := stage.get_node_or_null("PaperSky") as TextureRect if stage != null else null
	ok(sky != null and sky.texture != null \
		and String(sky.texture.resource_path).ends_with("ui/meadow_v2/texture_sky.png"),
		"standalone backdrop uses the Meadow Sky paper texture")

	var expected := {
		"WaterPill": {
			"position": Vector2(133, 20), "size": Vector2(234, 80),
			"icon": "water_drop.png", "amount": "100",
			"icon_rect": Rect2(27, 3, 70, 70), "plus_rect": Rect2(67, 41, 35, 35),
			"amount_rect": Rect2(98, 7, 96, 68),
		},
		"CoinPill": {
			"position": Vector2(382, 20), "size": Vector2(227, 80),
			"icon": "coin.png", "amount": "50",
			"icon_rect": Rect2(26, 3, 70, 70), "plus_rect": Rect2(68, 41, 35, 35),
			"amount_rect": Rect2(107, 7, 84, 68),
		},
		"AcornPill": {
			"position": Vector2(624, 20), "size": Vector2(226, 80),
			"icon": "acorn.png", "amount": "5",
			"icon_rect": Rect2(26, 3, 70, 70), "plus_rect": Rect2(67, 41, 35, 35),
			"amount_rect": Rect2(107, 7, 62, 68),
		},
	}

	var wallet := stage.get_node_or_null("Wallet") as Control if stage != null else null
	ok(wallet != null and wallet.get_child_count() == 3,
		"wallet study contains exactly the three reference pills")
	for pill_name in expected:
		var spec: Dictionary = expected[pill_name]
		var pill := wallet.get_node_or_null(pill_name) as Control if wallet != null else null
		ok(pill != null, "%s exists" % pill_name)
		if pill == null:
			continue
		ok(near_vec(pill.position, spec.position) and near_vec(pill.size, spec.size),
			"%s matches measured mock position and size" % pill_name)

		var shadow := pill.get_node_or_null("Shadow") as Panel
		var shadow_style := shadow.get_theme_stylebox("panel") as StyleBoxFlat if shadow != null else null
		ok(shadow_style != null and same_rgb(shadow_style.shadow_color, SHADOW_TINT) \
			and absf(shadow_style.shadow_color.a - 0.20) <= 0.01 \
			and shadow_style.shadow_size == 10 and near_vec(shadow_style.shadow_offset, Vector2(2, 6)),
			"%s casts THE uniform slate shadow" % pill_name)

		var shell := pill.get_node_or_null("Shell") as Panel
		var shell_style := shell.get_theme_stylebox("panel") as StyleBoxFlat if shell != null else null
		ok(shell_style != null and same_rgb(shell_style.bg_color, SHELL_FILL) \
			and same_rgb(shell_style.border_color, SHELL_EDGE) \
			and absf(shell_style.border_color.a - 0.35) <= 0.002 \
			and shell_style.get_border_width(SIDE_LEFT) == 1 \
			and shell_style.get_border_width(SIDE_TOP) == 1 \
			and shell_style.get_border_width(SIDE_RIGHT) == 1 \
			and shell_style.get_border_width(SIDE_BOTTOM) == 1 \
			and shell_style.get_corner_radius(CORNER_TOP_LEFT) == 28 \
			and shell_style.get_corner_radius(CORNER_TOP_RIGHT) == 28 \
			and shell_style.get_corner_radius(CORNER_BOTTOM_LEFT) == 28 \
			and shell_style.get_corner_radius(CORNER_BOTTOM_RIGHT) == 28 \
			and near_vec(shell.size, pill.size),
			"%s draws its rounded fill, edge, and radius in code" % pill_name)

		var paper := pill.get_node_or_null("PaperTexture") as TextureRect
		var paper_material := paper.material as ShaderMaterial if paper != null else null
		var paper_shader := paper_material.shader if paper_material != null else null
		var paper_size: Vector2 = spec.size - Vector2(4, 4)
		ok(paper != null and paper.texture != null \
			and String(paper.texture.resource_path).ends_with("ui/meadow_v2/texture_cream.png") \
			and near_vec(paper.position, Vector2(2, 2)) \
			and near_vec(paper.size, paper_size) \
			and paper_material != null and paper_shader != null \
			and String(paper_shader.code).find("rounded_box_distance") != -1 \
			and near_vec(paper_material.get_shader_parameter("control_size"), paper_size) \
			and absf(float(paper_material.get_shader_parameter("radius_px")) - 26.0) <= 0.01,
			"%s masks the flat cream paper texture with code-defined pill geometry" % pill_name)

		var icon := pill.get_node_or_null("Icon") as TextureRect
		ok(icon != null and icon.texture != null \
			and String(icon.texture.resource_path).ends_with("ui/meadow_v2/%s" % spec.icon) \
			and Rect2(icon.position, icon.size) == spec.icon_rect,
			"%s uses the reference currency art at measured scale" % pill_name)

		var plus := pill.get_node_or_null("Plus") as TextureRect
		ok(plus != null and plus.texture != null \
			and String(plus.texture.resource_path).ends_with("ui/meadow_v2/button_plus.png") \
			and Rect2(plus.position, plus.size) == spec.plus_rect,
			"%s overlays the 35px paper plus token on the icon" % pill_name)

		var amount := pill.get_node_or_null("Amount") as Label
		ok(amount != null and amount.text == spec.amount \
			and amount.get_theme_font_size("font_size") == preload(SCRIPT_PATH).AMOUNT_FONT_SIZE \
			and same_rgb(amount.get_theme_color("font_color"), INK) \
			and amount.get_theme_constant("outline_size") == 0 \
			and amount.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT \
			and Rect2(amount.position, amount.size) == spec.amount_rect,
			"%s keeps the live number code-drawn in the mock's ink, size, and placement" % pill_name)

	scene.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("== %d passed, %d failed ==" % [passed, failed])
	quit(0 if failed == 0 else 1)
