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
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")   # pre-warm Map off-thread so Home is snappy
const Game = preload("res://engine/scripts/core/game.gd")
const Debug = preload("res://engine/scripts/ui/debug.gd")
const SettingsUI = preload("res://engine/scripts/ui/settings.gd")   # the shared Settings card — reachable from the board, not only the map
const LevelPopup = preload("res://engine/scripts/ui/level_popup.gd")   # tap the Lv badge or a locked cell → the level screen
const Pal = Game.PALETTE
const Data = Game.DATA   # T43: the active game's DATA (the §10 out-of-water offer numbers)

var GAP := 7.0                   # #7: tight, consistent gutter (was 10) — cells sit close. Workbench-overridable (board.gap).
const BOARD_MARGIN := 6.0        # breathing room each side; the board owns the rest
const DRAG_HILITE := Color(1.12, 1.12, 1.12, 1.0)   # a drop-target well's brighten while a piece is dragged
const FENCE_H := 215.0           # the quest fence band above the grid (wide giver boxes)
const BOTTOM_BAR_H := 166.0      # the board bottom bar height (Bag · info bar · Home) — grown with the ~10%-bigger wells (#5)
const BOTTOM_BTN_PX := 130.0     # #5: the Bag/Home wells + the info bar share this height (~10% bigger than the old 118)
const STAND_W := 300.0           # fallback giver box width (merchant stall / preview); the live fence sizes by %
const GIVER_COLS := 4            # cards across the FULL width — each is ~25% of the screen (Purge card + up to 3 quests, or 4 quests)
const QUEST_SIDE := 18.0         # the fence row's left/right inset (aligns with the board's side breathing room)
const QUEST_GAP := 16.0          # gap BETWEEN cards (the "more margin between them")
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
const SHADE_DIM := Color(1, 1, 1, 1.0)      # inert: not-yet-payable giver, nothing to sell — full opacity (✓/count/bob carry the lit state)
const PURGE_DIM := Color(0.62, 0.62, 0.62, 0.85)  # the Purge card while it can't yet afford a region — greyed (no padlock)

# §6: a full board DIMS the generator(s) to a standing "paused" state — popping is free
# while dimmed, so the cue must persist (not a one-shot wobble) until a cell frees up.
# A generator's stop is a stronger signal than a giver's, so it dims further (0.5) — same
# affordance family (bright = tappable), just a deeper "paused" read for the harder stop.
const GEN_DIM := Color(1, 1, 1, 0.5)
const GEN_LIT := SHADE_LIT

