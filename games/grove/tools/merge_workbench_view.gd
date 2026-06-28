extends Control
## Merge Feel workbench — click ▶ Merge, tile A slides into tile B and the two FUSE, repeatedly. The
## right sidebar gives a toggle + sliders for each merge cue (squash, flash, hitstop, burst, shake,
## sound, ripple, board punch) wired to MergeFx; drag, click ▶ Merge (again) to FEEL it, Save to
## config. Two TEST sliders at the top (Tier, Combo) drive the escalation but are NOT saved.
##   live:  make merge-workbench

const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const MergeFx = preload("res://engine/scripts/ui/merge_fx.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

const SIDEBAR_W := 360.0
const CSZ := 150.0
const FIELD := Vector2(560, 780)
const TILE_CODE := 101               # two matching tiles (same code) so they MERGE
const NB_CODE := 201                 # dummy neighbours so the ripple is visible
const MERGE_POS := Vector2(280, 420) # the fuse cell centre (tile B), field-local
const SRC_POS := Vector2(110, 420)   # tile A start cell centre, field-local

const INK := Color("#43352B")
const PARCH := Color("#F3E7CE")
const STRAW := Color("#E3B23C")
const PANEL_BG := Color("#1B1622")
const SCREEN_BG := Color("#2B2330")

var _params: Dictionary = {}
var _field: Control = null
var _tile_a: Control = null
var _tile_b: Control = null
var _neighbors: Array = []
var _status: Label = null

func _ready() -> void:
	UiFont.apply()
	custom_minimum_size = Vector2(980, 820)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_params = MergeFx.from_config(Kit.load_config(Kit.CONFIG_PATH))
	# test-only escalation knobs — kept in _params, never saved.
	_params["tier"] = 3
	_params["combo"] = 0
	_build()

func _build() -> void:
	for c in get_children():
		remove_child(c); c.queue_free()
	var bg := ColorRect.new()
	bg.color = SCREEN_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_make_stage())
	root.add_child(_make_sidebar())

# --- stage: a parchment field with two matching tiles + neighbours + a clickable Merge ----------
func _make_stage() -> Control:
	var wrap := CenterContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var field := Control.new()
	field.custom_minimum_size = FIELD
	field.size = FIELD
	field.clip_contents = false
	_field = field
	wrap.add_child(field)

	var card := ColorRect.new()       # parchment field backdrop
	card.color = PARCH
	card.size = FIELD
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(card)

	# the merge (fuse) cell marker
	field.add_child(_cell_marker(MERGE_POS))
	field.add_child(_cell_marker(SRC_POS))

	# the clickable Merge button over the stage
	var mbtn := Button.new()
	mbtn.flat = true
	mbtn.size = FIELD
	mbtn.position = Vector2.ZERO
	mbtn.tooltip_text = "Merge"
	mbtn.mouse_filter = Control.MOUSE_FILTER_PASS
	mbtn.pressed.connect(_merge)
	field.add_child(mbtn)

	var hint := Label.new()
	hint.text = "Click anywhere — or ▶ Merge"
	hint.add_theme_color_override("font_color", INK)
	hint.add_theme_font_size_override("font_size", 20)
	hint.position = Vector2(70, 80)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(hint)

	_spawn_pieces()
	return wrap

func _cell_marker(center: Vector2) -> Panel:
	var cell := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK.r, INK.g, INK.b, 0.06)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = Color(INK.r, INK.g, INK.b, 0.18)
	cell.add_theme_stylebox_override("panel", sb)
	cell.size = Vector2(CSZ, CSZ)
	cell.position = center - Vector2(CSZ, CSZ) / 2.0
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cell

# the four NEIGHBOUR cell offsets around the fuse cell (orthogonal), so the ripple reads.
const _NB_OFFSETS := [Vector2(0, -CSZ + 6), Vector2(0, CSZ - 6), Vector2(-CSZ + 6, 0), Vector2(CSZ - 6, 0)]

func _spawn_pieces() -> void:
	# clear any previous tiles + neighbours
	for n in _neighbors:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_neighbors.clear()
	if _tile_a != null and is_instance_valid(_tile_a):
		_tile_a.queue_free()
	if _tile_b != null and is_instance_valid(_tile_b):
		_tile_b.queue_free()

	# the four dummy neighbours around the merge cell
	for off in _NB_OFFSETS:
		var nb := PieceView.make_piece(NB_CODE, CSZ)
		nb.position = (MERGE_POS + off) - Vector2(CSZ, CSZ) / 2.0
		nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_field.add_child(nb)
		_neighbors.append(nb)

	# tile B sits in the fuse cell; tile A starts in the source cell, same code so they merge.
	var b := PieceView.make_piece(TILE_CODE, CSZ)
	b.position = MERGE_POS - Vector2(CSZ, CSZ) / 2.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(b)
	_tile_b = b

	var a := PieceView.make_piece(TILE_CODE, CSZ)
	a.position = SRC_POS - Vector2(CSZ, CSZ) / 2.0
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(a)
	_tile_a = a

