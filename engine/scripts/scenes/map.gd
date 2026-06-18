extends Control
## HOME: the game's hub IS the homestead (Core §8 / grove_spec §3). A map IS one
## self-contained image — an open space (the Farmhouse, the Barn, …) with the
## restoration SPOTS sitting directly on that image. Level-gated spots sit greyed
## ("Lv N"), available ones price themselves ("✿ N★" — tap to buy with stars), and
## OWNED ones open their own customization list (variants priced in coins/diamonds).
## Discrete maps are reached via a map-SELECT screen; the first map (the hub) is the
## home. Buying advances your level; level-ups gift water+diamonds. A pinned garden button
## leads to the board. Art auto-wires: assets/map/map_<id>.png + assets/rooms/furn_<id>.png.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Music = preload("res://engine/scripts/core/music.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const NavBar = preload("res://engine/scripts/ui/nav_bar.gd")   # the shared bottom nav row (board + map)
const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Spotlight = preload("res://engine/scripts/core/spotlight.gd")          # T28: the §14 first-appearance gate
const Vault = preload("res://engine/scripts/core/vault.gd")                  # T44 SKIM-SITE — the piggy bank skims earned premium here
const VaultUI = preload("res://engine/scripts/ui/vault.gd")                  # T45: the diegetic piggy-bank jar (chrome entry point)
const Ads = preload("res://engine/scripts/core/ads.gd")                      # rewarded ads — the free-gem rail (T43); the 2× coin doubler moved to board.gd (quest reward)
const Login = preload("res://engine/scripts/core/login.gd")                  # T45: the forgiving daily-login calendar (auto-popup gate)
const LoginUI = preload("res://engine/scripts/ui/login.gd")                  # T45: the diegetic login-calendar popup surface
const Shop = preload("res://engine/scripts/ui/shop.gd")                      # chrome: the Store-badge query (starter_available)
const SpotlightOverlay = preload("res://engine/scripts/ui/spotlight_overlay.gd")  # T28: the veil+pulse+hand guide
const SettingsUI = preload("res://engine/scripts/ui/settings.gd")            # the shared Settings card (gear + board bottom bar)
const Debug = preload("res://engine/scripts/ui/debug.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Design = preload("res://engine/scripts/core/design.gd")
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
static var decorate_map := ""

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
var _map_rect := Rect2()         # the stable map canvas (spot pos maps to THIS rect)
var _map_art_rect := Rect2()     # the placed/scaled background art
var spot_hits: Array = []        # [{node, z, k}] — the open map's spots
var select_hits: Array = []      # [{node, z}] — the map-select cards
var variant_hits: Array = []     # [{node, z, k, vid}] — the inline strip's swatch chips
var resident_hits: Array = []    # [{node, z, type}] — the "welcome a spirit" panel's kind rows (residents §1)
var _customize_spot := ""        # spot id whose inline variant strip is open
var _press := Vector2.ZERO       # last press point (still-tap resolution)

var _chrome_nodes: Array = []    # bottom chrome (garden CTA, gear, shop, atlas)
var _weather: Control = null     # ambient weather layer — belongs to a MAP; hidden on the place-picker
var _backdrop: Control = null    # the place-picker's sky backdrop (gradient + clouds); hidden on a MAP
var _shop_btn: Button            # T28: kept so the §14 shop spotlight can target it
var level_label: Label
var level_prog_label: Label
var stars_label: Label
var coins_label: Label
var _hud_refresh := Callable()
var _piggy_pip: Control = null    # T45: the vault chrome button's "claimable" ready glow (shown when Vault.claimable())
var _open_shop := Callable()      # opens the shared Shop (lives in the bottom chrome)
var _hud_panels: Array = []       # wallet + Lv chips
# chrome badges (driven by actionable-state queries; visibility only — never a nag)
var _store_badge: Control = null  # Store "new offer" badge — lit while the starter pack is unclaimed
var _daily_badge: Control = null  # Daily rail badge — lit when today's login reward is unclaimed
var _free_badge: Control = null   # Free rail badge — lit when the rewarded gem faucet is offerable
var _inbox_badge: Control = null  # Inbox rail badge — unread count (only built when the inbox system exists)
var _task_strip: Control = null   # the above-CTA task strip (rebuilt when frontier progress changes)
var _task_strip_sb := 0.0         # cached safe-bottom so a rebuild keeps the strip's pin
# Inbox is a PARALLEL system (core/inbox.gd + ui/inbox.gd) NOT in this worktree's base — GUARD it so
# this compiles + tests without it, and the button lights up once that system merges (load() is runtime).
var _has_inbox := ResourceLoader.exists("res://engine/scripts/ui/inbox.gd") and ResourceLoader.exists("res://engine/scripts/core/inbox.gd")

func _ready() -> void:
	_heal_capture_flags()
	Design.fit_desktop_window()          # desktop: open at the design portrait aspect, monitor height
	UiFont.apply()
	Music.ensure()
	if get_tree() != null:               # headless harnesses run _ready() out of tree
		get_tree().quit_on_go_back = false   # we step back to the map-select on OS back instead
	_load_state()

	var sky := ColorRect.new()
	sky.color = SKY
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)

	# the place-picker's richer sky (gradient + drifting-free clouds) sits BEHIND content; shown
	# only on the chooser (a map has its own painted backdrop). Built hidden; the nav toggles it.
	_backdrop = _build_backdrop()
	_backdrop.visible = false
	add_child(_backdrop)

	# the single view host — full-rect, the ONE input surface; views repopulate it
	content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_STOP
	content.gui_input.connect(_on_input)
	add_child(content)

	# the day's weather drifts over the MAP (calm mode wins inside); kept as a member so the
	# place-picker can hide it — drifting leaves over a static chooser read as stray sprites.
	var g0 := Save.grove()
	Ambient.check_winback(g0, Time.get_unix_time_from_system())
	_weather = Ambient.build_weather(get_viewport_rect().size, Ambient.weather_now(FX.calm()))
	add_child(_weather)

	_build_hud()
	_build_chrome()
	_update_hud()

	# Choose the initial view (still inside _ready = before the first draw):
	# T2 the board's Decorate jumps straight to a known, unlocked map; otherwise
	# open the frontier (falling back to the hub when nothing is open yet).
	var start := -1
	if decorate_map != "":
		var dz := G.map_for_id(decorate_map)
		if dz >= 0 and map_unlocked(dz):
			start = dz
	decorate_map = ""
	if start < 0:
		start = _frontier_map()
		if start < 0:
			start = G.hub_map()
	_open_map(start)

	# T28 (§14): if the player lands on the map first, announce the shop on its first
	# appearance (a tap guide). Shared seen-state with the board, so whichever scene shows
	# it first wins and it never double-announces. Deferred so the button has a real rect.
	if Spotlight.should_spotlight("shop"):
		_spotlight_shop_deferred.call_deferred()

	# T45 (§18): on the day's FIRST hub open, auto-show the login calendar ONCE. The hub map is the
	# surface the player reliably hits first (fresh boot lands on the frontier — the hub when nothing
	# is open yet — and the board's Home button returns here). Gated + deferred so it never collides
	# with the FTUE shop spotlight or fires on a cold first launch (see _maybe_login_popup).
	_maybe_login_popup_deferred.call_deferred()

	Debug.mount(self)                    # debug/authoring panel (no-op in prod)

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
	# T1: sanitize — a last_map that no longer names a map is dropped
	if g.has("last_map") and G.map_for_id(String(g.last_map)) < 0:
		g.erase("last_map")
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

