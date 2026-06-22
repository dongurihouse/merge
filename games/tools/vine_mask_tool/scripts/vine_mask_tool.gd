extends Control

const RegionEditorOverlay := preload("res://games/tools/vine_mask_tool/scripts/region_editor_overlay.gd")
const RegionListPanel := preload("res://games/tools/vine_mask_tool/scripts/region_list_panel.gd")
const VineMapView := preload("res://games/grove/vine/vine_map_view.gd")
const VineMaps := preload("res://games/grove/vine/vine_maps.gd")   # shared cost ladder (legacy default)
const MAPS_PATH := "res://games/tools/vine_mask_tool/maps/maps.json"
const DEFAULT_MAP_ID := "map1_farm"
const DEFAULT_STARS := 3            # stars cost a freshly drawn polygon starts at (the cheapest rung)

# Per-region shader knobs. The knob→param mapping mirrors VineMapView.CONTROLS (canonical);
# this copy adds slider UI fields (label/min/max/step) for the panel. Keep in sync with
# VineMapView.CONTROLS whenever entries are added or changed. The table lives here (not inside
# _build_panel) so it is readable before the panel exists.
const CONTROLS := [
	{"name": "GlowOpacity", "label": "Glow opacity", "target": "glow", "param": "opacity", "min": 0.0, "max": 1.0, "step": 0.01, "decimals": 2},
	{"name": "GlowPower", "label": "Glow power", "target": "glow", "param": "glow_strength", "min": 0.0, "max": 3.0, "step": 0.01, "decimals": 2},
	{"name": "GlowSize", "label": "Glow size", "target": "glow", "param": "glow_radius", "min": 0.0, "max": 0.03, "step": 0.001, "decimals": 3},
	{"name": "VineOpacity", "label": "Vine opacity", "target": "vines", "param": "opacity", "min": 0.0, "max": 1.2, "step": 0.01, "decimals": 2},
	{"name": "VinePower", "label": "Vine power", "target": "vines", "param": "glow_strength", "min": 0.0, "max": 2.0, "step": 0.01, "decimals": 2},
	{"name": "Sharpness", "label": "Sharpness", "target": "vines", "param": "edge_power", "min": 0.5, "max": 6.0, "step": 0.05, "decimals": 2},
	{"name": "PulseSpeed", "label": "Pulse speed", "target": "both", "param": "pulse_speed", "min": 0.0, "max": 5.0, "step": 0.05, "decimals": 2},
	{"name": "FlowSpeed", "label": "Flow speed", "target": "both", "param": "flow_speed", "min": 0.0, "max": 4.0, "step": 0.05, "decimals": 2},
	{"name": "Breathing", "label": "Breathing", "target": "vines", "param": "breath_strength", "min": 0.0, "max": 1.5, "step": 0.01, "decimals": 2},
	{"name": "Heartbeat", "label": "Heartbeat", "target": "vines", "param": "heartbeat_strength", "min": 0.0, "max": 1.5, "step": 0.01, "decimals": 2},
	{"name": "Lightning", "label": "Lightning", "target": "vines", "param": "lightning_strength", "min": 0.0, "max": 2.5, "step": 0.01, "decimals": 2},
	{"name": "Shimmer", "label": "Shimmer", "target": "vines", "param": "shimmer_strength", "min": 0.0, "max": 0.015, "step": 0.001, "decimals": 3},
	{"name": "EnergyCrawl", "label": "Energy crawl", "target": "vines", "param": "energy_crawl_strength", "min": 0.0, "max": 2.0, "step": 0.01, "decimals": 2},
	{"name": "Shadow", "label": "Shadow", "target": "shadow", "param": "shadow_opacity", "min": 0.0, "max": 0.65, "step": 0.01, "decimals": 2},
	{"name": "Embers", "label": "Embers", "target": "embers", "param": "ember_opacity", "min": 0.0, "max": 1.5, "step": 0.01, "decimals": 2},
]

