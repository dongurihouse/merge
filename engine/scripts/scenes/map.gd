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
const Feel = preload("res://engine/scripts/ui/feel.gd")   # the unified feel verbs — the spirit merge uses Feel.merge gently
const MergeFx = preload("res://engine/scripts/ui/merge_fx.gd")    # the toggleable + tunable feel appliers
const LandFx = preload("res://engine/scripts/ui/land_fx.gd")      # (workbench-tuned, resolved once in _ready)
const LaunchFx = preload("res://engine/scripts/ui/launch_fx.gd")
const MoveFx = preload("res://engine/scripts/ui/move_fx.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")   # shared modal-overlay mount (one source of truth for dialog z)
const FocusRing = preload("res://engine/scripts/ui/focus_ring.gd")   # selected resident cells use the same corner focus as the board
const LevelPopup = preload("res://engine/scripts/ui/level_popup.gd")   # tap the Lv badge → the level screen
const NavBar = preload("res://engine/scripts/ui/nav_bar.gd")   # the shared bottom nav row (board + map)
const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Vault = preload("res://engine/scripts/core/vault.gd")                  # T44 SKIM-SITE — the piggy bank skims earned premium here
const VaultUI = preload("res://engine/scripts/ui/vault.gd")                  # T45: the diegetic piggy-bank jar (chrome entry point)
const Login = preload("res://engine/scripts/core/login.gd")                  # T45: the forgiving daily-login calendar (auto-popup gate)
const LoginUI = preload("res://engine/scripts/ui/login.gd")                  # T45: the diegetic login-calendar popup surface
const Shop = preload("res://engine/scripts/ui/shop.gd")                      # chrome: the Store-badge query (starter_available)
const SettingsUI = preload("res://engine/scripts/ui/settings.gd")            # the shared Settings card (side-rail Settings tile)
const Debug = preload("res://engine/scripts/ui/debug.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Design = preload("res://engine/scripts/core/design.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")   # pre-warm Board off-thread so the garden CTA is snappy
const BootTrace = preload("res://engine/scripts/core/boot_trace.gd")   # cold-boot phase timer — no-ops unless the Boot splash opened a trace
const Habitat = preload("res://engine/scripts/core/habitat.gd")   # the unified resident model (hand + placed + production) — the map IS the habitat surface
const Explore = preload("res://engine/scripts/core/explore.gd")   # the acquire ritual (Expedition nav button → Load out dialog → Rush → Trade)
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Pal = Game.PALETTE
# The grove UI kit (a game-side tool): lazy-loaded so the engine never hard-depends on it — the unowned
# home spot's restore-cost disc builds through it from the workbench-saved style. Missing → baked fallback.
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const HOME_CHROME_PATH := "res://games/grove/home_chrome.gd"   # canonical chrome icon ids (shared with the bake)

const SPOT_NAME_DY := 50.0   # spot name/price stack baseline below the plot point
const ZONE_LEVEL_BADGE_NODE := "ZoneLevelBadge"

# Opacity the lock veil is snapshotted at for the breaking-glass shatter. The resting ready-zone veil
# is semi-transparent; the shards are captured at this crisper alpha so the break reads clearly.
const SHATTER_VEIL_ALPHA := 0.72
const VINE_DIAG_PREFIX := "VINE_DIAG "
const VINE_DEBUG_MODES := ["all", "no_lock", "lock_only", "vines_only", "off"]

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
const CARD_BACK := "map/back_arrow.png"          # the back button's arrow mark (on the shared home disc)
const LEFT_MAP_TITLE_PLATE := "map/left_title_plate.png"
const LEFT_MAP_REWARD_SHELF := "map/left_reward_shelf.png"

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
var _select_scroll := 0.0        # current scroll offset of the place-picker card column (px from the top)
var _select_scroll_max := 0.0    # 0 when the cards fit their column (no scroll); else total_h - column_h
var _hand_scroll := 0.0          # current scroll offset of the in-hand orb grid (px from the top)
var _hand_scroll_max := 0.0      # 0 when the hand fits its column; else grid_h - viewport_h

var _chrome_nodes: Array = []    # bottom chrome (garden CTA, gear, shop, atlas)
var _play_btn: Button            # the MERGED bottom-right CTA: PLAY (board+acorn → board), or RESTORE (vine → unlock) when the map's next spot is affordable
var _residents_btn: Button = null  # legacy handle for the side-rail Expedition badge visibility gate
# THE map-view spirit dock (replaces the standalone habitat dialog). The place-picker carries an in-hand
# COLUMN on the right, and every completed map's housed orbs as a vertical STRIP down the card's right side.
# Spirits are managed by DRAG through the single input surface: hand→a map places, hand→a matching orb
# merges, a housed orb→the hand column brings out. A still-tap on a housed orb focuses it for Sell.
var _hand_panel: Control = null            # the in-hand column (right side of the place-picker); null off the picker
var _hand_orbs: Array = []                 # [{node, idx, kind, tier}] — in-hand orbs (drag sources / merge targets)
var _placed_orbs: Array = []               # [{node, z, map_id, idx, kind, tier}] — housed orbs (drag sources / merge + focus targets)
var _drag: Dictionary = {}                 # the in-flight (or pending) spirit drag; {} when none. active=true once it lifts off
var _drag_ghost: Control = null            # the orb that follows the finger while dragging
var _sel_orb: Dictionary = {}         # the SELECTED orb {src, idx, kind, tier[, z, map_id]} → its tier shows in the in-hand info bar (Sell too when housed); {} when none
var _lv_panel: Control = null              # the HUD Lv chip — hidden on the place-picker (kept on a map)
var _weather: Control = null     # ambient weather layer — belongs to a MAP; hidden on the place-picker
# the resolved feel-FX opts (MergeFx/LandFx/LaunchFx/MoveFx.from_config) — workbench-tuned toggles +
# knobs, resolved ONCE in _ready so the spirit merge runs the same applier the Merge workbench previews.
var _merge_opts := {}
var _land_opts := {}
var _launch_opts := {}
var _move_opts := {}
var _select_back: Button         # the place-picker's bottom-left back arrow (shown only in the select view)
var level_label: Label
var coins_label: Label
var diamonds_label: Label
var _hud_refresh := Callable()
var _gear: Button = null          # the side-rail Settings tile
var _piggy_pip: Control = null    # T45: the vault chrome button's "claimable" ready glow (shown when Vault.claimable())
var _open_water := Callable()     # opens the water stall (the water pill's +; wired from the HUD)
var _hud_panels: Array = []       # wallet + Lv chips
# chrome badges (driven by actionable-state queries; visibility only — never a nag)
var _daily_badge: Control = null  # Daily rail badge — lit when today's login reward is unclaimed
var _inbox_badge: Control = null  # Inbox rail badge — unread count (only built when the inbox system exists)
var _vine_debug_mode_idx := 0
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

	# resolve the workbench-tuned feel-FX opts ONCE — the spirit merge then runs the SAME applier the
	# Merge workbench previews, so a saved tuning takes effect in-game.
	var KitFx: GDScript = load(KIT_PATH)
	var fx_cfg: Dictionary = KitFx.load_config(KitFx.CONFIG_PATH)
	_merge_opts = MergeFx.from_config(fx_cfg)
	_land_opts = LandFx.from_config(fx_cfg)
	_launch_opts = LaunchFx.from_config(fx_cfg)
	_move_opts = MoveFx.from_config(fx_cfg)

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

	# the day's weather drifts over the MAP; kept as a member so the
	# place-picker can hide it — drifting leaves over a static chooser read as stray sprites.
	BootTrace.begin("map.weather")
	var g0 := Save.grove()
	Ambient.check_winback(g0, Time.get_unix_time_from_system())
	_weather = Ambient.build_weather(get_viewport_rect().size, Ambient.weather_now())
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
	_set_level_chip_visible(true)         # the Lv chip rides a map (it was hidden on the place-picker)
	_end_drag()
	if _select_back != null and is_instance_valid(_select_back):
		_select_back.visible = false      # the back arrow belongs to the place-picker, not a map
	# T1: remember WHICH map you were on — the board's Decorate jumps back here
	var g := Save.grove()
	g["last_map"] = String(G.MAPS[z].id)
	Save.grove_write()
	_build_map()
	_refresh_chrome_badges()             # Daily · Vault · Inbox badges re-read their actionable state on nav
	_refresh_play_cta()                  # the merged CTA is PER-MAP — flip Play↔Restore for the map just opened
	_refresh_residents_btn()             # show/hide the Expedition rail badge for the map just opened

func _open_select() -> void:
	_view = "select"
	_set_map_chrome_visible(false)        # the place-picker is a calm chooser — no map chrome, no weather
	_set_level_chip_visible(false)        # the place-picker drops the top-left Lv chip (the wallet still reads)
	Audio.play("button_tap", -4.0)
	_select_scroll = 0.0                  # always open the picker scrolled to the top
	_sel_orb = {}                    # a fresh picker has nothing focused for Sell
	_end_drag()
	_build_select()

# The top-left player-Lv chip rides the map, NOT the place-picker (the picker is the spirit-management
# surface — its right column carries the read). Toggled on map↔picker nav; the wallet stays in both.
func _set_level_chip_visible(on: bool) -> void:
	if _lv_panel != null and is_instance_valid(_lv_panel):
		_lv_panel.visible = on

# The bottom chrome (garden CTA / gear / shop / atlas / piggy) and ambient weather belong to a
# MAP, not the place-picker. One toggle keeps the chooser clean and restores the lived-in map on
# return. The piggy pip rides its button's own visible flag, so it stays correct under this.
func _set_map_chrome_visible(on: bool) -> void:
	for n in _chrome_nodes:
		if is_instance_valid(n):
			(n as CanvasItem).visible = on
	if _weather != null and is_instance_valid(_weather):
		_weather.visible = on

func debug_refresh_weather() -> void:
	var insert_at := get_child_count()
	if _weather != null and is_instance_valid(_weather):
		insert_at = _weather.get_index()
		remove_child(_weather)
		_weather.queue_free()
	else:
		var existing := get_node_or_null("WeatherLayer")
		if existing != null:
			insert_at = existing.get_index()
			remove_child(existing)
			existing.queue_free()
	_weather = Ambient.build_weather(get_viewport_rect().size, Ambient.weather_now())
	add_child(_weather)
	move_child(_weather, mini(insert_at, get_child_count() - 1))
	_weather.visible = _view != "select"

func debug_add_resident_to_hand() -> void:
	var kind := _debug_resident_kind()
	if kind == "":
		return
	Habitat.hand_add(kind)
	if is_inside_tree():
		Audio.play("level_complete", -8.0, 1.05)
		FX.celebrate_at(self, _screen_center(-12.0), "+1 spirit", STRAW)
	_refresh_picker()

func _debug_resident_kind() -> String:
	var z := clampi(_map_idx, 0, G.MAPS.size() - 1)
	for ln in G.resident_lines(z):
		var id := String(ln.id)
		if id != "":
			return id
	for zi in G.MAPS.size():
		for ln in G.resident_lines(zi):
			var id := String(ln.id)
			if id != "":
				return id
	return ""

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
	# ambient life — every map. The wanderers ARE the map's placed residents (the §1 population
	# sub-game): one sprite per placed spirit, EMPTY until something is placed. A map opens to
	# placement at its FIRST restored spot (resident_capacity ramps 1 → MAX), so a single complete
	# zone hosts one resident and it shows here. (The old generic moss/acorn/lantern wander fallback
	# for not-yet-populated maps was retired — ambient life now derives solely from the habitat.)
	var amb := Ambient.build_population_layer(_map_rect.size, _habitat_members(z))
	amb.position = _map_rect.position
	amb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(amb)
	if not has_home:
		_seat_spots(z, home_dict, frame)
	# §1 residents: a FULLY-UNLOCKED map (spots restored + gate delivered) pays its one-time unlock gift
	# (the celebration dialog; the free spirit lands in the habitat hand) and shows the spirits dock + the
	# Expedition rail button (_build_liveops_rail).
	if G.can_populate(z, unlocks, _gates()):
		_maybe_show_unlock_reward(z)
	BootTrace.end("map.open.ambient")
	if animate:
		FX.pop_in(content)        # a navigation pops in; a live resize re-fit does not (would flicker)

# The open map's PLACED spirits as ambient members ({type, tier}). The map renders the habitat
# (engine/scripts/core/habitat.gd) — the single resident model where Explore deposits — instead of the
# legacy per-map welcome roster (G.resident_members), which is now dormant (retired with the economy pass).
func _habitat_members(z: int) -> Array:
	var out: Array = []
	for inst in Habitat.placed(String(G.MAPS[z].id)):
		out.append({"type": String(inst.kind), "tier": int(inst.tier)})
	return out

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
	var hit := _home_badge(z, k, b)
	_add_zone_level_badge_if_locked(hit, z, k)
	return hit

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

func _add_zone_level_badge_if_locked(node: Control, z: int, k: int) -> void:
	var need_level := G.spot_unlock_level(z, k)
	if G.level_for_exp(Save.exp_total()) >= need_level:
		return
	node.add_child(_zone_level_badge(need_level, node.size))

func _zone_level_badge(level: int, host_size: Vector2) -> Control:
	var px := clampf(_map_rect.size.x * 0.085, 64.0, 92.0)
	var wrap := Control.new()
	wrap.name = ZONE_LEVEL_BADGE_NODE
	wrap.size = Vector2(px, px)
	wrap.custom_minimum_size = wrap.size
	wrap.position = ((host_size - wrap.size) * 0.5).floor()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.z_index = 6
	var badge := Look.make_level_badge(level, px)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(badge)
	return wrap

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
		var mask_offset: Vector2 = Grove.mask_offset_for(vine)
		view.mask_offset = mask_offset
		view.load_map(vine, regions)                                # sets size to image_size (for the tool's use)
		# the game seats the view full-rect over the clip frame; clear the image-size hint so the frame
		# (not the image) drives geometry — base cover layer + vine overlays then fill the SAME frame.
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.custom_minimum_size = Vector2.ZERO
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
		view.set_mask_offset(mask_offset)
		_apply_vine_debug_mode(view)
		if _vine_diag_enabled():
			_print_vine_diag.call_deferred("map_open")
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

func debug_cycle_vine_fx() -> void:
	_vine_debug_mode_idx = (_vine_debug_mode_idx + 1) % VINE_DEBUG_MODES.size()
	var view := _active_vine_view()
	_apply_vine_debug_mode(view)
	_print_vine_diag("cycle")

func debug_vine_diag() -> void:
	_print_vine_diag("manual")

func _active_vine_view() -> Control:
	if content == null:
		return null
	return content.find_child("VineMapView", true, false) as Control

func _apply_vine_debug_mode(view: Control) -> void:
	if view == null or not view.has_method("set_debug_layer_mode"):
		return
	view.call("set_debug_layer_mode", String(VINE_DEBUG_MODES[_vine_debug_mode_idx]))

func _vine_diag_enabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if OS.get_environment("TU_VINE_DIAG") == "1":
		return true
	return OS.has_feature("mobile") and OS.is_debug_build()

func _print_vine_diag(reason: String) -> void:
	var view := _active_vine_view()
	if view == null:
		print(VINE_DIAG_PREFIX + JSON.stringify({"reason": reason, "vine_view": false}))
		return
	print(VINE_DIAG_PREFIX + JSON.stringify(_vine_diag_payload(view, reason)))

func _vine_diag_payload(view: Control, reason: String) -> Dictionary:
	var vp := get_viewport_rect().size
	var win := DisplayServer.window_get_size()
	var ready := G.map_next_unlock(_map_idx, unlocks)
	var vine_summary := {}
	if view.has_method("diagnostic_summary"):
		vine_summary = view.call("diagnostic_summary")
	return {
		"reason": reason,
		"os": OS.get_name(),
		"display": DisplayServer.get_name(),
		"features": {
			"mobile": OS.has_feature("mobile"),
			"ios": OS.has_feature("ios"),
			"debug": OS.is_debug_build(),
		},
		"window": [win.x, win.y],
		"viewport": [roundi(vp.x), roundi(vp.y)],
		"map": {
			"index": _map_idx,
			"id": String(G.MAPS[_map_idx].id),
			"rect": _rect_diag(_map_rect),
			"art_rect": _rect_diag(_map_art_rect),
			"base_exists": _vine_base_exists(_map_idx),
		},
		"progress": {
			"exp": Save.exp_total(),
			"level": G.level_for_exp(Save.exp_total()),
			"ready_k": int(ready.k),
			"ready_exp": int(ready.exp),
			"owned_count": owned_count(_map_idx),
			"spot_count": G.MAPS[_map_idx].spots.size(),
		},
		"wallet": {
			"water": Save.water(),
			"coins": Save.coins(),
			"diamonds": Save.diamonds(),
		},
		"vine": vine_summary,
	}

func _vine_base_exists(z: int) -> bool:
	var vine = G.MAPS[z].get("vine", null)
	if typeof(vine) != TYPE_DICTIONARY:
		return false
	return ResourceLoader.exists(String((vine as Dictionary).get("base", "")))

func _rect_diag(rect: Rect2) -> Array:
	return [roundi(rect.position.x), roundi(rect.position.y), roundi(rect.size.x), roundi(rect.size.y)]

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
	_hand_orbs.clear()
	_placed_orbs.clear()
	_hand_panel = null
	var view := get_viewport_rect().size
	# TWO SEPARATE columns, both top-aligned. LEFT: the individual map cards, scrolled in a clipped column.
	# RIGHT: the in-hand spirits on a reused garden BOARD (its own framed planter — a 2-column grid + a bottom
	# info bar). The board is the single input surface (cards / orbs are hit-tested by their scrolled global rect).
	var n := G.MAPS.size()
	var Kit: GDScript = load(KIT_PATH)
	var opts: Dictionary = Kit.map_card_opts_from_config(Kit.load_config(Kit.CONFIG_PATH)) if Kit != null else {}
	var layout: Dictionary = Kit.map_select_layout(view, opts, Look.safe_top(self), Look.safe_bottom(self))
	var sep := float(layout.sep)
	var band_top := float(layout.band_top)
	var col_h := float(layout.col_h)
	var left_clip_top := float(layout.get("left_clip_top", band_top))
	var left_clip_h := float(layout.get("left_clip_h", col_h))
	var left_content_top := float(layout.get("left_content_top", band_top - left_clip_top))
	var card_w := float(layout.card_w)
	var base_card_h := float(layout.base_card_h)
	var left_x := float(layout.left_x)
	var hand_x := float(layout.hand_x)
	var hand_w := float(layout.hand_w)
	# LEFT column: the card stack keeps its visual top alignment with the hand board, but the clip itself spans
	# the full screen so scrolling can reveal cards all the way to the top and bottom edges.
	var clip := Control.new()
	clip.name = "MapSelectCardScrollClip"
	clip.position = Vector2(left_x, left_clip_top)
	clip.size = Vector2(card_w, left_clip_h)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE                  # single-input-surface: taps pass through to `content`
	content.add_child(clip)
	var card_heights: Array = []
	var total_h := sep * float(maxi(n - 1, 0))
	for z in n:
		var this_h := base_card_h * (1.045 if map_unlocked(z) else 0.965)
		this_h = maxf(this_h, 132.0)
		card_heights.append(this_h)
		total_h += this_h
	_select_scroll_max = maxf(0.0, left_content_top + total_h - left_clip_h)
	_select_scroll = clampf(_select_scroll, 0.0, _select_scroll_max)
	var y := left_content_top
	for z in n:
		var card_h := float(card_heights[z])
		var card := _make_card(z, card_w, card_h, opts)
		card.position = Vector2(0.0, y - _select_scroll)        # clip-local: flush to the column's top-left
		card.size = Vector2(card_w, card_h)
		clip.add_child(card)
		select_hits.append({"node": card, "z": z, "y0": y})
		y += card_h + sep
	# RIGHT column: the in-hand garden board
	_hand_panel = _build_hand_panel(Rect2(hand_x, band_top, hand_w, col_h))
	content.add_child(_hand_panel)
	if _select_back != null and is_instance_valid(_select_back):
		_select_back.visible = true
	if animate:
		FX.pop_in(content)

# One map card, built from the SHARED kit (Kit.map_card) so the workbench tunes the SAME recipe the
# game renders. This resolves the per-card DATA from game state — OPEN → the locale art inside the gold
# frame + a restored-zone progress pill; LOCKED → the dark baked panel under an "after <prev>" line — and
# hands it the workbench-saved look `opts` (Kit.map_card_opts_from_config, resolved once per place-picker
# build in _build_select). `card_h` is always > 0 from _build_select. Every node IGNOREs the mouse.
func _make_card(z: int, card_w: float, card_h: float = 0.0, opts: Dictionary = {}) -> Control:
	var Kit: GDScript = load(KIT_PATH)
	if opts.is_empty():     # standalone callers (no _build_select context) resolve the saved look themselves
		opts = Kit.map_card_opts_from_config(Kit.load_config(Kit.CONFIG_PATH)) if Kit != null else {}
	# a COMPLETED map renders as the prototype habitat card; in-progress / locked maps keep the vista card
	if Kit != null and map_unlocked(z) and G.can_populate(z, unlocks, _gates()):
		return _habitat_card(z, card_w, card_h, opts)
	var open := map_unlocked(z)
	# One zone per vine region — the badge reports honest restore progress over every region (owned/total),
	# and a map is "done" only when all of them are restored (map_spots_done). No phantom base-region offset.
	var total_zones: int = G.MAPS[z].spots.size()
	var d := {
		"open": open,
		"done": map_spots_done(z),
		"title": tr(G.MAPS[z].name),
		"art": _card_art_path(z) if open else "",     # painted thumbnail / §16 home clean art / "" → meadow fill
		"owned_zones": owned_count(z),
		"total_zones": total_zones,
		"prereq": Strings.t("map.card.prereq") % tr(G.MAPS[maxi(z - 1, 0)].name),
		"map_id": String(G.MAPS[z].id),               # the §8 veil-art seam (map/veil_<id>.png)
	}
	return Kit.map_card(d, opts, card_w, card_h)

# A COMPLETED map's place-picker card: the map's own art fills the WHOLE card as a full-bleed background
# inside the SHARED gold frame (so a completed place reads with the same framed vista as an open one), with
# the habitat controls riding on top — a name plate over the art, then the housed spirits as ORBS in slots
# (empty slots show free capacity) and a production fill-bar + Collect on a translucent parchment shelf so
# the dark-ink content stays legible. The body is mouse-IGNORE so a tap navigates; only Collect intercepts.
func _habitat_card(z: int, card_w: float, card_h: float, opts: Dictionary = {}) -> Control:
	var Kit: GDScript = load(KIT_PATH)
	var map_id := String(G.MAPS[z].id)
	var placed: Array = Habitat.placed(map_id)
	var cap := Habitat.cap(map_id)
	var cur := Habitat.reward_currency(map_id)
	if opts.is_empty() and Kit != null:
		opts = Kit.map_card_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	var badge_opts: Dictionary = opts.get("badge", {})

	var card := Control.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# full-bleed map art as the card background, framed + COVER-filled exactly like an open vista card.
	var band := clampf(float(badge_opts.get("inner_inset", 6.0)) + 3.0, 4.0, minf(card_w, card_h) * 0.45)
	var radius := maxf(2.0, float(Kit.gold_badge_cap(badge_opts)) - band)
	Kit._map_add_frame(card, badge_opts)
	var art_path := _card_art_path(z)
	if art_path != "" and ResourceLoader.exists(art_path):
		Kit._map_add_fill(card, load(art_path), badge_opts, card_w, card_h)
	else:
		card.add_child(_inset_fill(Color(DOCK_STRAW, 0.5), band, radius))   # a parched plate when art is absent

	# the map name on a parchment plate, top-left over the art
	var plate := _habitat_plate(String(G.MAPS[z].name))
	plate.position = Vector2(band + 8.0, band + 8.0)
	card.add_child(plate)

	var inset := band + 6.0
	# the HOUSED spirits ride a VERTICAL strip down the card's RIGHT side. This strip IS the drop zone for a
	# dragged in-hand spirit — sized generously so a drop lands easily, while a tap elsewhere on the card still
	# navigates into the map. The orbs register into `_placed_orbs` (drag-out / merge / focus targets).
	var resident_slot_px := clampf(float(opts.get("resident_slot_px", 58.0)), 30.0, 148.0)
	var resident_slot_gap := clampf(float(opts.get("resident_slot_gap", 10.0)), 0.0, 36.0)
	var rail_pad_preview := clampf(resident_slot_px * 0.26, 11.0, 36.0)
	var strip_w := clampf(resident_slot_px * 2.0 + resident_slot_gap + rail_pad_preview * 2.0, 96.0, minf(card_w * 0.76, 440.0))
	_add_habitat_strip(card, z, map_id, placed, cap, Rect2(card_w - inset - strip_w, inset, strip_w, card_h - inset * 2.0), resident_slot_px, opts, resident_slot_gap)
	var shelf_rect: Rect2 = Kit.map_habitat_shelf_rect(card_w, card_h, inset, strip_w, opts)

	# the name + production read ride a translucent parchment shelf docked to the BOTTOM-LEFT (clear of the
	# strip) so the dark-ink labels stay legible while the art still shows through behind them.
	var shelf := Panel.new()
	shelf.name = "MapHabitatRewardShelf"
	shelf.position = shelf_rect.position
	shelf.size = shelf_rect.size
	shelf.custom_minimum_size = shelf_rect.size
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shelf_style := _left_map_style(LEFT_MAP_REWARD_SHELF, Vector4(36, 24, 36, 24), Vector4(14, 8, 14, 8))
	if shelf_style != null:
		shelf.add_theme_stylebox_override("panel", shelf_style)
	else:
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(DOCK_PARCH, 0.88)
		ss.set_corner_radius_all(14)
		ss.set_border_width_all(2)
		ss.border_color = Color(DOCK_INK, 0.12)
		shelf.add_theme_stylebox_override("panel", ss)
	var shelf_pad_l := 14.0
	var shelf_pad_r := 14.0
	var shelf_pad_t := 8.0
	var shelf_pad_b := 8.0
	var shelf_gap := 8.0
	var capf := 0.0
	var pendingf := 0.0
	var ready := 0
	var reward_cap := 0
	if cur != "":
		capf = Habitat.accrual_cap(map_id)
		pendingf = Habitat.pending(map_id)
		ready = _reward_amount_ready(map_id)
		reward_cap = _reward_amount_cap(map_id)

	var reward_icon: Control = null
	var reward_icon_size := clampf(float(opts.get("reward_icon_size", 24.0)), 8.0, 72.0)
	if Kit != null:
		reward_icon = Kit.make_icon(_reward_icon(cur), reward_icon_size)
	if reward_icon != null:
		reward_icon.name = "MapHabitatRewardIcon"
		reward_icon.custom_minimum_size = Vector2(reward_icon_size, reward_icon_size)
		reward_icon.size = reward_icon.custom_minimum_size
		reward_icon.position = Vector2(shelf_pad_l, shelf_pad_t) + Vector2(float(opts.get("reward_icon_x", 0.0)), float(opts.get("reward_icon_y", 0.0)))
		reward_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shelf.add_child(reward_icon)
	var sub := _card_sub("%s · %d/%d" % [_reward_label(cur), ready, reward_cap])
	sub.name = "MapHabitatRewardLabel"
	sub.add_theme_font_size_override("font_size", int(clampf(float(opts.get("reward_label_font", 21)), 8.0, 48.0)))
	sub.custom_minimum_size = Vector2(maxf(120.0, shelf_rect.size.x * 0.40), float(sub.get_theme_font_size("font_size")) + 8.0)
	sub.size = sub.custom_minimum_size
	sub.position = Vector2(shelf_pad_l + reward_icon_size + 4.0, shelf_pad_t - 1.0) + Vector2(float(opts.get("reward_label_x", 0.0)), float(opts.get("reward_label_y", 0.0)))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shelf.add_child(sub)

	# production bar + Collect — every completed map pays its own reward now (coins/water/boost/diamonds/chest)
	if cur != "":
		var frac := (pendingf / capf) if capf > 0.0 else 0.0
		var button_size := Vector2(
			clampf(float(opts.get("reward_button_w", 116.0)), 40.0, 260.0),
			clampf(float(opts.get("reward_button_h", 36.0)), 20.0, 90.0)
		)
		var button_pos := Vector2(shelf_rect.size.x - shelf_pad_r - button_size.x, shelf_rect.size.y - shelf_pad_b - button_size.y) + Vector2(float(opts.get("reward_button_x", 0.0)), float(opts.get("reward_button_y", 0.0)))
		var bar_h := clampf(float(opts.get("reward_bar_h", clampf(shelf_rect.size.y * 0.13, 10.0, 18.0))), 4.0, 40.0)
		var bar_x := shelf_pad_l
		var bar_y := clampf(
			shelf_rect.size.y - shelf_pad_b - bar_h - 5.0 + float(opts.get("reward_bar_y", 0.0)),
			shelf_pad_t,
			maxf(shelf_pad_t, shelf_rect.size.y - shelf_pad_b - bar_h)
		)
		var bar: Control = Kit.progress_bar(clampf(frac, 0.0, 1.0), {
			"height": bar_h,
			"width": clampf(button_pos.x - shelf_gap - bar_x, 44.0, maxf(44.0, shelf_rect.size.x - shelf_pad_l - shelf_pad_r)),
			"art": true,
		})
		bar.name = "MapHabitatProgressBar"
		bar.size = bar.custom_minimum_size
		bar.position = Vector2(bar_x, bar_y)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shelf.add_child(bar)
		var collect: Button = Kit.map_reward_collect_button("Collect", "", button_size,
			int(clampf(float(opts.get("reward_button_font", 18)), 8.0, 48.0)),
			0.0,
			ready > 0)
		collect.position = button_pos
		collect.pressed.connect(func() -> void: _on_card_collect(z))   # STOP filter → intercepts its own tap (no navigate)
		shelf.add_child(collect)
		# map 3: a "Use boost" affordance once charges are stockpiled (arms the generator boost for free)
		if cur == "boost" and Habitat.boost_charges() > 0:
			var useb: Button = Kit.pill_button("Use boost (%d)" % Habitat.boost_charges(), {"bg": "cream", "art": true, "font": 18, "enabled": not G.boost_active()})
			useb.position = Vector2(button_pos.x, maxf(shelf_pad_t, button_pos.y - button_size.y - 4.0))
			useb.pressed.connect(func() -> void: _on_use_boost())
			shelf.add_child(useb)

	card.add_child(shelf)

	return card

# The housed-spirit STRIP down a card's right side — a translucent vertical plate carrying the placed orbs
# (then empty slots up to capacity), arranged as a stable two-column / four-row rail. The whole strip
# is the card's PLACE/merge drop zone; each filled orb registers into `_placed_orbs` (drag-out + merge + focus
# target) and the focused orb is tinted. Every node IGNOREs the mouse (the single input surface hit-tests it).
func _add_habitat_strip(card: Control, z: int, map_id: String, placed: Array, cap: int, rect: Rect2, orb_px: float, opts: Dictionary = {}, slot_gap: float = 10.0) -> void:
	var Kit: GDScript = load(KIT_PATH)
	var badge_opts: Dictionary = opts.get("badge", {})
	var display_cap := maxi(cap, 8)
	var slot_cols := 2
	var slot_rows := 4
	display_cap = mini(display_cap, slot_cols * slot_rows)
	var sep := clampf(slot_gap, 0.0, 36.0)
	orb_px = clampf(orb_px, 30.0, 148.0)
	var rail_pad := clampf(orb_px * 0.26, 11.0, 36.0)
	var max_sep_w := maxf(0.0, (rect.size.x - rail_pad * 2.0 - 10.0 * float(slot_cols)) / float(slot_cols - 1))
	var max_sep_h := maxf(0.0, (rect.size.y - rail_pad * 2.0 - 10.0 * float(slot_rows)) / float(slot_rows - 1))
	sep = minf(sep, minf(max_sep_w, max_sep_h))
	var max_orb_w := (rect.size.x - rail_pad * 2.0 - sep * float(slot_cols - 1)) / float(slot_cols)
	var max_orb_h := (rect.size.y - rail_pad * 2.0 - sep * float(slot_rows - 1)) / float(slot_rows)
	orb_px = floor(clampf(maxf(8.0, minf(orb_px, minf(max_orb_w, max_orb_h))), 8.0, 148.0))
	rail_pad = clampf(orb_px * 0.26, 11.0, 36.0)
	var rail_w := orb_px * float(slot_cols) + sep * float(slot_cols - 1) + rail_pad * 2.0
	var rail_h := orb_px * float(slot_rows) + sep * float(slot_rows - 1) + rail_pad * 2.0
	rail_w = minf(rect.size.x, rail_w)
	rail_h = minf(rect.size.y, rail_h)
	var strip := Control.new()
	strip.position = rect.position + Vector2(maxf(0.0, rect.size.x - rail_w), maxf(0.0, (rect.size.y - rail_h) * 0.5))
	strip.size = Vector2(rail_w, rail_h)
	strip.clip_contents = true
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rail_badge: Dictionary = badge_opts.duplicate()
	rail_badge["corner"] = minf(float(rail_badge.get("corner", 24.0)), 24.0)
	rail_badge["inner_inset"] = clampf(float(rail_badge.get("inner_inset", 7.0)), 4.0, 8.0)
	var frame: Control = null
	if Kit != null:
		frame = Kit.board_panel(strip.size, {
			"frame_style": "badge",
			"badge": rail_badge,
			"draw_center": true,
			"shadow": false,
		})
	if frame == null:
		var panel := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(DOCK_PARCH, 0.96)
		sb.draw_center = true
		sb.set_corner_radius_all(18)
		sb.set_border_width_all(2)
		sb.border_color = Color(DOCK_STRAW, 0.72)
		panel.add_theme_stylebox_override("panel", sb)
		frame = panel
	frame.name = "MapResidentRailFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.modulate = Color(1, 1, 1, 0.96)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(frame)

	# a MarginContainer insets the two-column / four-row grid inside the board-style background.
	var margin := MarginContainer.new()
	margin.name = "MapResidentRailInset"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, int(round(rail_pad)))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", sep)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)
	var avail_w := maxf(1.0, rail_w - rail_pad * 2.0)
	var avail_h := maxf(1.0, rail_h - rail_pad * 2.0)
	var slot_gap_x := sep
	var slot_gap_y := sep
	var grid := GridContainer.new()
	grid.columns = slot_cols
	grid.custom_minimum_size = Vector2(avail_w, avail_h)
	grid.add_theme_constant_override("h_separation", int(round(slot_gap_x)))
	grid.add_theme_constant_override("v_separation", int(round(slot_gap_y)))
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bag_opts: Dictionary = opts.get("slot_cell", {})
	if bag_opts.is_empty() and Kit != null:
		bag_opts = Kit.bag_card_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	else:
		bag_opts = bag_opts.duplicate(true)
	bag_opts["cell_w"] = orb_px
	bag_opts["cell_h"] = orb_px
	for i in placed.size():
		var inst: Dictionary = placed[i]
		var selected := String(_sel_orb.get("src", "")) == "placed" and int(_sel_orb.get("z", -1)) == z and int(_sel_orb.get("idx", -1)) == i
		var slot := _spirit_cell(Kit, bag_opts, String(inst.kind), int(inst.tier), orb_px, selected)
		slot.name = "MapResidentRailCell_%02d" % i
		grid.add_child(slot)
		_placed_orbs.append({"node": slot, "z": z, "map_id": map_id, "idx": i, "kind": String(inst.kind), "tier": int(inst.tier)})
	for _e in range(placed.size(), display_cap):
		grid.add_child(_empty_cell(Kit, bag_opts, orb_px))
	vb.add_child(grid)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(spacer)
	card.add_child(strip)

