extends Control
## HOME: the game's hub IS the homestead (Core §8 / grove_spec §3). A map IS one
## self-contained image — an open space (the Farmhouse, the Barn, …) with the
## restoration SPOTS sitting directly on that image. Unowned spots price themselves
## ("✿ N★" — tap to buy with stars), and OWNED ones open their own customization list
## (variants priced in coins/diamonds).
## Discrete maps are reached via a map-SELECT screen; the first map (the hub) is the
## home. Buying advances your level; level-ups gift water+diamonds. A pinned garden button
## leads to the board. Every map renders through ONE path (_build_map → _build_map_base + _seat_spots):
## a map that ships §16 home art (clean/broken + per-building masks) reveals the clean art per restored
## building (_build_home_spot); any other map draws cutout sprites / placeholder tiles via _make_spot.

const G = preload("res://engine/scripts/core/content.gd")
const Strings = preload("res://engine/scripts/core/strings.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Music = preload("res://engine/scripts/core/music.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const LevelPopup = preload("res://engine/scripts/ui/level_popup.gd")   # tap the Lv badge → the level screen
const NavBar = preload("res://engine/scripts/ui/nav_bar.gd")   # the shared bottom nav row (board + map)
const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Vault = preload("res://engine/scripts/core/vault.gd")                  # T44 SKIM-SITE — the piggy bank skims earned premium here
const VaultUI = preload("res://engine/scripts/ui/vault.gd")                  # T45: the diegetic piggy-bank jar (chrome entry point)
const Login = preload("res://engine/scripts/core/login.gd")                  # T45: the forgiving daily-login calendar (auto-popup gate)
const LoginUI = preload("res://engine/scripts/ui/login.gd")                  # T45: the diegetic login-calendar popup surface
const Shop = preload("res://engine/scripts/ui/shop.gd")                      # chrome: the Store-badge query (starter_available)
const SettingsUI = preload("res://engine/scripts/ui/settings.gd")            # the shared Settings card (gear + board bottom bar)
const Debug = preload("res://engine/scripts/ui/debug.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Design = preload("res://engine/scripts/core/design.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")   # pre-warm Board off-thread so the garden CTA is snappy
const BootTrace = preload("res://engine/scripts/core/boot_trace.gd")   # cold-boot phase timer — no-ops unless the Boot splash opened a trace
const Pal = Game.PALETTE
# The grove UI kit (a game-side tool): lazy-loaded so the engine never hard-depends on it — the unowned
# home spot's restore-cost disc builds through it from the workbench-saved style. Missing → baked fallback.
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const HOME_CHROME_PATH := "res://games/grove/home_chrome.gd"   # canonical chrome icon ids (shared with the bake)

const SPOT_NAME_DY := 50.0   # spot name/price stack baseline below the plot point

# Opacity the lock veil is snapshotted at for the breaking-glass shatter. The resting ready-zone veil
# is semi-transparent; the shards are captured at this crisper alpha so the break reads clearly.
const SHATTER_VEIL_ALPHA := 0.72

# T2: the board's Decorate sets this (a MAP id) before changing scene; _ready
# consumes it and opens that map BEFORE the first draw — no map-select flash.
# Process-scoped on purpose: a fresh app boot always lands on the frontier.
static var decorate_map := ""
# item 3 (§18): the daily-login calendar auto-pops once per APP LAUNCH, not once per Map open. This
# static arms on the first show and survives Board→Map scene changes within a launch (a new process
# resets it), so a return to the map never re-pops the calendar.
static var _login_shown_launch := false

const SKY = Pal.SKY
const MEADOW = Pal.MEADOW
const LEAF = Pal.LEAF
const INK = Pal.INK
const CREAM = Pal.CREAM
const STRAW = Pal.STRAW
const BARK = Pal.BARK
const CLAY = Pal.CLAY

# --- map-select place-picker CARD ----------------------------------------------------------------------
# The CARD recipe (the SHARED gold-badge frame over the locale art for an OPEN place, or over a dark
# gradient + lock medallion for a LOCKED one / cream count pill `pill_left` / the rounded-corner art clip)
# lives in the SHARED kit — Kit.map_card + Kit.map_card_opts_from_config — so the workbench tunes the SAME
# recipe the game renders here (the currency-pill / settings pattern). map.gd resolves each card's DATA (open/locked ·
# locale art · star count · the "after <prev>" prerequisite) and owns the back-arrow chrome below; the
# card LOOK is workbench-saved config. The back arrow returns to the map you were viewing.
const VEIL_NODE := "Veil"                       # the locked-card fog overlay's name (mapfx_tests asserts it; built by Kit.map_card)
const CARD_BACK := "map/back_arrow.png"          # the back button's arrow mark (on the shared home disc)

var unlocks := {}

# THE one input surface. Rebuilding a view clears + repopulates it; every visual
# descendant is MOUSE_FILTER_IGNORE (the single-input-surface rule; a test asserts it).
var content: Control
var _view := "map"               # "map" | "select"
var _last_view_size := Vector2.ZERO   # viewport size at the last fit — guards the resize re-fit
var _relayout_queued := false         # coalesces a burst of size_changed into one rebuild per frame
var _map_idx := 0                # the map being viewed
var _map_rect := Rect2()         # the stable map canvas (spot pos maps to THIS rect)
var _map_art_rect := Rect2()     # the placed/scaled background art
var spot_hits: Array = []        # [{node, z, k}] — the open map's spots
var select_hits: Array = []      # [{node, z, y0}] — the map-select cards (y0 = screen base y, pre-scroll)
var _press := Vector2.ZERO       # last press point (still-tap resolution)
var _select_clip: Control = null # the place-picker's clipped scroll viewport (cards live + scroll inside it)
var _select_scroll := 0.0        # current scroll offset of the place-picker stack (px from the top)
var _select_scroll_max := 0.0    # 0 when the stack fits the band (no scroll); else total_h - band_h

var _chrome_nodes: Array = []    # bottom chrome (garden CTA, gear, shop, atlas)
var _play_btn: Button            # the MERGED bottom-right CTA: PLAY (board+acorn → board), or RESTORE (vine → unlock) when the map's next spot is affordable
var _residents_btn: Button = null  # the bottom-nav Residents badge — shown only on a fully-unlocked map
var _weather: Control = null     # ambient weather layer — belongs to a MAP; hidden on the place-picker
var _shop_btn: Control           # anchor for the Store "new offer" badge — the wallet's gem pill (premium stall's + entry)
var _select_back: Button         # the place-picker's bottom-left back arrow (shown only in the select view)
var level_label: Label
var coins_label: Label
var _hud_refresh := Callable()
var _gear: Button = null          # the shared HUD's top-right settings tile (the live-ops rail hangs beneath it)
var _piggy_pip: Control = null    # T45: the vault chrome button's "claimable" ready glow (shown when Vault.claimable())
var _open_shop := Callable()      # opens the shared Shop (lives in the bottom chrome)
var _hud_panels: Array = []       # wallet + Lv chips
# chrome badges (driven by actionable-state queries; visibility only — never a nag)
var _store_badge: Control = null  # Store "new offer" badge — lit while the starter pack is unclaimed
var _daily_badge: Control = null  # Daily rail badge — lit when today's login reward is unclaimed
var _inbox_badge: Control = null  # Inbox rail badge — unread count (only built when the inbox system exists)
# Inbox is a PARALLEL system (core/inbox.gd + ui/inbox.gd) NOT in this worktree's base — GUARD it so
# this compiles + tests without it, and the button lights up once that system merges (load() is runtime).
var _has_inbox := ResourceLoader.exists("res://engine/scripts/ui/inbox.gd") and ResourceLoader.exists("res://engine/scripts/core/inbox.gd")

func _ready() -> void:
	# Boot trace (cold launch only): every begin/end here no-ops unless the Boot splash opened a
	# trace, so a warm Board->Map open pays nothing and prints nothing. Supersedes the old [prof] prints.
	BootTrace.begin("map.heal+fit")
	_heal_capture_flags()
	Design.fit_desktop_window()          # desktop: open at the design portrait aspect, monitor height
	BootTrace.end("map.heal+fit")
	BootTrace.begin("map.font"); UiFont.apply(); BootTrace.end("map.font")
	BootTrace.begin("map.music"); Music.ensure(); BootTrace.end("map.music")
	if get_tree() != null:               # headless harnesses run _ready() out of tree
		get_tree().quit_on_go_back = false   # we step back to the map-select on OS back instead
	BootTrace.begin("map.load_state"); _load_state(); BootTrace.end("map.load_state")

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

	# the day's weather drifts over the MAP (calm mode wins inside); kept as a member so the
	# place-picker can hide it — drifting leaves over a static chooser read as stray sprites.
	BootTrace.begin("map.weather")
	var g0 := Save.grove()
	Ambient.check_winback(g0, Time.get_unix_time_from_system())
	_weather = Ambient.build_weather(get_viewport_rect().size, Ambient.weather_now(FX.calm()))
	add_child(_weather)
	BootTrace.end("map.weather")

	BootTrace.begin("map.build_hud"); _build_hud(); BootTrace.end("map.build_hud")
	BootTrace.begin("map.build_chrome"); _build_chrome(); BootTrace.end("map.build_chrome")
	BootTrace.begin("map.update_hud"); _update_hud(); BootTrace.end("map.update_hud")

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

	# Live RESIZE: the map canvas is fitted once per build (_map_image_rect reads the viewport), so
	# unlike the board's anchor-stretched background it does NOT follow a window/orientation resize on
	# its own — drag a desktop window wider and the home stayed put. Re-fit the active view whenever the
	# viewport actually changes. (headless harnesses run _ready out of tree → no viewport to watch.)
	if get_viewport() != null:
		_last_view_size = get_viewport_rect().size
		get_viewport().size_changed.connect(_on_viewport_resized)

	# T45 (§18): on the day's FIRST hub open, auto-show the login calendar ONCE. The hub map is the
	# surface the player reliably hits first (fresh boot lands on the frontier — the hub when nothing
	# is open yet — and the board's Home button returns here). Gated + deferred so it never fires on a
	# cold first launch (see _maybe_login_popup).
	_maybe_login_popup_deferred.call_deferred()

	# Apple Game Center sign-in → a pseudonymous player id for targeted mail (and later more). Flag-gated
	# + iOS-only (the provider no-ops without the GameCenter plugin singleton), so this is inert in the
	# editor / on desktop / in tests. Idempotent — safe to call on every home open.
	if Features.on("game_center") and ResourceLoader.exists("res://engine/scripts/core/identity.gd"):
		load("res://engine/scripts/core/identity.gd").boot(self)

	# Server-driven mail: top the mailbox up from the remote feed on every home open, and again on a
	# light timer while the player lingers. Guarded + flag-gated + non-blocking (a dead network or the
	# placeholder endpoint is a silent no-op; sync() also skips when the box is full). See core/inbox_sync.gd.
	_sync_mail.call_deferred()
	if _has_inbox and Features.on("mail_sync"):
		var mail_timer := Timer.new()
		mail_timer.wait_time = MAIL_SYNC_EVERY
		mail_timer.autostart = true
		mail_timer.timeout.connect(_sync_mail)
		add_child(mail_timer)

	Debug.mount(self)                    # debug/authoring panel (no-op in prod)

	SceneWarm.prewarm("res://engine/scenes/Board.tscn")   # warm the board off-thread while the player lingers on the map

	BootTrace.done()                     # cold boot only: print the boot-phase timing table, then close the trace

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

func _gates() -> Array:                       # which maps are spots-done (all spots restored → next map unlocks)
	return Save.grove().get("gates", [])

func spot_owned(id: String) -> bool:
	return unlocks.has(id)

func map_spots_done(z: int) -> bool:
	return G.map_spots_done(z, unlocks)

func map_unlocked(z: int) -> bool:
	return G.map_unlocked(z, unlocks, _gates())

func owned_count(z: int) -> int:
	return G.owned_count(z, unlocks)

func _frontier_map() -> int:
	return G.frontier_map(unlocks, _gates())

# --- navigation: a map IS one image; discrete maps via the map-select -------------------

func _open_map(z: int) -> void:
	_view = "map"
	_map_idx = z
	_set_map_chrome_visible(true)         # a map wears its bottom chrome + drifting weather
	if _select_back != null and is_instance_valid(_select_back):
		_select_back.visible = false      # the back arrow belongs to the place-picker, not a map
	# T1: remember WHICH map you were on — the board's Decorate jumps back here
	var g := Save.grove()
	g["last_map"] = String(G.MAPS[z].id)
	Save.grove_write()
	_build_map()
	_refresh_chrome_badges()             # Store / Daily / Free / Inbox badges re-read their actionable state on nav
	_refresh_play_cta()                  # the merged CTA is PER-MAP — flip Play↔Restore for the map just opened
	_refresh_residents_btn()             # show/hide the Residents badge for the map just opened

func _open_select() -> void:
	_view = "select"
	_set_map_chrome_visible(false)        # the place-picker is a calm chooser — no map chrome, no weather
	Audio.play("button_tap", -4.0)
	_select_scroll = 0.0                  # always open the picker scrolled to the top
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

# (The 2× DOUBLER lived here, triggered by the now-removed hub yield-collect. It was RE-HOMED to the
# quest coin reward on the board — see board.gd `_maybe_offer_2x` — since the map scene no longer has a
# coin faucet to double. It is a 💎-priced doubler now, gated to rewards big enough to beat the shop.)

# --- THE MAP VIEW (grove_spec §3) -------------------------------------------------------
# One self-contained image fills the area below the HUD; the spots sit directly on
# it at spot.pos (a fraction of the fitted image rect). Owned spots draw furniture
# sprites. The whole view lives under `content` — every child IGNOREs (single input
# surface).

func _build_map(animate := true) -> void:
	for c in content.get_children():
		c.queue_free()
	spot_hits.clear()
	select_hits.clear()
	var z := _map_idx
	# the stable map canvas is a centered, design-aspect rect (see _map_image_rect) that the HUD
	# floats over. Background art fills it; spots ride this same rect, so the painting and the
	# buildings stay locked together on any window aspect.
	_map_rect = _map_image_rect()
	_map_art_rect = _map_placed_rect(z, _map_rect)
	# ONE rendering path for EVERY map (item 1 — no hub special-case): a unified base layer, then one
	# spot per G.MAPS[z].spots index-aligned into spot_hits via _seat_spots. A map that ships §16 home
	# art (clean/broken + per-building masks) reveals the clean art per RESTORED building; any other map
	# renders its cutout sprites / ghost badges through _make_spot. Both share this base + seat + ambient.
	var home = G.MAPS[z].get("home", null)
	var has_home := typeof(home) == TYPE_DICTIONARY
	var home_dict: Dictionary = home if has_home else {}
	BootTrace.begin("map.open.base")
	var frame := _build_map_base(z, home_dict)   # §16 overgrown home base · the map's bg · or flat fallback
	BootTrace.end("map.open.base")
	# z-order parity with the pre-unify renderer (so the look is unchanged): a §16 home seats its reveals
	# /badges UNDER the ambient wanderers + title plank; a cutout map seats its sprites OVER them.
	BootTrace.begin("map.open.seat")
	if has_home:
		_seat_spots(z, home_dict, frame)
	BootTrace.end("map.open.seat")
	BootTrace.begin("map.open.ambient")
	# ambient life + title — every map. On a COMPLETED map the wanderers ARE its residents (the §1
	# population sub-game); an in-progress map keeps the baseline generic ambient.
	var amb: Control
	if G.can_populate(z, unlocks, _gates()):
		amb = Ambient.build_population_layer(_map_rect.size, G.resident_members(z))
	else:
		amb = Ambient.build_layer(_map_rect.size, G.character_count(unlocks))
	amb.position = _map_rect.position
	amb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(amb)
	if not has_home:
		_seat_spots(z, home_dict, frame)
	# §1 residents: a FULLY-UNLOCKED map (spots restored + gate delivered) pays its one-time unlock gift
	# (the celebration dialog) and offers the Residents shop via the bottom-nav button (_make_residents_button).
	if G.can_populate(z, unlocks, _gates()):
		_maybe_show_unlock_reward(z)
	BootTrace.end("map.open.ambient")
	if animate:
		FX.pop_in(content)        # a navigation pops in; a live resize re-fit does not (would flicker)

# Seat one tap-hit per spot, index-aligned with G.MAPS[z].spots (the buy flow + tests rely on this).
# A §16 home (home != {}) renders the per-building reveal/badge into `frame`; any other map renders the
# cutout sprite/ghost via _make_spot. Either way the hit lands in content + spot_hits.
func _seat_spots(z: int, home: Dictionary, frame: Control) -> void:
	var has_home := not home.is_empty()
	var is_vine := typeof(G.MAPS[z].get("vine", null)) == TYPE_DICTIONARY
	var by_id := _home_buildings(home) if has_home else {}
	# For a vine map, the READY-to-claim region gets a hit that covers its WHOLE zone (its polygon bounding
	# box) instead of the small centroid disc, so a tap anywhere on the highlighted zone restores it.
	var vregions: Array = []
	var visize := Vector2.ONE
	var ready_k := -1
	if is_vine:
		var Grove := load("res://games/grove/vine/vine_maps.gd")
		var vine = G.MAPS[z].get("vine", null)
		vregions = Grove.regions_for(vine)
		visize = Grove.image_size_for(vine)
		var nxt := G.map_next_unlock(z, unlocks)
		if int(nxt.k) != -1 and Save.exp_total() >= int(nxt.exp):
			ready_k = int(nxt.k)
	for k in G.MAPS[z].spots.size():
		var hit: Control
		if is_vine:
			hit = _build_vine_spot(z, k, ready_k, vregions, visize)
		elif has_home:
			hit = _build_home_spot(z, k, home, frame, by_id)
		else:
			hit = _make_spot(z, k, _map_rect)
		content.add_child(hit)
		spot_hits.append({"node": hit, "z": z, "k": k})

# A vine map's per-region affordance: unowned -> a tap target that routes the restore via spot_hits;
# owned -> an inert marker (keeps spot_hits index-aligned). The READY spot (k == ready_k) takes a
# full-zone hit so tapping anywhere on the lit zone claims it; other zones keep the compact centroid disc.
func _build_vine_spot(z: int, k: int, ready_k: int = -1, regions: Array = [], isize: Vector2 = Vector2.ONE) -> Control:
	var spot: Dictionary = G.MAPS[z].spots[k]
	# adapt the spot's Vector2 pos to the home-building dict's [x, y] list form that _home_badge reads.
	var b := {"pos": [float(spot.pos.x), float(spot.pos.y)]}
	if spot_owned(String(spot.id)):
		return _home_owned_item(z, k, b)
	if k == ready_k and k < regions.size():
		var zone := _region_zone_hit(regions[k], isize)
		if zone != null:
			return zone
	return _home_badge(z, k, b)

# A tap surface covering a vine region's whole zone: the polygon's bounding box, normalized by the
# region image size and mapped into the live map rect. Returns null when the region carries no polygon
# (the caller then falls back to the centroid disc). Mouse-ignored — the central router resolves the tap.
func _region_zone_hit(region, isize: Vector2) -> Control:
	if not (region is Dictionary):
		return null
	var pts: Array = (region as Dictionary).get("points", [])
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pts:
		if p is Array and (p as Array).size() >= 2:
			var v := Vector2(clampf(float(p[0]) / isize.x, 0.0, 1.0), clampf(float(p[1]) / isize.y, 0.0, 1.0))
			mn = mn.min(v); mx = mx.max(v)
	if mn.x > mx.x:
		return null
	var tl := _map_rect.position + mn * _map_rect.size
	var br := _map_rect.position + mx * _map_rect.size
	var node := Control.new()
	node.position = tl
	node.size = br - tl
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

# --- §16 mask-reveal home (any map that ships clean/broken/mask art) ----------------------

const _HOME_MASK_SHADER := "shader_type canvas_item;
uniform sampler2D mask;
void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= texture(mask, UV).a;
}"
var _home_mask: Shader

# The unified base layer for ANY map: a §16 overgrown-home base (broken art, clipped — the per-building
# mask reveals stack into the returned frame), else the map's own `bg`/convention art (cover-fit), else a
# flat fallback panel. Returns the clipped frame the §16 reveals attach to (null for the panel — only a
# §16 home needs it). `home` is {} for a map that ships no §16 home art.
func _build_map_base(z: int, home: Dictionary) -> Control:
	var vine = G.MAPS[z].get("vine", null)
	if typeof(vine) == TYPE_DICTIONARY:
		var vframe := _clip_frame()
		_add_cover_layer(vframe, String(vine.get("base", "")))      # clean base (e.g. map1.png)
		var Grove := load("res://games/grove/vine/vine_maps.gd")
		var regions: Array = Grove.regions_for(vine)
		# A registered map whose regions aren't authored yet shows its CLEAN base only — skip the overlay.
		# (VineMapView forces region_count to max(1), so a zero-region view would paint vines across the
		# whole mask, i.e. fully overgrown — the opposite of "clean base art".) The overlay appears once
		# the tool authors regions for this map.
		if regions.is_empty():
			return vframe
		var VineView := load("res://games/grove/vine/vine_map_view.gd")
		var view: Control = VineView.new()
		view.name = "VineMapView"
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.load_map(vine, regions)                                # sets size to image_size (for the tool's use)
		# the game seats the view full-rect over the clip frame; clear the image-size hint so the frame
		# (not the image) drives geometry — base cover layer + vine overlays then fill the SAME frame.
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.custom_minimum_size = Vector2.ZERO
		view.set_calm(FX.calm())
		# owned regions show clean (vines off); unowned show vines.
		for i in range(view.region_count()):
			var sid := "%s_r%d" % [String(G.MAPS[z].id), i]
			view.set_region_enabled(i, not spot_owned(sid))
		# the spot that's READY to claim (enough exp banked) is lit hotter than the other locked zones —
		# a stronger glow halo + denser, brighter vines — so the eye lands on the one you can restore now.
		var ready := G.map_next_unlock(z, unlocks)
		if int(ready.k) != -1 and Save.exp_total() >= int(ready.exp) and int(ready.k) < view.region_count():
			var rk := int(ready.k)
			view.write_shader_value("glow", "opacity", 0.6, rk)          # default 0.28 — a stronger highlight halo
			view.write_shader_value("glow", "glow_strength", 2.3, rk)    # default 1.15 — brighter
			view.write_shader_value("vines", "opacity", 0.9, rk)         # default 0.48 — denser vines
			view.write_shader_value("vines", "glow_strength", 1.1, rk)   # default 0.42 — hotter vine cores
			view.set_region_lock_alpha(rk, 0.75)                         # default 0.34 — the claimable zone's overall purple shape reads as a near-SOLID pane ready to shatter (75% — far more opaque than a locked zone), not a faded film
		vframe.add_child(view)
		return vframe
	var broken := String(home.get("broken", ""))
	if broken != "":
		var frame := _clip_frame()
		_add_fill_layer(frame, broken)                              # overgrown base
		return frame
	# a map may name its own `bg` (e.g. map1v2 base_empty); else the convention path.
	var art_path := String(G.MAPS[z].get("bg", Game.art("map/map_%s.png" % String(G.MAPS[z].id))))
	if ResourceLoader.exists(art_path):
		var frame := _clip_frame()
		_add_cover_layer(frame, art_path)
		return frame
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
	return null

# A clipped frame AT the map-art rect; layers fill it via full-rect anchors (cover/scale fit) so the
# painting + buildings stay locked together on any window aspect.
func _clip_frame() -> Control:
	var frame := Control.new()
	frame.position = _map_art_rect.position
	frame.size = _map_art_rect.size
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(frame)
	return frame

# The per-building mask data a §16 home ships (farm_home.json → {spot_id: {mask, pos, …}}); {} if absent.
func _home_buildings(home: Dictionary) -> Dictionary:
	var data = _read_json_file(String(home.get("data", "")))
	var by_id := {}
	if typeof(data) == TYPE_DICTIONARY:
		for b in data.get("buildings", []):
			by_id[String(b.get("spot", ""))] = b
	return by_id

# ONE §16 home spot at index k: owned → reveal the clean art through its baked mask (into `frame`) + an
# invisible tap marker carrying the inline customize strip; unowned → the ✿cost badge into the buy flow.
func _build_home_spot(z: int, k: int, home: Dictionary, frame: Control, by_id: Dictionary) -> Control:
	var sid := String(G.MAPS[z].spots[k].id)
	var b = by_id.get(sid, null)
	if not spot_owned(sid):
		return _home_badge(z, k, b)
	var mtex: Texture2D = load(Game.art("map/farm/" + String(b.get("mask", "")))) if b != null else null
	if mtex != null:
		# clean art, masked to THIS building. Guard the mask load: a null mask (e.g. a checkout that
		# hasn't re-imported the assets) must NOT fall back to a full-opaque reveal — that would clean
		# the WHOLE image off one restore. No mask → skip the reveal (stays overgrown).
		var rev := _add_fill_layer(frame, String(home.get("clean", "")))
		var mat := ShaderMaterial.new()
		mat.shader = _home_mask_shader()
		mat.set_shader_parameter("mask", mtex)
		rev.material = mat
	return _home_owned_item(z, k, b)

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

# An unlock-cost restore badge (item 3 — the farm_ui mockup's round dashed cream disc), centered on the
# building. An unowned spot shows badge_cost.png with a "+" stacked over the star cost "★ N". Built through
# the grove kit from the workbench-saved style (disc size + proportions), so a tweak there flows here.
# Rendered mouse-IGNORE to keep the map's single-input-surface invariant: the tap routes centrally via
# _map_tap → spot_hits → _on_spot_tap (the buy), exactly as the baked badge did. Kit missing → that fallback.
func _home_badge(z: int, k: int, b) -> Control:
	# The unowned-spot hit is now a transparent, mouse-ignored marker at the spot centroid. The
	# "locked" read is the region veil (VineMapView); restoring is driven by the SINGLE bottom
	# Unlock button (no per-spot cost disc any more). Kept as a sized hit so spot_hits stays
	# index-aligned and the central router can still route a tap to _on_spot_tap.
	var p = b.get("pos", [0.5, 0.5]) if b != null else [0.5, 0.5]
	var ctr := _map_rect.position + Vector2(float(p[0]), float(p[1])) * _map_rect.size
	var d := _map_rect.size.x * 0.16
	var node := Control.new()
	node.size = Vector2(d, d)
	node.position = ctr - Vector2(d, d) * 0.5
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

# Force a control subtree mouse-transparent — the map routes every spot tap through its single input
# surface, so any seated affordance (the kit unlock disc) must not eat the press before _map_tap.
func _force_ignore(n: Control) -> void:
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		if c is Control:
			_force_ignore(c)

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

func _read_json_file(path: String):
	if path == "" or not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

# The available area below the HUD and above the bottom chrome; the map image COVER-FILLS the full
# viewport at the design aspect, centered.
func _map_image_rect() -> Rect2:
	# The map canvas is a design-aspect rect that COVER-FILLS the viewport (like the board background),
	# CENTERED, so it always fills the screen edge-to-edge on any device — never letterboxing. On a window
	# TALLER than the design aspect (the common phone case: 19.5:9 vs the 9:16 canvas) the map fills the
	# height and overflows/crops left+right; on a WIDER window it fills the width and overflows top+bottom.
	# On the exact design aspect it fills the viewport exactly. Spots map to THIS rect, so the painting +
	# buildings stay locked together even where the art runs off-screen. HUD floats on top.
	return map_rect_for(get_viewport_rect().size, Design.aspect())

# Pure geometry for _map_image_rect (unit-tested): the smallest `aspect`-ratio rect that COVERS `view`,
# centered. Cover-fit (not inscribe) so the home fills the screen edge-to-edge and never letterboxes on
# an off-design device — the overflow spills off the LONGER axis (crop) rather than leaving empty bands:
# a taller-than-design window (phones) crops left/right, a wider one crops top/bottom. Matches the board.
static func map_rect_for(view: Vector2, aspect: float) -> Rect2:
	var w := maxf(view.x, view.y * aspect)
	var h := w / aspect
	return Rect2(((view - Vector2(w, h)) * 0.5).floor(), Vector2(w, h).floor())

func _map_placed_rect(_z: int, base: Rect2) -> Rect2:
	return base

# Add a full-rect, cover-fit, click-through TextureRect under `parent` (a map-rect frame). Used for the
# base background so layers share the exact same fit.
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
# sprout baked in) carries "N to restore this place" text in its upper body (NO inline icon — the pill
# art's baked flower is the single left mark) and a GREEN fill bar (pill_progress_fill.png) inside its
# lower groove, sized to restore-progress. The map NAME is dropped entirely. A fully-restored map shows
# the "restored ✿ 🎁" state and pays MAP_TASK_REWARD once. If the pill art is missing it degrades to the
# old dark plank look so the read never blanks.
const _PILL_ASPECT := 603.0 / 109.0
# the green groove rect inside pill_progress.png, as fractions of the pill size. Pixel-measured from the
# 603×109 art: the recessed channel's flat tan interior is x=37..500, y=74..86 (between the dark rim
# walls). The fill bar is sized to exactly this so it sits flush in the empty track.
const _PILL_GROOVE_X := 0.0614   # 37 / 603
const _PILL_GROOVE_W := 0.7695   # 464 / 603
const _PILL_GROOVE_Y := 0.6789   # 74 / 109
const _PILL_GROOVE_H := 0.1193   # 13 / 109

func _map_title_plank(z: int) -> Control:
	# the pill IS the restore read; a fully-unlocked map pays its unlock gift once — the gift rides the
	# pill's "restored" end-state (idempotent via a per-map flag, so revisiting never re-pays). NOTE: this
	# pill is DISABLED (see _build_map); the live trigger is _build_map's can_populate block.
	if G.can_populate(z, unlocks, _gates()):
		_maybe_show_unlock_reward(z)
	var pill_path := Look.kit("map/pill_progress.png")
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
	# the GREEN fill bar inside the groove, clipped to the restore progress fraction (claimed / total spots).
	var total: int = G.MAPS[z].spots.size()
	var owned := owned_count(z)
	var left := total - owned
	var frac := 1.0 if total <= 0 else clampf(float(owned) / float(total), 0.0, 1.0)
	if map_spots_done(z):
		frac = 1.0
	var fill_path := Look.kit("map/pill_progress_fill.png")
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
	# the text — "N to restore this place" (or "restored ✿ 🎁"), in the pill's UPPER body. pill_progress.png
	# already bakes a flower into its top-left, so we DON'T add an icon here — that flower IS the single
	# left mark (mockup: one flower + text). The number is now the count of UNCLAIMED spots (the single
	# bottom Unlock button carries the live per-spot exp requirement). The label fills the area to the
	# RIGHT of the baked flower and centers itself in that remaining span, so it never overlaps the flower.
	var lbl := Label.new()
	lbl.text = Strings.t("map.pill.restored") if map_spots_done(z) else Strings.t("map.pill.to_restore_this_place") % left
	lbl.add_theme_font_size_override("font_size", int(ph * 0.30 if map_spots_done(z) else ph * 0.28))
	# match the currency pill: dark INK + NO halo (panel-text law — the pill is a solid painted capsule).
	lbl.add_theme_color_override("font_color", INK)
	lbl.add_theme_constant_override("outline_size", 0)
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
		lbl.text = Strings.t("map.plank.restored")
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", STRAW)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plank.add_child(lbl)
	else:
		plank.add_child(_restore_left_row(G.MAPS[z].spots.size() - owned_count(z), STRAW, 22))
	return plank

# A code-drawn stand-in for an owned spot that ships no cutout art (the non-hub maps):
# a footprint-sized rounded tile in the map palette, centered on the plot exactly like
# the real sprite, with the spot's name. Honours the chosen variant wash + gem accent.
# Carries the "placeholder" meta so tests/tools can tell it from a real sprite.
func _placeholder_tile(spot: Dictionary, fs: float) -> Control:
	var tile := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CLAY.lerp(Color.WHITE, 0.18)
	sb.set_corner_radius_all(int(clampf(fs * 0.14, 12.0, 30.0)))
	sb.set_border_width_all(3)
	sb.border_color = BARK
	tile.add_theme_stylebox_override("panel", sb)
	tile.size = Vector2(fs, fs)
	tile.position = Vector2(90.0 - fs / 2.0, 60.0 - fs / 2.0)   # centered on the plot, like the real sprite
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.set_meta("placeholder", true)
	var lbl := Label.new()
	lbl.text = tr(spot.name)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 23)
	lbl.add_theme_color_override("font_color", INK)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_left = 12.0
	lbl.offset_top = 12.0
	lbl.offset_right = -12.0
	lbl.offset_bottom = -12.0
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(lbl)
	return tile

