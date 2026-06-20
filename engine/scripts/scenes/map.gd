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
const Ads = preload("res://engine/scripts/core/ads.gd")                      # rewarded ads — the free-gem rail (T43); the 2× coin doubler moved to board.gd (quest reward)
const Login = preload("res://engine/scripts/core/login.gd")                  # T45: the forgiving daily-login calendar (auto-popup gate)
const LoginUI = preload("res://engine/scripts/ui/login.gd")                  # T45: the diegetic login-calendar popup surface
const Shop = preload("res://engine/scripts/ui/shop.gd")                      # chrome: the Store-badge query (starter_available)
const SettingsUI = preload("res://engine/scripts/ui/settings.gd")            # the shared Settings card (gear + board bottom bar)
const Debug = preload("res://engine/scripts/ui/debug.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Design = preload("res://engine/scripts/core/design.gd")
const Pal = Game.PALETTE
# The grove UI kit (a game-side tool): lazy-loaded so the engine never hard-depends on it — the unowned
# home spot's restore-cost disc builds through it from the workbench-saved style. Missing → baked fallback.
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"

const SPOT_NAME_DY := 50.0   # spot name/price stack baseline below the plot point

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

# --- map-select cards — the painted place-picker kit (map_asset.png, §8 / map.png preview) ---------
# The shipped frames REPLACE the code-drawn card look: an OPEN place wears a glowing gold frame
# (card_active) over its locale art; a LOCKED place is the dark baked panel (card_locked — its
# scene + flower-lock medallion baked in) under an "after <prev>" line; the restore count rides a
# cream pill (pill_left) on the open card's lower edge; a round back arrow (back_arrow) returns to
# the map you were viewing. All are sliced kit (ui/map/*) with code-drawn fallbacks (the §8 fog
# veil among them) so the picker never blanks when an asset is missing.
const CARD_ACTIVE := "map/card_active.png"
const CARD_LOCKED := "map/card_locked.png"
const CARD_PILL := "map/pill_left.png"
const CARD_BACK := "map/back_arrow.png"          # the back button's arrow mark (on the shared home disc)
const CARD_ASPECT := 1027.0 / 352.0       # card_active's aspect — cards size to it so the gold frame never distorts
const CARD_PILL_ASPECT := 293.0 / 102.0   # pill_left's aspect
# the locale art insets this fraction of card WIDTH inside the gold frame. Pixel-measured from
# card_active.png: the gold band's straight inner edge is ~0.054w and its outer edge ~0.031w, so the
# art edge must sit INSIDE the band (≤0.054w) to tuck under the gold with no sky gap — 0.045w lands
# mid-band. Its corners are ROUNDED to CARD_ART_RADIUS so they follow the frame's rounded corner
# (a square corner at this inset would poke past the gold arc into the transparent corner).
const CARD_FRAME_INSET := 0.045
const CARD_ART_RADIUS := 0.058            # the art's rounded-corner radius, as a fraction of the art rect's WIDTH
# Rounds the locale art's 4 corners so they nest inside the gold frame's rounded interior (the frame
# is alpha-0 in its corners, so a square art corner would show as a nub there). UV-space rounded-rect
# alpha mask; `rx` is the corner radius in UV.x, `aspect` the art rect's width/height (so corners stay
# circular in pixels). A soft 1-step falloff keeps the edge clean.
const _ART_CLIP_SHADER := "shader_type canvas_item;
uniform float rx = 0.06;
uniform float aspect = 3.0;
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float ry = rx * aspect;
	float dx = max(rx - min(UV.x, 1.0 - UV.x), 0.0);
	float dy = max(ry - min(UV.y, 1.0 - UV.y), 0.0);
	float d = length(vec2(dx, dy / aspect));
	col.a *= 1.0 - smoothstep(rx - 0.006, rx, d);
	COLOR = col;
}"
var _art_clip: Shader

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
var resident_hits: Array = []    # [{node, z, type}] — the "welcome a spirit" panel's kind rows (residents §1)
var _press := Vector2.ZERO       # last press point (still-tap resolution)

