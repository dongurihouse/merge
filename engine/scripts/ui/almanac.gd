extends RefCounted
## ALMANAC — read-only zone-line status grid. The board coordinator owns the entries and drill-down;
## this file only renders the shared tiers face with line-level states.
##   Almanac.open(host, {entries:Array, on_line:Callable})

const Strings = preload("res://engine/scripts/core/strings.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale

const OVERLAY_NAME := "AlmanacOverlay"

static func open(host: Control, opts: Dictionary) -> void:
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = Game.kit_script()
	if Kit == null:
		push_warning("Almanac: ui kit missing at %s" % Game.kit())
		return
	var entries: Array = opts.get("entries", [])
	if entries.is_empty():
		return
	var on_line: Callable = opts.get("on_line", Callable())
	Audio.play("button_tap", -4.0)

	var modal := Overlay.modal(host, OVERLAY_NAME, {"ink": Pal.GROUND_EDGE})
	var overlay: Control = modal["overlay"]
	var cc: CenterContainer = modal["center"]

	var cfg: Dictionary = Game.kit_config()
	var vw: float = host.get_viewport_rect().size.x
	var width: float = vw * Kit.DIALOG_DESIGN_PCT["tiers"] / 100.0

	var dopts: Dictionary = Kit.tiers_opts_from_config(cfg)
	dopts["content_scale"] = Kit.dialog_content_scale(cfg, "tiers")
	dopts["show_num"] = false
	dopts["banner_text"] = Strings.t("almanac.title")
	dopts["list_max_h"] = host.get_viewport_rect().size.y * 0.66
	dopts["make_content"] = func(d: Dictionary, px: float) -> Control:
		var state := String(d.get("state", ""))
		var art_px := px * (0.62 if state == "away" or state == "complete" else 1.0)
		return PieceView.make_piece(int(d.get("code", 0)), art_px, 0.0)
	dopts["on_close"] = func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()

	var cells := _cells(entries, on_line)
	var grid: Control = Kit.tiers_grid(cells, width, dopts)
	_dress_cells(grid, cells)
	var dialog: Control = Kit.dialog_frame(grid, width, dopts)
	cc.add_child(dialog)
	FX.pop_in(dialog)

static func _cells(entries: Array, on_line: Callable) -> Array:
	var out: Array = []
	for e in entries:
		var line := int(e.get("line", 0))
		var seen := bool(e.get("seen", false))
		var state := String(e.get("state", "complete"))
		var cell := {
			"tier": 0,
			"line": line,
			"seen": seen,
			"marked": seen and state == "producing",
			"code": int(e.get("code", 0)),
			"state": state,
			"back_level": int(e.get("back_level", 0)),
			"for_line": int(e.get("for_line", 0)),
			"dim_bg": seen and state != "producing",
		}
		if seen and on_line.is_valid():
			cell["on_tap"] = _line_tap(on_line, line)
		out.append(cell)
	return out

static func _line_tap(on_line: Callable, line: int) -> Callable:
	return func() -> void:
		on_line.call(line)

static func _dress_cells(grid: Control, cells: Array) -> void:
	var i := 0
	for row in grid.get_children():
		for child in (row as Node).get_children():
			if i < cells.size() and child is Control:
				_dress_cell(child as Control, cells[i], i)
			i += 1

static func _dress_cell(cell: Control, d: Dictionary, idx: int) -> void:
	cell.name = "AlmanacCell%d" % idx
	cell.set_meta("almanac_line", int(d.get("line", 0)))
	cell.set_meta("almanac_state", String(d.get("state", "")))
	cell.set_meta("almanac_seen", bool(d.get("seen", false)))
	if not bool(d.get("seen", false)):
		var q := Label.new()
		q.name = "AlmanacLockedGlyph"
		q.text = "?"
		q.set_anchors_preset(Control.PRESET_FULL_RECT)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", FS.TITLE)
		q.add_theme_color_override("font_color", Color(Pal.INK, 0.82))
		q.add_theme_constant_override("outline_size", 0)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(q)
		return
	var status := _status_text(d)
	if status == "":
		return
	var pill := PanelContainer.new()
	pill.name = "AlmanacStatusPill"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Pal.CREAM, 0.92)
	sb.border_color = Color(Pal.INK, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.anti_aliasing = true
	pill.add_theme_stylebox_override("panel", sb)
	var label := Label.new()
	label.name = "AlmanacStatus"
	label.text = status
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FS.FINE)
	label.add_theme_color_override("font_color", Pal.INK)
	label.add_theme_constant_override("outline_size", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(label)
	cell.add_child(pill)
	var dock := func() -> void:
		if not (is_instance_valid(pill) and is_instance_valid(cell)):
			return
		var h := maxf(20.0, cell.size.y * 0.17)
		pill.size = Vector2(maxf(1.0, cell.size.x - 12.0), h)
		pill.position = Vector2(6.0, cell.size.y - h - 6.0)
	cell.resized.connect(dock)
	dock.call_deferred()

static func _status_text(d: Dictionary) -> String:
	match String(d.get("state", "")):
		"away":
			return Strings.t("almanac.back_at") % int(d.get("back_level", 0))
		"complete":
			return Strings.t("almanac.complete")
	return ""
