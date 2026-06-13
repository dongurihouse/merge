extends Control
## Ghibli Grove — HOME: the game's hub IS the homestead, seen as one large
## free-pan map (owner 2026-06-11): a high top-down EMPTY terrain with the zones
## (farmhouse → barn → pond → orchard → meadow) as scenery placed at G.ZONES
## map_pos — no boxes, no 0/8 buttons. Each zone's items scatter ON the land
## around its house: level-gated ones sit greyed ("Lv N"), available ones price
## themselves ("✿ N★" — tap to buy with stars), and OWNED ones open their own
## customization list (variants priced in coins or diamonds). Buying grants EXP;
## level-ups gift water+diamonds. A pinned garden button leads to the board.
## Art auto-wires: assets/rooms/map_grove.png + assets/map/poi_<zone_id>.png.

const G = preload("res://scripts/grove_content.gd")
const Save = preload("res://scripts/save.gd")
const Audio = preload("res://scripts/audio.gd")
const Music = preload("res://scripts/music.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Look = preload("res://scripts/skin.gd")
const FX = preload("res://scripts/fx.gd")
const Hud = preload("res://scripts/hud.gd")
const Ambient = preload("res://scripts/ambient.gd")
const Features = preload("res://scripts/features.gd")
const Layout = preload("res://scripts/layout.gd")
const Debug = preload("res://scripts/debug.gd")

const TAP_SLOP := 14.0      # drag farther than this and the release is a pan, not a tap
const ZONE_NAME_DY := 18.0   # R2: name baseline below the building (shared, all zones)
const ZONE_STATUS_DY := 56.0 # R2: status plank top below the building (shared)

# T2: the board's Decorate sets this (a zone id) before changing scene; _ready
# consumes it and opens that interior BEFORE the first draw — no map flash.
# Process-scoped on purpose: a fresh app boot always lands on the map.
static var decorate_zone := ""

# greys a locked POI to "part of the land, not yet awake" (modulate can only tint)
const DESAT_SHADER := "
shader_type canvas_item;
uniform float sat : hint_range(0.0, 1.0) = 0.15;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(g), c.rgb, sat), c.a) * COLOR;
}"

const SKY := Color("#9CCDE8")
const MEADOW := Color("#7FA65A")
const LEAF := Color("#3F6B43")
const INK := Color("#33402F")
const CREAM := Color("#FBF3EA")
const STRAW := Color("#E3B23C")
const BARK := Color("#8A5A3B")
const CLAY := Color("#C96F4A")

var exp_points := 0
var unlocks := {}

var vista: Control               # the map surface (name kept for tools/tests)
var zone_nodes: Array = []       # POI controls, index = zone index
var spot_hits: Array = []        # [{node, z, k}] — the open INTERIOR's spots
var wayside_hits: Array = []     # Z2: [{node, w}] — coin-priced wayside plots on the map
var interior: Control = null     # the room takeover (null = on the map)
var _interior_zone := -1
var _back_hit := Rect2()         # the round back button's tap rect (generous)
var _int_art_rect := Rect2()     # the CONTAIN-fit room art (a dark-tap outside closes)
var _int_head_rect := Rect2()    # the plank header band (taps there don't close)
var _int_cta: Control = null     # T3: "to the board" CTA — hit = its OWN laid-out rect
var _int_press := Vector2.ZERO
var _chrome_nodes: Array = []    # bottom chrome, hidden while inside
var _customize_spot := ""        # spot id whose inline variant strip is open
var variant_hits: Array = []     # [{node, z, k, vid}] — the strip's swatch chips
var level_label: Label
var xp_label: Label
var stars_label: Label
var coins_label: Label
var _hud_refresh := Callable()
var _hud_panels: Array = []       # wallet + Lv chips — hidden in place mode (they'd eat top-zone presses)
var _pan_drag := false
var _pan_start := Vector2.ZERO
var _vista_start := Vector2.ZERO
var _pan_moved := 0.0
# --- dev placement editor (Layout) ---
var _place_overlay: Control = null    # toolbar + readout, kept topmost
var _place_readout: Label = null
var _place_sel_box: Panel = null      # hollow rect over the selected item
var _place_drag: Dictionary = {}      # {kind:"zone"/"spot", z, k, node, grab}
var _place_sel: Dictionary = {}       # last-touched {kind, z, k, node} for size/reset

func _ready() -> void:
	_heal_capture_flags()
	UiFont.apply()
	Music.ensure()
	if get_tree() != null:               # headless harnesses run _ready() out of tree
		get_tree().quit_on_go_back = false   # we close the interior on OS back instead
	_load_state()

	var sky := ColorRect.new()
	sky.color = SKY
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)

	# the map: one large surface, dragged freely on both axes
	var clip := Control.new()
	clip.clip_contents = true
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.mouse_filter = Control.MOUSE_FILTER_STOP    # the map's ONE input surface
	clip.gui_input.connect(_on_pan_input)
	add_child(clip)
	vista = Control.new()
	vista.custom_minimum_size = G.MAP_SIZE
	vista.size = G.MAP_SIZE
	vista.mouse_filter = Control.MOUSE_FILTER_IGNORE # children never eat the pan/tap
	clip.add_child(vista)
	_build_vista()
	_center_on_frontier()

	# the day's weather drifts over the whole scene (calm mode wins inside)
	var g0 := Save.grove()
	Ambient.check_winback(g0, Time.get_unix_time_from_system())
	add_child(Ambient.build_weather(get_viewport_rect().size, Ambient.weather_now(FX.calm())))

	_build_hud()
	_build_chrome()
	_update_hud()
	if _place_on():
		_build_place_ui()

	# T2: arriving from the board's Decorate — walk straight into the room you
	# were decorating (still inside _ready = before the first draw, so the map
	# never flashes). Unknown/locked zones fall through to the map.
	if decorate_zone != "":
		var dz := _zone_for_id(decorate_zone)
		decorate_zone = ""
		if dz >= 0 and zone_unlocked(dz):
			_open_interior(dz)

# The dev capture harness births its windows minimized + focusless via a
# transient override.cfg (tools/quiet_godot.sh). If a REAL launch ever inherits
# those flags — a leaked file, or launching while a capture is in flight — the
# game self-heals at boot: restore the window, delete a leftover that is OURS.
# Quiet runs export TU_QUIET=1 and are exempt (their windows must stay hidden).
func _heal_capture_flags() -> void:
	if OS.get_environment("TU_QUIET") == "1":
		return
	if FileAccess.file_exists("res://override.cfg"):
		var txt := FileAccess.get_file_as_string("res://override.cfg")
		if "window/size/no_focus=true" in txt:
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://override.cfg"))
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, false)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _zone_for_id(id: String) -> int:
	for z in G.ZONES.size():
		if String(G.ZONES[z].id) == id:
			return z
	return -1

func _load_state() -> void:
	var g := Save.grove()
	exp_points = int(g.get("exp", 0))
	unlocks = g.get("unlocks", {})
	# T1: sanitize — a last_zone that no longer names a zone is dropped
	if g.has("last_zone") and _zone_for_id(String(g.last_zone)) < 0:
		g.erase("last_zone")
	if not g.has("unlocks"):
		g["unlocks"] = unlocks

func _persist() -> void:
	var g := Save.grove()
	g["exp"] = exp_points
	g["unlocks"] = unlocks
	g["last_seen"] = Time.get_unix_time_from_system()   # the win-back reads this
	Save.grove_write()

# --- progression queries ------------------------------------------------------------

func spot_owned(id: String) -> bool:
	return unlocks.has(id)

func zone_complete(z: int) -> bool:
	return G.zone_done(z, unlocks)

