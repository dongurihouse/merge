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
const Vault = preload("res://engine/scripts/core/vault.gd")                  # T44 SKIM-SITE — the piggy bank skims earned premium here
const VaultUI = preload("res://engine/scripts/ui/vault.gd")                  # T45: the diegetic piggy-bank jar (chrome entry point)
const Ads = preload("res://engine/scripts/core/ads.gd")                      # T45: the rewarded 2×-collect doubler (post hub-collect offer)
const Login = preload("res://engine/scripts/core/login.gd")                  # T45: the forgiving daily-login calendar (auto-popup gate)
const LoginUI = preload("res://engine/scripts/ui/login.gd")                  # T45: the diegetic login-calendar popup surface
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
var upgrade_hits: Array = []     # [{node, z, k}] — the hub yield-building coin-upgrade pills (§8)
var _customize_spot := ""        # spot id whose inline variant strip is open
var _press := Vector2.ZERO       # last press point (still-tap resolution)

var _chrome_nodes: Array = []    # bottom chrome (garden CTA, gear, shop, atlas)
var _weather: Control = null     # ambient weather layer — belongs to a MAP; hidden on the place-picker
var _backdrop: Control = null    # the place-picker's sky backdrop (gradient + clouds); hidden on a MAP
var _shop_btn: Button            # T28: kept so the §14 shop spotlight can target it
var level_label: Label
var xp_label: Label
var stars_label: Label
var coins_label: Label
var _hud_refresh := Callable()
var _2x_offer: Control = null     # T45: the post-collect "double your coins" rewarded-ad card (opt-in, dismissible)
var _piggy_pip: Control = null    # T45: the vault chrome button's "claimable" ready glow (shown when Vault.claimable())
var _home_cue := Callable()       # toggles the §8 home-shortcut yield-ready pip (Hud.home_cue)
var _open_shop := Callable()      # opens the shared Shop (lives in the bottom chrome)
var _hud_panels: Array = []       # wallet + Lv chips

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
	_dismiss_2x_offer()                  # T45: a stale doubler card from a prior hub visit closes on nav (a fresh collect re-offers)
	# T1: remember WHICH map you were on — the board's Decorate jumps back here
	var g := Save.grove()
	g["last_map"] = String(G.MAPS[z].id)
	Save.grove_write()
	_build_map()
	# §8 keystone: entering/returning to the HUB sweeps all ready yield in ONE beat (the home
	# pays you). Credit + clock-reset happen NOW (correct even headless / pre-layout); the single
	# satisfying collect FX is deferred a frame so the wallet chip has a real global rect to arc to.
	if z == G.hub_map():
		_collect_hub_yield()

func _open_select() -> void:
	_view = "select"
	_customize_spot = ""
	_set_map_chrome_visible(false)        # the place-picker is a calm chooser — no map chrome, no weather
	_dismiss_2x_offer()                  # T45: leaving the hub for the map-select closes any open doubler card
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

# §8 keystone — the hub-collect BEAT. Sweep every restored yield building's accrued coins to the
# wallet in ONE go and reset the accrual clock (G.hub_collect does the credit + reset together).
# Always runs the economy immediately (correct headless / pre-layout); when in-tree it then plays a
# single satisfying collect FX — a coin arcs to the wallet chip + a shout — deferred a frame so the
# chip has a real global rect. A 0-yield open silently no-ops the FX (the clock still reset).
func _collect_hub_yield() -> void:
	var got := G.hub_collect(unlocks, Time.get_unix_time_from_system())
	if got <= 0:
		_refresh_home_cue()
		return
	_update_hud()
	_refresh_home_cue()
	if get_tree() == null or not is_inside_tree():
		return
	_hub_collect_fx.call_deferred(got)

func _hub_collect_fx(amount: int) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var chip: Control = _hud_panels[0] if _hud_panels.size() > 0 and is_instance_valid(_hud_panels[0]) else null
	var center := get_global_rect().get_center()
	Audio.play("level_complete", -5.0, 1.15)
	# a coin arcs from the hub center to the wallet chip, then the wallet ticks; plus a warm shout.
	FX.fly_to_wallet(self, center, Look.icon("coin", 44.0), chip, func() -> void: _update_hud())
	FX.celebrate_reward(self, center - Vector2(0, 40), "coin", amount, Color("#E3B23C"))
	FX.floating_text(self, center - Vector2(150, 110), tr("The home gathered some coins ✿"), CREAM, 28)
	# T45: AUTO-COLLECT TENSION — the hub already swept the coins for free (above). So the 2× ad is
	# a POST-collect DOUBLER, not a pre-collect choice: an OPT-IN card offering to watch a cloud and
	# add the SAME amount again. It never auto-plays, never blocks (tap-away dismisses), and only
	# appears when the rewarded ad is offerable (capped + cooled, §4/§10). Decline = keep your coins.
	_maybe_offer_2x(amount, center)

