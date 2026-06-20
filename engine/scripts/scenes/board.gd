extends Control
## The board — P1 core feel (water OFF).
## One persistent SAVED board: tap the seed satchel to pop items (random tier,
## ask-weighted line), drag matching plants together to grow them, merge beside
## brambles to clear them, drag onto empty ground to rearrange, stash in the Bag,
## feed top tiers to the Merchant, deliver quest asks to the fox/hedgehog for
## stars, and spend stars at the Restore gate to restore the grove (givers pause
## the moment the gate is affordable — the drive-to-spend loop).

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")
const Quests = preload("res://engine/scripts/core/quests.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Music = preload("res://engine/scripts/core/music.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Tuning = preload("res://engine/scripts/core/tuning.gd")   # UI-redesign role dials (Tuning.UiSkin.*)
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Bust = preload("res://engine/scripts/ui/bust.gd")
const GiverStand = preload("res://engine/scripts/ui/giver_stand.gd")
const MerchantStand = preload("res://engine/scripts/ui/merchant_stand.gd")
const BagOverlay = preload("res://engine/scripts/ui/bag_overlay.gd")   # the tap-to-open full bag (replaces the inline row)
const Ladder = preload("res://engine/scripts/ui/ladder.gd")
const OowOffer = preload("res://engine/scripts/ui/oow_offer.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const NavBar = preload("res://engine/scripts/ui/nav_bar.gd")   # the shared global bottom nav row (board + map)
const Shop = preload("res://engine/scripts/ui/shop.gd")   # §10: drains shop-bought item-shortcuts into the bag
const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Spotlight = preload("res://engine/scripts/core/spotlight.gd")          # T28: the §14 first-appearance gate
const Ads = preload("res://engine/scripts/core/ads.gd")                       # T43: §10 rewarded-ad refill at the wall
const SpotlightOverlay = preload("res://engine/scripts/ui/spotlight_overlay.gd")  # T28: the veil+pulse+hand guide
const Vault = preload("res://engine/scripts/core/vault.gd")                  # T44 SKIM-SITE — the piggy bank skims the t8-sell premium here
const HomeScene = preload("res://engine/scripts/scenes/map.gd")   # T2: the Decorate jump request
const Game = preload("res://engine/scripts/core/game.gd")
const Debug = preload("res://engine/scripts/ui/debug.gd")
const SettingsUI = preload("res://engine/scripts/ui/settings.gd")   # the shared Settings card — reachable from the board, not only the map
const LevelPopup = preload("res://engine/scripts/ui/level_popup.gd")   # tap the Lv badge or a locked cell → the level screen
const Pal = Game.PALETTE
const Data = Game.DATA   # T43: the active game's DATA (the §10 out-of-water offer numbers)

const GAP := 7.0                 # #7: tight, consistent gutter (was 10) — cells sit close
const BOARD_MARGIN := 12.0       # breathing room each side; the board owns the rest
const DRAG_HILITE := Color(1.12, 1.12, 1.12, 1.0)   # a drop-target well's brighten while a piece is dragged
const FENCE_H := 196.0           # the quest fence band above the grid (horizontal cards)
const DIVIDER_H := 54.0          # the wood-branch divider band between the fence and the grid
const STAND_W := 270.0           # one giver card's width — ~4 fit across like the reference (row scrolls beyond)
const IDLE_HINT_SECS := 4.5      # W1: first idle hint sooner (was 7) → a mergeable pair rocks
const IDLE_RENUDGE_SECS := 4.0   # W1: re-nudge cadence while the player stays idle
const HINT_ROCK_DEG := 6.0       # W1: gentle rock amplitude (was a fast ±0.22rad shake)
const HINT_ROCK_CYCLE := 1.2     # W1: seconds per rock cycle
const HINT_ROCK_CYCLES := 3      # W1: number of slow rock cycles
# §5: the bag's owned-slot COUNT is dynamic + persisted (Save.bag_slots(), 6→18) — no const.
const BASKET_CAP = G.BASKET_CAP
const PORTER_SECS = G.PORTER_SECS
const TREAT_COST = G.TREAT_COST

# grove board palette (the night-purples retire here)
const GROUND_EDGE = Pal.GROUND_EDGE
const CREAM = Pal.CREAM
const STRAW = Pal.STRAW

# Shading IS the clickable/important affordance (board polish #8): the brighter a thing
# reads, the more it's asking to be tapped. BRIGHT/un-shaded = actionable right now; a
# gentle DIM = inert/locked/satisfied. One cozy dim value (~0.78 alpha) for every
# "step back" read — a soft difference, never harsh — so the eye lands on what's live.
const SHADE_LIT := Color(1, 1, 1, 1.0)      # actionable: deliverable giver, has-spares merchant
const SHADE_DIM := Color(1, 1, 1, 0.78)     # inert: not-yet-payable giver, nothing to sell

# §6: a full board DIMS the generator(s) to a standing "paused" state — popping is free
# while dimmed, so the cue must persist (not a one-shot wobble) until a cell frees up.
# A generator's stop is a stronger signal than a giver's, so it dims further (0.5) — same
# affordance family (bright = tappable), just a deeper "paused" read for the harder stop.
const GEN_DIM := Color(1, 1, 1, 0.5)
const GEN_LIT := SHADE_LIT

var board: BoardModel
var rng := RandomNumberGenerator.new()
var quests: Array = []             # §7: the LIVE generated fence (metered to the next unlock), persisted
var quests_map := -1              # the map these quests were generated for (regenerate on map change)
var bag: Array = []
var water := G.WATER_CAP
var refills_used := 0
var _regen_ts := 0.0               # regen anchor (unix); advances as water accrues
var _winback := false              # set on load when away >= WINBACK_HOURS

var csz := 86.0
var board_area: Control
var slot_nodes := {}
var piece_nodes := {}
var bramble_nodes := {}
var gen_node: Control              # the starter satchel (kept for tools/tests)
var gen_nodes := {}                # generator index -> node
var gen_preview_cells := {}        # V: cell -> gi for locked-gen previews (tap → name floater)
var _grown_cells: Array = []       # cells of generators that just GREW IN this rebuild (appear_level reached) — popped for feedback
# (the §6 burst buy pill and the W3 merchant drag sell-tag were the dark stat_chip pill — retired
#  T48 ahead of the UI redesign; the burst coin sink stays in code, see _upgrade_gen_burst)
var giver_bar: Control           # the quest fence (givers pop up over it)
var giver_chips: Array = []        # [{chip, qi}]
var merchant_chip: Control
# Y2/Y3: the merchant's collection basket — last <=3 sales, each with its EXACT grant
# for an exact buy-back. NOT persisted (the porter clears it within ~3 min anyway).
var basket: Array = []               # [{code, coins, diamonds}]
var basket_chip: Control             # the wicker basket beside the merchant stall
var _porter_timer := 0.0             # Y3: counts up while the basket has anything
var _porter_running := false
var _amb_layer: Control              # Z3: the board's wandering-spirit layer (a treat sends one over)
var home_btn: Button                 # the centre nav Home button — IS the decorate jump; breathes when a spot is affordable
# the bottom-nav bag + merchant are circular wells (the always-present bag row is retired).
# bag_btn: tap → full bag, drag a board item onto it → stash; bag_content (a CenterContainer)
# shows the most-recent stashed item, centered at bag_piece_px. merchant_btn: drag a spare onto
# it → sell; merchant_pay previews the payout (+N coin/acorn) while a spare is dragged over it.
var bag_btn: Button
var bag_content: Control
var bag_piece_px := 72.0             # the in-well item-preview size (set from the well px on build)
var merchant_btn: Button
var merchant_rest: Control
var merchant_pay: Control
var merchant_pay_lbl: Label
var merchant_pay_icon: Control
var stars_label: Label
var coins_label: Label
var _2x_offer: Control = null   # the post-reward 2× "double your coins" rewarded-ad card (re-homed from the removed hub-collect, §10)
var diamonds_label: Label
var level_label: Label            # S10: the shared Lv chip, wired in BOTH scenes
var bag_slots_ui: Array = []
var _bag_drag_idx := -1                 # §5 drag-back: which bag slot the in-flight drag came from (-1 = none)
var _open_shop: Callable = Callable()   # opens the shared Shop (wired from the HUD)
var bottom_bar: Control          # the painted bottom nav row (Home·Shop·Leaf·Gear·Bag)
var shop_btn: Button             # T28: kept as a member so the §14 spotlight can target it
var _spotlight_active := false   # T28: one spotlight at a time (don't stack overlays)

var _press_cell := Vector2i(-1, -1)
var _press_pos := Vector2.ZERO
var _drag_is_gen := false          # the current drag picked up a generator (movable-only, §6)
var _drag_node: Control = null
var _drag_from := Vector2i(-1, -1)
var animating := false
var _idle := 0.0                   # seconds without input → the wiggle hint

var water_label: Label
var _water_icon: Control
var _wallet_panel: Control
var refill_btn: Button
# T43: the empty-water surfaces stack under the Lv chip (shown only at water<=0): the
# free/💎 refill (refill_btn), a rewarded WATCH-AD refill, and the cozy out-of-water OFFER.
var _refill_stack: VBoxContainer
var ad_refill_btn: Button
var oow_offer_btn: Button
var _water_pending_drained := false   # the starter-pack water credit drains once per board open

func _ready() -> void:
	UiFont.apply()
	Music.ensure()
	# UI redesign: the play surface is a flat SURFACE stage so items pop — replacing the
	# painted bg_grove_board.png (an olive field) and the warm dim that used to recede it.
	# A flat neutral field needs no veil.
	add_child(_field_backdrop())
	# (the ambient drift + wandering-spirit layers were removed — they cluttered the top.
	# _amb_layer stays null; _buy_treat guards it.)
	_load_state()

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_BEGIN   # pin the stack to the top so quests sit right above the grid (no centred dead band)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# the fence band lives BELOW the pinned HUD chips, never under them
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 64.0 + Look.safe_top(self))
	root.add_child(spacer)

	# The chapter ribbon is retired (T49 — progression is one `level` clock, merge_spec §3;
	# the player-facing "Chapter N" title is gone per the UI-language redesign §6). The
	# top-bar center stays empty, which also reclaims vertical space for the fence below.

	# the quest fence: a full-width wall the giver animals pop up over, each
	# with a big cream ask-card (item + progress + star reward; ✓ when ready)
	giver_bar = Control.new()
	giver_bar.custom_minimum_size = Vector2(0, FENCE_H)
	giver_bar.size_flags_horizontal = Control.SIZE_FILL
	root.add_child(giver_bar)

	# The standalone "✿ Decorate!" pill is retired — the centre Home button below IS the decorate
	# jump, and it lights up (a gold ready-dot + a gentle breathe) the moment a spot is affordable.

	var center := CenterContainer.new()
	# the grid pins DIRECTLY under the quest fence (no vertical centring) — quests sit right
	# above the board; the leftover meadow falls below toward the bottom nav.
	center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(center)
	board_area = Control.new()
	# the board fills the screen side to side (owner); on wide screens the
	# HEIGHT budget binds instead so the fence/bag rows always fit
	var view := get_viewport_rect().size
	# the bamboo FRAME extends FRAME_OUT past the grid on every side — budget for it so the
	# frame + last column never run off-screen (the prior calc sized only the cells → overflow).
	var w_csz := (view.x - 2.0 * BOARD_MARGIN - 2.0 * FRAME_OUT - (G.COLS - 1) * GAP) / float(G.COLS)
	# +DIVIDER_H (+ one VBox gap) reserves the branch divider's band so the grid+frame still
	# clear the bottom nav (the divider now sits between the fence and the grid).
	var h_csz := (view.y - 520.0 - (DIVIDER_H + 10.0) - 2.0 * FRAME_OUT - (G.ROWS - 1) * GAP) / float(G.ROWS)
	csz = minf(w_csz, h_csz)
	# The bamboo frame overhangs the grid by FRAME_OUT on all sides. Reserve that real
	# visual footprint in the VBox so the frame no longer intrudes into the giver cards.
	center.custom_minimum_size = Vector2(_board_w() + FRAME_OUT * 2.0, _board_h() + FRAME_OUT * 2.0)
	board_area.custom_minimum_size = Vector2(_board_w(), _board_h())
	board_area.gui_input.connect(_on_board_input)
	center.add_child(board_area)

	# the wood-branch divider between the quest fence and the board grid (the "transition" from
	# quests to the board). Sits in the stack right above the grid; null when the art is absent.
	var divider := _make_branch_divider()
	if divider != null:
		root.add_child(divider)
		root.move_child(divider, center.get_index())   # slot it just ABOVE the grid (below the fence)

	# the bag is no longer an always-present row; it is a single circular well in the bottom nav
	# (tap → full bag overlay, drag a board item onto it → stash). See _make_bag_button.

	# the full-width bottom nav: Shop · Settings · [Home centre] · Bag · Merchant. Home is the
	# single home affordance (the Leaf is retired) and sits centred + prominent — the way back to
	# the Map/decorate hub. The Bag and Merchant are circular wells; the Merchant is the new
	# drag-to-sell drop target (the fence stall is gone). shop_btn stays a member (§14 spotlight).
	# Built through the shared NavBar component (ui/nav_bar.gd) — the SAME global bottom row the
	# home/map screen uses, just fed different specs; the per-scene builder it used to duplicate is gone.
	# Every button is the SHARED configurable home button (disc shell + icon). Shop/Settings/Home go through
	# `home_icon`; the Bag + Merchant are still custom `make` wells (their drop-target role + live overlays),
	# now built on the SAME home-button shell (_home_well) — house/bag/coin-sack icons lifted off the old
	# baked nav buttons (extract_nav_icons.py) so they sit on the shared disc like the map's icons.
	var nav := NavBar.build(self, [
		# Shop — the currency store (unchanged action)
		{"home_icon": "shop", "px": 140.0, "label": tr("Shop"), "action": func() -> void:
			Audio.play("button_tap", -2.0)
			if _open_shop.is_valid():
				_open_shop.call()},
		# Settings — the shared card the map's gear opens (ui/settings.gd)
		{"home_icon": "gear", "px": 140.0, "label": tr("Settings"), "action": func() -> void:
			Audio.play("button_tap", -2.0)
			SettingsUI.open(self)},
		# Home — the centre, prominent button; the single affordance back to the Map. Lands on the
		# map you were LAST decorating (last_map), NOT the hub — empty on a fresh save → frontier.
		{"home_icon": "house", "px": 184.0, "label": tr("Home"), "action": func() -> void:
			Audio.play("button_tap", -2.0)
			_persist()
			HomeScene.decorate_map = _decorate_target()
			get_tree().change_scene_to_file("res://engine/scenes/Map.tscn")},
		# Bag — a circular well; tap opens the full bag, drag a board item onto it to stash
		{"make": func() -> Control: return _make_bag_button(140.0)},
		# Merchant — a circular well; drag a spare onto it to sell (it previews the payout)
		{"make": func() -> Control: return _make_merchant_button(140.0)}])
	bottom_bar = nav.row
	shop_btn = nav.buttons[0] as Button       # §14 spotlight target
	home_btn = nav.buttons[2] as Button       # lit when a spot is affordable (replaces the Decorate CTA)
	bag_btn = nav.buttons[3] as Button
	merchant_btn = nav.buttons[4] as Button

	_build_hud()
	_build_water_hud()
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.timeout.connect(_tick_water)
	add_child(tick)
	tick.start()
	add_child(Ambient.build_weather(get_viewport_rect().size, Ambient.weather_now(FX.calm())))
	_rebuild_all()
	if _winback:
		_winback = false
		FX.floating_text(self, Vector2(get_global_rect().get_center().x - 260, 200),
			tr("It rained while you were away ☔"), CREAM, 38)
		Audio.play("rain_refill" if Audio.has("rain_refill") else "level_complete", -3.0)

	Debug.mount(self)                    # debug/authoring panel (no-op in prod)

# After a quiet spell, a pair that can merge wiggles to show the next step
# (owner: ~5-10s of inactivity). Re-nudges gently while the player stays idle.
func _process(delta: float) -> void:
	if board == null:
		return
	_porter_tick(delta)   # Y3: the basket's collection timer runs regardless of the idle hint
	if animating or _drag_node != null or not Features.on("idle_hint"):
		_idle = 0.0
		return
	_idle += delta
	if _idle >= IDLE_HINT_SECS:
		_idle = IDLE_HINT_SECS - IDLE_RENUDGE_SECS   # W1: re-nudge ~every IDLE_RENUDGE_SECS while idle
		_hint_pair()

# Find one mergeable pair and wiggle it. Returns the pair (tests; [] = none).
# The unlockable cell(s) this merge would OPEN are NOT rocked — they already carry the bright
# highlight border + glow (PieceView.make_bramble), so the rock was redundant teach-signal.
func _hint_pair() -> Array:
	if not Features.on("idle_hint"):
		return []
	var pair := BoardLogic.find_mergeable_pair(board)
	for cell in pair:
		var n: Control = piece_nodes.get(cell)
		if n != null and is_instance_valid(n):
			FX.rock(n, HINT_ROCK_DEG, HINT_ROCK_CYCLE, HINT_ROCK_CYCLES)   # W1: gentle rock
	return pair

func _board_w() -> float:
	return G.COLS * csz + (G.COLS - 1) * GAP

func _board_h() -> float:
	return G.ROWS * csz + (G.ROWS - 1) * GAP

# --- state ----------------------------------------------------------------------

func _load_state() -> void:
	board = BoardModel.new()
	var now := Time.get_unix_time_from_system()
	var g := Save.grove()
	if g.has("board"):
		board.from_dict(g["board"])
		quests = Array(g.get("quests", []))
		quests_map = int(g.get("quests_map", -1))
		bag = Array(g.get("bag", []))
		rng.state = int(g.get("rng_state", 0))
		water = int(g.get("water", G.WATER_CAP))
		refills_used = int(g.get("refills_used", 0))
		_regen_ts = float(g.get("regen_ts", now))
		# the >=48h check lives in Ambient now (both scenes' weather reads its stamp)
		if Ambient.check_winback(g, now) and water < G.WATER_CAP:
			water = G.WATER_CAP            # "it rained" — the >= 48h win-back
			_regen_ts = now
			_winback = true
		else:
			_apply_regen(now)
	else:
		rng.randomize()
		_regen_ts = now
		_init_quests()
		_persist()
	if board.gens.is_empty():               # fresh game, or a pre-T17 save with no gen map →
		board.seed_gens(G.map_for_spots(_spots_bought()), _quest_level())   # seed at the player's Level — staged gens (appear_level) hold back until earned
	if not Save.grove().has("gates"):       # pre-§7 save: maps already spot-restored were unlocked → gate them
		var mg: Array = []
		var ul: Dictionary = Save.grove().get("unlocks", {})
		for z in G.MAPS.size():
			if G.map_spots_done(z, ul):
				mg.append(z)
		var gg := Save.grove()
		gg["gates"] = mg
		Save.grove_write()
	if quests_map != _quest_map():        # never-seeded (pre-§7 save) or crossed into a new map
		_init_quests()
	else:
		_refill_quests()                    # top up / trim the live fence to the current meter
	for v in board.items:                # everything already growing counts as met
		_mark_seen(int(v))
	for v in bag:
		_mark_seen(int(v))
	# §10: drain any item-shortcuts bought in the Shop into the bag (bounded by capacity);
	# leftovers stay queued. Persist + mark-seen the pieces that landed.
	if Shop.drain_pending(bag, _bag_capacity()) > 0:
		for v in bag:
			_mark_seen(int(v))
		_persist()

# --- the discovery log: which items has this player ever grown? -------------------
# Powers the upgrade-path card (unseen tiers show as "?").

func _mark_seen(code: int) -> void:
	if code <= 0 or G.is_coin(code):
		return
	var g := Save.grove()
	if not g.has("seen"):
		g["seen"] = {}
	g["seen"][str(code)] = true

# [{tier, code, seen}] for a line's full ladder (pure — tests use it directly).
func _ladder_entries(line: int) -> Array:
	return Quests.ladder_entries(Save.grove().get("seen", {}), line)

# water regen rule lives in BoardLogic; apply the returned state to ours
func _apply_regen(now: float) -> void:
	var r := BoardLogic.regen(water, _regen_ts, now)
	water = int(r.water)
	_regen_ts = float(r.regen_ts)

# --- §7 live generated-quest fence ------------------------------------------------
# Gates delivered so far (map indices) — the §7 completion chain; persisted in the save.
func _gates() -> Array:
	return Save.grove().get("gates", [])

# The map currently being restored (its generators/lines are live). Clamped to a valid map.
func _quest_map() -> int:
	return Quests.current_map(Save.grove().get("unlocks", {}), _gates())

func _quest_level() -> int:
	return G.level_for_stars(int(Save.grove().get("stars_earned", 0)))

# The soft gate (§7): how many stands the fence shows, metered to the current map's next spot.
func _meter_target() -> int:
	return Quests.meter_target(_quest_map(), Save.stars(), Save.grove().get("unlocks", {}))

# Top up / trim the live fence to the metered count with freshly generated quests (§7). Deterministic
# via the rng. Near the end of the map, one quest also carries the next map's generator(s) → auto-placed on board.
func _refill_quests() -> void:
	quests = Quests.refill(quests, _quest_map(), Save.grove().get("unlocks", {}), _gates(), board.gens, board.gen_bag, Save.stars(), _quest_level(), rng)

# Fresh fence for the current map (load / migration / crossing a map boundary).
func _init_quests() -> void:
	quests = []
	quests_map = _quest_map()
	_refill_quests()

func _quest_stars(q: Dictionary) -> int:
	return Quests.stars(q)

func _quest_coins(q: Dictionary) -> int:
	return Quests.coins(q)

func _quest_gems(q: Dictionary) -> int:
	return Quests.gems(q)

func _persist() -> void:
	var g := Save.grove()
	g["board"] = board.to_dict()
	g["quests"] = quests
	g["quests_map"] = quests_map
	g["bag"] = bag
	g["rng_state"] = rng.state
	g["water"] = water
	g["refills_used"] = refills_used
	g["regen_ts"] = _regen_ts
	g["last_seen"] = Time.get_unix_time_from_system()
	Save.grove_write()

func _spots_bought() -> int:
	return Save.grove().get("unlocks", {}).size()   # the count of home spots bought

func _map_done() -> bool:                     # every map fully complete (spots + gate) — no frontier left
	return Quests.map_done(Save.grove().get("unlocks", {}), _gates())

# the restore CTA: ready once the CURRENT map's cheapest level-affordable spot is affordable.
# Scoped to the frontier map; a fully-restored map auto-unlocks the next one (spots-done),
# so a map with no remaining spots is NOT "ready to restore" — there is nothing left to buy.
func _gate_ready() -> bool:
	return Quests.gate_ready(_quest_map(), Save.stars(), Save.grove().get("unlocks", {}))

# --- HUD ------------------------------------------------------------------------

func _build_hud() -> void:
	# the shared top bar (owner: one module, currencies in the same place everywhere)
	var hud := Hud.build(self, {"water": true, "water_grant": func() -> void:
		water = G.WATER_CAP
		_update_water_hud()
		_persist(),
		# §10: a shop-bought item-shortcut lands in the bag LIVE (drained from the queue)
		# while the board is open — no scene reload needed for it to appear.
		"piece_grant": func() -> void: _drain_shop_pieces(),
		# tap the level badge -> the level screen (stars earned / needed for the next level)
		"on_level": func() -> void: LevelPopup.open(self)})
		# (no "home" opt → the shared HUD skips its top-left home chip; the bottom nav owns Home now)
	stars_label = hud.stars
	coins_label = hud.coins
	diamonds_label = hud.diamonds
	level_label = hud.level          # S10: store the board's Lv chip (set at build; level is static here)
	_wallet_panel = hud.wallet       # the shared cluster
	water_label = hud.water          # water pair is built by the shared HUD now (one path with the map)
	_water_icon = hud.water_icon     # the icon node, so FTUE can hide the water icon + label together
	_open_shop = hud.open_shop       # the bottom-bar shop button opens it
	_update_hud()

# water lives in the shared currency cluster (top-right) next to the other
# currencies — no second row (owner 2026-06-13). The refill OFFER stays a separate
# button, shown only when empty.
func _build_water_hud() -> void:
	# The water icon + count live in the shared currency cluster now (built by Hud.build via opts.water
	# — ONE path with the map; the refs come back as hud.water / hud.water_icon, bound in _build_hud).
	# This builds only the board-specific empty-water REFILL stack.
	# T43: the empty-water surfaces live in a vertical stack under the Lv chip, shown only
	# at water<=0 (§10 — the friction point). Top: the free/💎 rain refill. Then a rewarded
	# WATCH-AD refill (capped) and the cozy out-of-water OFFER, each shown only when live.
	_refill_stack = VBoxContainer.new()
	_refill_stack.add_theme_constant_override("separation", 8)
	_refill_stack.offset_left = 16.0
	_refill_stack.offset_top = 16.0 + Look.safe_top(self) + 84.0
	_refill_stack.visible = false
	add_child(_refill_stack)
	refill_btn = Look.button(tr("Rain ☔ free refill"), _on_refill, true)
	refill_btn.custom_minimum_size = Vector2(330, 76)
	_refill_stack.add_child(refill_btn)
	ad_refill_btn = Look.button(tr("Watch a cloud ☁ → fill"), _on_ad_refill, false)
	ad_refill_btn.custom_minimum_size = Vector2(330, 68)
	ad_refill_btn.visible = false
	_refill_stack.add_child(ad_refill_btn)
	oow_offer_btn = Look.button(tr("A little help ✿"), _on_oow_offer, false)
	oow_offer_btn.custom_minimum_size = Vector2(330, 68)
	oow_offer_btn.visible = false
	_refill_stack.add_child(oow_offer_btn)
	_update_water_hud()

func _tick_water() -> void:
	var before := water
	_apply_regen(Time.get_unix_time_from_system())
	_update_water_hud()
	if water != before:
		_persist()

func _ftue_pops_done() -> bool:
	if not Features.on("ftue_free_pops"):
		return true
	return int(Save.grove().get("pops", 0)) >= 10   # the first ten pops are free & uncounted

func _update_water_hud() -> void:
	if water_label == null:
		return
	# T43: apply any banked water credit (e.g. the starter pack's water bonus bought from
	# the map) ONCE on board open — before the empty check, so a fresh top-up shows.
	if not _water_pending_drained:
		_water_pending_drained = true
		var credit := Save.take_water_pending()
		if credit > 0:
			water = mini(G.WATER_CAP, water + credit)
			_persist()
	# Water is a first-class currency in the shared top bar — always visible on the board now, matching
	# the map. (The old FTUE staged-chrome hide that kept the meter hidden until the 10 free pops were
	# spent is retired; the separate water-COST gate at _ftue_pops_done() — see _charge — is unchanged,
	# so during the free intro the meter simply reads full.)
	_water_icon.visible = true
	water_label.visible = true
	water_label.text = str(water)
	# the empty-water surfaces (§10 the friction point): the stack appears at water<=0.
	var empty := water <= 0
	var free_left := refills_used < G.FREE_REFILLS
	refill_btn.visible = empty and (free_left or Save.diamonds() >= G.REFILL_DIAMOND_COST)
	if refill_btn.visible:
		refill_btn.text = tr("Rain ☔ free refill") if free_left else tr("Rain ☔ %d🌰") % G.REFILL_DIAMOND_COST
	# the rewarded WATCH-AD refill — a free, capped + cooldowned alternative (§10 ads).
	ad_refill_btn.visible = empty and Ads.can_show("refill_water")
	# the cozy OUT-OF-WATER offer — a gently-discounted top-up on a low cap + long cooldown,
	# NO countdown, NO fail copy (§10 locked guardrails). Shows only inside its cap/cooldown.
	oow_offer_btn.visible = empty and Save.oow_can_show(int(Data.OOW_OFFER.cap), float(Data.OOW_OFFER.cooldown))
	if oow_offer_btn.visible:
		oow_offer_btn.text = tr("A little help ✿ +%d💧 +%d🌰 · %s") % \
			[int(Data.OOW_OFFER.water), int(Data.OOW_OFFER.gems), String(Data.OOW_OFFER.usd)]
	_refill_stack.visible = refill_btn.visible or ad_refill_btn.visible or oow_offer_btn.visible
	if _refill_stack.visible:
		FX.breathe_once(refill_btn if refill_btn.visible else _first_visible_refill())

func _on_refill() -> void:
	if water > 0:
		return
	if refills_used < G.FREE_REFILLS:
		refills_used += 1
	elif not Save.spend_diamonds(G.REFILL_DIAMOND_COST):
		FX.wobble(refill_btn)
		Audio.play("invalid_soft", -4.0)
		return
	water = G.WATER_CAP
	_regen_ts = Time.get_unix_time_from_system()
	Audio.play("rain_refill" if Audio.has("rain_refill") else "level_complete", -3.0)
	FX.celebrate_reward(self, refill_btn.get_global_rect().get_center(), "water", G.WATER_CAP, Color("#9CCDE8"))
	_persist()
	_update_water_hud()
	_update_hud()

# The first currently-visible refill button (for the breathe pulse when the free/💎
# refill is spent but the ad / offer surfaces remain).
func _first_visible_refill() -> Control:
	if ad_refill_btn.visible:
		return ad_refill_btn
	if oow_offer_btn.visible:
		return oow_offer_btn
	return refill_btn

# Rewarded WATCH-AD refill (§10): the ad is a STUB here — Ads.claim re-checks the cap +
# cooldown, records the watch, and hands back the water target; we fill to it. The real
# ad-SDK show→reward callback replaces only the (here-instant) "watch"; everything else
# — the cap gate, the grant, the persist — is wired. Refuses cozily if just-capped.
func _on_ad_refill() -> void:
	if water > 0:
		return
	var res := Ads.claim("refill_water")
	if not bool(res.get("ok", false)):
		FX.wobble(ad_refill_btn)
		Audio.play("invalid_soft", -4.0)
		_update_water_hud()
		return
	water = mini(G.WATER_CAP, int(res.get("water", G.WATER_CAP)))
	_regen_ts = Time.get_unix_time_from_system()
	Audio.play("rain_refill" if Audio.has("rain_refill") else "level_complete", -3.0)
	FX.celebrate_reward(self, ad_refill_btn.get_global_rect().get_center(), "water", G.WATER_CAP, Color("#9CCDE8"))
	_persist()
	_update_water_hud()
	_update_hud()

# The cozy OUT-OF-WATER offer (§10): an honest confirm (LIVE IAP, "test build" note) for a
# gently-discounted top-up — a full can + a little 💎 at the entry price, on a low cap + long
# cooldown. NO countdown, NO fail-shaming (the locked guardrails). Confirming grants both and
# records the show (so the cap/cooldown holds); cancelling costs nothing.
func _on_oow_offer() -> void:
	if water > 0:
		return
	if not Save.oow_can_show(int(Data.OOW_OFFER.cap), float(Data.OOW_OFFER.cooldown)):
		FX.wobble(oow_offer_btn)
		_update_water_hud()
		return
	var line := tr("+%d water, +%d acorns") % [int(Data.OOW_OFFER.water), int(Data.OOW_OFFER.gems)]
	_open_oow_confirm(line, tr("for %s — a little help on a dry day") % String(Data.OOW_OFFER.usd))

# Grant the out-of-water offer (pure side effects): the water top-up, the 💎, and record
# the show. Factored so it is the single grant seam (a real receipt check guards the call).
func _grant_oow_offer() -> void:
	water = mini(G.WATER_CAP, water + int(Data.OOW_OFFER.water))
	_regen_ts = Time.get_unix_time_from_system()
	Save.add_diamonds(int(Data.OOW_OFFER.gems))
	Save.oow_record()
	Audio.play("rain_refill" if Audio.has("rain_refill") else "level_complete", -3.0)
	FX.celebrate_reward(self, oow_offer_btn.get_global_rect().get_center(), "water", G.WATER_CAP, Color("#9CCDE8"))
	_persist()
	_update_water_hud()
	_update_hud()

# A compact honest parchment confirm for the out-of-water offer (same "(test build —
# nothing is charged)" disclosure as the shop's cash confirm). Cozy: warm copy, a Maybe
# later / Yes please pair, no pressure.
func _open_oow_confirm(line: String, sub: String) -> void:
	# Wave 3: the modal lives in ui/oow_offer.gd; the gate + grant stay in the coordinator.
	OowOffer.open(self, {"amount": line, "sub": sub, "on_accept": _grant_oow_offer})

func _update_hud() -> void:
	stars_label.text = str(Save.stars())
	coins_label.text = str(Save.coins())
	if diamonds_label != null:
		diamonds_label.text = str(Save.diamonds())
	# The decorate invitation now rides on the centre Home button (the standalone CTA is gone):
	# light it up the moment the frontier map has a spot the player can afford; a fully-done
	# game (no frontier left) leaves it resting.
	_set_home_ready(not _map_done() and _gate_ready())

# The Home button is the way back to the decorate hub, so the "you can afford a spot" cue lives
# ON it now: a gentle breathe (suppressed in calm, like every attention pulse). On the board stars
# only rise, so this flips off→on once and never back; breathe_once self-guards re-entry.
func _set_home_ready(on: bool) -> void:
	if on and home_btn != null and is_instance_valid(home_btn):
		FX.breathe_once(home_btn)

# --- givers + merchant ------------------------------------------------------------

func _active_quest_idx() -> Array:
	# the live fence is already metered to <= MAX_GIVERS by _refill_quests (§7's soft gate:
	# it shrinks as stars bank toward the next unlock, and empties once it's affordable).
	var out: Array = []
	for i in quests.size():
		out.append(i)
	return out

func _rebuild_givers() -> void:
	for c in giver_bar.get_children():
		c.queue_free()
	giver_chips.clear()
	_refill_quests()                          # §7: size the live fence to the meter before rendering
	var qidx := _active_quest_idx()
	var stands := qidx.size()
	merchant_chip = null   # the sell merchant is a bottom-nav well now (no fence stall)
	if stands == 0:
		return
	# the fence wall — one bordered strip; busts and cards pop up over its edge
	var wall := Control.new()
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall.offset_top = 64.0
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	giver_bar.add_child(wall)
	giver_bar.move_child(wall, 0)
	# (the full-width quest-band Panel is removed — the giver cards now ride directly on the
	# painted backdrop; the band box read as a phantom slab.)
	# the stands scroll horizontally when the map is generous (cards stay BIG)
	var span := giver_bar.size.x
	if span <= 0.0:
		span = get_viewport_rect().size.x
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	giver_bar.add_child(scroll)
	giver_bar.move_child(scroll, 1)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	if stands * STAND_W < span:
		row.custom_minimum_size = Vector2(span, FENCE_H)   # few stands sit centered
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)
	for k in qidx.size():
		var qi: int = qidx[k]
		var stand := _make_giver_stand(qi, quests[qi])
		row.add_child(stand.chip)
		giver_chips.append(stand)
	_refresh_giver_lights()