func zone_unlocked(z: int) -> bool:
	return z == 0 or zone_complete(z - 1)

func owned_count(z: int) -> int:
	var n := 0
	for s in G.ZONES[z].spots:
		if spot_owned(String(s.id)):
			n += 1
	return n

# Z: wayside decorations — the COIN sink. Owned-set + the buy transaction (coins only,
# never level-gated; available once its zone is restored). Pure cosmetics.
func wayside_owned(id: String) -> bool:
	return Save.grove().get("waysides", {}).has(id)

func buy_wayside(w: Dictionary) -> bool:
	var id := String(w.id)
	if wayside_owned(id) or not G.wayside_available(w, unlocks):
		return false
	if not Save.spend(int(w.cost), "wayside"):
		return false                 # not enough coins — caller wobbles
	var g := Save.grove()
	if not g.has("waysides"):
		g["waysides"] = {}
	g["waysides"][id] = true
	_persist()
	return true

# --- the map: zones are CHESTS with lids (owner 2026-06-11) -----------------------------
# Closed = the building + ONE status line (how to open, or the stars left inside).
# Tap an unlocked zone and its lid opens IN PLACE, revealing the unlockables —
# a tidy list of items (chair, hearth...) each with its star price / level gate /
# owned state right next to it. Tap the land (or another zone) to close it.

func zone_stars_left(z: int) -> int:
	var left := 0
	for s in G.ZONES[z].spots:
		if not spot_owned(String(s.id)):
			left += int(s.cost)
	return left

func _build_vista() -> void:
	for c in vista.get_children():
		c.queue_free()
	zone_nodes.clear()
	spot_hits.clear()
	# the land: generated EMPTY top-down terrain when present, painted ground until then
	if ResourceLoader.exists("res://assets/rooms/map_grove.png"):
		var t := TextureRect.new()
		t.texture = load("res://assets/rooms/map_grove.png")
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vista.add_child(t)
	else:
		var meadow := ColorRect.new()
		meadow.color = MEADOW
		meadow.set_anchors_preset(Control.PRESET_FULL_RECT)
		meadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vista.add_child(meadow)
		var blot_rng := RandomNumberGenerator.new()
		blot_rng.seed = 7                       # deterministic grass mottling (pan feedback)
		for i in 70:
			var blot := Panel.new()
			var r := blot_rng.randf_range(40.0, 150.0)
			blot.custom_minimum_size = Vector2(r, r) * Vector2(1.0, 0.62)
			blot.position = Vector2(blot_rng.randf() * (G.MAP_SIZE.x - r), blot_rng.randf() * (G.MAP_SIZE.y - r))
			var bs := StyleBoxFlat.new()
			bs.bg_color = MEADOW.lerp(LEAF, blot_rng.randf_range(0.10, 0.45))
			bs.set_corner_radius_all(int(r / 2.0))
			blot.add_theme_stylebox_override("panel", bs)
			blot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vista.add_child(blot)
	variant_hits.clear()
	# ambient life wanders BETWEEN the terrain and the buildings (order L)
	vista.add_child(Ambient.build_layer(G.MAP_SIZE, unlocks))
	for z in G.ZONES.size():
		var node := _make_zone_closed(z)
		vista.add_child(node)
		zone_nodes.append(node)
	# Z2: the coin sink — wayside plots scattered along the paths (provisional positions;
	# the owner finalizes with the placement tool). 3 states: dormant → coin-pin → owned.
	wayside_hits.clear()
	if Features.on("wayside_decor"):
		for w in G.waysides():
			var wp := _make_wayside(w)
			vista.add_child(wp)
			wayside_hits.append({"node": wp, "w": w})


func _poi_art(z: int, open: bool, px: float) -> Control:
	var art_path := "res://assets/map/poi_%s.png" % String(G.ZONES[z].id)
	var art: Control
	if ResourceLoader.exists(art_path):
		var t := TextureRect.new()
		t.texture = load(art_path)
		t.size = Vector2(px, px)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art = t
	else:
		var disc := Panel.new()
		disc.size = Vector2(px, px) * 0.78
		disc.position = Vector2(px, px) * 0.11
		var ds := StyleBoxFlat.new()
		ds.bg_color = (CLAY if z == 0 else BARK).lerp(Color.WHITE, 0.12)
		ds.set_corner_radius_all(int(px * 0.39))
		ds.set_border_width_all(5)
		ds.border_color = CREAM
		ds.shadow_color = Color(0, 0, 0, 0.25)
		ds.shadow_size = 8
		ds.shadow_offset = Vector2(0, 5)
		disc.add_theme_stylebox_override("panel", ds)
		art = disc
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not open:
		var sm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = DESAT_SHADER
		sm.shader = sh
		art.material = sm
		art.modulate = Color(0.72, 0.74, 0.72, 0.9)
	return art

# Z2: a wayside plot — 3 states. dormant ghost (its zone not restored) → ghosted
# prop + a coin-cost pin (available, unowned) → the full placed prop (owned).
func _make_wayside(w: Dictionary) -> Control:
	var px := 92.0
	var holder := Control.new()
	holder.position = (Vector2(w.map_pos) * G.MAP_SIZE) - Vector2(px, px) * 0.5
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spr := TextureRect.new()
	if ResourceLoader.exists(String(w.tex)):
		spr.texture = load(String(w.tex))
	spr.size = Vector2(px, px)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(spr)
	if wayside_owned(String(w.id)):
		return holder                                   # the placed prop, full
	if not G.wayside_available(w, unlocks):
		spr.modulate = Color(0.70, 0.72, 0.70, 0.22)    # dormant — its zone isn't restored yet
		return holder
	spr.modulate = Color(1, 1, 1, 0.45)                 # available: a ghost preview + a price pin
	var pin := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("#FBF6EC", 0.96)
	ps.set_corner_radius_all(14)
	ps.set_border_width_all(2)
	ps.border_color = Color("#C9A66B", 0.9)
	ps.shadow_color = Color(0, 0, 0, 0.22)
	ps.shadow_size = 4
	ps.content_margin_left = 10.0
	ps.content_margin_right = 10.0
	ps.content_margin_top = 3.0
	ps.content_margin_bottom = 4.0
	pin.add_theme_stylebox_override("panel", ps)
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.add_child(row)
	row.add_child(Look.icon("coin", 26.0))
	var cl := Label.new()
	cl.text = str(int(w.cost))
	cl.add_theme_font_size_override("font_size", 22)
	cl.add_theme_color_override("font_color", Color("#33402F"))
	cl.add_theme_constant_override("outline_size", 0)
	row.add_child(cl)
	pin.position = Vector2(px * 0.5 - 30.0, px - 6.0)
	holder.add_child(pin)
	return holder

# Z2: tap an available plot to BUY it (coins only, never a gate) — wobble if its zone
# isn't restored or you can't afford it.
func _on_wayside_tap(w: Dictionary, node: Control, at: Vector2) -> void:
	if wayside_owned(String(w.id)):
		return
	if not G.wayside_available(w, unlocks):
		Audio.play("invalid_soft", -4.0)
		FX.wobble(node)
		FX.floating_text(self, at - Vector2(160, 64), tr("Restore %s first ✿") % tr(G.ZONES[int(w.zone_req)].name), Color(CREAM, 0.9), 28)
		return
	if not buy_wayside(w):
		Audio.play("invalid_soft", -4.0)
		FX.wobble(node)
		FX.floating_text(self, at - Vector2(120, 64), tr("Need %d🪙 more") % maxi(0, int(w.cost) - Save.coins()), Color(CREAM, 0.9), 28)
		return
	FX.burst(self, at, STRAW, 16)
	Audio.play("level_complete", -6.0, 1.15)
	FX.floating_text(self, at - Vector2(70, 60), tr("%s placed ✿") % tr(String(w.name)), CREAM, 28)
	_update_hud()
	_build_vista()

