extends SceneTree

const SCENE_PATH := "res://games/tools/vine_mask_tool/VineMaskTool.tscn"
const REGIONS_PATH := "res://games/tools/vine_mask_tool/maps/map1_farm_regions.json"

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

	# Region editing is on by default — the toggle is pressed and the overlay accepts edits.
	var edit_toggle := scene.find_child("EditRegionsToggle", true, false) as CheckButton
	if edit_toggle == null or not edit_toggle.button_pressed:
		_fail("Edit Regions should be ON by default")
		return
	var editor := scene.find_child("RegionEditor", true, false)
	if editor == null or not bool(editor.get("edit_enabled")):
		_fail("Region editor should be edit-enabled by default")
		return

	# The first visit to a map seeds its regions file (auto-detect + save).
	if not FileAccess.file_exists(REGIONS_PATH):
		_fail("First visit should have written %s" % REGIONS_PATH)
		return

	# Per-region shader tuning survives a save → reload round-trip. Mutate region 0's glow
	# opacity to a sentinel that differs from the template default (0.28), save, reload in a
	# fresh instance, and confirm the value was persisted AND re-applied. Restore the file so
	# the committed seed stays byte-identical.
	var regions_abs := ProjectSettings.globalize_path(REGIONS_PATH)
	var backup := FileAccess.get_file_as_string(regions_abs)
	const SENTINEL := 0.9123
	scene.call("_write_shader_value", "glow", "opacity", SENTINEL, 0)
	scene.call("_store_region_tuning", 0, "GlowOpacity", SENTINEL)
	scene.call("_save_regions_to_file")

	var reloaded := packed.instantiate()
	root.add_child(reloaded)
	await process_frame
	await process_frame
	var applied := float(reloaded.call("_read_shader_value", "glow", "opacity", 0))
	_restore_file(regions_abs, backup)
	if absf(applied - SENTINEL) > 0.0001:
		_fail("Tuning did not round-trip: expected %f, got %f" % [SENTINEL, applied])
		return

	print("Vine mask tool verification passed")
	quit(0)

func _restore_file(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(contents)
		file.close()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