# The IN-HAND board on the place-picker's right — a REUSED garden planter (PieceView.make_board_mat) carrying
# the spirits as a TWO-column grid (no per-orb tier badge), above a bottom INFO BAR. Tap a spirit (here, or a
# housed orb on a card) to select it; the info bar reads its tier and — for a housed spirit — shows Sell. The
# grid scrolls (wheel, or a drag on the board's empty soil). Orbs IGNORE the mouse (the single input surface
# hit-tests them); only the info-bar Sell button intercepts its own tap.
func _build_hand_panel(rect: Rect2) -> Control:
	var Kit: GDScript = load(KIT_PATH)
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH) if Kit != null else {}
	var panel := Control.new()
	panel.name = "HandColumn"
	panel.position = rect.position
	panel.size = rect.size
	panel.custom_minimum_size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# the NEW board skin — the reskinned Kit.board_panel (cream face + gold frame), the SAME surface the merge
	# board now wears — fills the column.
	if Kit != null:
		var bp_opts: Dictionary = Kit.board_panel_opts_from_config(cfg)
		var bp: Control = Kit.board_panel(rect.size, bp_opts)
		bp.position = Vector2.ZERO
		_force_ignore(bp)
		panel.add_child(bp)

	var ci := 22.0                                               # content inset inside the board frame
	var cx := ci
	var cw := rect.size.x - ci * 2.0
	var ctop := ci
	# the board frame's corner radius is large (GOLD_BADGE_CAP = 58); keep the bottom info bar clear of the
	# rounded bottom corners so neither it nor its Sell button pokes past the frame.
	var cbot := rect.size.y - 62.0

	var title := _dock_label("In hand", 20, true)
	title.position = Vector2(cx, ctop)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)
	var grid_top := ctop + 30.0

	# the bottom INFO BAR — the selected spirit's tier + Sell (housed), sitting above the rounded corners
	var bar_h := 88.0
	panel.add_child(_inhand_info_bar(Rect2(cx, cbot - bar_h, cw, bar_h)))
	var grid_bot := cbot - bar_h - 8.0

	# the spirit grid, scrollable within a clipped viewport between the title and the info bar
	var hand: Array = Habitat.hand()
	var view_h := maxf(40.0, grid_bot - grid_top)
	var clip := Control.new()
	clip.name = "HandClip"
	clip.position = Vector2(cx, grid_top)
	clip.size = Vector2(cw, view_h)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(clip)
	if hand.is_empty():
		var empty := _dock_label("Empty —\nfind spirits on Expedition.", 15)
		empty.position = Vector2(2.0, 2.0)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty.size = Vector2(cw - 4.0, view_h)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(empty)
		_hand_scroll_max = 0.0
		return panel
	var sep := 8.0
	var cols := 2                                                # exactly two columns → larger cells
	var cell_px := (cw - sep * float(cols - 1)) / float(cols)    # fill the width evenly
	# the NEW board CELLS — Kit.slot_cell, the very component the reskinned board + bag use
	var bag_opts: Dictionary = Kit.bag_card_opts_from_config(cfg) if Kit != null else {}
	bag_opts["cell_w"] = cell_px
	bag_opts["cell_h"] = cell_px
	var grid := GridContainer.new()
	grid.name = "HandGrid"
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", int(sep))
	grid.add_theme_constant_override("v_separation", int(sep))
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in hand.size():
		var inst: Dictionary = hand[i]
		var sel := String(_sel_orb.get("src", "")) == "hand" and int(_sel_orb.get("idx", -1)) == i
		var cell := _spirit_cell(Kit, bag_opts, String(inst.kind), int(inst.tier), cell_px, sel)
		grid.add_child(cell)
		_hand_orbs.append({"node": cell, "idx": i, "kind": String(inst.kind), "tier": int(inst.tier)})
	# round the grid out with EMPTY cells so it reads as a board, filling the visible rows
	var vis_rows := maxi(1, int((view_h + sep) / (cell_px + sep)))
	var want_cells := maxi(hand.size(), vis_rows * cols)
	for _e in range(hand.size(), want_cells):
		grid.add_child(_empty_cell(Kit, bag_opts, cell_px))
	clip.add_child(grid)
	var rows := int(ceil(float(want_cells) / float(cols)))
	var grid_h := float(rows) * cell_px + float(maxi(rows - 1, 0)) * sep
	_hand_scroll_max = maxf(0.0, grid_h - view_h)
	_hand_scroll = clampf(_hand_scroll, 0.0, _hand_scroll_max)
	grid.position = Vector2(0.0, -_hand_scroll)
	return panel