# A tap fires on a still RELEASE so scrolling the row never delivers by accident.
func _stand_tap(stand: Control, action: Callable) -> void:
	stand.gui_input.connect(func(ev: InputEvent) -> void:
		var btn: bool = (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT) \
			or ev is InputEventScreenTouch
		if not btn:
			return
		if ev.pressed:
			stand.set_meta("press_pos", ev.position)
		elif stand.has_meta("press_pos"):
			var moved: float = ev.position.distance_to(stand.get_meta("press_pos"))
			stand.remove_meta("press_pos")
			if moved <= 24.0:
				_idle = 0.0
				action.call())

# Build one quest-giver stand. Wave 3: the construction lives in ui/giver_stand.gd;
# the coordinator still owns the quests + delivery and wires the stand's taps back.
func _make_giver_stand(qi: int, q: Dictionary) -> Dictionary:
	return GiverStand.make(qi, q, {
		"ask_tap": _open_ladder,        # an ask icon tapped -> open its tier ladder
		"stand_tap": _on_giver_tap,     # the stand tapped -> try to deliver
		"wire_tap": _stand_tap,         # still-release tap (also resets the idle hint)
		"stand_w": STAND_W, "fence_h": FENCE_H,
	})


# AB1: a FRAMELESS giver — the chest-up cutout IS the UI element (no panel, no
# border). Pops over the fence rail. Art-missing fallback is a ROUND initial chip
# (never a square).
func _bust(which: int, px: float = 124.0) -> Control:
	return Bust.make(which, px)