var _chrome_nodes: Array = []    # bottom chrome (garden CTA, gear, shop, atlas)
var _weather: Control = null     # ambient weather layer — belongs to a MAP; hidden on the place-picker
var _shop_btn: Button            # the Store nav button — kept as the anchor for the Store "new offer" badge
var _select_back: Button         # the place-picker's bottom-left back arrow (shown only in the select view)
var level_label: Label
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

	# T45 (§18): on the day's FIRST hub open, auto-show the login calendar ONCE. The hub map is the
	# surface the player reliably hits first (fresh boot lands on the frontier — the hub when nothing
	# is open yet — and the board's Home button returns here). Gated + deferred so it never fires on a
	# cold first launch (see _maybe_login_popup). (The §14 shop spotlight that used to share this
	# first-hub-open beat was removed 2026-06-18 — docs/BACKLOG.md "Restore the shop FTUE".)
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

func map_stars_left(z: int) -> int:
	return G.map_stars_left(z, unlocks)

func _frontier_map() -> int:
	return G.frontier_map(unlocks, _gates())

func _is_cheapest_open(z: int, k: int) -> bool:
	return G.is_cheapest_open(z, k, unlocks)

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

func _open_select() -> void:
	_view = "select"
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

# (The 2× rewarded-ad DOUBLER lived here, triggered by the now-removed hub yield-collect. It was
# RE-HOMED to the quest coin reward on the board — see board.gd `_maybe_offer_2x` — since the map
# scene no longer has a coin faucet to double. The `collect_2x` ad id is unchanged.)

# --- THE MAP VIEW (grove_spec §3) -------------------------------------------------------
# One self-contained image fills the area below the HUD; the spots sit directly on
# it at spot.pos (a fraction of the fitted image rect). Owned spots draw furniture
# sprites. The whole view lives under `content` — every child IGNOREs (single input
# surface).

func _build_map() -> void:
	for c in content.get_children():
		c.queue_free()
	spot_hits.clear()
	select_hits.clear()
	resident_hits.clear()
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
	var frame := _build_map_base(z, home_dict)   # §16 overgrown home base · the map's bg · or flat fallback
	# z-order parity with the pre-unify renderer (so the look is unchanged): a §16 home seats its reveals
	# /badges UNDER the ambient wanderers + title plank; a cutout map seats its sprites OVER them.
	if has_home:
		_seat_spots(z, home_dict, frame)
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
	content.add_child(_map_title_plank(z))
	if not has_home:
		_seat_spots(z, home_dict, frame)
	# §1 residents: a COMPLETED map invites the player to WELCOME spirits (the population sub-game)
	if G.can_populate(z, unlocks, _gates()):
		_add_welcome_panel(z)
	FX.pop_in(content)

# Seat one tap-hit per spot, index-aligned with G.MAPS[z].spots (the buy flow + tests rely on this).
# A §16 home (home != {}) renders the per-building reveal/badge into `frame`; any other map renders the
# cutout sprite/ghost via _make_spot. Either way the hit lands in content + spot_hits.
func _seat_spots(z: int, home: Dictionary, frame: Control) -> void:
	var has_home := not home.is_empty()
	var by_id := _home_buildings(home) if has_home else {}
	for k in G.MAPS[z].spots.size():
		var hit: Control = _build_home_spot(z, k, home, frame, by_id) if has_home else _make_spot(z, k, _map_rect)
		content.add_child(hit)
		spot_hits.append({"node": hit, "z": z, "k": k})

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
	var spot: Dictionary = G.MAPS[z].spots[k]
	var p = b.get("pos", [0.5, 0.5]) if b != null else [0.5, 0.5]
	var ctr := _map_rect.position + Vector2(float(p[0]), float(p[1])) * _map_rect.size
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return _home_badge_baked(z, k, b)             # engine fallback: the central spot-routing buys it
	var opts: Dictionary = Kit.home_unlock_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	var d := _map_rect.size.x * float(opts.get("disc_pct", 16.0)) / 100.0   # diameter as a % of the map width
	opts["px"] = d
	opts["calm"] = FX.calm()                          # reduced-motion: freeze the sparkle to a static glow
	# sparkle is opt-in via the workbench (glow/twinkle default 0 → no sparkle); when tuned up it draws the
	# eye to a restorable spot. The overlay is mouse-ignored (and _force_ignore below seals the invariant).
	var btn: Button = Kit.home_unlock_button({"cost": int(spot.cost), "icon": "star", "sparkle": true}, opts)
	btn.size = Vector2(d, d)
	btn.position = ctr - Vector2(d, d) * 0.5
	_force_ignore(btn)                                # the map is ONE input surface; the central router buys it
	return btn