# The fixed `fence` overlay shows only once its reveal-spot (a spot with reveal:"fence") is restored;
# maps with no such spot always show their fence. Keeps the fence from reading as already-restored.
func _fence_revealed(z: int) -> bool:
	for sp in G.MAPS[z].spots:
		if String(sp.get("reveal", "")) == "fence":
			return spot_owned(String(sp.id))
	return true

func map_spots_done(z: int) -> bool:
	return G.map_spots_done(z, unlocks)

func map_unlocked(z: int) -> bool:
	return G.map_unlocked(z, unlocks, _gates())

func owned_count(z: int) -> int:
	return G.owned_count(z, unlocks)

func map_stars_left(z: int) -> int:
	return G.map_stars_left(z, unlocks)

func _frontier_map() -> int:
	return G.frontier_map(unlocks, _gates())

func _is_cheapest_open(z: int, k: int, lvl: int) -> bool:
	return G.is_cheapest_open(z, k, lvl, unlocks)

func _spot_variant(z: int, k: int) -> Dictionary:
	var chosen := String(Save.grove().get("custom", {}).get(String(G.MAPS[z].spots[k].id), "base"))
	for v in G.spot_variants(z, k):
		if String(v.id) == chosen:
			return v
	return G.spot_variants(z, k)[0]

# --- navigation: a map IS one image; discrete maps via the map-select -------------------

func _open_map(z: int) -> void:
	_view = "map"
	_map_idx = z
	_customize_spot = ""
	_set_map_chrome_visible(true)         # a map wears its bottom chrome + drifting weather
	# T1: remember WHICH map you were on — the board's Decorate jumps back here
	var g := Save.grove()
	g["last_map"] = String(G.MAPS[z].id)
	Save.grove_write()
	_build_map()
	_refresh_chrome_badges()             # Store / Daily / Free / Inbox badges re-read their actionable state on nav

func _open_select() -> void:
	_view = "select"
	_customize_spot = ""
	_set_map_chrome_visible(false)        # the place-picker is a calm chooser — no map chrome, no weather
	Audio.play("button_tap", -4.0)
	_build_select()

# The bottom chrome (garden CTA / gear / shop / atlas / piggy) and ambient weather belong to a
# MAP, not the place-picker. One toggle keeps the chooser clean and restores the lived-in map on
# return. The piggy pip rides its button's own visible flag, so it stays correct under this.
func _set_map_chrome_visible(on: bool) -> void:
	for n in _chrome_nodes:
		if is_instance_valid(n):
			(n as CanvasItem).visible = on
	if _weather != null and is_instance_valid(_weather):
		_weather.visible = on
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.visible = not on        # the sky backdrop is the chooser's, not the map's

# The place-picker's backdrop: a soft daytime sky (a vertical gradient — deeper up top, warm
# toward the horizon) with a few painted clouds peeking in. Replaces the flat-blue fill so the
# chooser reads as "your grove's sky" without weather motion. The cloud art is a grove seam
# (ui/cloud.png) — absent, it degrades to the gradient alone. Every node IGNOREs the mouse.
func _build_backdrop() -> Control:
	var layer := Control.new()
	layer.name = "SelectBackdrop"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.clip_contents = true
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the sky gradient
	var grad := Gradient.new()
	grad.set_color(0, SKY.darkened(0.12))          # top — a touch deeper
	grad.set_color(1, SKY.lerp(CREAM, 0.34))       # horizon — warm, hazy, bright
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	gtex.width = 8
	gtex.height = 128
	var sky_rect := TextureRect.new()
	sky_rect.texture = gtex
	sky_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky_rect.stretch_mode = TextureRect.STRETCH_SCALE
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sky_rect)
	# painted clouds — a few soft, static drifts high in the sky (grove art seam)
	var cloud_path := Game.art("ui/cloud.png")
	if ResourceLoader.exists(cloud_path):
		var view := get_viewport_rect().size
		var tex := load(cloud_path)
		var spots := [Vector2(0.18, 0.015), Vector2(0.70, 0.0), Vector2(0.46, 0.075), Vector2(0.52, 0.90), Vector2(0.90, 0.55)]
		var sizes := [0.50, 0.60, 0.34, 0.42, 0.40]
		var alphas := [0.92, 0.88, 0.75, 0.82, 0.70]
		for i in spots.size():
			var c := TextureRect.new()
			c.texture = tex
			c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			var cw := view.x * float(sizes[i])
			c.size = Vector2(cw, cw)
			c.position = Vector2(spots[i].x * view.x - cw * 0.5, spots[i].y * view.y)
			c.modulate = Color(1.0, 1.0, 1.0, alphas[i])
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(c)
	return layer

# (The 2× rewarded-ad DOUBLER lived here, triggered by the now-removed hub yield-collect. It was
# RE-HOMED to the quest coin reward on the board — see board.gd `_maybe_offer_2x` — since the map
# scene no longer has a coin faucet to double. The `collect_2x` ad id is unchanged.)

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
	resident_hits.clear()
	var z := _map_idx
	# the stable map canvas is a centered, design-aspect rect (see _map_image_rect) that the HUD
	# floats over. Background art fills it; spots ride this same rect, so the painting and the
	# buildings stay locked together on any window aspect.
	_map_rect = _map_image_rect()
	_map_art_rect = _map_placed_rect(z, _map_rect)
	var home = G.MAPS[z].get("home", null)   # §16 mask-reveal home (the hub) — overrides cutout rendering
	if typeof(home) == TYPE_DICTIONARY:
		_build_home(z, home)                 # overgrown base + per-building reveal/badge (→ spot_hits)
	else:
		# background: a map may name its own `bg` (e.g. map1v2 base_empty); else the convention path.
		var art_path := String(G.MAPS[z].get("bg", Game.art("map/map_%s.png" % String(G.MAPS[z].id))))
		if ResourceLoader.exists(art_path):
			# A clipped frame AT the map rect; layers fill it via full-rect anchors (cover-fit). The base
			# fills it; an optional fixed `fence` layer composites on top at its baked position/size.
			var frame := Control.new()
			frame.position = _map_art_rect.position
			frame.size = _map_art_rect.size
			frame.clip_contents = true
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(frame)
			_add_cover_layer(frame, art_path)
			var fence_path := String(G.MAPS[z].get("fence", ""))
			if fence_path != "" and ResourceLoader.exists(fence_path) and _fence_revealed(z):
				_add_cover_layer(frame, fence_path)
		else:
			var fallback := Panel.new()
			fallback.position = _map_art_rect.position
			fallback.size = _map_art_rect.size
			var fs := StyleBoxFlat.new()
			fs.bg_color = MEADOW
			fs.set_corner_radius_all(28)
			fs.set_border_width_all(5)
			fs.border_color = MEADOW.lerp(LEAF, 0.4)
			fallback.add_theme_stylebox_override("panel", fs)
			fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(fallback)
	# ambient life + title — both render paths. On a COMPLETED map the wanderers ARE its residents
	# (the §1 population sub-game); an in-progress map keeps the baseline generic ambient.
	var amb: Control
	if G.can_populate(z, unlocks, _gates()):
		amb = Ambient.build_population_layer(_map_rect.size, G.resident_members(z))
	else:
		amb = Ambient.build_layer(_map_rect.size, G.character_count(unlocks))
	amb.position = _map_rect.position
	amb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(amb)
	content.add_child(_map_title_plank(z))
	if typeof(home) != TYPE_DICTIONARY:
		var lvl := G.level_for_stars(int(Save.grove().get("stars_earned", 0)))
		for k in G.MAPS[z].spots.size():
			var spot := _make_spot(z, k, lvl, _map_rect)
			content.add_child(spot)
			spot_hits.append({"node": spot, "z": z, "k": k})
	# §1 residents: a COMPLETED map invites the player to WELCOME spirits (the population sub-game)
	if G.can_populate(z, unlocks, _gates()):
		_add_welcome_panel(z)
	FX.pop_in(content)