# Lid CLOSED: the building, its name, and one honest status line.
func _make_zone_closed(z: int) -> Control:
	var zone: Dictionary = G.ZONES[z]
	var open := zone_unlocked(z)
	var done := zone_complete(z)
	var poi := Control.new()
	poi.size = Vector2(G.POI_SIZE, G.POI_SIZE + 104.0)
	poi.position = Layout.zone_map_pos(z) * G.MAP_SIZE - Vector2(G.POI_SIZE / 2.0, G.POI_SIZE / 2.0)
	poi.pivot_offset = Vector2(G.POI_SIZE / 2.0, G.POI_SIZE / 2.0)
	poi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poi.add_child(_poi_art(z, open, G.POI_SIZE))
	if _place_on():
		poi.add_child(_make_crosshair(Vector2(G.POI_SIZE / 2.0, G.POI_SIZE / 2.0), STRAW))
	# S5 (refines R2): name AND status ride ONE plank, centered UNDER the
	# building — neither line ever sits on the art. One shared offset, all zones.
	var stxt: String
	var scol: Color
	if done:
		stxt = tr("✿ restored"); scol = STRAW
	elif open:
		stxt = tr("✿ %d★ left") % zone_stars_left(z); scol = CREAM
	else:
		stxt = tr("✿ after %s") % tr(G.ZONES[z - 1].name); scol = Color(CREAM, 0.7)
	poi.add_child(_zone_status_plank(tr(zone.name), open, stxt, scol, G.POI_SIZE + ZONE_NAME_DY))
	if open and not done and z == _frontier_zone():
		FX.breathe_once(poi)
	return poi

# R2+S5: the zone pin — NAME line + STATUS line on one plank, anchored
# bottom-center under the building (anchor x=0.5, grow both → always on the
# POI's center axis, whatever the content width). Both lines centered.
func _zone_status_plank(zname: String, open: bool, status: String, scol: Color, top: float) -> Control:
	var plank := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3D2A1B", 0.84)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = Color("#2A1C11", 0.9)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 7.0
	plank.add_theme_stylebox_override("panel", sb)
	plank.anchor_left = 0.5
	plank.anchor_right = 0.5
	plank.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plank.offset_top = top
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plank.add_child(col)
	var name_l := Label.new()
	name_l.text = zname
	name_l.add_theme_font_size_override("font_size", 26)
	name_l.add_theme_color_override("font_color", CREAM if open else Color(CREAM, 0.6))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_l)
	var lbl := Label.new()
	lbl.text = status
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", scol)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(lbl)
	return plank

# --- THE INTERIOR (order K; spec §0c #10 — supersedes the on-map scatter) --------
# The map keeps ONLY closed chests. Tapping an unlocked zone walks INSIDE:
# a full-screen room under the pinned HUD (bottom chrome hidden while open).
# The room art is the screen; spots sit at their painted plots (spot.pos maps
# to the ART RECT); owned spots draw furniture sprites when the art exists.
# The interior is its own ONE input surface — every visual child IGNOREs.

func _open_interior(z: int) -> void:
	if interior != null:
		return
	_interior_zone = z
	_customize_spot = ""
	# T1: remember WHERE the player decorates — the board's Decorate jumps here
	var gz := Save.grove()
	gz["last_zone"] = String(G.ZONES[z].id)
	Save.grove_write()
	Audio.play("roof_open" if Audio.has("roof_open") else "button_tap", -2.0)
	for c in _chrome_nodes:
		if is_instance_valid(c):
			c.visible = false
	var amb: Control = vista.get_node_or_null("AmbientLayer")
	if amb != null:
		amb.set_meta("paused", true)
	interior = Control.new()
	interior.set_anchors_preset(Control.PRESET_FULL_RECT)
	interior.mouse_filter = Control.MOUSE_FILTER_STOP
	interior.gui_input.connect(_on_interior_input)
	add_child(interior)
	move_child(interior, 2)          # above sky+map, UNDER the Hud module
	_build_interior()
	_place_clear_sel()
	_place_raise()

func _close_interior() -> void:
	if interior == null:
		return
	interior.queue_free()
	interior = null
	_int_cta = null
	_interior_zone = -1
	_customize_spot = ""
	spot_hits.clear()
	variant_hits.clear()
	for c in _chrome_nodes:
		if is_instance_valid(c):
			c.visible = true
	Audio.play("button_tap", -4.0)
	_place_clear_sel()
	_build_vista()                   # rebuild un-pauses the ambient layer too
	_place_raise()
	_place_hide_map_chrome()         # re-hide (the chrome-restore above un-hid it)