# Force a control subtree mouse-transparent — the map routes every spot tap through its single input
# surface, so any seated affordance (the kit unlock disc) must not eat the press before _map_tap.
func _force_ignore(n: Control) -> void:
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		if c is Control:
			_force_ignore(c)

# The baked code-drawn restore badge — the engine fallback when the grove kit can't load. Decoration only
# (mouse-ignored); the spot's tap is then routed centrally via _map_tap → spot_hits → _on_spot_tap.
func _home_badge_baked(z: int, k: int, b) -> Control:
	var spot: Dictionary = G.MAPS[z].spots[k]
	var p = b.get("pos", [0.5, 0.5]) if b != null else [0.5, 0.5]
	var ctr := _map_rect.position + Vector2(float(p[0]), float(p[1])) * _map_rect.size
	var d := _map_rect.size.x * 0.16                  # badge diameter relative to the map
	var node := Control.new()
	node.size = Vector2(d, d)
	node.position = ctr - Vector2(d, d) * 0.5
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the disc — the sliced round cost badge. Falls back to the legacy badge.png disc (ui/map/).
	var disc_kit := Look.kit("map/badge_cost.png")
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.texture = load(disc_kit) if ResourceLoader.exists(disc_kit) else load(Look.kit("map/badge.png"))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(bg)
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
	# the pill IS the restore read; a fully-restored map pays MAP_TASK_REWARD once — the gift rides the
	# pill's "restored" end-state (idempotent via a per-map flag, so revisiting never re-pays).
	if map_spots_done(z):
		_grant_map_task_reward(z)
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
	# the GREEN fill bar inside the groove, clipped to the progress fraction (paid / total star cost).
	var total := 0
	for s in G.MAPS[z].spots:
		total += int(s.cost)
	var left := map_stars_left(z)
	var frac := 1.0 if total <= 0 else clampf(float(total - left) / float(total), 0.0, 1.0)
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
	# left mark (mockup: one flower + text). The number is the map's TOTAL remaining star cost (every
	# unowned spot), not just the next one — see map_stars_left. The label fills the area to the RIGHT of
	# the baked flower and centers itself in that remaining span, so the text never overlaps the flower.
	var lbl := Label.new()
	lbl.text = tr("restored ✿ 🎁") if map_spots_done(z) else tr("%d to restore this place") % left
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
		lbl.text = tr("✿ restored 🎁")
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", STRAW)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plank.add_child(lbl)
	else:
		plank.add_child(_stars_left_row(map_stars_left(z), STRAW, 22))   # gold star sprite + count
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
		# Only unowned (gated or buyable) spots reach here — the price-pin + name.
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
		var name_l := _lbl(tr(spot.name), 24, CREAM)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(name_l)
		item.add_child(stack)
		if z == _frontier_map() and _is_cheapest_open(z, k):
			FX.breathe_once(item)
	return item

# --- THE MAP-SELECT VIEW (grove_spec §3) ------------------------------------------------
# A clean atlas of every map as a card: thumbnail + name + state line. Tapping an
# unlocked card opens that map; a locked card wobbles. Lives under `content` —
# every child IGNOREs (single input surface).