var board: BoardModel
var rng := RandomNumberGenerator.new()
var quests: Array = []             # §7: the LIVE generated fence (metered to the next unlock), persisted
var _recent_givers: Array = []     # the last ≤5 assigned giver indices — a new quest's face avoids these
var _recent_lines: Array = []      # the last ≤5 asked item-lines — a NEW quest's item avoids these (§7)
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
var _board_center: Control       # the CenterContainer holding the board (placement tool nudges this)
var _place_fence_dy := 0.0       # saved vertical nudge for the quest fence (fraction of viewport height)
var _place_board_dy := 0.0       # saved vertical nudge for the board (fraction of viewport height)
var _board_scale := 1.0          # saved UI-Workbench board size (board.scale; 1.0 = the responsive full-fit)
var _board_item_inset := 0.16    # saved piece-in-cell inset (from board.item width %; 0.16 = the shipped look)
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
var _bag_count_lbl: Label            # the "x/y" bag count under the bag well
var merchant_btn: Button
var merchant_rest: Control
var merchant_pay: Control
var merchant_pay_lbl: Label
var merchant_pay_icon: Control
# the bottom-bar INFO BAR: tapping a board item selects it here (its name + an info button that opens the
# Tiers ladder + a trashcan that sells it for coins when it's a deletable, non-generator item).
var _selected_cell := Vector2i(-1, -1)
var _info_icon: CenterContainer      # the selected piece preview
var _info_label: Label               # "<name> · Tier N" (or the empty-state prompt)
var _info_btn: Button                # opens the selected item's Tiers ladder
var _info_trash: Button              # sells the selected item; its content shows trash + payout (built by the kit)
var _info_trash_count: Label         # the "+N" sell payout amount inside the trash button (kit meta sell_count)
var _info_trash_coin: Control        # the payout currency icon slot (standard coin/acorn) inside the trash button
var _info_inner_px := 62.4           # the info bar's piece-preview box (from the kit's inner-control knob)
var coins_label: Label
var _2x_offer: Control = null   # the post-reward 2× "double your coins" rewarded-ad card (re-homed from the removed hub-collect, §10)
var diamonds_label: Label
var level_label: Label            # S10: the shared Lv chip, wired in BOTH scenes
var bag_slots_ui: Array = []
var _bag_drag_idx := -1                 # §5 drag-back: which bag slot the in-flight drag came from (-1 = none)
var _open_shop: Callable = Callable()   # opens the shared Shop (wired from the HUD)
var bottom_bar: Control          # the board bottom bar row (Bag+count · info bar · Home)
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
	SceneWarm.prewarm("res://engine/scenes/Map.tscn")   # warm the Home target off-thread while we build

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
	# pick up any saved UI-Workbench board design (gap / frame / scale / item) BEFORE the fit is computed,
	# so the gutter + frame budgets and the final cell size all reflect it. Absent → today's defaults.
	_load_board_config()
	# the bamboo FRAME extends FRAME_OUT past the grid on every side — budget for it so the
	# frame + last column never run off-screen (the prior calc sized only the cells → overflow).
	var w_csz := (view.x - 2.0 * BOARD_MARGIN - 2.0 * FRAME_OUT - (G.COLS - 1) * GAP) / float(G.COLS)
	# the grid pins directly under the quest fence now (the wood-branch divider band is retired),
	# so the height budget reserves only the frame overhang + the fence/nav rows.
	var h_csz := (view.y - 536.0 - 2.0 * FRAME_OUT - (G.ROWS - 1) * GAP) / float(G.ROWS)
	# `_board_scale` (1.0 = the responsive full-fit) shrinks the cells within the available space — the
	# in-game "board size" knob. <1 leaves a centred margin; values >1 may overflow the screen budget.
	csz = minf(w_csz, h_csz) * _board_scale
	# The bamboo frame overhangs the grid by FRAME_OUT on all sides. Reserve that real
	# visual footprint in the VBox so the frame no longer intrudes into the giver cards.
	center.custom_minimum_size = Vector2(_board_w() + FRAME_OUT * 2.0, _board_h() + FRAME_OUT * 2.0)
	board_area.custom_minimum_size = Vector2(_board_w(), _board_h())
	board_area.gui_input.connect(_on_board_input)
	center.add_child(board_area)

	# (the wood-branch divider that used to sit between the quest fence and the grid is retired —
	# the grid pins directly under the fence now.)

	# Placement Workbench (tools/ui_placement.gd): the quest fence + the board carry an optional
	# saved vertical nudge (board_layout.json). Applied AFTER the VBox lays out, per sort, so the
	# offsets are independent and the responsive layout is untouched. No file / 0 → identical render.
	_board_center = center
	_load_placement()
	root.sort_children.connect(_apply_placement)

	# the bag is no longer an always-present row; it is a single circular well in the bottom nav
	# (tap → full bag overlay, drag a board item onto it → stash). See _make_bag_button.

	# The board bottom bar: Bag (+ x/y count) · Info bar · Home. Tapping a board item SELECTS it into the
	# centre info bar — its name, an info button that opens the Tiers ladder, and a trashcan that sells it
	# for coins when it's a deletable (non-generator) item. Selling moved here from the old drag-to-merchant
	# well (merchant_btn stays null). Bag stays a drag-to-stash target; Home returns to the Map.
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb_inset := Look.safe_bottom(self)
	bar.offset_left = QUEST_SIDE
	bar.offset_right = -QUEST_SIDE
	bar.offset_top = -BOTTOM_BAR_H - 14.0 - sb_inset
	bar.offset_bottom = -14.0 - sb_inset
	bar.add_theme_constant_override("separation", 12)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bar)
	bottom_bar = bar
	bar.add_child(_build_bag_box(BOTTOM_BTN_PX))   # left: the Bag well + the x/y count
	bar.add_child(_build_info_bar(BOTTOM_BTN_PX))  # centre: the selected-item info bar (expands), height-matched to the wells
	home_btn = _home_nav_button(BOTTOM_BTN_PX)     # right: the Home disc (lit when a spot is affordable)
	bar.add_child(home_btn)
	_clear_selection()                             # the info bar starts in its empty "tap an item" state

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

# --- board design (tools/ui_workbench — the "board" element) --------------------------
# Pull the optional saved board design out of the UI-Workbench settings (ui_workbench_settings.json →
# "board"): the gutter, the frame overhang, the overall scale, and the piece-in-cell width. Absent file
# or keys → the shipped defaults, so the board is unchanged until you save a board block in the workbench.
# (cell / cols / rows are workbench-PREVIEW only — the live grid is G.COLS×G.ROWS and sizes itself to the
# screen; `scale` is the in-game cell/item-size knob, `item` the sprite width within each cell.)
func _load_board_config() -> void:
	var Kit: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
	if Kit == null:
		return
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	if cfg.has("board") and cfg["board"] is Dictionary:
		_apply_board_config(cfg["board"])

# Map a saved "board" block onto the live geometry. Split out so it is unit-testable without a file.
func _apply_board_config(b: Dictionary) -> void:
	GAP = float(b.get("gap", 7.0))
	FRAME_OUT = float(b.get("frame", 60.0))
	_board_scale = float(b.get("scale", 100.0)) / 100.0
	# `item` = the piece sprite width as a % of its cell; the inset is the leftover half on each side.
	# Default 68 reproduces the shipped ITEM_INSET (0.16), so a saved-default board renders identically.
	_board_item_inset = clampf((1.0 - float(b.get("item", 68.0)) / 100.0) / 2.0, 0.0, 0.45)