# The in-hand board's bottom strip reads the selected spirit's tier and surfaces Sell. It uses the same
# thin code-drawn Slot-cell face as the resident cells so it stays quiet inside the right board.
func _inhand_info_bar(rect: Rect2) -> Control:
	var Kit: GDScript = load(KIT_PATH)
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH) if Kit != null else {}
	var bar := Control.new()
	bar.name = "InHandInfoBar"
	bar.position = rect.position
	bar.size = rect.size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg: Panel
	if Kit != null:
		var bag_opts: Dictionary = Kit.bag_card_opts_from_config(cfg)
		bg = Kit.slot_cell_background(rect.size, "empty", false, bag_opts) as Panel
	else:
		bg = Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(DOCK_PARCH, 0.97)
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(2)
		sb.border_color = Color(DOCK_INK, 0.20)
		bg.add_theme_stylebox_override("panel", sb)
	bg.name = "InHandInfoBarFrame"
	bg.position = Vector2.ZERO
	bg.size = rect.size
	bg.custom_minimum_size = rect.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bg)
	var pad := 8.0
	if _sel_orb.is_empty():
		var hint := _dock_label("Tap a spirit", 16)
		hint.position = Vector2(pad + 4.0, (rect.size.y - 22.0) * 0.5)
		hint.modulate = Color(1, 1, 1, 0.65)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(hint)
		return bar
	var info_px := clampf(rect.size.y * 0.48, 34.0, 48.0)
	var info := Button.new()
	info.name = "ResidentInfoButton"
	info.flat = true
	info.focus_mode = Control.FOCUS_NONE
	info.tooltip_text = "Tiers"
	info.custom_minimum_size = Vector2(info_px, info_px)
	info.size = Vector2(info_px, info_px)
	info.position = Vector2(pad + 4.0, (rect.size.y - info_px) * 0.5)
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		info.add_theme_stylebox_override(st, empty)
	var info_icon_px := info_px * 0.86
	var info_icon: Control = Kit.make_icon("info", info_icon_px) if Kit != null else Look.icon("info", info_icon_px)
	info_icon.name = "ResidentInfoIcon"
	info_icon.size = Vector2(info_icon_px, info_icon_px)
	info_icon.position = Vector2((info_px - info_icon_px) * 0.5, (info_px - info_icon_px) * 0.5)
	info_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(info_icon)
	info.pressed.connect(_on_resident_info_pressed)
	bar.add_child(info)
	if not _sel_orb.is_empty():
		# Sell shows for ANY selected spirit — in-hand OR housed (both pay SELL_PER_TIER × tier). A FIXED-size
		# green pill, so its footprint is controlled and never pokes past the bar / board frame.
		var tier := int(_sel_orb.get("tier", 1))
		var sw := 122.0
		var sh := 42.0
		var sell := Button.new()
		sell.name = "ResidentSellButton"
		sell.text = "Sell +%d" % (Habitat.SELL_PER_TIER * tier)
		sell.add_theme_font_size_override("font_size", 22)
		sell.add_theme_color_override("font_color", Color("#F4FBE9"))
		sell.add_theme_color_override("font_outline_color", Color("#173404"))
		sell.add_theme_constant_override("outline_size", 3)
		var gsb := StyleBoxFlat.new()
		gsb.bg_color = Color("#639922")
		gsb.set_corner_radius_all(12)
		gsb.set_border_width_all(2)
		gsb.border_color = Color("#3B6D11")
		for st in ["normal", "hover", "pressed", "focus"]:
			sell.add_theme_stylebox_override(st, gsb)
		sell.custom_minimum_size = Vector2(sw, sh)
		sell.size = Vector2(sw, sh)
		sell.position = Vector2(rect.size.x - sw - pad - 2.0, (rect.size.y - sh) * 0.5)
		sell.pressed.connect(func() -> void: _on_focus_sell())
		bar.add_child(sell)
	return bar

