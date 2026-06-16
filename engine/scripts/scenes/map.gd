extends Control
## HOME: the game's hub IS the homestead (Core §8 / grove_spec §3). A map IS one
## self-contained image — an open space (the Farmhouse, the Barn, …) with the
## restoration SPOTS sitting directly on that image. Level-gated spots sit greyed
## ("Lv N"), available ones price themselves ("✿ N★" — tap to buy with stars), and
## OWNED ones open their own customization list (variants priced in coins/diamonds).
## Discrete maps are reached via a map-SELECT screen; the first map (the hub) is the
## home. Buying grants EXP; level-ups gift water+diamonds. A pinned garden button
## leads to the board. Art auto-wires: assets/map/map_<id>.png + assets/rooms/furn_<id>.png.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Music = preload("res://engine/scripts/core/music.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Spotlight = preload("res://engine/scripts/core/spotlight.gd")          # T28: the §14 first-appearance gate
const SpotlightOverlay = preload("res://engine/scripts/ui/spotlight_overlay.gd")  # T28: the veil+pulse+hand guide
const Layout = preload("res://engine/scripts/core/layout.gd")
const Debug = preload("res://engine/scripts/ui/debug.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

const TAP_SLOP := 14.0       # drag farther than this and the release is a drag, not a tap
const SPOT_NAME_DY := 50.0   # spot name/price stack baseline below the plot point

# §8 ghost-preview: an UNOWNED spot may show a faint cut-out of the buildable that
# will fill it (behind the price-pin + name, which stay legible). Gated by Features
# "spot_ghost". The treatment is a low-alpha desaturating MULTIPLY — the same grey
# wash the map-select uses to grey incomplete maps (a true desaturate needs a shader;
# a neutral multiply reads as "not real yet" and costs no material). GHOST_ALPHA is
# the opacity; GHOST_TINT is the grey it multiplies by (the lower the channels, the
# more it cools/dims). Owned/built spots draw the REAL sprite — never a ghost.
const GHOST_ALPHA := 0.34
const GHOST_TINT := Color(0.72, 0.74, 0.72)

# T2: the board's Decorate sets this (a MAP id) before changing scene; _ready
# consumes it and opens that map BEFORE the first draw — no map-select flash.
# Process-scoped on purpose: a fresh app boot always lands on the frontier.
static var decorate_zone := ""

const SKY = Pal.SKY
const MEADOW = Pal.MEADOW
const LEAF = Pal.LEAF
const INK = Pal.INK
const CREAM = Pal.CREAM
const STRAW = Pal.STRAW
const BARK = Pal.BARK
const CLAY = Pal.CLAY

# --- map-select veil (§8 "the horizon — visible AND veiled") ----------------
# A LOCKED map card sits behind FOG: not greyed-but-legible, but teased — a soft
# fog scrim over its thumbnail that thickens toward the bottom (fog settling in)
# with a faint ✿ ghost, so the next map reads "there's MORE, not yet revealed."
# UNLOCKED/available cards get NO veil. The look is code-drawn today; the seam
# `map/veil[_<id>].png` lets grove art drop in a painted veil sprite later with
# zero code change (see `_veil_thumb`). All dials are named + tunable here.
const VEIL_NODE := "Veil"                       # the overlay's name (tests assert it by this)
const VEIL_TINT := INK                          # fog colour (deep ink — the unknown)
const VEIL_SCRIM_ALPHA := 0.42                  # flat fog haze over the whole thumb
const VEIL_DEEP_ALPHA := 0.66                   # extra fog pooled at the bottom edge
const VEIL_MARK_ALPHA := 0.16                   # the teasing ✿ ghost in the mist
const VEIL_MARK_SIZE := 64                      # ✿ glyph size, px
const VEIL_ART := "map/veil.png"                # generic painted-veil seam (per-map: veil_<id>.png)

var unlocks := {}

# THE one input surface. Rebuilding a view clears + repopulates it; every visual
# descendant is MOUSE_FILTER_IGNORE (the single-input-surface rule; a test asserts it).
var content: Control
var _view := "map"               # "map" | "select"
var _map_idx := 0                # the map being viewed
var _map_rect := Rect2()         # the CONTAIN-fit map image (spot pos maps to THIS rect)
var spot_hits: Array = []        # [{node, z, k}] — the open map's spots
var select_hits: Array = []      # [{node, z}] — the map-select cards
var variant_hits: Array = []     # [{node, z, k, vid}] — the inline strip's swatch chips
var _customize_spot := ""        # spot id whose inline variant strip is open
var _press := Vector2.ZERO       # last press point (still-tap resolution)

var _chrome_nodes: Array = []    # bottom chrome (garden CTA, gear, shop, atlas)
var _shop_btn: Button            # T28: kept so the §14 shop spotlight can target it
var level_label: Label
var xp_label: Label
var stars_label: Label
var coins_label: Label
var _hud_refresh := Callable()
var _open_shop := Callable()      # opens the shared Shop (lives in the bottom chrome)
var _hud_panels: Array = []       # wallet + Lv chips — hidden in place mode (they'd eat presses)

# --- dev placement editor (Layout) ---
var _place_overlay: Control = null    # toolbar + readout, kept topmost
var _place_readout: Label = null
var _place_sel_box: Panel = null      # hollow rect over the selected spot
var _place_drag: Dictionary = {}      # {kind:"spot", z, k, node, grab}
var _place_sel: Dictionary = {}       # last-touched {kind, z, k, node} for size/reset

func _ready() -> void:
	_heal_capture_flags()
	UiFont.apply()
	Music.ensure()
	if get_tree() != null:               # headless harnesses run _ready() out of tree
		get_tree().quit_on_go_back = false   # we step back to the map-select on OS back instead
	_load_state()

	var sky := ColorRect.new()
	sky.color = SKY
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)

	# the single view host — full-rect, the ONE input surface; views repopulate it
	content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_STOP
	content.gui_input.connect(_on_input)
	add_child(content)

	# the day's weather drifts over the whole scene (calm mode wins inside)
	var g0 := Save.grove()
	Ambient.check_winback(g0, Time.get_unix_time_from_system())
	add_child(Ambient.build_weather(get_viewport_rect().size, Ambient.weather_now(FX.calm())))

	_build_hud()
	_build_chrome()
	_update_hud()
	if _place_on():
		_build_place_ui()

	# Choose the initial view (still inside _ready = before the first draw):
	# T2 the board's Decorate jumps straight to a known, unlocked map; otherwise
	# open the frontier (falling back to the hub when nothing is open yet).
	var start := -1
	if decorate_zone != "":
		var dz := G.zone_for_id(decorate_zone)
		if dz >= 0 and zone_unlocked(dz):
			start = dz
	decorate_zone = ""
	if start < 0:
		start = _frontier_zone()
		if start < 0:
			start = G.hub_zone()
	_open_map(start)

	# T28 (§14): if the player lands on the map first, announce the shop on its first
	# appearance (a tap guide). Shared seen-state with the board, so whichever scene shows
	# it first wins and it never double-announces. Deferred so the button has a real rect.
	if Spotlight.should_spotlight("shop"):
		_spotlight_shop_deferred.call_deferred()

	Debug.mount(self)                    # base/testing debug panel (no-op in prod)