# T45: the cozy, optional 2×-collect DOUBLER card. Surfaced AFTER an automatic hub-collect of
# `got` coins, only when the rewarded ad is offerable (Ads.can_show — capped + cooled). A small
# parchment card floats just below the collect FX with a "double it" CTA and a "No thanks" out.
# Accept → claim the ad, credit a SECOND `got` (Save.add_coins), celebrate + tick the wallet, and
# consume the arm for bookkeeping. It is opt-in (never auto-plays), dismissible (tap-away / decline),
# and never blocks play. One at a time — a still-open offer is replaced.
func _maybe_offer_2x(got: int, _center: Vector2) -> void:
	if got <= 0 or not Ads.can_show("collect_2x"):
		return
	if not is_inside_tree():
		return
	if _2x_offer != null and is_instance_valid(_2x_offer):
		_2x_offer.queue_free()                       # never stack offers
	var view := get_viewport_rect().size
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	# pinned just under the wallet/HUD, centered — near the collect FX, clear of the spots
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.offset_top = 150.0 + Look.safe_top(self)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.z_index = 40
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)
	# the pitch — an icon + number ("double your N ✿"), emoji-free per §13 (coin is a sprite)
	var pitch := HBoxContainer.new()
	pitch.alignment = BoxContainer.ALIGNMENT_CENTER
	pitch.add_theme_constant_override("separation", 6)
	col.add_child(pitch)
	var pl := Label.new()
	pl.text = tr("Watch a cloud → double it!")
	pl.add_theme_font_size_override("font_size", 24)
	pl.add_theme_color_override("font_color", INK)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pitch.add_child(pl)
	var sub := HBoxContainer.new()
	sub.alignment = BoxContainer.ALIGNMENT_CENTER
	sub.add_theme_constant_override("separation", 4)
	col.add_child(sub)
	var sl := Label.new()
	sl.text = tr("+")
	sl.add_theme_font_size_override("font_size", 22)
	sl.add_theme_color_override("font_color", Color(BARK, 0.95))
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_child(sl)
	sub.add_child(Look.icon("coin", 22.0))
	var sn := Label.new()
	sn.text = str(got)
	sn.add_theme_font_size_override("font_size", 22)
	sn.add_theme_color_override("font_color", Color(BARK, 0.95))
	sn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_child(sn)
	# the two ways out — a primary "Double" and a quiet "No thanks" (decline keeps the coins)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	col.add_child(btns)
	btns.add_child(Look.button(tr("No thanks"), _dismiss_2x_offer, false))
	btns.add_child(Look.button(tr("Double ✿"), func() -> void: _accept_2x_offer(got), true))
	add_child(card)
	_2x_offer = card
	FX.pop_in(card)
	FX.breathe_once(card)

# Accept the 2× doubler: re-check + claim the rewarded ad (the stub records the watch), then credit
# a SECOND `got` coins, celebrate the bonus from the card, tick the wallet, consume the arm, and
# close the card. A refused claim (raced past the cap) just closes cozily — no penalty.
func _accept_2x_offer(got: int) -> void:
	var at := _2x_offer.get_global_rect().get_center() if _2x_offer != null and is_instance_valid(_2x_offer) else get_global_rect().get_center()
	_dismiss_2x_offer()
	var res := Ads.claim("collect_2x")
	if not bool(res.get("ok", false)):
		Audio.play("invalid_soft", -4.0)
		return
	Save.add_coins(got)                              # the doubled half — the same amount again
	Ads.consume_2x()                                 # spend the arm (bookkeeping; the bonus is applied)
	Audio.play("level_complete", -3.0, 1.2)
	FX.celebrate_reward(self, at, "coin", got, Color("#E3B23C"))
	FX.fly_to_wallet(self, at, Look.icon("coin", 40.0),
		_hud_panels[0] if _hud_panels.size() > 0 and is_instance_valid(_hud_panels[0]) else null,
		func() -> void: _update_hud())
	_update_hud()