func _build_interior() -> void:
	for c in interior.get_children():
		c.queue_free()
	spot_hits.clear()
	variant_hits.clear()
	var z := _interior_zone
	var view := get_viewport_rect().size
	# warm room-tone surround (fills whatever the 3:4 art doesn't)
	var tone := ColorRect.new()
	tone.color = Color("#3A2D1E")
	tone.set_anchors_preset(Control.PRESET_FULL_RECT)
	tone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interior.add_child(tone)
	var room := Control.new()        # everything that pops in together
	room.set_anchors_preset(Control.PRESET_FULL_RECT)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interior.add_child(room)
	# plank header under the hud: back · zone name · stars-left
	var head_y := 96.0 + Look.safe_top(self)
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", Look.kit_panel("plank"))
	# the plank starts PAST the back button so the wooden circle sits on the dark
	# room tone and reads as pressable (wood-on-wood made it vanish — owner report)
	header.position = Vector2(118, head_y)
	header.size = Vector2(view.x - 130.0, 96.0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(header)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 14)
	hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(hrow)
	# S9: the title CENTERS on the plank (an overlay, not a row slot) and the
	# ✿-progress docks right INSIDE the content margin — nothing clips
	var hov := Control.new()
	hov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(hov)
	var title := Label.new()
	title.text = tr(G.ZONES[z].name)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hov.add_child(title)
	var left_l := Label.new()
	left_l.text = tr("✿ restored") if zone_complete(z) else tr("✿ %d★ left") % zone_stars_left(z)
	left_l.add_theme_font_size_override("font_size", 26)
	left_l.add_theme_color_override("font_color", STRAW)
	left_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_l.anchor_left = 1.0
	left_l.anchor_right = 1.0
	left_l.anchor_top = 0.0
	left_l.anchor_bottom = 1.0
	left_l.offset_right = -10.0
	left_l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	left_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hov.add_child(left_l)
	_back_hit = Rect2(Vector2(2, head_y - 12.0), Vector2(116, 116))
	_int_head_rect = Rect2(Vector2(118, head_y), Vector2(view.x - 130.0, 96.0))
	# the room art: CONTAIN-fit 3:4 below the header (pins map to THIS rect)
	var top := head_y + 112.0
	var avail := Rect2(Vector2(0, top), Vector2(view.x, view.y - top - 24.0 - Look.safe_bottom(self)))
	var art_h: float = minf(avail.size.y, avail.size.x / 0.75)
	var art_sz := Vector2(art_h * 0.75, art_h)
	var art_rect := Rect2(avail.position + (avail.size - art_sz) / 2.0, art_sz)
	var art_path := "res://assets/rooms/int_%s.png" % String(G.ZONES[z].id)
	if ResourceLoader.exists(art_path):
		var t := TextureRect.new()
		t.texture = load(art_path)
		t.position = art_rect.position
		t.size = art_rect.size
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		room.add_child(t)
	else:
		var fallback := Panel.new()
		fallback.position = art_rect.position
		fallback.size = art_rect.size
		var fs := StyleBoxFlat.new()
		fs.bg_color = Color("#EAD9B8")
		fs.set_corner_radius_all(24)
		fs.set_border_width_all(5)
		fs.border_color = BARK
		fallback.add_theme_stylebox_override("panel", fs)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		room.add_child(fallback)
	var lvl := G.level_for_exp(exp_points)
	for k in G.ZONES[z].spots.size():
		var pin := _make_interior_spot(z, k, lvl, art_rect)
		room.add_child(pin)
		spot_hits.append({"node": pin, "z": z, "k": k})
	_int_art_rect = art_rect
	# THE way out — a REAL round button riding the plank's left end (owner report:
	# "no way to go back" — the old inline arrow read as wood-grain decoration)
	var back := Panel.new()
	back.size = Vector2(92, 92)
	back.position = Vector2(14, head_y + 2.0)
	if ResourceLoader.exists(Look.KIT + "btn_round.png"):
		var bs := StyleBoxTexture.new()
		bs.texture = load(Look.KIT + "btn_round.png")
		bs.set_texture_margin_all(24.0)
		back.add_theme_stylebox_override("panel", bs)
	else:
		var bf := StyleBoxFlat.new()
		bf.bg_color = Color("#6E4B2F")
		bf.set_corner_radius_all(46)
		bf.set_border_width_all(4)
		bf.border_color = Color(CREAM, 0.85)
		bf.shadow_color = Color(0, 0, 0, 0.35)
		bf.shadow_size = 8
		back.add_theme_stylebox_override("panel", bf)
	var bicon := Look.icon("back", 46.0)
	bicon.set_anchors_preset(Control.PRESET_FULL_RECT)
	if bicon is Label:
		(bicon as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(bicon as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(bicon)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interior.add_child(back)         # above the room — it must never blend away
	# T3: "to the board" CTA — the SAME kit button in the SAME slot/size as the
	# map's garden CTA (one muscle memory). Visual only (the interior is ONE
	# input surface); the tap resolves via _int_cta_rect in _on_interior_input.
	var sb_cta := Look.safe_bottom(self)
	var cta := Look.button(tr("Tend the garden ▶"), func() -> void: pass, true)
	cta.custom_minimum_size = Vector2(380, 96)
	cta.anchor_left = 0.5
	cta.anchor_right = 0.5
	cta.anchor_top = 1.0
	cta.anchor_bottom = 1.0
	cta.offset_left = -190
	cta.offset_right = 190
	cta.offset_top = -120 - sb_cta
	cta.offset_bottom = -24 - sb_cta
	cta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interior.add_child(cta)
	_int_cta = cta                   # hit-tested against its laid-out rect (no dup math)
	FX.pop_in(room)
	_place_resync_sel()
	_place_raise()

# One spot inside the room: furniture art when owned (and generated), else the
# 3-state pin + name. The customize strip rides directly beneath when open.
func _make_interior_spot(z: int, k: int, lvl: int, art_rect: Rect2) -> Control:
	var spot: Dictionary = G.ZONES[z].spots[k]
	var pos: Vector2 = art_rect.position + Layout.spot_pos(z, k) * art_rect.size
	var item := Control.new()
	item.size = Vector2(180, 150)
	item.position = pos - Vector2(90, 40)
	item.pivot_offset = Vector2(90, 50)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var owned := spot_owned(String(spot.id))
	var gated := G.spot_level_req(z, k) > lvl
	var furn_path := "res://assets/rooms/furn_%s.png" % String(spot.id)
	# debug place mode shows the real sprite for EVERY spot that has art (even
	# unowned/locked) so the owner drags the actual item, not just its price pin
	if (owned or _place_on()) and ResourceLoader.exists(furn_path):
		var f := TextureRect.new()
		# ORDER MATTERS: expand_mode must precede size — with the default
		# EXPAND_KEEP_SIZE the texture's 512px min CLAMPS size up and a later
		# expand_mode never shrinks it back (every sprite rendered 512px; the
		# Q3 probe caught it). Footprint is per-spot data (fsize, px on the art).
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		f.texture = load(furn_path)
		var fs: float = Layout.spot_fsize(z, k)
		f.size = Vector2(fs, fs)
		f.position = Vector2(90.0 - fs / 2.0, 60.0 - fs / 2.0)   # centered on the plot
		# S8: the variant is a SUBTLE wash (was a full multiply — green wood read
		# as a bug) + a swatch dot so the chosen look still reads at a glance
		var vcur := _spot_variant(z, k)
		f.modulate = Color.WHITE.lerp(Color(vcur.tint), 0.28) if String(vcur.id) != "base" else Color.WHITE
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(f)
		if String(vcur.id) != "base":
			var dot := Panel.new()
			dot.size = Vector2(18, 18)
			dot.position = Vector2(140, 14)
			var ds := StyleBoxFlat.new()
			ds.bg_color = Color(vcur.tint)
			ds.set_corner_radius_all(9)
			ds.set_border_width_all(2)
			ds.border_color = Color(CREAM, 0.9)
			dot.add_theme_stylebox_override("panel", ds)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			item.add_child(dot)
	elif owned:
		var chip := PanelContainer.new()
		var fs := StyleBoxFlat.new()
		var cur := _spot_variant(z, k)
		fs.bg_color = CLAY.lerp(Color.WHITE, 0.18).lerp(Color(cur.tint), 0.45 if String(cur.id) != "base" else 0.0)
		fs.set_corner_radius_all(16)
		fs.set_border_width_all(3)
		fs.border_color = Color("#E8C84A") if String(cur.id) == "gem" else BARK
		fs.content_margin_left = 12.0
		fs.content_margin_right = 12.0
		fs.content_margin_top = 8.0
		fs.content_margin_bottom = 8.0
		chip.add_theme_stylebox_override("panel", fs)
		var cl := Label.new()
		cl.text = tr(spot.name)
		cl.add_theme_font_size_override("font_size", 23)
		cl.add_theme_color_override("font_color", INK)
		chip.add_child(cl)
		chip.position = Vector2(28, 30)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(chip)
	else:
		# S7: ONE anchor rule — price chip + name stack CENTERED UNDER the plot
		# point, ≥28px chip text, never covering the plot the furniture will fill
		var stack := VBoxContainer.new()
		stack.anchor_left = 0.0
		stack.anchor_right = 1.0
		stack.offset_top = 50.0
		stack.add_theme_constant_override("separation", 2)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pin := PanelContainer.new()
		pin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var ps := StyleBoxFlat.new()
		ps.set_corner_radius_all(19)
		ps.content_margin_left = 16.0
		ps.content_margin_right = 16.0
		ps.content_margin_top = 6.0
		ps.content_margin_bottom = 6.0
		ps.shadow_color = Color(0, 0, 0, 0.3)
		ps.shadow_size = 4
		var prow := HBoxContainer.new()
		prow.alignment = BoxContainer.ALIGNMENT_CENTER
		prow.add_theme_constant_override("separation", 5)
		prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ptxt := Label.new()
		ptxt.add_theme_font_size_override("font_size", 28)
		var kit_icons := ResourceLoader.exists(Look.KIT + "icon_star.png")
		if gated:
			ps.bg_color = Color("#4A4F46", 0.72)
			if kit_icons and ResourceLoader.exists(Look.KIT + "icon_lock.png"):
				prow.add_child(Look.icon("lock", 24.0))
				ptxt.text = str(G.spot_level_req(z, k))
			else:
				ptxt.text = tr("Lv %d") % G.spot_level_req(z, k)
			ptxt.add_theme_color_override("font_color", Color(CREAM, 0.55))
		else:
			ps.bg_color = Color(INK, 0.85)
			ps.set_border_width_all(2)
			ps.border_color = STRAW
			if kit_icons:
				prow.add_child(Look.icon("star", 26.0))
				ptxt.text = str(int(spot.cost))
			else:
				ptxt.text = tr("✿ %d★") % int(spot.cost)
			ptxt.add_theme_color_override("font_color", CREAM)
		prow.add_child(ptxt)
		pin.add_theme_stylebox_override("panel", ps)
		pin.add_child(prow)
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(pin)
		var name_l := _lbl(tr(spot.name), 24, CREAM if not gated else Color(CREAM, 0.55))
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(name_l)
		item.add_child(stack)
		if not gated and z == _frontier_zone() and _is_cheapest_open(z, k, lvl):
			FX.breathe_once(item)
	if owned and _customize_spot == String(spot.id):
		_add_variant_strip(item, z, k)
	if _place_on():
		item.add_child(_make_crosshair(Vector2(90, 40), Color("#E84AC0")))
	return item

# The inline customize strip (unchanged law: chips are IGNORE visuals resolved
# by the interior's input surface via variant_hits).
func _add_variant_strip(item: Control, z: int, k: int) -> void:
	var current := String(_spot_variant(z, k).id)
	var variants: Array = G.spot_variants(z, k)
	for i in variants.size():
		var v: Dictionary = variants[i]
		var chip := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(INK, 0.82)
		cs.set_corner_radius_all(14)
		cs.set_border_width_all(3 if String(v.id) == current else 1)
		cs.border_color = STRAW if String(v.id) == current else Color(CREAM, 0.35)
		cs.content_margin_left = 8.0
		cs.content_margin_right = 10.0
		cs.content_margin_top = 5.0
		cs.content_margin_bottom = 5.0
		chip.add_theme_stylebox_override("panel", cs)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(row)
		var sw := ColorRect.new()
		sw.color = Color(v.tint) if String(v.id) != "base" else Color(CLAY.lerp(Color.WHITE, 0.18))
		sw.custom_minimum_size = Vector2(22, 22)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sw)
		var price := Label.new()
		if String(v.id) == current:
			price.text = "✓"
		elif String(v.currency) == "coins":
			price.text = "%d🪙" % int(v.cost)
		elif String(v.currency) == "diamonds":
			price.text = "%d💎" % int(v.cost)
		else:
			price.text = tr("Classic")
		price.add_theme_font_size_override("font_size", 19)
		price.add_theme_color_override("font_color", CREAM)
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(price)
		chip.position = Vector2(2.0 + i * 60.0, 110.0)
		item.add_child(chip)
		variant_hits.append({"node": chip, "z": z, "k": k, "vid": String(v.id)})

# The interior's input: still-tap resolution for back / swatches / pins.
func _on_interior_input(event: InputEvent) -> void:
	if _place_on() and _place_interior_input(event):
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) \
		or event is InputEventScreenTouch
	if pressed and event.pressed:
		_int_press = event.position
	elif pressed and not event.pressed and event.position.distance_to(_int_press) <= 18.0:
		var gpos: Vector2 = event.position
		if _back_hit.has_point(gpos):
			_close_interior()
			return
		if _int_cta != null and is_instance_valid(_int_cta) \
				and _int_cta.get_global_rect().grow(4.0).has_point(gpos):
			_on_board()                  # T3: straight back to the board
			return
		for hit in variant_hits:
			var vn: Control = hit.node
			if vn.get_global_rect().grow(6.0).has_point(gpos):
				_apply_variant(int(hit.z), int(hit.k), String(hit.vid), gpos)
				return
		for hit in spot_hits:
			var n: Control = hit.node
			if n.get_global_rect().grow(8.0).has_point(gpos):
				_on_spot_tap(int(hit.z), int(hit.k), n, gpos)
				return
		if _customize_spot != "":
			_customize_spot = ""
			_build_interior()
			return
		# a tap on the dark surround — outside the room art and its header —
		# steps back out the door (the lost thumb's path off the screen)
		if not _int_art_rect.grow(16.0).has_point(gpos) and not _int_head_rect.has_point(gpos):
			_close_interior()