# The dev capture harness births its windows minimized + focusless via a
# transient override.cfg (engine/tools/quiet_godot.sh). If a REAL launch ever inherits
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

func _load_state() -> void:
	var g := Save.grove()
	unlocks = g.get("unlocks", {})
	# T1: sanitize — a last_zone that no longer names a map is dropped
	if g.has("last_zone") and G.zone_for_id(String(g.last_zone)) < 0:
		g.erase("last_zone")
	if not g.has("unlocks"):
		g["unlocks"] = unlocks

func _persist() -> void:
	var g := Save.grove()
	g["unlocks"] = unlocks
	g["last_seen"] = Time.get_unix_time_from_system()   # the win-back reads this
	Save.grove_write()

# --- progression queries ------------------------------------------------------------

func _gates() -> Array:                       # §7 gate-delivery state (which maps' gate quests are done)
	return Save.grove().get("gates", [])

func spot_owned(id: String) -> bool:
	return unlocks.has(id)

func zone_complete(z: int) -> bool:
	return G.zone_done(z, unlocks)

func zone_unlocked(z: int) -> bool:
	return G.zone_unlocked(z, unlocks, _gates())

func owned_count(z: int) -> int:
	return G.owned_count(z, unlocks)

func zone_stars_left(z: int) -> int:
	return G.zone_stars_left(z, unlocks)

func _frontier_zone() -> int:
	return G.frontier_zone(unlocks, _gates())

func _is_cheapest_open(z: int, k: int, lvl: int) -> bool:
	return G.is_cheapest_open(z, k, lvl, unlocks)

func _spot_variant(z: int, k: int) -> Dictionary:
	var chosen := String(Save.grove().get("custom", {}).get(String(G.ZONES[z].spots[k].id), "base"))
	for v in G.spot_variants(z, k):
		if String(v.id) == chosen:
			return v
	return G.spot_variants(z, k)[0]

# --- navigation: a map IS one image; discrete maps via the map-select -------------------

func _open_map(z: int) -> void:
	_view = "map"
	_map_idx = z
	_customize_spot = ""
	# T1: remember WHICH map you were on — the board's Decorate jumps back here
	var g := Save.grove()
	g["last_zone"] = String(G.ZONES[z].id)
	Save.grove_write()
	_build_map()

func _open_select() -> void:
	_view = "select"
	_customize_spot = ""
	Audio.play("button_tap", -4.0)
	_build_select()

# --- THE MAP VIEW (grove_spec §3) -------------------------------------------------------
# One self-contained image fills the area below the HUD; the spots sit directly on
# it at spot.pos (a fraction of the fitted image rect). Owned spots draw furniture
# sprites; the customize strip rides directly beneath an owned spot when open. The
# whole view lives under `content` — every child IGNOREs (single input surface).