# --- placement (tools/ui_placement.gd) -----------------------------------------------
const PLACEMENT_PATH := "res://games/grove/assets/board_layout.json"

# Read the saved fence/board vertical nudges. Missing file or 0 → no offset (today's layout).
func _load_placement() -> void:
	if not FileAccess.file_exists(PLACEMENT_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PLACEMENT_PATH))
	if typeof(d) == TYPE_DICTIONARY:
		_place_fence_dy = float(d.get("fence_dy", 0.0))
		_place_board_dy = float(d.get("board_dy", 0.0))

# Shift the fence + board by their saved fractions AFTER the VBox has positioned them, so the
# nudges are independent of each other and the responsive sizing is unchanged. Runs per sort.
func _apply_placement() -> void:
	if _place_fence_dy == 0.0 and _place_board_dy == 0.0:
		return
	var h := get_viewport_rect().size.y
	if giver_bar != null:
		giver_bar.position.y += _place_fence_dy * h
	if _board_center != null:
		_board_center.position.y += _place_board_dy * h

# The placement tool changed an offset → re-sort so _apply_placement reseats the bands.
func placement_refresh() -> void:
	if giver_bar != null and giver_bar.get_parent() != null:
		(giver_bar.get_parent() as Container).queue_sort()

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

# §7 fence sizing: how many stands the fence shows, metered to the whole map's remaining stars.
func _meter_target() -> int:
	return Quests.meter_target(_quest_map(), Save.stars(), Save.grove().get("unlocks", {}))

# Top up / trim the live fence to the metered count with freshly generated quests (§7). Deterministic
# via the rng. Near the end of the map, one quest also carries the next map's generator(s) → auto-placed on board.
func _refill_quests() -> void:
	quests = Quests.refill(quests, _quest_map(), Save.grove().get("unlocks", {}), _gates(), board.gens, board.gen_bag, Save.stars(), _quest_level(), rng, _recent_lines)
	_assign_givers()                          # give each new quest a giver face distinct from the previous 5

# Each quest carries a stable `giver` index (the portrait shown on its stand). A NEW quest is assigned a
# giver that is NOT among the last 5 assigned, so the same forest character never reappears within 5 — the
# index persists on the quest (saved), so a stand keeps its face across rebuilds + sessions.
func _assign_givers() -> void:
	# seed the rolling window once from quests that already carry a giver (their array order ≈ assignment
	# order), so a freshly-loaded session's new givers still avoid the recently-shown faces.
	if _recent_givers.is_empty():
		for q in quests:
			if q.has("giver"):
				_push_recent_giver(int(q["giver"]))
	for q in quests:
		if not q.has("giver"):
			q["giver"] = _next_giver()

# Pick a giver index (0..GIVER_COUNT-1) that is not among the last 5 used; GIVER_COUNT (16) ≫ 5, so the
# avoid-set never exhausts the pool. Records the pick in the rolling window.
func _next_giver() -> int:
	var avail: Array = []
	for g in range(Bust.GIVER_COUNT):
		if not _recent_givers.has(g):
			avail.append(g)
	var pick: int = avail[rng.randi() % avail.size()] if not avail.is_empty() else rng.randi() % Bust.GIVER_COUNT
	_push_recent_giver(pick)
	return pick

func _push_recent_giver(g: int) -> void:
	_recent_givers.append(g)
	while _recent_givers.size() > 5:
		_recent_givers.pop_front()

# Record an asked item-line in the rolling window (mirrors _push_recent_giver): a NEW quest's item is
# steered off the last ≤5 asks, so the same item does not reappear within 5 (§7 anti-monotony).
func _push_recent_line(line: int) -> void:
	_recent_lines.append(line)
	while _recent_lines.size() > 5:
		_recent_lines.pop_front()

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
	var hud := Hud.build(self, {"water_grant": func() -> void:
		water = G.WATER_CAP
		_update_water_hud()
		_persist(),
		# §10: a shop-bought item-shortcut lands in the bag LIVE (drained from the queue)
		# while the board is open — no scene reload needed for it to appear.
		"piece_grant": func() -> void: _drain_shop_pieces(),
		# tap the level badge -> the level screen (stars earned / needed for the next level)
		"on_level": func() -> void: LevelPopup.open(self),
		# Settings is a top-RIGHT gear in the shared HUD now (off the bottom bar) — opens the shared card.
		"settings": func() -> void:
			Audio.play("button_tap", -2.0)
			SettingsUI.open(self)})
		# (no "home" opt → the shared HUD skips its top-left home chip; the bottom nav owns Home now)
	coins_label = hud.coins
	diamonds_label = hud.diamonds
	level_label = hud.level          # S10: store the board's Lv chip (set at build; level is static here)
	_wallet_panel = hud.wallet       # the shared cluster
	# water is the FIRST top-center pill now (Water·Coin·Gem); the board's live value overrides it via
	# _update_water_hud. The board owns only the empty-water REFILL stack (built in _build_water_hud).
	water_label = hud.water
	_water_icon = hud.water_icon
	_open_shop = hud.open_premium    # generic "open the shop" → the premium (acorn) stall (the pills' + open their own)
	_update_hud()