func _build_select() -> void:
	for c in content.get_children():
		c.queue_free()
	spot_hits.clear()
	select_hits.clear()
	resident_hits.clear()
	var view := get_viewport_rect().size
	var top := 96.0 + Look.safe_top(self)
	# ONE wide painted card per row — a vista per place (map.png place-picker). No header: the HUD
	# wallet + the framed cards carry the read. Cards size to the gold frame's ASPECT (so the frame
	# never distorts) and the stack centers in the band between the HUD and the floor back-arrow; if
	# the natural height overflows the band, every card shrinks uniformly to fit. No ScrollContainer
	# (the single-input-surface model has none); cards are positioned + hit-tested directly.
	var n := G.MAPS.size()
	var side := 46.0
	var card_w := view.x - side * 2.0
	var sep := 18.0
	var band_top := top + 16.0
	var band_bot := view.y - (Look.safe_bottom(self) + 150.0)   # leave the bottom-left back arrow its room
	var band_h := band_bot - band_top
	var card_h := card_w / CARD_ASPECT
	var total_h := card_h * float(n) + sep * float(maxi(n - 1, 0))
	if total_h > band_h:                                        # shrink uniformly so all cards fit the band
		card_h *= band_h / total_h
		card_w = card_h * CARD_ASPECT
		total_h = card_h * float(n) + sep * float(maxi(n - 1, 0))
	var x := (view.x - card_w) * 0.5
	var y := band_top + maxf(0.0, (band_h - total_h) * 0.5)
	for z in n:
		var card := _make_card(z, card_w, card_h)
		card.position = Vector2(x, y)
		card.size = Vector2(card_w, card_h)
		content.add_child(card)
		select_hits.append({"node": card, "z": z})
		y += card_h + sep
	if _select_back != null and is_instance_valid(_select_back):
		_select_back.visible = true
	FX.pop_in(content)

# One map card (the painted place-picker, map.png). OPEN → the locale art inside the glowing gold
# frame (card_active) + a "★ N left"/"restored" pill on its lower edge; LOCKED → the dark baked
# panel (card_locked, its flower-lock medallion + scene baked in) under an "after <prev>" line. The
# card is a plain Control sized to the gold frame's aspect, so the frame fills it without distortion.
# `card_h` is always > 0 from _build_select (the one-per-row banner). Every node IGNOREs the mouse.
func _make_card(z: int, card_w: float, card_h: float = 0.0) -> Control:
	var open := map_unlocked(z)
	var done := map_spots_done(z)
	var card := Control.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if open:
		_dress_open_card(z, card, card_w, card_h, done)
	else:
		_dress_locked_card(z, card, card_w, card_h)
	return card

# An OPEN place: the locale art (its painted thumbnail, or the §16 home clean art, or a meadow
# fallback) fills the hollow of the gold frame (card_active), drawn OVER it so the frame's
# transparent centre lets the art show and its border frames it. The restore count rides a pill on
# the lower edge.
func _dress_open_card(z: int, card: Control, card_w: float, card_h: float, done: bool) -> void:
	var inset := card_w * CARD_FRAME_INSET
	var inner := Control.new()
	inner.position = Vector2(inset, inset)
	inner.size = Vector2(card_w - inset * 2.0, card_h - inset * 2.0)
	inner.clip_contents = true
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	var art_path := _card_art_path(z)
	if art_path != "":
		var t := TextureRect.new()
		t.texture = load(art_path)
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.material = _art_clip_material(inner.size)   # round the art's corners to nest in the gold frame
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(t)
	else:
		inner.add_child(_meadow_fill(true))
	# the gold frame OVER the art — card sized to its aspect, so a plain SCALE keeps the border crisp.
	var frame_path := Look.kit(CARD_ACTIVE)
	if ResourceLoader.exists(frame_path):
		var fr := TextureRect.new()
		fr.texture = load(frame_path)
		fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fr.stretch_mode = TextureRect.STRETCH_SCALE
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(fr)
	else:
		card.add_child(_code_card_border(card_w, card_h))
	_add_count_pill(z, card, card_w, card_h, done)