@onready var artwork_frame: Control = $Workspace/ArtworkFrame
@onready var base_rect: TextureRect = $Workspace/ArtworkFrame/Base

var maps: Array[Dictionary] = []
var current_map_index := 0
var current_map: Dictionary = {}
var current_map_id := ""
var image_size := Vector2i(941, 1672)
var regions_path := ""
# Each region: {name, points:[Vector2], enabled:bool, cost:int (stars), tuning:Dictionary}. Hand-drawn
# in the editor (no mask auto-detection). Order in this array == unlock order (spot id <slot>_r<i>).
var regions: Array = []
var region_count := 0
var controls: Array[Dictionary] = []
var sliders: Dictionary = {}
var value_labels: Dictionary = {}
var view: VineMapView                # the shared renderer — the tool owns one, edits push to it
var selected_region := 0
var updating_ui := false
var region_editor: Control
var region_list: Control             # the reorderable per-polygon list (name / stars / on / delete)
var map_select: OptionButton
var edit_regions_toggle: CheckButton
var save_status_label: Label
# Whole-mask nudge: shifts every overlay + the region editor over the fixed base, so a mask
# that doesn't line up with the art can be aligned. Region points stay in mask-local space;
# this offset is persisted alongside them.
var mask_offset := Vector2.ZERO
var mask_offset_sliders: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(1380.0, 1672.0)
	controls.assign(CONTROLS.duplicate(true))
	_load_maps()
	if maps.is_empty():
		push_error("Vine mask tool has no maps in %s" % MAPS_PATH)
		return
	current_map_index = _default_map_index()
	_apply_current_map()
	_build_panel()
	_create_region_editor()
	_select_region(0)

# ── Public API (also the seam the headless tests drive) ───────────────────────

func get_map_count() -> int:
	return maps.size()

func get_current_map_id() -> String:
	return current_map_id

func get_region_count() -> int:
	return regions.size()

func get_region_point_count(region_index: int) -> int:
	if region_index < 0 or region_index >= regions.size():
		return 0
	var region: Dictionary = regions[region_index]
	var points: Array = region.get("points", [])
	return points.size()

func get_region_cost(region_index: int) -> int:
	if region_index < 0 or region_index >= regions.size():
		return 0
	return int((regions[region_index] as Dictionary).get("cost", DEFAULT_STARS))

# Append a hand-drawn polygon (≥3 vertices). Points may be Vector2 or [x,y]. Selects the new region.
func add_region(points: Array, cost: int = DEFAULT_STARS, name := "") -> void:
	var pts: Array = []
	for p in points:
		if p is Vector2:
			pts.append(_clamp_to_image(p))
		elif p is Array and (p as Array).size() >= 2:
			pts.append(_clamp_to_image(Vector2(float(p[0]), float(p[1]))))
	if pts.size() < 3:
		return
	regions.append({
		"name": name if name != "" else "Region %d" % [regions.size() + 1],
		"points": pts,
		"enabled": true,
		"cost": maxi(1, cost),
		"tuning": {},
	})
	_regions_mutated(regions.size() - 1)

func delete_region(region_index: int) -> void:
	if region_index < 0 or region_index >= regions.size():
		return
	regions.remove_at(region_index)
	_regions_mutated(mini(region_index, maxi(regions.size() - 1, 0)))

