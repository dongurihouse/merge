extends SceneTree
## Contract tests for the standalone layered Home review scene.

const SCENE_PATH := "res://games/grove/tools/HomeLayerWorkbench.tscn"

var _pass := 0
var _fail := 0


func ok(condition: bool, label: String) -> void:
	if condition:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)


func _initialize() -> void:
	print("== Grove Home layer workbench tests ==")
	var packed := load(SCENE_PATH) as PackedScene
	ok(packed != null, "standalone Home layer workbench scene loads")
	if packed != null:
		var view := packed.instantiate()
		root.add_child(view)
		await process_frame
		await process_frame

		ok(view.has_method("reload_manifest"), "workbench exposes manifest reload")
		ok(view.has_method("set_all_props_visible"), "workbench exposes all-prop visibility")
		ok(view.has_method("set_guides_visible"), "workbench exposes guide visibility")
		ok(view.has_method("prop_count"), "workbench exposes prop count")
		ok(view.has_method("canvas_size"), "workbench exposes canvas size")
		ok(int(view.call("prop_count")) == 33, "checkpoint manifest creates the house and modular ground props")
		ok(view.call("canvas_size") == Vector2i(941, 1672), "workbench keeps the exact Home art canvas")

		var base := view.find_child("HomeBase", true, false) as TextureRect
		var props := view.find_child("Props", true, false) as Control
		var guides := view.find_child("Guides", true, false) as Control
		var help := view.find_child("Help", true, false) as PanelContainer
		var help_label := help.find_child("Label", true, false) as Label
		ok(base != null and base.texture != null, "building-free foundation is present")
		ok(
			base != null
			and base.texture != null
			and base.texture.resource_path.ends_with("home_base_no_road.png"),
			"workbench loads the exact road-free background"
		)
		ok(props != null and props.get_child_count() == 33, "house, road stones, and grass live in separate prop entries")
		var house := props.find_child("fh_hearth", false, false) as TextureRect
		var first_road := props.find_child("fh_road_01", false, false) as TextureRect
		ok(house != null, "checkpoint contains the farmhouse")
		ok(
			house != null
			and house.texture != null
			and house.texture.resource_path.ends_with("fh_hearth_shadowless_v3.png"),
			"checkpoint loads the exact shadowless farmhouse"
		)
		var textured_props := 0
		for prop in props.get_children():
			if prop is TextureRect and prop.texture != null:
				textured_props += 1
		ok(textured_props == 33, "all modular checkpoint textures are importable")
		ok(house != null and guides.z_index > house.z_index, "placement guides render above the house")
		ok(help.z_index > guides.z_index, "help overlay renders above guides and props")
		ok(help_label != null and "1 farmhouse" in help_label.text, "help names the available farmhouse hotkey")

		var house_key := InputEventKey.new()
		house_key.keycode = KEY_1
		house_key.pressed = true
		view.call("_unhandled_key_input", house_key)
		await process_frame
		ok(house != null and not house.visible, "key 1 toggles the manifest-tagged farmhouse")
		ok(first_road != null and first_road.visible, "key 1 does not toggle the first road entry")
		view.call("_unhandled_key_input", house_key)
		await process_frame

		view.call("set_all_props_visible", false)
		await process_frame
		var hidden_count := 0
		for prop in props.get_children():
			if not prop.visible:
				hidden_count += 1
		ok(hidden_count == 33, "all modular props can be hidden to inspect the road-free background")

		view.call("set_all_props_visible", true)
		await process_frame
		var shown_count := 0
		for prop in props.get_children():
			if prop.visible:
				shown_count += 1
		ok(shown_count == 33, "all modular props can be restored")
		view.queue_free()

		var native_viewport := SubViewport.new()
		native_viewport.size = Vector2i(941, 1672)
		root.add_child(native_viewport)
		var native_view := packed.instantiate() as Control
		native_viewport.add_child(native_view)
		await process_frame
		await process_frame
		await create_timer(0.2).timeout
		var native_stage := native_view.find_child("Stage", true, false) as Control
		ok(native_stage != null and native_stage.scale.is_equal_approx(Vector2.ONE), "native-size review capture is not zoomed or cropped")
		native_viewport.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