func _build_map() -> void:
	for c in content.get_children():
		c.queue_free()
	spot_hits.clear()
	select_hits.clear()
	variant_hits.clear()
	var z := _map_idx
	# the map image fills the viewport below the HUD top inset and above the chrome
	_map_rect = _map_image_rect()
	var art_path := Game.art("map/map_%s.png" % String(G.ZONES[z].id))
	if ResourceLoader.exists(art_path):
		var t := TextureRect.new()
		t.texture = load(art_path)
		t.position = _map_rect.position
		t.size = _map_rect.size
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.clip_contents = true
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(t)
	else:
		var fallback := Panel.new()
		fallback.position = _map_rect.position
		fallback.size = _map_rect.size
		var fs := StyleBoxFlat.new()
		fs.bg_color = MEADOW
		fs.set_corner_radius_all(28)
		fs.set_border_width_all(5)
		fs.border_color = MEADOW.lerp(LEAF, 0.4)
		fallback.add_theme_stylebox_override("panel", fs)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(fallback)
	# ambient life wanders over the map (order L), positioned within the image rect
	var amb := Ambient.build_layer(_map_rect.size, G.character_count(unlocks))
	amb.position = _map_rect.position
	amb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(amb)
	# the title plank — map name + ✿-progress — near the top of the map rect
	content.add_child(_map_title_plank(z))
	var lvl := G.level_for_stars(int(Save.grove().get("stars_earned", 0)))
	for k in G.ZONES[z].spots.size():
		var spot := _make_spot(z, k, lvl, _map_rect)
		content.add_child(spot)
		spot_hits.append({"node": spot, "z": z, "k": k})
	if _place_on():
		_place_resync_sel()
		_place_raise()
	FX.pop_in(content)

# The available area below the HUD and above the bottom chrome; the map image is
# CONTAIN-fit, centered, to the viewport aspect (full-bleed-ish portrait).
func _map_image_rect() -> Rect2:
	var view := get_viewport_rect().size
	var top := 96.0 + Look.safe_top(self)
	var avail := Rect2(Vector2(0, top), Vector2(view.x, view.y - top - 24.0 - Look.safe_bottom(self)))
	# fit to the available rect's own aspect (the image is full-bleed-ish) — keep the
	# whole rect so spots have the maximum stable canvas. Center within the viewport.
	var rw: float = avail.size.x
	var rh: float = avail.size.y
	return Rect2(avail.position + (avail.size - Vector2(rw, rh)) / 2.0, Vector2(rw, rh))

# The map's title — NAME + ✿-progress on one plank, centered near the top of the
# map image (an IGNORE visual; never eats a press).
func _map_title_plank(z: int) -> Control:
	var plank := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3D2A1B", 0.84)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = Color("#2A1C11", 0.9)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 7.0
	plank.add_theme_stylebox_override("panel", sb)
	plank.position = _map_rect.position + Vector2(_map_rect.size.x / 2.0, 16.0)
	plank.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plank.add_child(col)
	var name_l := Label.new()
	name_l.text = tr(G.ZONES[z].name)
	name_l.add_theme_font_size_override("font_size", 30)
	name_l.add_theme_color_override("font_color", CREAM)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_l)
	var lbl := Label.new()
	lbl.text = tr("✿ restored") if zone_complete(z) else tr("✿ %d★ left") % zone_stars_left(z)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", STRAW)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(lbl)
	return plank

# §8: the optional ghost-preview of an UNOWNED spot's buildable. Reuses the SAME
# buildable-sprite lookup the Layout editor draws from (the caller's `furn_path` =
# Game.art("rooms/furn_<id>.png")), so there is ONE asset-path source. Returns null
# when the flag is off or this spot has no art — the caller then draws only the pin.
# A faint, desaturated cut-out: low alpha + colour leaned toward neutral grey, sized
# and centered exactly like the real sprite so the build "settles into" its outline.
func _ghost_sprite(furn_path: String, fs: float) -> TextureRect:
	if not Features.on("spot_ghost"):
		return null
	if furn_path == "" or not ResourceLoader.exists(furn_path):
		return null
	var g := TextureRect.new()
	# Same ORDER-MATTERS dance as the real sprite (expand_mode before size).
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	g.texture = load(furn_path)
	g.size = Vector2(fs, fs)
	g.position = Vector2(90.0 - fs / 2.0, 60.0 - fs / 2.0)   # centered on the plot, like the real one
	g.modulate = Color(GHOST_TINT.r, GHOST_TINT.g, GHOST_TINT.b, GHOST_ALPHA)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.set_meta("ghost", true)
	return g