# Move a region to a new list position; its name/stars/tuning travel with it (order = list position).
func reorder_region(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= regions.size():
		return
	var region: Dictionary = regions[from_index]
	regions.remove_at(from_index)
	var dest := clampi(to_index, 0, regions.size())
	regions.insert(dest, region)
	_regions_mutated(dest)

func set_region_cost(region_index: int, cost: int) -> void:
	if region_index < 0 or region_index >= regions.size():
		return
	var region: Dictionary = regions[region_index]
	region["cost"] = maxi(1, cost)
	regions[region_index] = region

# ── Maps ──────────────────────────────────────────────────────────────────────

func _load_maps() -> void:
	maps.clear()
	var file := FileAccess.open(MAPS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	var entries: Array = data.get("maps", [])
	for entry in entries:
		if entry is Dictionary and String(entry.get("id", "")) != "":
			maps.append(entry)

func _default_map_index() -> int:
	for index in range(maps.size()):
		if String(maps[index].get("id", "")) == DEFAULT_MAP_ID:
			return index
	return 0

func _apply_current_map() -> void:
	current_map = maps[clampi(current_map_index, 0, maps.size() - 1)]
	current_map_id = String(current_map.get("id", "map_%d" % [current_map_index + 1]))
	regions_path = String(current_map.get("regions_path", "res://games/tools/vine_mask_tool/maps/%s_regions.json" % current_map_id))
	_load_base_art()

	mask_offset = _load_saved_mask_offset()
	# Manual-only: load the hand-authored regions if a file exists, else start empty (the user draws).
	# No mask auto-detection, and no fixed-count guard — the count is whatever the file/canvas holds.
	# (_load_saved_regions seeds a missing `cost` from the ladder, so legacy maps round-trip cleanly.)
	regions = _load_saved_regions()
	region_count = regions.size()

	# Hand the whole render off to the shared view: it builds the mask, region-index map, the
	# per-region shadow/glow/vines/embers overlays, and applies each region's saved tuning.
	_ensure_view()
	view.mask_offset = mask_offset
	view.load_map(current_map, regions)

func _ensure_view() -> void:
	if view != null and is_instance_valid(view):
		return
	view = VineMapView.new()
	view.name = "VineView"
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.position = Vector2.ZERO
	artwork_frame.add_child(view)

func _load_base_art() -> void:
	var base_path := String(current_map.get("base", ""))
	var base_texture := load(base_path) as Texture2D
	if base_texture != null:
		base_rect.texture = base_texture
		image_size = Vector2i(int(base_texture.get_size().x), int(base_texture.get_size().y))
	artwork_frame.custom_minimum_size = Vector2(image_size)
	artwork_frame.size = Vector2(image_size)

func _load_saved_mask_offset() -> Vector2:
	if regions_path == "" or not FileAccess.file_exists(regions_path):
		return Vector2.ZERO
	var file := FileAccess.open(regions_path, FileAccess.READ)
	if file == null:
		return Vector2.ZERO
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return Vector2.ZERO
	var offset: Variant = (parsed as Dictionary).get("mask_offset", null)
	if offset is Array and offset.size() >= 2:
		return Vector2(float(offset[0]), float(offset[1]))
	return Vector2.ZERO

# Load the saved polygons verbatim — no count guard (the count is dynamic now). Each region carries
# its stars `cost` (default DEFAULT_STARS when the file predates the field) and its shader `tuning`.
func _load_saved_regions() -> Array:
	if regions_path == "" or not FileAccess.file_exists(regions_path):
		return []
	var file := FileAccess.open(regions_path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var data: Dictionary = parsed
	if not data.has("regions") or not (data["regions"] is Array):
		return []

	var loaded: Array = []
	for region_data in data["regions"]:
		if not (region_data is Dictionary) or not region_data.has("points"):
			continue
		var points: Array = []
		for point_value in region_data["points"]:
			if point_value is Array and point_value.size() >= 2:
				points.append(_clamp_to_image(Vector2(float(point_value[0]), float(point_value[1]))))
		if points.size() >= 3:
			var tuning_value: Variant = region_data.get("tuning", {})
			# A pre-stars file has no `cost`: seed it from the cost ladder by index, matching what the
			# game currently derives — so opening + re-saving an old map preserves its stars.
			loaded.append({
				"name": str(region_data.get("name", "Region %d" % [loaded.size() + 1])),
				"points": points,
				"enabled": bool(region_data.get("enabled", true)),
				"cost": int(region_data.get("cost", _ladder_cost(loaded.size()))),
				"tuning": tuning_value if tuning_value is Dictionary else {}
			})
			# the optional unlock-disc position; absent => the game/editor uses the centroid
			var button_value: Variant = region_data.get("button", null)
			if button_value is Array and (button_value as Array).size() >= 2:
				(loaded[loaded.size() - 1] as Dictionary)["button"] = _clamp_to_image(Vector2(float(button_value[0]), float(button_value[1])))
	return loaded

# ── Region-set changes ─────────────────────────────────────────────────────────

# Push current region geometry to the shared renderer (rebuilds index map + overlays + tuning).
func _render_regions() -> void:
	region_count = regions.size()
	if view != null and is_instance_valid(view):
		view.mask_offset = mask_offset
		view.refresh(regions)

# The region SET changed (add / delete / reorder): re-sync the editor's geometry, re-render, rebuild
# the list, and re-select. Geometry-only edits (handle drags) skip this — see _on_regions_changed.
func _regions_mutated(select_index: int) -> void:
	if region_editor != null:
		region_editor.call("set_regions", regions)
	_render_regions()
	_refresh_region_list()
	_select_region(clampi(select_index, 0, maxi(regions.size() - 1, 0)))

func _refresh_region_list() -> void:
	if region_list != null and region_list.has_method("set_regions"):
		region_list.call("set_regions", regions, selected_region)

func _store_region_tuning(region_index: int, control_name: String, value: float) -> void:
	if region_index < 0 or region_index >= regions.size():
		return
	var region: Dictionary = regions[region_index]
	var tuning: Dictionary = region.get("tuning", {})
	tuning[control_name] = value
	region["tuning"] = tuning
	regions[region_index] = region

# A full snapshot of one region's live shader values, used when serializing — so the
# saved file carries every knob, not just the ones the user happened to touch.
func _current_region_tuning(region_index: int) -> Dictionary:
	var tuning: Dictionary = {}
	if view == null or not is_instance_valid(view):
		return tuning
	for control in controls:
		tuning[String(control["name"])] = _read_shader_value(control["target"], control["param"], region_index)
	return tuning

# The pristine template value for a knob — what "Reset Region" restores. Delegates to the view's
# never-mutated template materials so saved tuning can never contaminate the reset target.
func _template_default(target: String, param: String) -> float:
	if view == null or not is_instance_valid(view):
		return 0.0
	return view.template_default(target, param)

func _edit_regions_default() -> bool:
	return edit_regions_toggle.button_pressed if edit_regions_toggle != null else true

func _show_save_status(message: String, ok: bool) -> void:
	if save_status_label == null:
		return
	save_status_label.text = message
	save_status_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if ok else Color(1.0, 0.45, 0.45))

# ── Panel ──────────────────────────────────────────────────────────────────────

func _build_panel() -> void:
	for control in controls:
		control["default"] = _template_default(control["target"], control["param"])

	var panel := PanelContainer.new()
	panel.name = "LiveTuningPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.offset_left = float(image_size.x + 24)
	panel.offset_top = 16.0
	panel.offset_right = float(image_size.x + 424)
	panel.offset_bottom = 0.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.018, 0.04, 0.82)
	style.border_color = Color(0.7, 0.25, 1.0, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)

	_add_map_controls(stack)

	var title := Label.new()
	title.text = "Vine Region Tuning"
	title.add_theme_font_size_override("font_size", 16)
	stack.add_child(title)

	_add_region_controls(stack)
	for control in controls:
		_add_slider(stack, control)

	var reset := Button.new()
	reset.text = "Reset Region"
	reset.pressed.connect(_reset_selected_region)
	stack.add_child(reset)
	add_child(panel)

func _add_map_controls(stack: VBoxContainer) -> void:
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 8)
	stack.add_child(map_row)

	var map_label := Label.new()
	map_label.text = "Map"
	map_label.custom_minimum_size = Vector2(104.0, 0.0)
	map_row.add_child(map_label)

	map_select = OptionButton.new()
	map_select.name = "MapSelect"
	map_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in range(maps.size()):
		map_select.add_item(String(maps[index].get("name", maps[index].get("id", "Map %d" % [index + 1]))), index)
	map_select.select(current_map_index)
	map_select.item_selected.connect(_on_map_selected)
	map_row.add_child(map_select)

	mask_offset_sliders.clear()
	_add_mask_offset_slider(stack, "Mask offset X", "x")
	_add_mask_offset_slider(stack, "Mask offset Y", "y")