# One spot ON the map image: a code-generated placeholder tile when owned, else the
# price-pin + name.
func _make_spot(z: int, k: int, rect: Rect2) -> Control:
	var spot: Dictionary = G.MAPS[z].spots[k]
	# `pos` (center fraction of the map canvas) comes from grove_data.MAPS. No spot ships a
	# cutout: an owned spot draws a code-generated placeholder tile, an empty one the price-pin.
	var pos: Vector2 = rect.position + Vector2(spot.pos) * rect.size
	var fs_eff := 240.0 * (rect.size.x / Design.size().x)   # placeholder footprint, scaled from the design-width canvas
	var item := Control.new()
	item.size = Vector2(180, 150)
	item.position = pos - Vector2(90, 40)
	item.pivot_offset = Vector2(90, 50)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var owned := spot_owned(String(spot.id))
	if owned:
		# Owned spots draw a code-generated placeholder so the restored plot reads as filled.
		item.add_child(_placeholder_tile(spot, fs_eff))
	else:
		# Unowned spots show just their NAME centered under the plot — no per-spot cost chip. The
		# single bottom Unlock button is the restore CTA, gated by each spot's exp threshold.
		var stack := VBoxContainer.new()
		stack.anchor_left = 0.0
		stack.anchor_right = 1.0
		stack.offset_top = SPOT_NAME_DY
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_l := _lbl(tr(spot.name), 24, CREAM)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(name_l)
		item.add_child(stack)
	return item

