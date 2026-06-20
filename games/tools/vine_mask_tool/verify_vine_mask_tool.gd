extends SceneTree

const SCENE_PATH := "res://games/tools/vine_mask_tool/VineMaskTool.tscn"

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

	if not scene.has_method("get_map_count") or scene.get_map_count() < 1:
		_fail("Vine mask tool did not load any maps")
		return

	if not scene.has_method("get_current_map_id") or scene.get_current_map_id() != "map1_farm":
		_fail("map1_farm should be the default map")
		return

	var base := scene.get_node_or_null("Workspace/ArtworkFrame/Base") as TextureRect
	if base == null or base.texture == null:
		_fail("Base texture missing")
		return
	var base_size := base.texture.get_size()
	if int(base_size.x) != 941 or int(base_size.y) != 1672:
		_fail("map1_farm should use the farm map dimensions")
		return

	var map_select := scene.find_child("MapSelect", true, false) as OptionButton
	if map_select == null or map_select.item_count < 1:
		_fail("MapSelect missing or empty")
		return

	for control_name in ["RegionSelect", "EnableRegion", "EditRegionsToggle", "AutoDetectRegions", "SaveRegions"]:
		if scene.find_child(control_name, true, false) == null:
			_fail("%s missing" % control_name)
			return

	if scene.get_region_count() != 8:
		_fail("map1_farm should expose exactly 8 editable regions")
		return

	for region_index in range(8):
		if scene.get_region_point_count(region_index) != 8:
			_fail("Each map1_farm region should have 8 vertices")
			return

	var vines := scene.get_node_or_null("Workspace/ArtworkFrame/RegionOverlays/Region1Vines") as TextureRect
	if vines == null:
		_fail("Region 1 vines overlay missing")
		return
	var vines_material := vines.material as ShaderMaterial
	if vines_material == null:
		_fail("Region 1 vines material missing")
		return
	for parameter_name in ["lightning_strength", "heartbeat_strength", "shimmer_strength", "energy_crawl_strength"]:
		if vines_material.get_shader_parameter(parameter_name) == null:
			_fail("%s missing from vine shader" % parameter_name)
			return

	var enabled := scene.find_child("EnableRegion", true, false) as CheckBox
	enabled.button_pressed = false
	enabled.toggled.emit(false)
	await process_frame
	var glow := scene.get_node("Workspace/ArtworkFrame/RegionOverlays/Region1Glow") as TextureRect
	var glow_material := glow.material as ShaderMaterial
	if float(glow_material.get_shader_parameter("region_enabled")) != 0.0:
		_fail("EnableRegion did not disable selected region")
		return

	print("Vine mask tool verification passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