func _left_map_texture(rel: String) -> Texture2D:
	var path := Look.kit(rel)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

func _left_map_style(rel: String, slice: Vector4, content: Vector4) -> StyleBoxTexture:
	var tex := _left_map_texture(rel)
	if tex == null:
		return null
	var st := StyleBoxTexture.new()
	st.texture = tex
	st.set_texture_margin(SIDE_LEFT, slice.x)
	st.set_texture_margin(SIDE_TOP, slice.y)
	st.set_texture_margin(SIDE_RIGHT, slice.z)
	st.set_texture_margin(SIDE_BOTTOM, slice.w)
	st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	st.content_margin_left = content.x
	st.content_margin_top = content.y
	st.content_margin_right = content.z
	st.content_margin_bottom = content.w
	return st

func _habitat_plate(text: String) -> Control:
	var plate_tex := _left_map_texture(LEFT_MAP_TITLE_PLATE)
	if plate_tex != null:
		var node := Control.new()
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lbl := _dock_label(text, 24, true)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var text_size := lbl.get_combined_minimum_size()
		node.size = Vector2(maxf(text_size.x + 54.0, 142.0), maxf(text_size.y + 16.0, 42.0))
		node.custom_minimum_size = node.size
		var bg := TextureRect.new()
		bg.texture = plate_tex
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(bg)
		lbl.position = Vector2(24.0, 6.0)
		lbl.size = Vector2(maxf(2.0, node.size.x - 48.0), maxf(2.0, node.size.y - 10.0))
		node.add_child(lbl)
		return node
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(DOCK_PARCH, 0.92)
	s.set_corner_radius_all(12)
	s.set_border_width_all(2)
	s.border_color = Color(DOCK_INK, 0.14)
	s.content_margin_left = 12 ; s.content_margin_right = 12
	s.content_margin_top = 4 ; s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	var lbl := _dock_label(text, 28, true)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lbl)
	p.size = p.get_combined_minimum_size()
	return p