# --- THE MAP-SELECT VIEW (grove_spec §3) ------------------------------------------------
# A clean atlas of every map as a card: thumbnail + name + state line. Tapping an
# unlocked card opens that map; a locked card wobbles. Lives under `content` —
# every child IGNOREs (single input surface).

func _build_select(animate := true) -> void:
	for c in content.get_children():
		c.queue_free()
	spot_hits.clear()
	select_hits.clear()
	var view := get_viewport_rect().size
	var top := 96.0 + Look.safe_top(self)
	# ONE wide painted card per row — a vista per place (map.png place-picker). No header: the HUD
	# wallet + the framed cards carry the read. The card SIZE is workbench-saved as a % of the screen
	# (card_w_frac of the screen width, card_h_frac of the screen height), tuned live in the kit. WIDTH and
	# HEIGHT are INDEPENDENT: width sets the side margins; height is honored as-is. The cards live in a
	# clipped band between the HUD and the floor back-arrow — when the stack fits it sits centered and
	# locked; when it overflows (tall cards) the band SCROLLS (drag / wheel), so height has no ceiling. The
	# band is the ONE input surface; cards are still hit-tested directly by their (scrolled) global rect.
	# NOTE: the gold frame STRETCH-scales, so a w:h far from the art's ~2.92 aspect distorts the border.
	var n := G.MAPS.size()
	# the place-picker card LOOK is the workbench-saved config, resolved ONCE for every card in this build
	var Kit: GDScript = load(KIT_PATH)
	var opts: Dictionary = Kit.map_card_opts_from_config(Kit.load_config(Kit.CONFIG_PATH)) if Kit != null else {}
	opts["calm"] = FX.calm()                                    # reduced-motion: freeze the active card's edge sparkle
	var w_frac: float = float(opts.get("card_w_frac", 0.96))    # card width  as a fraction of the screen width
	var h_frac: float = float(opts.get("card_h_frac", 0.16))    # card height as a fraction of the screen height
	var sep := 18.0
	var band_top := top + 16.0
	var band_bot := view.y - (Look.safe_bottom(self) + 150.0)   # leave the bottom-left back arrow its room
	var band_h := band_bot - band_top
	var card_w := view.x * w_frac                               # width is honored as-is — it sets the side margins
	var card_h := view.y * h_frac                               # height is honored as-is — the band scrolls if the stack overflows
	var total_h := card_h * float(n) + sep * float(maxi(n - 1, 0))
	var x := (view.x - card_w) * 0.5
	# the clipped scroll viewport is the FULL screen, so cards scroll off the real top/bottom edges
	# (passing behind the floating HUD + back arrow) instead of being cut mid-image at an interior band
	# line. Cards are still LAID OUT within the band (below the HUD, above the back arrow); only the clip
	# rect spans the whole view.
	var clip := Control.new()
	clip.position = Vector2.ZERO
	clip.size = view
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE                  # single-input-surface: taps pass through to `content`
	content.add_child(clip)
	_select_clip = clip
	# the first card rests TOP_PAD below the band top so it clears the settings gear; the stack then
	# scrolls if it overflows. y is in clip (= screen) coords: band_top + the in-band offset.
	var top_pad := 20.0
	var y0 := maxf(top_pad, (band_h - total_h) * 0.5)          # centered when it fits; TOP_PAD down once it scrolls
	_select_scroll_max = maxf(0.0, y0 + total_h - band_h)
	_select_scroll = clampf(_select_scroll, 0.0, _select_scroll_max)
	var y := band_top + y0
	for z in n:
		var card := _make_card(z, card_w, card_h, opts)
		card.position = Vector2(x, y - _select_scroll)
		card.size = Vector2(card_w, card_h)
		clip.add_child(card)
		select_hits.append({"node": card, "z": z, "y0": y})
		y += card_h + sep
	if _select_back != null and is_instance_valid(_select_back):
		_select_back.visible = true
	if animate:
		FX.pop_in(content)