# One spot ON the map image: furniture art when owned (and generated), else the
# 3-state pin + name. The customize strip rides directly beneath when open.
func _make_spot(z: int, k: int, lvl: int, rect: Rect2) -> Control:
	var spot: Dictionary = G.ZONES[z].spots[k]
	var pos: Vector2 = rect.position + Layout.spot_pos(z, k) * rect.size
	var item := Control.new()
	item.size = Vector2(180, 150)
	item.position = pos - Vector2(90, 40)
	item.pivot_offset = Vector2(90, 50)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var owned := spot_owned(String(spot.id))
	var gated := G.spot_level_req(z, k) > lvl
	var furn_path := Game.art("rooms/furn_%s.png" % String(spot.id))
	# debug place mode shows the real sprite for EVERY spot that has art (even
	# unowned/locked) so the owner drags the actual item, not just its price pin
	if (owned or _place_on()) and ResourceLoader.exists(furn_path):
		var f := TextureRect.new()
		# ORDER MATTERS: expand_mode must precede size — with the default
		# EXPAND_KEEP_SIZE the texture's 512px min CLAMPS size up and a later
		# expand_mode never shrinks it back (every sprite rendered 512px; the
		# Q3 probe caught it). Footprint is per-spot data (fsize, px on the image).
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
		# §8: a faint ghost of the buildable sits BEHIND the pin (added first), so an
		# empty plot teases what will fill it. Owned spots took the branches above —
		# only unowned (gated or buyable) spots reach here, so the ghost is correct.
		var ghost := _ghost_sprite(furn_path, Layout.spot_fsize(z, k))
		if ghost != null:
			item.add_child(ghost)
		# S7: ONE anchor rule — price chip + name stack CENTERED UNDER the plot
		# point, ≥28px chip text, never covering the plot the furniture will fill
		var stack := VBoxContainer.new()
		stack.anchor_left = 0.0
		stack.anchor_right = 1.0
		stack.offset_top = SPOT_NAME_DY
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
		var kit_icons := ResourceLoader.exists(Look.kit("icon_star.png"))
		if gated:
			ps.bg_color = Color("#4A4F46", 0.72)
			if kit_icons and ResourceLoader.exists(Look.kit("icon_lock.png")):
				prow.add_child(Look.icon("lock", 24.0))
				ptxt.text = str(G.spot_level_req(z, k))
			else:
				ptxt.text = tr("Lv %d") % G.spot_level_req(z, k)
			ptxt.add_theme_color_override("font_color", Color(CREAM, 0.55))
		else:
			ps.bg_color = Color(INK, 0.85)
			ps.set_border_width_all(2)
			ps.border_color = STRAW
			# §13: the star price is ALWAYS a Look.icon sprite + a number-only label
			# (Look.icon ships the ★ glyph as its own fallback) — no emoji baked in.
			prow.add_child(Look.icon("star", 26.0))
			ptxt.text = str(int(spot.cost))
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

# The inline customize strip (chips are IGNORE visuals resolved by content's
# input surface via variant_hits).
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
		# §13: currency variants show a Look.icon SPRITE (coin/gem) + a number-only
		# label — never an emoji baked into the price text. The owned variant shows a
		# check sprite; the free "Classic" stays plain text.
		var price := Label.new()
		if String(v.id) == current:
			row.add_child(Look.icon("check", 20.0))
		elif String(v.currency) == "coins":
			row.add_child(Look.icon("coin", 20.0))
			price.text = "%d" % int(v.cost)
		elif String(v.currency) == "diamonds":
			row.add_child(Look.icon("gem", 20.0))
			price.text = "%d" % int(v.cost)
		else:
			price.text = tr("Classic")
		price.add_theme_font_size_override("font_size", 19)
		price.add_theme_color_override("font_color", CREAM)
		price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(price)
		chip.position = Vector2(2.0 + i * 60.0, 110.0)
		item.add_child(chip)
		variant_hits.append({"node": chip, "z": z, "k": k, "vid": String(v.id)})

# --- THE MAP-SELECT VIEW (grove_spec §3) ------------------------------------------------
# A clean atlas of every map as a card: thumbnail + name + state line. Tapping an
# unlocked card opens that map; a locked card wobbles. Lives under `content` —
# every child IGNOREs (single input surface).

