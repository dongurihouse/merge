extends Control
## Launch Feel workbench — click the generator, a tile is EMITTED (pops up-and-away), repeatedly. The
## right sidebar gives a toggle + sliders for each launch cue (recoil, muzzle puff, toss sound) wired
## to LaunchFx; drag, click the generator (or ▶ Launch again) to FEEL it, Save to config.
##   live:  make launch-workbench

const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const LaunchFx = preload("res://engine/scripts/ui/launch_fx.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

const SIDEBAR_W := 360.0
const CSZ := 150.0
const FIELD := Vector2(560, 780)
const GEN_ID := "seed_satchel"
const TILE_CODE := 102               # a representative mid-tile that "launches"
const GEN_POS := Vector2(280, 420)   # generator centre, field-local (near the CENTER of the field)

const INK := Color("#43352B")
const PARCH := Color("#F3E7CE")
const STRAW := Color("#E3B23C")
const PANEL_BG := Color("#1B1622")
const SCREEN_BG := Color("#2B2330")

var _params: Dictionary = {}
var _field: Control = null
var _tile: Control = null
var _gen_art: Control = null
var _status: Label = null

func _ready() -> void:
	UiFont.apply()
	custom_minimum_size = Vector2(980, 820)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_params = LaunchFx.from_config(Kit.load_config(Kit.CONFIG_PATH))
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

# --- stage: a field with a clickable generator near the centre that EMITS a tile -----------
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

	# the clickable generator
	var gbtn := Button.new()
	gbtn.flat = true
	gbtn.size = Vector2(CSZ, CSZ)
	gbtn.position = GEN_POS - Vector2(CSZ, CSZ) / 2.0
	gbtn.tooltip_text = "Launch a tile"
	var gart := PieceView.make_generator(GEN_ID, CSZ)
	gart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gbtn.add_child(gart)
	_gen_art = gart
	gbtn.pressed.connect(_launch)
	field.add_child(gbtn)

	var hint := Label.new()
	hint.text = "Click the generator ↑"
	hint.add_theme_color_override("font_color", INK)
	hint.add_theme_font_size_override("font_size", 20)
	hint.position = GEN_POS + Vector2(-70, CSZ / 2.0 + 6)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(hint)
	return wrap

func _launch() -> void:
	if _tile != null and is_instance_valid(_tile):
		_tile.queue_free()
	var tile := PieceView.make_piece(TILE_CODE, CSZ)
	var start := GEN_POS - Vector2(CSZ, CSZ) / 2.0
	tile.position = start
	tile.pivot_offset = Vector2(CSZ, CSZ) / 2.0
	tile.scale = Vector2(0.4, 0.4)
	_field.add_child(tile)
	_tile = tile
	# fire the recoil + muzzle puff as it LEAVES the emitter
	LaunchFx.apply(_gen_art, tile, GEN_POS, _params)
	# pop UP-and-away: a small arc (up ~120px then settle) while scaling 0.4 -> 1.0, over ~0.3s
	var up := start + Vector2(80, -120)
	var settle := start + Vector2(80, -40)
	var tw := tile.create_tween()
	tw.parallel().tween_property(tile, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tile, "position", up, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(tile, "position", settle, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _status != null:
		_status.text = "launched — tune + click again to feel it"

# --- sidebar: a toggle + sliders per launch cue, Launch again, Save -------------------------
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

	body.add_child(_title("Launch Feel"))
	body.add_child(_dim("Click the generator to launch. Toggle + tune each cue, then launch again to feel it."))

	var launch := Button.new()
	launch.text = "▶  Launch again"
	launch.add_theme_font_size_override("font_size", 18)
	launch.pressed.connect(_launch)
	body.add_child(launch)

	body.add_child(_toggle_row("All cues (master)", "enabled"))
	body.add_child(_sep())

	for e in LaunchFx.EFFECTS:
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
	"recoil": [["recoil_pct", 0, 200]],
	"puff":   [["puff_count", 0, 30]],
	"sound":  [["sound_db", -24, 0]],
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
	for e in LaunchFx.EFFECTS:
		sub[String(e.id)] = bool(_params.get(String(e.id), true))
	for k in LaunchFx.KNOBS.keys():
		sub[k] = int(_params.get(k, LaunchFx.KNOBS[k]))
	cfg["launch_fx"] = sub
	var f := FileAccess.open(Kit.CONFIG_PATH, FileAccess.WRITE)
	if f == null:
		if _status != null:
			_status.text = "save FAILED (could not open config)"
		return
	f.store_string(JSON.stringify(cfg, "\t"))
	f.close()
	Kit.clear_config_cache(Kit.CONFIG_PATH)
	if _status != null:
		_status.text = "saved to launch_fx ✓"

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