# --- §16 mask-reveal home (the hub) ------------------------------------------------------

const _HOME_MASK_SHADER := "shader_type canvas_item;
uniform sampler2D mask;
void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= texture(mask, UV).a;
}"
var _home_mask: Shader

# The hub home screen: an overgrown base (farm_brokenv2). Each RESTORED building reveals the clean farm
# through its baked mask; each UNRESTORED building shows a ✿cost badge that taps into the normal buy flow.
func _build_home(z: int, home: Dictionary) -> void:
	var frame := Control.new()
	frame.position = _map_art_rect.position
	frame.size = _map_art_rect.size
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(frame)
	_add_fill_layer(frame, String(home.get("broken", "")))          # overgrown base
	var data = _read_json_file(String(home.get("data", "")))
	var by_id := {}
	if typeof(data) == TYPE_DICTIONARY:
		for b in data.get("buildings", []):
			by_id[String(b.get("spot", ""))] = b
	# ONE spot_hit per spot, index-aligned with G.MAPS[z].spots — the buy flow + tests rely on this:
	# owned → reveal the clean farm through its mask + an invisible tap marker; unowned → the ✿cost badge.
	for k in G.MAPS[z].spots.size():
		var sid := String(G.MAPS[z].spots[k].id)
		var b = by_id.get(sid, null)
		var hit: Control
		if spot_owned(sid):
			var mtex: Texture2D = load(Game.art("farm/" + String(b.get("mask", "")))) if b != null else null
			if mtex != null:
				# clean farm, masked to THIS building. Guard the mask load: a null mask (e.g. a checkout
				# that hasn't re-imported the assets) must NOT fall back to a full-opaque reveal — that
				# would clean the WHOLE farm off one restore. No mask → skip the reveal (stays overgrown).
				var rev := _add_fill_layer(frame, String(home.get("clean", "")))
				var mat := ShaderMaterial.new()
				mat.shader = _home_mask_shader()
				mat.set_shader_parameter("mask", mtex)
				rev.material = mat
				var vcur := _spot_variant(z, k)            # a chosen variant tints the revealed building
				if String(vcur.id) != "base":
					rev.modulate = Color.WHITE.lerp(Color(vcur.tint), 0.28)
			hit = _home_owned_item(z, k, b)               # carries the inline customize strip
			if _customize_spot == sid:
				_add_variant_strip(hit, z, k)
		else:
			hit = _home_badge(z, k, b)
		content.add_child(hit)
		spot_hits.append({"node": hit, "z": z, "k": k})

func _home_mask_shader() -> Shader:
	if _home_mask == null:
		_home_mask = Shader.new(); _home_mask.code = _HOME_MASK_SHADER
	return _home_mask

func _add_fill_layer(frame: Control, path: String) -> TextureRect:
	var t := TextureRect.new()
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE       # SCALE → UV [0,1] = full texture, so masks align
	t.texture = load(path)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(t)
	return t

# An unlock-cost restore badge (item 3 — the farm_ui mockup's round dashed cream disc), centered on
# the building. Two variants picked from the spot's GATE state (the same signal _make_spot uses —
# spot_level_req(z,k) vs the player's level): a still-GATED spot shows badge_locked.png (lock + sprout,
# no price — you can't buy it yet); an unlockable/buyable spot shows badge_cost.png with a "+" stacked
# over the star cost "★ N". Decoration only (mouse-ignored); the spot's tap hit-area is the spot_hit node.
func _home_badge(z: int, k: int, b) -> Control:
	var spot: Dictionary = G.MAPS[z].spots[k]
	var p = b.get("pos", [0.5, 0.5]) if b != null else [0.5, 0.5]
	var ctr := _map_rect.position + Vector2(float(p[0]), float(p[1])) * _map_rect.size
	var d := _map_rect.size.x * 0.16                  # badge diameter relative to the map
	# the gate signal: a spot whose level requirement exceeds the player's level is still LOCKED
	# (the lock disc, no price); otherwise it prices itself (the cost disc).
	var lvl := G.level_for_stars(int(Save.grove().get("stars_earned", 0)))
	var gated := G.spot_level_req(z, k) > lvl
	var node := Control.new()
	node.size = Vector2(d, d)
	node.position = ctr - Vector2(d, d) * 0.5
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the disc — the sliced round badge (cost vs locked). Falls back to the legacy farm/badge.png disc.
	var disc_kit := Look.kit("badge_locked.png" if gated else "badge_cost.png")
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.texture = load(disc_kit) if ResourceLoader.exists(disc_kit) else load(Game.art("farm/badge.png"))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(bg)
	# a still-gated spot shows ONLY the locked disc (the lock + sprout art carries the meaning — no price).
	if gated:
		return node
	# the buyable disc stacks a "+" over the star cost "★ N", centered on the disc.
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(col)
	var plus := Label.new()
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", int(d * 0.30))
	plus.add_theme_color_override("font_color", Color("#6E4E25"))
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(plus)
	# the star cost — a gold star sprite (Look.icon) + the number, on the second line (matches the wallet).
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var ic := Look.icon("star", d * 0.26)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var lbl := Label.new()
	lbl.text = "%d" % int(spot.cost)
	lbl.add_theme_font_size_override("font_size", int(d * 0.26))
	lbl.add_theme_color_override("font_color", Color("#6E4E25"))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	return node

# An owned building's affordance node at its position — a spot_hit (keeps the list index-aligned with
# the spots) that also carries the upgrade pill + the inline customize strip, exactly like _make_spot.
func _home_owned_item(z: int, k: int, b) -> Control:
	var p = b.get("pos", [0.5, 0.5]) if b != null else [0.5, 0.5]
	var pos := _map_rect.position + Vector2(float(p[0]), float(p[1])) * _map_rect.size
	var item := Control.new()
	item.size = Vector2(180, 150)                    # match _make_spot's box so the pill/strip place the same
	item.position = pos - Vector2(90, 40)
	item.pivot_offset = Vector2(90, 50)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

func _spot_index(z: int, id: String) -> int:
	for k in G.MAPS[z].spots.size():
		if String(G.MAPS[z].spots[k].id) == id:
			return k
	return -1

func _read_json_file(path: String):
	if path == "" or not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

# The available area below the HUD and above the bottom chrome; the map image is
# CONTAIN-fit, centered, to the viewport aspect (full-bleed-ish portrait).
func _map_image_rect() -> Rect2:
	# The map canvas is a phone-aspect rect, CONTAIN-fit and CENTERED in the viewport, so the
	# WHOLE map image is always visible — never zoomed/cropped — on ANY window aspect (a wide
	# desktop window no longer blows the cover-fit up). On the design phone aspect this fills the
	# viewport exactly, so it stays identical to the map placer. Spots map to THIS rect; the sky
	# ColorRect shows through any gap on an off-aspect (desktop) window. The HUD floats on top.
	var view := get_viewport_rect().size
	var aspect := Design.aspect()          # design portrait aspect (the art is authored to it)
	var w := view.x
	var h := w / aspect
	if h > view.y:
		h = view.y
		w = h * aspect
	return Rect2(((view - Vector2(w, h)) * 0.5).floor(), Vector2(w, h).floor())

