extends Control
## Move Feel workbench — click ▶ Send (or the tile), a tile TRAVELS across the field, repeatedly. The
## right sidebar gives a master toggle, a KIND selector (slide / arc / fall), and a toggle + sliders for
## each move enhancement (cast shadow, motion trail, motion-lean) wired to MoveFx; tune, click Send again
## to FEEL it, Save to config.
##   live:  make move-workbench

const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const MoveFx = preload("res://engine/scripts/ui/move_fx.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

const SIDEBAR_W := 360.0
const CSZ := 150.0
const FIELD := Vector2(560, 780)
const TILE_CODE := 102                # a representative mid-tile that travels
const START_POS := Vector2(150, 200)  # start point, field-local (top-left)
const DEST_POS := Vector2(410, 580)   # destination point, field-local (bottom-right)

const INK := Color("#43352B")
const PARCH := Color("#F3E7CE")
const STRAW := Color("#E3B23C")
const PANEL_BG := Color("#1B1622")
const SCREEN_BG := Color("#2B2330")

const KINDS := ["slide", "arc", "fall"]

var _params: Dictionary = {}
var _field: Control = null
var _tile: Control = null
var _status: Label = null

func _ready() -> void:
	UiFont.apply()
	custom_minimum_size = Vector2(980, 820)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_params = MoveFx.from_config(Kit.load_config(Kit.CONFIG_PATH))
	if not _params.has("kind"):
		_params["kind"] = "slide"
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
	_reset_tile()

# --- stage: a field with a clickable tile at the START + a destination marker ----------------
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

	# the destination cell marker
	var cell := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK.r, INK.g, INK.b, 0.06)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = Color(INK.r, INK.g, INK.b, 0.18)
	cell.add_theme_stylebox_override("panel", sb)
	cell.size = Vector2(CSZ, CSZ)
	cell.position = DEST_POS - Vector2(CSZ, CSZ) / 2.0
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(cell)

	# the clickable tile sitting at the start — clicking it sends it across
	var sbtn := Button.new()
	sbtn.flat = true
	sbtn.size = Vector2(CSZ, CSZ)
	sbtn.position = START_POS - Vector2(CSZ, CSZ) / 2.0
	sbtn.tooltip_text = "Send the tile"
	sbtn.pressed.connect(_send)
	field.add_child(sbtn)

	var hint := Label.new()
	hint.text = "Click the tile ↓"
	hint.add_theme_color_override("font_color", INK)
	hint.add_theme_font_size_override("font_size", 20)
	hint.position = START_POS + Vector2(-66, -CSZ / 2.0 - 34)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(hint)
	return wrap

func _reset_tile() -> void:
	if _tile != null and is_instance_valid(_tile):
		_tile.queue_free()
	var tile := PieceView.make_piece(TILE_CODE, CSZ)
	tile.position = START_POS - Vector2(CSZ, CSZ) / 2.0
	tile.rotation = 0.0
	_field.add_child(tile)
	_tile = tile

func _send() -> void:
	# reset the tile to the start so the move replays repeatedly
	_reset_tile()
	var start_top := START_POS - Vector2(CSZ, CSZ) / 2.0
	var dest_top := DEST_POS - Vector2(CSZ, CSZ) / 2.0
	var kind := String(_params.get("kind", "slide"))
	MoveFx.apply(_tile, start_top, dest_top, kind, _params)
	if _status != null:
		_status.text = "sent (%s) — tune + send again to feel it" % kind

# --- sidebar: master toggle, kind selector, a toggle + sliders per enhancement, Save ---------
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

	body.add_child(_title("Move Feel"))
	body.add_child(_dim("Click the tile to send it across. Pick a kind, toggle + tune each cue, then send again to feel it."))

	var send := Button.new()
	send.text = "▶  Send again"
	send.add_theme_font_size_override("font_size", 18)
	send.pressed.connect(_send)
	body.add_child(send)

	body.add_child(_toggle_row("All cues (master)", "enabled"))
	body.add_child(_option_row("Kind", "kind", KINDS))
	body.add_child(_slider_row(["duration_ms", 60, 600]))   # travel speed — applies to every kind
	body.add_child(_sep())

	for e in MoveFx.EFFECTS:
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

# which knob sliders show under each cue: [param, lo, hi]. duration sits under the master kind row.
const _KNOBS_FOR := {
	"shadow": [["shadow_alpha_pct", 0, 60]],
	"trail":  [["trail_count", 0, 8]],
	"lean":   [["lean_deg", 0, 20]],
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

# A KIND selector: an OptionButton storing the chosen String in _params[key] (test-only, not a
# numeric knob, but saved as a string in the config too so a reopened workbench restores the choice).
func _option_row(label: String, key: String, options: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", PARCH)
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_font_size_override("font_size", 16)
	var cur := String(_params.get(key, options[0] if not options.is_empty() else ""))
	for i in options.size():
		opt.add_item(String(options[i]), i)
		if String(options[i]) == cur:
			opt.select(i)
	opt.item_selected.connect(func(idx: int) -> void:
		_params[key] = String(options[idx]))
	row.add_child(opt)
	return row

func _save() -> void:
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	if not (cfg is Dictionary):
		cfg = {}
	var sub := {}
	sub["enabled"] = bool(_params.get("enabled", true))
	sub["kind"] = String(_params.get("kind", "slide"))
	for e in MoveFx.EFFECTS:
		sub[String(e.id)] = bool(_params.get(String(e.id), true))
	for k in MoveFx.KNOBS.keys():
		sub[k] = int(_params.get(k, MoveFx.KNOBS[k]))
	cfg["move_fx"] = sub
	var f := FileAccess.open(Kit.CONFIG_PATH, FileAccess.WRITE)
	if f == null:
		if _status != null:
			_status.text = "save FAILED (could not open config)"
		return
	f.store_string(JSON.stringify(cfg, "\t"))
	f.close()
	Kit.clear_config_cache(Kit.CONFIG_PATH)
	if _status != null:
		_status.text = "saved to move_fx ✓"

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