# A LOCKED place: the dark baked panel (card_locked — scene + flower-lock medallion baked in) fills
# the card, with the "after <prev>" prerequisite line low over it. When the art is missing, fall
# back to a meadow panel under the code-drawn §8 fog veil so the horizon still reads as veiled.
func _dress_locked_card(z: int, card: Control, card_w: float, card_h: float) -> void:
	var panel_path := Look.kit(CARD_LOCKED)
	if ResourceLoader.exists(panel_path):
		var p := TextureRect.new()
		p.texture = load(panel_path)
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_SCALE
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(p)
	else:
		var inner := _meadow_fill(false)
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(inner)
		_veil_thumb(inner, String(G.MAPS[z].id))     # the §8 code-drawn fog, only when the painted panel is absent
	# the prerequisite line, low on the panel (the baked medallion is the centre mark).
	var state_l := Label.new()
	state_l.text = tr("✿ after %s") % tr(G.MAPS[maxi(z - 1, 0)].name)
	state_l.add_theme_font_size_override("font_size", int(clampf(card_h * 0.135, 18.0, 30.0)))
	state_l.add_theme_color_override("font_color", Color(CREAM, 0.88))
	state_l.add_theme_color_override("font_outline_color", INK)
	state_l.add_theme_constant_override("outline_size", 5)
	state_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	state_l.position = Vector2(card_w * 0.12, card_h - card_h * 0.30)
	state_l.size = Vector2(card_w * 0.76, card_h * 0.24)
	state_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(state_l)

# The art that fills an open card: the map's own painted thumbnail (map_<id>.png), else its §16 home
# clean art (the hub's restored cottage), else "" → a code-drawn meadow fill.
func _card_art_path(z: int) -> String:
	var map_data: Dictionary = G.MAPS[z]
	var thumb_path := Game.art("map/map_%s.png" % String(map_data.id))
	if ResourceLoader.exists(thumb_path):
		return thumb_path
	var home = map_data.get("home", null)
	if typeof(home) == TYPE_DICTIONARY:
		var clean := String(home.get("clean", ""))
		if clean != "" and ResourceLoader.exists(clean):
			return clean
	return ""

# The rounded-corner alpha-mask material for an open card's locale art, sized to the inner rect so
# the corner radius is CARD_ART_RADIUS of the card width and stays circular at the rect's aspect.
func _art_clip_material(inner_size: Vector2) -> ShaderMaterial:
	if _art_clip == null:
		_art_clip = Shader.new()
		_art_clip.code = _ART_CLIP_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _art_clip
	mat.set_shader_parameter("rx", CARD_ART_RADIUS / (1.0 - 2.0 * CARD_FRAME_INSET))
	mat.set_shader_parameter("aspect", inner_size.x / maxf(inner_size.y, 1.0))
	return mat

# The restore count on an open card's lower edge: a cream pill (pill_left) carrying the GOLD star
# sprite + "N left" (panel-text law: dark INK, no halo), or "✿ restored" on a finished place. An
# IGNORE visual; the card is the hit target.
func _add_count_pill(z: int, card: Control, card_w: float, card_h: float, done: bool) -> void:
	var pw := clampf(card_w * 0.30, 170.0, 290.0)
	var ph := pw / CARD_PILL_ASPECT
	var node := Control.new()
	node.size = Vector2(pw, ph)
	# sit in the lower body, ABOVE the frame's bottom gold band (~10% of height) so the pill never
	# overlaps the border.
	node.position = Vector2((card_w - pw) * 0.5, card_h - ph - card_h * 0.13)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(node)
	var pill_path := Look.kit(CARD_PILL)
	if ResourceLoader.exists(pill_path):
		var bg := TextureRect.new()
		bg.texture = load(pill_path)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(bg)
	else:
		var pnl := Panel.new()
		pnl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var ps := StyleBoxFlat.new()
		ps.bg_color = CREAM
		ps.set_corner_radius_all(int(ph * 0.5))
		ps.set_border_width_all(3)
		ps.border_color = STRAW
		pnl.add_theme_stylebox_override("panel", ps)
		pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(pnl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(row)
	if done:
		var lbl := Label.new()
		lbl.text = tr("✿ restored")
		lbl.add_theme_font_size_override("font_size", int(ph * 0.42))
		lbl.add_theme_color_override("font_color", INK)
		lbl.add_theme_constant_override("outline_size", 0)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)
	else:
		var ic := Look.icon("star", ph * 0.50)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
		var lbl := Label.new()
		lbl.text = tr("%d left") % map_stars_left(z)
		lbl.add_theme_font_size_override("font_size", int(ph * 0.42))
		lbl.add_theme_color_override("font_color", INK)
		lbl.add_theme_constant_override("outline_size", 0)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)