func _map_placed_rect(_z: int, base: Rect2) -> Rect2:
	return base

# Add a full-rect, cover-fit, click-through TextureRect under `parent` (a map-rect frame). Used for the
# base background and for fixed overlay layers (fence) so they share the exact same fit.
func _add_cover_layer(parent: Control, path: String) -> void:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.texture = load(path)
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)

# Item 5 — the map's progress PILL (the farm_ui mockup), centered near the top of the map image
# (an IGNORE visual; never eats a press). The cream pill (pill_progress.png — green groove + flower +
# sprout baked in) carries "N to the next place" text in its upper body (NO inline icon — the pill art's
# baked flower is the single left mark) and a GREEN fill bar (pill_progress_fill.png) inside its lower
# groove, sized to restore-progress. The map NAME is
# dropped entirely. A fully-restored map shows the "restored" state. If the pill art is missing it
# degrades to the old dark plank look so the read never blanks.
const _PILL_ASPECT := 603.0 / 109.0
# the green groove rect inside pill_progress.png, as fractions of the pill size (measured from the art).
const _PILL_GROOVE_X := 0.085
const _PILL_GROOVE_W := 0.78
const _PILL_GROOVE_Y := 0.66
const _PILL_GROOVE_H := 0.22

func _map_title_plank(z: int) -> Control:
	var pill_path := Look.kit("pill_progress.png")
	if not ResourceLoader.exists(pill_path):
		return _map_title_plank_fallback(z)
	# size the pill relative to the map width (clamped), keeping the source aspect.
	var pw := clampf(_map_rect.size.x * 0.74, 360.0, 560.0)
	var ph := pw / _PILL_ASPECT
	var node := Control.new()
	node.size = Vector2(pw, ph)
	node.position = _map_rect.position + Vector2((_map_rect.size.x - pw) / 2.0, 16.0 + 96.0 + Look.safe_top(self))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the pill background art
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture = load(pill_path)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(bg)
	# the GREEN fill bar inside the groove, clipped to the progress fraction (paid / total star cost).
	var total := 0
	for s in G.MAPS[z].spots:
		total += int(s.cost)
	var left := map_stars_left(z)
	var frac := 1.0 if total <= 0 else clampf(float(total - left) / float(total), 0.0, 1.0)
	if map_spots_done(z):
		frac = 1.0
	var fill_path := Look.kit("pill_progress_fill.png")
	if ResourceLoader.exists(fill_path) and frac > 0.0:
		var groove_x := _PILL_GROOVE_X * pw
		var groove_w := _PILL_GROOVE_W * pw
		var groove_y := _PILL_GROOVE_Y * ph
		var groove_h := _PILL_GROOVE_H * ph
		# a clip frame at the FULL groove width; the bar inside spans the full groove and the frame
		# crops it to `frac`, so the green bar grows left→right without squashing its rounded caps.
		var clip := Control.new()
		clip.position = Vector2(groove_x, groove_y)
		clip.size = Vector2(groove_w * frac, groove_h)
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(clip)
		var fill := TextureRect.new()
		fill.position = Vector2.ZERO
		fill.size = Vector2(groove_w, groove_h)
		fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fill.stretch_mode = TextureRect.STRETCH_SCALE
		fill.texture = load(fill_path)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(fill)
	# the text — just "N to the next place" (or "restored ✿"), in the pill's UPPER body. pill_progress.png
	# already bakes a flower into its top-left, so we DON'T add an icon here — that flower IS the single
	# left mark (mockup: one flower + text). The label fills the area to the RIGHT of the baked flower and
	# centers itself in that remaining span, so the text never overlaps the flower.
	var lbl := Label.new()
	lbl.text = tr("restored ✿") if map_spots_done(z) else tr("%d to the next place") % left
	lbl.add_theme_font_size_override("font_size", int(ph * 0.30 if map_spots_done(z) else ph * 0.28))
	lbl.add_theme_color_override("font_color", Color("#6E4E25"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position = Vector2(groove_text_left(pw), ph * 0.10)
	lbl.size = Vector2(pw - groove_text_left(pw) - _PILL_GROOVE_X * pw, ph * 0.42)
	node.add_child(lbl)
	return node

# Where the pill's text starts — inset past the baked flower badge on the far left.
func groove_text_left(pw: float) -> float:
	return _PILL_GROOVE_X * pw + pw * 0.06

# The legacy dark-plank read, kept ONLY as a graceful fallback when the pill art is missing (so the
# progress read never blanks). The map NAME is dropped here too (item 5).
func _map_title_plank_fallback(z: int) -> Control:
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
	plank.position = _map_rect.position + Vector2(_map_rect.size.x / 2.0, 16.0 + 96.0 + Look.safe_top(self))
	plank.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if map_spots_done(z):
		var lbl := Label.new()
		lbl.text = tr("✿ restored")
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", STRAW)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plank.add_child(lbl)
	else:
		plank.add_child(_stars_left_row(map_stars_left(z), STRAW, 22))   # gold star sprite + count
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
	var spot: Dictionary = G.MAPS[z].spots[k]
	# pos + fsize come from grove_data.MAPS, which merges the placer's data/map1_placements.json once at
	# load (see grove_data._merge_map1_placements). `art` (a res:// cutout) overrides the default furn art.
	var pos: Vector2 = rect.position + Vector2(spot.pos) * rect.size
	var art_scale := rect.size.x / Design.size().x   # footprints are authored at the design-width canvas
	var fs_eff := float(spot.get("fsize", 240.0)) * art_scale
	var furn_path := String(spot.get("art", Game.art("rooms/furn_%s.png" % String(spot.id))))
	var item := Control.new()
	item.size = Vector2(180, 150)
	item.position = pos - Vector2(90, 40)
	item.pivot_offset = Vector2(90, 50)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var owned := spot_owned(String(spot.id))
	var gated := G.spot_level_req(z, k) > lvl
	# an owned spot draws its furniture sprite (when the art exists)
	if owned and ResourceLoader.exists(furn_path):
		var f := TextureRect.new()
		# ORDER MATTERS: expand_mode must precede size — with the default
		# EXPAND_KEEP_SIZE the texture's 512px min CLAMPS size up and a later
		# expand_mode never shrinks it back (every sprite rendered 512px; the
		# Q3 probe caught it). Footprint is per-spot data (fsize, px on the image).
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		f.texture = load(furn_path)
		var fs: float = fs_eff
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
	elif owned and String(spot.get("reveal", "")) != "":
		pass   # an overlay-reward spot (e.g. the garden fence): the reward is the revealed `fence`
		       # layer, so the restored spot draws no point sprite (no stray solid-colour chip).
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
		var ghost := _ghost_sprite(furn_path, fs_eff)
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
		if not gated and z == _frontier_map() and _is_cheapest_open(z, k, lvl):
			FX.breathe_once(item)
	if owned and _customize_spot == String(spot.id):
		_add_variant_strip(item, z, k)
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
	resident_hits.clear()
	var view := get_viewport_rect().size
	var top := 96.0 + Look.safe_top(self)
	# the header — the grove's name, an invitation to choose
	var header := _lbl(tr("Choose a place ✿"), 40, CREAM)
	header.position = Vector2(0, top + 8.0)
	header.size = Vector2(view.x, 56.0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(header)
	# ONE wide card per row — a vista per place, floating in the grove SKY. Cards split the band
	# between the header and the safe bottom (no pool of dead space), but card height is capped so a
	# modest sky margin frames the stack top/bottom + sides — the backdrop's gradient + clouds read
	# as a real sky, not flat blue. The stack centers in the band. No ScrollContainer (the single-
	# input-surface model has none, every map fits one screen); cards are positioned + hit-tested directly.
	var n := G.MAPS.size()
	var side := 52.0
	var card_w := view.x - side * 2.0
	var sep := 20.0
	var band_top := top + 72.0
	var band_bot := view.y - (Look.safe_bottom(self) + 40.0)
	var band_h := band_bot - band_top
	var card_h := clampf((band_h - sep * float(maxi(n - 1, 0))) / float(maxi(n, 1)), 168.0, 288.0)
	var total_h := card_h * float(n) + sep * float(maxi(n - 1, 0))
	var y := band_top + maxf(0.0, (band_h - total_h) * 0.5)
	for z in n:
		var card := _make_card(z, card_w, card_h)
		card.position = Vector2(side, y)
		card.size = Vector2(card_w, card_h)
		content.add_child(card)
		select_hits.append({"node": card, "z": z})
		y += card_h + sep
	FX.pop_in(content)

# One map card: thumbnail + name + state line. Three states drive the line and the
# greying — locked ("after <prev>"), unlocked-incomplete (★ N left), restored.
# `card_h` > 0 makes the thumbnail a BANNER that expands to fill the card (the one-per-row
# place-picker); 0 keeps the legacy fixed-aspect thumb.
func _make_card(z: int, card_w: float, card_h: float = 0.0) -> Control:
	var map_data: Dictionary = G.MAPS[z]
	var open := map_unlocked(z)
	var done := map_spots_done(z)
	var banner := card_h > 0.0
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
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
	var thumb_min_h := 0.0 if banner else thumb_h   # banner thumbs EXPAND to fill the card height
	var thumb: Control
	# prefer the map's own thumbnail; else fall back to its `poi_<id>` teaser so every LOCKED place
	# shows ITS scenery under the fog instead of an identical blank tile; else a meadow-toned panel.
	var thumb_path := Game.art("map/map_%s.png" % String(map_data.id))
	if not ResourceLoader.exists(thumb_path):
		var poi := Game.art("map/poi_%s.png" % String(map_data.id))
		if ResourceLoader.exists(poi):
			thumb_path = poi
	if ResourceLoader.exists(thumb_path):
		var t := TextureRect.new()
		t.texture = load(thumb_path)
		t.custom_minimum_size = Vector2(thumb_w, thumb_min_h)
		if banner:
			t.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
		ph.custom_minimum_size = Vector2(thumb_w, thumb_min_h)
		if banner:
			ph.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
		_veil_thumb(thumb, String(map_data.id))
	var name_l := Label.new()
	name_l.text = tr(map_data.name)
	name_l.add_theme_font_size_override("font_size", 26)
	name_l.add_theme_color_override("font_color", CREAM if open else Color(CREAM, 0.6))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_l)
	if open and not done:
		# §13: the star count is the GOLD sprite + a number — not a baked ★ glyph — so it reads as
		# the same currency as the HUD wallet and the in-map spot pins (a centered icon+number row).
		col.add_child(_stars_left_row(map_stars_left(z), CREAM, 21))
	else:
		var stxt: String
		var scol: Color
		if done:
			stxt = tr("✿ restored"); scol = STRAW
		else:
			stxt = tr("✿ after %s") % tr(G.MAPS[z - 1].name); scol = Color(CREAM, 0.6)
		var state_l := Label.new()
		state_l.text = stxt
		state_l.add_theme_font_size_override("font_size", 21)
		state_l.add_theme_color_override("font_color", scol)
		state_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_l.autowrap_mode = TextServer.AUTOWRAP_WORD
		state_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(state_l)
	if open and not done and z == _frontier_map():
		FX.breathe_once(card)
	return card

# A centered "★ N left" status row: the GOLD star SPRITE (Look.icon) + a number-only label, so
# every star reads as the same currency as the HUD wallet. Used by the map cards and the map title
# plank (replaces the old baked-glyph "✿ N★ left"). Every node IGNOREs the single input surface.
func _stars_left_row(n: int, num_col: Color, px: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Look.icon("star", float(px) + 3.0)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var lbl := Label.new()
	lbl.text = tr("%d left") % n
	lbl.add_theme_font_size_override("font_size", px)
	lbl.add_theme_color_override("font_color", num_col)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	return row

# The fog veil for a LOCKED map card (§8). ONE place that dresses a thumbnail as
# "behind fog, not yet revealed" — a translucent ink scrim + a soft gradient that
# pools fog at the bottom edge + a faint ✿ ghost in the mist. It overlays exactly
# the thumb rect (full-rect child of `thumb`), so the "✿ after …" line below stays
# crisp. ART SEAM: if `map/veil_<id>.png` (per-map) or `map/veil.png` (generic)
# exists, that painted sprite REPLACES the code-drawn fog — grove art drops in with
# no code change. Every node IGNOREs the mouse (single-input-surface rule). The
# overlay node is named VEIL_NODE so a headless test can assert its presence/look.
# The veil anchors full-rect to `thumb`, so it tracks the thumbnail's size for free.
func _veil_thumb(thumb: Control, map_id: String) -> void:
	thumb.clip_contents = true
	var veil := Control.new()
	veil.name = VEIL_NODE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.add_child(veil)
	# ART SEAM — a painted veil sprite, if grove (or any game) supplies one.
	var art := Game.art("map/veil_%s.png" % map_id)
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
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) \
		or event is InputEventScreenTouch
	if pressed and event.pressed:
		_press = event.position
	elif pressed and not event.pressed and event.position.distance_to(_press) <= 18.0:
		# tap targets hit-test against GLOBAL rects; in place mode `content` is scaled,
		# so lift the content-local event point into global space (identity otherwise).
		var gpos: Vector2 = content.get_global_transform() * event.position
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
		if map_unlocked(z):
			_open_map(z)
		else:
			Audio.play("invalid_soft", -4.0)
			FX.wobble(n)
			FX.floating_text(self, gpos - Vector2(150, 70),
				tr("Restore %s first ✿") % tr(G.MAPS[maxi(z - 1, 0)].name), Color(CREAM, 0.9), 28)
		return

func _map_tap(gpos: Vector2) -> void:
	for hit in variant_hits:
		var vn: Control = hit.node
		if vn.get_global_rect().grow(6.0).has_point(gpos):
			_apply_variant(int(hit.z), int(hit.k), String(hit.vid), gpos)
			return
	# §1 residents: the "welcome a spirit" panel's kind rows float over the map — resolve them
	# before the spots so a tap on the panel never falls through to a spot behind it.
	for hit in resident_hits:
		var rn: Control = hit.node
		if rn.get_global_rect().grow(6.0).has_point(gpos):
			_on_welcome_tap(int(hit.z), String(hit.type), rn, gpos)
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
	var spot: Dictionary = G.MAPS[z].spots[k]
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
	if _task_strip != null:               # the chrome task strip tracks the frontier — rebuild it
		_build_task_strip(_task_strip_sb)
	if map_spots_done(z):
		Save.add_diamonds(G.MAP_DIAMONDS)
		Vault.skim(G.MAP_DIAMONDS)            # T44 SKIM-SITE 2/3 (map-restore): the piggy bank skims a slice of the restore premium (§10)
		FX.celebrate_at(self, get_global_rect().get_center(), tr("%s restored!") % tr(G.MAPS[z].name), STRAW)
		FX.floating_reward(self, get_global_rect().get_center() + Vector2(-60, 70),
			"gem", G.MAP_DIAMONDS, Color("#BFE6F2"), 38)
		Audio.play("level_complete", -2.0)
		# §8: this restore completed the map's spots, so its great-spirit GATE quest is now
		# the lone fence stand WAITING ON THE BOARD — a silent cross-screen handoff. Arm the
		# wordless pointer; the board consumes it on its next open and pulses the gate stand.
		# Only when the gate is genuinely still pending (not already delivered for this map).
		if not _gates().has(z):
			Save.set_gate_pointer(z)

# A swatch chip was tapped: pay (if needed) and dress the item — all on the map.
func _apply_variant(z: int, k: int, vid: String, at: Vector2) -> void:
	var spot_id := String(G.MAPS[z].spots[k].id)
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

# --- §1 residents: WELCOMING spirits home (the population sub-game) ----------------------
# On a COMPLETED map the player WELCOMES wandering spirits. A cozy panel lists each welcomable
# KIND (G.resident_lines) with its name + cost (coin/diamond). Tapping a row welcomes one
# (G.welcome_resident, which spends + adds + silently auto-merges two-of-a-kind). The roster is
# the source of truth: on success the population layer is REBUILT from it and a warm merge
# flourish plays once per merge event. The panel itself is an IGNORE visual; content's input
# surface resolves the taps via resident_hits.

# The "Welcome a spirit" panel — a small parchment card pinned bottom-center (above the CTA),
# one tappable row per welcomable kind. Built only on a populatable map; appended under `content`
# so it clears + rebuilds with the map. Frame copy WELCOMES (never "Buy").
func _add_welcome_panel(z: int) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var head := Label.new()
	head.text = tr("Welcome a spirit ✿")
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", INK)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	for type_def in G.resident_lines(z):
		col.add_child(_welcome_row(z, type_def))
	# pinned centered, just ABOVE the task strip / CTA stack at the bottom of the map
	var sb_cta := Look.safe_bottom(self)
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.offset_top = -340 - sb_cta
	card.offset_bottom = -184 - sb_cta
	content.add_child(card)

# One welcomable-kind row: the kind's name + its cost (coin/diamond icon + number). An IGNORE
# visual resolved by content's input surface (registered in resident_hits → _on_welcome_tap).
func _welcome_row(z: int, type_def: Dictionary) -> Control:
	var cost: Dictionary = G.resident_cost(type_def)
	var row_panel := PanelContainer.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(INK, 0.10)
	rs.set_corner_radius_all(12)
	rs.content_margin_left = 10.0
	rs.content_margin_right = 10.0
	rs.content_margin_top = 5.0
	rs.content_margin_bottom = 5.0
	row_panel.add_theme_stylebox_override("panel", rs)
	row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_panel.add_child(row)
	var name_l := Label.new()
	name_l.text = tr(String(type_def.name))
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", INK)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.custom_minimum_size = Vector2(150, 0)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_l)
	# the price: the currency SPRITE (coin/gem) + a number-only label (§13 — no baked emoji)
	var icon_id := "gem" if String(cost.currency) == "diamonds" else "coin"
	var ci := Look.icon(icon_id, 22.0)
	ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ci)
	var pl := Label.new()
	pl.text = str(int(cost.cost))
	pl.add_theme_font_size_override("font_size", 20)
	pl.add_theme_color_override("font_color", Color(BARK, 0.95))
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pl)
	resident_hits.append({"node": row_panel, "z": z, "type": String(type_def.id)})
	return row_panel