func _build_select() -> void:
	for c in content.get_children():
		c.queue_free()
	spot_hits.clear()
	select_hits.clear()
	variant_hits.clear()
	var view := get_viewport_rect().size
	var top := 96.0 + Look.safe_top(self)
	# the header — the grove's name, an invitation to choose
	var header := _lbl(tr("Choose a place ✿"), 40, CREAM)
	header.position = Vector2(0, top + 8.0)
	header.size = Vector2(view.x, 56.0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(header)
	# a 2-column grid of cards, centered, scrolling room left below the header
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col_w: float = (view.x - 18.0 * 3.0) / 2.0
	var card_w: float = clampf(col_w, 200.0, 320.0)
	for z in G.ZONES.size():
		var card := _make_card(z, card_w)
		grid.add_child(card)
		select_hits.append({"node": card, "z": z})
	# center the grid under the header
	var grid_top := top + 80.0
	grid.position = Vector2((view.x - (card_w * 2.0 + 18.0)) / 2.0, grid_top)
	grid.custom_minimum_size = Vector2(card_w * 2.0 + 18.0, 0)
	content.add_child(grid)
	FX.pop_in(content)

# One map card: thumbnail + name + state line. Three states drive the line and the
# greying — locked ("✿ after <prev>"), unlocked-incomplete ("✿ N★ left"), restored.
func _make_card(z: int, card_w: float) -> Control:
	var zone: Dictionary = G.ZONES[z]
	var open := zone_unlocked(z)
	var done := zone_complete(z)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(card_w, 0)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color("#3D2A1B", 0.9) if open else Color("#2A2620", 0.85)
	cs.set_corner_radius_all(20)
	cs.set_border_width_all(3)
	cs.border_color = STRAW if (open and not done) else (Color("#E8C84A") if done else Color(CREAM, 0.25))
	cs.shadow_color = Color(0, 0, 0, 0.28)
	cs.shadow_size = 6
	cs.shadow_offset = Vector2(0, 4)
	cs.content_margin_left = 12.0
	cs.content_margin_right = 12.0
	cs.content_margin_top = 12.0
	cs.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", cs)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	# thumbnail — the map image (or a meadow-toned fallback). Captured so a LOCKED
	# card can wear its fog veil over exactly the thumb rect (text stays clear below).
	var thumb_h := card_w * 0.62
	var thumb_w := card_w - 24.0
	var thumb: Control
	var thumb_path := Game.art("map/map_%s.png" % String(zone.id))
	if ResourceLoader.exists(thumb_path):
		var t := TextureRect.new()
		t.texture = load(thumb_path)
		t.custom_minimum_size = Vector2(thumb_w, thumb_h)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.clip_contents = true
		if not open:
			t.modulate = Color(0.72, 0.74, 0.72, 0.85)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(t)
		thumb = t
	else:
		var ph := Panel.new()
		ph.custom_minimum_size = Vector2(thumb_w, thumb_h)
		ph.clip_contents = true
		var ps := StyleBoxFlat.new()
		ps.bg_color = MEADOW if open else MEADOW.lerp(INK, 0.45)
		ps.set_corner_radius_all(14)
		ph.add_theme_stylebox_override("panel", ps)
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(ph)
		thumb = ph
	# LOCKED → veil it (the §8 horizon: visible AND not-yet-revealed). One place.
	if not open:
		_veil_thumb(thumb, String(zone.id))
	var name_l := Label.new()
	name_l.text = tr(zone.name)
	name_l.add_theme_font_size_override("font_size", 26)
	name_l.add_theme_color_override("font_color", CREAM if open else Color(CREAM, 0.6))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_l)
	var stxt: String
	var scol: Color
	if done:
		stxt = tr("✿ restored"); scol = STRAW
	elif open:
		stxt = tr("✿ %d★ left") % zone_stars_left(z); scol = CREAM
	else:
		stxt = tr("✿ after %s") % tr(G.ZONES[z - 1].name); scol = Color(CREAM, 0.6)
	var state_l := Label.new()
	state_l.text = stxt
	state_l.add_theme_font_size_override("font_size", 21)
	state_l.add_theme_color_override("font_color", scol)
	state_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	state_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(state_l)
	if open and not done and z == _frontier_zone():
		FX.breathe_once(card)
	return card

# The fog veil for a LOCKED map card (§8). ONE place that dresses a thumbnail as
# "behind fog, not yet revealed" — a translucent ink scrim + a soft gradient that
# pools fog at the bottom edge + a faint ✿ ghost in the mist. It overlays exactly
# the thumb rect (full-rect child of `thumb`), so the "✿ after …" line below stays
# crisp. ART SEAM: if `map/veil_<id>.png` (per-map) or `map/veil.png` (generic)
# exists, that painted sprite REPLACES the code-drawn fog — grove art drops in with
# no code change. Every node IGNOREs the mouse (single-input-surface rule). The
# overlay node is named VEIL_NODE so a headless test can assert its presence/look.
# The veil anchors full-rect to `thumb`, so it tracks the thumbnail's size for free.
func _veil_thumb(thumb: Control, zone_id: String) -> void:
	thumb.clip_contents = true
	var veil := Control.new()
	veil.name = VEIL_NODE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.add_child(veil)
	# ART SEAM — a painted veil sprite, if grove (or any game) supplies one.
	var art := Game.art("map/veil_%s.png" % zone_id)
	if not ResourceLoader.exists(art):
		art = Game.art(VEIL_ART)
	if ResourceLoader.exists(art):
		var sprite := TextureRect.new()
		sprite.texture = load(art)
		sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.add_child(sprite)
		return
	# CODE-DRAWN fog (today's default — no art asset needed).
	# 1. a flat haze over the whole thumb.
	var haze := ColorRect.new()
	haze.color = Color(VEIL_TINT, VEIL_SCRIM_ALPHA)
	haze.set_anchors_preset(Control.PRESET_FULL_RECT)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(haze)
	# 2. fog settling — a top→bottom gradient that deepens to VEIL_DEEP_ALPHA at the
	#    base, so the thumb dissolves into mist rather than reading as flat grey.
	var grad := Gradient.new()
	grad.set_color(0, Color(VEIL_TINT, 0.0))
	grad.set_color(1, Color(VEIL_TINT, VEIL_DEEP_ALPHA - VEIL_SCRIM_ALPHA))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	gtex.width = 4
	gtex.height = 64
	var settle := TextureRect.new()
	settle.texture = gtex
	settle.set_anchors_preset(Control.PRESET_FULL_RECT)
	settle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	settle.stretch_mode = TextureRect.STRETCH_SCALE
	settle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(settle)
	# 3. the teasing ✿ ghost — a faint mark in the mist (there IS something here).
	var ghost := Label.new()
	ghost.name = "VeilMark"
	ghost.text = "✿"
	ghost.add_theme_font_size_override("font_size", VEIL_MARK_SIZE)
	ghost.add_theme_color_override("font_color", Color(CREAM, VEIL_MARK_ALPHA))
	ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(ghost)