# A code-drawn meadow fill for a card whose locale art hasn't shipped — a flat panel + a centered ✿
# "place" mark. `open` brightens it; a locked fallback dims (the fog veil layers over this).
func _meadow_fill(open: bool) -> Control:
	var ph := Panel.new()
	ph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ph.clip_contents = true
	var ps := StyleBoxFlat.new()
	ps.bg_color = MEADOW if open else MEADOW.lerp(INK, 0.45)
	ps.set_corner_radius_all(14)
	ph.add_theme_stylebox_override("panel", ps)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := Label.new()
	mark.name = "PlaceMark"
	mark.text = "✿"
	mark.add_theme_font_size_override("font_size", VEIL_MARK_SIZE)
	mark.add_theme_color_override("font_color", Color(CREAM, 0.5))
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(mark)
	return ph

# A code-drawn gold border, the fallback when card_active.png is absent (so an open card still reads
# as framed). A borderless rounded panel that draws only the rim — mouse-ignored, self-sizing.
func _code_card_border(_card_w: float, _card_h: float) -> Control:
	var pnl := Panel.new()
	pnl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0, 0, 0, 0)
	ps.set_corner_radius_all(22)
	ps.set_border_width_all(5)
	ps.border_color = STRAW
	pnl.add_theme_stylebox_override("panel", ps)
	pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pnl

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

func _on_spot_tap(z: int, k: int, node: Control, at: Vector2) -> void:
	var spot: Dictionary = G.MAPS[z].spots[k]
	if spot_owned(String(spot.id)):
		return                                # an already-restored spot is inert (no customization)
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
	if map_spots_done(z):
		Save.add_diamonds(G.MAP_DIAMONDS)
		Vault.skim(G.MAP_DIAMONDS)            # T44 SKIM-SITE 2/3 (map-restore): the piggy bank skims a slice of the restore premium (§10)
		FX.celebrate_at(self, get_global_rect().get_center(), tr("%s restored!") % tr(G.MAPS[z].name), STRAW)
		FX.floating_reward(self, get_global_rect().get_center() + Vector2(-60, 70),
			"gem", G.MAP_DIAMONDS, Color("#BFE6F2"), 38)
		Audio.play("level_complete", -2.0)
		# Spots-done unlock: completing the map's spots IS the completion record now (the gate
		# quest is retired). Append z to `gates` so `map_complete`/`frontier_map` advance — the
		# next map unlocks immediately. (The next map's generator already arrived earlier, via a
		# near-end quest's reward.generators into the gen_bag.)
		if not _gates().has(z):
			var gg := Save.grove()
			var gl: Array = gg.get("gates", [])
			gl.append(z)
			gg["gates"] = gl
			Save.grove_write()

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
		# the hub surfaces the board's water energy in the top-right currency bar (the board adds its
		# own water entry, so only the map opts in here).
		"water": true,
		"water_grant": func() -> void:
			var g := Save.grove()
			g["water"] = G.WATER_CAP
			Save.grove_write(),
		# tap the level badge -> the level screen (stars earned / needed for the next level)
		"on_level": func() -> void: LevelPopup.open(self)})
	stars_label = hud.stars
	coins_label = hud.coins
	level_label = hud.level
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
	# The home/map bottom nav is the SAME shared global row the board uses (ui/nav_bar.gd), at the SAME
	# board sizing — side buttons 140, the centred primary (Play) 184 — so the two screens' bottom bars
	# match. Order: Settings · Shop · [Play] · Map · Piggy, with PLAY in the CENTRE (3rd of 5), mirroring
	# the board's centred Home and home.png. PLAY is the way into the garden/board (the prominent leaf
	# that replaced the old wide "Enter Garden ▶" CTA). The Store "new offer" badge rides the Shop button
	# (_shop_btn anchor); the piggy bank rides the bottom bar (home.png) with its ready-pip.
	var sb := Look.safe_bottom(self)
	# The four flanking buttons are the SHARED configurable home button (disc shell + icon, tuned in the
	# workbench — `home_icon`); only the CENTRE Play stays the prominent baked leaf (the primary CTA).
	var nav := NavBar.build(self, [
		# Settings — the shared music/sounds/calm card (ui/settings.gd).
		{"home_icon": "gear", "px": 140.0, "label": tr("Settings"), "action": func() -> void:
			Audio.play("button_tap", -2.0)
			_open_settings()},
		# Shop — the shared currency store (the wallet's open_shop closure).
		{"home_icon": "shop", "px": 140.0, "label": tr("Shop"), "action": func() -> void:
			Audio.play("button_tap", -2.0)
			if _open_shop.is_valid():
				_open_shop.call()},
		# Play — the CENTRE, prominent leaf: the way into the garden/board (old wide "Enter Garden ▶" retired).
		{"icon": "nav_leaf.png", "px": 184.0, "label": tr("Play"), "action": _on_board},
		# Map — the place-picker (atlas).
		{"home_icon": "map", "px": 140.0, "label": tr("Map"), "action": func() -> void:
			Audio.play("button_tap", -2.0)
			_open_select()},
		# Piggy bank — the diegetic accrual-vault, on the bottom bar (home.png). Its claimable ready-pip
		# rides this button (driven by _refresh_piggy_pip → Vault.claimable()).
		{"home_icon": "piggy", "px": 140.0, "label": tr("Vault"), "action": _open_vault}])
	for b in nav.buttons:
		_chrome_nodes.append(b)
	_chrome_nodes.append(nav.row)
	# the Store-badge anchor = the Shop button (index 1).
	_shop_btn = nav.buttons[1]
	# the Play leaf breathes so the way to the board reads as the primary action (centre, index 2).
	FX.breathe_once(nav.buttons[2])
	# the Store "new offer" badge — shown only while the starter pack is unclaimed (an actionable offer)
	_store_badge = Look.badge("dot")
	Look.attach_badge(_shop_btn, _store_badge)
	_refresh_store_badge()
	# the piggy's claimable ready-pip rides the bottom-bar piggy button (index 4).
	_piggy_pip = Look.badge("dot")
	Look.attach_badge(nav.buttons[4], _piggy_pip)
	_refresh_piggy_pip()
	# the LiveOps rail: Daily · Free · Inbox, pinned TOP-right below the wallet (home.png). The map's
	# restore progress (and its completion gift) rides the top progress pill, so there's no above-CTA strip.
	_build_liveops_rail()
	# the place-picker's bottom-left BACK arrow (map.png) — returns to the map you were viewing. A real
	# Button on `self` (chrome), NOT under the content input surface; hidden on a map, shown in select.
	_select_back = _make_back_button(sb)
	add_child(_select_back)
	_select_back.visible = false