# Close the 2× offer card (decline, tap-away, or post-accept). Idempotent.
func _dismiss_2x_offer() -> void:
	if _2x_offer != null and is_instance_valid(_2x_offer):
		_2x_offer.queue_free()
	_2x_offer = null

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
	upgrade_hits.clear()
	var z := _map_idx
	# the stable map canvas is a centered, design-aspect rect (see _map_image_rect) that the HUD
	# floats over. Background art fills it; spots ride this same rect, so the painting and the
	# buildings stay locked together on any window aspect.
	_map_rect = _map_image_rect()
	_map_art_rect = _map_placed_rect(z, _map_rect)
	# background: a map may name its own `bg` (e.g. map1v2 base_empty); else the convention path.
	var art_path := String(G.MAPS[z].get("bg", Game.art("map/map_%s.png" % String(G.MAPS[z].id))))
	if ResourceLoader.exists(art_path):
		# A clipped frame AT the map rect; layers fill it via full-rect anchors (cover-fit). Anchoring to
		# a sized parent avoids the TextureRect native-size reset. The base fills it; an optional fixed
		# `fence` layer composites on top at its baked position/size.
		var frame := Control.new()
		frame.position = _map_art_rect.position
		frame.size = _map_art_rect.size
		frame.clip_contents = true
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(frame)
		_add_cover_layer(frame, art_path)
		var fence_path := String(G.MAPS[z].get("fence", ""))
		if fence_path != "" and ResourceLoader.exists(fence_path):
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
	# decoration placed in the map placer (data/map1v2_decor.json)
	var decor := _load_decor_list(z)
	_add_placed_clouds(decor, _map_rect)    # placed clouds drift slowly in the sky, behind everything
	_add_decor(decor, "back", _map_rect)    # trees BEHIND the buildings (their canopies sway)
	# ambient life wanders over the map (order L), positioned within the image rect
	var amb := Ambient.build_layer(_map_rect.size, G.character_count(unlocks))
	amb.position = _map_rect.position
	amb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(amb)
	# the title plank — map name + ✿-progress — near the top of the map rect
	content.add_child(_map_title_plank(z))
	var lvl := G.level_for_stars(int(Save.grove().get("stars_earned", 0)))
	for k in G.MAPS[z].spots.size():
		var spot := _make_spot(z, k, lvl, _map_rect)
		content.add_child(spot)
		spot_hits.append({"node": spot, "z": z, "k": k})
	_add_decor(decor, "front", _map_rect)   # grass IN FRONT of the buildings
	FX.pop_in(content)

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

# Decoration placed in the map placer (data/map1v2_decor.json). `back` = trees (behind the buildings),
# `front` = grass (in front). Flat sprites for now; wind/idle animation comes in a later phase.
func _load_decor_list(z: int) -> Array:
	var path := String(G.MAPS[z].get("decor", ""))
	if path == "" or not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY or not data.has("decor"):
		return []
	return data["decor"]

func _add_decor(decor: Array, layer: String, rect: Rect2) -> void:
	var sc := rect.size.x / Design.size().x          # footprints are authored at the design-width canvas
	for d in decor:
		if String(d.get("layer", "front")) != layer:
			continue
		var art := String(d.get("art", ""))
		if not ResourceLoader.exists(art):
			continue
		var fs := float(d.get("fsize", 200)) * sc
		var p = d.get("pos", [0.5, 0.5])
		var center := rect.position + Vector2(float(p[0]), float(p[1])) * rect.size
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture = load(art)
		t.size = Vector2(fs, fs)
		t.position = center - Vector2(fs, fs) * 0.5
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(t)
		if "/trees/" in art:
			_sway(t, fs)   # trees rock gently from the base in the wind

# Tree wind (items 5 & 6): a shader shears the sprite horizontally by an amount that grows toward the
# CANOPY (zero at the trunk base, so only leaves/outer branches move), and a per-tree gust scheduler
# drives it in occasional bursts — trees rest, then sway briefly, rather than rocking nonstop.
const _TREE_SWAY_SHADER := "shader_type canvas_item;
uniform float phase = 0.0;
uniform float freq = 2.0;
uniform float amp = 0.06;
uniform float trunk = 0.62;
uniform float gust = 0.0;
void fragment() {
	float w = smoothstep(trunk, 0.0, UV.y);          // 0 at/below the trunk line, → 1 at the top
	float wind = sin(TIME * freq + phase) * gust * amp * w;
	vec2 uv = UV + vec2(wind, 0.0);
	if (uv.x < 0.0 || uv.x > 1.0) { COLOR = vec4(0.0); }
	else { COLOR = texture(TEXTURE, uv); }
}"
var _tree_shader: Shader