func _mini_item(code: int) -> Control:
	return PieceView.mini_item(code)

# Build the merchant stall. Wave 3: construction lives in ui/merchant_stand.gd; the coordinator
# keeps the basket state, the sell/buy-back transactions, the drag-driven affordance, the porter.
func _make_merchant_stand() -> Control:
	var m := MerchantStand.build({
		"stand_w": STAND_W, "fence_h": FENCE_H,
		"buy_treat": _buy_treat,
		"wire_tap": _stand_tap,
	})
	basket_chip = m.basket_chip
	_rebuild_basket()                        # paint any held sales now that basket_chip exists
	return m.stand

# Z3: spend 10🪙 → a random wandering spirit scurries over, nibbles, hops + glows.
# Endlessly repeatable; rapid taps each resolve independently (no queue to break).
func _buy_treat() -> void:
	if not Features.on("spirit_treats"):
		return
	if Save.coins() < TREAT_COST:
		Audio.play("invalid_soft", -6.0)
		if merchant_chip != null and is_instance_valid(merchant_chip):
			FX.wobble(merchant_chip)
		return
	Save.spend(TREAT_COST, "treat")
	var spirits: Array = []
	if _amb_layer != null and is_instance_valid(_amb_layer):
		for sp in _amb_layer.get_children():
			if sp is Control:
				spirits.append(sp)
	if not spirits.is_empty():
		var who: Control = spirits[rng.randi_range(0, spirits.size() - 1)]
		Ambient.hop(who)
		FX.celebrate_at(self, who.get_global_rect().get_center(), tr("✿"), STRAW)
	Audio.play("merge_success", -4.0, 1.3)
	_persist()
	_update_hud()

# W3: while ANY item is dragged, the merchant's stall brightens — the sell affordance.
# (The live "+N🪙" shoulder tag was the dark stat_chip pill — retired T48 ahead of the UI
#  redesign; the +N value read returns as a new-language chip during the redesign. The `code`
#  is no longer read here, kept on the signature for the callers + the redesign rebuild.)
func _show_sell_affordance(code: int) -> void:
	if not Features.on("sell_hints") or merchant_btn == null or not is_instance_valid(merchant_btn):
		return
	merchant_btn.modulate = DRAG_HILITE
	FX.breathe_once(merchant_btn)
	# preview the payout on the well so the player sees what they'll get before dropping
	if G.is_coin(code) or merchant_pay == null or not is_instance_valid(merchant_pay):
		return
	var rw := G.sell_reward(code)            # Vector2i(coins, acorns)
	var gem := rw.y > 0
	merchant_pay_lbl.text = "+%d" % (rw.y if gem else rw.x)
	for c in merchant_pay_icon.get_children():
		c.queue_free()
	var ic := Look.icon("gem" if gem else "coin", merchant_pay_icon.custom_minimum_size.x)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	merchant_pay_icon.add_child(ic)
	merchant_pay.visible = true
	if merchant_rest != null and is_instance_valid(merchant_rest):
		merchant_rest.visible = false