func _add_mask_offset_slider(stack: VBoxContainer, label_text: String, axis: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(104.0, 0.0)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.name = "MaskOffset" + axis.to_upper()
	slider.min_value = -float(image_size.x if axis == "x" else image_size.y)
	slider.max_value = float(image_size.x if axis == "x" else image_size.y)
	slider.step = 1.0
	slider.value = mask_offset.x if axis == "x" else mask_offset.y
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	mask_offset_sliders[axis] = slider

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(48.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%d" % int(slider.value)
	row.add_child(value_label)

	slider.value_changed.connect(_on_mask_offset_changed.bind(axis, value_label))

func _on_mask_offset_changed(value: float, axis: String, value_label: Label) -> void:
	if axis == "x":
		mask_offset.x = value
	else:
		mask_offset.y = value
	value_label.text = "%d" % int(value)
	_apply_mask_offset()

func _apply_mask_offset() -> void:
	if view != null and is_instance_valid(view):
		view.set_mask_offset(mask_offset)
	if region_editor != null:
		region_editor.call("set_mask_offset", mask_offset)

func _add_region_controls(stack: VBoxContainer) -> void:
	# The reorderable region list owns selection, name, stars, enabled, delete, and the Draw button.
	region_list = RegionListPanel.new()
	region_list.name = "RegionList"
	region_list.connect("draw_requested", _on_draw_requested)
	region_list.connect("region_selected", _select_region)
	region_list.connect("reordered", reorder_region)
	region_list.connect("region_renamed", _on_region_renamed)
	region_list.connect("cost_changed", set_region_cost)
	region_list.connect("enabled_changed", _set_region_enabled)
	region_list.connect("deleted", delete_region)
	stack.add_child(region_list)

	var edit_row := HBoxContainer.new()
	edit_row.add_theme_constant_override("separation", 8)
	stack.add_child(edit_row)

	edit_regions_toggle = CheckButton.new()
	edit_regions_toggle.name = "EditRegionsToggle"
	edit_regions_toggle.text = "Edit Regions"
	edit_regions_toggle.toggled.connect(_set_edit_regions_enabled)
	# On by default: open the tool ready to drag region handles. The editor itself is built
	# after this panel, so it reads this state in _create_region_editor.
	edit_regions_toggle.button_pressed = true
	edit_row.add_child(edit_regions_toggle)

	var save := Button.new()
	save.name = "SaveRegions"
	save.text = "Save Regions"
	save.pressed.connect(_save_regions_to_file)
	edit_row.add_child(save)

	save_status_label = Label.new()
	save_status_label.name = "SaveStatus"
	save_status_label.add_theme_font_size_override("font_size", 12)
	save_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(save_status_label)

	_refresh_region_list()

func _add_slider(stack: VBoxContainer, config: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)

	var name_label := Label.new()
	name_label.text = config["label"]
	name_label.custom_minimum_size = Vector2(104.0, 0.0)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.name = config["name"]
	slider.min_value = config["min"]
	slider.max_value = config["max"]
	slider.step = config["step"]
	slider.value = _read_shader_value(config["target"], config["param"], selected_region)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	sliders[config["name"]] = slider

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(48.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	value_labels[config["name"]] = value_label

	_update_value_label(value_label, slider.value, config["decimals"])
	slider.value_changed.connect(_on_slider_changed.bind(config["name"], config["target"], config["param"], value_label, config["decimals"]))

func _create_region_editor() -> void:
	if region_editor != null:
		region_editor.queue_free()
	region_editor = RegionEditorOverlay.new()
	region_editor.name = "RegionEditor"
	region_editor.call("set_image_size", Vector2(image_size))
	region_editor.call("set_mask_offset", mask_offset)
	region_editor.call("set_regions", regions)
	region_editor.call("set_selected_region", selected_region)
	region_editor.call("set_edit_enabled", _edit_regions_default())
	region_editor.regions_changed.connect(_on_regions_changed)
	region_editor.selection_changed.connect(_select_region)
	region_editor.region_drawn.connect(_on_region_drawn)
	artwork_frame.add_child(region_editor)

func _on_map_selected(index: int) -> void:
	if index == current_map_index:
		return
	current_map_index = clampi(index, 0, maps.size() - 1)
	_remove_live_controls()
	selected_region = 0
	sliders.clear()
	value_labels.clear()
	_apply_current_map()
	_build_panel()
	_create_region_editor()
	_select_region(0)

func _remove_live_controls() -> void:
	var panel := get_node_or_null("LiveTuningPanel")
	if panel != null:
		remove_child(panel)
		panel.queue_free()
	var existing_editor := artwork_frame.get_node_or_null("RegionEditor")
	if existing_editor != null:
		artwork_frame.remove_child(existing_editor)
		existing_editor.queue_free()
	region_editor = null
	region_list = null

func _select_region(index: int) -> void:
	selected_region = clampi(index, 0, maxi(regions.size() - 1, 0))
	updating_ui = true
	if region_list != null and region_list.has_method("set_selected"):
		region_list.call("set_selected", selected_region)
	if region_editor != null:
		region_editor.call("set_selected_region", selected_region)

	for control in controls:
		var slider := sliders.get(control["name"]) as HSlider
		var label := value_labels.get(control["name"]) as Label
		if slider != null:
			slider.value = _read_shader_value(control["target"], control["param"], selected_region)
		if label != null and slider != null:
			_update_value_label(label, slider.value, control["decimals"])
	updating_ui = false

func _set_edit_regions_enabled(enabled: bool) -> void:
	if region_editor != null:
		region_editor.call("set_edit_enabled", enabled)

# Push an enable toggle to the renderer and keep the tool's own `regions` source of truth in sync.
func _set_region_enabled(region_index: int, enabled: bool) -> void:
	if region_index < 0 or region_index >= regions.size():
		return
	var region: Dictionary = regions[region_index]
	region["enabled"] = enabled
	regions[region_index] = region
	if view != null and is_instance_valid(view):
		view.set_region_enabled(region_index, enabled)

func _on_slider_changed(value: float, control_name: String, target: String, param: String, value_label: Label, decimals: int) -> void:
	if updating_ui:
		return
	_write_shader_value(target, param, value, selected_region)
	_store_region_tuning(selected_region, control_name, value)
	_update_value_label(value_label, value, decimals)

# Live read/write of one shader knob — delegates to the view so the tool and the game share ONE
# renderer. Kept as named methods because the functional tests call them by name.
func _read_shader_value(target: String, param: String, region_index: int) -> float:
	if view == null or not is_instance_valid(view):
		return 0.0
	return view.read_shader_value(target, param, region_index)

func _write_shader_value(target: String, param: String, value: float, region_index: int) -> void:
	if view == null or not is_instance_valid(view):
		return
	view.write_shader_value(target, param, value, region_index)

func _update_value_label(label: Label, value: float, decimals: int) -> void:
	if decimals == 3:
		label.text = "%.3f" % value
	elif decimals == 2:
		label.text = "%.2f" % value
	else:
		label.text = "%.1f" % value

func _reset_selected_region() -> void:
	for control in controls:
		var value := float(control["default"])
		_write_shader_value(control["target"], control["param"], value, selected_region)
		var slider := sliders.get(control["name"]) as HSlider
		if slider != null:
			slider.value = value
	# Drop stored deltas so a later overlay rebuild keeps the template look, not the old tuning.
	if selected_region >= 0 and selected_region < regions.size():
		var region: Dictionary = regions[selected_region]
		region["tuning"] = {}
		regions[selected_region] = region

# ── Region list / draw callbacks ───────────────────────────────────────────────

func _on_draw_requested() -> void:
	if edit_regions_toggle != null and not edit_regions_toggle.button_pressed:
		edit_regions_toggle.button_pressed = true
	if region_editor != null and region_editor.has_method("set_draw_mode"):
		region_editor.call("set_draw_mode", true)

func _on_region_renamed(region_index: int, new_name: String) -> void:
	if region_index < 0 or region_index >= regions.size():
		return
	var region: Dictionary = regions[region_index]
	region["name"] = new_name
	regions[region_index] = region

func _on_region_drawn(points: Array) -> void:
	add_region(points)

# Geometry-only change from the editor handles: merge points/name/enabled back by index (cost +
# tuning the editor doesn't carry are preserved), then re-render. The list/order are untouched.
func _on_regions_changed(next_regions: Array) -> void:
	for index in range(mini(regions.size(), next_regions.size())):
		var existing: Dictionary = regions[index]
		var incoming: Dictionary = next_regions[index]
		existing["points"] = incoming.get("points", existing.get("points", []))
		existing["name"] = incoming.get("name", existing.get("name", "Region %d" % [index + 1]))
		existing["enabled"] = bool(incoming.get("enabled", existing.get("enabled", true)))
		# the unlock-disc position: carry a placed button, or drop it when reset to auto (centroid)
		if incoming.has("button"):
			existing["button"] = incoming["button"]
		else:
			existing.erase("button")
		regions[index] = existing
	_render_regions()

# ── Save ────────────────────────────────────────────────────────────────────────

func _save_regions_to_file() -> void:
	var data := {
		"map_id": current_map_id,
		"image_size": [image_size.x, image_size.y],
		"mask_offset": [roundi(mask_offset.x), roundi(mask_offset.y)],
		"mode": "hand_drawn_regions",
		"regions": []
	}
	for index in range(regions.size()):
		var region: Dictionary = regions[index]
		var serialized_points: Array = []
		for point in region.get("points", []):
			serialized_points.append([roundi(point.x), roundi(point.y)])
		var serialized := {
			"name": str(region.get("name", "Region %d" % [index + 1])),
			"enabled": bool(region.get("enabled", true)),
			"cost": int(region.get("cost", DEFAULT_STARS)),
			"points": serialized_points,
			"tuning": _current_region_tuning(index)
		}
		# persist the unlock-disc position ONLY when placed; absent => the game uses the centroid
		var button = region.get("button", null)
		if button is Vector2:
			serialized["button"] = [roundi(button.x), roundi(button.y)]
		data["regions"].append(serialized)

	if regions_path == "":
		_show_save_status("Save failed: this map has no regions_path", false)
		push_error("[vine_mask_tool] cannot save — current map has no regions_path")
		return

	var path := ProjectSettings.globalize_path(regions_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))
		file.close()
		_show_save_status("Saved ✓  %d regions → %s" % [regions.size(), regions_path.get_file()], true)
		print("[vine_mask_tool] saved %d regions to %s" % [regions.size(), regions_path])
	else:
		_show_save_status("Save failed: could not write %s" % regions_path.get_file(), false)
		push_error("[vine_mask_tool] could not write %s (error %d)" % [path, FileAccess.get_open_error()])

func _clamp_to_image(position: Vector2) -> Vector2:
	return Vector2(clampf(position.x, 0.0, float(image_size.x - 1)), clampf(position.y, 0.0, float(image_size.y - 1)))

# The tool's own default cost ladder for region `index` (the artist may still author per-region costs
# in the tool; the GAME ignores them now — unlock thresholds come from G.spot_unlock_exp). Past the
# table, the tail value repeats.
func _ladder_cost(index: int) -> int:
	var ladder := [3, 3, 3, 4, 4, 4, 5, 5]
	return int(ladder[index]) if index < ladder.size() else 5
