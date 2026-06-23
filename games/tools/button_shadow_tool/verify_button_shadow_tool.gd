extends SceneTree

const SCENE_PATH := "res://games/tools/button_shadow_tool/ButtonShadowTool.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Could not load %s" % SCENE_PATH)
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var preview := scene.find_child("ButtonPreview", true, false)
	if preview == null:
		_fail("ButtonPreview missing")
		return
	if not preview.has_method("get_shadow_settings"):
		_fail("ButtonPreview needs get_shadow_settings")
		return

	for slider_name in ["OffsetX", "OffsetY", "Blur", "Spread", "Alpha", "Warmth", "InnerHighlight"]:
		var slider := scene.find_child(slider_name, true, false) as HSlider
		if slider == null:
			_fail("%s slider missing" % slider_name)
			return

	var before: Dictionary = preview.call("get_shadow_settings")
	if float(before.get("offset_y", 0.0)) <= 0.0:
		_fail("Default shadow should sit below the button")
		return
	if float(before.get("blur", 0.0)) < 8.0:
		_fail("Default shadow should be soft")
		return
	if float(before.get("alpha", 0.0)) <= 0.0:
		_fail("Default shadow alpha should be visible")
		return

	var blur := scene.find_child("Blur", true, false) as HSlider
	blur.value = 22.0
	blur.value_changed.emit(22.0)
	await process_frame

	var after: Dictionary = preview.call("get_shadow_settings")
	if absf(float(after.get("blur", 0.0)) - 22.0) > 0.001:
		_fail("Blur slider did not update preview settings")
		return

	print("Button shadow tool verification passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