func _is_cheapest_open(z: int, k: int, lvl: int) -> bool:
	var my_cost := int(G.ZONES[z].spots[k].cost)
	for j in G.ZONES[z].spots.size():
		var s: Dictionary = G.ZONES[z].spots[j]
		if spot_owned(String(s.id)) or G.spot_level_req(z, j) > lvl:
			continue
		if int(s.cost) < my_cost or (int(s.cost) == my_cost and j < k):
			return j == k
	return true

func _spot_variant(z: int, k: int) -> Dictionary:
	var chosen := String(Save.grove().get("custom", {}).get(String(G.ZONES[z].spots[k].id), "base"))
	for v in G.spot_variants(z, k):
		if String(v.id) == chosen:
			return v
	return G.spot_variants(z, k)[0]

func _frontier_zone() -> int:
	for z in G.ZONES.size():
		if zone_unlocked(z) and not zone_complete(z):
			return z
	return -1

# Open with the story's current chapter in view — slightly above center, clear
# of the pinned garden button along the bottom.
func _center_on_frontier() -> void:
	var z := _frontier_zone()
	if z < 0:
		z = G.ZONES.size() - 1
	var target: Vector2 = get_viewport_rect().size * Vector2(0.5, 0.40) - Layout.zone_map_pos(z) * G.MAP_SIZE
	vista.position = _clamp_pan(target)

func _clamp_pan(p: Vector2) -> Vector2:
	var view := get_viewport_rect().size
	return Vector2(
		clampf(p.x, minf(view.x - G.MAP_SIZE.x, 0.0), 0.0),
		clampf(p.y, minf(view.y - G.MAP_SIZE.y, 0.0), 0.0))

# One handler does both: drag pans the land, a still release taps what's under it.
func _on_pan_input(event: InputEvent) -> void:
	if _place_on() and _place_map_input(event):
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) \
		or event is InputEventScreenTouch
	if pressed and event.pressed:
		_pan_drag = true
		_pan_moved = 0.0
		_pan_start = event.position
		_vista_start = vista.position
	elif pressed and not event.pressed:
		if _pan_drag and _pan_moved <= TAP_SLOP:
			_on_map_tap(event.position)
		_pan_drag = false
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and _pan_drag:
		_pan_moved = maxf(_pan_moved, (event.position - _pan_start).length())
		vista.position = _clamp_pan(_vista_start + (event.position - _pan_start))

func _on_map_tap(screen_pos: Vector2) -> void:
	for z in zone_nodes.size():
		if not zone_nodes[z].get_global_rect().has_point(screen_pos):
			continue
		if zone_unlocked(z):
			_open_interior(z)             # walk inside (order K)
		else:
			Audio.play("invalid_soft", -4.0)
			FX.wobble(zone_nodes[z])
			FX.floating_text(self, screen_pos - Vector2(150, 70),
				tr("Restore %s first ✿") % tr(G.ZONES[maxi(z - 1, 0)].name), Color(CREAM, 0.9), 30)
		return
	# Z2: a wayside plot? buy it with coins (the structural sink)
	for hit in wayside_hits:
		if (hit.node as Control).get_global_rect().has_point(screen_pos):
			_on_wayside_tap(hit.w, hit.node, screen_pos)
			return
	# a wandering spirit? a tap earns a hop (pure charm, v1)
	var amb: Control = vista.get_node_or_null("AmbientLayer")
	if amb != null:
		for sp in amb.get_children():
			if (sp as Control).get_global_rect().grow(10.0).has_point(screen_pos):
				if Features.on("spirit_tap_hop"):
					Ambient.hop(sp)
					Audio.play("button_tap", -8.0)
				return