# --- input: ONE surface, still-tap resolution ------------------------------------------

func _on_input(event: InputEvent) -> void:
	if _place_on() and _place_input(event):
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) \
		or event is InputEventScreenTouch
	if pressed and event.pressed:
		_press = event.position
	elif pressed and not event.pressed and event.position.distance_to(_press) <= 18.0:
		var gpos: Vector2 = event.position
		if _view == "select":
			_select_tap(gpos)
		else:
			_map_tap(gpos)

func _select_tap(gpos: Vector2) -> void:
	for hit in select_hits:
		var n: Control = hit.node
		if not n.get_global_rect().grow(6.0).has_point(gpos):
			continue
		var z := int(hit.z)
		if zone_unlocked(z):
			_open_map(z)
		else:
			Audio.play("invalid_soft", -4.0)
			FX.wobble(n)
			FX.floating_text(self, gpos - Vector2(150, 70),
				tr("Restore %s first ✿") % tr(G.ZONES[maxi(z - 1, 0)].name), Color(CREAM, 0.9), 28)
		return

func _map_tap(gpos: Vector2) -> void:
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
		_build_map()
		return
	# a wandering spirit? a tap earns a hop (pure charm, v1)
	var amb: Control = content.get_node_or_null("AmbientLayer")
	if amb != null:
		for sp in amb.get_children():
			if (sp as Control).get_global_rect().grow(10.0).has_point(gpos):
				if Features.on("spirit_tap_hop"):
					Ambient.hop(sp)
					Audio.play("button_tap", -8.0)
				return

# --- buying & customizing, right on the map image ---------------------------------------

func _on_spot_tap(z: int, k: int, node: Control, at: Vector2) -> void:
	var spot: Dictionary = G.ZONES[z].spots[k]
	if spot_owned(String(spot.id)):
		if not Features.on("customize_variants"):
			return
		Audio.play("button_tap", -2.0)
		_customize_spot = "" if _customize_spot == String(spot.id) else String(spot.id)
		_build_map()
		return
	var lvl := G.level_for_stars(int(Save.grove().get("stars_earned", 0)))
	if G.spot_level_req(z, k) > lvl:
		Audio.play("invalid_soft", -4.0)
		FX.wobble(node)
		FX.floating_text(self, at - Vector2(120, 64), tr("Reach Lv %d ❀") % G.spot_level_req(z, k), Color(CREAM, 0.9), 30)
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
	# the garden's givers re-meter to the next unlock after a purchase (§7 — water comes from
	# level-ups, not a per-spot gift)
	FX.floating_text(self, at - Vector2(160, 96), tr("New asks in the garden ❀"), CREAM, 30)
	_persist()
	_build_map()                          # the map (spot art + stars-left) refreshes
	_update_hud()
	if zone_complete(z):
		Save.add_diamonds(G.ZONE_DIAMONDS)
		FX.celebrate_at(self, get_global_rect().get_center(), tr("%s restored!") % tr(G.ZONES[z].name), STRAW)
		FX.floating_reward(self, get_global_rect().get_center() + Vector2(-60, 70),
			"gem", G.ZONE_DIAMONDS, Color("#BFE6F2"), 38)
		Audio.play("level_complete", -2.0)
		# §8: this restore completed the map's spots, so its great-spirit GATE quest is now
		# the lone fence stand WAITING ON THE BOARD — a silent cross-screen handoff. Arm the
		# wordless pointer; the board consumes it on its next open and pulses the gate stand.
		# Only when the gate is genuinely still pending (not already delivered for this zone).
		if not _gates().has(z):
			Save.set_gate_pointer(z)

# A swatch chip was tapped: pay (if needed) and dress the item — all on the map.
func _apply_variant(z: int, k: int, vid: String, at: Vector2) -> void:
	var spot_id := String(G.ZONES[z].spots[k].id)
	if String(_spot_variant(z, k).id) == vid:
		_customize_spot = ""
		_build_map()
		return
	var chosen: Dictionary = G.variant_by_id(z, k, vid)
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
	_build_map()
	_update_hud()

# --- HUD & chrome -----------------------------------------------------------------------