# A welcome-row was tapped: welcome one spirit of `type_id` on map z. G.welcome_resident spends +
# adds + silently auto-merges. On ok: rebuild the population layer from the now-updated roster, play
# a warm float-text + a merge flourish once per merge event. On not-ok: the standard "can't afford"
# feedback (the same wobble + "need more" the spots use).
func _on_welcome_tap(z: int, type_id: String, node: Control, at: Vector2) -> void:
	var res := G.welcome_resident(z, type_id)
	if not bool(res.get("ok", false)):
		Audio.play("invalid_soft", -4.0)
		FX.wobble(node)
		FX.floating_text(self, at - Vector2(110, 60), tr("Not enough — keep tending ✿"), Color(CREAM, 0.9), 26)
		return
	Audio.play("level_complete", -6.0, 1.15)
	FX.burst(self, at, STRAW, 14)
	FX.floating_text(self, at - Vector2(120, 70), tr("A new friend wanders in ✿"), STRAW, 26)
	# the roster changed → rebuild the whole map (the population layer reads the fresh roster). Then
	# play the merge flourish on the rebuilt layer, once per auto-merge event (the roster is already
	# committed by the API, so this is pure juice).
	_build_map()
	_update_hud()
	var events: Array = res.get("events", [])
	if not events.is_empty():
		var amb: Control = content.get_node_or_null("AmbientLayer")
		Ambient.merge_poof(amb, events.size())
		Audio.play("tidy_poof", -2.0, 1.1)
		FX.floating_text(self, get_global_rect().get_center() - Vector2(0, 40),
			tr("Two friends became one ✿"), CREAM, 26)