# --- buying & customizing, right on the land (the close-up modal retired) ---------------

func _on_spot_tap(z: int, k: int, node: Control, at: Vector2) -> void:
	var spot: Dictionary = G.ZONES[z].spots[k]
	if spot_owned(String(spot.id)):
		if not Features.on("customize_variants"):
			return
		Audio.play("button_tap", -2.0)
		_customize_spot = "" if _customize_spot == String(spot.id) else String(spot.id)
		if interior != null:
			_build_interior()
		else:
			_build_vista()
		return
	var lvl := G.level_for_exp(exp_points)
	if G.spot_level_req(z, k) > lvl:
		Audio.play("invalid_soft", -4.0)
		FX.wobble(node)
		FX.floating_text(self, at - Vector2(120, 64), tr("Reach Lv %d \u2740") % G.spot_level_req(z, k), Color(CREAM, 0.9), 30)
		return
	var cost := int(spot.cost)
	if not Save.spend_stars(cost):
		Audio.play("invalid_soft", -4.0)
		FX.wobble(node)
		FX.floating_text(self, at - Vector2(110, 64), tr("Need %d more") % (cost - Save.stars()), Color(CREAM, 0.9), 30)
		return
	unlocks[String(spot.id)] = true
	FX.burst(self, at, STRAW, 18)
	Audio.play("level_complete", -6.0, 1.2)
	# this purchase IS the chapter gate: pay the closing chapter's water gift,
	# and the garden's givers come back with the next chapter's asks
	var closing := unlocks.size() - 1
	var gift := int(G.chapters()[mini(closing, G.chapters().size() - 1)].get("gift", 0))
	if gift > 0:
		var gw := Save.grove()
		gw["water"] = mini(G.WATER_CAP, int(gw.get("water", G.WATER_CAP)) + gift)
		FX.floating_text(self, at + Vector2(90, -50), tr("+%d💧") % gift, Color("#9CCDE8"), 34)
	FX.floating_text(self, at - Vector2(160, 96), tr("New asks in the garden \u2740"), CREAM, 30)
	_grant_exp(cost * G.EXP_PER_STAR)
	_persist()
	if interior != null:
		_build_interior()                 # the room refreshes; we STAY inside
	_build_vista()                        # the closed chest's stars-left too
	_update_hud()
	if zone_complete(z):
		Save.add_diamonds(G.ZONE_DIAMONDS)
		FX.celebrate_at(self, get_global_rect().get_center(), tr("%s restored!") % tr(G.ZONES[z].name), STRAW)
		FX.floating_text(self, get_global_rect().get_center() + Vector2(-60, 70),
			tr("+%d💎") % G.ZONE_DIAMONDS, Color("#BFE6F2"), 38)
		Audio.play("level_complete", -2.0)

# A swatch chip was tapped: pay (if needed) and dress the item — all on the land.
func _apply_variant(z: int, k: int, vid: String, at: Vector2) -> void:
	var spot_id := String(G.ZONES[z].spots[k].id)
	if String(_spot_variant(z, k).id) == vid:
		_customize_spot = ""
		_build_vista()
		return
	var chosen: Dictionary = {}
	for v in G.spot_variants(z, k):
		if String(v.id) == vid:
			chosen = v
	var paid := true
	if String(chosen.currency) == "coins":
		paid = Save.spend(int(chosen.cost), "decor_variant")
	elif String(chosen.currency) == "diamonds":
		paid = Save.spend_diamonds(int(chosen.cost))
	if not paid:
		Audio.play("invalid_soft", -4.0)
		FX.floating_text(self, at - Vector2(100, 60), tr("Need %d more") % int(chosen.cost), Color(CREAM, 0.9), 28)
		return
	var g := Save.grove()
	if not g.has("custom"):
		g["custom"] = {}
	g["custom"][spot_id] = vid
	Save.grove_write()
	Audio.play("tidy_poof", -2.0, 1.1)
	FX.burst(self, at, Color(chosen.tint), 12)
	_customize_spot = ""
	if interior != null:
		_build_interior()
	else:
		_build_vista()
	_update_hud()


func _grant_exp(amount: int) -> void:
	var before := G.level_for_exp(exp_points)
	exp_points += amount
	Save.grove()["exp"] = exp_points     # S10: the shared Lv chip reads the blob
	var after := G.level_for_exp(exp_points)
	if after > before:
		var g := Save.grove()
		g["water"] = mini(G.WATER_CAP, int(g.get("water", G.WATER_CAP)) + G.LEVEL_WATER_GIFT)
		Save.add_diamonds(G.LEVEL_DIAMONDS)
		FX.celebrate_at(self, Vector2(get_global_rect().get_center().x, 220),
			tr("Level %d!") % after, STRAW)
		FX.floating_text(self, Vector2(get_global_rect().get_center().x - 130, 300),
			tr("+%d💧") % G.LEVEL_WATER_GIFT, Color("#9CCDE8"), 36)
		FX.floating_text(self, Vector2(get_global_rect().get_center().x + 40, 300),
			tr("+%d💎") % G.LEVEL_DIAMONDS, Color("#BFE6F2"), 36)
		Audio.play("level_complete", -1.0)

# --- HUD & chrome -----------------------------------------------------------------------

func _build_hud() -> void:
	# the shared top bar (owner: one module — ★🪙💎 + Store + the S10 Lv chip
	# never move between scenes; the chip ticks via the module's refresh)
	var hud := Hud.build(self, {"water_grant": func() -> void:
		var g := Save.grove()
		g["water"] = G.WATER_CAP
		Save.grove_write()})
	stars_label = hud.stars
	coins_label = hud.coins
	level_label = hud.level
	xp_label = hud.xp
	_hud_refresh = hud.refresh
	_hud_panels = [hud.wallet, hud.lv_panel]

func _update_hud() -> void:
	if _hud_refresh.is_valid():
		_hud_refresh.call()              # wallet + the S10 level chip (ticks)
	else:
		stars_label.text = str(Save.stars())
		coins_label.text = str(Save.coins())