# One map card, built from the SHARED kit (Kit.map_card) so the workbench tunes the SAME recipe the
# game renders. This resolves the per-card DATA from game state — OPEN → the locale art inside the gold
# frame + a "★ N left"/"restored" pill; LOCKED → the dark baked panel under an "after <prev>" line — and
# hands it the workbench-saved look `opts` (Kit.map_card_opts_from_config, resolved once per place-picker
# build in _build_select). `card_h` is always > 0 from _build_select. Every node IGNOREs the mouse.
func _make_card(z: int, card_w: float, card_h: float = 0.0, opts: Dictionary = {}) -> Control:
	var Kit: GDScript = load(KIT_PATH)
	if opts.is_empty():     # standalone callers (no _build_select context) resolve the saved look themselves
		opts = Kit.map_card_opts_from_config(Kit.load_config(Kit.CONFIG_PATH)) if Kit != null else {}
	var open := map_unlocked(z)
	var d := {
		"open": open,
		"done": map_spots_done(z),
		"art": _card_art_path(z) if open else "",     # painted thumbnail / §16 home clean art / "" → meadow fill
		"unlock_exp": G.spot_unlock_exp(z, maxi(0, G.MAPS[z].spots.size() - 1)),   # exp to fully restore this map
		"prereq": Strings.t("map.card.prereq") % tr(G.MAPS[maxi(z - 1, 0)].name),
		"map_id": String(G.MAPS[z].id),               # the §8 veil-art seam (map/veil_<id>.png)
	}
	return Kit.map_card(d, opts, card_w, card_h)

