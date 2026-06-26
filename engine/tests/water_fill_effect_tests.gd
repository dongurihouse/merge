extends SceneTree
## Headless tests for the code-drawn water fill FX component.
##   godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd

const WaterFillEffect = preload("res://engine/scripts/ui/water_fill_effect.gd")
const VaseWaterEffect = preload("res://engine/scripts/ui/vase_water_effect.gd")
const BoardScene = preload("res://engine/scripts/scenes/board.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const SCENE_PATH := "res://engine/tools/WaterFillDemo.tscn"
const VASE_SCENE_PATH := "res://engine/tools/VaseWaterDemo.tscn"

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func fresh(name: String) -> void:
	var dir := "user://tu_water_fill_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _has_button(node: Node) -> bool:
	if node is Button:
		return true
	for child in node.get_children():
		if _has_button(child):
			return true
	return false

func _has_card_frame(node: Node) -> bool:
	if node is NinePatchRect or node is Panel:
		return true
	for child in node.get_children():
		if _has_card_frame(child):
			return true
	return false

func _find_label(node: Node, label_name: String) -> Label:
	if node is Label and node.name == label_name:
		return node
	for child in node.get_children():
		var found := _find_label(child, label_name)
		if found != null:
			return found
	return null

func _has_label_text(node: Node, text: String) -> bool:
	if node is Label and node.text == text:
		return true
	for child in node.get_children():
		if _has_label_text(child, text):
			return true
	return false

func _control_rect(control: Control) -> Rect2:
	return Rect2(control.position, control.size)

func _read_text_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text

func _initialize() -> void:
	var fx: Control = WaterFillEffect.new()
	fx.size = Vector2(640, 520)
	root.add_child(fx)
	await process_frame

	ok(is_equal_approx(fx.energy_for_test(), WaterFillEffect.IDLE_ENERGY),
		"starts at idle wave energy")

	fx.trigger_impact_for_test()
	ok(fx.energy_for_test() > WaterFillEffect.IDLE_ENERGY * 3.0,
		"impact injects substantially more wave energy")

	var center_wave: float = fx.wave_height_for_test(0.5)
	var edge_wave: float = fx.wave_height_for_test(0.1)
	ok(absf(center_wave - edge_wave) > 3.0,
		"impact wave is localized around the droplet hit point")

	for i in 180:
		fx.advance_for_test(1.0 / 60.0)
	ok(fx.energy_for_test() < WaterFillEffect.IDLE_ENERGY + 0.8,
		"wave energy damps back near idle")

	fx.set_time_for_test(0.9)
	var growing: Dictionary = fx.drop_state_for_test()
	ok(bool(growing.visible) and float(growing.radius) > 7.0,
		"droplet grows before falling")

	fx.set_time_for_test(1.8)
	var falling: Dictionary = fx.drop_state_for_test()
	ok(bool(falling.visible) and float(falling.y) > float(growing.y),
		"droplet falls downward after growing")

	fx.set_time_for_test(2.25)
	var after_hit: Dictionary = fx.drop_state_for_test()
	ok(not bool(after_hit.visible),
		"droplet disappears into the water after impact")

	fx.queue_free()

	ok(ResourceLoader.exists(SCENE_PATH), "editor-openable water demo scene exists")
	var packed := load(SCENE_PATH) as PackedScene
	ok(packed != null, "water demo scene loads as a PackedScene")
	if packed != null:
		var scene := packed.instantiate() as Control
		ok(scene != null and scene.name == "WaterFillDemo", "water demo scene instantiates as WaterFillDemo")
		if scene != null:
			root.add_child(scene)
			await process_frame
			ok(scene.find_child("WaterFillEffect", true, false) is Control,
				"water demo scene contains the animated water effect")
			scene.queue_free()

	ok(VaseWaterEffect.VASE_PATH.ends_with("vase_acorn.png"), "vase water effect uses the acorn vase art")
	ok(ResourceLoader.exists(VaseWaterEffect.VASE_PATH), "acorn vase sprite exists")
	ok(ResourceLoader.exists(VaseWaterEffect.MASK_PATH), "acorn vase water mask exists")
	var vase_fx: Control = VaseWaterEffect.new()
	vase_fx.size = Vector2(360, 420)
	root.add_child(vase_fx)
	await process_frame
	ok(vase_fx.get_texture_for_test() != null, "vase water effect loads the vase texture")
	ok(vase_fx.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"vase water effect requests smooth mipmap texture filtering")
	var vase_import_text := _read_text_file(VaseWaterEffect.VASE_PATH + ".import")
	ok(vase_import_text.contains("mipmaps/generate=true"), "acorn vase import generates mipmaps")
	ok(vase_fx.has_method("visible_vase_rect_for_test"), "vase water effect exposes visible art bounds")
	if vase_fx.has_method("visible_vase_rect_for_test"):
		var visible_vase_rect: Rect2 = vase_fx.call("visible_vase_rect_for_test")
		ok(visible_vase_rect.size.y >= vase_fx.size.y * 0.96, "visible vase art fills the control height")
		ok(visible_vase_rect.position.y <= vase_fx.size.y * 0.02, "visible vase art starts at the top of the control")
	ok(vase_fx.get_mask_texture_for_test() != null, "vase water effect loads the water mask texture")
	ok(vase_fx.has_method("ready_glow_style_for_test"), "vase ready glow exposes its style for tests")
	if vase_fx.has_method("ready_glow_style_for_test"):
		var glow_style: Dictionary = vase_fx.call("ready_glow_style_for_test")
		ok(glow_style.get("tone", "") == "gold", "vase ready glow is gold-toned")
		ok(int(glow_style.get("soft_layers", 0)) >= 3, "vase ready glow uses layered soft fills")
		ok(int(glow_style.get("hard_rings", -1)) == 0, "vase ready glow avoids hard outline rings")
	var calm_surface: PackedVector2Array = vase_fx.water_surface_for_test()
	ok(calm_surface.size() >= 12, "vase water effect exposes a sampled water surface")
	if vase_fx.has_method("visible_vase_rect_for_test"):
		var mask_clip_rect: Rect2 = vase_fx.call("visible_vase_rect_for_test")
		ok(calm_surface[0].x > mask_clip_rect.position.x + mask_clip_rect.size.x * 0.02
				and calm_surface[calm_surface.size() - 1].x < mask_clip_rect.end.x - mask_clip_rect.size.x * 0.02,
			"vase water surface is clipped to the mask span")
	vase_fx.set_progress_for_test(0.0)
	var empty_line: float = vase_fx.waterline_y_for_test()
	vase_fx.set_progress_for_test(1.0)
	var full_line: float = vase_fx.waterline_y_for_test()
	ok(full_line < empty_line, "vase water progress raises the waterline")
	vase_fx.set_progress_for_test(0.2)
	vase_fx.animate_progress_for_test(0.7)
	for i in 20:
		await process_frame
	ok(vase_fx.progress_for_test() > 0.2, "vase water animates progress upward")
	vase_fx.set_progress_for_test(0.2)
	vase_fx.animate_progress_for_test(0.8)
	ok(vase_fx.energy_for_test() > VaseWaterEffect.IDLE_ENERGY + 7.0,
		"vase water fill animation injects stronger wave energy")
	ok(vase_fx.has_method("advance_for_test"), "vase water effect exposes idle advance for droplet gating")
	if vase_fx.has_method("advance_for_test"):
		vase_fx.set_time_for_test(0.0)
		vase_fx.call("advance_for_test", VaseWaterEffect.IMPACT_TIME + 0.08)
		var idle_vase_drop: Dictionary = vase_fx.drop_state_for_test()
		ok(not bool(idle_vase_drop.visible), "vase droplet does not auto-play during idle animation")
	ok(vase_fx.has_method("play_drop_for_test"), "vase water effect exposes explicit quest droplet playback")
	if vase_fx.has_method("play_drop_for_test"):
		vase_fx.call("play_drop_for_test")
		var quest_vase_drop: Dictionary = vase_fx.drop_state_for_test()
		ok(bool(quest_vase_drop.visible), "quest droplet playback makes the vase droplet visible")
	vase_fx.set_time_for_test(0.9)
	var vase_drop: Dictionary = vase_fx.drop_state_for_test()
	ok(bool(vase_drop.visible)
			and float(vase_drop.radius) > vase_fx.size.x * 0.05
			and float(vase_drop.radius) < vase_fx.size.x * 0.09,
		"vase droplet is smaller but still readable on the acorn vase")
	ok(str(vase_drop.get("shape", "")) == "teardrop", "vase droplet uses a teardrop shape")
	ok(vase_drop.has("width_scale") and vase_drop.has("height_scale"), "vase droplet reports squash/stretch shape")
	ok(vase_fx.has_method("drop_shape_points_for_test"), "vase droplet exposes its outline points for tests")
	if vase_fx.has_method("drop_shape_points_for_test"):
		var drop_points: PackedVector2Array = vase_fx.call("drop_shape_points_for_test")
		ok(drop_points.size() >= 18, "vase droplet outline has enough points to look smooth")
		var top_y := INF
		var bottom_y := -INF
		for p in drop_points:
			top_y = minf(top_y, p.y)
			bottom_y = maxf(bottom_y, p.y)
		ok(top_y < float(vase_drop.y) and bottom_y > float(vase_drop.y), "vase droplet outline has tapered top and rounded bottom")
	vase_fx.set_time_for_test(1.65)
	var falling_vase_drop: Dictionary = vase_fx.drop_state_for_test()
	if bool(vase_drop.visible) and bool(falling_vase_drop.visible) and vase_drop.has("width_scale") and falling_vase_drop.has("width_scale"):
		ok(absf(float(vase_drop.get("width_scale", 0.0)) - float(falling_vase_drop.get("width_scale", 0.0))) > 0.04
				or absf(float(vase_drop.get("height_scale", 0.0)) - float(falling_vase_drop.get("height_scale", 0.0))) > 0.04,
			"vase droplet shape shifts as it falls")
	vase_fx.set_time_for_test(0.0)
	var calm_energy: float = vase_fx.energy_for_test()
	vase_fx.trigger_impact_for_test()
	ok(vase_fx.energy_for_test() > calm_energy * 3.0, "vase water impact injects extra energy")
	vase_fx.queue_free()

	ok(ResourceLoader.exists(VASE_SCENE_PATH), "editor-openable vase water scene exists")
	var vase_packed := load(VASE_SCENE_PATH) as PackedScene
	ok(vase_packed != null, "vase water scene loads as a PackedScene")
	if vase_packed != null:
		var vase_scene := vase_packed.instantiate() as Control
		ok(vase_scene != null and vase_scene.name == "VaseWaterDemo", "vase water scene instantiates as VaseWaterDemo")
		if vase_scene != null:
			root.add_child(vase_scene)
			await process_frame
			ok(vase_scene.find_child("VaseWaterEffect", true, false) is Control,
				"vase water scene contains the animated vase water effect")
			vase_scene.queue_free()

	fresh("purge_card")
	var first_unlock := G.spot_unlock_exp(0, 0)
	Save.grove()["exp"] = int(first_unlock / 2)
	Save.grove_write()
	var board := BoardScene.new()
	var purge_card := board._make_purge_card(360.0)
	var purge_vase := purge_card.find_child("PurgeVaseWater", true, false) as VaseWaterEffect
	var percent_label := _find_label(purge_card, "PurgeProgressLabel")
	ok(purge_vase != null, "purge card contains the vase water animation")
	if purge_vase != null:
		ok(absf(purge_vase.progress_for_test() - 0.5) < 0.06, "purge vase initializes from exp progress")
		var lay: Dictionary = board._giver_lay()
		var card_h := purge_card.custom_minimum_size.y * float(lay.get("card_h", 1.0))
		ok(purge_vase.size.y >= card_h * 0.96, "purge vase is full height inside the card slot")
		var slot_h := purge_card.custom_minimum_size.y
		ok(purge_vase.size.y >= slot_h * 0.96, "purge vase fills the whole Purge slot height")
		ok(purge_vase.position.y <= slot_h * 0.02, "purge vase starts at the top of the Purge slot")
		var purge_vase_center_x := purge_vase.position.x + purge_vase.size.x * 0.5
		ok(purge_vase_center_x <= purge_card.custom_minimum_size.x * 0.38,
			"purge vase is shifted left under the level badge drop source")
		var expected_vase_center_x := clampf(
			purge_card.custom_minimum_size.x * 0.32 + 5.0,
			purge_vase.size.x * 0.5,
			purge_card.custom_minimum_size.x - purge_vase.size.x * 0.5)
		ok(absf(purge_vase_center_x - expected_vase_center_x) < 0.5,
			"purge vase is nudged 5 px right from the badge-aligned position")
		if purge_vase.has_method("visible_vase_rect_for_test"):
			var purge_visible_rect: Rect2 = purge_vase.call("visible_vase_rect_for_test")
			ok(purge_visible_rect.size.y >= purge_vase.size.y * 0.96, "visible purge vase art fills the whole slot height")
		ok(purge_card.modulate == Color.WHITE, "not-ready purge card keeps the vase full color")
		ok(purge_vase.modulate == Color.WHITE, "not-ready purge vase is not locally faded")
	ok(percent_label != null and percent_label.text == "50%", "purge card shows readable percent progress")
	if purge_vase != null and percent_label != null:
		var vase_rect := _control_rect(purge_vase)
		var label_rect := _control_rect(percent_label)
		ok(vase_rect.has_point(label_rect.get_center()), "purge percent label is centered inside the vase")
	ok(not _has_label_text(purge_card, str(Save.exp_total())), "purge card removes the old star count label")
	ok(not _has_card_frame(purge_card), "purge card removes the old framed background")
	ok(not _has_button(purge_card), "purge card replaces the text CTA button with the vase")
	purge_card.free()
	board.free()
	await process_frame

	fresh("purge_debug_exp")
	var debug_board := BoardScene.new()
	var debug_card := debug_board._make_purge_card(360.0)
	root.add_child(debug_card)
	await process_frame
	var debug_vase := debug_card.find_child("PurgeVaseWater", true, false) as VaseWaterEffect
	var before_progress: float = debug_vase.progress_for_test() if debug_vase != null else 0.0
	debug_board.debug_add_exp(5)
	for i in 20:
		await process_frame
	ok(Save.exp_total() == 5, "debug board exp gain credits Save without scene reload")
	if debug_vase != null:
		ok(debug_vase.progress_for_test() > before_progress, "debug board exp gain fills the visible purge vase")
		ok(not bool(debug_vase.drop_state_for_test().visible), "debug board exp gain does not show the quest droplet")
	debug_card.free()
	debug_board.free()
	await process_frame

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