func _build_hud() -> void:
	# the shared top bar (owner: one module — ★🪙💎 + Store + the S10 Lv chip
	# never move between scenes; the chip ticks via the module's refresh). `home`
	# is a shortcut to the hub map — the shared HUD renders its button in a
	# separate change; passing it now is harmless.
	var hud := Hud.build(self, {
		"water_grant": func() -> void:
			var g := Save.grove()
			g["water"] = G.WATER_CAP
			Save.grove_write(),
		"home": func() -> void: _open_map(G.hub_zone())})
	stars_label = hud.stars
	coins_label = hud.coins
	level_label = hud.level
	xp_label = hud.xp
	_hud_refresh = hud.refresh
	_open_shop = hud.open_shop
	_hud_panels = [hud.wallet, hud.lv_panel]

func _update_hud() -> void:
	if _hud_refresh.is_valid():
		_hud_refresh.call()              # wallet + the S10 level chip (ticks)
	else:
		stars_label.text = str(Save.stars())
		coins_label.text = str(Save.coins())

func _build_chrome() -> void:
	# the garden CTA — pinned bottom-center so the way to the board never moves
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
	if ResourceLoader.exists(Look.kit("btn_round.png")):
		var gt := StyleBoxTexture.new()
		gt.texture = load(Look.kit("btn_round.png"))
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
	# the Store, relocated from the top cluster — sits to the LEFT of the gear
	var shop := Button.new()
	_shop_btn = shop                 # T28: target for the §14 shop spotlight
	shop.focus_mode = Control.FOCUS_NONE
	shop.custom_minimum_size = Vector2(76, 76)
	if ResourceLoader.exists(Look.kit("btn_round.png")):
		var st := StyleBoxTexture.new()
		st.texture = load(Look.kit("btn_round.png"))
		st.set_texture_margin_all(24.0)
		shop.add_theme_stylebox_override("normal", st)
		shop.add_theme_stylebox_override("hover", st)
		shop.add_theme_stylebox_override("pressed", st)
		var si := Look.icon("cart", 36.0)
		si.set_anchors_preset(Control.PRESET_FULL_RECT)
		shop.add_child(si)
	else:
		shop.text = "🛒"
		shop.add_theme_font_size_override("font_size", 34)
		shop.add_theme_color_override("font_color", CREAM)
	Look.add_press_juice(shop)
	shop.anchor_left = 1.0
	shop.anchor_right = 1.0
	shop.anchor_top = 1.0
	shop.anchor_bottom = 1.0
	shop.offset_left = -180
	shop.offset_right = -104
	shop.offset_top = -92 - sb
	shop.offset_bottom = -16 - sb
	shop.pressed.connect(func() -> void:
		Audio.play("button_tap", -2.0)
		if _open_shop.is_valid():
			_open_shop.call())
	add_child(shop)
	_chrome_nodes.append(shop)
	# the map-select (atlas) button — sits to the LEFT of the shop; opens the
	# place-picker. Visible in map view (the place-picker is its own view). The
	# kit has no map icon, so the glyph (🗺) rides the round-button art directly
	# (using Look.icon("map") would render "?" — no such kit/glyph entry).
	var atlas := Button.new()
	atlas.focus_mode = Control.FOCUS_NONE
	atlas.custom_minimum_size = Vector2(76, 76)
	if ResourceLoader.exists(Look.kit("btn_round.png")):
		var at := StyleBoxTexture.new()
		at.texture = load(Look.kit("btn_round.png"))
		at.set_texture_margin_all(24.0)
		atlas.add_theme_stylebox_override("normal", at)
		atlas.add_theme_stylebox_override("hover", at)
		atlas.add_theme_stylebox_override("pressed", at)
		var ai := Label.new()
		ai.text = "🗺"
		ai.add_theme_font_size_override("font_size", 34)
		ai.add_theme_color_override("font_color", CREAM)
		ai.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ai.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ai.set_anchors_preset(Control.PRESET_FULL_RECT)
		ai.mouse_filter = Control.MOUSE_FILTER_IGNORE
		atlas.add_child(ai)
	else:
		atlas.text = "🗺"
		atlas.add_theme_font_size_override("font_size", 34)
		atlas.add_theme_color_override("font_color", CREAM)
		var as_sb := StyleBoxFlat.new()
		as_sb.bg_color = Color(INK, 0.6)
		as_sb.set_corner_radius_all(38)
		atlas.add_theme_stylebox_override("normal", as_sb)
		atlas.add_theme_stylebox_override("hover", as_sb)
		atlas.add_theme_stylebox_override("pressed", as_sb)
	Look.add_press_juice(atlas)
	atlas.anchor_left = 1.0
	atlas.anchor_right = 1.0
	atlas.anchor_top = 1.0
	atlas.anchor_bottom = 1.0
	atlas.offset_left = -268
	atlas.offset_right = -192
	atlas.offset_top = -92 - sb
	atlas.offset_bottom = -16 - sb
	atlas.pressed.connect(_open_select)
	add_child(atlas)
	_chrome_nodes.append(atlas)