# A rounded fill inset to the gold frame's inner rim — the habitat card's fallback when a map has no
# painted art yet (mirrors the COVER art fill's band/radius so it nestles inside the same rim). Mouse-IGNORE.
func _inset_fill(col: Color, band: float, radius: float) -> Control:
	var pnl := Panel.new()
	pnl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pnl.offset_left = band ; pnl.offset_top = band
	pnl.offset_right = -band ; pnl.offset_bottom = -band
	pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(int(radius))
	pnl.add_theme_stylebox_override("panel", s)
	return pnl

func _on_card_collect(z: int) -> void:
	var r: Dictionary = Habitat.collect(String(G.MAPS[z].id))
	_update_hud()
	_collect_fx(r, get_global_rect().get_center() - Vector2(0, 40))
	_refresh_picker()    # a residents-chest collect grows the hand; repaint the bar + Collect + hand column

# --- the per-map reward, surfaced (icon / collectable amount / feedback) --------------------------
# Map 1 coins · map 2 water · map 3 a generator-boost charge · map 4 diamonds · map 5 a resident chest.
# Boost + residents reuse the leaf glyph until their bespoke art ships (parked); diamonds read as gems.
func _reward_icon(cur: String) -> String:
	match cur:
		"coins": return "coin"
		"water": return "water"
		"diamonds": return "gem"
		_: return "leaf"

func _reward_label(cur: String) -> String:
	match cur:
		"coins": return "Coins"
		"water": return "Water"
		"boost": return "Boosts"
		"diamonds": return "Diamonds"
		"residents": return "Spirits"
		_: return "Resting"

# The amount a collect would bank right now: floor(pending), already in the map's currency (the per-map MULT
# is baked into pending). For map 5 that's the number of residents the chest would drop. 0 below one whole unit.
func _reward_amount_ready(map_id: String) -> int:
	if Habitat.reward_currency(map_id) == "":
		return 0
	return int(floor(Habitat.pending(map_id)))

func _reward_amount_cap(map_id: String) -> int:
	if Habitat.reward_currency(map_id) == "":
		return 0
	return int(floor(Habitat.accrual_cap(map_id)))

# Reward-aware collect feedback (a chime + a float/callout matched to the currency).
func _collect_fx(r: Dictionary, at: Vector2) -> void:
	var amt := int(r.get("amount", 0))
	if amt <= 0:
		Audio.play("button_tap", -2.0)
		return
	Audio.play("level_complete", -8.0, 1.1)
	match String(r.get("currency", "")):
		"coins": FX.floating_reward(self, at, "coin", amt, STRAW)
		"water": FX.floating_reward(self, at, "water", amt, STRAW)
		"diamonds": FX.floating_reward(self, at, "gem", amt, STRAW)
		"boost": FX.celebrate_at(self, at, "+%d boost%s" % [amt, "" if amt == 1 else "s"], STRAW)
		"residents": FX.celebrate_at(self, at, "Chest! +%d spirit%s" % [amt, "" if amt == 1 else "s"], STRAW)
		_: FX.celebrate_at(self, at, "+%d" % amt, STRAW)

# Spend one stockpiled generator-boost charge (map 3's reward) to arm the board boost for FREE. Repaints the
# place-picker (the card's boost affordance) when it is the open surface.
func _on_use_boost() -> void:
	if Habitat.use_boost_charge():
		Audio.play("level_complete", -8.0, 1.1)
		FX.celebrate_at(self, _screen_center(-12.0), "Boost armed!", STRAW)
	else:
		Audio.play("button_tap", -2.0)
	_update_hud()
	if _view == "select":
		_refresh_picker()    # repaint the card's boost affordance in place

func _card_sub(text: String) -> Label:
	var l := _dock_label(text, 21, true)
	l.modulate = Color(1, 1, 1, 0.92)
	return l

# The art that fills an open card: the map's own painted thumbnail (map_<id>.png), else its §16 home
# clean art (the hub's restored cottage), else "" → a code-drawn meadow fill.
func _card_art_path(z: int) -> String:
	var Kit: GDScript = load(KIT_PATH)
	return Kit.map_card_art_path(G.MAPS[z]) if Kit != null else ""

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
	if _view == "select":
		_on_select_input(event)
		return
	# a MAP: a still-tap resolves straight to spots / wandering spirits (no drag surface here).
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) \
		or event is InputEventScreenTouch
	if pressed and event.pressed:
		_press = event.position
	elif pressed and not event.pressed and event.position.distance_to(_press) <= 18.0:
		# tap targets hit-test against GLOBAL rects; in place mode `content` is scaled,
		# so lift the content-local event point into global space (identity otherwise).
		_map_tap(content.get_global_transform() * event.position)

# The place-picker input surface. A press on a spirit ORB starts a DRAG (8 px lift-off): a hand orb dropped
# on a map's right drop zone PLACES, on a matching orb MERGES (place_merge / hand_merge); a housed orb dropped
# on the in-hand column BRINGS OUT. A press on empty card area PANS the stack / still-taps a card to open it.
# A still-tap on a housed orb FOCUSES it (its Sell button appears in the hand column).
func _on_select_input(event: InputEvent) -> void:
	var press: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	var release: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
		or (event is InputEventScreenTouch and not event.pressed)
	var moved: bool = event is InputEventScreenDrag \
		or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
	if press:
		_press = event.position
		_drag = _orb_at(content.get_global_transform() * event.position)
		return
	if moved:
		var gp: Vector2 = content.get_global_transform() * event.position
		if not _drag.is_empty():
			# a press that LANDED on an orb lifts it once it moves past the threshold — drag it onto a map to
			# place / onto a match to merge (a housed orb onto the hand board to bring out). No direction
			# gymnastics: any drag on an orb is an orb drag, so the right column drags reliably.
			if not bool(_drag.get("active", false)) and event.position.distance_to(_press) > 8.0:
				_begin_drag_ghost(gp)
			if bool(_drag.get("active", false)):
				_move_drag_ghost(gp)
			return
		# a drag on EMPTY area scrolls the column it is over (the hand board, else the map cards)
		if _hand_panel != null and is_instance_valid(_hand_panel) and _hand_panel.get_global_rect().has_point(gp):
			_scroll_hand_by(-event.relative.y)
		elif _select_scroll_max > 0.0:
			_scroll_select_by(-event.relative.y)
		return
	if event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP):
		var gpw: Vector2 = content.get_global_transform() * event.position
		var dy := 90.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -90.0
		if _hand_panel != null and is_instance_valid(_hand_panel) and _hand_panel.get_global_rect().has_point(gpw):
			_scroll_hand_by(dy)
		else:
			_scroll_select_by(dy)
		return
	if release:
		var gpos: Vector2 = content.get_global_transform() * event.position
		if not _drag.is_empty():
			if bool(_drag.get("active", false)):
				_resolve_drop(gpos)
			else:
				_on_orb_tap(_drag)
			_end_drag()
			return
		if event.position.distance_to(_press) <= 18.0:
			_select_tap(gpos)

# --- the place-picker spirit DRAG (place / merge / bring out, all through the single input surface) -------

# The orb (hand or housed) under a global point, as a drag descriptor — {} on empty space.
func _orb_at(gpos: Vector2) -> Dictionary:
	for o in _hand_orbs:
		var n: Control = o.node
		if is_instance_valid(n) and n.get_global_rect().grow(4.0).has_point(gpos):
			return {"src": "hand", "idx": int(o.idx), "kind": String(o.kind), "tier": int(o.tier), "node": n}
	for o in _placed_orbs:
		var pn: Control = o.node
		if is_instance_valid(pn) and pn.get_global_rect().grow(4.0).has_point(gpos):
			return {"src": "placed", "idx": int(o.idx), "z": int(o.z), "map_id": String(o.map_id),
				"kind": String(o.kind), "tier": int(o.tier), "node": pn}
	return {}

# Lift the dragged spirit into a ghost orb that follows the finger (IGNOREs input, rides above the cards).
func _begin_drag_ghost(gpos: Vector2) -> void:
	_drag["active"] = true
	_sel_orb = {}                       # starting a drag clears any Sell focus
	var px := _drag_source_px()
	_drag_ghost = _spirit_chip(String(_drag.get("kind", "")), int(_drag.get("tier", 1)), px, func() -> void: pass, false)
	_force_ignore(_drag_ghost)
	_drag_ghost.z_index = 200
	_drag_ghost.modulate = Color(1.0, 1.0, 1.0, 0.92)
	_drag_ghost.set_meta("ghost_px", px)
	content.add_child(_drag_ghost)
	_move_drag_ghost(gpos)
	Audio.play("button_tap", -6.0)

func _drag_source_px() -> float:
	var source := _drag.get("node", null) as Control
	if source != null and is_instance_valid(source):
		var size := source.get_global_rect().size
		if size.x > 0.0 and size.y > 0.0:
			return maxf(size.x, size.y)
	return clampf(_map_rect.size.x * 0.10, 48.0, 84.0)

func _move_drag_ghost(gpos: Vector2) -> void:
	if _drag_ghost == null or not is_instance_valid(_drag_ghost):
		return
	var px := float(_drag_ghost.get_meta("ghost_px", 64.0))
	_drag_ghost.global_position = gpos - Vector2(px, px) * 0.5

func _end_drag() -> void:
	if _drag_ghost != null and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	_drag_ghost = null
	_drag = {}