# --- HUD & chrome -----------------------------------------------------------------------

func _build_hud() -> void:
	# the shared top bar (owner: one module — ★🪙💎 + Store + the S10 Lv chip
	# never move between scenes; the chip ticks via the module's refresh). The home
	# screen is the hub itself, so it does NOT pass `home` — the HUD's home chip is
	# redundant here and the level ring stands alone (item 2; the board still passes
	# `home` since its nav legitimately returns to the map).
	var hud := Hud.build(self, {
		"water_grant": func() -> void:
			var g := Save.grove()
			g["water"] = G.WATER_CAP
			Save.grove_write()})
	stars_label = hud.stars
	coins_label = hud.coins
	level_label = hud.level
	level_prog_label = hud.level_prog
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
	# The home/map bottom nav is the SAME shared global row the board uses (ui/nav_bar.gd), fed its own
	# specs: Settings · [Play] (centre, prominent) · Shop · Map. PLAY is the way into the garden/board —
	# the prominent leaf that replaces the old wide "Enter Garden ▶" text CTA. The Store "new offer" badge
	# rides the Shop button; the piggy bank moved to the LiveOps rail (its ready-pip rides it there).
	# _shop_btn stays the §14 spotlight target.
	var sb := Look.safe_bottom(self)
	var sb_cta := sb
	var nav := NavBar.build(self, [
		# Settings — the shared music/sounds/calm card (ui/settings.gd).
		{"icon": "nav_gear.png", "px": 96.0, "label": tr("Settings"), "action": func() -> void:
			Audio.play("button_tap", -2.0)
			_open_settings()},
		# Play — the way into the garden/board: the prominent leaf (the old "Enter Garden ▶" text CTA retired).
		{"icon": "nav_leaf.png", "px": 140.0, "label": tr("Play"), "action": _on_board},
		# Shop — the shared currency store (the wallet's open_shop closure).
		{"icon": "nav_shop.png", "px": 96.0, "label": tr("Shop"), "action": func() -> void:
			Audio.play("button_tap", -2.0)
			if _open_shop.is_valid():
				_open_shop.call()},
		# Map — the place-picker (atlas).
		{"icon": "nav_map.png", "px": 96.0, "label": tr("Map"), "action": func() -> void:
			Audio.play("button_tap", -2.0)
			_open_select()}])
	for b in nav.buttons:
		_chrome_nodes.append(b)
	_chrome_nodes.append(nav.row)
	# §14 spotlight target = the Shop button (index 2, after Settings and Play).
	_shop_btn = nav.buttons[2]
	# the Play leaf breathes so the way to the board reads as the primary action.
	FX.breathe_once(nav.buttons[1])
	# the Store "new offer" badge — shown only while the starter pack is unclaimed (an actionable offer)
	_store_badge = Look.badge("dot")
	Look.attach_badge(_shop_btn, _store_badge)
	_refresh_store_badge()
	# the LiveOps rail (right edge) + the task strip (above the nav row) — the two kept chrome slices.
	# The piggy bank now lives on the rail (its claimable ready-pip is attached there).
	_build_liveops_rail(sb)
	_build_task_strip(sb_cta)