# The art that fills an open card: the map's own painted thumbnail (map_<id>.png), else its §16 home
# clean art (the hub's restored cottage), else "" → a code-drawn meadow fill.
func _card_art_path(z: int) -> String:
	var map_data: Dictionary = G.MAPS[z]
	var thumb_path := Game.art("map/map_%s.png" % String(map_data.id))
	if ResourceLoader.exists(thumb_path):
		return thumb_path
	var vine = map_data.get("vine", null)
	if typeof(vine) == TYPE_DICTIONARY:
		var base := String(vine.get("base", ""))
		if base != "" and ResourceLoader.exists(base):
			return base
	var home = map_data.get("home", null)
	if typeof(home) == TYPE_DICTIONARY:
		var clean := String(home.get("clean", ""))
		if clean != "" and ResourceLoader.exists(clean):
			return clean
	return ""

# A centered "✿ N to restore" status row (no star sprite — exp/level is the only currency now). `n`
# is the count of UNCLAIMED spots. Used by the (disabled) map title plank fallback. Mouse-IGNOREd.
func _restore_left_row(n: int, num_col: Color, px: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = Strings.t("map.restore_row.left") % n
	lbl.add_theme_font_size_override("font_size", px)
	lbl.add_theme_color_override("font_color", num_col)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	return row

# --- input: ONE surface, still-tap resolution ------------------------------------------

func _on_input(event: InputEvent) -> void:
	# place-picker scroll — only when the stack overflows the band. A drag/wheel pans the cards; the
	# 18 px still-tap window below then disqualifies the release as a tap, so scroll never opens a card.
	if _view == "select" and _select_scroll_max > 0.0:
		if event is InputEventScreenDrag:
			_scroll_select_by(-event.relative.y)
			return
		if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_scroll_select_by(-event.relative.y)
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_select_by(90.0)
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_select_by(-90.0)
			return
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
				Strings.t("map.select.locked_prereq") % tr(G.MAPS[maxi(z - 1, 0)].name), Color(CREAM, 0.9), 28)
		return

# Pan the place-picker stack by `dy` px, clamped to [0, _select_scroll_max], and slide every card to its
# scrolled position (clip-local y0 − scroll). No-op when the stack fits (_select_scroll_max == 0).
func _scroll_select_by(dy: float) -> void:
	var prev := _select_scroll
	_select_scroll = clampf(_select_scroll + dy, 0.0, _select_scroll_max)
	if is_equal_approx(_select_scroll, prev):
		return
	for hit in select_hits:
		var c: Control = hit.node
		if is_instance_valid(c):
			c.position.y = float(hit.y0) - _select_scroll

func _map_tap(gpos: Vector2) -> void:
	# §1 residents are welcomed via the Residents shop dialog now (not an on-map panel), so taps resolve
	# straight to spots / wandering spirits.
	for hit in spot_hits:
		var n: Control = hit.node
		if n.get_global_rect().grow(8.0).has_point(gpos):
			_on_spot_tap(int(hit.z), int(hit.k), n, gpos)
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

# --- buying a spot, right on the map image -----------------------------------------------

# Restore (claim) a spot. FREE — total exp is never spent; the spot just becomes claimable once
# exp reaches its threshold. Driven by the bottom Unlock button (and a direct spot tap, harmless
# since thresholds are monotonic). A below-threshold call wobbles + shows the exp still needed.
func _on_spot_tap(z: int, k: int, node: Control, at: Vector2) -> void:
	var spot: Dictionary = G.MAPS[z].spots[k]
	if spot_owned(String(spot.id)):
		return                                # an already-restored spot is inert (no customization)
	var need := G.spot_unlock_exp(z, k)
	if Save.exp_total() < need:
		Audio.play("invalid_soft", -4.0)
		FX.wobble(node)
		FX.floating_text(self, at - Vector2(110, 64), Strings.t("map.spot.needs_exp") % need, Color(CREAM, 0.9), 30)
		return
	unlocks[String(spot.id)] = true
	FX.burst(self, at, STRAW, 18)
	Audio.play("level_complete", -6.0, 1.2)
	# the garden's givers re-meter to the next unlock after a purchase (§7 — water comes from
	# level-ups, not a per-spot gift)
	FX.floating_text(self, at - Vector2(160, 96), Strings.t("map.spot.new_asks_in_garden"), CREAM, 30)
	_persist()
	# Spots-done completion — recorded SYNCHRONOUSLY (before the async veil FX below) so the gate
	# advance + map reward never depend on FX timing. Completing the map's spots IS the completion
	# record (the gate quest is retired): append z to `gates` so `map_complete`/`frontier_map`
	# advance and the next map unlocks.
	if map_spots_done(z):
		Save.add_diamonds(G.MAP_DIAMONDS)
		Vault.skim(G.MAP_DIAMONDS)            # T44 SKIM-SITE 2/3 (map-restore): the piggy bank skims a slice of the restore premium (§10)
		if not G.gate_recorded(_gates(), z):     # int-tolerant: a reloaded gate is a JSON float (0.0)
			var gg := Save.grove()
			var gl: Array = gg.get("gates", [])
			gl.append(z)
			gg["gates"] = gl
			Save.grove_write()
		FX.celebrate_at(self, get_global_rect().get_center(), Strings.t("map.spot.map_restored") % tr(G.MAPS[z].name), STRAW)
		FX.floating_reward(self, get_global_rect().get_center() + Vector2(-60, 70),
			"gem", G.MAP_DIAMONDS, Color("#BFE6F2"), 38)
		Audio.play("level_complete", -2.0)
	# Break the purple lock veil with a glass-shatter from the tap point. Snapshot the veil's
	# true (masked) shape BEFORE the rebuild hides it, rebuild, then spawn the shards on top.
	var veil := {}
	if not FX.calm():
		var vv = content.find_child("VineMapView", true, false)
		if vv != null:
			veil = await _capture_region_veil(vv, k)
	_build_map(false)                     # rebuild IN PLACE (no whole-map pop-in) — only the veil should break
	if not veil.is_empty():
		FX.shatter_veil(self, veil["tex"], veil["bbox"], at - get_global_rect().position)
	_update_hud()

# Snapshot the still-visible purple lock veil for region `k` into a texture, in self-local pixels.
# The lock shader rendered alone in a transparent SubViewport reproduces the exact on-screen masking
# (cover-fit + mask offset), so the snapshot matches where the veil sits. Returns {tex, bbox}, or {}
# if the veil isn't present. Async — the SubViewport needs a frame to render.
func _capture_region_veil(view: Variant, k: int) -> Dictionary:
	if view == null or k < 0 or k >= view.region_overlays.size():
		return {}
	var lock := view.region_overlays[k].get("lock") as TextureRect
	if lock == null or not lock.visible:
		return {}
	var vsize := Vector2i(get_global_rect().size)
	if vsize.x < 4 or vsize.y < 4:
		return {}
	var sv := SubViewport.new()
	sv.size = vsize
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var dup := lock.duplicate() as TextureRect
	var dmat := (lock.material as ShaderMaterial).duplicate() as ShaderMaterial
	dmat.set_shader_parameter("region_enabled", 1.0)
	# The shards carry this snapshot's alpha. The live veil sits semi-transparent, so capture it at a
	# crisp opacity here — otherwise the breaking glass reads as a faint purple smear.
	var vtc: Color = dmat.get_shader_parameter("tint_color")
	dmat.set_shader_parameter("tint_color", Color(vtc.r, vtc.g, vtc.b, SHATTER_VEIL_ALPHA))
	dup.material = dmat
	dup.visible = true
	dup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sv.add_child(dup)
	add_child(sv)
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = sv.get_texture().get_image()
	sv.queue_free()
	if img == null:
		return {}
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()       # native opaque-bounds (C++) — NOT a per-pixel GDScript scan
	if used.size.x < 2 or used.size.y < 2:
		return {}
	return {"tex": ImageTexture.create_from_image(img), "bbox": Rect2(used)}

# --- §1 residents: WELCOMING spirits home (the population sub-game) ----------------------
# On a COMPLETED map the player WELCOMES wandering spirits via the Residents shop dialog
# (_open_residents_shop, opened from the bottom-nav Residents button). G.welcome_resident spends +
# adds + silently auto-merges two-of-a-kind; the roster is the source of truth and the population
# layer is rebuilt from it on each buy. (The old always-on bottom panel was retired for the shop.)

# --- HUD & chrome -----------------------------------------------------------------------

func _build_hud() -> void:
	# the shared top bar (owner: one module — ★🪙💎 + Store + the S10 Lv chip
	# never move between scenes; the chip ticks via the module's refresh). The home
	# screen is the hub itself, so it does NOT pass `home` — the HUD's home chip is
	# redundant here and the level ring stands alone (item 2; the board still passes
	# `home` since its nav legitimately returns to the map).
	var hud := Hud.build(self, {
		# the water pill's + opens the water stall here too (no live board on the hub, so both refills
		# write Save's water; the board reads it on open). `water_grant` = the 💎 fill (top to cap).
		"water_grant": func() -> void:
			var g := Save.grove()
			g["water"] = G.WATER_CAP
			Save.grove_write(),
		# the FREE refill — pour a full can ON TOP of the saved water (ADDITIVE, over-cap ok; the board
		# reads the banked water on its next open). Gated the free-refill card on in the water stall.
		"water_add": func() -> void:
			var g := Save.grove()
			g["water"] = int(g.get("water", G.WATER_CAP)) + G.WATER_CAP
			Save.grove_write(),
		# tap the level badge -> the level screen (stars earned / needed for the next level)
		"on_level": func() -> void: LevelPopup.open(self),
		# Settings is the top-right gear in the shared HUD — the SAME button + spot the board uses, so the
		# gear sits in one place across both screens (off the LiveOps rail now).
		"settings": func() -> void:
			Audio.play("button_tap", -2.0)
			_open_settings()})
	coins_label = hud.coins
	level_label = hud.level
	_hud_refresh = hud.refresh
	_gear = hud.gear                 # the top-right settings tile — the live-ops rail hangs beneath it
	_open_shop = hud.open_premium    # generic "open the shop" → the premium (acorn) stall
	_hud_panels = [hud.wallet, hud.lv_panel]
	_shop_btn = hud.gem_plus         # the Welcome gift lives in the premium stall now → the badge rides the GEM pill's "+"