# T28 (§14): present the shop spotlight over the chrome's shop button on first appearance,
# then mark it spotlit. The gesture/caption come from the game's registry; the overlay
# honours the §11 flag itself.
func _spotlight_shop_deferred() -> void:
	await get_tree().process_frame              # let the shop button get a real global rect
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if _shop_btn == null or not is_instance_valid(_shop_btn) or not Spotlight.should_spotlight("shop"):
		return
	Spotlight.mark_spotlit("shop")
	SpotlightOverlay.present(self, _shop_btn, Spotlight.gesture_for("shop"), tr(Spotlight.label_for("shop")))

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
	# inner padding so the content clears the parchment's deckled edge (was flush)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 36)
	pad.add_theme_constant_override("margin_right", 36)
	pad.add_theme_constant_override("margin_top", 30)
	pad.add_theme_constant_override("margin_bottom", 30)
	card.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	pad.add_child(col)
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
	get_tree().change_scene_to_file("res://engine/scenes/Board.tscn")

func _unhandled_input(event: InputEvent) -> void:
	# Esc steps back: a map → the place-picker; the picker → quit (desktop has no
	# OS back gesture). Mirrors _notification(WM_GO_BACK_REQUEST).
	if event.is_action_pressed("ui_cancel"):
		if _view == "map":
			_open_select()
			get_viewport().set_input_as_handled()
		elif _view == "select" and get_tree() != null:
			get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _view == "map":
			_open_select()               # step back to the place-picker
		elif get_tree() != null:
			get_tree().quit()            # from the picker, the default we disabled (by hand)

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
# DEBUG-mode tool: drag-to-place editor (Layout). Gated by Debug.authoring() — an
# explicit owner tool, NOT auto-on in base. Spots on the open map image become
# draggable; a crosshair marks each anchor; a bottom toolbar saves to
# res://data/placements.json. The renderer always reads through Layout, so saved
# positions persist for everyone.
# ============================================================================

func _place_on() -> bool:
	return Debug.authoring()             # the Layout editor is owner-authoring, not base

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
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE    # the screen stays tappable
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
# they'd swallow presses on spots near the screen edges. Authoring placement
# doesn't need them, so hide them in place mode. Idempotent.
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

# After a map rebuild the spot nodes are fresh — re-bind the selected one.
func _place_resync_sel() -> void:
	if String(_place_sel.get("kind", "")) != "spot":
		_place_update_sel_box()
		return
	if _map_idx != int(_place_sel.get("z", -1)):
		_place_clear_sel()
		return
	var k := int(_place_sel.get("k", -1))
	for hit in spot_hits:
		if int(hit.z) == _map_idx and int(hit.k) == k:
			_place_sel.node = hit.node
			_place_update_readout()
			_place_update_sel_box()
			return
	_place_clear_sel()

func _place_update_readout() -> void:
	if _place_readout == null or not is_instance_valid(_place_readout):
		return
	var kind := String(_place_sel.get("kind", ""))
	if kind == "spot":
		var z := int(_place_sel.z)
		var k := int(_place_sel.k)
		var sp := Layout.spot_pos(z, k)
		var fs := Layout.spot_fsize(z, k)
		_place_readout.text = "🪑 %s   pos (%.3f, %.3f) · size %d%s" % [
			String(G.ZONES[z].spots[k].name), sp.x, sp.y, int(fs), "  •edited" if Layout.spot_overridden(z, k) else ""]
	else:
		_place_readout.text = "DEBUG · PLACE — drag a spot on the map · − / + resize · 💾 SAVE → data/placements.json"

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

# Map place input: drag a SPOT to reposition (live spot_pos on the map image). A
# press that misses every spot returns false so the normal handler still resolves
# taps (variant chips, buy, spirits). Returns true when it consumed the event.
func _place_input(event: InputEvent) -> bool:
	# only the map view has draggable spots; the place-picker is plain navigation
	if _view != "map":
		return false
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
			if _map_rect.size.x > 0.0 and _map_rect.size.y > 0.0:
				Layout.set_spot_pos(int(_place_drag.z), int(_place_drag.k), (anchor - _map_rect.position) / _map_rect.size)
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
	if kind == "spot":
		Layout.reset_spot(int(_place_sel.z), int(_place_sel.k))
		_rebuild_after_reset()
	else:
		_place_flash("select a spot to reset")

func _place_reset_all() -> void:
	Layout.reset_all()
	_rebuild_after_reset()
	_place_flash("↺ all placements reset to defaults (not yet saved)")

func _rebuild_after_reset() -> void:
	_place_clear_sel()
	_build_map()
	_place_raise()

func _place_size(delta: float) -> void:
	if String(_place_sel.get("kind", "")) != "spot":
		_place_flash("select a spot first, then − / + resize it")
		return
	var z := int(_place_sel.z)
	var k := int(_place_sel.k)
	Layout.set_spot_fsize(z, k, Layout.spot_fsize(z, k) + delta)
	_build_map()                          # re-renders at the new size (resyncs sel)
	_place_update_readout()

func _place_flash(msg: String) -> void:
	if _place_readout != null and is_instance_valid(_place_readout):
		_place_readout.text = msg