# The LIVE-OPS RAIL (backlog "LiveOps buttons") — a CALM vertical column of round buttons on the
# right edge, ABOVE the bottom corner cluster: Daily, Free, and (guarded) Inbox. Each is a quiet
# cream chrome button; the RED BADGE does all the attention-pulling, shown ONLY when actionable
# (today unclaimed / a free watch is ready / unread mail). Every rail button is appended to
# _chrome_nodes so it follows _set_map_chrome_visible (hidden on the place-picker). The rail
# stacks UPWARD from just above the corner cluster so it never collides with the CTA or the gear.
func _build_liveops_rail(sb: float) -> void:
	var px := 72.0
	var gap := 14.0
	var bottom := 172.0 + sb            # first rail button sits above the ~150px full-width nav row (item 4)
	var slot := 0
	# Daily — opens the existing login calendar on demand; badge when today is unclaimed.
	var daily := _rail_button("📅", _open_daily)
	_place_rail(daily, px, bottom, slot); slot += 1
	_daily_badge = Look.badge("dot")
	Look.attach_badge(daily, _daily_badge)
	# Free — a rewarded-video gem faucet; badge when a watch is offerable.
	var free := _rail_button("▶", _claim_free_gems)
	_place_rail(free, px, bottom, slot); slot += 1
	_free_badge = Look.badge("dot")
	Look.attach_badge(free, _free_badge)
	# Inbox — GUARDED: only built when the parallel inbox system exists in this build (load() runtime).
	if _has_inbox:
		var inbox := _rail_button("✉", _open_inbox)
		_place_rail(inbox, px, bottom, slot); slot += 1
		_inbox_badge = Look.badge("pill", 0)
		Look.attach_badge(inbox, _inbox_badge)
	# Piggy bank — the diegetic accrual-vault, moved here off the bottom bar. Its "claimable" ready-pip
	# (driven by _refresh_piggy_pip → Vault.claimable()) rides this rail button now.
	var piggy := _rail_button("🐷", _open_vault)
	_place_rail(piggy, px, bottom, slot); slot += 1
	_piggy_pip = Look.badge("dot")
	Look.attach_badge(piggy, _piggy_pip)
	_refresh_piggy_pip()
	_refresh_liveops_badges()

# One calm cream rail button: the round-button art (or an INK-disc fallback) carrying a glyph Label
# directly — same pattern the atlas/piggy chrome uses for glyphs the kit has no icon for, so we
# never touch skin.gd's ICON_GLYPHS. Mouse-ignored glyph keeps the single-input-surface rule.
func _rail_button(glyph: String, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(72, 72)
	if ResourceLoader.exists(Look.kit("btn_round.png")):
		var st := StyleBoxTexture.new()
		st.texture = load(Look.kit("btn_round.png"))
		st.set_texture_margin_all(24.0)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
	else:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(INK, 0.6)
		s.set_corner_radius_all(36)
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", s)
		b.add_theme_stylebox_override("pressed", s)
	var g := Label.new()
	g.text = glyph
	g.add_theme_font_size_override("font_size", 32)
	g.add_theme_color_override("font_color", CREAM)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(g)
	Look.add_press_juice(b)
	b.pressed.connect(cb)
	add_child(b)
	_chrome_nodes.append(b)
	return b

# Pin a rail button to the right edge, stacked UPWARD (slot 0 lowest) from `bottom` px off the floor.
func _place_rail(b: Button, px: float, bottom: float, slot: int) -> void:
	var step := px + 14.0
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = -16 - px
	b.offset_right = -16
	b.offset_bottom = -(bottom + slot * step)
	b.offset_top = b.offset_bottom - px

# Light each rail badge ONLY when its surface is actionable (the calm rule: the badge pulls, not the
# button). Daily = today unclaimed; Free = a rewarded watch offerable; Inbox = unread count (guarded).
func _refresh_liveops_badges() -> void:
	if _daily_badge != null and is_instance_valid(_daily_badge):
		_daily_badge.visible = not Login.claimed_today()
	if _free_badge != null and is_instance_valid(_free_badge):
		_free_badge.visible = Ads.can_show("free_gems")
	if _has_inbox and _inbox_badge != null and is_instance_valid(_inbox_badge):
		var n := int(load("res://engine/scripts/core/inbox.gd").unread_count())
		_inbox_badge.visible = n > 0
		# the count-pill badge is a PanelContainer whose only child is its number Label (skin.gd badge("pill"))
		if _inbox_badge.get_child_count() > 0 and _inbox_badge.get_child(0) is Label:
			(_inbox_badge.get_child(0) as Label).text = ("99+" if n > 99 else str(maxi(n, 1)))

# Daily rail tap: open the login calendar on demand (the persistent entry the auto-popup lacked).
# Refreshes the wallet + the day-badge on close (a just-claimed day drops its cue).
func _open_daily() -> void:
	Audio.play("button_tap", -2.0)
	LoginUI.open(self, {"refresh": func() -> void:
		_update_hud()
		_refresh_piggy_pip()
		_refresh_liveops_badges()})

# Free rail tap: the rewarded gem faucet. If a watch is offerable, claim it (the stub records the
# watch + grants the 💎 purely in Save) and play a small reward FX from the button; else a soft
# "come back" nudge — never a wall. Refreshes the wallet + the Free badge after.
func _claim_free_gems() -> void:
	# the FX origin is the Free button (the badge's host), so coins/gems arc from where the player tapped
	var src: Vector2 = get_global_rect().get_center()
	if _free_badge != null and is_instance_valid(_free_badge) and is_instance_valid(_free_badge.get_parent()):
		src = (_free_badge.get_parent() as Control).get_global_rect().get_center()
	var res := Ads.claim("free_gems")
	if not bool(res.get("ok", false)):
		Audio.play("invalid_soft", -6.0)
		FX.floating_text(self, src, tr("More acorns soon — come back later"), CREAM, 22)
		_refresh_liveops_badges()
		return
	var gems := int(res.get("gems", 0))
	Audio.play("level_complete", -3.0, 1.15)
	FX.celebrate_reward(self, src, "gem", gems, Color("#A9C7E8"))
	FX.fly_to_wallet(self, src, Look.icon("gem", 36.0),
		_hud_panels[0] if _hud_panels.size() > 0 and is_instance_valid(_hud_panels[0]) else null,
		func() -> void: _update_hud())
	_update_hud()
	_refresh_liveops_badges()

# Inbox rail tap (GUARDED): open the parallel mailbox modal via load() so this worktree never hard-
# depends on a system it doesn't own. Refreshes the unread badge on close.
func _open_inbox() -> void:
	if not _has_inbox:
		return
	Audio.play("button_tap", -2.0)
	load("res://engine/scripts/ui/inbox.gd").open(self)
	# refresh deferred so a modal that grants on open settles before we re-read the count
	_refresh_liveops_badges.call_deferred()

# The TASK STRIP (backlog "Task strip") — a slim cozy band JUST ABOVE the garden CTA showing the
# next short-term goal: "Today  ✿ N/M  → 🎁", chained off the EXISTING restore-the-next-spot goal
# (no bolted-on quest — the cozy spine IS the task). On a fully-restored frontier it celebrates
# "✿ restored → 🎁" and, once, pays MAP_TASK_REWARD. Decorative + informative; never blocks play.
# Appended to _chrome_nodes so it follows the place-picker hide.
func _build_task_strip(sb_cta: float) -> void:
	_task_strip_sb = sb_cta
	if _task_strip != null and is_instance_valid(_task_strip):
		_task_strip.queue_free()
		_chrome_nodes.erase(_task_strip)
		_task_strip = null
	var z := _frontier_map()
	if z < 0:
		z = G.hub_map()
	var total: int = G.MAPS[z].spots.size()
	var done: int = owned_count(z)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3D2A1B", 0.84)
	sb.set_corner_radius_all(14)                  # small chip radius (matches UiSkin.RADIUS_CHIP)
	sb.set_border_width_all(2)
	sb.border_color = Color("#2A1C11", 0.9)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var head := Label.new()
	head.text = tr("Today")
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", STRAW)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(head)
	row.add_child(Look.icon("star", 22.0))
	var prog := Label.new()
	prog.text = ("%d/%d" % [done, total]) if done < total else tr("restored")
	prog.add_theme_font_size_override("font_size", 20)
	prog.add_theme_color_override("font_color", CREAM)
	prog.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(prog)
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 20)
	arrow.add_theme_color_override("font_color", Color(CREAM, 0.8))
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)
	var gift := Label.new()
	gift.text = "🎁"
	gift.add_theme_font_size_override("font_size", 22)
	gift.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gift)
	# pinned centered, just ABOVE the nav row (item 4 moved the bottom chrome into one full-width row
	# ~132px tall — its prominent center CTA; the strip clears it).
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.offset_top = -208 - sb_cta
	card.offset_bottom = -170 - sb_cta
	add_child(card)
	_chrome_nodes.append(card)
	_task_strip = card
	card.visible = (_view == "map")          # a rebuild mid-place-picker stays hidden (follows the chrome toggle)
	# pay the milestone ONCE: the frontier map is fully restored and we haven't granted yet.
	if done >= total and total > 0:
		_grant_map_task_reward(z)