func _update_hud() -> void:
	if _hud_refresh.is_valid():
		_hud_refresh.call()              # wallet (Water·Coin·Gem) + the S10 level chip (ticks)
	else:
		coins_label.text = str(Save.coins())
	_refresh_play_cta()

# Is the open map's next spot affordable right now? Drives the merged Play/Restore CTA's state.
func _unlock_ready() -> bool:
	var nxt := G.map_next_unlock(_map_idx, unlocks)
	return int(nxt.k) != -1 and Save.exp_total() >= int(nxt.exp)

# The bottom-right CTA is MERGED: PLAY by default (the board+acorn mark → the board), and RESTORE when the
# open map's next spot is affordable — the SAME orange play disc, but wearing the ui_asset3 vine mark and
# tapping into the unlock (_on_unlock_pressed). Called on build + map open + any exp/owner change (via
# _update_hud), so it flips the instant a spot becomes affordable. Updates the disc IN PLACE — swaps the
# icon + repoints the press — so the breathing tween carries across the flip (no rebuild).
func _refresh_play_cta() -> void:
	if _play_btn == null or not is_instance_valid(_play_btn):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return
	var ready := _unlock_ready()
	var wrap := _play_btn.get_meta("icon_wrap", null) as Control
	if wrap != null:
		for c in wrap.get_children():
			c.queue_free()
		var HC: GDScript = load(HOME_CHROME_PATH)
		var icon_node: Control = Kit.make_icon(HC.ICON_PLAY_RESTORE if ready else HC.ICON_PLAY, float(_play_btn.get_meta("icon_px", 96.0)))
		if icon_node != null:
			wrap.add_child(icon_node)
	# re-point the tap: RESTORE the next spot when affordable, else into the garden/board.
	for conn in _play_btn.pressed.get_connections():
		_play_btn.pressed.disconnect(conn["callable"])
	_play_btn.pressed.connect(_on_unlock_pressed if ready else _on_board)

func _on_unlock_pressed() -> void:
	var z := _map_idx
	var nxt := G.map_next_unlock(z, unlocks)
	if int(nxt.k) == -1 or Save.exp_total() < int(nxt.exp):
		return
	var k := int(nxt.k)
	var node: Control = self
	var at := get_global_rect().get_center()
	for hit in spot_hits:
		if int(hit.z) == z and int(hit.k) == k:
			node = hit.node
			at = (hit.node as Control).get_global_rect().get_center()
			break
	_on_spot_tap(z, k, node, at)

func _build_chrome() -> void:
	# The home/map bottom nav is the SAME shared global row the board uses (ui/nav_bar.gd), at the SAME
	# board sizing — side buttons 140, the centred primary (Play) 184 — so the two screens' bottom bars
	# match. Order: Map · Play. PLAY is the way into the garden/board (the prominent leaf). Shop + Settings
	# left the bottom bar (shop opens from the top pills' "+", Settings is the top-right gear); the Piggy
	# bank moved to the LiveOps side rail (_build_liveops_rail).
	var sb := Look.safe_bottom(self)
	# The flanking Map button is the SHARED configurable home button in its ROUNDED-RECT form (icon + "Map"
	# label inside the badge — ui_mock2); Play is the big CIRCULAR orange CTA (the only round bottom button).
	var nav := NavBar.build(self, [
		# Map — the place-picker (atlas). A labeled rounded-rect badge (built via `make` to pass shape:"rect").
		{"make": _make_map_button, "label": Strings.t("map.nav.map")},
		# Residents — the resident roster shop (only on a fully-unlocked map; hidden otherwise).
		{"make": _make_residents_button, "label": Strings.t("map.nav.residents")},
		# Play — the way into the garden/board. The big orange play disc (board+acorn mark, no label).
		{"make": _make_play_button, "label": Strings.t("map.nav.play")}])
	for b in nav.buttons:
		_chrome_nodes.append(b)
	_chrome_nodes.append(nav.row)
	_refresh_play_cta()                  # confirm the merged CTA's Play↔Restore state for the open map
	# the Play disc breathes so the primary action reads — kept whether it shows board or vine. (Target by
	# identity, not nav index: the Residents button shifts Play's position in the row.)
	if is_instance_valid(_play_btn):
		FX.breathe_once(_play_btn)
	# The premium (gem) pill's top-right "new offer" red dot was REMOVED by request — the gem stall no
	# longer wears a corner badge. `_store_badge` stays null, so `_refresh_store_badge` is a safe no-op.
	# the LiveOps rail: Daily · Free · Vault · Inbox, pinned TOP-right below the wallet (home.png). The Piggy
	# bank lives here now (moved off the bottom bar); its claimable ready-pip is attached there.
	_build_liveops_rail()
	# the place-picker's bottom-left BACK arrow (map.png) — returns to the map you were viewing. A real
	# Button on `self` (chrome), NOT under the content input surface; hidden on a map, shown in select.
	_select_back = _make_back_button(sb)
	add_child(_select_back)
	_select_back.visible = false

# The Map button (bottom nav, index 0) — opens the place-picker. The shared home button in its ROUNDED-RECT
# form: the ui_asset2 badge with the map icon over a "Map" label, both inside the badge (ui_mock2).
func _make_map_button() -> Button:
	var open := func() -> void:
		Audio.play("button_tap", -2.0)
		_open_select()
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return NavBar._make_nav_button("nav_map.png", 140.0, open)   # defensive: the baked map disc
	var opts: Dictionary = Kit.home_button_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	opts["px"] = 140.0
	opts["shape"] = "rect"                    # the rounded-rect badge (not a disc)
	opts["calm"] = FX.calm()
	var HC: GDScript = load(HOME_CHROME_PATH)
	return Kit.home_button({"icon": HC.ICON_MAP, "caption": Strings.t("map.nav.map"), "action": open}, opts)

# The Residents button (bottom nav, between Map and Play) — opens the resident roster shop. Built like the
# Map button (rounded-rect badge, shape:"rect"), carrying the "house" icon (residence → residents) + a
# "Residents" caption. Hidden until the open map is fully unlocked (G.can_populate); a hidden child collapses
# out of the nav HBox, so an incomplete map shows just [Map, Play].
func _make_residents_button() -> Button:
	var open := func() -> void:
		Audio.play("button_tap", -2.0)
		_open_residents_shop(_map_idx)
	var Kit: GDScript = load(KIT_PATH)
	var b: Button
	if Kit == null:
		b = NavBar._make_nav_button("nav_residents.png", 140.0, open)   # defensive: glyph/png fallback
	else:
		var opts: Dictionary = Kit.home_button_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
		opts["px"] = 140.0
		opts["shape"] = "rect"
		opts["calm"] = FX.calm()
		var HC: GDScript = load(HOME_CHROME_PATH)
		b = Kit.home_button({"icon": HC.ICON_RESIDENTS, "caption": Strings.t("map.nav.residents"), "action": open}, opts)
	_residents_btn = b
	_refresh_residents_btn()
	return b

# Show the Residents button only when the open map is fully unlocked (same gate as the population layer).
func _refresh_residents_btn() -> void:
	if _residents_btn != null and is_instance_valid(_residents_btn):
		_residents_btn.visible = G.can_populate(_map_idx, unlocks, _gates())

# The residents SHOP: the roster as a shop-style dialog (one cell per offered resident — spirit icon, name,
# cost). Buying welcomes a t1 (G.welcome_resident: spend → add → auto-merge), then rebuilds the population
# layer and refreshes the shop's affordability in place. Built over a veil overlay with the shared Kit
# shop_dialog chrome — the same frame the coin/gem store wears.
func _open_residents_shop(z: int) -> void:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return
	var overlay := Control.new()
	overlay.name = "ResidentsShopOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)
	var width: float = minf(get_viewport_rect().size.x * 0.92, 520.0)
	# rebuild closure: clears + rebuilds the storefront so a buy refreshes affordability in place.
	var rebuild := {"fn": Callable()}
	rebuild.fn = func() -> void:
		if not is_instance_valid(cc):
			return
		for c in cc.get_children():
			c.queue_free()
		var cards: Array = []
		for cd in G.residents_shop_cards(z):
			var id := String(cd.id)
			cards.append({
				"node": _spirit_icon(id, width / 3.0 * 0.52),
				"label": tr(String(cd.name)),
				"price": str(int(cd.cost)),
				"price_icon": ("gem" if String(cd.currency) == "diamonds" else "coin"),
				"affordable": bool(cd.affordable),
				"on_buy": func() -> void: _buy_resident(z, id, rebuild.fn),
			})
		var sopts: Dictionary = Kit.shop_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
		sopts["banner_text"] = Strings.t("map.welcome.title")
		sopts["on_close"] = func() -> void: overlay.queue_free()
		if float(sopts.get("list_max_h", 0)) <= 0.0:
			sopts["list_max_h"] = get_viewport_rect().size.y * 0.72
		var dialog: Control = Kit.shop_dialog([{"caption": "", "cards": cards}], width, sopts)
		cc.add_child(dialog)
		FX.pop_in(dialog)
	rebuild.fn.call()