# Water is the FIRST top-center pill (Water·Coin·Gem), bound from the shared HUD (water_label / _water_icon
# in _build_hud) and overridden live via _update_water_hud. The board owns only the empty-water REFILL
# stack — the free/💎 rain refill, a rewarded watch-ad refill, and the cozy out-of-water offer — pinned
# top-LEFT below the Lv badge and shown only when water runs out.
func _build_water_hud() -> void:
	var safe_top := Look.safe_top(self)
	# T43: the empty-water surfaces live in a vertical stack top-left (below the 130px Lv badge), shown only
	# at water<=0 (§10 — the friction point). Top: the free/💎 rain refill. Then a rewarded WATCH-AD refill
	# (capped) and the cozy out-of-water OFFER, each shown only when live.
	_refill_stack = VBoxContainer.new()
	_refill_stack.add_theme_constant_override("separation", 8)
	_refill_stack.offset_left = 16.0
	_refill_stack.offset_top = 16.0 + safe_top + 130.0 + 16.0
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
	# the top wallet is Water·Coin·Gem now (no star count). Water is updated live by _update_water_hud.
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
	# the live fence is already metered to <= MAX_GIVERS by _refill_quests (§7: sized to the
	# whole map's remaining stars — full through the map, tapering only in the final stretch).
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
	var show_purge := _show_purge_card()
	# the fence renders while there are quests OR the Purge card is showing — the Purge card now stands
	# alone once the meter empties (banked enough to restore), so an empty quest list no longer blanks it.
	if stands == 0 and not show_purge:
		return
	# the fence wall — one bordered strip; busts and cards pop up over its edge
	var wall := Control.new()
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall.offset_top = 64.0
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	giver_bar.add_child(wall)
	giver_bar.move_child(wall, 0)
	# (the full-width quest-band Panel is removed — the cards ride directly on the painted backdrop.)
	# The fence is FULL-WIDTH: GIVER_COLS cards at ~25% each, inset QUEST_SIDE on each edge with QUEST_GAP
	# between them. A "Purge" card takes the FIRST slot when the player can afford to unlock a region
	# (_show_purge_card) — so the fence is Purge + up to 3 quests, otherwise up to 4 quests.
	var span := giver_bar.size.x
	if span <= 0.0:
		span = get_viewport_rect().size.x
	var cols := GIVER_COLS
	var stand_w := (span - 2.0 * QUEST_SIDE - float(cols - 1) * QUEST_GAP) / float(cols)
	var row := HBoxContainer.new()
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 0.0
	row.anchor_bottom = 1.0
	row.offset_left = QUEST_SIDE
	row.offset_right = -QUEST_SIDE
	row.alignment = BoxContainer.ALIGNMENT_BEGIN   # pack cards from the left
	row.add_theme_constant_override("separation", int(QUEST_GAP))
	giver_bar.add_child(row)
	giver_bar.move_child(row, 1)
	if show_purge:
		row.add_child(_make_purge_card(stand_w))
	var quest_slots := cols - (1 if show_purge else 0)   # Purge eats one slot → only 3 quests beside it
	for k in range(mini(quest_slots, qidx.size())):
		var qi: int = qidx[k]
		var stand := _make_giver_stand(qi, quests[qi], stand_w)
		row.add_child(stand.chip)
		giver_chips.append(stand)
	_refresh_giver_lights()

# The Purge card (fence slot 0) shows whenever a frontier remains (the map is not done) — ALWAYS, not
# only once affordable — advertising the home map's current ★ balance. It greys out until the cheapest
# region is affordable, then lights + breathes (the SAME gate_ready signal the Home button uses).
func _show_purge_card() -> bool:
	return Quests.purge_state(_quest_map(), Save.stars(), Save.grove().get("unlocks", {}), _gates()).show