# The place-picker's bottom-left BACK button. It is the SAME shared home button (Kit.home_button) the
# bottom nav + the live-ops rail build from — the cream/gold disc tuned in the workbench — so a button
# tweak (size · shell · icon scale · polish) flows here too. It just carries the back-arrow icon
# (CARD_BACK, outside the icon_<id> convention → passed as icon_rel) and no caption. Pinned bottom-left;
# its press returns to the last-viewed map. Falls back to a bare disc when the kit can't load.
func _make_back_button(sb: float) -> Button:
	var px := _rail_px                       # the workbench-saved disc size (shared with the rail + nav)
	var back := func() -> void:
		Audio.play("button_tap", -4.0)
		_open_map(_map_idx)
	var Kit: GDScript = load(RAIL_KIT_PATH)
	var b: Button
	if Kit != null:
		b = Kit.home_button({"icon_rel": CARD_BACK, "caption": "", "action": back}, _home_opts)
	else:
		b = Button.new()                     # defensive fallback (kit absent): a bare disc
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

# The LIVE-OPS RAIL — a CALM vertical column of round badge-buttons pinned TOP-RIGHT, below the
# wallet pill (home.png): Daily · Free · (guarded) Inbox. Each is the SHARED configurable home button
# (Kit.home_button — the SAME cream/gold disc + icon + caption the bottom nav uses, tuned in the
# workbench) carrying a caption tab; the RED BADGE does all the attention-pulling, shown ONLY when
# actionable (today unclaimed / a free watch ready / unread mail — the mail badge shows the count).
# The Free faucet wears the optional SPARKLE (the workbench glow/twinkle amount). Discs are sized by the
# saved config (default 140, matching the bottom bar). Every button is appended to _chrome_nodes so it
# follows _set_map_chrome_visible (hidden on the place-picker).
const RAIL_KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const RAIL_PX := 140.0          # fallback disc size — matches the bottom-bar side buttons
const RAIL_MARGIN := 18.0       # right-edge inset
const RAIL_CAP_H := 42.0        # caption-tab band beneath each disc
const RAIL_GAP := 16.0          # gap between stacked entries
const RAIL_TOP := 210.0         # first disc sits this far below the safe-top (clear of the wallet pill)
var _home_opts := {}            # the shared home-button style (loaded once per rail build)
var _rail_px := RAIL_PX         # live disc size = the saved config px (drives the stacking layout)

