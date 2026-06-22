extends VBoxContainer
## The region list for the vine authoring tool: one row per hand-drawn polygon, in unlock order
## (list position == order). Each row edits the polygon's name, stars cost, and enabled flag, can be
## deleted, and can be DRAG-REORDERED by its ≡ handle. A header button starts a new polygon draw.
## Pure UI: it owns no region data — it emits intents and is rebuilt from set_regions().

signal draw_requested
signal region_selected(index: int)
signal reordered(from_index: int, to_index: int)
signal region_renamed(index: int, name: String)
signal cost_changed(index: int, cost: int)
signal enabled_changed(index: int, on: bool)
signal deleted(index: int)

const DEFAULT_STARS := 3
const MIN_STARS := 1
const MAX_STARS := 99

var _selected := 0
var _rows: Array = []          # the RegionRow controls, index-aligned with the regions
var _draw_button: Button
var _rows_box: VBoxContainer

# A draggable list row. Its ≡ handle is the drag source; the whole row is a drop target that asks the
# panel to reorder. The interactive widgets (name/stars/on/delete) keep their own input.
class RegionRow extends PanelContainer:
	var panel
	var index := 0

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and (data as Dictionary).has("region_row_from")

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		if panel != null:
			panel._on_row_dropped(int((data as Dictionary)["region_row_from"]), index)

class DragHandle extends Label:
	var row

	func _get_drag_data(_pos: Vector2) -> Variant:
		if row == null:
			return null
		var preview := Label.new()
		preview.text = "≡ move"
		set_drag_preview(preview)
		return {"region_row_from": row.index}

func _init() -> void:
	add_theme_constant_override("separation", 4)
	_draw_button = Button.new()
	_draw_button.name = "DrawPolygon"
	_draw_button.text = "＋ Draw Polygon"
	_draw_button.pressed.connect(func(): draw_requested.emit())
	add_child(_draw_button)
	_rows_box = VBoxContainer.new()
	_rows_box.name = "Rows"
	_rows_box.add_theme_constant_override("separation", 4)
	add_child(_rows_box)

func set_regions(regions: Array, selected: int) -> void:
	_selected = selected
	for row in _rows:
		row.queue_free()
	_rows.clear()
	for i in range(regions.size()):
		_rows.append(_build_row(i, regions[i] if regions[i] is Dictionary else {}))
	_highlight()

func set_selected(index: int) -> void:
	_selected = index
	_highlight()

func get_row_count() -> int:
	return _rows.size()

func _build_row(i: int, region: Dictionary) -> RegionRow:
	var row := RegionRow.new()
	row.panel = self
	row.index = i
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)

	var handle := DragHandle.new()
	handle.row = row
	handle.text = "≡"
	handle.tooltip_text = "Drag to reorder"
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.custom_minimum_size = Vector2(18.0, 0.0)
	box.add_child(handle)

	var pick := Button.new()
	pick.text = "%d" % (i + 1)
	pick.custom_minimum_size = Vector2(28.0, 0.0)
	pick.pressed.connect(func(): region_selected.emit(i))
	box.add_child(pick)

	var name_edit := LineEdit.new()
	name_edit.text = String(region.get("name", "Region %d" % (i + 1)))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(96.0, 0.0)
	name_edit.text_submitted.connect(func(t): region_renamed.emit(i, t))
	name_edit.focus_exited.connect(func(): region_renamed.emit(i, name_edit.text))
	box.add_child(name_edit)

	var stars_label := Label.new()
	stars_label.text = "★"
	box.add_child(stars_label)

	var stars := SpinBox.new()
	stars.name = "Stars"
	stars.min_value = MIN_STARS
	stars.max_value = MAX_STARS
	stars.step = 1.0
	stars.value = float(int(region.get("cost", DEFAULT_STARS)))
	stars.custom_minimum_size = Vector2(56.0, 0.0)
	stars.value_changed.connect(func(v): cost_changed.emit(i, int(v)))
	box.add_child(stars)

	var on := CheckBox.new()
	on.text = "On"
	on.button_pressed = bool(region.get("enabled", true))
	on.toggled.connect(func(pressed): enabled_changed.emit(i, pressed))
	box.add_child(on)

	var del := Button.new()
	del.text = "✕"
	del.tooltip_text = "Delete polygon"
	del.pressed.connect(func(): deleted.emit(i))
	box.add_child(del)

	_rows_box.add_child(row)
	return row

func _highlight() -> void:
	for i in range(_rows.size()):
		var style := StyleBoxFlat.new()
		if i == _selected:
			style.bg_color = Color(0.2, 0.55, 0.7, 0.5)
			style.set_border_width_all(1)
			style.border_color = Color(0.4, 0.9, 1.0, 0.8)
		else:
			style.bg_color = Color(0.1, 0.08, 0.16, 0.35)
		style.set_corner_radius_all(4)
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		_rows[i].add_theme_stylebox_override("panel", style)

func _on_row_dropped(from_index: int, to_index: int) -> void:
	if from_index != to_index:
		reordered.emit(from_index, to_index)