# A special fence card: the home map's current ★ balance over a "Purge" button, tapped to go HOME and
# spend stars on regions. Sized like a giver card so it sits flush in its 25% slot; reuses the Home
# action (persist → Map). It ALWAYS shows while a frontier remains (no padlock now) — greyed + still until
# the cheapest region is affordable, then full colour + breathing (the Home-button gate_ready signal).
func _make_purge_card(stand_w: float) -> Control:
	var stand := Control.new()
	stand.custom_minimum_size = Vector2(stand_w, FENCE_H)
	# #1: size + frame the card EXACTLY like a giver card — the SAME card_w/card_h fractions and the SAME
	# 9-slice wood frame (GiverStand._quest_card) — so the Purge slot sits flush with the quest cards at
	# the same height (no more shorter, aspect-locked card).
	var L := _giver_lay()
	var cardW := stand_w * float(L.card_w)
	var cardH := FENCE_H * float(L.card_h)
	var cx := (stand_w - cardW) / 2.0
	var cy := (FENCE_H - cardH) / 2.0
	var card := GiverStand._quest_card(cardW, cardH, L)
	card.position = Vector2(cx, cy)
	card.size = Vector2(cardW, cardH)
	stand.add_child(card)
	var ready := _gate_ready()                     # affordable → light + breathe; else grey + still
	# the layer's CURRENT ★ balance (replaces the old padlock): a star icon + the banked count, centred a
	# touch high so the green button clears it below. Always shown — it is the card's headline now.
	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	srow.add_theme_constant_override("separation", maxi(2, int(cardH * 0.05)))
	srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	srow.add_child(Look.icon("star", cardH * 0.30))
	var slbl := Label.new()
	slbl.text = str(Save.stars())
	slbl.add_theme_font_size_override("font_size", int(cardH * 0.28))
	slbl.add_theme_color_override("font_color", Pal.INK)
	slbl.add_theme_constant_override("outline_size", 0)
	slbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	srow.add_child(slbl)
	stand.add_child(srow)
	var place_stars := func() -> void:
		if is_instance_valid(srow):
			srow.position = Vector2(cx + cardW * 0.5 - srow.size.x / 2.0, cy + cardH * 0.30 - srow.size.y / 2.0)
	srow.resized.connect(place_stars)
	place_stars.call()
	# #2: the "Purge" CTA is the shared GREEN primary button (Look.button primary) — the same leaf-green
	# pill + cream label as every other CTA in the grove. Tapped → go HOME (persist + jump to the Map) to
	# unlock more regions. The button IS the affordance now (the old whole-card tap + cream pill are gone).
	var purge_go := func() -> void:
		Audio.play("button_tap", -2.0)
		_persist()
		HomeScene.decorate_map = _decorate_target()
		SceneWarm.go(get_tree(), "res://engine/scenes/Map.tscn")
	var btn := Look.button(tr("Purge"), purge_go, true)
	btn.add_theme_font_size_override("font_size", int(cardH * 0.15))
	btn.custom_minimum_size = Vector2(cardW * 0.6, 0.0)
	stand.add_child(btn)
	# centre the green pill near the card's lower third (driven by resized — its size settles after layout)
	var place_btn := func() -> void:
		if is_instance_valid(btn):
			btn.position = Vector2(cx + cardW * 0.5 - btn.size.x / 2.0, cy + cardH * 0.64 - btn.size.y / 2.0)
	btn.resized.connect(place_btn)
	place_btn.call()
	# ready → full colour + a gentle breathe (like a payable giver card); not yet → grey + still, so it
	# reads as "earn more ★ first" without a padlock.
	if ready:
		stand.modulate = Color.WHITE
		FX.breathe_once(stand)
	else:
		stand.modulate = PURGE_DIM
	return stand

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
func _make_giver_stand(qi: int, q: Dictionary, stand_w: float = STAND_W) -> Dictionary:
	var cfg := {
		"ask_tap": _open_ladder,        # an ask icon tapped while NOT ready -> open its tier ladder
		"item_tap": _on_item_tap,       # an ask icon tapped -> claim if ready, else open the ladder (#3)
		"stand_tap": _on_giver_tap,     # the stand tapped -> try to deliver
		"wire_tap": _stand_tap,         # still-release tap (also resets the idle hint)
		"stand_w": stand_w, "fence_h": FENCE_H,
	}
	# the giver-card LAYOUT is tuned in the UI workbench and SAVED to its config (the quest_card block);
	# read it the SAME way every other element does — soft-load the game-tool kit (engine → game bridge).
	# Absent kit / empty block → GiverStand falls back to its baked-in LAY, so nothing changes until saved.
	cfg["lay"] = _giver_lay()
	return GiverStand.make(qi, q, cfg)

# The resolved giver-card layout: GiverStand's baked defaults with the workbench config (the quest_card
# block) merged over them. Shared by the giver stands AND the Purge card (#1) so the Purge slot is sized
# and framed identically to the quest cards. Absent kit → the bare GiverStand.LAY defaults.
func _giver_lay() -> Dictionary:
	var L: Dictionary = GiverStand.LAY.duplicate()
	var Kit: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
	if Kit != null:
		var over: Dictionary = Kit.giver_lay_from_config(Kit.load_config(Kit.CONFIG_PATH))
		for k in over:
			L[k] = over[k]
	return L


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
	# the ask-bubble's "N/1" count tracks the same single source of truth as the ✓.
	var count: Label = item.get("count")
	if count != null and is_instance_valid(count):
		count.text = "1/1" if met_ok else "0/1"
		count.add_theme_color_override("font_color", Color("#4E7C46") if met_ok else Pal.INK)
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
	var ghl := _gen_highlight_opts()         # workbench-tuned glow/outline/sparkle (or {} for shipped look)
	for cell in board.gens:                  # the live, stateful set (cell -> id), §6
		var gn := _make_generator(String(board.gens[cell]), ghl)
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
	# (the board panel — mat + border in one — is the bottom layer, added by _make_board_mat above;
	# there is no separate frame overlay now that the panel carries its own border.)
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
	# the cell-sized holder stays `size` (placement + drag are unchanged); only the sprite inset shrinks/
	# grows the visible item per the saved board.item width. The single chokepoint for every board piece.
	return PieceView.make_piece(code, size, _board_item_inset)