func _build_liveops_rail() -> void:
	# Load the shared home-button style ONCE (the same transform the bottom nav + workbench read).
	var Kit: GDScript = load(RAIL_KIT_PATH)
	_home_opts = Kit.home_button_opts_from_config(Kit.load_config(Kit.CONFIG_PATH)) if Kit != null else {}
	_home_opts["calm"] = FX.calm()
	_rail_px = float(_home_opts.get("px", RAIL_PX))
	var step := _rail_px + RAIL_CAP_H + RAIL_GAP
	var top := Look.safe_top(self) + RAIL_TOP
	var slot := 0
	# Daily — opens the login calendar on demand; badge when today is unclaimed.
	var daily := _rail_button("gift", tr("Daily"), _open_daily)
	_place_rail(daily, top, slot, step); slot += 1
	_daily_badge = Look.badge("dot")
	Look.attach_badge(daily, _daily_badge)
	# Free — a rewarded-video gem faucet; badge when a watch is offerable. Wears the optional SPARKLE
	# (the "+gems" twinkle from the reference) at the workbench-tuned amount.
	var free := _rail_button("faucet", tr("Free"), _claim_free_gems, true)
	_place_rail(free, top, slot, step); slot += 1
	_free_badge = Look.badge("dot")
	Look.attach_badge(free, _free_badge)
	# Inbox — GUARDED: only built when the parallel inbox system exists in this build (load() runtime).
	if _has_inbox:
		var inbox := _rail_button("mail", tr("Inbox"), _open_inbox)
		_place_rail(inbox, top, slot, step); slot += 1
		_inbox_badge = Look.badge("pill", 0)
		Look.attach_badge(inbox, _inbox_badge)
	_refresh_liveops_badges()

# One rail button = the SHARED configurable home button (Kit.home_button): the cream/gold disc + icon +
# caption tab, tuned in the workbench. `sparkle` opts the disc into the engine-drawn glow/twinkle. Falls
# back to a plain cream disc when the kit can't load. Parented to self + tracked as chrome.
func _rail_button(icon_id: String, label: String, cb: Callable, sparkle := false) -> Button:
	var Kit: GDScript = load(RAIL_KIT_PATH)
	var b: Button
	if Kit != null:
		b = Kit.home_button({"icon": icon_id, "caption": label, "action": cb, "sparkle": sparkle}, _home_opts)
	else:
		b = Button.new()                          # defensive fallback (kit absent): a bare disc
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(_rail_px, _rail_px)
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
	b.offset_left = -RAIL_MARGIN - _rail_px
	b.offset_top = top + slot * step
	b.offset_bottom = b.offset_top + _rail_px

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

# Grant the map's milestone reward ONCE per map (persisted by a per-map flag) when its spots are all
# restored. Driven from the progress pill's "restored" end-state (see _map_title_plank), so the gift
# rides the top progress read — no separate strip. Celebrates the beat the player already reached
# (§4: no possibility gate).
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
	FX.floating_text(self, at - Vector2(0, 40), tr("Place restored ✿ 🎁"), CREAM, 24)
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
# (The §14 shop spotlight used to share this first-hub-open beat and gated the popup so the two never
# stacked — removed 2026-06-18, docs/BACKLOG.md "Restore the shop FTUE". With no spotlight to collide
# with, the extra defer + overlay-live check are gone; restore the don't-collide guard if a chrome
# spotlight is re-added here.)
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