func _sway(t: Control, _fs: float) -> void:
	if _tree_shader == null:
		_tree_shader = Shader.new()
		_tree_shader.code = _TREE_SWAY_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _tree_shader
	mat.set_shader_parameter("phase", randf() * TAU)
	mat.set_shader_parameter("freq", 1.5 + randf() * 1.3)       # ~1.5–2.8 rad/s
	mat.set_shader_parameter("amp", 0.045 + randf() * 0.03)     # max canopy shear (fraction of width)
	mat.set_shader_parameter("trunk", 0.58 + randf() * 0.08)    # UV.y below this stays planted
	mat.set_shader_parameter("gust", 0.0)
	t.material = mat
	_gust(t, mat)

# One gust cycle: rest a random while, ramp the sway in, hold briefly, damp out — then reschedule.
func _gust(t: Control, mat: ShaderMaterial) -> void:
	if not is_instance_valid(t):
		return
	var tw := t.create_tween()
	tw.tween_interval(4.0 + randf() * 9.0)                                              # rest between gusts
	tw.tween_property(mat, "shader_parameter/gust", 1.0, 0.5 + randf() * 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5 + randf() * 0.8)
	tw.tween_property(mat, "shader_parameter/gust", 0.0, 1.3 + randf() * 1.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(_gust.bind(t, mat))

# Clouds placed in the map placer (layer "cloud"): each starts where it was placed, then drifts slowly
# leftward and wraps around the sky. Rendered behind everything (added before the buildings/spots).
func _add_placed_clouds(decor: Array, rect: Rect2) -> void:
	var sc := rect.size.x / Design.size().x
	for d in decor:
		if String(d.get("layer", "front")) != "cloud":
			continue
		var art := String(d.get("art", ""))
		if not ResourceLoader.exists(art):
			continue
		var fs := float(d.get("fsize", 240)) * sc
		var p = d.get("pos", [0.5, 0.18])
		var center := rect.position + Vector2(float(p[0]), float(p[1])) * rect.size
		var c := TextureRect.new()
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.texture = load(art)
		c.size = Vector2(fs, fs)
		c.position = center - Vector2(fs, fs) * 0.5
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(c)
		_drift_cloud(c, rect, fs)

func _drift_cloud(c: TextureRect, rect: Rect2, cloud_w: float) -> void:
	var span := rect.size.x + cloud_w                       # travel from off-right to off-left
	if span <= 0.0:
		return
	var left := rect.position.x - cloud_w
	var base_x := c.position.x
	var period := (span / rect.size.x) * (90.0 + randf() * 50.0)   # ~90–140s to cross, per-cloud
	var tw := c.create_tween().set_loops()
	tw.tween_method(func(prog: float):
			c.position.x = left + fposmod(base_x - prog * span - left, span),
		0.0, 1.0, period)

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
	# canvas is now full-bleed, so push the name plank below the floating HUD band
	plank.position = _map_rect.position + Vector2(_map_rect.size.x / 2.0, 16.0 + 96.0 + Look.safe_top(self))
	plank.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plank.add_child(col)
	var name_l := Label.new()
	name_l.text = tr(G.MAPS[z].name)
	name_l.add_theme_font_size_override("font_size", 30)
	name_l.add_theme_color_override("font_color", CREAM)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_l)
	if map_spots_done(z):
		var lbl := Label.new()
		lbl.text = tr("✿ restored")
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", STRAW)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(lbl)
	else:
		col.add_child(_stars_left_row(map_stars_left(z), STRAW, 22))   # gold star sprite + count
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
	# §8 keystone: an OWNED hub YIELD building wears a coin-upgrade pill — its current level
	# and (until maxed) the next upgrade cost. Tapping it spends coins → +1 level (richer look +
	# higher yield). Décor + non-hub spots never get it. A breathe nudges an affordable upgrade.
	if owned and z == G.hub_map() and G.spot_is_yield(z, String(spot.id)):
		_add_upgrade_pill(item, z, k)
	if owned and _customize_spot == String(spot.id):
		_add_variant_strip(item, z, k)
	return item