func _hide_sell_affordance() -> void:
	if merchant_pay != null and is_instance_valid(merchant_pay):
		merchant_pay.visible = false
	if merchant_rest != null and is_instance_valid(merchant_rest):
		merchant_rest.visible = true
	if merchant_btn != null and is_instance_valid(merchant_btn):
		FX.breathe_stop(merchant_btn)        # end the drag pulse (it otherwise loops forever after the 1st drag)
		merchant_btn.modulate = Color(1, 1, 1, 1.0)

# Drag drop-target affordance (the §-bottom-nav wells). A stashable piece picked up lights BOTH its
# drop targets for the drag's duration — the Bag (stash) and the merchant's cart (sell) — each with
# a gentle pulse + brighten. NEITHER pulses at idle. The Bag is SKIPPED when full (no room to stash).
func _show_drag_targets(code: int) -> void:
	_show_sell_affordance(code)              # the merchant cart (sell) — pulse + brighten + payout preview
	_highlight_bag_target()

func _hide_drag_targets() -> void:
	_hide_sell_affordance()                  # settle the cart back to rest
	_unhighlight_bag_target()

func _highlight_bag_target() -> void:
	if bag_btn == null or not is_instance_valid(bag_btn):
		return
	if bag.size() >= _bag_capacity():        # full → no room; don't invite a stash that can't land
		return
	bag_btn.modulate = DRAG_HILITE
	FX.breathe_once(bag_btn)

func _unhighlight_bag_target() -> void:
	if bag_btn != null and is_instance_valid(bag_btn):
		FX.breathe_stop(bag_btn)
		bag_btn.modulate = Color(1, 1, 1, 1.0)

# W3: the first time a MAX-TIER item lands on the board, a one-time floater points
# the player at the stall (persisted seen-flag — never nags twice).
func _note_item_landed(code: int) -> void:
	if not Features.on("sell_hints") or G.is_coin(code) or BoardModel.tier_of(code) < G.TOP_TIER:
		return
	var g := Save.grove()
	if bool(g.get("seen_sell_hint", false)):
		return
	g["seen_sell_hint"] = true
	FX.floating_text(self, Vector2(get_global_rect().get_center().x - 250, 220),
		tr("the merchant buys spares — drag it to his stall"), CREAM, 28)

# The one notion of "deliverable" — the single asked item is on the board RIGHT NOW.
# A pure boolean, asserted by tests, that both the ✓ and the bob read so they can never diverge.
func _giver_is_payable(e: Dictionary) -> bool:
	var item: Dictionary = e.get("item", {})
	if item.is_empty():
		return true                       # a generator-reward-only card with no item ask
	var have := board.count_of(int(item.code))
	var met_ok := have >= 1
	var met: Control = item.get("met")
	if met != null and is_instance_valid(met):
		met.visible = met_ok
	return met_ok

func _refresh_giver_lights() -> void:
	for e in giver_chips:
		var lit := _giver_is_payable(e)
		var ready_ui := lit and Features.on("quest_ready_check")
		var check: Control = e.check
		if check != null and is_instance_valid(check):
			check.visible = ready_ui     # AB3: the check IS the ready state (no ring)
		# Tier 2 §2: bob ONLY deliverable givers — the bob now carries readiness, so it
		# starts when the quest becomes payable and stops when it no longer is. Gated on
		# the SAME predicate as the ✓ above (no second, divergent notion of payable).
		var bust: Control = e.get("bust")
		if bust != null and is_instance_valid(bust):
			GiverStand.bob(bust, lit)
		# board polish #8: a deliverable giver reads BRIGHT (it's the actionable thing);
		# one not-yet-payable sits gently shaded. Same `lit` predicate as the ✓/bob above.
		var chip: Control = e.chip
		chip.modulate = SHADE_LIT if lit else SHADE_DIM
		if lit:
			FX.breathe_once(chip)
	if merchant_chip != null and is_instance_valid(merchant_chip):
		# the stall is actionable only when there's a top-tier spare to sell — bright then,
		# softly shaded otherwise (same cozy dim as the givers, so the rule reads as one).
		var has_top := not board.top_tier_cells().is_empty()
		merchant_chip.modulate = SHADE_LIT if has_top else SHADE_DIM

# §6: dim EVERY live generator to a standing "paused" look while the board has no free
# cell (popping is free while dimmed — only the cue is missing), and restore full modulate
# the instant a cell frees up. Called from every event that changes board fullness (pop,
# merge, sell, deliver, coin collect/drop, buy-back, refill, rebuild). Mirrors the
# giver-lights refresh: read board state, write modulate — no scattered ad-hoc writes.
# Safe alongside FX.breathe (that tweens scale, not modulate).
# A staged generator (appear_level) grows in once the player's Level reaches it — the
# board no longer opens with two generators (owner). Self-healing: called at the top of every
# _rebuild_all, it installs map-1 generators (e.g. pantry_crock at L5) that have grown in,
# makes their lines askable (refill), and persists. Records new cell(s) so the rebuild can pop them in.
# Later maps' generators never grow in here — they arrive via the near-end grant, auto-placed on board.
func _grow_generators() -> void:
	if board == null:
		return
	# Only the first map's generators are seeded/staged on the board (pantry_crock at
	# appear_level 5); every later map's generator arrives via the near-end grant →
	# auto-placed on board (gen_bag is the fallback when the board is full), so we never
	# auto-grow a later map here.
	# On map 1+, this function is a no-op: all of that map's generators arrive via the near-end grant.
	if _quest_map() != 0:
		return
	var added: Array = board.grow_gens(0, _quest_level())
	if added.is_empty():
		return
	for id in added:
		_grown_cells.append(G.gen_cell_of(G.GENERATORS, String(id)))
	_refill_quests()                          # the new generator's lines are now askable
	_persist()

func _refresh_generator_dim() -> void:
	if board == null:
		return
	var lit := not board.empty_ground_cells().is_empty()
	var m := GEN_LIT if lit else GEN_DIM
	for gn in gen_nodes.values():
		if gn != null and is_instance_valid(gn):
			gn.modulate = m
	if gen_node != null and is_instance_valid(gen_node):
		gen_node.modulate = m

# --- board rendering --------------------------------------------------------------

func _cell_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell.y * (csz + GAP), cell.x * (csz + GAP))

func _pos_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.y / (csz + GAP)), 0, G.ROWS - 1), clampi(int(p.x / (csz + GAP)), 0, G.COLS - 1))

func _rebuild_all() -> void:
	_grow_generators()                        # a staged second generator grows in once its level is reached
	for n in board_area.get_children():
		n.queue_free()
	slot_nodes.clear()
	piece_nodes.clear()
	bramble_nodes.clear()
	board_area.add_child(_make_board_mat())   # contrast: the garden bed under the grid
	for r in G.ROWS:
		for c in G.COLS:
			var cell := Vector2i(r, c)
			if board.is_open(cell):
				var slot := _make_slot(cell)   # #7: shared soft-well builder
				board_area.add_child(slot)
				slot_nodes[cell] = slot
			else:
				var br := _make_bramble(cell)
				br.position = _cell_pos(cell)
				board_area.add_child(br)
				bramble_nodes[cell] = br
	gen_nodes.clear()
	for cell in board.gens:                  # the live, stateful set (cell -> id), §6
		var gn := _make_generator(String(board.gens[cell]))
		gn.position = _cell_pos(cell)
		board_area.add_child(gn)
		FX.breathe(gn)
		if _grown_cells.has(cell):            # a just-grown second generator — pop it in
			FX.pop(gn)
		gen_nodes[cell] = gn                  # keyed by CELL now (a gen persists; new ones arrive via gen_bag, §6)
	if not _grown_cells.is_empty():
		Audio.play("level_complete", -6.0, 1.1)
		_grown_cells = []
	gen_node = gen_nodes.values()[0] if not gen_nodes.is_empty() else null
	# (the §6 burst buy pill was rebuilt here — retired T48 ahead of the UI redesign; the burst
	#  coin sink stays live via _upgrade_gen_burst, only its on-board pill is gone)
	# PARKED (T17): the locked-generator preview ("after N spots") was keyed on the old
	# per-spot-count `appears_at`. Under per-map generators the next set arrives on map
	# COMPLETION, not after N spots — the preview needs redefining (show the next map's
	# incoming generators) alongside §6/§7. Disabled for now; the `gen_preview` flag stays.
	gen_preview_cells.clear()
	_rebuild_pieces()
	var frame := _make_board_frame()   # bamboo ring ABOVE the cells — corner leaves overlap, not hidden under them
	if frame != null:
		board_area.add_child(frame)
	_rebuild_givers()
	_rebuild_bag()
	_refresh_generator_dim()   # §6: the freshly-built generators take their full/dimmed state
	_update_hud()
	_maybe_spotlight_chrome()

# T28 (§14): the instant a staged chrome feature FIRST appears, announce it once — a
# spotlight + pulse over it and a mimed tap/drag guide. Driven from _rebuild_all (which
# runs on every state change), but the first-appearance GATE (Spotlight.should_spotlight)
# fires each only once, ever. Target rects must be laid out, so resolve on the next frame.
func _maybe_spotlight_chrome() -> void:
	# ALL §14 board chrome spotlights (merchant/sell, bag, shop) are removed for now — each
	# fired before its action was meaningful (removed 2026-06-18; see docs/BACKLOG.md "Restore
	# the sell + bag FTUEs" and "Restore the shop FTUE"). Nothing is eligible, so never defer.
	# The presenter helpers below (_spotlight_chrome_deferred / _show_spotlight) are kept as the
	# re-add surface — restore the flag check + a should_spotlight(id) → call_deferred here, plus
	# the matching branch in _spotlight_chrome_deferred, to bring one back. The §14 mechanism +
	# registry are unchanged.
	return

# Dormant re-add template (not called while _maybe_spotlight_chrome is neutered above). When a
# chrome spotlight is restored, this dispatches them one at a time in staged order so overlays
# never stack: add `if <btn> != null and is_instance_valid(<btn>) and Spotlight.should_spotlight(id):
# _show_spotlight(id, <btn>); return` per feature.
func _spotlight_chrome_deferred() -> void:
	await get_tree().process_frame              # let busts/slots get real global rects
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if shop_btn != null and is_instance_valid(shop_btn) and Spotlight.should_spotlight("shop"):
		_show_spotlight("shop", shop_btn)

# Present the §14 overlay for `feature_id` over `target` and mark it spotlit (so it never
# re-announces). One overlay at a time; the gesture/caption come from the game's registry.
# The completion callback is a BOUND method (not a self-capturing lambda) so a torn-down
# scene leaves an auto-invalidated Callable, never a "freed capture" error.
func _show_spotlight(feature_id: String, target: Control) -> void:
	if _spotlight_active:
		return
	_spotlight_active = true
	Spotlight.mark_spotlit(feature_id)          # record now — announced exactly once
	var ov := SpotlightOverlay.present(self, target, Spotlight.gesture_for(feature_id),
		tr(Spotlight.label_for(feature_id)), Callable(self, "_on_spotlight_done"))
	if ov == null:                              # flag flipped off mid-call → release the latch
		_spotlight_active = false

# A spotlight was dismissed: release the latch and chain to the next staged feature that
# may already be visible (so merchant → bag → shop announce one after another).
func _on_spotlight_done() -> void:
	_spotlight_active = false
	_maybe_spotlight_chrome()

func _rebuild_pieces() -> void:
	for n in piece_nodes.values():
		if is_instance_valid(n):
			n.queue_free()
	piece_nodes.clear()
	for r in G.ROWS:
		for c in G.COLS:
			var cell := Vector2i(r, c)
			var k := board.item_at(cell)
			if k > 0:
				var n := _make_piece(k, csz)
				n.position = _cell_pos(cell)
				board_area.add_child(n)
				piece_nodes[cell] = n

func _make_piece(code: int, size: float) -> Control:
	return PieceView.make_piece(code, size)

# The garden bed under the grid — the wood-plank grid FRAME (`ui/board/panel_grid.png`) as a
# nine-patch, sized to the 7×9 grid, with a flat parchment field behind the cells so the
# gutters read cream. The frame art is composited from the kit's corner + plank parts into one
# 306px ring with a transparent center (games/grove/tools/build_board_frame.py), so ONLY the
# wood ring + its corner leaf clusters are opaque. The nine-patch margin (108) holds those
# corner clusters rigid; only the plain planks between corners stretch. Code-drawn planter fallback.
const FRAME_OUT := 60.0      # how far the wood frame extends OUTSIDE the cell grid
const FRAME_MARGIN := 108.0  # nine-patch corner size — matches the composited frame's 108px corners
const FIELD_INSET := 16.0    # cream field tucks this far under the planks so no backdrop shows in the gutter
const FIELD_RADIUS := 44     # field corner radius — rounds with the board so cream stays under the wood joints
const FIELD_CREAM := Color("#FEE2B1")   # sampled new parchment — the gutter colour behind cells