# Buy one resident from the shop: welcome (spend + add + auto-merge), rebuild the population layer + refresh
# the open shop, and play the warm success / merge / can't-afford feedback (the old panel's feel).
func _buy_resident(z: int, type_id: String, refresh: Callable) -> void:
	var res := G.welcome_resident(z, type_id)
	if not bool(res.get("ok", false)):
		Audio.play("invalid_soft", -4.0)
		FX.floating_text(self, get_global_rect().get_center() - Vector2(0, 40),
			Strings.t("map.welcome.not_enough"), Color(CREAM, 0.9), 26)
		return
	Audio.play("level_complete", -6.0, 1.15)
	_build_map()
	_update_hud()
	if refresh.is_valid():
		refresh.call()
	var events: Array = res.get("events", [])
	if not events.is_empty():
		var amb: Control = content.get_node_or_null("AmbientLayer")
		Ambient.merge_poof(amb, events.size())
		Audio.play("tidy_poof", -2.0, 1.1)
		FX.floating_text(self, get_global_rect().get_center() - Vector2(0, 40),
			Strings.t("map.welcome.two_became_one"), CREAM, 26)
	else:
		FX.floating_text(self, get_global_rect().get_center() - Vector2(0, 40),
			Strings.t("map.welcome.new_friend"), STRAW, 26)

# The Play button (bottom nav, index 1) — the home screen's primary CTA, and the MERGED restore button: the
# big ORANGE play disc (ui_asset2 play_disc), CAPTIONLESS. It wears the board+acorn mark and taps into the
# board by default, but flips to the ui_asset3 VINE mark + the restore action the moment the open map's next
# spot is affordable (_unlock_ready). _refresh_play_cta swaps the icon/action in place; the disc breathes in
# either state. Stored in _play_btn so the refresh can find it.
func _make_play_button() -> Button:
	var ready := _unlock_ready()
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return NavBar._make_nav_button("nav_leaf.png", 188.0, _on_board)   # defensive: the baked leaf pill
	var opts: Dictionary = Kit.home_button_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	opts["px"] = float(opts.get("play_px", 188))   # the workbench-tuned Play-disc size (bigger than the 140 Map badge)
	var HC: GDScript = load(HOME_CHROME_PATH)
	opts["shell"] = HC.PLAY_SHELL             # the orange play disc (no green tint — the art carries the colour)
	opts["icon_scale"] = 0.52                 # the centred mark (board+acorn, or the vine when a restore is ready)
	opts["calm"] = FX.calm()
	var action: Callable = _on_unlock_pressed if ready else _on_board
	_play_btn = Kit.home_button({"icon": (HC.ICON_PLAY_RESTORE if ready else HC.ICON_PLAY), "caption": "", "action": action}, opts)
	return _play_btn

# The place-picker's bottom-left BACK button. It is the SAME shared home button (Kit.home_button) the
# bottom nav + the live-ops rail build from, in its ROUNDED-RECT form (shape:"rect") — matching the Map
# button — so a button tweak (size · shell · icon scale · polish) flows here too. It just carries the
# back-arrow icon (CARD_BACK, outside the icon_<id> convention → passed as icon_rel) and no caption.
# Pinned bottom-left; its press returns to the last-viewed map. Falls back to a bare square when the kit can't load.
func _make_back_button(sb: float) -> Button:
	var px := _rail_px                       # the workbench-saved button size (shared with the rail + nav)
	var back := func() -> void:
		Audio.play("button_tap", -4.0)
		_open_map(_map_idx)
	var Kit: GDScript = load(KIT_PATH)
	var b: Button
	if Kit != null:
		var opts := _home_opts.duplicate()
		opts["shape"] = "rect"               # the rounded-rect badge, matching the Map button (no longer a disc)
		b = Kit.home_button({"icon_rel": CARD_BACK, "caption": "", "action": back}, opts)
	else:
		b = Button.new()                     # defensive fallback (kit absent): a bare square
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(px, px)
		Look.add_press_juice(b)
		b.pressed.connect(back)
	b.anchor_left = 0.0
	b.anchor_right = 0.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = 22.0
	b.offset_right = 22.0 + px
	b.offset_bottom = -(sb + 30.0)
	b.offset_top = b.offset_bottom - px
	return b

# The LIVE-OPS RAIL — a CALM vertical column of rounded-rect badge tiles pinned TOP-RIGHT, below the
# wallet pill (home.png): Daily · Vault · (guarded) Inbox. Each is the SHARED configurable home button
# in its rect form (Kit.home_button shape:"rect" — the SAME cream/gold badge + icon the bottom nav uses,
# tuned in the workbench) with its label INSIDE the tile; the RED BADGE does all the attention-pulling,
# shown ONLY when actionable (today unclaimed / vault claimable / unread mail — the mail badge shows the count).
# Tiles are sized by the saved config (default 140, scaled by RAIL_SCALE), matching the bottom bar. Every button is appended to _chrome_nodes so it
# follows _set_map_chrome_visible (hidden on the place-picker).
const RAIL_PX := 140.0          # fallback disc size — matches the bottom-bar side buttons
const RAIL_MARGIN := 18.0       # right-edge inset
const RAIL_CAP_H := 10.0        # gap band beneath each tile (captions now sit INSIDE the rect badge, so this is just spacing)
const RAIL_GAP := 8.0           # gap between stacked entries (tightened so the rail reads as one tidy column)
const RAIL_TOP := 210.0         # first disc sits this far below the safe-top (clear of the wallet pill)
const RAIL_SCALE := 0.80        # the rail discs are SMALLER than the shared home-button size (nav + back stay full)
var _home_opts := {}            # the shared home-button style (loaded once per rail build)
var _rail_px := RAIL_PX         # the shared home-button size (drives the place-picker back button; full size)
var _rail_disc_px := RAIL_PX    # the rail's OWN reduced disc size (RAIL_SCALE × shared) — smaller than the nav
var _rail_opts := {}            # _home_opts with px overridden to _rail_disc_px (the rail discs only)

func _build_liveops_rail() -> void:
	# Load the shared home-button style ONCE (the same transform the bottom nav + workbench read).
	var Kit: GDScript = load(KIT_PATH)
	_home_opts = Kit.home_button_opts_from_config(Kit.load_config(Kit.CONFIG_PATH)) if Kit != null else {}
	_home_opts["calm"] = FX.calm()
	_rail_px = float(_home_opts.get("px", RAIL_PX))
	# the rail discs are smaller than the shared nav/back size, and packed closer (RAIL_GAP) — a tidier column.
	_rail_disc_px = round(_rail_px * RAIL_SCALE)
	_rail_opts = _home_opts.duplicate()
	_rail_opts["px"] = _rail_disc_px
	_rail_opts["shape"] = "rect"   # the rail tiles are ROUNDED-RECT badges (icon over label inside), not discs (ui_mock2)
	# the workbench-tuned badge offset (px past the disc's top-right): pulls the red dot / count snug to the
	# rail disc instead of floating off its transparent art margin (negative tucks it IN over the edge).
	var bover := Vector2(float(_home_opts.get("badge_dx", -26.0)), float(_home_opts.get("badge_dy", -26.0)))
	# the workbench-tuned badge SIZE (dot diameter / count font) — the same opts the home-button preview uses.
	var bopts := {"dot_px": int(_home_opts.get("badge_dot_px", 14)), "num_size": int(_home_opts.get("badge_num_size", 14))}
	var step := _rail_disc_px + RAIL_CAP_H + RAIL_GAP
	# the rail hangs directly beneath the settings gear (top-aligned with the wallet), one inter-tile gap
	# below it — so the gear + the rail read as ONE top-aligned right column. The gear box matches the rail
	# disc size (both RAIL_SCALE × the home button), so the spacing is even. Fallback: the old fixed inset.
	var top := (_gear.offset_bottom + RAIL_CAP_H + RAIL_GAP) if (_gear != null and is_instance_valid(_gear)) \
		else (Look.safe_top(self) + RAIL_TOP)
	var slot := 0
	# Daily — opens the login calendar on demand; badge when today is unclaimed.
	var HC: GDScript = load(HOME_CHROME_PATH)
	var daily := _rail_button(HC.ICON_DAILY, Strings.t("map.rail.daily"), _open_daily)
	_place_rail(daily, top, slot, step); slot += 1
	_daily_badge = Look.badge("dot", 0, bopts)
	Look.attach_badge(daily, _daily_badge, bover)
	# (The free "Free" gem faucet moved off the rail into the premium/acorn shop — its lead card.
	#  See shop.gd `_free_gems_card`. The rail is the navigation/liveops column only now.)
	# Vault — the diegetic piggy bank, moved here from the bottom bar. Its claimable ready-pip lights when
	# Vault.claimable() (driven by _refresh_piggy_pip).
	var piggy := _rail_button(HC.ICON_VAULT, Strings.t("map.rail.vault"), _open_vault)
	_place_rail(piggy, top, slot, step); slot += 1
	_piggy_pip = Look.badge("dot", 0, bopts)
	Look.attach_badge(piggy, _piggy_pip, bover)
	_refresh_piggy_pip()
	# Inbox — GUARDED: only built when the parallel inbox system exists in this build (load() runtime).
	if _has_inbox:
		var inbox := _rail_button(HC.ICON_INBOX, Strings.t("map.rail.inbox"), _open_inbox)
		_place_rail(inbox, top, slot, step); slot += 1
		_inbox_badge = Look.badge("pill", 0, bopts)
		Look.attach_badge(inbox, _inbox_badge, bover)
	# (Settings is NOT on the rail — it is the shared top-right HUD gear now, the same button + spot the
	# board uses. See the Hud.build `settings` opt above.)
	_refresh_liveops_badges()