# Grant the slim task-strip milestone reward ONCE per map (persisted by a per-map flag) when its
# spots are all restored. Celebrates the beat the player already reached (§4: no possibility gate).
func _grant_map_task_reward(z: int) -> void:
	var g := Save.grove()
	var claimed: Dictionary = g.get("task_reward", {})
	var key := String(G.MAPS[z].id)
	if claimed.has(key):
		return
	claimed[key] = true
	g["task_reward"] = claimed
	Save.grove_write()
	var rew: Dictionary = Game.DATA.MAP_TASK_REWARD
	var coins := int(rew.get("coins", 0))
	var gems := int(rew.get("gems", 0))
	if coins > 0:
		Save.add_coins(coins)
	if gems > 0:
		Save.add_diamonds(gems)
	if not is_inside_tree():
		return
	_task_reward_fx.call_deferred(coins, gems)

func _task_reward_fx(coins: int, gems: int) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var at := get_global_rect().get_center() + Vector2(0, 120)
	Audio.play("level_complete", -4.0, 1.1)
	var dy := 0.0
	if gems > 0:
		FX.celebrate_reward(self, at + Vector2(0, dy), "gem", gems, Color("#A9C7E8")); dy += 34
	if coins > 0:
		FX.celebrate_reward(self, at + Vector2(0, dy), "coin", coins, Color("#E3B23C"))
	FX.floating_text(self, at - Vector2(0, 40), tr("Today's task complete ✿"), CREAM, 24)
	_update_hud()

# Refresh the Store "new offer" badge — lit while the one-time starter pack is unclaimed (the
# clearest "there's an offer for you" signal; Shop.starter_available is the public query).
func _refresh_store_badge() -> void:
	if _store_badge != null and is_instance_valid(_store_badge):
		_store_badge.visible = Shop.starter_available()

# Re-read every chrome badge's actionable state in one go (called on map nav). Cheap, idempotent.
func _refresh_chrome_badges() -> void:
	_refresh_store_badge()
	_refresh_liveops_badges()

# T45: open the diegetic piggy-bank jar (the accrual vault, ui/vault.gd). On close it refreshes
# the ready-pip so a just-cracked (now empty) jar drops its cue immediately.
func _open_vault() -> void:
	Audio.play("button_tap", -2.0)
	VaultUI.open(self, {"refresh": func() -> void: _refresh_piggy_pip()})

# Light the piggy ready-pip iff the jar has banked past the claim threshold (Vault.claimable()).
func _refresh_piggy_pip() -> void:
	if _piggy_pip != null and is_instance_valid(_piggy_pip):
		_piggy_pip.visible = Vault.claimable()

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

# T45 (§18): auto-show the daily-login calendar on the day's first hub open — ONCE, and only after a
# rewarding moment, never on a cold first launch. The §18 spirit is "prompt after a reward, not a
# cold open", so all of these must hold:
#   • the flag is on (daily_login_popup),
#   • today is genuinely unclaimed (not Login.claimed_today() — the day's first open),
#   • this is NOT the very-first FTUE session (unlocks.size() > 0 — at least one spot restored, so a
#     rewarding beat has already happened; a brand-new save sees the FTUE, not a money-ish calendar),
#   • no FTUE shop spotlight is owed (not Spotlight.should_spotlight("shop")) — never two overlays at once.
# Deferred TWO frames: one so the scene/chrome is built, one more so the same-frame shop-spotlight
# defer resolves first (it marks itself seen), so the should_spotlight gate reads settled state.
func _maybe_login_popup_deferred() -> void:
	if not Features.on("daily_login_popup"):
		return
	if Login.claimed_today():
		return
	if unlocks.size() <= 0:                       # cold first FTUE session — show the FTUE, not the calendar
		return
	if Spotlight.should_spotlight("shop"):        # an FTUE shop spotlight is owed → don't collide; skip today
		return
	await get_tree().process_frame                # let the shop-spotlight defer (same frame) settle first
	if not is_instance_valid(self) or not is_inside_tree():
		return
	# re-check after the await — a spotlight may have just been raised, or today claimed elsewhere
	if Login.claimed_today():
		return
	if _spotlight_overlay_live():                 # an FTUE spotlight is on screen → never stack a second overlay
		return
	LoginUI.open(self, {"refresh": func() -> void:
		_update_hud()
		_refresh_piggy_pip()})

# True if a feature-spotlight overlay is currently on screen (SpotlightOverlay.present roots a
# full-rect Control at z_index 4096 — its signature). Used to keep the login popup from stacking
# on top of an FTUE spotlight on a borderline frame.
func _spotlight_overlay_live() -> bool:
	for c in get_children():
		if c is Control and (c as Control).z_index == 4096:
			return true
	return false

func _open_settings() -> void:
	SettingsUI.open(self)               # the shared card (music/sounds/calm) — also on the board's bottom bar

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