# The cream parchment bed the cells sit on — the BOTTOM layer of the board. The bamboo ring is a
# separate node (_make_board_frame) drawn ABOVE the cells. Falls back to the code-drawn planter
# (which carries its own frame) when the kit art is absent.
func _make_board_mat() -> Control:
	var fp := Look.kit("board/panel_grid.png")
	if not ResourceLoader.exists(fp):
		return PieceView.make_board_mat(_board_w(), _board_h())
	var bw := _board_w()
	var bh := _board_h()
	var mat := Control.new()
	mat.position = Vector2(-FRAME_OUT, -FRAME_OUT)
	mat.size = Vector2(bw + FRAME_OUT * 2.0, bh + FRAME_OUT * 2.0)
	mat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# parchment field, tucked out under the poles (FIELD_INSET) so the whole gutter reads cream with
	# no backdrop sliver, and rounded (FIELD_RADIUS) so the cream stays under the bamboo at the corners.
	var field := Panel.new()
	field.position = Vector2(FIELD_INSET, FIELD_INSET)
	field.size = mat.size - Vector2(FIELD_INSET, FIELD_INSET) * 2.0
	var fs := StyleBoxFlat.new()
	fs.bg_color = FIELD_CREAM
	fs.set_corner_radius_all(FIELD_RADIUS)
	field.add_theme_stylebox_override("panel", fs)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat.add_child(field)
	return mat

# The bamboo ring — a nine-patch, drawn ABOVE the cells so its corner leaf clusters overlap the
# board (instead of being hidden under the corner cell). The poles sit OUTSIDE the grid so they
# never cover a cell; only the inward-reaching corner leaves overlap. Null when the kit art is
# absent (the planter fallback in _make_board_mat already carries a frame).
func _make_board_frame() -> Control:
	var fp := Look.kit("board/panel_grid.png")
	if not ResourceLoader.exists(fp):
		return null
	var bw := _board_w()
	var bh := _board_h()
	var frame := NinePatchRect.new()
	frame.texture = load(fp)
	frame.position = Vector2(-FRAME_OUT, -FRAME_OUT)
	frame.size = Vector2(bw + FRAME_OUT * 2.0, bh + FRAME_OUT * 2.0)
	frame.patch_margin_left = int(FRAME_MARGIN)
	frame.patch_margin_top = int(FRAME_MARGIN)
	frame.patch_margin_right = int(FRAME_MARGIN)
	frame.patch_margin_bottom = int(FRAME_MARGIN)
	frame.draw_center = false   # interior is transparent (pre-cleared); the cream field shows through
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame

# The wood-branch divider between the quest fence and the board grid — the "transition" from
# quests to the board. A NinePatchRect: the leafy cut ends stay fixed while the middle log
# stretches to the board width. Null when the art is absent (the stack just omits it).
func _make_branch_divider() -> Control:
	var p := Look.kit("board/branch_divider.png")
	if not ResourceLoader.exists(p):
		return null
	var np := NinePatchRect.new()
	np.texture = load(p)
	np.custom_minimum_size = Vector2(_board_w() + FRAME_OUT * 2.0, DIVIDER_H)
	np.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	np.patch_margin_left = 80
	np.patch_margin_right = 80
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return np


# #7: the per-cell empty "well" — a single shared builder so both creation sites
# (full rebuild + bramble-clear) stay identical. A soft warm well with a gentle,
# low-alpha rounded outline (reads as an outline, not a hard line) and little
# inner padding, plus a faint shadow for depth.
func _make_slot(cell: Vector2i) -> Panel:
	var slot := Panel.new()
	slot.position = _cell_pos(cell)
	slot.size = Vector2(csz, csz)
	slot.add_theme_stylebox_override("panel", _slot_style())
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slot

# The per-cell empty well: the kit tile-slot sprite (`ui/board/slot_tile.png`) as a nine-patch,
# falling back to the code-drawn `_cell_style()` well when the art is absent.
static func _slot_style() -> StyleBox:
	var p := Look.kit("board/slot_tile.png")
	if ResourceLoader.exists(p):
		var sbt := StyleBoxTexture.new()
		sbt.texture = load(p)
		sbt.set_texture_margin_all(28.0)   # ~180px source corners → crisp at cell size
		return sbt
	return _cell_style()

# One painted nav button: a flat Button hosting the kit sprite (`ui/nav/<kit_name>`),
# centered + aspect-kept in a px×px box, with the shared press juice. Falls back to a glyph
# Look.icon when the sprite is absent (kit_name → icon id by dropping "nav_"/".png").
# An expanding gap between two nav buttons — the full-width row distributes its leftover
# space equally across these so the 5 buttons spread evenly edge to edge.
# A round painted button for the bottom nav (Bag + Merchant): hosts the round wood `nav/<art>`
# sprite (matching board.png), with the stash/sell preview riding on top. A drop is resolved by
# global-rect in _on_release, so a round button is as good a target as the old square well. Falls
# back to the slot-tile well when the sprite is absent.
func _tray_well(px: float, art: String = "") -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var p := Look.kit("nav/" + art) if art != "" else ""
	if art != "" and ResourceLoader.exists(p):
		var t := TextureRect.new()
		t.texture = load(p)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(t)
	else:
		var bg := Panel.new()
		bg.add_theme_stylebox_override("panel", _slot_style())
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bg)
	Look.add_press_juice(b)
	return b

# The Bag/Merchant well, built on the SHARED home-button shell (cream/gold disc + the lifted icon) so it
# matches the rest of the bar; the stash/sell preview overlays still ride on top and the drop is resolved
# by global-rect, so a home-button disc is as good a target as the old wood well. Soft-loads the kit by
# path (engine → game-tool bridge); falls back to the wood _tray_well if the kit can't load.
func _home_well(px: float, icon_id: String, fallback_art: String) -> Button:
	var Kit: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
	if Kit == null:
		return _tray_well(px, fallback_art)
	var opts: Dictionary = Kit.home_button_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	opts["px"] = px
	opts["calm"] = FX.calm()
	return Kit.home_button({"icon": icon_id, "caption": "", "sparkle": false}, opts)

# The Bag well (bottom nav): tap → the full bag overlay; a board item dragged onto it stashes
# (the drop is resolved in _on_release by global-rect). bag_content shows the most-recent stashed
# item (centered, no count badge — the full total lives in the overlay).
func _make_bag_button(px: float) -> Button:
	var b := _home_well(px, "bag", "nav_bag.png")     # the home-button disc + the lifted satchel icon
	bag_content = CenterContainer.new()        # CENTERS the most-recent stashed item over the satchel
	bag_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pad := px * 0.30
	bag_content.offset_left = pad
	bag_content.offset_top = pad
	bag_content.offset_right = -pad
	bag_content.offset_bottom = -pad
	bag_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_piece_px = px * 0.40                    # small preview that rides on the satchel body
	b.add_child(bag_content)
	b.pressed.connect(_open_bag_overlay)
	return b

# The Merchant well (bottom nav): drag a board spare onto it to SELL (drop resolved in _on_release).
# While a spare is dragged the well brightens and merchant_pay previews the payout (+N coin/acorn);
# a tap is a gentle nudge (the verb is drag-to-sell). The fence sell-stall is retired.
func _make_merchant_button(px: float) -> Button:
	var b := _home_well(px, "sack", "nav_merchant.png")   # the home-button disc + the lifted coin-sack icon
	merchant_rest = null
	merchant_pay = HBoxContainer.new()
	merchant_pay.alignment = BoxContainer.ALIGNMENT_CENTER
	merchant_pay.add_theme_constant_override("separation", 2)
	merchant_pay.set_anchors_preset(Control.PRESET_FULL_RECT)
	merchant_pay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	merchant_pay.visible = false
	merchant_pay_lbl = Label.new()
	merchant_pay_lbl.add_theme_font_size_override("font_size", int(px * 0.26))
	merchant_pay_lbl.add_theme_color_override("font_color", Color("#33402F"))
	merchant_pay_lbl.add_theme_color_override("font_outline_color", CREAM)
	merchant_pay_lbl.add_theme_constant_override("outline_size", 4)
	merchant_pay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	merchant_pay.add_child(merchant_pay_lbl)
	merchant_pay_icon = Control.new()
	merchant_pay_icon.custom_minimum_size = Vector2(px * 0.32, px * 0.32)
	merchant_pay_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	merchant_pay.add_child(merchant_pay_icon)
	b.add_child(merchant_pay)
	b.pressed.connect(func() -> void:
		Audio.play("button_tap", -2.0)
		FX.floating_text(self, b.get_global_rect().get_center() - Vector2(120, 70), tr("drag a spare here to sell"), CREAM, 26))
	return b

# Open the full bag overlay (the bottom-nav Bag well's tap). Tapping an item there returns it to
# the board's first empty cell; the +slot tile buys a slot. Built in ui/bag_overlay.gd (pure view).
func _open_bag_overlay() -> void:
	Audio.play("button_tap", -2.0)
	var owned := Save.bag_slots()
	BagOverlay.open(self, {
		"bag": bag,
		"owned": owned,
		"balance": Save.diamonds(),               # the acorn counter (💎, drawn as the grove's acorn)
		"max_slots": G.BAG_MAX_SLOTS,             # the ladder length (locked future slots show below)
		"start_slots": G.BAG_START_SLOTS,         # prices index from the first purchasable slot
		"prices": G.BAG_SLOT_PRICES,              # the per-expansion 💎 price ladder
		"on_retrieve": func(i: int) -> void: _retrieve_to_first_empty(i),
		"on_buy_slot": _buy_bag_slot,
		"gen_bag": board.gen_bag,
		"on_place_gen": func(id: String) -> void:
			var cells := board.empty_ground_cells()
			if cells.is_empty():
				Audio.play("invalid_soft", -6.0)
				return
			if not board.place_gen_from_bag(id, Vector2i(cells[0])):
				return
			_persist()
			_rebuild_all(),
	})

# Return bagged item `i` to the first empty board cell (the overlay's click-to-retrieve path).
func _retrieve_to_first_empty(i: int) -> void:
	var empties := board.empty_ground_cells()
	if empties.is_empty():
		Audio.play("invalid_soft", -6.0)
		return
	_retrieve_from_bag(i, empties[0])

# The empty playable cell — a Sunk-plane well (UI redesign): CELL_EMPTY fill, a faint
# inset line, and NO drop shadow (Sunk floats nothing), so it reads as a recessed slot
# on the SURFACE field. Static so it is unit-testable in isolation (grove_tests).
static func _cell_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.CELL_EMPTY
	sb.set_corner_radius_all(Tuning.UiSkin.RADIUS_CARD)
	sb.set_border_width_all(Tuning.UiSkin.INSET_LINE_W)
	sb.border_color = Tuning.UiSkin.INSET_LINE
	sb.shadow_color = Tuning.UiSkin.SHADOW_SUNK
	sb.shadow_size = Tuning.UiSkin.SHADOW_SUNK_SIZE
	sb.shadow_offset = Tuning.UiSkin.SHADOW_SUNK_OFFSET
	return sb

# The board backdrop — the painted grove meadow (sky + windmill + fence rail + flowers,
# `ui/bg_grove_board2.png`). Items + grid pop against it; the dynamic givers/merchant ride
# over the painted fence band. Falls back to the flat SURFACE field when the art is absent.
static func _field_backdrop() -> Control:
	var path := Game.art("ui/bg_grove_board2.png")
	if ResourceLoader.exists(path):
		var bg := TextureRect.new()
		bg.texture = load(path)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return bg
	var c := ColorRect.new()
	c.color = Pal.SURFACE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

# The quest band behind the givers (UI redesign) — a LIGHT Rest-plane strip (SURFACE_FRAME) with
# a quiet rim + soft resting shadow, replacing the old dark wooden fence. Static so it is testable.
static func _quest_band_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Pal.SURFACE_FRAME, 0.92)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = Color(Pal.BARK, 0.22)
	sb.shadow_color = Color(0, 0, 0, 0.12)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	return sb

func _make_bramble(cell: Vector2i) -> Control:
	var frontier := _is_frontier_bramble(cell)
	# unlockable NOW = on the frontier AND the player's Level has reached this cell's gate, so a
	# merge beside it would open it (board_model.openable_brambles is the authority).
	var unlockable := frontier and G.cell_min_level(cell) <= _quest_level()
	return PieceView.make_bramble(cell, csz, frontier, unlockable)

