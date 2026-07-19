extends SceneTree
## Headless tests for the acorn-vase water FX component and the board's NEXT UNLOCK strip.
##   godot --headless --path . -s res://engine/tests/vase_water_effect_tests.gd

const VaseWaterEffect = preload("res://engine/scripts/ui/vase_water_effect.gd")
const BoardScene = preload("res://engine/scripts/scenes/board.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
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
	ok(VaseWaterEffect.VASE_PATH.ends_with("vase_acorn.png"), "vase water effect uses the acorn vase art")
	ok(ResourceLoader.exists(VaseWaterEffect.VASE_PATH), "acorn vase sprite exists")
	ok(ResourceLoader.exists(VaseWaterEffect.MASK_PATH), "acorn vase water mask exists")
	var vase_fx: Control = VaseWaterEffect.new()
	vase_fx.size = Vector2(360, 420)
	ok(vase_fx.show_shadow, "a fresh vase draws its contact shadow by default")
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

	fresh("unlock_bar")
	var first_unlock := G.coins_at_level(2)      # the strip is the level bar on the coin clock
	Save.grove()["coins_earned"] = int(first_unlock / 2)
	Save.grove_write()
	var board := BoardScene.new()
	board._build_unlock_bar()
	var bar: Control = board._unlock_bar
	ok(bar != null and bar.name == "NextUnlockBar", "board builds the NEXT UNLOCK strip")
	if bar != null:
		bar.size = Vector2(900.0, 120.0)   # force a concrete layout off-tree
		bar._relayout()
		ok(bar.visible, "the strip shows while the zone arc still runs")
		ok(absf(bar.progress_for_test() - 0.5) < 0.06, "strip fill initializes from the coin-clock progress")
		var percent_label := _find_label(bar, "UnlockPct")
		ok(percent_label != null and percent_label.text == "50%", "strip shows readable percent progress")
		var level_label := _find_label(bar, "UnlockLevel")
		ok(level_label != null and level_label.text.to_upper().contains("2"),
			"strip names the NEXT level it unlocks")
		var title_label := _find_label(bar, "UnlockTitle")
		ok(title_label != null and title_label.text == title_label.text.to_upper(),
			"strip title reads as the mock's caps NEXT UNLOCK")
		var badge := bar.find_child("UnlockBadge", true, false) as TextureRect
		ok(badge != null and badge.texture != null, "strip carries the lock-flower badge art")
		var track := bar.find_child("UnlockTrack", true, false) as Control
		var fill := bar.find_child("UnlockFill", true, false) as Control
		ok(track != null and fill != null, "strip has a track and a fill bar")
		if track != null and fill != null:
			ok(absf(fill.size.x - track.size.x * 0.5) <= track.size.y,
				"fill width tracks the 50% progress")
			ok(fill.size.x < track.size.x, "half progress leaves visible empty track")
			ok(track.position.x > 0.0 and track.position.x + track.size.x <= bar.size.x,
				"track sits inside the strip")
		ok(bar.mouse_filter == Control.MOUSE_FILTER_STOP, "the whole strip is the Home tap target")
		bar.set_progress(1.0)
		ok(percent_label != null and percent_label.text == "100%", "full progress reads 100%")
		if track != null and fill != null:
			ok(absf(fill.size.x - track.size.x) < 1.0, "full progress fills the whole track")
	board.free()
	await process_frame

	fresh("unlock_bar_debug_progress")
	var debug_board := BoardScene.new()
	debug_board._build_unlock_bar()
	var debug_bar: Control = debug_board._unlock_bar
	debug_board.remove_child(debug_bar)
	root.add_child(debug_bar)             # in-tree so animate_progress_to can tween
	await process_frame
	var before_progress: float = debug_bar.progress_for_test()
	debug_board.debug_add_progress(5)
	for i in 20:
		await process_frame
	ok(Save.coins_earned_lifetime() == 5, "debug board progress gain credits the coin clock without scene reload")
	ok(debug_bar.progress_for_test() > before_progress, "debug board progress gain fills the visible strip")
	debug_bar.free()
	debug_board.free()
	await process_frame

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