func _build_chrome() -> void:
	# the garden CTA — pinned bottom-center so the way to the board never pans away
	var sb_cta := Look.safe_bottom(self)
	var plot := Look.button(tr("Tend the garden ▶"), _on_board, true)
	plot.custom_minimum_size = Vector2(380, 96)
	plot.anchor_left = 0.5
	plot.anchor_right = 0.5
	plot.anchor_top = 1.0
	plot.anchor_bottom = 1.0
	plot.offset_left = -190
	plot.offset_right = 190
	plot.offset_top = -120 - sb_cta
	plot.offset_bottom = -24 - sb_cta
	add_child(plot)
	FX.breathe_once(plot)
	_chrome_nodes.append(plot)
	# settings gear (bottom-right) — the compact music/sounds/calm card
	var gear := Button.new()
	gear.focus_mode = Control.FOCUS_NONE
	gear.custom_minimum_size = Vector2(76, 76)
	if ResourceLoader.exists(Look.KIT + "btn_round.png"):
		var gt := StyleBoxTexture.new()
		gt.texture = load(Look.KIT + "btn_round.png")
		gt.set_texture_margin_all(24.0)
		gear.add_theme_stylebox_override("normal", gt)
		gear.add_theme_stylebox_override("hover", gt)
		gear.add_theme_stylebox_override("pressed", gt)
		var gi := Look.icon("gear", 36.0)
		gi.set_anchors_preset(Control.PRESET_FULL_RECT)
		if gi is Label:
			(gi as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gear.add_child(gi)
	else:
		gear.text = "⚙"
		gear.add_theme_font_size_override("font_size", 38)
		gear.add_theme_color_override("font_color", CREAM)
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color(INK, 0.6)
		gs.set_corner_radius_all(38)
		gear.add_theme_stylebox_override("normal", gs)
		gear.add_theme_stylebox_override("hover", gs)
		gear.add_theme_stylebox_override("pressed", gs)
	Look.add_press_juice(gear)
	gear.anchor_left = 1.0
	gear.anchor_right = 1.0
	gear.anchor_top = 1.0
	gear.anchor_bottom = 1.0
	var sb := Look.safe_bottom(self)
	gear.offset_left = -92
	gear.offset_right = -16
	gear.offset_top = -92 - sb
	gear.offset_bottom = -16 - sb
	gear.pressed.connect(_open_settings)
	add_child(gear)
	_chrome_nodes.append(gear)
	# the old game, reachable but out of the way during the transition
	var classic := Button.new()
	classic.text = tr("classic ▸")
	classic.flat = true
	classic.focus_mode = Control.FOCUS_NONE
	classic.add_theme_font_size_override("font_size", 20)
	classic.add_theme_color_override("font_color", Color(CREAM, 0.45))
	classic.anchor_top = 1.0
	classic.anchor_bottom = 1.0
	classic.offset_left = 16
	classic.offset_top = -52 - sb
	classic.offset_bottom = -16 - sb
	classic.pressed.connect(func() -> void:
		get_tree().quit_on_go_back = true
		get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	add_child(classic)
	_chrome_nodes.append(classic)

func _open_settings() -> void:
	Audio.play("button_tap", -2.0)
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.6)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	card.add_child(col)
	col.add_child(_lbl(tr("Settings"), 44, INK))
	col.add_child(_toggle("music", tr("Music: On"), tr("Music: Off"), true, func() -> void: Music.refresh()))
	col.add_child(_toggle("sfx", tr("Sounds: On"), tr("Sounds: Off"), true, Callable()))
	col.add_child(_toggle("calm", tr("Calm mode: On"), tr("Calm mode: Off"), false, Callable()))
	col.add_child(Look.button(tr("Close"), func() -> void:
		Audio.play("button_tap", -2.0)
		overlay.queue_free(), true))
	FX.pop_in(card)

func _toggle(key: String, on_t: String, off_t: String, def: bool, extra: Callable) -> Button:
	var b := Look.button(on_t if Save.get_setting(key, def) else off_t, func() -> void: pass, false)
	b.pressed.connect(func() -> void:
		Save.set_setting(key, not Save.get_setting(key, def))
		if extra.is_valid():
			extra.call()
		Audio.play("button_tap", -2.0)
		b.text = on_t if Save.get_setting(key, def) else off_t)
	return b

func _on_board() -> void:
	Audio.play("button_tap", -2.0)
	get_tree().quit_on_go_back = true    # other scenes keep the platform default
	get_tree().change_scene_to_file("res://scenes/Grove.tscn")

func _unhandled_input(event: InputEvent) -> void:
	# Esc walks out of the room — desktop has no OS back gesture
	if interior != null and event.is_action_pressed("ui_cancel"):
		_close_interior()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if interior != null:
			_close_interior()
		elif get_tree() != null:
			get_tree().quit()            # the default we disabled, restored by hand

func _lbl(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", INK if col != INK else CREAM)
	l.add_theme_constant_override("outline_size", 6)
	return l

# ============================================================================
# DEBUG-mode tool: drag-to-place editor (Layout). Gated by Debug.on() — production
# never shows it. Buildings on the map and furniture inside rooms become draggable;
# a crosshair marks each anchor; a bottom toolbar saves to res://data/placements.json.
# The renderers always read through Layout, so saved positions persist for everyone.
# ============================================================================

func _place_on() -> bool:
	return Debug.on()                    # placement editor = a DEBUG-mode tool

func _make_crosshair(at_local: Vector2, color: Color) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arm := 16.0
	var th := 3.0
	var h := ColorRect.new()
	h.color = color
	h.size = Vector2(arm * 2.0, th)
	h.position = at_local - Vector2(arm, th / 2.0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(h)
	var v := ColorRect.new()
	v.color = color
	v.size = Vector2(th, arm * 2.0)
	v.position = at_local - Vector2(th / 2.0, arm)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var dot := Panel.new()
	var ds := StyleBoxFlat.new()
	ds.bg_color = color
	ds.set_corner_radius_all(5)
	dot.add_theme_stylebox_override("panel", ds)
	dot.size = Vector2(10, 10)
	dot.position = at_local - Vector2(5, 5)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(dot)
	return c

func _build_place_ui() -> void:
	if _place_overlay != null and is_instance_valid(_place_overlay):
		return
	var ov := Control.new()
	ov.name = "PlaceOverlay"
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE    # the screen stays draggable
	add_child(ov)
	_place_overlay = ov
	var box := Panel.new()                            # hollow selection outline
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0, 0, 0, 0)
	bs.set_border_width_all(3)
	bs.border_color = Color("#39E0C8")
	bs.set_corner_radius_all(8)
	box.add_theme_stylebox_override("panel", bs)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false
	ov.add_child(box)
	_place_sel_box = box
	var strip := Panel.new()                          # bottom toolbar
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color("#1A0E22", 0.93)
	ss.set_border_width_all(2)
	ss.border_color = Color("#E84AC0")
	strip.add_theme_stylebox_override("panel", ss)
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	var sb := Look.safe_bottom(self)
	strip.offset_top = -104.0 - sb
	strip.mouse_filter = Control.MOUSE_FILTER_STOP    # taps here never reach the map
	ov.add_child(strip)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	row.offset_left = 14.0
	row.offset_right = -14.0
	row.offset_top = 8.0
	row.offset_bottom = -8.0 - sb
	strip.add_child(row)
	var ro := Label.new()
	ro.add_theme_font_size_override("font_size", 21)
	ro.add_theme_color_override("font_color", Color("#39E0C8"))
	ro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ro.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(ro)
	_place_readout = ro
	row.add_child(_dbg_btn("− size", func() -> void: _place_size(-10.0)))
	row.add_child(_dbg_btn("+ size", func() -> void: _place_size(10.0)))
	row.add_child(_dbg_btn("↺ sel", _place_reset_sel))
	row.add_child(_dbg_btn("↺ all", _place_reset_all))
	row.add_child(_dbg_btn("💾 SAVE", _place_save))
	_place_hide_map_chrome()
	_place_update_readout()

# The HUD chips (top corners) and bottom chrome are STOP controls above the map —
# they'd swallow presses on the top-edge zones (meadow under the Lv chip, orchard
# under the wallet). Authoring placement doesn't need them, so hide them in place
# mode. Idempotent; re-called after a room visit (which re-shows the chrome).
func _place_hide_map_chrome() -> void:
	if not _place_on():
		return
	for p in _hud_panels:
		if p != null and is_instance_valid(p):
			(p as Control).visible = false
	for c in _chrome_nodes:
		if is_instance_valid(c):
			(c as Control).visible = false

func _dbg_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(0, 72)
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color("#E84AC0")
	bn.set_corner_radius_all(10)
	bn.content_margin_left = 14.0
	bn.content_margin_right = 14.0
	bn.content_margin_top = 8.0
	bn.content_margin_bottom = 8.0
	b.add_theme_stylebox_override("normal", bn)
	b.add_theme_stylebox_override("hover", bn)
	var bp := bn.duplicate()
	bp.bg_color = Color("#C0349E")
	b.add_theme_stylebox_override("pressed", bp)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(cb)
	return b

func _place_raise() -> void:
	if _place_overlay != null and is_instance_valid(_place_overlay) and _place_overlay.get_parent() == self:
		move_child(_place_overlay, get_child_count() - 1)

func _place_clear_sel() -> void:
	_place_sel = {}
	_place_drag = {}
	if _place_sel_box != null and is_instance_valid(_place_sel_box):
		_place_sel_box.visible = false

func _place_select(d: Dictionary) -> void:
	_place_sel = d
	_place_update_readout()
	_place_update_sel_box()

# After an interior rebuild the spot nodes are fresh — re-bind the selected one.
func _place_resync_sel() -> void:
	if String(_place_sel.get("kind", "")) != "spot":
		_place_update_sel_box()
		return
	if _interior_zone != int(_place_sel.get("z", -1)):
		_place_clear_sel()
		return
	var k := int(_place_sel.get("k", -1))
	for hit in spot_hits:
		if int(hit.z) == _interior_zone and int(hit.k) == k:
			_place_sel.node = hit.node
			_place_update_readout()
			_place_update_sel_box()
			return
	_place_clear_sel()

func _place_update_readout() -> void:
	if _place_readout == null or not is_instance_valid(_place_readout):
		return
	var kind := String(_place_sel.get("kind", ""))
	if kind == "zone":
		var z := int(_place_sel.z)
		var mp := Layout.zone_map_pos(z)
		_place_readout.text = "🏠 %s   map_pos (%.4f, %.4f)%s   — drag onto its clearing · tap to enter" % [
			String(G.ZONES[z].name), mp.x, mp.y, "  •edited" if Layout.zone_overridden(z) else ""]
	elif kind == "spot":
		var z := int(_place_sel.z)
		var k := int(_place_sel.k)
		var sp := Layout.spot_pos(z, k)
		var fs := Layout.spot_fsize(z, k)
		_place_readout.text = "🪑 %s   pos (%.3f, %.3f) · size %d%s" % [
			String(G.ZONES[z].spots[k].name), sp.x, sp.y, int(fs), "  •edited" if Layout.spot_overridden(z, k) else ""]
	else:
		_place_readout.text = "DEBUG · PLACE — drag a building to its clearing · tap to enter a room · 💾 SAVE → data/placements.json"

func _place_update_sel_box() -> void:
	if _place_sel_box == null or not is_instance_valid(_place_sel_box):
		return
	var n: Variant = _place_sel.get("node", null)
	if n == null or not is_instance_valid(n):
		_place_sel_box.visible = false
		return
	var r: Rect2 = (n as Control).get_global_rect()
	var g := 6.0
	_place_sel_box.visible = true
	_place_sel_box.global_position = r.position - Vector2(g, g)
	_place_sel_box.size = r.size + Vector2(g, g) * 2.0

# Map place input: drag a building to reposition (live map_pos); a still tap
# still enters the room. Returns true when it consumed the event (else the pan
# handler runs — so empty terrain still pans).
func _place_map_input(event: InputEvent) -> bool:
	var is_press: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	var is_release: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed)
	var is_motion: bool = event is InputEventMouseMotion or event is InputEventScreenDrag
	if is_press:
		for z in zone_nodes.size():
			var n: Control = zone_nodes[z]
			if n.get_global_rect().has_point(event.position):
				_place_drag = {"kind": "zone", "z": z, "node": n, "grab": event.position - n.global_position, "press": event.position, "moved": 0.0}
				_place_select({"kind": "zone", "z": z, "node": n})
				return true
		return false
	if is_motion and String(_place_drag.get("kind", "")) == "zone":
		var n: Control = _place_drag.node
		var press_pt: Vector2 = _place_drag.press
		_place_drag.moved = maxf(float(_place_drag.moved), (event.position - press_pt).length())
		if float(_place_drag.moved) > TAP_SLOP:
			var grab: Vector2 = _place_drag.grab
			n.global_position = event.position - grab
			var anchor := n.global_position + Vector2(G.POI_SIZE / 2.0, G.POI_SIZE / 2.0)
			Layout.set_zone_map_pos(int(_place_drag.z), (anchor - vista.global_position) / G.MAP_SIZE)
			_place_update_readout()
			_place_update_sel_box()
		return true
	if is_release and String(_place_drag.get("kind", "")) == "zone":
		var z := int(_place_drag.z)
		var moved := float(_place_drag.moved)
		_place_drag = {}
		if moved <= TAP_SLOP:
			_open_interior(z)             # debug: a tap enters ANY zone, locked or not
		else:
			_place_update_readout()
		return true
	return false

# Interior place input: drag furniture/pins to reposition. A press that misses
# every spot returns false so the normal handler still does back/CTA/close.
func _place_interior_input(event: InputEvent) -> bool:
	var is_press: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	var is_release: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed)
	var is_motion: bool = event is InputEventMouseMotion or event is InputEventScreenDrag
	if is_press:
		for hit in spot_hits:
			var n: Control = hit.node
			if n.get_global_rect().grow(8.0).has_point(event.position):
				_place_drag = {"kind": "spot", "z": int(hit.z), "k": int(hit.k), "node": n, "grab": event.position - n.global_position, "press": event.position, "moved": 0.0}
				_place_select({"kind": "spot", "z": int(hit.z), "k": int(hit.k), "node": n})
				return true
		return false                      # navigation taps fall through
	if is_motion and String(_place_drag.get("kind", "")) == "spot":
		var n: Control = _place_drag.node
		var press_pt: Vector2 = _place_drag.press
		_place_drag.moved = maxf(float(_place_drag.moved), (event.position - press_pt).length())
		if float(_place_drag.moved) > TAP_SLOP:
			var grab: Vector2 = _place_drag.grab
			n.global_position = event.position - grab
			var anchor := n.global_position + Vector2(90.0, 40.0)
			if _int_art_rect.size.x > 0.0 and _int_art_rect.size.y > 0.0:
				Layout.set_spot_pos(int(_place_drag.z), int(_place_drag.k), (anchor - _int_art_rect.position) / _int_art_rect.size)
			_place_update_readout()
			_place_update_sel_box()
		return true
	if is_release and String(_place_drag.get("kind", "")) == "spot":
		_place_drag = {}
		_place_update_readout()
		return true
	return false