# §8: the coin-upgrade affordance on an owned hub yield building. A compact pill above the spot:
# "Lk" when maxed, else "Lk · 🪙N" (the cost to reach L k+1). Tapping it (resolved via upgrade_hits)
# spends N coins and raises the level. An IGNORE visual; the content surface resolves the tap. The
# pill breathes when the upgrade is currently affordable — a subtle "spend your coins here" cue.
func _add_upgrade_pill(item: Control, z: int, k: int) -> void:
	var spot_id := String(G.MAPS[z].spots[k].id)
	var level: int = Save.spot_level(spot_id)
	var cost: int = G.hub_upgrade_cost(level)
	var maxed: bool = cost < 0
	var pill := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("#E8C84A", 0.92) if maxed else Color(INK, 0.86)
	ps.set_corner_radius_all(14)
	ps.set_border_width_all(2)
	ps.border_color = Color("#E8C84A") if maxed else STRAW
	ps.content_margin_left = 10.0
	ps.content_margin_right = 10.0
	ps.content_margin_top = 4.0
	ps.content_margin_bottom = 4.0
	pill.add_theme_stylebox_override("panel", ps)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var lv := Label.new()
	lv.text = tr("Lv %d") % level
	lv.add_theme_font_size_override("font_size", 19)
	lv.add_theme_color_override("font_color", INK if maxed else CREAM)
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lv)
	if maxed:
		var star := Look.icon("star", 18.0)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(star)
	else:
		var up := Label.new()
		up.text = "▲"
		up.add_theme_font_size_override("font_size", 15)
		up.add_theme_color_override("font_color", STRAW)
		up.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		up.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(up)
		var ci := Look.icon("coin", 18.0)
		ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ci)
		var cl := Label.new()
		cl.text = str(cost)
		cl.add_theme_font_size_override("font_size", 19)
		cl.add_theme_color_override("font_color", CREAM)
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cl)
	# pinned just ABOVE the spot's center plot (the furniture fills the middle); shrink-centered.
	pill.position = Vector2(90, -2)
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	item.add_child(pill)
	upgrade_hits.append({"node": pill, "z": z, "k": k})
	if not maxed and Save.coins() >= cost:
		FX.breathe_once(pill)

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
	upgrade_hits.clear()
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
	# §8 upgrade pills sit ABOVE their owned spot — resolve them before the spot's own tap.
	for hit in upgrade_hits:
		var un: Control = hit.node
		if un.get_global_rect().grow(6.0).has_point(gpos):
			_on_upgrade_tap(int(hit.z), int(hit.k), un, gpos)
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
	# §8 keystone: restoring a HUB spot brings it to L1 — the start of the coin upgrade ladder
	# (a yield building immediately drips its L1 base yield; a décor spot just reads "restored").
	# Non-hub maps don't run the level system, so only the hub map records a level.
	if z == G.hub_map():
		Save.set_spot_level(String(spot.id), 1)
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

# §8 keystone: a coin-upgrade pill was tapped on an owned hub yield building. Refuse at the cap
# (a finite ladder — wiggle + "fully upgraded") or when broke (wiggle + "need N more" — never
# blocks progress, §10), else SPEND the coins and raise the stored level by 1 (richer look +
# higher yield). The map re-renders (the pill reprices, the spot's variant wash unchanged) and the
# HUD ticks. Spend-then-bump: Save.spend is atomic, so a refusal leaves the level untouched.
func _on_upgrade_tap(z: int, k: int, node: Control, at: Vector2) -> void:
	var spot_id := String(G.MAPS[z].spots[k].id)
	var level: int = Save.spot_level(spot_id)
	var cost: int = G.hub_upgrade_cost(level)
	if cost < 0:                                   # already at the max level — nothing to buy
		Audio.play("invalid_soft", -4.0)
		FX.wobble(node)
		FX.floating_text(self, at - Vector2(110, 60), tr("Fully upgraded ✿"), Color(CREAM, 0.9), 28)
		return
	if not Save.spend(cost, "hub_upgrade"):
		Audio.play("invalid_soft", -4.0)
		FX.wobble(node)
		FX.floating_text(self, at - Vector2(110, 60), tr("Need %d more") % (cost - Save.coins()), Color(CREAM, 0.9), 28)
		return
	Save.set_spot_level(spot_id, level + 1)
	Audio.play("level_complete", -5.0, 1.15)
	FX.burst(self, at, STRAW, 14)
	FX.floating_text(self, at - Vector2(90, 70), tr("%s → Lv %d ✿") % [tr(G.MAPS[z].spots[k].name), level + 1], STRAW, 28)
	_build_map()
	_update_hud()
	_refresh_home_cue()

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
		"home": func() -> void: _open_map(G.hub_map())})
	stars_label = hud.stars
	coins_label = hud.coins
	level_label = hud.level
	xp_label = hud.xp
	_hud_refresh = hud.refresh
	_home_cue = hud.get("home_cue", Callable())
	_open_shop = hud.open_shop
	_hud_panels = [hud.wallet, hud.lv_panel]
	_refresh_home_cue()