# The board surface — a single solid panel (`ui/board/board_frame.png`, sliced from board1_asset3.png):
# a cream parchment field ringed by a soft wood/rope border with a dashed stitch line. Drawn as ONE
# nine-patch BEHIND the cells (its own border + cream center in one art piece), so the cells sit on the
# parchment and the rope frames them. Replaces the old bamboo ring + separate flat-cream field. The
# PANEL_MARGIN corner holds the rounded corner + border rigid; only the plain parchment middle stretches.
var FRAME_OUT := 60.0        # how far the board panel extends OUTSIDE the cell grid. Workbench-overridable (board.frame).
const PANEL_MARGIN := 70     # nine-patch corner size — covers the panel's rounded corner + rope border

# The board panel — the BOTTOM layer of the board, drawn behind the cells. Falls back to the
# code-drawn planter (which carries its own frame) when the kit art is absent.
func _make_board_mat() -> Control:
	var fp := Look.kit("board/board_frame.png")
	if not ResourceLoader.exists(fp):
		return PieceView.make_board_mat(_board_w(), _board_h())
	var panel := NinePatchRect.new()
	panel.texture = load(fp)
	panel.position = Vector2(-FRAME_OUT, -FRAME_OUT)
	panel.size = Vector2(_board_w() + FRAME_OUT * 2.0, _board_h() + FRAME_OUT * 2.0)
	panel.patch_margin_left = PANEL_MARGIN
	panel.patch_margin_top = PANEL_MARGIN
	panel.patch_margin_right = PANEL_MARGIN
	panel.patch_margin_bottom = PANEL_MARGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

# #7: the per-cell empty "well" — a single shared builder so both creation sites
# (full rebuild + bramble-clear) stay identical. A soft warm well with a gentle,
# low-alpha rounded outline (reads as an outline, not a hard line) and little
# inner padding, plus a faint shadow for depth.
func _make_slot(cell: Vector2i) -> Control:
	# the open empty well, built on the SHARED slot cell (Kit.slot_cell) — the SAME component the bag
	# uses, reading the SAME workbench "bag_card" style, so the board + bag wells stay in lockstep.
	var Kit: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
	var opts: Dictionary = Kit.bag_card_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	opts["cell_w"] = csz
	opts["cell_h"] = csz
	var slot: Control = Kit.slot_cell({"state": "empty"}, opts)
	slot.position = _cell_pos(cell)
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
func _home_well(px: float, icon_id: String, fallback_art: String, count: String = "") -> Button:
	var Kit: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
	if Kit == null:
		return _tray_well(px, fallback_art)
	var opts: Dictionary = Kit.home_button_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	opts["px"] = px
	opts["calm"] = FX.calm()
	# `count` (the Bag's "x/y") rides INSIDE the disc via the shared component's workbench-tuned overlay —
	# so the bag cell stays the same px box as the rest of the bar (no taller label stacked beneath it).
	return Kit.home_button({"icon": icon_id, "caption": "", "sparkle": false, "count": count}, opts)

# The Bag well (bottom nav): tap → the full bag overlay; a board item dragged onto it stashes
# (the drop is resolved in _on_release by global-rect). bag_content shows the most-recent stashed
# item (centered, no count badge — the full total lives in the overlay).
func _make_bag_button(px: float) -> Button:
	var b := _home_well(px, "bag", "nav_bag.png", _bag_count_text())   # the home-button disc + satchel icon + the in-disc "x/y" count
	# The disc's own icon wrapper IS the swap surface: a stashed item REPLACES the satchel here (same box,
	# same size — a true icon swap, per the workbench-tuned button), and the satchel is restored when the
	# bag empties (see _rebuild_bag). No separate small overlay riding on top of the satchel anymore.
	bag_content = b.get_meta("icon_wrap") if b.has_meta("icon_wrap") else null
	bag_piece_px = float(b.get_meta("icon_px", px * 0.5))   # match the satchel icon box so the item FILLS it
	# the "x/y" slot count now lives INSIDE the disc (the shared home_button's count overlay), so the bag cell
	# is the same px box as the info bar + home disc next to it. The label is updated in place via this meta.
	_bag_count_lbl = b.get_meta("count_label") if b.has_meta("count_label") else null
	b.pressed.connect(_open_bag_overlay)
	return b

# The bottom-bar Bag cell: just the swap-icon bag well — the "x/y" count rides INSIDE the disc now
# (see _make_bag_button), so the cell matches the height of the info bar + Home disc beside it.
func _build_bag_box(px: float) -> Control:
	bag_btn = _make_bag_button(px)
	return bag_btn

# The Bag's "held / capacity" string, e.g. "1/6" — used both to seed the in-disc overlay and to refresh it.
func _bag_count_text() -> String:
	return "%d/%d" % [bag.size(), _bag_capacity()]

# The Home disc for the bottom bar's right edge: the shared workbench-tuned home button + the Map jump.
func _home_nav_button(px: float) -> Button:
	var b := _home_well(px, "house", "nav_home.png")
	b.pressed.connect(func() -> void:
		Audio.play("button_tap", -2.0)
		_persist()
		HomeScene.decorate_map = _decorate_target()
		SceneWarm.go(get_tree(), "res://engine/scenes/Map.tscn"))
	return b