## Replay: rebuild the two tiles + neighbours at their start cells, then slide A into B and fuse.
func _merge() -> void:
	_spawn_pieces()
	var a := _tile_a
	var b := _tile_b
	var merge_top := MERGE_POS - Vector2(CSZ, CSZ) / 2.0
	var tw := a.create_tween()
	tw.tween_property(a, "position", merge_top, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		# A has reached B's cell — the loser vanishes, B is the produced result tile.
		if a != null and is_instance_valid(a):
			a.queue_free()
		var nb_nodes: Array = []
		for n in _neighbors:
			if n != null and is_instance_valid(n):
				nb_nodes.append(n)
		MergeFx.apply(_field, b, MERGE_POS, int(_params.get("tier", 3)), int(_params.get("combo", 0)), nb_nodes, _field, _params))
	if _status != null:
		_status.text = "merged — tune + merge again to feel it"

# --- sidebar: test sliders, a toggle + sliders per merge cue, Merge again, Save -----------------
func _make_sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SIDEBAR_W, 0)
	var pb := StyleBoxFlat.new()
	pb.bg_color = PANEL_BG
	panel.add_theme_stylebox_override("panel", pb)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(SIDEBAR_W - 28, 0)
	scroll.add_child(body)

	body.add_child(_title("Merge Feel"))
	body.add_child(_dim("Click the field to merge. Toggle + tune each cue, then merge again to feel it."))

	var merge := Button.new()
	merge.text = "▶  Merge again"
	merge.add_theme_font_size_override("font_size", 18)
	merge.pressed.connect(_merge)
	body.add_child(merge)

	# test-only escalation sliders (NOT saved) — feel the tier/combo escalation.
	body.add_child(_section("Test (not saved)"))
	body.add_child(_dim("Drive the escalation — tier ramps colour/flash/pitch, combo climbs the pentatonic ladder."))
	body.add_child(_slider_row(["tier", 1, 12]))
	body.add_child(_slider_row(["combo", 0, 10]))
	body.add_child(_sep())

	body.add_child(_toggle_row("All cues (master)", "enabled"))
	body.add_child(_sep())

	for e in MergeFx.EFFECTS:
		var fid := String(e.get("id", ""))
		body.add_child(_section(String(e.get("label", fid))))
		var tip := String(e.get("tip", ""))
		if tip != "":
			body.add_child(_dim(tip))
		body.add_child(_toggle_row("On", fid))
		for spec in _KNOBS_FOR.get(fid, []):
			body.add_child(_slider_row(spec))

	body.add_child(_sep())
	var save := Button.new()
	save.text = "💾  Save to config"
	save.add_theme_font_size_override("font_size", 18)
	save.pressed.connect(_save)
	body.add_child(save)
	_status = _dim("")
	body.add_child(_status)
	return panel

# which knob sliders show under each cue: [param, lo, hi]
const _KNOBS_FOR := {
	"squash":      [],
	"flash":       [["flash_pct", 0, 100]],
	"hitstop":     [["hitstop_ms", 0, 120]],
	"burst":       [["burst_count", 0, 60]],
	"shake":       [["shake_amp", 0, 20]],
	"sound":       [["pitch_base_pct", 80, 160]],
	"ripple":      [["ripple_pct", 0, 100]],
	"board_punch": [["punch_pct", 0, 100]],
}

func _slider_row(spec: Array) -> Control:
	var key: String = spec[0]
	var lo: float = float(spec[1])
	var hi: float = float(spec[2])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = key.replace("_", " ").capitalize()
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", PARCH)
	row.add_child(lbl)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.value = float(int(_params.get(key, 0)))
	s.custom_minimum_size = Vector2(0, 26)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := Label.new()
	val.text = "%d" % int(_params.get(key, 0))
	val.custom_minimum_size = Vector2(48, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", STRAW)
	row.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		_params[key] = int(x)
		val.text = "%d" % int(x))
	return row

func _toggle_row(label: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", PARCH)
	row.add_child(lbl)
	var cb := CheckButton.new()
	cb.button_pressed = bool(_params.get(key, true))
	cb.toggled.connect(func(on: bool) -> void:
		_params[key] = on)
	row.add_child(cb)
	return row

func _save() -> void:
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	if not (cfg is Dictionary):
		cfg = {}
	var sub := {}
	sub["enabled"] = bool(_params.get("enabled", true))
	for e in MergeFx.EFFECTS:
		sub[String(e.id)] = bool(_params.get(String(e.id), true))
	for k in MergeFx.KNOBS.keys():
		sub[k] = int(_params.get(k, MergeFx.KNOBS[k]))
	cfg["merge_fx"] = sub
	var f := FileAccess.open(Kit.CONFIG_PATH, FileAccess.WRITE)
	if f == null:
		if _status != null:
			_status.text = "save FAILED (could not open config)"
		return
	f.store_string(JSON.stringify(cfg, "\t"))
	f.close()
	Kit.clear_config_cache(Kit.CONFIG_PATH)
	if _status != null:
		_status.text = "saved to merge_fx ✓"

# --- tiny styled helpers --------------------------------------------------------------------
func _title(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", STRAW)
	return l

func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color.WHITE)
	return l

func _dim(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(SIDEBAR_W - 40, 0)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color("#9C93A8"))
	return l

func _sep() -> Control:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.08)
	r.custom_minimum_size = Vector2(0, 2)
	return r