# Resolve a dropped drag at `gpos`. HAND spirit → a matching housed orb merges (place_merge), another matching
# hand orb merges in hand (hand_merge), else a map card's right drop zone places (place). HOUSED spirit → the
# in-hand column brings it out (unplace). Anything else snaps back (a soft tap).
func _resolve_drop(gpos: Vector2) -> void:
	var d := _drag
	if String(d.get("src", "")) == "hand":
		# onto a MATCHING housed orb → merge it up a tier on that map. A non-matching housed orb is NOT a
		# rejection: the strip is the map's drop zone, so fall through and PLACE into a free slot instead.
		for o in _placed_orbs:
			var pn: Control = o.node
			if not (is_instance_valid(pn) and pn.get_global_rect().grow(6.0).has_point(gpos)):
				continue
			if String(o.kind) == String(d.kind) and int(o.tier) == int(d.tier) and int(o.tier) < Habitat.MAX_TIER:
				if Habitat.place_merge(String(o.map_id), int(d.idx), int(o.idx)):
					_merge_fx(pn.get_global_rect().get_center())
					_after_habitat_action()
				else:
					_invalid_at(pn)
				return
			break                             # over a non-mergeable housed orb → place onto its map below
		# onto a MATCHING hand orb → merge the pair in hand
		for o in _hand_orbs:
			if int(o.idx) == int(d.idx):
				continue
			var hn: Control = o.node
			if not (is_instance_valid(hn) and hn.get_global_rect().grow(6.0).has_point(gpos)):
				continue
			if String(o.kind) == String(d.kind) and int(o.tier) == int(d.tier) and int(o.tier) < Habitat.MAX_TIER:
				if Habitat.hand_merge(String(d.kind), int(d.tier), int(o.idx), int(d.idx)):
					_merge_fx(hn.get_global_rect().get_center())
					_after_habitat_action()
				return
			break                             # over a non-matching hand orb → snap back below
		# onto a map card's right drop zone → place into a free slot
		for hit in select_hits:
			var card: Control = hit.node
			if not (is_instance_valid(card) and _card_dropzone(card).has_point(gpos)):
				continue
			var z := int(hit.z)
			var mid := String(G.MAPS[z].id)
			if not G.can_populate(z, unlocks, _gates()):
				_invalid_at(card)
			elif Habitat.is_full(mid):
				_invalid_at(card)
				FX.floating_text(self, gpos - Vector2(120, 60), "Full", Color(CREAM, 0.9), 26)
			elif Habitat.place(mid, int(d.idx)):
				Audio.play("tidy_poof", -3.0, 1.05)
				_after_habitat_action()
			return
		Audio.play("button_tap", -8.0)        # dropped on nothing — a soft snap-back
	elif String(d.get("src", "")) == "placed":
		if _hand_panel != null and is_instance_valid(_hand_panel) and _hand_panel.get_global_rect().has_point(gpos):
			if Habitat.unplace(String(d.map_id), int(d.idx)):
				Audio.play("tidy_poof", -3.0, 1.0)
				_after_habitat_action()
			return
		Audio.play("button_tap", -8.0)

# The right portion of a card — the generous drop zone for placing a spirit (a tap on the rest navigates).
func _card_dropzone(card: Control) -> Rect2:
	var r := card.get_global_rect()
	return Rect2(r.position.x + r.size.x * 0.58, r.position.y, r.size.x * 0.42, r.size.y)

# A still-tap on an orb SELECTS it (hand or housed) — the in-hand board's bottom info bar then reads its
# tier, and a housed selection also surfaces a Sell button there. Tapping the same orb again clears it.
func _on_orb_tap(d: Dictionary) -> void:
	var same := String(_sel_orb.get("src", "")) == String(d.get("src", "")) \
		and int(_sel_orb.get("idx", -2)) == int(d.get("idx", -1)) \
		and int(_sel_orb.get("z", -2)) == int(d.get("z", -1))
	if same:
		_sel_orb = {}
	else:
		_sel_orb = {"src": String(d.src), "idx": int(d.idx), "kind": String(d.kind), "tier": int(d.tier)}
		if String(d.src) == "placed":
			_sel_orb["z"] = int(d.z)
			_sel_orb["map_id"] = String(d.map_id)
	Audio.play("button_tap", -3.0)
	_refresh_picker()

func _merge_fx(at: Vector2) -> void:
	# the spirit merge gets the unified verb at a GENTLE intensity (squash + a soft bloom + a light
	# burst + the real merge sound) — no hitstop (the sentinel gate 9999 sits above any possible combo,
	# so the freeze never fires on the calm map) and no tier escalation (low constant tier 1). The verb
	# plays the merge sound now, so the old redundant `tidy_poof` poof is dropped (the placement poof
	# elsewhere still stands). The picker rebuilds the orbs after this, so no result node is passed.
	# the spirit merge runs the workbench-tuned MergeFx applier (resolved once in _ready) at a GENTLE
	# intensity 0.4 (a soft bloom + a light burst + the real merge sound) — no hitstop (the sentinel gate
	# 9999 sits above any possible combo, so the freeze never fires on the calm map) and no tier escalation
	# (low constant tier 1). No produced node + no neighbours (the picker rebuilds the orbs after this), so
	# null + [] are passed; the board is `self` for the (suppressed) punch.
	MergeFx.apply(self, null, at, 1, 0, [], self, _merge_opts, 0.4, 9999)
	FX.celebrate_at(self, at, "Merged!", STRAW)

func _invalid_at(node: Control) -> void:
	Audio.play("invalid_soft", -4.0)
	if is_instance_valid(node):
		FX.wobble(node)

# Sell the SELECTED spirit (its button lives in the in-hand board's info bar) — a housed one frees its map
# slot, an in-hand one drops from the hand; either way it pays SELL_PER_TIER × tier coins.
func _on_focus_sell() -> void:
	var src := String(_sel_orb.get("src", ""))
	if src == "":
		return
	var idx := int(_sel_orb.get("idx", -1))
	var got := int(Habitat.sell(String(_sel_orb.get("map_id", "")), idx)) if src == "placed" else int(Habitat.sell_hand(idx))
	Audio.play("button_tap", -2.0)
	if got > 0:
		FX.floating_reward(self, _screen_center(0.0), "coin", got, STRAW)
	_sel_orb = {}
	_after_habitat_action()

func _on_resident_info_pressed() -> void:
	if _sel_orb.is_empty():
		return
	_open_resident_ladder(String(_sel_orb.get("kind", "")), int(_sel_orb.get("tier", 1)))

