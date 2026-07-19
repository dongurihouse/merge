extends Control
## ZONE WORKBENCH (make zones): draw polygon UNLOCK ZONES over a real picture-book page.
## Replaces the retired vine mask tool's authoring role. The page renders through HomeZoneView
## (every building "built") so zones are drawn on exactly what the game shows; polygons are authored
## in NATIVE canvas coordinates (the stage is uniformly scaled to fit the window). Save writes
## unlocks_<scene>.json beside the page's zone manifest — see zone_workbench_model.gd for the schema.

const Model := preload("res://games/grove/tools/zone_workbench_model.gd")
const HomeZoneView := preload("res://engine/scripts/ui/home_zone_view.gd")
const RegionEditorOverlay := preload("res://games/tools/zone_workbench/region_editor_overlay.gd")
const ZoneListPanel := preload("res://games/tools/zone_workbench/zone_list_panel.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale

const PANEL_W := 400.0
const VIEW_H := 1100.0                 # the scaled page height on screen (fits a laptop window)

var pages: Array = []
var page_index := 0
var doc: Dictionary = {}
var selected := 0
var stage_holder: Control              # scaled wrapper: page render + overlay live at NATIVE size inside
var overlay: Control
var zone_list: Control
var page_select: OptionButton
var save_status: Label

func _ready() -> void:
	pages = Model.pages()
	if pages.is_empty():
		push_error("Zone workbench: no G.MAPS rows carry a zone_manifest")
		return
	_build_panel()
	_open_page(0)

func _open_page(index: int) -> void:
	page_index = clampi(index, 0, pages.size() - 1)
	var page: Dictionary = pages[page_index]
	var manifest: Dictionary = HomeZoneView.load_manifest(String(page.zone_manifest))
	var cv: Dictionary = manifest.get("canvas", {})
	var canvas := Vector2(float(cv.get("width", 1320)), float(cv.get("height", 2346)))
	doc = Model.load_doc(String(page.id), canvas)
	selected = 0
	_rebuild_stage(manifest, canvas)
	_sync_all()

# The scaled page stage: HomeZoneView's tree + the polygon overlay, both at NATIVE canvas size,
# uniformly scaled to VIEW_H. Overlay input arrives in native coordinates (Godot applies the
# inverse canvas transform), so the model never sees screen space.
func _rebuild_stage(manifest: Dictionary, canvas: Vector2) -> void:
	if stage_holder != null:
		stage_holder.queue_free()
	stage_holder = Control.new()
	stage_holder.name = "Stage"
	var s := VIEW_H / canvas.y
	stage_holder.scale = Vector2.ONE * s
	stage_holder.position = Vector2.ZERO
	add_child(stage_holder)
	move_child(stage_holder, 0)
	custom_minimum_size = Vector2(canvas.x * s + PANEL_W + 48.0, VIEW_H)

	var page_holder := Control.new()
	page_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_holder.add_child(page_holder)
	# render every building as "built", no badges/coverings — the finished page is the tracing surface
	HomeZoneView.build(page_holder, manifest, func(_id: String) -> String: return "built",
		func(_id: String) -> Dictionary: return {}, [])

	overlay = RegionEditorOverlay.new()
	overlay.name = "ZoneEditor"
	overlay.call("set_image_size", canvas)
	overlay.call("set_edit_enabled", true)
	overlay.regions_changed.connect(_on_zones_changed)
	overlay.selection_changed.connect(_select_zone)
	overlay.region_drawn.connect(_on_zone_drawn)
	stage_holder.add_child(overlay)

func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "ZonePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(PANEL_W, 0.0)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-PANEL_W - 16.0, 16.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.03, 0.85)
	style.border_color = Color(0.4, 0.8, 0.45, 0.45)
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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)
	var lbl := Label.new()
	lbl.text = "Page"
	row.add_child(lbl)
	page_select = OptionButton.new()
	page_select.name = "PageSelect"
	page_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(pages.size()):
		page_select.add_item(String(pages[i].name), i)
	page_select.item_selected.connect(_open_page)
	row.add_child(page_select)

	var title := Label.new()
	title.text = "Unlock zones (order = unlock order)"
	title.add_theme_font_size_override("font_size", FS.FINE)
	stack.add_child(title)

	zone_list = ZoneListPanel.new()
	zone_list.name = "ZoneList"
	zone_list.connect("draw_requested", _on_draw_requested)
	zone_list.connect("region_selected", _select_zone)
	zone_list.connect("reordered", _on_reordered)
	zone_list.connect("region_renamed", _on_renamed)
	zone_list.connect("enabled_changed", _on_enabled)
	zone_list.connect("deleted", _on_deleted)
	stack.add_child(zone_list)

	var save := Button.new()
	save.name = "SaveZones"
	save.text = "Save Zones"
	save.pressed.connect(_save)
	stack.add_child(save)

	save_status = Label.new()
	save_status.name = "SaveStatus"
	save_status.add_theme_font_size_override("font_size", FS.TOOL)
	save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(save_status)
	add_child(panel)

# ── sync: the doc is the single source; overlay + list are projections ─────────

func _sync_all() -> void:
	if page_select != null:
		page_select.select(page_index)
	overlay.call("set_regions", doc.zones)
	overlay.call("set_selected_region", selected)
	if zone_list != null:
		zone_list.call("set_regions", doc.zones, selected)

func _select_zone(index: int) -> void:
	selected = clampi(index, 0, maxi((doc.zones as Array).size() - 1, 0))
	overlay.call("set_selected_region", selected)
	if zone_list.has_method("set_selected"):
		zone_list.call("set_selected", selected)

func _on_draw_requested() -> void:
	overlay.call("set_draw_mode", true)

func _on_zone_drawn(points: Array) -> void:
	if Model.add_zone(doc, points):
		selected = (doc.zones as Array).size() - 1
		_sync_all()

# Geometry/button edits from the overlay handles: adopt the overlay clone by index (it carries
# name/enabled/points/button only — exactly the zone shape).
func _on_zones_changed(next_zones: Array) -> void:
	var zones: Array = doc.zones
	for i in range(mini(zones.size(), next_zones.size())):
		zones[i] = next_zones[i]

func _on_reordered(from_index: int, to_index: int) -> void:
	Model.reorder_zone(doc, from_index, to_index)
	selected = clampi(to_index, 0, (doc.zones as Array).size() - 1)
	_sync_all()

func _on_renamed(index: int, name: String) -> void:
	Model.rename_zone(doc, index, name)

func _on_enabled(index: int, on: bool) -> void:
	Model.set_enabled(doc, index, on)

func _on_deleted(index: int) -> void:
	Model.delete_zone(doc, index)
	selected = clampi(index, 0, maxi((doc.zones as Array).size() - 1, 0))
	_sync_all()

func _save() -> void:
	var res_path: String = Model.unlocks_path(String(pages[page_index].id))
	var path := ProjectSettings.globalize_path(res_path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		save_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		save_status.text = "Save failed: could not write %s" % res_path.get_file()
		push_error("[zone_workbench] could not write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	f.store_string(Model.serialize(doc))
	f.close()
	save_status.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
	save_status.text = "Saved ✓  %d zones → %s" % [(doc.zones as Array).size(), res_path.get_file()]
	print("[zone_workbench] saved %d zones to %s" % [(doc.zones as Array).size(), res_path])