# The center INFO BAR: [info button] [selected piece + name] [trashcan/sell]. Tapping a board item fills it
# (see _select_item); empty otherwise. The info button opens the Tiers ladder; the trashcan sells the item.
# The bar itself is the SHARED kit component (Kit.info_bar — the same one the workbench previews + tunes);
# the board just grabs its mutable sub-nodes (info ⓘ / piece box / name / sell) and drives selection state.
func _build_info_bar(px: float = 130.0) -> Control:
	var Kit: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
	if Kit == null:
		return PanelContainer.new()   # engine-only safety net — the grove kit owns the info bar (always present in the bundled game)
	var opts: Dictionary = Kit.info_bar_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	var pill: PanelContainer = Kit.info_bar({"info_action": _on_info_pressed, "sell_action": _on_trash_pressed}, opts)
	_info_btn = pill.get_meta("info_btn")            # opens the selected item's Tiers ladder
	_info_icon = pill.get_meta("info_icon")          # the selected piece preview (filled in _select_item)
	_info_label = pill.get_meta("name_label")        # "<name> · Tier N" (or the empty prompt)
	_info_trash = pill.get_meta("sell_btn")          # sells the selected item; its content shows trash + payout
	_info_trash_count = pill.get_meta("sell_count")  # the "+N" payout label, set in _select_item
	_info_trash_coin = pill.get_meta("sell_coin")    # the payout currency icon slot (standard coin/acorn)
	_info_inner_px = float(pill.get_meta("inner_px", px * 0.48))   # the piece preview scales with the bar's inner-control knob
	return pill

# Select a board item INTO the info bar: show its piece + "<name> · Tier N", enable the info button, and
# show the trashcan with its sell payout (hidden for generators / raw coins — they aren't deletable here).
func _select_item(cell: Vector2i) -> void:
	var code := board.item_at(cell)
	if code <= 0:
		_clear_selection()
		return
	_selected_cell = cell
	var line := BoardModel.line_of(code)
	var tier := BoardModel.tier_of(code)
	for c in _info_icon.get_children():
		c.queue_free()
	_info_icon.add_child(_make_piece(code, _info_inner_px * 0.8))   # ~0.8 of the box (≈50px at the default inner) — scales with the bar knob
	var nm: String = tr(String(G.LINES[line].name)) if G.LINES.has(line) else tr("Item")
	_info_label.text = "%s · %s %d" % [nm, tr("Tier"), tier]
	_info_btn.disabled = false
	if board.is_gen(cell) or G.is_coin(code):
		_info_trash.visible = false           # generators + raw coins aren't "deletable for coins"
	else:
		var rw := G.sell_reward(code)         # Vector2i(coins, acorns) — top tier pays the premium
		var gem := rw.y > 0
		_info_trash_count.text = "+%d" % (rw.y if gem else rw.x)
		for c in _info_trash_coin.get_children():
			c.queue_free()
		var pay_icon := Look.icon("gem" if gem else "coin", _info_trash_coin.custom_minimum_size.x)
		pay_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_info_trash_coin.add_child(pay_icon)
		_info_trash.visible = true

# Reset the info bar to its empty "tap an item" state.
func _clear_selection() -> void:
	_selected_cell = Vector2i(-1, -1)
	if _info_icon != null and is_instance_valid(_info_icon):
		for c in _info_icon.get_children():
			c.queue_free()
	if _info_label != null and is_instance_valid(_info_label):
		_info_label.text = tr("Tap an item to inspect it")
	if _info_btn != null and is_instance_valid(_info_btn):
		_info_btn.disabled = true
	if _info_trash != null and is_instance_valid(_info_trash):
		_info_trash.visible = false

# The info button → open the selected item's Tiers ladder (guards a stale/empty selection).
func _on_info_pressed() -> void:
	if _selected_cell.x < 0:
		return
	var code := board.item_at(_selected_cell)
	if code <= 0:
		return
	_open_ladder(BoardModel.line_of(code), BoardModel.tier_of(code))

# The trashcan → sell the selected item for coins (guards generators / coins / a stale selection).
func _on_trash_pressed() -> void:
	if _selected_cell.x < 0:
		return
	var cell := _selected_cell
	var code := board.item_at(cell)
	if code <= 0 or board.is_gen(cell) or G.is_coin(code):
		return
	var node: Control = piece_nodes.get(cell)
	if node == null:
		return
	_sell_item(cell, node)
	_clear_selection()

# Refresh the bottom-bar bag "x/y" count (held / capacity) — the label lives inside the bag disc now.
func _update_bag_count() -> void:
	if _bag_count_lbl != null and is_instance_valid(_bag_count_lbl):
		_bag_count_lbl.text = _bag_count_text()

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

# The board backdrop — the painted grove meadow (`ui/board2_bg.png`). Items + grid pop
# against it; the dynamic givers/merchant ride over the painted fence band. Falls back to
# the flat SURFACE field when the art is absent.
static func _field_backdrop() -> Control:
	var path := Game.art("ui/board2_bg.png")
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