# One rail button = the SHARED configurable home button (Kit.home_button): the cream/gold disc + icon +
# caption tab, tuned in the workbench. `sparkle` opts the disc into the engine-drawn glow/twinkle. Falls
# back to a plain cream disc when the kit can't load. Parented to self + tracked as chrome.
func _rail_button(icon_id: String, label: String, cb: Callable, sparkle := false) -> Button:
	var Kit: GDScript = load(KIT_PATH)
	var b: Button
	if Kit != null:
		b = Kit.home_button({"icon": icon_id, "caption": label, "action": cb, "sparkle": sparkle}, _rail_opts)
	else:
		b = Button.new()                          # defensive fallback (kit absent): a bare disc
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(_rail_disc_px, _rail_disc_px)
		b.pressed.connect(cb)
	add_child(b)
	_chrome_nodes.append(b)
	return b

# Pin a rail button to the TOP-right edge, stacked DOWNWARD (slot 0 highest) from `top` px below the
# safe-top. The caption tab overflows into the `step` gap beneath each disc.
func _place_rail(b: Button, top: float, slot: int, step: float) -> void:
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 0.0
	b.anchor_bottom = 0.0
	b.offset_right = -RAIL_MARGIN
	b.offset_left = -RAIL_MARGIN - _rail_disc_px
	b.offset_top = top + slot * step
	b.offset_bottom = b.offset_top + _rail_disc_px

# Light each rail badge ONLY when its surface is actionable (the calm rule: the badge pulls, not the
# button). Daily = today unclaimed; Inbox = unread count (guarded).
func _refresh_liveops_badges() -> void:
	if _daily_badge != null and is_instance_valid(_daily_badge):
		_daily_badge.visible = not Login.claimed_today()
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

# Inbox rail tap (GUARDED): open the parallel mailbox modal via load() so this worktree never hard-
# depends on a system it doesn't own. A claim's refresh hook re-reads the wallet + unread badge (Save
# has no change signal — the HUD is pull-based), mirroring the daily calendar's refresh.
# Server-driven mail: top up the mailbox from the remote feed (core/inbox_sync.gd), relighting the
# inbox badge if anything new arrived. Flag-gated + guarded + non-blocking; sync() itself skips the
# network when the box is already full ("clear old ones first"). Fires on home open + every MAIL_SYNC_EVERY.
const MAIL_SYNC_EVERY := 600.0          # 10 min — the in-session mail poll cadence
func _sync_mail() -> void:
	if not (_has_inbox and Features.on("mail_sync")):
		return
	if not ResourceLoader.exists("res://engine/scripts/core/inbox_sync.gd"):
		return
	load("res://engine/scripts/core/inbox_sync.gd").sync(self, func(added: int) -> void:
		if added > 0:
			_refresh_liveops_badges())

func _open_inbox() -> void:
	if not _has_inbox:
		return
	Audio.play("button_tap", -2.0)
	load("res://engine/scripts/ui/inbox.gd").open(self, {"refresh": func() -> void:
		_update_hud()
		_refresh_liveops_badges()})
	# refresh deferred so a modal that grants on open settles before we re-read the count
	_refresh_liveops_badges.call_deferred()

# One-time map-UNLOCK celebration. Grants the scaled reward (coins + gems + free signature spirit) via the
# model the instant the map first completes (robust to interruption — the grant is committed before any
# UI), then reveals it in a parchment dialog. Idempotent: claim_unlock_reward returns {} after the first
# time, so a revisit shows nothing. Safe in headless rebuilds (the dialog is deferred + tree-guarded).
func _maybe_show_unlock_reward(z: int) -> void:
	var rew: Dictionary = G.claim_unlock_reward(z)
	if rew.is_empty():
		return
	_update_hud()
	if not is_inside_tree():
		return
	_show_unlock_dialog.call_deferred(z, rew)

func _show_unlock_dialog(z: int, rew: Dictionary) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var coins := int(rew.get("coins", 0))
	var gems := int(rew.get("gems", 0))
	var spirit := String(rew.get("spirit", ""))
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		_task_reward_fx(coins, gems)          # defensive: at least play the float FX if the kit is absent
		return
	var overlay := Control.new()
	overlay.name = "UnlockRewardOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dismiss := func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
		_task_reward_fx(coins, gems)
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			dismiss.call())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	if coins > 0:
		col.add_child(_reward_row(Look.icon("coin", 44.0), Strings.t("map.unlock.coins"), "+%d" % coins))
	if gems > 0:
		col.add_child(_reward_row(Look.icon("gem", 44.0), Strings.t("map.unlock.diamonds"), "+%d" % gems))
	if spirit != "":
		col.add_child(_reward_row(_spirit_icon(spirit, 44.0), _resident_name(z, spirit), "+1"))
	var collect: Button = Kit.pill_button(Strings.t("map.unlock.collect"), {"bg": "green", "font": 22})
	collect.pressed.connect(func() -> void: dismiss.call())
	var btn_wrap := CenterContainer.new()
	btn_wrap.add_child(collect)
	col.add_child(btn_wrap)
	var width: float = minf(get_viewport_rect().size.x * 0.86, 520.0)
	var opts := {"banner_text": Strings.t("map.unlock.title"), "banner_icon_on": false}
	opts["on_close"] = func() -> void: dismiss.call()
	var dialog: Control = Kit.dialog_frame(col, width, opts)
	cc.add_child(dialog)
	FX.pop_in(dialog)

# A fixed-size resident icon: the type's art when present, else a soft cream disc (signature spirits ship
# without art yet — this keeps the row reading as "a spirit" rather than a broken/empty box).
func _spirit_icon(type_id: String, px: float) -> Control:
	var path := G.resident_art(type_id)
	if path != "" and ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.custom_minimum_size = Vector2(px, px)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	var disc := Panel.new()
	disc.custom_minimum_size = Vector2(px, px)
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(STRAW, 0.9)
	ds.set_corner_radius_all(int(px / 2.0))
	disc.add_theme_stylebox_override("panel", ds)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return disc

# The resident's localized display name for map z (falls back to the raw id if unlisted).
func _resident_name(z: int, type_id: String) -> String:
	for td in G.resident_lines(z):
		if String(td.id) == type_id:
			return tr(String(td.name))
	return type_id

# One reward-reveal row: [icon] · label (expands) · amount (right). Used by the unlock dialog.
func _reward_row(icon: Control, label: String, amount: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	var a := Label.new()
	a.text = amount
	a.add_theme_font_size_override("font_size", 22)
	a.add_theme_color_override("font_color", Color(BARK, 0.95))
	a.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(a)
	return row

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
	FX.floating_text(self, at - Vector2(0, 40), Strings.t("map.reward.place_restored"), CREAM, 24)
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
	# cracking grants gems (Vault.crack → Save.add_diamonds) — re-read the wallet too, not just the
	# ready-pip (Save has no change signal; the HUD is pull-based), mirroring _open_daily.
	VaultUI.open(self, {"refresh": func() -> void:
		_update_hud()
		_refresh_piggy_pip()})

# Light the piggy ready-pip iff the jar has banked past the claim threshold (Vault.claimable()).
func _refresh_piggy_pip() -> void:
	if _piggy_pip != null and is_instance_valid(_piggy_pip):
		_piggy_pip.visible = Vault.claimable()

# T45 (§18): auto-show the daily-login calendar once per APP LAUNCH (item 3 — the `_login_shown_launch`
# guard, NOT once per Map open; a Board→Map return never re-pops it), and only after a rewarding
# moment, never on a cold first launch. The §18 spirit is "prompt after a reward, not a
# cold open", so all of these must hold:
#   • the flag is on (daily_login_popup),
#   • today is genuinely unclaimed (not Login.claimed_today() — the day's first open),
#   • this is NOT a brand-new save (unlocks.size() > 0 — at least one spot restored, so a rewarding
#     beat has already happened; a fresh save doesn't open on a money-ish calendar).
# (A future FTUE spotlight on this same first-hub-open beat must coordinate so the two never stack on
# one frame — see the parked redesign spec docs/superpowers/specs/2026-06-23-ftue-hand-gesture-
# spotlight-design.md; the current sites are merge/bag on the board, so there is nothing to collide
# with here today.)
# The synchronous gate for the auto-popup: shown-this-launch (item 3) · flag · today unclaimed ·
# past the cold-FTUE. Pulled out so a test can assert the once-per-launch guard without the UI.
func _login_popup_blocked() -> bool:
	return _login_shown_launch \
		or not Features.on("daily_login_popup") \
		or Login.claimed_today() \
		or unlocks.size() <= 0                     # brand-new save — no calendar before the first restore

func _maybe_login_popup_deferred() -> void:
	if _login_popup_blocked():
		return
	_login_shown_launch = true                    # item 3: arm the per-launch guard (a Map re-open won't re-pop)
	LoginUI.open(self, {"refresh": func() -> void:
		_update_hud()
		_refresh_piggy_pip()})

func _open_settings() -> void:
	SettingsUI.open(self)               # the shared card (music/sounds/calm) — also on the board's bottom bar

func _on_board() -> void:
	Audio.play("button_tap", -2.0)
	get_tree().quit_on_go_back = true    # other scenes keep the platform default
	SceneWarm.go(get_tree(), "res://engine/scenes/Board.tscn")

func _unhandled_input(event: InputEvent) -> void:
	# Esc steps back: a map → the place-picker; the picker → quit (desktop has no
	# OS back gesture). Mirrors _notification(WM_GO_BACK_REQUEST).
	if event.is_action_pressed("ui_cancel"):
		if _view == "map":
			_open_select()
			get_viewport().set_input_as_handled()
		elif _view == "select" and get_tree() != null:
			get_tree().quit()

# A window/orientation resize fires size_changed (often many times per drag). Coalesce to one
# rebuild at the end of the frame so the home canvas re-fits the new width like the board background.
func _on_viewport_resized() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	_relayout_after_resize.call_deferred()

func _relayout_after_resize() -> void:
	_relayout_queued = false
	if get_viewport() == null:
		return
	var sz := get_viewport_rect().size
	if sz == _last_view_size:
		return                            # no real change — skip the rebuild
	_last_view_size = sz
	if _view == "map":
		_build_map(false)                 # re-fit WITHOUT the pop-in (a resize is not a navigation)
	else:
		_build_select(false)

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