func _place_save() -> void:
	var p := Layout.save()
	if p == "":
		_place_flash("⚠ SAVE FAILED — could not write placements.json")
		push_warning("[place] save failed")
	else:
		_place_flash("✔ saved → %s" % p)
		print("[place] saved → ", ProjectSettings.globalize_path(p))

func _place_reset_sel() -> void:
	var kind := String(_place_sel.get("kind", ""))
	if kind == "zone":
		Layout.reset_zone(int(_place_sel.z))
		_rebuild_after_reset()
	elif kind == "spot":
		Layout.reset_spot(int(_place_sel.z), int(_place_sel.k))
		_rebuild_after_reset()
	else:
		_place_flash("select something to reset")

func _place_reset_all() -> void:
	Layout.reset_all()
	_rebuild_after_reset()
	_place_flash("↺ all placements reset to defaults (not yet saved)")

func _rebuild_after_reset() -> void:
	_place_clear_sel()
	if interior != null:
		_build_interior()
	else:
		_build_vista()
	_place_raise()

func _place_size(delta: float) -> void:
	if String(_place_sel.get("kind", "")) != "spot":
		_place_flash("select a furniture item first, then − / + resize it")
		return
	var z := int(_place_sel.z)
	var k := int(_place_sel.k)
	Layout.set_spot_fsize(z, k, Layout.spot_fsize(z, k) + delta)
	if interior != null:
		_build_interior()                 # re-renders at the new size (resyncs sel)
	_place_update_readout()

func _place_flash(msg: String) -> void:
	if _place_readout != null and is_instance_valid(_place_readout):
		_place_readout.text = msg