func _make_generator(id: String, hl: Dictionary = {}) -> Control:
	return PieceView.make_generator(String(id), csz, hl)

# The GEN-highlight (glow / silhouette outline / sparkle) tuning saved in the UI workbench
# ("generator" block). Absent file/keys → {} → make_generator falls back to its shipped GEN_* consts.
func _gen_highlight_opts() -> Dictionary:
	var Kit: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
	if Kit == null:
		return {}
	return Kit.gen_highlight_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))

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
	if _selected_cell.x >= 0:
		_clear_selection()                    # a new board touch resets the info bar (a still tap re-selects)
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
		_snap_back(from, node)             # a STILL tap SELECTS the item into the bottom info bar
		_select_item(from)
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

# Refresh the bottom-nav Bag well by SWAPPING the disc's icon: the most-recent stashed item replaces
# the satchel glyph (filled), and the satchel is restored when the bag empties. bag_content IS the
# home-button's icon wrapper (a CenterContainer), so the swapped sprite sits exactly where the satchel did.
func _rebuild_bag() -> void:
	_update_bag_count()                       # keep the bottom-bar "x/y" count in sync with the bag
	if bag_content == null or not is_instance_valid(bag_content):
		return
	for c in bag_content.get_children():
		c.queue_free()
	if bag.is_empty():
		# empty → restore the satchel glyph (the same workbench-tuned kit icon the disc shipped with)
		var Kit: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
		if Kit != null:
			bag_content.add_child(Kit.make_icon("bag", bag_piece_px))
	else:
		# filled → the most-recent stashed item, sized to FILL the disc's icon box (a true swap, not a
		# tiny preview riding on top of the satchel).
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

# #3: a tap on the asked item IS the claim affordance. When the quest is READY (the asked item is on
# the board, so the per-item ✓ is up) the tap DELIVERS it — the same path the stand-body tap takes —
# instead of opening the tier ladder over a quest the player wants to hand in. While NOT ready the tap
# still opens the ladder (the inspect / aim-for-the-ask path). One seam so the ✓ never opens a dialog.
func _on_item_tap(qi: int, line: int, tier: int, chip: Control) -> void:
	if qi >= 0 and qi < quests.size() and BoardLogic.quest_payable(board, quests[qi]):
		_on_giver_tap(qi, chip)
	else:
		_open_ladder(line, tier)

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
	if not it.is_empty():
		_push_recent_line(int(it.line))       # remember this ask so the next ≤5 quests avoid the same item
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
		_refresh_locked_cells()   # a level-up may make deeper frontier cells unlockable now
		Audio.play("level_complete", -1.0)
		# the Level dialog IS the celebration now — it shows the new level + the earned gift and pays the
		# gift out on Collect (the deferred grant). Re-sync the water + HUD when it closes (post-Collect).
		var lvlup_ov := LevelPopup.open_levelup(self, levels_up)
		if lvlup_ov != null:
			lvlup_ov.tree_exited.connect(func() -> void:
				if not is_instance_valid(self):
					return
				water = int(Save.grove().get("water", water))   # re-sync the local after Collect granted the gift
				_update_water_hud()
				_update_hud())
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
	pl.text = tr("Watch a cloud to double it!")
	pl.add_theme_font_size_override("font_size", 24)
	pl.add_theme_color_override("font_color", Pal.INK)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pitch.add_child(pl)
	# The value row SPELLS OUT the doubling — the ORIGINAL reward, an arrow, then the DOUBLED total —
	# so the player plainly sees their `got` become `got × 2` (legibility, §10). The bonus half (the
	# same amount again) is what _accept_2x_offer actually grants; here we just make it readable.
	# Before: muted + small. After: gold + big — the payoff the eye lands on.
	var sub := HBoxContainer.new()
	sub.alignment = BoxContainer.ALIGNMENT_CENTER
	sub.add_theme_constant_override("separation", 8)
	col.add_child(sub)
	sub.add_child(Look.icon("coin", 22.0))
	var sn0 := Label.new()
	sn0.text = str(got)                                  # the "before" — the reward as it stands now
	sn0.add_theme_font_size_override("font_size", 22)
	sn0.add_theme_color_override("font_color", Color(Pal.INK, 0.5))
	sn0.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_child(sn0)
	var arrow := Label.new()
	arrow.text = "→"                                     # the "becomes"
	arrow.add_theme_font_size_override("font_size", 24)
	arrow.add_theme_color_override("font_color", Color(Pal.BARK, 0.95))
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_child(arrow)
	sub.add_child(Look.icon("coin", 32.0))
	var sn1 := Label.new()
	sn1.text = str(got * 2)                              # the "after" — the doubled total
	sn1.add_theme_font_size_override("font_size", 34)
	sn1.add_theme_color_override("font_color", STRAW)
	sn1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_child(sn1)
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
		if Features.on("fly_to_wallet") and diamonds_label != null:
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
	# The dialog header is a fixed "Tiers" (set in ladder.gd) — no internal line name passed.
	Ladder.open(self, {
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