func _open_resident_ladder(kind: String, mark_tier: int) -> void:
	if kind == "" or Overlay.is_open(self, "ResidentLadderOverlay"):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return
	Audio.play("button_tap", -4.0)
	var overlay := Overlay.mount(self, "ResidentLadderOverlay")
	var veil := ColorRect.new()
	veil.color = Color(DOCK_INK, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var pct: float = float((cfg.get("tiers", {}) as Dictionary).get("width_pct", 85.0))
	var width: float = get_viewport_rect().size.x * clampf(pct, 30.0, 100.0) / 100.0
	var dopts: Dictionary = Kit.tiers_opts_from_config(cfg)
	dopts["banner_text"] = Strings.t("ladder.title")
	dopts["make_content"] = func(d: Dictionary, px: float) -> Control:
		return _spirit_icon_node(String(d.get("kind", "")), int(d.get("tier", 1)), px)
	dopts["on_close"] = func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()

	var dialog: Control = Kit.tiers_dialog(_resident_ladder_entries(kind, mark_tier), width, dopts)
	cc.add_child(dialog)
	FX.pop_in(dialog)

func _resident_ladder_entries(kind: String, mark_tier: int) -> Array:
	var out: Array = []
	var seen_cap := _resident_seen_tier_cap(kind, mark_tier)
	for tier in range(1, G.RESIDENT_MAX_TIER + 1):
		out.append({
			"tier": tier,
			"seen": tier <= seen_cap,
			"marked": tier == mark_tier,
			"kind": kind,
		})
	return out

func _resident_seen_tier_cap(kind: String, mark_tier: int) -> int:
	var cap := clampi(mark_tier, 1, G.RESIDENT_MAX_TIER)
	for inst in Habitat.hand():
		if String(inst.get("kind", "")) == kind:
			cap = maxi(cap, int(inst.get("tier", 1)))
	for m in G.MAPS:
		var map_id := String(m.get("id", ""))
		for inst in Habitat.placed(map_id):
			if String(inst.get("kind", "")) == kind:
				cap = maxi(cap, int(inst.get("tier", 1)))
	return clampi(cap, 1, G.RESIDENT_MAX_TIER)

func _after_habitat_action() -> void:
	_update_hud()
	_refresh_picker()

# Repaint the place-picker in place (cards + hand column) after a habitat change, dropping a now-invalid Sell
# focus. A rebuild re-clamps (never resets) _select_scroll, so the scroll position is preserved.
func _refresh_picker() -> void:
	if _view != "select":
		return
	_sel_orb = _valid_sel()
	_build_select(false)

# Keep the selection only while it still points at a real spirit (a merge / sell / place / bring-out drops it).
func _valid_sel() -> Dictionary:
	if _sel_orb.is_empty():
		return {}
	var idx := int(_sel_orb.get("idx", -1))
	if String(_sel_orb.get("src", "")) == "placed":
		return _sel_orb if idx < Habitat.placed(String(_sel_orb.get("map_id", ""))).size() else {}
	return _sel_orb if idx < Habitat.hand().size() else {}

func _screen_center(dy: float) -> Vector2:
	return get_global_rect().get_center() + Vector2(0.0, dy)

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

# Scroll the in-hand orb grid by `dy` px, clamped to [0, _hand_scroll_max]. No-op when the hand fits.
func _scroll_hand_by(dy: float) -> void:
	if _hand_scroll_max <= 0.0 or _hand_panel == null or not is_instance_valid(_hand_panel):
		return
	var prev := _hand_scroll
	_hand_scroll = clampf(_hand_scroll + dy, 0.0, _hand_scroll_max)
	if is_equal_approx(_hand_scroll, prev):
		return
	var grid := _hand_panel.get_node_or_null("HandClip/HandGrid")
	if grid != null:
		(grid as Control).position.y = -_hand_scroll

func _map_tap(gpos: Vector2) -> void:
	# Residents live on their own screen now, so map taps resolve straight to spots / wandering spirits.
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
		FX.floating_text(self, at - Vector2(110, 64),
			Strings.t("map.spot.needs_level") % G.spot_unlock_level(z, k), Color(CREAM, 0.9), 30)
		return
	unlocks[String(spot.id)] = true
	FX.burst(self, at, STRAW, 18)
	Audio.play("level_complete", -6.0, 1.2)
	if Features.on("big_moment_shake"):
		FX.shake(self)
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
	var vv = content.find_child("VineMapView", true, false)
	if vv != null:
		veil = await _capture_region_veil(vv, k)
	_build_map(false)                     # rebuild IN PLACE (no whole-map pop-in) — only the veil should break
	if not veil.is_empty():
		FX.shatter_veil(self, veil["tex"], veil["bbox"], at - get_global_rect().position)
		if Features.on("big_moment_shake"):
			FX.shake(self)
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

# --- §1 residents: DORMANT legacy welcome shop + unlock gift helpers ----------------------
# Superseded by the unified habitat: the map now renders + manages the habitat (the spirits dock) and
# the nav routes to the Expedition dialog. This welcome-shop path is no longer reached in-game; it (and
# the resident_counts roster model it drives) is kept dormant and retires together with the economy pass.
# G.welcome_resident spends + adds + silently auto-merges two-of-a-kind; the population layer is rebuilt
# from that roster after each legacy buy.

# --- HUD & chrome -----------------------------------------------------------------------

func _build_hud() -> void:
	# the shared top bar (owner: one module — ★🪙💎 + Store + the S10 Lv chip
	# never move between scenes; the chip ticks via the module's refresh). The home
	# screen is the hub itself, so it does NOT pass `home` — the HUD's home chip is
	# redundant here and the level ring stands alone (item 2; the board still passes
	# `home` since its nav legitimately returns to the map).
	var hud := Hud.build(self, {
		# the water pill's + opens the water stall here too. Water is Save-backed (the shop grants through
		# Save), so the hub needs no water callbacks — the HUD refresh re-reads Save into the water pill,
		# and the board reads the banked water on its next open. (No live board on the hub to re-sync.)
		# tap the level badge -> the level screen (stars earned / needed for the next level)
		"on_level": func() -> void: LevelPopup.open(self)})
	coins_label = hud.coins
	diamonds_label = hud.diamonds
	level_label = hud.level
	_hud_refresh = hud.refresh
	_open_water = hud.open_water     # the water stall (free refill + 💎 fill) — same as the water pill's +
	_lv_panel = hud.lv_panel         # the top-left Lv chip — hidden on the place-picker (see _set_level_chip_visible)
	_hud_panels = [hud.wallet, hud.lv_panel]

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
	# match. Order: Map · Play. PLAY is the way into the garden/board (the prominent leaf). Shop opens
	# from the top pills' "+", and Settings/Piggy live in the LiveOps side rail (_build_liveops_rail).
	var sb := Look.safe_bottom(self)
	var edge := _hud_edge_margin_px()
	# The flanking Map button is the SHARED configurable home button in its ROUNDED-RECT form (icon + "Map"
	# label inside the badge — ui_mock2); Play is the big CIRCULAR orange CTA (the only round bottom button).
	var nav := NavBar.build(self, [
		# Map — the place-picker (atlas). A labeled rounded-rect badge (built via `make` to pass shape:"rect").
		{"make": _make_map_button, "label": Strings.t("map.nav.map")},
		# (Residents management folded into the place-picker — the map view's right-hand in-hand column +
		# each map's housed strip — so there is no longer a standalone Residents button or dialog.)
		# Play — the way into the garden/board. The big orange play disc (board+acorn mark, no label).
		{"make": _make_play_button, "label": Strings.t("map.nav.play")}],
		{"side": edge, "bottom": edge})
	for b in nav.buttons:
		_chrome_nodes.append(b)
	_chrome_nodes.append(nav.row)
	_refresh_play_cta()                  # confirm the merged CTA's Play↔Restore state for the open map
	# the Play disc breathes so the primary action reads — kept whether it shows board or vine. (Target by
	# identity, not nav index: the Residents button shifts Play's position in the row.)
	if is_instance_valid(_play_btn):
		FX.breathe_once(_play_btn)
	# the LiveOps rail: Settings · Daily · Vault · Inbox, pinned TOP-right below the wallet (home.png). The Piggy
	# bank lives here now (moved off the bottom bar); its claimable ready-pip is attached there. (The
	# premium pill's "new offer" red dot and the rail "Free" faucet were removed — Free moved to the shop.)
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
	opts["px"] = _hud_button_px()
	opts["shape"] = "rect"                    # the rounded-rect badge (not a disc)
	opts["icon_scale"] = HOME_ICON_ONLY_SCALE
	var HC: GDScript = load(HOME_CHROME_PATH)
	return Kit.home_button({"icon": HC.ICON_MAP, "caption": "", "tooltip": Strings.t("map.nav.map"), "action": open}, opts)

# Show the Expedition rail button only when the open map is ready for the acquisition loop.
func _refresh_residents_btn() -> void:
	if _residents_btn != null and is_instance_valid(_residents_btn):
		_residents_btn.visible = G.can_populate(_map_idx, unlocks, _gates())

# --- the spirit DOCK constants (shared by the place-picker's housed strip + in-hand column) ------
# The map view IS the residents surface now: the place-picker carries every completed map's housed orbs
# as a right-side STRIP and the in-hand spirits as a right-hand COLUMN. Spirits are dragged between them
# (a map places, a match merges, the hand column brings out); a tap on a housed orb focuses it for Sell.
# (There is no standalone Residents button or modal dialog any more.)
const DOCK_INK := Color("#43352B")
const DOCK_PARCH := Color("#F3E7CE")
const DOCK_STRAW := Color("#D9B679")

static var _resident_content_cache: Dictionary = {}
static func _resident_content_tex(path: String) -> Texture2D:
	if _resident_content_cache.has(path):
		return _resident_content_cache[path]
	var tex: Texture2D = load(path)
	var result: Texture2D = tex
	if tex != null:
		var img := tex.get_image()
		if img != null:
			var used := img.get_used_rect()
			var full := Vector2i(tex.get_width(), tex.get_height())
			if used.size.x > 0 and used.size.y > 0 and (used.position != Vector2i.ZERO or used.size != full):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(used)
				result = at
	_resident_content_cache[path] = result
	return result

func _spirit_chip(kind: String, tier: int, px: float, on_tap: Callable, show_badge: bool = true) -> Control:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(px, px)
	btn.size = Vector2(px, px)
	btn.pressed.connect(on_tap)
	var path := G.resident_art(kind, tier)
	var has_art := path != "" and ResourceLoader.exists(path)
	if has_art:
		var t := TextureRect.new()
		t.texture = load(path)                            # art is pre-centered (re-cut), so display it as-is
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(t)
	else:
		var disc := Panel.new()
		disc.name = "MapResidentFallbackDisc"
		disc.set_anchors_preset(Control.PRESET_FULL_RECT)
		var ds := StyleBoxFlat.new()
		ds.bg_color = Color("#F6B659", 0.96)
		ds.set_corner_radius_all(int(px / 2.0))
		ds.set_border_width_all(maxi(2, int(round(px * 0.075))))
		ds.border_color = Color("#8D5A26", 0.72)
		disc.add_theme_stylebox_override("panel", ds)
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(disc)
	if not show_badge:
		return btn                                       # the in-hand board reads tier from its info bar, not a per-orb badge
	var badge := Label.new()
	badge.text = "t%d" % tier
	badge.name = "MapResidentTierBadge"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", int(clampf(px * (0.38 if has_art else 0.46), 14.0, 24.0)))   # scales with the orb size
	badge.add_theme_color_override("font_color", DOCK_INK)
	badge.add_theme_color_override("font_outline_color", DOCK_PARCH)
	badge.add_theme_constant_override("outline_size", 3)
	badge.custom_minimum_size = Vector2(px * (0.48 if has_art else 1.0), px * (0.34 if has_art else 1.0))
	badge.size = badge.custom_minimum_size
	badge.position = Vector2(px - badge.size.x - 1.0, 0.0) if has_art else Vector2.ZERO
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)
	return btn

# A NEW-STYLE board CELL holding a spirit — built from Kit.slot_cell (the SAME cell the reskinned merge board
# + bag use), with the spirit's icon (content-cropped → uniform + centered) as its filled content. The cell
# IGNOREs the mouse (the single input surface hit-tests it); `selected` draws the board's shared focus ring.
func _spirit_cell(Kit: GDScript, bag_opts: Dictionary, kind: String, tier: int, px: float, selected: bool) -> Control:
	if Kit == null:
		return _empty_cell(Kit, bag_opts, px)
	var cell: Control = Kit.slot_cell({"state": "filled",
		"make_content": func(pp: float) -> Control: return _spirit_icon_node(kind, tier, pp)}, bag_opts)
	cell.custom_minimum_size = Vector2(px, px)
	_force_ignore(cell)
	if selected:
		cell.add_child(_resident_focus_ring())
	return cell

# An EMPTY new-style board cell (Kit.slot_cell, no spirit) so the in-hand grid reads as a board of cells.
func _empty_cell(Kit: GDScript, bag_opts: Dictionary, px: float) -> Control:
	if Kit == null:
		var c := Panel.new()
		c.custom_minimum_size = Vector2(px, px)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return c
	var cell: Control = Kit.slot_cell({"state": "empty"}, bag_opts)
	cell.custom_minimum_size = Vector2(px, px)
	_force_ignore(cell)
	return cell

# The spirit's icon for a cell's content — cropped to its opaque bounds (the board pipeline) so every creature
# fills the cell uniformly + centered. `px` is the fitted content size slot_cell asks for.
func _spirit_icon_node(kind: String, tier: int, px: float) -> Control:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(px, px)
	t.size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := G.resident_art(kind, tier)
	if art != "" and ResourceLoader.exists(art):
		t.texture = _resident_content_tex(art)
	return t

func _resident_focus_ring() -> Control:
	var ring := FocusRing.new()
	ring.name = "ResidentFocusRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = 8
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var o := _focus_ring_opts()
	if not o.is_empty():
		ring.color = o.color
		ring.halo_color = o.halo_color
		ring.halo_a = o.halo_a
		ring.arm_frac = o.arm_frac
		ring.thick_frac = o.thick_frac
		ring.pad_frac = o.pad_frac
		ring.halo = o.halo
	ring.queue_redraw()
	return ring

func _focus_ring_opts() -> Dictionary:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return {}
	return Kit.focus_ring_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))