# §8 keystone: light the home-shortcut yield-ready pip iff the hub has uncollected coin yield.
# Called after HUD build and whenever the hub's ready-state can change (map open, collect, upgrade).
# On the hub itself it reads false right after the collect beat; off the hub it nudges the return.
func _refresh_home_cue() -> void:
	if _home_cue.is_valid():
		_home_cue.call(G.hub_has_yield_ready(unlocks, Time.get_unix_time_from_system()))

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
	# T45: the PIGGY BANK — the diegetic accrual-vault entry (§10/§13). The hub map is the
	# natural home: it is the return surface the player lands on. Sits to the LEFT of the atlas,
	# same round-button language as the rest of the chrome. A gold ready-pip rides its corner
	# when the jar has filled past the claim threshold (Vault.claimable()) — a gentle "ready"
	# cue, never a nag. Tapping opens the jar surface (ui/vault.gd), which refreshes the pip on close.
	var piggy := Button.new()
	piggy.focus_mode = Control.FOCUS_NONE
	piggy.custom_minimum_size = Vector2(76, 76)
	if ResourceLoader.exists(Look.kit("btn_round.png")):
		var pt := StyleBoxTexture.new()
		pt.texture = load(Look.kit("btn_round.png"))
		pt.set_texture_margin_all(24.0)
		piggy.add_theme_stylebox_override("normal", pt)
		piggy.add_theme_stylebox_override("hover", pt)
		piggy.add_theme_stylebox_override("pressed", pt)
	else:
		var pgs := StyleBoxFlat.new()
		pgs.bg_color = Color(INK, 0.6)
		pgs.set_corner_radius_all(38)
		piggy.add_theme_stylebox_override("normal", pgs)
		piggy.add_theme_stylebox_override("hover", pgs)
		piggy.add_theme_stylebox_override("pressed", pgs)
	# the piggy glyph rides the round button (the kit has no "piggy" icon entry, so a glyph,
	# matching how the atlas button renders its 🗺 — Look.icon("piggy") would render "?")
	var pgi := Label.new()
	pgi.text = "🐷"
	pgi.add_theme_font_size_override("font_size", 34)
	pgi.add_theme_color_override("font_color", CREAM)
	pgi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pgi.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pgi.set_anchors_preset(Control.PRESET_FULL_RECT)
	pgi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piggy.add_child(pgi)
	Look.add_press_juice(piggy)
	piggy.anchor_left = 1.0
	piggy.anchor_right = 1.0
	piggy.anchor_top = 1.0
	piggy.anchor_bottom = 1.0
	piggy.offset_left = -356
	piggy.offset_right = -280
	piggy.offset_top = -92 - sb
	piggy.offset_bottom = -16 - sb
	piggy.pressed.connect(_open_vault)
	add_child(piggy)
	_chrome_nodes.append(piggy)
	# the ready-pip — a small gold dot on the button's top-right, shown only when claimable
	var pip := Panel.new()
	var pps := StyleBoxFlat.new()
	pps.bg_color = Color("#E8C84A")
	pps.set_corner_radius_all(9)
	pps.set_border_width_all(2)
	pps.border_color = Color(CREAM, 0.9)
	pip.add_theme_stylebox_override("panel", pps)
	pip.custom_minimum_size = Vector2(18, 18)
	pip.size = Vector2(18, 18)
	pip.position = Vector2(58, 2)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piggy.add_child(pip)
	_piggy_pip = pip
	_refresh_piggy_pip()

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
	if Login.claimed_today() or _2x_offer != null:
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