# A locked cell is on the FRONTIER when at least one 4-neighbour is already open (playable) — only
# these show the numbered lock; deeper locks stay numberless + receded (board-UI pass item 3).
func _is_frontier_bramble(cell: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if board.is_open(cell + d):
			return true
	return false

# Re-evaluate every locked cell's frontier/unlockable state and rebuild its tile in place. Called
# when the open set changes (a bramble opened) or the player levels up (a deeper gate becomes
# reachable) — cheap (~one map's locked cells), keeps the highlight + numbering live.
func _refresh_locked_cells() -> void:
	if board == null:
		return
	for cell in bramble_nodes.keys():
		var old: Control = bramble_nodes[cell]
		if old == null or not is_instance_valid(old):
			continue
		var nb := _make_bramble(cell)
		nb.position = _cell_pos(cell)
		board_area.add_child(nb)
		board_area.move_child(nb, old.get_index())
		old.queue_free()
		bramble_nodes[cell] = nb

func _make_generator(id: String) -> Control:
	return PieceView.make_generator(String(id), csz)

# --- input ---------------------------------------------------------------------

func _on_board_input(event: InputEvent) -> void:
	_idle = 0.0
	if animating:
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event is InputEventScreenTouch
	if pressed and event.pressed:
		_on_press(event.position)
	elif pressed and not event.pressed:
		_on_release(event.position)
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and _drag_node != null:
		_drag_node.position = event.position - Vector2(csz, csz) / 2.0

func _on_press(pos: Vector2) -> void:
	var cell := _pos_to_cell(pos)
	_press_cell = cell
	_press_pos = pos
	_drag_is_gen = board.is_gen(cell)
	if _drag_is_gen:                          # a generator is a movable piece now (§2/T17)
		_drag_from = cell
		_drag_node = gen_nodes.get(cell)
		if _drag_node != null:
			_drag_node.z_index = 20
			_drag_node.scale = Vector2(1.12, 1.12)
			PieceView.set_lifted(_drag_node, true)   # spread the shadow — the generator lifts off
			Audio.play("item_pickup", -6.0)
		return
	if board.item_at(cell) > 0:
		_drag_from = cell
		_drag_node = piece_nodes.get(cell)
		if _drag_node != null:
			_drag_node.z_index = 20
			_drag_node.scale = Vector2(1.12, 1.12)
			PieceView.set_lifted(_drag_node, true)   # spread the shadow — the item lifts off
			Audio.play("item_pickup", -6.0)
			_show_drag_targets(board.item_at(cell))   # light the drop targets: Bag (stash) + cart (sell)

func _on_release(pos: Vector2) -> void:
	if _drag_is_gen:
		_release_gen(pos)
		return
	if _drag_node == null:
		var tap := _pos_to_cell(pos)
		if tap == _press_cell and board.is_bramble(tap):
			LevelPopup.open(self)   # tap a locked cell -> the level screen (its gate Level + your progress)
		return
	var target := _pos_to_cell(pos)
	var from := _drag_from
	var node := _drag_node
	_drag_node = null
	_drag_from = Vector2i(-1, -1)
	node.z_index = 0
	node.scale = Vector2.ONE
	PieceView.set_lifted(node, false)   # back to the tight resting shadow
	_hide_drag_targets()   # drag ended — settle the Bag + cart back to rest (stop the pulse)
	# the bag and the merchant's cart are drop targets too (global-rect check)
	var gp: Vector2 = board_area.get_global_transform() * pos
	if bag_btn != null and is_instance_valid(bag_btn) and bag_btn.get_global_rect().has_point(gp):
		_stash(from, node)
		return
	if merchant_btn != null and is_instance_valid(merchant_btn) \
			and merchant_btn.get_global_rect().has_point(gp):
		_sell_item(from, node)
		return
	if target == from and G.is_coin(board.item_at(from)):
		_collect_coin(from, node)          # tapping a coin pockets it
	elif target == from and board.item_at(from) > 0 and pos.distance_to(_press_pos) <= 18.0:
		_snap_back(from, node)             # a STILL tap shows the upgrade path
		_open_ladder(BoardModel.line_of(board.item_at(from)), BoardModel.tier_of(board.item_at(from)))
	elif board.can_merge(from, target):
		_commit_merge(from, target, node)
	elif board.is_empty_ground(target) and target != from:
		_commit_move(from, target, node)
	elif Features.on("drag_swap") and target != from \
			and board.item_at(target) > 0 and not board.is_gen(target) \
			and piece_nodes.has(target):
		_commit_swap(from, target, node)        # P: trade two unlocked items
	else:
		_snap_back(from, node)

## A generator was dragged (T17). A still tap pops it; otherwise it MOVES to empty ground
## (#1) or EVOLVES onto the predecessor it upgrades (#2 — the grant→old merge). A generator
## is never sold and never normal-merges; any other drop snaps it back.
func _release_gen(pos: Vector2) -> void:
	_drag_is_gen = false
	var target := _pos_to_cell(pos)
	var from := _drag_from
	var node := _drag_node
	_drag_node = null
	_drag_from = Vector2i(-1, -1)
	if node != null:
		node.z_index = 0
		node.scale = Vector2.ONE
		PieceView.set_lifted(node, false)   # back to the tight resting shadow
	if target == from and pos.distance_to(_press_pos) <= 18.0:
		if node != null:
			node.position = _cell_pos(from)
		_pop_seed(from)                       # a still tap pops the generator (merge fuel)
		return
	var gp: Vector2 = board_area.get_global_transform() * pos
	if bag_btn != null and is_instance_valid(bag_btn) and bag_btn.get_global_rect().has_point(gp):
		if board.store_gen(from):
			_persist()
			_rebuild_all()
			FX.celebrate_at(self, bag_btn.get_global_rect().get_center(), tr("Stored!"), STRAW)
		elif node != null:
			_snap_back(from, node)
		return
	if merchant_btn != null and is_instance_valid(merchant_btn) \
			and merchant_btn.get_global_rect().has_point(gp):
		if node != null:
			_snap_back(from, node)            # never sold
		return
	if target != from and board.is_empty_ground(target) and board.move_gen(from, target):
		Audio.play("item_drop", -3.0)
		_persist()
		_rebuild_all()                        # #1 move (generators are movable-only; new ones arrive via near-end reward → gen_bag)
		return
	if node != null:
		_snap_back(from, node)                # occupied / bramble / dropped on another gen — refuse

func _snap_back(from: Vector2i, node: Control) -> void:
	var t := node.create_tween()
	t.tween_property(node, "position", _cell_pos(from), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("invalid_soft", -8.0)

# --- actions ---------------------------------------------------------------------

func _pop_seed(cell: Vector2i = Vector2i(-1, -1)) -> void:
	if cell.x < 0:                            # default: the first live generator (tests / FTUE / no-arg)
		if board.gens.is_empty():
			return
		cell = board.gens.keys()[0]
	var gnode: Control = gen_nodes.get(cell, gen_node)
	var charged := _ftue_pops_done()          # once the FTUE intro pops are spent, each item costs energy
	if charged and water < G.POP_COST:
		FX.wobble(gnode)
		Audio.play("invalid_soft", -4.0)
		_update_water_hud()                # surfaces the refill offer if available
		return
	var empties := board.empty_ground_cells()
	if empties.is_empty():
		FX.wobble(gnode)                   # full board pauses the generator for FREE
		Audio.play("invalid_soft", -4.0)
		return
	# Burst-pop (§6): one tap throws a BURST, not just one item. Its size scales with the map (a
	# free per-map step-up) and the player's paid burst-upgrade; bound it by what's affordable
	# (energy) and what fits (open cells). Each popped item still costs G.POP_COST.
	# FTUE (§4): during the free-pop intro a tap pops EXACTLY ONE item — burst is suppressed so the
	# 10 free pops are ~10 deliberate frictionless taps (not spent 3-at-a-time) and the counter can't
	# overshoot 10 mid-burst. Burst resumes the moment the free budget is gone (`charged`).
	var burst := 1 if not charged else G.burst_count(_quest_map(), _gen_burst_level(), rng)
	if charged:
		burst = mini(burst, int(water / G.POP_COST))
	burst = mini(burst, empties.size())
	# the spawn decision (landing cell + code) is board_logic's; the active givers' wanted lines AND
	# poppable wanted tiers bias every item's roll (§6). Pool + wanted are fixed across the burst.
	# RNG order is load-bearing.
	var pool: Array = G.gen_def(G.GENERATORS, board.gen_id_at(cell)).get("lines", [])
	var giver_quests: Array = []
	for e in giver_chips:
		if int(e.qi) >= 0 and int(e.qi) < quests.size():
			giver_quests.append(quests[int(e.qi)])
	var wanted: Array = BoardLogic.wanted_lines(pool, giver_quests)
	# §6 spawn tier-bias is OFF by default (G.ASK_TIER_WEIGHT = 0, owner pacing dial) — skip the dict then.
	var wanted_t: Dictionary = BoardLogic.wanted_tiers(pool, giver_quests) if G.ASK_TIER_WEIGHT > 0.0 else {}
	var g := Save.grove()
	if Audio.has("water_pop"):
		Audio.play("water_pop", -2.0)
	# W2: the spawn flight is COSMETIC and must NOT set `animating` — that flag gates the board
	# input surface, so a 0.22s flight used to EAT the next generator tap. Items are placed in
	# the model immediately; `animating` now guards MERGES only, so rapid taps each land.
	for _b in burst:
		if charged:
			water -= G.POP_COST
		g["pops"] = int(g.get("pops", 0)) + 1
		var spawn := BoardLogic.roll_spawn(empties, cell, pool, wanted, rng, wanted_t, G.ASK_TIER_WEIGHT)
		var pick: Vector2i = spawn.cell
		var code: int = spawn.code
		board.place(pick, code)
		empties.erase(pick)                # each burst item lands in its own cell
		_mark_seen(code)
		_note_item_landed(code)            # W3: a spawned max-tier item also triggers the one-time hint
		var n := _make_piece(code, csz)
		n.position = _cell_pos(cell)
		n.scale = Vector2(0.3, 0.3)
		board_area.add_child(n)
		piece_nodes[pick] = n
		var t := n.create_tween()
		t.set_parallel(true)
		t.tween_property(n, "position", _cell_pos(pick), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(n, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	FX.pop(gnode)
	if not Audio.has("water_pop"):
		Audio.play("item_drop", -3.0, 1.1)
	_persist()
	_refresh_giver_lights()
	_refresh_generator_dim()   # §6: a burst may have filled the last cell → dim the generator(s)
	_update_water_hud()

# The player's paid burst-upgrade level (the burst-upgrade COIN SINK, §6/§8) — persisted in the
# grove blob, read by _pop_seed to size the burst. 0 = unbought.
func _gen_burst_level() -> int:
	return int(Save.grove().get("burst_lvl", 0))

# Spend coins to raise the burst-upgrade one level (the coin sink): a bigger burst per tap. Refuses
# when broke or already atop the cost ladder. The upgrade surface (parked, hub-concentrated) calls this.
func _upgrade_gen_burst() -> bool:
	var lvl := _gen_burst_level()
	var cost := G.burst_upgrade_cost(lvl)
	if cost < 0:
		return false                          # already at the max burst-upgrade level
	if not Save.spend(cost, "burst_upgrade"):
		return false                          # not enough coins
	Save.grove()["burst_lvl"] = lvl + 1
	_persist()
	return true

# (The on-board burst-upgrade buy pill — _rebuild_burst_chip / _on_burst_chip_input /
#  _refresh_burst_chip / _try_buy_burst — was the dark stat_chip pill; retired T48 ahead of the UI
#  redesign. The §6 coin sink lives on in _gen_burst_level + _upgrade_gen_burst above (still tested);
#  the redesign re-surfaces a burst-upgrade buy affordance in the new chip language.)

func _commit_merge(a: Vector2i, b: Vector2i, node: Control) -> void:
	var produced := board.merge(a, b)
	piece_nodes.erase(a)
	animating = true
	var t := node.create_tween()
	t.tween_property(node, "position", _cell_pos(b), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(_after_merge.bind(a, b, produced, node))

func _after_merge(_a: Vector2i, b: Vector2i, produced: int, moved: Control) -> void:
	if is_instance_valid(moved):
		moved.queue_free()
	var old: Control = piece_nodes.get(b)
	if old != null and is_instance_valid(old):
		old.queue_free()
	_mark_seen(produced)
	_note_item_landed(produced)   # W3: first max-tier item → one-time "sell at the stall" hint
	var n := _make_piece(produced, csz)
	n.position = _cell_pos(b)
	board_area.add_child(n)
	piece_nodes[b] = n
	FX.pop(n)
	var tier := BoardModel.tier_of(produced)
	FX.burst(board_area, _cell_pos(b) + Vector2(csz, csz) / 2.0, STRAW if tier >= 4 else Color("#7FA65A"), 10 + tier * 3)
	Audio.play("merge_success" if tier >= 4 else "merge_soft", -1.0, clampf(0.95 + 0.03 * tier, 0.9, 1.3))
	# a merge beside a sealed cell opens it once the player's Level has reached its §4 gate
	for cell in board.openable_brambles(b, _quest_level()):
		_open_bramble(cell)
	_refresh_locked_cells()   # the open set changed → re-evaluate neighbours' frontier/highlight
	# a little luck: merges sometimes shake a coin loose
	if BoardLogic.rolls_coin_drop(produced, rng):
		_drop_coin_near(b)
	animating = false
	_persist()
	_refresh_giver_lights()
	_refresh_generator_dim()   # §6: a merge freed a cell → un-dim the generator(s) if the board was full
	_update_hud()

func _open_bramble(cell: Vector2i) -> void:
	var contents := board.open_bramble(cell)
	_mark_seen(contents)
	Audio.play("bramble_clear" if Audio.has("bramble_clear") else "tidy_poof", -2.0)
	var br: Control = bramble_nodes.get(cell)
	bramble_nodes.erase(cell)
	if br != null and is_instance_valid(br):
		var t := br.create_tween()
		t.set_parallel(true)
		t.tween_property(br, "scale", Vector2(1.35, 1.35), 0.25).set_ease(Tween.EASE_OUT)
		t.tween_property(br, "modulate:a", 0.0, 0.25)
		t.chain().tween_callback(br.queue_free)
	var slot := _make_slot(cell)   # #7: same shared soft-well builder as _rebuild_all
	board_area.add_child(slot)
	# right ABOVE the mat (child 0), under brambles/pieces — index 0 hid the
	# tile behind the moss until the next full rebuild (owner's "no border" bug)
	board_area.move_child(slot, 1)
	slot_nodes[cell] = slot
	var n := _make_piece(contents, csz)
	n.position = _cell_pos(cell)
	n.scale = Vector2(0.3, 0.3)
	board_area.add_child(n)
	piece_nodes[cell] = n
	var t2 := n.create_tween()
	t2.tween_property(n, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	FX.burst(board_area, _cell_pos(cell) + Vector2(csz, csz) / 2.0, Color("#7FA65A"), 16)
	FX.floating_text(self, board_area.get_global_transform() * (_cell_pos(cell)) - Vector2(10, 40), tr("Cleared!"), CREAM, 34)
	Audio.play("tidy_poof", -2.0)

func _drop_coin_near(near: Vector2i) -> void:
	var empties := board.empty_ground_cells()
	if empties.is_empty():
		return
	empties.sort_custom(func(a, b): return (a - near).length_squared() < (b - near).length_squared())
	var cell: Vector2i = empties[rng.randi_range(0, mini(2, empties.size() - 1))]
	var code := G.COIN_LINE * 100 + 1
	board.place(cell, code)
	var n := _make_piece(code, csz)
	n.position = _cell_pos(near)
	n.scale = Vector2(0.3, 0.3)
	board_area.add_child(n)
	piece_nodes[cell] = n
	var t := n.create_tween()
	t.set_parallel(true)
	t.tween_property(n, "position", _cell_pos(cell), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("tidy_poof", -5.0, 1.3)

func _collect_coin(cell: Vector2i, node: Control) -> void:
	var code := board.take(cell)
	piece_nodes.erase(cell)
	Save.add_coins(G.coin_value(code))
	if node != null and is_instance_valid(node):
		var dest: Vector2 = coins_label.get_global_rect().get_center() - board_area.get_global_transform().origin - Vector2(csz, csz) / 2.0
		var t := node.create_tween()
		t.set_parallel(true)
		t.tween_property(node, "position", dest, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(node, "scale", Vector2(0.3, 0.3), 0.3)
		t.chain().tween_callback(node.queue_free)
	FX.floating_text(self, board_area.get_global_transform() * _cell_pos(cell) - Vector2(0, 30), "+%d" % G.coin_value(code), STRAW, 32)
	Audio.play("star_earn" if Audio.has("star_earn") else "merge_soft", -3.0, 1.2)
	_persist()
	_update_hud()
	_refresh_giver_lights()
	_refresh_generator_dim()   # §6: collecting a coin freed a cell → un-dim if the board was full

func _commit_move(a: Vector2i, b: Vector2i, node: Control) -> void:
	board.move(a, b)
	piece_nodes.erase(a)
	piece_nodes[b] = node
	var t := node.create_tween()
	t.tween_property(node, "position", _cell_pos(b), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Audio.play("item_drop", -4.0)
	_persist()
	_refresh_giver_lights()

# P: the dragged item settles into `b`; the item already there glides to `a` with
# the same TRANS_BACK ease as a snap-back, so it reads as "we traded places".
func _commit_swap(a: Vector2i, b: Vector2i, node: Control) -> void:
	var other: Control = piece_nodes.get(b)
	board.swap(a, b)
	piece_nodes[b] = node
	piece_nodes[a] = other
	node.create_tween().tween_property(node, "position", _cell_pos(b), 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if other != null and is_instance_valid(other):
		other.create_tween().tween_property(other, "position", _cell_pos(a), 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("item_drop", -4.0)
	_persist()
	_refresh_giver_lights()

# --- bag --------------------------------------------------------------------------

# §5: the bag holds as many items as the player OWNS slots (6 at start, bought up to 18).
func _bag_capacity() -> int:
	return BoardLogic.bag_capacity(Save.bag_slots())

# Is there a buyable "+slot" affordance at the end of the bar right now? (Below the cap only.)
func _bag_has_buy_slot() -> bool:
	return Save.bag_slots() < G.BAG_MAX_SLOTS

# §10: pull any item-shortcuts bought in the (open) Shop into the live bag, up to
# capacity, then persist + rebuild the bag UI so the new pieces show without a reload.
# Leftovers (bag full) stay queued for the next open / a freed slot.
func _drain_shop_pieces() -> void:
	if Shop.drain_pending(bag, _bag_capacity()) > 0:
		for v in bag:
			_mark_seen(int(v))
		_persist()
		_rebuild_bag()
		_refresh_giver_lights()

func _stash(from: Vector2i, node: Control) -> void:
	if bag.size() >= _bag_capacity():
		_snap_back(from, node)
		return
	var code := board.take(from)
	bag.append(code)
	piece_nodes.erase(from)
	if is_instance_valid(node):
		node.queue_free()
	Audio.play("bag_in" if Audio.has("bag_in") else "item_pickup", -2.0)
	_persist()
	_rebuild_bag()
	_refresh_giver_lights()

# §5 expansion: buy ONE more slot with 💎 at the schedule price, then regrow the bar. A refusal
# (broke or already maxed) just wobbles — convenience, never a wall (§4/§5).
func _buy_bag_slot() -> void:
	var price := G.next_bag_slot_price(Save.bag_slots())
	if price > 0 and Save.buy_bag_slot(price):
		Audio.play("level_complete", -4.0, 1.2)
		if bag_btn != null and is_instance_valid(bag_btn):
			FX.celebrate_at(self, bag_btn.get_global_rect().get_center(), tr("Bag +1!"), STRAW)
		_build_bag_bar()              # one more owned slot → refresh the bag well
		_update_hud()
	else:
		if bag_btn != null and is_instance_valid(bag_btn):
			FX.wobble(bag_btn)
		Audio.play("invalid_soft", -4.0)

# §5 drag-back retrieve (the model half — also the headless-test seam): drop bagged item `i`
# onto board `cell`. The cell must be empty ground; returns whether it was placed.
func _retrieve_from_bag(i: int, cell: Vector2i) -> bool:
	if i < 0 or i >= bag.size():
		return false
	if not board.is_empty_ground(cell):
		return false
	var code := int(bag[i])
	bag.remove_at(i)
	board.place(cell, code)
	var n := _make_piece(code, csz)
	n.position = _cell_pos(cell)
	n.scale = Vector2(0.3, 0.3)
	board_area.add_child(n)
	piece_nodes[cell] = n
	n.create_tween().tween_property(n, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("bag_out" if Audio.has("bag_out") else "item_drop", -3.0)
	_persist()
	_rebuild_bag()
	_refresh_giver_lights()
	return true

# (Re)build the bag-bar buttons to match the OWNED slot count, plus a trailing "+slot" buy
# affordance while below the cap. Called at _ready and whenever a slot is bought (the count grows
# at runtime, so the row is rebuilt, not just refilled). Each item slot is a DRAG SOURCE for the
# §5 drag-back retrieve; the buy slot is a tap.
func _build_bag_bar() -> void:
	_rebuild_bag()   # the bag is a single bottom-nav well now; just refresh it

# Refresh the bottom-nav Bag well: show the most-recent stashed item in the circle (empty when the
# bag is empty) and a count pill when more than one is held.
func _rebuild_bag() -> void:
	if bag_content == null or not is_instance_valid(bag_content):
		return
	for c in bag_content.get_children():
		c.queue_free()
	if not bag.is_empty():
		# the most-recent stashed item, sized to fit the well and CENTERED (bag_content is a
		# CenterContainer) — never stretched to fill, which over-scaled the art past the slot.
		bag_content.add_child(_make_piece(int(bag[bag.size() - 1]), bag_piece_px))

# §5 drag-back: a press on a FILLED bag slot lifts a preview that follows the cursor; releasing
# over an empty board cell places it (else it snaps back to the bag). Reuses the board's _drag_node
# slot, gated by _bag_drag_idx so the board-piece drag path (idx -1) is untouched. Motion + release
# while the drag is live are tracked in _input (the cursor leaves this button onto the board).
func _on_bag_slot_input(event: InputEvent, i: int) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed or _bag_drag_idx >= 0 or _drag_node != null:
		return
	if i >= bag.size():
		return
	_bag_drag_idx = i
	var n := _make_piece(int(bag[i]), csz)
	n.z_index = 40
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(n)
	n.global_position = get_global_mouse_position() - Vector2(csz, csz) / 2.0
	_drag_node = n
	bag_slots_ui[i].modulate = Color(1, 1, 1, 0.4)   # the slot dims while its item is in hand
	Audio.play("item_pickup", -6.0)

func _input(event: InputEvent) -> void:
	if _bag_drag_idx < 0 or _drag_node == null:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		_drag_node.global_position = get_global_mouse_position() - Vector2(csz, csz) / 2.0
	elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
			or (event is InputEventScreenTouch and not event.pressed):
		_end_bag_drag(get_global_mouse_position())

# Resolve a bag drag-back at the global release point: place on the board cell under the cursor
# if it is empty ground, else snap the item back into the bag (no loss).
func _end_bag_drag(gpos: Vector2) -> void:
	var i := _bag_drag_idx
	var node := _drag_node
	_bag_drag_idx = -1
	_drag_node = null
	if is_instance_valid(node):
		node.queue_free()
	if i >= 0 and i < bag_slots_ui.size() and is_instance_valid(bag_slots_ui[i]):
		bag_slots_ui[i].modulate = Color.WHITE
	var local: Vector2 = board_area.get_global_transform().affine_inverse() * gpos
	var cell := _pos_to_cell(local)
	if board_area.get_global_rect().has_point(gpos) and _retrieve_from_bag(i, cell):
		return
	Audio.play("invalid_soft", -8.0)
	_rebuild_bag()                                    # the dimmed slot restores; item stays put

# --- givers / merchant / gate actions ----------------------------------------------

func _on_giver_tap(qi: int, chip: Control) -> void:
	if qi < 0 or qi >= quests.size():
		return
	var q: Dictionary = quests[qi]
	var it: Dictionary = G.quest_item(q)
	if not BoardLogic.quest_payable(board, q):
		FX.wobble(chip)
		Audio.play("invalid_soft", -6.0)
		return
	var code := int(it.line) * 100 + int(it.tier)
	var cell := board.first_item_of(code)
	board.take(cell)
	var n: Control = piece_nodes.get(cell)
	piece_nodes.erase(cell)
	if n != null and is_instance_valid(n):
		var dest := chip.get_global_rect().get_center() - board_area.get_global_transform().origin - Vector2(csz, csz) / 2.0
		var t := n.create_tween()
		t.set_parallel(true)
		t.tween_property(n, "position", dest, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(n, "scale", Vector2(0.4, 0.4), 0.3)
		t.chain().tween_callback(n.queue_free)
	quests.remove_at(qi)                      # §7: the delivered quest leaves the live fence
	# delivering a quest is the ONE place Level advances — earn_stars credits the
	# spendable balance AND the earned clock, and gifts water+💎 on a level-up.
	var sp_stars := _quest_stars(q)
	var sp_coins := _quest_coins(q)
	var sp_gems := _quest_gems(q)             # §7: a featured quest may carry an occasional 💎 bonus
	var levels_up := G.earn_stars(sp_stars)
	if sp_coins > 0:
		Save.add_coins(sp_coins)              # §7/§10: the quest coin faucet
	if sp_gems > 0:
		Save.add_diamonds(sp_gems)            # §7: the featured-quest premium bonus (never extra ★)
	# the near-end map quest grants the NEXT map's generator(s) — auto-placed on the board's first
	# open cell so the new map opens with its tool already producing; gen_bag is only a fallback when
	# the board is full (the player can still store a generator into the bag at will).
	var got_gens: Array = []
	if q.has("reward") and q.reward.has("generators"):
		for gid in q.reward.generators:
			var id := String(gid)
			if board.gen_bag.has(id) or board.gens.values().has(id):
				continue                       # already owned (on board or stored)
			var dest := Vector2i(-1, -1)
			for c in board.empty_ground_cells():
				if not board.gens.has(c):
					dest = c
					break
			if dest == Vector2i(-1, -1):
				board.gen_bag.append(id)       # board full → hold it in the bag
			else:
				board.place_gen(id, dest)
			got_gens.append(id)
	FX.celebrate_reward(self, chip.get_global_rect().get_center(), "star", sp_stars, STRAW)
	if sp_coins > 0:
		FX.floating_reward(self, chip.get_global_rect().get_center() + Vector2(20, 36), "coin", sp_coins, STRAW, 26)
	if sp_gems > 0:
		FX.floating_reward(self, chip.get_global_rect().get_center() + Vector2(20, 64), "gem", sp_gems, Color("#BFE6F2"), 26)
	Audio.play("giver_cheer" if Audio.has("giver_cheer") else "merge_success", -2.0, 1.2)
	if not got_gens.is_empty():
		# a new tool arrived on the board (gen_bag is just the fallback if the board was full)
		FX.celebrate_at(self, chip.get_global_rect().get_center() - Vector2(0, 60), tr("A new tool arrived!"), STRAW)
		Audio.play("level_complete" if Audio.has("level_complete") else "merge_success", -3.0, 1.1)
	if levels_up > 0:
		water = int(Save.grove().get("water", water))   # re-sync the local after the level-up gift
		_update_water_hud()
		_refresh_locked_cells()   # a level-up may make deeper frontier cells unlockable now
		var lv := G.level_for_stars(int(Save.grove().get("stars_earned", 0)))
		FX.celebrate_at(self, Vector2(get_global_rect().get_center().x, 240), tr("Level %d!") % lv, STRAW)
		FX.floating_reward(self, Vector2(get_global_rect().get_center().x - 130, 320),
			"water", G.LEVEL_WATER_GIFT * levels_up, Color("#9CCDE8"), 36)
		FX.floating_reward(self, Vector2(get_global_rect().get_center().x + 40, 320),
			"gem", G.LEVEL_DIAMONDS * levels_up, Color("#BFE6F2"), 36)
		Audio.play("level_complete", -1.0)
	_persist()
	_rebuild_givers()
	_refresh_generator_dim()   # §6: delivering items freed cells → un-dim the generator(s)
	_update_hud()
	# §10: a quest's coin overflow is the surviving lump coin faucet — the re-home of the old
	# hub-collect 2× doubler. Offer to double it via a rewarded ad (opt-in, capped by Ads.can_show).
	if sp_coins > 0:
		_maybe_offer_2x(sp_coins, chip.get_global_rect().get_center())
	if _gate_ready() and home_btn != null and is_instance_valid(home_btn):
		FX.floating_text(self, home_btn.get_global_rect().get_center() - Vector2(140, 120), tr("Ready to restore!"), STRAW, 40)

# The cozy, optional 2× DOUBLER card — re-homed from the removed hub yield-collect to the quest
# COIN reward (the surviving lump coin faucet, §7/§10). Shown after a quest pays `got` coins when
# the rewarded ad is offerable; accept → claim the ad + credit a SECOND `got`. Opt-in, dismissible,
# one at a time, never blocks play. The board frees on scene-change, so no nav-dismiss is needed.
func _maybe_offer_2x(got: int, _center: Vector2) -> void:
	if got <= 0 or not Ads.can_show("collect_2x"):
		return
	if not is_inside_tree():
		return
	if _2x_offer != null and is_instance_valid(_2x_offer):
		_2x_offer.queue_free()                       # never stack offers
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	# pinned just under the wallet/HUD, centered — near the reward FX, clear of the board
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.offset_top = 150.0 + Look.safe_top(self)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.z_index = 40
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)
	# the pitch — copy + an icon/number ("+ N coin"), emoji-free per §13 (coin is a sprite)
	var pitch := HBoxContainer.new()
	pitch.alignment = BoxContainer.ALIGNMENT_CENTER
	pitch.add_theme_constant_override("separation", 6)
	col.add_child(pitch)
	var pl := Label.new()
	pl.text = tr("Watch a cloud → double it!")
	pl.add_theme_font_size_override("font_size", 24)
	pl.add_theme_color_override("font_color", Pal.INK)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pitch.add_child(pl)
	var sub := HBoxContainer.new()
	sub.alignment = BoxContainer.ALIGNMENT_CENTER
	sub.add_theme_constant_override("separation", 4)
	col.add_child(sub)
	var sl := Label.new()
	sl.text = tr("+")
	sl.add_theme_font_size_override("font_size", 22)
	sl.add_theme_color_override("font_color", Color(Pal.BARK, 0.95))
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_child(sl)
	sub.add_child(Look.icon("coin", 22.0))
	var sn := Label.new()
	sn.text = str(got)
	sn.add_theme_font_size_override("font_size", 22)
	sn.add_theme_color_override("font_color", Color(Pal.BARK, 0.95))
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

# Accept the 2× doubler: re-check + claim the rewarded ad, credit a SECOND `got` coins, celebrate
# the bonus, tick the wallet, consume the arm, and close the card. A refused claim closes cozily.
func _accept_2x_offer(got: int) -> void:
	var at := _2x_offer.get_global_rect().get_center() if _2x_offer != null and is_instance_valid(_2x_offer) else get_global_rect().get_center()
	_dismiss_2x_offer()
	var res := Ads.claim("collect_2x")
	if not bool(res.get("ok", false)):
		Audio.play("invalid_soft", -4.0)
		return
	Save.add_coins(got)                              # the doubled half — the same amount again
	Audio.play("level_complete", -3.0, 1.2)
	FX.celebrate_reward(self, at, "coin", got, Color("#E3B23C"))
	FX.fly_to_wallet(self, at, Look.icon("coin", 40.0), coins_label, func() -> void: _update_hud())
	_update_hud()

# Close the 2× offer card (decline, tap-away, or post-accept). Idempotent.
func _dismiss_2x_offer() -> void:
	if _2x_offer != null and is_instance_valid(_2x_offer):
		_2x_offer.queue_free()
	_2x_offer = null

# sell ANYTHING dragged onto the cart — tier pocket change; cleanup, never income
func _sell_item(from: Vector2i, node: Control) -> void:
	var code := board.item_at(from)
	if code <= 0:
		return
	if G.is_coin(code):
		_collect_coin(from, node)          # coins are money already — pocket them
		return
	board.take(from)
	piece_nodes.erase(from)
	_grant_sale(code, node)
	Audio.play("tidy_poof", -4.0, 1.1)
	_persist()
	_update_hud()
	_refresh_giver_lights()
	_refresh_generator_dim()   # §6: selling freed a cell → un-dim if the board was full

# Y1/Y2: pay the sale (t8 → a flat 1💎; t1–t7 → tier coins × the item's per-map band, §6),
# fly the piece into the basket, float the right currency, and RECORD the sale so it can be
# bought back for the EXACT grant until the porter comes.
func _grant_sale(code: int, node: Control) -> void:
	var reward := G.sell_reward(code)        # Vector2i(coins, diamonds)
	if reward.x > 0:
		Save.add_coins(reward.x)
	if reward.y > 0:
		Save.add_diamonds(reward.y)
		Vault.skim(reward.y)                  # T44 SKIM-SITE 3/3 (t8-sell): the piggy bank skims a slice of the t8 premium sale (§10)
	var target: Control = merchant_btn   # the sale flies into the bottom-nav merchant well
	var center: Vector2 = target.get_global_rect().get_center() if (target != null and is_instance_valid(target)) else get_global_rect().get_center()
	if node != null and is_instance_valid(node):
		var dest: Vector2 = center - board_area.get_global_transform().origin - Vector2(csz, csz) / 2.0
		var t := node.create_tween()
		t.set_parallel(true)
		t.tween_property(node, "position", dest, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(node, "scale", Vector2(0.35, 0.35), 0.25)
		t.chain().tween_callback(node.queue_free)
	if reward.y > 0:
		FX.floating_reward(self, center - Vector2(30, 60), "gem", reward.y, Color("#A9C7E8"), 30)
		if Features.on("fly_to_wallet") and stars_label != null:
			FX.fly_to_wallet(self, center, Look.icon("gem", 30.0), diamonds_label)
	else:
		FX.floating_reward(self, center - Vector2(30, 60), "coin", reward.x, STRAW, 30)
	_record_sale(code, reward)

# Y2: hold the sale for buy-back; a 4th sale overflows → the porter comes at once.
func _record_sale(code: int, reward: Vector2i) -> void:
	basket.append({"code": code, "coins": reward.x, "diamonds": reward.y})
	if basket.size() > BASKET_CAP:
		_porter_collect(true)
	else:
		_rebuild_basket()

# Y2: refund EXACTLY what was granted and return the item to a free cell (no arbitrage:
# you give back the same currency, you get the same item). Blocked (wobble) if the
# board is full or you've already spent the granted currency.
func _buy_back(idx: int) -> void:
	if idx < 0 or idx >= basket.size():
		return
	var rec: Dictionary = basket[idx]
	var empties := board.empty_ground_cells()
	if empties.is_empty() or Save.coins() < int(rec.coins) or Save.diamonds() < int(rec.diamonds):
		if basket_chip != null and is_instance_valid(basket_chip):
			FX.wobble(basket_chip)
		Audio.play("invalid_soft", -6.0)
		return
	if int(rec.coins) > 0:
		Save.spend(int(rec.coins), "buyback")
	if int(rec.diamonds) > 0:
		Save.spend_diamonds(int(rec.diamonds))
	var cell: Vector2i = empties[0]
	board.place(cell, int(rec.code))
	basket.remove_at(idx)
	var pn := _make_piece(int(rec.code), csz)
	pn.position = _cell_pos(cell)
	board_area.add_child(pn)
	piece_nodes[cell] = pn
	FX.pop(pn)
	Audio.play("item_pickup", -4.0)
	_rebuild_basket()
	_persist()
	_update_hud()
	_refresh_giver_lights()
	_refresh_generator_dim()   # §6: a bought-back item may have filled the last cell → dim

# Y2: paint the <=3 sale chips into the basket (tap one to buy it back).
func _rebuild_basket() -> void:
	if basket_chip == null or not is_instance_valid(basket_chip):
		return
	for c in basket_chip.get_children():
		c.queue_free()
	basket_chip.visible = not basket.is_empty()
	if basket.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	basket_chip.add_child(row)
	for idx in basket.size():
		var rec: Dictionary = basket[idx]
		var chip := Control.new()
		chip.custom_minimum_size = Vector2(42, 42)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.add_child(_make_piece(int(rec.code), 42.0))
		var bidx := idx
		_stand_tap(chip, func() -> void: _buy_back(bidx))
		row.add_child(chip)

# Y3: the porter spirit collects the basket — buy-back closes, items gone for good.
# The basket data clears IMMEDIATELY (the window shuts the moment he arrives); the
# sprite drift is a cosmetic flourish behind the flag. Flag OFF → chips just fade.
func _porter_collect(_early: bool) -> void:
	if basket.is_empty():
		return
	_porter_timer = 0.0
	basket.clear()
	_rebuild_basket()
	if Features.on("porter_collect"):
		_play_porter()

func _porter_tick(delta: float) -> void:
	if basket.is_empty() or _porter_running:
		_porter_timer = 0.0
		return
	_porter_timer += delta
	if _porter_timer >= PORTER_SECS:
		_porter_collect(false)

# Y3: a wandering spirit drifts along the fence to the stall and off again (cosmetic).
func _play_porter() -> void:
	if merchant_chip == null or not is_instance_valid(merchant_chip):
		return
	if not ResourceLoader.exists(Game.art("characters/spirit_porter.png")):
		return
	_porter_running = true
	var sp := TextureRect.new()
	sp.texture = load(Game.art("characters/spirit_porter.png"))
	sp.custom_minimum_size = Vector2(96, 96)
	sp.size = Vector2(96, 96)
	sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.z_index = 40
	add_child(sp)
	var mid: Vector2 = merchant_chip.get_global_rect().get_center() - Vector2(48, 96)
	sp.global_position = Vector2(-110, mid.y)
	var t := sp.create_tween()
	t.tween_property(sp, "global_position", mid, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.35)
	t.tween_property(sp, "global_position", Vector2(get_viewport_rect().size.x + 110, mid.y), 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void:
		_porter_running = false
		if is_instance_valid(sp):
			sp.queue_free())

# The real gate lives on the HOME scene now (buying a spot IS the progression step) —
# this button is the invitation: stars suffice, go decorate.
# The upgrade path: the line's full ladder, tier by tier — grown tiers show their
# art, never-seen tiers show "?", and the tapped/asked tier wears a gold ring.
func _open_ladder(line: int, mark_tier: int) -> void:
	if not Features.on("discovery_ladder") or not G.LINES.has(line):
		return
	# Wave 3: the ladder modal lives in ui/ladder.gd; the open-gate + data stay here.
	Ladder.open(self, {
		"title": tr(String(G.LINES[line].name)),
		"entries": _ladder_entries(line),
		"mark_tier": mark_tier,
	})

# The map→Map handoff target: the map the player was LAST on (persisted last_map). Empty on a
# fresh save → the Map boot falls through to the frontier. Shared by the nav Home button and the
# Decorate/gate jump — Home is no longer hard-wired to the hub; both return you where you were.
func _decorate_target() -> String:
	return String(Save.grove().get("last_map", ""))

# --- misc -------------------------------------------------------------------------

func _lbl(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", GROUND_EDGE)
	l.add_theme_constant_override("outline_size", 8)
	return l