func _dock_label(text: String, size: int, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", DOCK_INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if bold:
		l.add_theme_color_override("font_outline_color", DOCK_PARCH)
		l.add_theme_constant_override("outline_size", 2)
	return l

# The EXPEDITION entry: the Load out as an overlay dialog (the start-expedition dialog). Spend coins on
# stackable boosts, then Set off → the Rush (a scene) → Trade → back to the map with spirits in hand.
# Replaces the standalone Loadout scene; built over a veil with the same look as the other map dialogs.
func _open_expedition() -> void:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return
	var equip := {"v": {}}                # boxed so the toggle callbacks can mutate the chosen boosts
	var overlay := Overlay.mount(self, "ExpeditionOverlay")
	var veil := ColorRect.new()
	veil.color = Color(DOCK_INK, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)
	var width: float = minf(get_viewport_rect().size.x * 0.9, 540.0)
	var switch_h := 40.0
	var ui_refs := {"cost_chip": null, "go": null}
	var refresh_state := func() -> void:
		var cost_chip := ui_refs.get("cost_chip", null) as Button
		if is_instance_valid(cost_chip):
			cost_chip.text = "Cost %d" % Explore.start_cost(equip.v)
		var go_btn := ui_refs.get("go", null) as Button
		if is_instance_valid(go_btn):
			go_btn.disabled = not Explore.can_start(equip.v)
	var make_loadout_toggle := func(boost_id: String) -> Callable:
		return func(want: bool) -> void:
			equip.v[boost_id] = want
			Audio.play("button_tap", -2.0)
			refresh_state.call()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(width - 64.0, 0)
	var loadout_icons := {
		"time": "star",
		"drops": "chest",
		"calm": "daisy",
		"lucky": "leaf",
		"focus": "board",
	}
	# each boost is a shared toggle card (parchment + the kit switch)
	for it in Explore.LOADOUT:
		var id := String(it.id)
		var card: Control = Kit.toggle_card({
			"icon": String(loadout_icons.get(id, "leaf")),
			"title": String(it.name),
			"body": String(it.eff),
			"cost": int(it.cost),
			"value": bool(equip.v.get(id, false)),
			"on_toggle": make_loadout_toggle.call(id),
		}, {"label_font": 19, "body_font": 15, "switch_h": switch_h, "card_art": true})
		col.add_child(card)
	# total set-off cost as a shared cream amount chip
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 10)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	var cost_chip: Button = Kit.amount_chip("coin", "Cost %d" % Explore.start_cost(equip.v))
	ui_refs["cost_chip"] = cost_chip
	chips.add_child(cost_chip)
	col.add_child(chips)
	# actions: Set off (green) + Cancel (cream) — the shared pill buttons
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var go: Button = Kit.pill_button("Set off", {"bg": "green", "art": true, "font": 22, "enabled": Explore.can_start(equip.v)})
	ui_refs["go"] = go
	go.pressed.connect(func() -> void:
		var cost := Explore.start_cost(equip.v)        # base minimum + boosts — the acquisition coin sink
		if cost > Save.coins():
			return
		if cost > 0:
			Save.spend(cost, "expedition")
		Explore.begin_run(equip.v)
		Audio.play("button_tap", -2.0)
		SceneWarm.go(get_tree(), "res://engine/scenes/ExploreRush.tscn"))
	actions.add_child(go)
	var cancel: Button = Kit.pill_button("Cancel", {"bg": "cream", "art": true, "font": 22})
	cancel.pressed.connect(func() -> void: overlay.queue_free())
	actions.add_child(cancel)
	col.add_child(actions)
	# the SHARED standard dialog face (workbench-tuned border / banner / ✕), as mail/shop/settings wear
	var fo: Dictionary = Kit.dialog_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	fo["banner_text"] = "Load out"
	fo["banner_icon_id"] = "leaf"
	fo["on_close"] = func() -> void: overlay.queue_free()
	fo["list_max_h"] = get_viewport_rect().size.y * 0.7
	var dialog: Control = Kit.dialog_frame(col, width, fo)
	cc.add_child(dialog)
	FX.pop_in(dialog)

# (The dormant legacy residents SHOP — `_open_residents_shop` + its `_buy_resident` welcome handler — was
# REMOVED: the live residents surface is the Expedition (acquire) → Habitat dialog (place/sell/yield). The
# welcome_resident MODEL stays for the unlock-gift grant + the pacing sim.)

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
		opts["icon_scale"] = HOME_ICON_ONLY_SCALE
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
	b.offset_left = _rail_margin_px
	b.offset_right = _rail_margin_px + px
	b.offset_bottom = -(sb + _rail_margin_px)
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
const HOME_ICON_ONLY_SCALE := 0.72
var _home_opts := {}            # the shared home-button style (loaded once per rail build)
var _rail_px := RAIL_PX         # the shared home-button size (drives the place-picker back button; full size)
var _rail_disc_px := RAIL_PX    # the rail's OWN reduced disc size (RAIL_SCALE × shared) — smaller than the nav
var _rail_margin_px := RAIL_MARGIN
var _rail_opts := {}            # _home_opts with px overridden to _rail_disc_px (the rail discs only)

func _view_size() -> Vector2:
	if is_inside_tree():
		var v := get_viewport_rect().size
		if v.x > 0.0 and v.y > 0.0:
			return v
	return Design.size()

func _hud_layout() -> Dictionary:
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return {"button_w_frac": RAIL_PX / Design.size().x, "edge_margin_px": RAIL_MARGIN}
	return Kit.hud_layout_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))

func _hud_edge_margin_px() -> float:
	return float(_hud_layout().get("edge_margin_px", RAIL_MARGIN))

func _hud_button_px() -> float:
	return maxf(1.0, roundf(_view_size().x * float(_hud_layout().get("button_w_frac", 0.15))))

func _wallet_bottom_y() -> float:
	if _hud_panels.size() > 0 and _hud_panels[0] is Control:
		var wallet := _hud_panels[0] as Control
		if wallet.get_child_count() > 0 and wallet.get_child(0) is Control:
			var first := wallet.get_child(0) as Control
			var rect := first.get_global_rect()
			if rect.size.y > 0.0:
				return rect.end.y
			var h := first.custom_minimum_size.y
			if h > 0.0:
				return wallet.get_global_rect().position.y + h
	return Look.safe_top(self) + 16.0

func _build_liveops_rail() -> void:
	# Load the shared home-button style ONCE (the same transform the bottom nav + workbench read).
	var Kit: GDScript = load(KIT_PATH)
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH) if Kit != null else {}
	_home_opts = Kit.home_button_opts_from_config(cfg) if Kit != null else {}
	var layout: Dictionary = Kit.hud_layout_opts_from_config(cfg) if Kit != null else {
		"button_w_frac": RAIL_PX / Design.size().x,
		"edge_margin_px": RAIL_MARGIN,
		"top_band_h_frac": 0.15,
	}
	_rail_px = maxf(1.0, roundf(_view_size().x * float(layout.get("button_w_frac", 0.15))))
	_rail_margin_px = float(layout.get("edge_margin_px", RAIL_MARGIN))
	# the rail tiles now use the same screen-width percentage as Map / Back / board Bag+Home.
	_rail_disc_px = _rail_px
	_rail_opts = _home_opts.duplicate()
	_rail_opts["px"] = _rail_disc_px
	_rail_opts["shape"] = "rect"   # the rail tiles are ROUNDED-RECT badges (icon over label inside), not discs (ui_mock2)
	_rail_opts["icon_scale"] = HOME_ICON_ONLY_SCALE
	# the workbench-tuned badge offset (px past the disc's top-right): pulls the red dot / count snug to the
	# rail disc instead of floating off its transparent art margin (negative tucks it IN over the edge).
	var bover := Vector2(float(_home_opts.get("badge_dx", -26.0)), float(_home_opts.get("badge_dy", -26.0)))
	# the workbench-tuned badge SIZE (dot diameter / count font) — the same opts the home-button preview uses.
	var bopts := {"dot_px": int(_home_opts.get("badge_dot_px", 14)), "num_size": int(_home_opts.get("badge_num_size", 14))}
	var step := _rail_disc_px + RAIL_CAP_H + RAIL_GAP
	var top := _wallet_bottom_y() + _rail_margin_px
	var slot := 0
	var HC: GDScript = load(HOME_CHROME_PATH)
	# Settings — first rail tile, using the same builder/placement as the rest of the side rail.
	_gear = _rail_button(HC.ICON_SETTINGS, Strings.t("settings.title"), func() -> void:
		Audio.play("button_tap", -2.0)
		_open_settings())
	_place_rail(_gear, top, slot, step); slot += 1
	# Daily — opens the login calendar on demand; badge when today is unclaimed.
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
	var open_expedition := func() -> void:
		Audio.play("button_tap", -2.0)
		_open_expedition()
	var expedition := _rail_button(HC.ICON_EXPEDITION, "Expedition", open_expedition)
	_residents_btn = expedition
	_place_rail(expedition, top, slot, step); slot += 1
	_refresh_residents_btn()
	_refresh_liveops_badges()

# One rail button = the SHARED configurable home button (Kit.home_button): the cream/gold disc + icon +
# caption tab, tuned in the workbench. `sparkle` opts the disc into the engine-drawn glow/twinkle. Falls
# back to a plain cream disc when the kit can't load. Parented to self + tracked as chrome.
func _rail_button(icon_id: String, label: String, cb: Callable, sparkle := false, extra_spec: Dictionary = {}) -> Button:
	var Kit: GDScript = load(KIT_PATH)
	var b: Button
	if Kit != null:
		var spec := {"icon": icon_id, "caption": "", "tooltip": label, "action": cb, "sparkle": sparkle}
		for k in extra_spec.keys():
			spec[k] = extra_spec[k]
		b = Kit.home_button(spec, _rail_opts)
	else:
		b = Button.new()                          # defensive fallback (kit absent): a bare disc
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = label
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
	b.offset_right = -_rail_margin_px
	b.offset_left = -_rail_margin_px - _rail_disc_px
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
	# Unified habitat: the free unlock spirit lands in the HAND so it shows + is placeable on the map.
	# (claim_unlock_reward also seats it in the now-dormant legacy roster; that copy retires with the economy pass.)
	var unlock_spirit := String(rew.get("spirit", ""))
	if unlock_spirit != "":
		Habitat.hand_add(unlock_spirit)
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
	var overlay := Overlay.mount(self, "UnlockRewardOverlay")
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
	var entries: Array = []
	if coins > 0:
		entries.append({
			"icon": "coin",
			"title": Strings.t("map.unlock.coins"),
			"body": "",
			"chip": {"icon": "coin", "text": "+%d" % coins},
		})
	if gems > 0:
		entries.append({
			"icon": "gem",
			"title": Strings.t("map.unlock.diamonds"),
			"body": "",
			"chip": {"icon": "gem", "text": "+%d" % gems},
		})
	if spirit != "":
		entries.append({
			"icon": "gift",
			"title": _resident_name(z, spirit),
			"body": Strings.t("map.welcome.new_friend"),
			"chip": {"icon": "gift", "text": "+1"},
		})
	var width: float = minf(get_viewport_rect().size.x * 0.86, 520.0)
	var opts: Dictionary = Kit.dialog_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	opts["banner_text"] = Strings.t("map.unlock.title")
	opts["banner_icon_on"] = false
	opts["got_it"] = Strings.t("map.unlock.collect")
	opts["on_close"] = func() -> void: dismiss.call()
	var dialog: Control = Kit.mail_dialog(entries, width, opts)
	cc.add_child(dialog)
	FX.pop_in(dialog)

# A fixed-size resident icon: the type's art when present, else a soft cream disc (signature spirits ship
# without art yet — this keeps the row reading as "a spirit" rather than a broken/empty box).
func _spirit_icon(type_id: String, px: float) -> Control:
	var path := G.resident_art(type_id)
	if path != "" and ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)                            # art is pre-centered (re-cut), so display it as-is
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
		var map_gem_done := func() -> void:
			if is_instance_valid(self):
				_update_hud()
		FX.reward_arrival(self, at + Vector2(0, dy), "gem", gems, Color("#A9C7E8"), diamonds_label, map_gem_done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "map_task_reward")
		dy += 34
	if coins > 0:
		var map_coin_done := func() -> void:
			if is_instance_valid(self):
				_update_hud()
		FX.reward_arrival(self, at + Vector2(0, dy), "coin", coins, Color("#E3B23C"), coins_label, map_coin_done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "map_task_reward")
	FX.floating_text(self, at - Vector2(0, 40), Strings.t("map.reward.place_restored"), CREAM, 24)
	if gems <= 0 and coins <= 0:
		_update_hud()

# Re-read every chrome badge's actionable state in one go (called on map nav). Cheap, idempotent.
func _refresh_chrome_badges() -> void:
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
	SettingsUI.open(self)               # the shared card (music/sounds)

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
