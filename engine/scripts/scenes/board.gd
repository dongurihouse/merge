extends Control
## The board — P1 core feel (water OFF).
## One persistent SAVED board: tap the seed satchel to pop items (random tier,
## ask-weighted line), drag matching plants together to grow them, merge beside
## brambles to clear them, drag onto empty ground to rearrange, stash in the Bag,
## feed top tiers to the Merchant, deliver quest asks to the fox/hedgehog for
## stars, and spend stars at the Restore gate to restore the grove (givers pause
## the moment the gate is affordable — the drive-to-spend loop).

const G = preload("res://engine/scripts/core/content.gd")
static var KIT: GDScript = load(Game.kit())   # the shared UI kit — resolved ONCE at script load, not a load() per call site
const Design = preload("res://engine/scripts/core/design.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")
const BoardActions = preload("res://engine/scripts/core/board_actions.gd")
const Bucket = preload("res://engine/scripts/core/bucket.gd")   # boost-line charges, spent on the board chip
const Quests = preload("res://engine/scripts/core/quests.gd")
const Claims = preload("res://engine/scripts/core/claims.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Music = preload("res://engine/scripts/core/music.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Tuning = preload("res://engine/scripts/core/tuning.gd")   # UI-redesign role dials (Tuning.UiSkin.*)
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const FocusRing = preload("res://engine/scripts/ui/focus_ring.gd")   # the selected-cell corner-bracket highlight
const Bust = preload("res://engine/scripts/ui/bust.gd")
const GiverStand = preload("res://engine/scripts/ui/giver_stand.gd")
const BoardFit = preload("res://engine/scripts/ui/board_fit.gd")
const BagOverlay = preload("res://engine/scripts/ui/bag_overlay.gd")   # the tap-to-open full bag (replaces the inline row)
const Ladder = preload("res://engine/scripts/ui/ladder.gd")
const GenLines = preload("res://engine/scripts/ui/gen_lines.gd")
const RetireOffer = preload("res://engine/scripts/ui/retire_offer.gd")   # §6 the line-retirement offer
const TutorialImage = preload("res://engine/scripts/ui/tutorial_image.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Feel = preload("res://engine/scripts/ui/feel.gd")
const MergeFx = preload("res://engine/scripts/ui/merge_fx.gd")    # the toggleable + tunable feel appliers
const LandFx = preload("res://engine/scripts/ui/land_fx.gd")      # (workbench-tuned, resolved once in _ready)
const LaunchFx = preload("res://engine/scripts/ui/launch_fx.gd")
const MoveFx = preload("res://engine/scripts/ui/move_fx.gd")
const GrabFx = preload("res://engine/scripts/ui/grab_fx.gd")        # the toggleable Grab (pickup) highlight
const GridFx = preload("res://engine/scripts/ui/grid_fx.gd")       # THE shared merge/slide-land orchestration (board + residents)
const UnlockBar = preload("res://engine/scripts/ui/unlock_bar.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const ActionBar = preload("res://engine/scripts/ui/action_bar.gd")   # the bottom action bar's shared visual builders
const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const ComboBloom = preload("res://engine/scripts/ui/combo_bloom.gd")
const HandHint = preload("res://engine/scripts/ui/hand_hint.gd")   # FTUE: the merge / generator-tap teach overlay
const Features = preload("res://engine/scripts/core/features.gd")
const Vault = preload("res://engine/scripts/core/vault.gd")                  # T44 SKIM-SITE — the piggy bank skims the t8-sell premium here
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")   # pre-warm Map off-thread so Home is snappy
const Game = preload("res://engine/scripts/core/game.gd")
const Strings = preload("res://engine/scripts/core/strings.gd")
const Debug = preload("res://engine/scripts/ui/debug.gd")
const LevelPopup = preload("res://engine/scripts/ui/level_popup.gd")   # tap the Lv badge → the level screen
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Pal = Game.PALETTE

var GAP := 7.0                   # #7: tight, consistent gutter (was 10) — cells sit close. Workbench-overridable (board.gap).
const BOARD_MARGIN := 6.0        # breathing room each side; the board owns the rest
const ROTATE_ASPECT := 1.0       # render the grid LANDSCAPE (cols/rows swapped: 9×7) when viewport w/h exceeds this
const ROTATE_DEADBAND := 0.04    # hysteresis around ROTATE_ASPECT so a near-square resize doesn't flip-flop
# Responsive band caps (the bottom-anchored layout) — ALIASES, never re-typed numbers: ui/action_bar.gd
# owns the bottom bar's band (it builds the bar) and ui/board_fit.gd owns the quest/page bands. The UI
# workbench's layout preview reads the SAME two modules, so a retune moves the board and the preview
# together and the operator can never tune to a value the board silently clamps away.
const QUEST_H_MIN := BoardFit.QUEST_H_MIN
const QUEST_H_MAX := BoardFit.QUEST_H_MAX
const BOTTOM_BAR_MIN := ActionBar.BOTTOM_BAR_MIN
const BOTTOM_BAR_MAX := ActionBar.BOTTOM_BAR_MAX
const BOTTOM_BTN_MIN := ActionBar.BOTTOM_BTN_MIN
const DRAG_HILITE := Color(1.12, 1.12, 1.12, 1.0)   # a drop-target well's brighten while a piece is dragged
const FENCE_H := 215.0           # the quest fence band above the grid (wide giver boxes)
const BOTTOM_BAR_H := ActionBar.BOTTOM_BAR_H     # fallback bottom bar height (Home · info bar · Bag)
const BOTTOM_BTN_PX := ActionBar.BOTTOM_BTN_PX   # fallback Bag/Home well size; runtime scales from button_w_pct
const BOTTOM_BAR_PAD := ActionBar.BOTTOM_BAR_PAD
const BOARD_TUTORIAL_OVERLAY := "BoardTutorialOverlay"
static var BOARD_TUTORIAL_IMAGE := Look.kit("tutorial/how_to_play_board.png")
const STAND_W := 300.0           # fallback giver box width (merchant stall / preview); the live fence sizes by %
const GIVER_COLS := 4            # legacy fence-slot count (kept for the workbench preview; the live fence packs dynamically)
const STAND_W_PER_FENCE := 1.17  # quest card width as a multiple of the band height — keeps the card art (~1.77:1) undistorted
const QUEST_SIDE := 18.0         # the fence row's left/right inset (aligns with the board's side breathing room)
const QUEST_GAP := 16.0          # fallback gap BETWEEN cards — the workbench quest_card.gap overrides (via _giver_lay)
const UNLOCK_BAR_H_FRAC := 0.10  # the NEXT UNLOCK strip's height as a fraction of screen width (mock: board_next_unlock_v1)
const EDGE_GAP := BoardFit.EDGE_GAP   # the EQUAL page margin: HUD pills → content top == board bottom → bottom bar
const BOTTOM_BAR_INSET := 14.0   # the floating bottom bar's gap off the screen (safe-area) bottom edge
const STACK_SEP := 20      # the row gap of the content stack (strip <-> quest fence <-> board)
const IDLE_HINT_SECS := 2.0      # W1: first idle hint sooner (was 7, then 4.5) → a mergeable pair rocks
const IDLE_RENUDGE_SECS := 4.0   # W1: re-nudge cadence while the player stays idle
const HINT_ROCK_DEG := 6.0       # W1: gentle rock amplitude (was a fast ±0.22rad shake)
const HINT_ROCK_CYCLE := 1.2     # W1: seconds per rock cycle
const HINT_ROCK_CYCLES := 3      # W1: number of slow rock cycles
const DRAG_LIFT_Z := HandHint.HAND_HINT_Z + 20   # FTUE: a lifted/dragged piece must stay visible above
                                                  # the hand-hint veil (hand_hint.gd) while a teach is live
const MERGE_TARGET_GROW := 0.30  # merge-only hit area added around each cell; move/swap keep exact-cell targeting
# §5: the bag's owned-slot COUNT is dynamic + persisted (Save.bag_slots(), 6→18) — no const.

# grove board palette (the night-purples retire here)
const GROUND_EDGE = Pal.GROUND_EDGE
const CREAM = Pal.CREAM
const STRAW = Pal.STRAW

# Shading IS the clickable/important affordance (board polish #8): the brighter a thing
# reads, the more it's asking to be tapped. GENERATORS still carry that read (GEN_LIT/GEN_DIM
# below). GIVERS no longer do — the dim tint was retuned to full opacity, so the ✓ mark, the
# count and the bob carry the lit state on their own.

# §6: a full board DIMS the generator(s) to a standing "paused" state — popping is free
# while dimmed, so the cue must persist (not a one-shot wobble) until a cell frees up.
# A generator's stop is a stronger signal than a giver's, so it dims further (0.5) — same
# affordance family (bright = tappable), just a deeper "paused" read for the harder stop.
const GEN_DIM := Color(1, 1, 1, 0.5)
const GEN_LIT := Color(1, 1, 1, 1.0)
# A generator whose LINE no open quest asks for FADES OUT — it can still pop (free while faded),
# but the eye lands on the generators the fence actually wants right now. Deeper than the paused
# dim (it is "not needed", not just "stopped"). Accumulators (utility, never asked) stay exempt.
const GEN_UNUSED := Color(1, 1, 1, 0.35)
# ...and the same read for ITEMS: a base-line piece whose line no open quest asks for GREYS OUT
# (muted + receded, still fully playable). Coins / special drops / treats are collectibles, not
# quest lines — they never grey. Gentler than the generator fade: items are the play material.
const ITEM_UNUSED := Color(0.78, 0.78, 0.78, 0.65)

var board: BoardModel
var rng := RandomNumberGenerator.new()
# DEV-TOOL DETERMINISM HOOK (screenshot captures). A fresh save has no saved rng_state, so
# _load_state() randomizes — and the very first thing that consumes the stream is the QUEST FENCE,
# which decides every generator's and item line's dimmed/lit state. That made two captures of
# identical code differ across a quarter of the board. A tool sets this BEFORE add_child (the seed
# must be in place before _ready → _load_state runs); -1 = live play, seeded from entropy.
static var forced_rng_seed := -1
var _combo_count := 0                 # cozy successive-merge streak length (see _bump_combo)
var _last_merge_ms := -100000         # ticks at the last merge; a big initial gap → first merge starts at 1
var _combo_bloom: ComboBloom          # bundle D: the warm screen-bloom overlay that swells on a streak
# the resolved feel-FX opts (MergeFx/LandFx/LaunchFx/MoveFx.from_config) — workbench-tuned toggles +
# knobs, resolved ONCE in _ready so the game runs the same appliers the workbenches preview.
var _merge_opts := {}
var _land_opts := {}
var _launch_opts := {}
var _move_opts := {}
var _grab_opts := {}
var _grid_fx_opts := {}   # {merge,move,land} bundle handed to GridFx (the shared merge/slide-land owner)
# the quest-ready glow look (colour/opacity/roundness/halo), resolved ONCE in _ready from the workbench
# "ready_glow" section so add_ready_glow renders the SAME look the workbench previews. {} → shipped amber.
var _ready_glow_opts := {}
var quests: Array = []             # §7: the LIVE generated fence (level-window asks, metered to restore progress), persisted
var _recent_givers: Array = []     # the last ≤5 assigned giver indices — a new quest's face avoids these
var _recent_items: Array = []      # the last ≤5 asked item codes (line*100+tier) — a NEW quest avoids these (§7)
var quests_map := -1              # the map these quests were generated for (regenerate on map change)
var bag: Array = []
var water := G.WATER_CAP
var _regen_ts := 0.0               # regen anchor (unix); advances as water accrues
var _winback := false              # set on load when away >= WINBACK_HOURS
var _gate_was_ready := false       # edge-detect for the quest_complete cue
var _gate_ready_seen := false      # skip the cue on the first (load-time) call
var _unlock_bar: UnlockBar

var csz := 86.0
var board_area: Control
var slot_nodes := {}
var piece_nodes := {}
var bramble_nodes := {}
var gen_node: Control              # the starter satchel (kept for tools/tests)
var gen_nodes := {}                # generator index -> node
var _hand_hint: Control = null      # FTUE: the live hand teach overlay (at most one), or null
var _hand_hint_id := ""             # which teach it is ("merge" / "gen_tap")
var _grown_cells: Array = []       # cells of generators that just GREW IN this rebuild (appear_level reached) — popped for feedback
# (the §6 burst buy pill and the W3 merchant drag sell-tag were the dark stat_chip pill — retired
#  T48 ahead of the UI redesign; the §6 boost coin sink stays in code, see _activate_gen_boost)
var giver_bar: Control           # the quest fence (givers pop up over it)
var _stack: VBoxContainer         # the bottom-anchored quest+board stack (region set in _recompute_board_geometry)
var _board_center: Control       # the CenterContainer holding the board, bottom-aligned in the stack
var _fence_h := FENCE_H          # runtime quest-row height, optionally driven by hud_layout % screen height
var _board_scale := 1.0          # saved UI-Workbench board size (board.scale; 1.0 = the responsive full-fit)
var _board_item_inset := 0.16    # saved piece-in-cell inset (from Slot-cell content_frac; 0.16 = the old shipped look)
var giver_chips: Array = []        # [{chip, qi}]
var _giver_row: Control = null     # the HBox the giver cards sit in — kept so the live refresh can reorder cards (ready-first)
var home_btn: Button                 # the centre nav Home button — IS the decorate jump; breathes when a spot is affordable
# the bottom-nav bag is a circular well (the always-present bag row is retired).
# bag_btn: tap → full bag, drag a board item onto it → stash; bag_content (a CenterContainer)
# shows the most-recent stashed item, centered at bag_piece_px.
var bag_btn: Button
var bag_content: Control
var bag_piece_px := 72.0             # the in-well item-preview size (set from the well px on build)
var _bag_count_lbl: Label            # the "x/y" bag count under the bag well
var _bag_well_drawn_disc := false    # true only for the kit-absent drawn-disc fallback (glyph lives IN bag_content)
# the bottom-bar INFO BAR: tapping a board item selects it here (its name + an info button that opens the
# Tiers ladder + a trashcan that sells it for coins when it's a deletable, non-generator item).
var _selected_cell := Vector2i(-1, -1)
var _focus_ring: Control = null      # the corner-bracket frame drawn on the selected cell (lazily built in board_area)
var _info_icon: CenterContainer      # the selected piece preview
var _info_label: Label               # "<name> · Tier N" (or the empty-state prompt)
var _info_desc_label: Label          # compact player-use hint for the selected item
var _info_btn: Button                # opens the selected item's Tiers ladder
var _info_button_hidden := false     # workbench option: hide the floating info button even when selected
var _info_btn_selected_pos := Vector2.ZERO
var _info_btn_empty_pos := Vector2.ZERO
var _info_trash: Button              # sells the selected item; its content shows trash + payout (built by the kit)
var _info_trash_count: Label         # the "+N" sell payout amount inside the trash button (kit meta sell_count)
var _info_trash_coin: Control        # the payout currency icon slot (standard coin/acorn) inside the trash button
# T54 — the burst-upgrade buy chip: it occupies the action slot the sell button leaves empty when a
# GENERATOR is selected (generators aren't sellable). Built as a sibling of the sell button so the bar
# reads as one button language; shown only for a generator that still has a burst level to buy.
var _info_burst: Button              # the burst-upgrade buy chip (a generator's contextual action)
var _info_burst_sb: StyleBoxFlat     # the badge's style (mutated for affordable / dimmed states)
var _info_burst_count: Label         # the next-cost coin amount inside the badge
var _info_burst_coin: Control        # the coin icon slot inside the badge
# T55 — the BUY chip: buy a copy of the SELECTED item (coins for sub-top tiers, 💎 for the top tier,
# at G.buy_price) and drop it on the board (the bag when the board is full). Sits beside the sell button.
var _info_buy: Button                # the buy-a-copy chip (a regular item's second action, beside sell)
var _info_buy_sb: StyleBoxFlat       # the badge's style (mutated for affordable / dimmed states)
var _info_buy_count: Label           # the price amount inside the badge
var _info_buy_coin: Control          # the price-currency icon slot (coin / gem) inside the badge
var _info_inner_px := 62.4           # the info bar's info-button slot (from the kit's inner-control knob)
var _info_item_icon_scale := 0.80    # selected item/generator art scale as a fraction of the info bar height
var _info_item_px := 62.4            # selected item/generator art size in the info bar
var coins_label: Label
var _2x_offer: Control = null   # the post-reward 2× "double your coins" card — pay 💎 to double a big quest coin reward (§10)
var diamonds_label: Label
var level_label: Label            # S10: the shared Lv chip, wired in BOTH scenes
var _open_water: Callable = Callable()  # opens the water stall (the water pill's +; wired from the HUD)
var _open_shop: Callable = Callable()   # opens the acorn (premium) stall — the bag's short-of-acorns prompt
var _hud_refresh: Callable = Callable() # ticks the shared wallet + re-syncs the live water cache (on_refresh)
var bottom_bar: Control          # the board bottom bar row (Home · info bar · Bag+count)
var _action_bar_relayout_queued := false
var _last_action_bar_view_size := Vector2.ZERO
var _board_reflow_queued := false           # debounce for the board-grid reflow on a window resize
var _last_board_view_size := Vector2.ZERO
var _landscape := false                      # display orientation: wide viewports render the 7×9 model transposed to 9×7

var _press_cell := Vector2i(-1, -1)
var _press_pos := Vector2.ZERO
var _press_was_selected := false   # the press landed on the already-focused cell (collect-on-second-tap)
var _pressing := false              # a physical press is in flight — dedupes the mouse+touch pair emulate_touch_from_mouse delivers
var _drag_is_gen := false           # the current drag picked up a generator (movable-only, §6)
var _drag_pending := false          # pressed on a tile; the lift waits for the touch slop (_drag_slop_px)
var _drag_node: Control = null
var _drag_from := Vector2i(-1, -1)
# Bundle A (tactile) drag feel — live only while a board piece is dragged:
#   • telegraph: the cell the held tile currently hovers as a VALID merge target (glow + breathe +
#     magnet lean). Tracked so it clears cleanly when the hover moves off / the drag ends (no stuck glow).
#   • lean: the held tile tilts into pointer velocity, lagged, easing back to upright when still.
var _telegraph_cell := Vector2i(-1, -1)
var _telegraph_node: Control = null   # the target piece currently telegraphed (its modulate/offset are restored on clear)
var _telegraph_rest := Vector2.ZERO   # the target's resting position (to undo the magnet lean)
var _drag_lean := 0.0                 # the held tile's current lean (rad), lerped toward the velocity target
var _drag_last_pos := Vector2.ZERO    # previous drag-follow pointer pos (for the per-update delta)
var _drag_lean_seeded := false        # false until the first follow seeds _drag_last_pos (so the first frame has no spurious velocity)
var animating := false
var _anim_t := 0.0                  # seconds the animating gate has been held (watchdog — see _process)
var _idle := 0.0                   # seconds without input → the wiggle hint

var water_label: Label
var _water_icon: Control
var _water_pill: Control              # the whole Water top-pill panel (breathes while the can is empty)
var _wallet_panel: Control
var refill_btn: Button
var _empty_hint_shown := false        # the drifting "water refills over time" hint fires once per empty episode
# T43: the empty-water surfaces stack under the Lv chip (shown only at water<=0): the free/💎
# refill (refill_btn). (The free daily refill — a full can, capped + cooled — lives in the water
# SHOP stall now, not here; see shop.gd.)
var _refill_stack: VBoxContainer
var _water_pending_drained := false   # the starter-pack water credit drains once per board open

func _ready() -> void:
	UiFont.apply()
	Music.ensure()
	# UI redesign: the play surface is a flat SURFACE stage so items pop — replacing the
	# painted bg_grove_board.png (an olive field) and the warm dim that used to recede it.
	# A flat neutral field needs no veil.
	add_child(_field_backdrop())
	# (the ambient drift + wandering-spirit layers were removed — they cluttered the top.)
	_load_state()
	SceneWarm.prewarm("res://engine/scenes/Map.tscn")   # warm the Home target off-thread while we build

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# CENTRED flow: the page content (NEXT UNLOCK strip → quest fence → board) flows RELATIVE row to
	# row inside the stack region (EDGE_GAP under the HUD pills, EDGE_GAP over the bottom bar). Spare
	# vertical room — the board is cell-quantised and can be width-capped on narrow screens — splits
	# EQUALLY above and below the group, so the page keeps matching top/bottom margins instead of
	# pooling all the slack against the bottom bar. The region's top/bottom offsets are set in
	# _recompute_board_geometry (they depend on the bottom bar height and recompute on a live resize).
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", STACK_SEP)
	add_child(root)
	_stack = root

	# the quest fence: a full-width wall the giver animals pop up over, each
	# with a big cream ask-card (item + progress + star reward; ✓ when ready)
	_fence_h = _quest_row_h_px()
	giver_bar = Control.new()
	giver_bar.custom_minimum_size = Vector2(0, _fence_h)
	giver_bar.size_flags_horizontal = Control.SIZE_FILL
	root.add_child(giver_bar)

	# The standalone "✿ Decorate!" pill is retired — the centre Home button below IS the decorate
	# jump, and it lights up (a gold ready-dot + a gentle breathe) the moment a spot is affordable.

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN   # follow the fence in the top-down flow
	root.add_child(center)
	_board_center = center
	board_area = Control.new()
	# pick up any saved UI-Workbench board design (gap / frame / scale / item) BEFORE the fit is computed,
	# so the gutter + frame budgets and the final cell size all reflect it. Absent → today's defaults.
	_load_board_config()
	# size the cells + quest band to the current viewport AND position the bottom-anchored stack region.
	# Recomputed on a live window resize so a resized desktop window reflows instead of clipping.
	_recompute_board_geometry()
	board_area.gui_input.connect(_on_board_input)
	center.add_child(board_area)

	# the bag is no longer an always-present row; it is a single circular well in the bottom nav
	# (tap → full bag overlay, drag a board item onto it → stash). See _make_bag_button.

	# The board bottom bar: Home · Info bar · Bag (+ x/y count). Tapping a board item SELECTS it into the
	# centre info bar — its name, an info button that opens the Tiers ladder, and a trashcan that sells it
	# for coins when it's a deletable (non-generator) item. Selling moved here from the old drag-to-merchant
	# well. Bag stays a drag-to-stash target; Home returns to the Map.
	# The row holder itself is TRANSPARENT: the Home and Bag tiles are free-standing paper tiles at the two
	# ends, and the painted cream tray is the info bar alone, filling the centre between them.
	var bar := PanelContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 0.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb_inset := Look.safe_bottom(self)
	var bottom_btn_px := _bottom_button_px()
	var bottom_bar_h := _bottom_bar_h_px(bottom_btn_px)
	var action_opts := ActionBar.opts()
	var bar_margin := _tray_side_margin_px()
	bar.offset_left = bar_margin
	bar.offset_right = _view_size().x - bar_margin
	bar.offset_top = -bottom_bar_h - BOTTOM_BAR_INSET - sb_inset
	bar.offset_bottom = -BOTTOM_BAR_INSET - sb_inset
	bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	bar.set_meta("shared_action_tray", true)
	add_child(bar)
	bottom_bar = bar
	var row := HBoxContainer.new()
	row.name = "ActionBarRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", ActionBar.well_gap(bottom_btn_px))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(ActionBar.content_host(row, bottom_bar_h, action_opts))
	_rebuild_action_bar_row(row, bottom_btn_px, action_opts, bottom_bar_h, false)
	if get_viewport() != null:
		_last_action_bar_view_size = get_viewport_rect().size
		_last_board_view_size = get_viewport_rect().size
		if not get_viewport().size_changed.is_connected(_on_action_bar_viewport_resized):
			get_viewport().size_changed.connect(_on_action_bar_viewport_resized)
		if not get_viewport().size_changed.is_connected(_on_board_viewport_resized):
			get_viewport().size_changed.connect(_on_board_viewport_resized)

	_build_hud()
	_build_water_hud()
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.timeout.connect(_tick_water)
	add_child(tick)
	tick.start()
	add_child(Ambient.build_weather(get_viewport_rect().size, Ambient.weather_now()))
	# bundle D: the combo screen bloom — ONE overlay owned by the scene, so it dies with the board.
	# It sits above the board art but below the HUD; merges poke it via bump().
	_combo_bloom = ComboBloom.new()
	add_child(_combo_bloom)
	# resolve the workbench-tuned feel-FX opts ONCE — the game then runs the SAME appliers the
	# Merge/Land/Launch/Move workbenches preview, so a saved tuning takes effect in-game.
	var KitX: GDScript = KIT
	var fx_cfg: Dictionary = KitX.load_config(KitX.CONFIG_PATH)
	_merge_opts = MergeFx.from_config(fx_cfg)
	_land_opts = LandFx.from_config(fx_cfg)
	_launch_opts = LaunchFx.from_config(fx_cfg)
	_move_opts = MoveFx.from_config(fx_cfg)
	_grab_opts = GrabFx.from_config(fx_cfg)
	_grid_fx_opts = {"merge": _merge_opts, "move": _move_opts, "land": _land_opts}   # one bundle for GridFx
	_ready_glow_opts = KitX.ready_glow_opts_from_config(fx_cfg)   # the quest-ready glow look (workbench "ready_glow")
	_rebuild_all()
	if _winback:
		_winback = false
		FX.floating_text(self, Vector2(get_global_rect().get_center().x - 260, 200),
			Strings.t("board.winback.rained"), CREAM, FS.TITLE)
		Audio.play("rain_refill" if Audio.has("rain_refill") else "level_complete", -3.0)

	Debug.mount(self)                    # debug/authoring panel (no-op in prod)
	_maybe_show_board_tutorial_first_run.call_deferred()
	_maybe_offer_retirement.call_deferred()   # §6: a calm moment — board entry, never mid-gesture

func debug_refresh_weather() -> void:
	var insert_at := get_child_count()
	for child in get_children():
		if child.name == "WeatherLayer":
			insert_at = mini(insert_at, child.get_index())
			remove_child(child)
			child.queue_free()
	var weather := Ambient.build_weather(get_viewport_rect().size, Ambient.weather_now())
	add_child(weather)
	move_child(weather, mini(insert_at, get_child_count() - 1))

# After a quiet spell, a pair that can merge wiggles to show the next step
# (owner: ~5-10s of inactivity). Re-nudges gently while the player stays idle.
func _process(delta: float) -> void:
	if board == null:
		return
	# Watchdog: `animating` gates ALL board taps and is meant to be true only for a merge tween
	# (~0.12s, cleared in _after_merge). If a tween callback is ever missed the gate sticks true and
	# the board silently swallows every tap (taps "do nothing"). Self-heal so input can never soft-lock.
	if animating:
		_anim_t += delta
		if _anim_t > 0.6:
			animating = false
			_anim_t = 0.0
			if Debug.on():
				print("[collect] animating watchdog fired — gate was stuck; input re-enabled")
	else:
		_anim_t = 0.0
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
	# FTUE: the hand is the FIRST merge teach. Don't rock pieces under a live hint, and don't
	# rock them at all until the merge hand has been seen — after that the idle hint resumes as
	# the ongoing re-nudge.
	if _hand_hint != null and is_instance_valid(_hand_hint):
		return []
	if Features.on("ftue_hand_hint") and not Save.ftue_seen("merge"):
		return []
	var pair := BoardLogic.find_mergeable_pair(board)
	for cell in pair:
		var n: Control = piece_nodes.get(cell)
		if n != null and is_instance_valid(n):
			FX.rock(n, HINT_ROCK_DEG, HINT_ROCK_CYCLE, HINT_ROCK_CYCLES)   # W1: gentle rock
	return pair

# --- FTUE hand hints -------------------------------------------------------------------
# Two one-time teaches, in order: drag-to-merge, then tap-the-generator. Spec:
# docs/superpowers/specs/2026-07-23-ftue-hand-hint-design.md. Called at the end of every
# _rebuild_all so the hint follows the board; a live hint RETARGETS rather than restarting.

func _maybe_hand_hint() -> void:
	if not Features.on("ftue_hand_hint"):
		_dismiss_hand_hint()   # the flag can flip off while a hint is live — tear it down, not stuck forever
		return
	await get_tree().process_frame          # let the rebuild's layout settle before reading rects
	if not is_inside_tree():
		return
	var gen_cell := _hand_hint_gen_cell()   # one scan of gen_nodes, shared by eligibility + rect lookup
	var want := _hand_hint_eligible(gen_cell)
	if want == "":
		_dismiss_hand_hint()
		return
	var rects := _hand_hint_rects(want, gen_cell)
	if rects.is_empty():
		_dismiss_hand_hint()
		return
	if _hand_hint != null and is_instance_valid(_hand_hint) and _hand_hint_id == want:
		_hand_hint.retarget(rects[0], rects[1])   # same teach, moved board — keep the loop running
		return
	_dismiss_hand_hint()
	var gesture: String = HandHint.GESTURE_DRAG if want == "merge" else HandHint.GESTURE_TAP
	_hand_hint = HandHint.present(self, gesture, rects[0], rects[1])
	_hand_hint_id = want if _hand_hint != null else ""

# Which teach the ledger + the current board allow. "" = none. `gen_cell` is the caller's own
# _hand_hint_gen_cell() result — passed in rather than re-scanned here (that scan runs once per
# _maybe_hand_hint(), not twice: once for eligibility, again for _hand_hint_rects()).
func _hand_hint_eligible(gen_cell: Array) -> String:
	var has_pair := not BoardLogic.find_mergeable_pair(board).is_empty()
	var has_gen := not gen_cell.is_empty()
	return HandHint.next_hint_id(Save.ftue_seen("merge"), Save.ftue_seen("gen_tap"), has_pair, has_gen)

# The generator the tap teach points at: the first live, tappable (non-accumulator, non-treat)
# generator on the board. [] when there is none. Returned as an Array so "no cell" is expressible.
func _hand_hint_gen_cell() -> Array:
	for cell in gen_nodes.keys():
		if not board.is_gen(cell):
			continue
		var gid := board.gen_id_at(cell)
		if G.is_accumulator(gid) or G.is_treat_gen(gid):
			continue
		var n: Control = gen_nodes.get(cell)
		if n != null and is_instance_valid(n):
			return [cell]
	return []

# [source_rect, target_rect] in THIS control's space, or [] when a node is missing. `gen_cell` is
# the caller's own _hand_hint_gen_cell() result (see _hand_hint_eligible()'s comment).
func _hand_hint_rects(id: String, gen_cell: Array) -> Array:
	if id == "merge":
		var pair := BoardLogic.find_mergeable_pair(board)
		if pair.size() < 2:
			return []
		var a: Control = piece_nodes.get(pair[0])
		var b: Control = piece_nodes.get(pair[1])
		if a == null or not is_instance_valid(a) or b == null or not is_instance_valid(b):
			return []
		return [_local_rect(a), _local_rect(b)]
	if gen_cell.is_empty():
		return []
	var gn: Control = gen_nodes.get(gen_cell[0])
	if gn == null or not is_instance_valid(gn):
		return []
	return [Rect2(), _local_rect(gn)]

func _local_rect(n: Control) -> Rect2:
	var gr := n.get_global_rect()
	return Rect2(gr.position - get_global_rect().position, gr.size)

func _dismiss_hand_hint() -> void:
	if _hand_hint != null and is_instance_valid(_hand_hint):
		_hand_hint.dismiss()
	_hand_hint = null
	_hand_hint_id = ""

# The taught action HAPPENED — bank it and hand off to the next teach.
func _end_hand_hint(id: String) -> void:
	if not Features.on("ftue_hand_hint"):   # flag off: tear down ANY live hint, not just an id match —
		_dismiss_hand_hint()                 # a different-id hint would otherwise linger until some later,
		return                                # unrelated rebuild. No ledger write while the flag is off.
	if _hand_hint_id == id:
		# Tear down before the seen check below — a live hint must clear even if `id` is already
		# marked seen (that check returns early and never re-teaches, so it must not gate the teardown).
		_dismiss_hand_hint()

	if Save.ftue_seen(id):
		return
	Save.mark_ftue_seen(id)
	_maybe_hand_hint()

# --- display orientation -------------------------------------------------------------
# The DATA model is always G.COLS×G.ROWS (7 wide × 9 tall). On a WIDE viewport we render it TRANSPOSED —
# the same cells drawn 9 across × 7 down, items still upright — so the board fills a landscape area. The
# model, saves, generators, and merge/adjacency logic never change; only cell→pixel mapping (and its
# inverse) and the board's pixel size swap. _landscape is recomputed (with hysteresis) per geometry pass.
func _compute_landscape() -> bool:
	var v := _view_size()
	var a := v.x / maxf(1.0, v.y)
	# hysteresis: hold the current orientation across a deadband so a resize near the cutoff is stable.
	if _landscape:
		return a >= ROTATE_ASPECT - ROTATE_DEADBAND
	return a > ROTATE_ASPECT + ROTATE_DEADBAND

# Cells ACROSS / DOWN as drawn: portrait 7×9, landscape (transposed) 9×7.
func _disp_cols() -> int:
	return G.ROWS if _landscape else G.COLS

func _disp_rows() -> int:
	return G.COLS if _landscape else G.ROWS

func _board_w() -> float:
	return _disp_cols() * csz + (_disp_cols() - 1) * GAP

func _board_h() -> float:
	return _disp_rows() * csz + (_disp_rows() - 1) * GAP

# The board panel sits centred in the full-width stack: its visual block is the grid plus the frame
# overhang on each side, so the breathing space to the screen edge is half the leftover width. The
# floating bottom bar insets by the SAME amount so its sides line up with the board's sides.
func _board_side_margin_px() -> float:
	return maxf(0.0, (_view_size().x - (_board_w() + FRAME_OUT * 2.0)) * 0.5)

# The bottom tray's side inset. It follows the board's sides while the board is width-governed, but
# is CAPPED so a height-capped (narrower) board — e.g. once the NEXT UNLOCK strip takes top room —
# can't starve the tray of the width its info copy needs.
func _tray_side_margin_px() -> float:
	return minf(_board_side_margin_px(), roundf(_view_size().x * 0.022))

# Live aspect + grid read-out for the debug overlay (you read this to pick the rotation cutoff).
func debug_layout_info() -> String:
	var v := _view_size()
	return "aspect %.0f×%.0f = %.3f   grid %d×%d   %s" % [
		v.x, v.y, v.x / maxf(1.0, v.y), _disp_cols(), _disp_rows(), ("LANDSCAPE" if _landscape else "PORTRAIT")]

# Size the cell grid + quest band to the CURRENT viewport, and resize the board containers to match.
# Shared by the initial build and the live window-resize reflow so the two can never drift. The board
# is WIDTH-governed: square cells fill the screen width (w_csz); the height budget (h_csz) is only a
# CAP so on wide/short screens the board never grows past the vertical budget into the quest/bottom
# rows. Assumes _load_board_config() has already loaded GAP / FRAME_OUT / _board_scale.
# The page column's ONE absolute anchor: content starts EDGE_GAP below the HUD's measured bottom
# (the Lv badge — Hud.bottom_px, workbench-config-driven), plus the device safe-area inset. Matching
# EDGE_GAP above the bottom action bar keeps the page's top and bottom margins equal.
func _content_top_px() -> float:
	return Hud.bottom_px() + EDGE_GAP + Look.safe_top(self)

func _recompute_board_geometry() -> void:
	_landscape = _compute_landscape()   # pick orientation FIRST (the size + cell mapping below read it)
	_fence_h = _quest_row_h_px()
	if giver_bar != null and is_instance_valid(giver_bar):
		giver_bar.custom_minimum_size = Vector2(0, _fence_h)
	var view := _view_size()
	var bottom_bar_h := _bottom_bar_h_px(_bottom_button_px())
	# The TOP-anchored stack region: its top edge is the page's ONE absolute anchor — EDGE_GAP below
	# the HUD's measured bottom (the Lv badge, the tallest top element — Hud.bottom_px), so the strip
	# can never slide behind the pills. The content rows (NEXT UNLOCK strip → quest fence → board)
	# live INSIDE the stack and flow relative to each other from there; the bottom edge caps the
	# board EDGE_GAP above the floating bottom bar — the SAME gap, so the page reads with equal
	# margins under the pills and over the action buttons.
	var bar_h := _unlock_bar_h_px()
	_place_unlock_bar(bar_h)
	var top_reserve := _content_top_px()
	var bar_top_y := view.y - Look.safe_bottom(self) - BOTTOM_BAR_INSET - bottom_bar_h
	if _stack != null and is_instance_valid(_stack):
		_stack.offset_top = top_reserve
		_stack.offset_bottom = -(view.y - bar_top_y + EDGE_GAP)   # cap the stack EDGE_GAP above the bottom bar
	# Cap the board to the room that actually remains inside the region after the quest fence + a gap, so
	# the grid never runs into the fence or the bottom bar regardless of screen shape.
	# the bamboo FRAME extends FRAME_OUT past the grid on every side — budget for it so the frame +
	# last column never run off-screen (the prior calc sized only the cells → overflow).
	# use the DISPLAY dims (transposed on a landscape viewport) so the cells fill the screen in either orientation.
	# `_board_scale` (1.0 = the responsive full-fit) shrinks the cells within that space — the in-game
	# "board size" knob. <1 leaves a centred margin; values >1 may overflow the screen budget.
	# the board's ceiling in the flow: below the strip row + the fence row (each + the VBox gap)
	var board_top := top_reserve + bar_h + STACK_SEP + _fence_h + STACK_SEP
	var board_bottom := bar_top_y - EDGE_GAP
	var fit: Dictionary = BoardFit.fit_bottom_aligned(
		view, _disp_cols(), _disp_rows(), GAP, FRAME_OUT, BOARD_MARGIN,
		board_top, board_bottom, _board_scale)
	csz = float(fit.cell)
	# The frame overhangs the grid by FRAME_OUT on all sides — reserve that real footprint in the VBox.
	if _board_center != null and is_instance_valid(_board_center):
		_board_center.custom_minimum_size = Vector2(_board_w() + FRAME_OUT * 2.0, _board_h() + FRAME_OUT * 2.0)
	if board_area != null and is_instance_valid(board_area):
		board_area.custom_minimum_size = Vector2(_board_w(), _board_h())

# The desktop window can be resized after launch (a real device's screen is fixed, so this never
# fires there). Recompute the cell size + quest band for the new viewport and re-lay the grid, so the
# board reflows instead of clipping. Debounced + coalesced via call_deferred, like the action bar.
func _on_board_viewport_resized() -> void:
	if _board_reflow_queued:
		return
	_board_reflow_queued = true
	_reflow_board_after_resize.call_deferred()

func _reflow_board_after_resize() -> void:
	_board_reflow_queued = false
	if board == null or get_viewport() == null or not is_inside_tree():
		return
	var sz := get_viewport_rect().size
	if sz == _last_board_view_size:
		return
	# don't yank a piece out from under an in-flight drag; the next resize tick will catch up.
	if _drag_node != null or animating:
		return
	_last_board_view_size = sz
	_recompute_board_geometry()
	_rebuild_all()   # re-lays the slots, pieces, generators and giver cards at the new cell size
	_relayout_action_bar()   # the bar insets to the board's sides — re-run it now csz (and _board_w) are fresh

# --- board design (tools/ui_workbench — the "board" element) --------------------------
# Pull the optional saved board design out of the UI-Workbench settings. Board layout owns the gutter,
# frame overhang, and overall scale; Slot-cell owns piece size via bag_card.content_frac. Absent file or
# keys preserve the shipped defaults. (cell / cols / rows are workbench-PREVIEW only — the live grid is
# G.COLS×G.ROWS and sizes itself to the screen.)
func _load_board_config() -> void:
	var Kit: GDScript = KIT
	if Kit == null:
		return
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	if cfg.has("board") and cfg["board"] is Dictionary:
		var b: Dictionary = (cfg["board"] as Dictionary).duplicate()
		# Slot-cell owns piece size via bag_card.content_frac — resolve it through the shared rule so the
		# live board and the residents dialog (PieceView.board_item_inset) can't drift apart.
		b["content_frac"] = PieceView.board_content_pct(cfg)
		_apply_board_config(b)

# Map a saved "board" block onto the live geometry. Split out so it is unit-testable without a file.
func _apply_board_config(b: Dictionary) -> void:
	GAP = float(b.get("gap", 7.0))
	FRAME_OUT = float(b.get("frame", 60.0))
	_board_scale = float(b.get("scale", 100.0)) / 100.0
	# Slot-cell content_frac = visible piece width as a % of its cell. Fall back to legacy board.item only
	# for older settings files that predate the shared Slot-cell control.
	var content_pct := float(b.get("content_frac", b.get("item", 68.0)))
	_board_item_inset = PieceView.inset_from_content_pct(content_pct)

# (The old per-axis fence/board vertical NUDGES — board_layout.json's fence_dy/board_dy, applied on
# sort — were retired with the bottom-anchored layout: the stack now packs to the bottom and the board
# is sized to the room between the HUD and bottom bar, so a manual nudge is no longer needed.)

# --- state ----------------------------------------------------------------------

func _sanitize_saved_item_bag(raw: Array) -> Dictionary:
	var out: Array = []
	var changed := false
	for v in raw:
		var code := int(v)
		if code > 0 and G.is_valid_item_code(code):
			out.append(code)
		else:
			changed = true
	return {"items": out, "changed": changed}

func _quest_items_are_known(q: Dictionary) -> bool:
	if q.has("line"):
		return G.is_valid_item_code(int(q.get("line", 0)) * 100 + int(q.get("tier", 0)))
	if q.has("asks"):
		for ask in Array(q.get("asks", [])):
			if not (ask is Dictionary):
				continue
			if not G.is_valid_item_code(int(ask.get("line", 0)) * 100 + int(ask.get("tier", 0))):
				return false
	return true

func _sanitize_saved_quests(raw: Array) -> Dictionary:
	var out: Array = []
	var changed := false
	for q in raw:
		if not (q is Dictionary):
			changed = true
			continue
		var qd: Dictionary = q
		if not _quest_items_are_known(qd):
			changed = true
			continue
		out.append(qd)
	return {"quests": out, "changed": changed}

func _sanitize_seen(g: Dictionary) -> bool:
	if not g.has("seen"):
		return false
	if not (g["seen"] is Dictionary):
		g["seen"] = {}
		return true
	var seen: Dictionary = g["seen"]
	var out := {}
	var changed := false
	for key in seen.keys():
		var sk := String(key)
		if not sk.is_valid_int():
			changed = true
			continue
		var code := int(sk)
		if not G.is_valid_item_code(code):
			changed = true
			continue
		out[sk] = seen[key]
	if changed:
		g["seen"] = out
	return changed

# A saved quest asks for a line the player should not have reached yet (either its single `line`, or any
# `asks[]` entry) — see G.line_gated_out. Mirrors _quest_items_are_known's dual shape.
func _quest_line_gated_out(q: Dictionary, level: int) -> bool:
	if q.has("line") and G.line_gated_out(int(q.get("line", 0)), level):
		return true
	for ask in Array(q.get("asks", [])):
		if ask is Dictionary and G.line_gated_out(int((ask as Dictionary).get("line", 0)), level):
			return true
	return false

# Save migration (2026-07-23, scene-aligned zone_unlock_level cadence — now DERIVED, see content.gd's
# _build_cadence): strip every generator, item and quest for a line the player should NOT have reached
# yet at their CURRENT level, so an older save matches
# the new pacing. Silent removal, no compensation (owner call). IDEMPOTENT — a no-op on any save already
# consistent with the cadence (birth-on-tap only ever grants in-cadence content; every new save starts
# clean), so it runs on every load with no schema bump and no one-time flag. Exempt (never gated out):
# coins, treasure/treat lines and special drops (zone_of_line == -1), accumulator generators, and the gen_1
# anchor (zone 0 unlocks at L1). Returns true if anything was removed (→ the caller re-persists).
func _purge_above_level_content() -> bool:
	var lvl := _quest_level()
	var changed := false
	# board pieces
	for r in G.ROWS:
		for c in G.COLS:
			var cell := Vector2i(r, c)
			var code := board.item_at(cell)
			if code > 0 and G.line_gated_out(BoardModel.line_of(code), lvl):
				board.take(cell)
				changed = true
	# live generators on the board (accumulators + the anchor never gate out)
	for cell in board.gens.keys():
		var gid := String(board.gens[cell])
		if not G.is_accumulator(gid) and G.line_gated_out(int(G.gen_def(G.GENERATORS, gid).get("line", 0)), lvl):
			board.remove_gen(cell)
			changed = true
	# stored generators — filter the PARALLEL bag arrays (ids ∥ tiers ∥ boost) in lockstep
	var kept_ids: Array = []
	var kept_tiers: Array = []
	var kept_boost: Array = []
	for i in board.gen_bag.size():
		var gid := String(board.gen_bag[i])
		if not G.is_accumulator(gid) and G.line_gated_out(int(G.gen_def(G.GENERATORS, gid).get("line", 0)), lvl):
			changed = true
			continue
		kept_ids.append(board.gen_bag[i])
		kept_tiers.append(board.gen_bag_tiers[i] if i < board.gen_bag_tiers.size() else 1)
		kept_boost.append(board.gen_bag_boost[i] if i < board.gen_bag_boost.size() else 0)
	board.gen_bag = kept_ids
	board.gen_bag_tiers = kept_tiers
	board.gen_bag_boost = kept_boost
	# stashed items in the item bag
	var kept_bag: Array = []
	for code in bag:
		if G.line_gated_out(BoardModel.line_of(int(code)), lvl):
			changed = true
		else:
			kept_bag.append(code)
	bag = kept_bag
	# live quests asking for a now-too-advanced line (the fence refills with valid lines after)
	var kept_quests: Array = []
	for q in quests:
		if q is Dictionary and _quest_line_gated_out(q, lvl):
			changed = true
		else:
			kept_quests.append(q)
	quests = kept_quests
	return changed

func _load_state() -> void:
	board = BoardModel.new()
	var now := Time.get_unix_time_from_system()
	var g := Save.grove()
	var save_dirty := _sanitize_seen(g)
	if g.has("board"):
		save_dirty = board.from_dict(g["board"]) or save_dirty
		var quest_clean := _sanitize_saved_quests(Array(g.get("quests", [])))
		quests = quest_clean["quests"]
		save_dirty = bool(quest_clean["changed"]) or save_dirty
		quests_map = int(g.get("quests_map", -1))
		var bag_clean := _sanitize_saved_item_bag(Array(g.get("bag", [])))
		bag = bag_clean["items"]
		save_dirty = bool(bag_clean["changed"]) or save_dirty
		# strip any generator/item/quest above the player's level under the scene-aligned cadence (migrates
		# older saves; idempotent no-op once clean). Runs after the board + quests + bag are loaded.
		save_dirty = _purge_above_level_content() or save_dirty
		rng.state = int(g.get("rng_state", 0))
		water = int(g.get("water", G.WATER_CAP))
		_regen_ts = float(g.get("regen_ts", now))
		# the >=48h check lives in Ambient now (both scenes' weather reads its stamp)
		if Ambient.check_winback(g, now) and water < G.WATER_CAP:
			water = G.WATER_CAP            # "it rained" — the >= 48h win-back
			_regen_ts = now
			_winback = true
		else:
			_apply_regen(now)
	else:
		if forced_rng_seed >= 0:
			rng.seed = forced_rng_seed      # a screenshot tool asked for a reproducible board
		else:
			rng.randomize()
		_regen_ts = now
		_init_quests()
		_persist()
	if board.gens.is_empty():               # fresh game, or a pre-T17 save with no gen map →
		# Seed only the zone-0 anchor (`gen_1`). Later base-line tools are born on tap when an active quest
		# asks for their line and the player lacks the generator; see Quests.due_gen / _produce_due_generators.
		board.seed_gens(0, _quest_level())
		save_dirty = true
	if quests_map != _quest_map():        # never-seeded save, or the level crossed into a new band
		_init_quests()
	else:
		_refill_quests()                    # top up / trim the live fence to the current meter
	for v in board.items:                # everything already growing counts as met
		_mark_seen(int(v))
	for v in bag:
		_mark_seen(int(v))
	if save_dirty:
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

# [{line, seen, in_pool, code}] for the Producing dialog. Normal generators SHOW ALL: one entry per line
# in the WHOLE game (every generator / every map, in roster order), so the panel reads as the full
# collection roadmap. Treat generators show only their treasure line; accumulator generators return no
# entries because they bank currency, not item lines. `seen`/`code` carry the lowest-seen tier for the piece.
func _gen_line_entries(gid: String) -> Array:
	var seen: Dictionary = Save.grove().get("seen", {})
	var pool: Array = []
	var out: Array = []
	var added := {}
	var lines: Array = []
	if G.is_accumulator(gid):
		return out
	if G.is_treat_gen(gid):
		var treat_line := G.treat_line_of(gid)
		lines.append(treat_line)
		pool = [treat_line] if treat_line > 0 else []
	else:
		var selected_line := int(G.gen_def(G.GENERATORS, gid).get("line", 0))
		pool = [selected_line] if selected_line > 0 else []
		for gen in G.GENERATORS:
			lines.append(int(gen.get("line", 0)))   # gen redesign: one line per generator (was lines[])
	for l in lines:
		var line := int(l)
		if added.has(line) or not G.LINES.has(line):
			continue                      # a line lives on one generator, but guard against roster overlap
		added[line] = true
		var code := _lowest_seen_code(line, seen)
		out.append({"line": line, "seen": code > 0, "in_pool": pool.has(line), "code": code})
	return out

# The lowest tier of `line` the player has discovered (its representative piece for the Producing cell), or 0
# if the line is wholly unseen. Pure off the seen set.
func _lowest_seen_code(line: int, seen: Dictionary) -> int:
	for t in range(1, G.TOP_TIER + 1):
		var code := line * 100 + t
		if seen.has(str(code)):
			return code
	return 0

# water regen rule lives in BoardLogic; apply the returned state to ours
func _apply_regen(now: float) -> void:
	var r := BoardLogic.regen(water, _regen_ts, now)
	water = int(r.water)
	_regen_ts = float(r.regen_ts)

# --- §7 live generated-quest fence ------------------------------------------------
# The single progression total — the COIN CLOCK (cumulative organic coin earnings); drives the
# level, the fence meter, and the vase (coin-clock redesign, spec 2026-07-17).
func _earned() -> int:
	return Save.coins_earned_lifetime()

# The reward BAND the fence currently pays at (the retired "current map" axis, now level-derived).
func _quest_map() -> int:
	return Quests.current_band(_quest_level())

func _quest_level() -> int:
	return G.level()

# Top up / trim the live fence to the metered count with freshly generated quests (§7). Deterministic
# via the rng.
func _refill_quests() -> void:
	quests = Quests.refill(quests, _quest_map(), board.gens, board.gen_bag, _earned(), _quest_level(), rng, _recent_items)
	_assign_givers()                          # give each new quest a face distinct from every other live stand

# Each quest carries a stable `giver` index (the portrait shown on its stand). A NEW quest is assigned a
# face that is NOT on any other LIVE stand (no two visible cards share a giver) and, when the pool allows,
# not among the last 5 assigned either — the index persists on the quest (saved), so a stand keeps its face
# across rebuilds + sessions. The pick + collision de-dup live in the pure, headless-tested Quests.assign_givers.
func _assign_givers() -> void:
	# seed the rolling window once from quests that already carry a giver (their array order ≈ assignment
	# order), so a freshly-loaded session's new givers still avoid the recently-shown faces.
	if _recent_givers.is_empty():
		for q in quests:
			if q.has("giver"):
				_push_recent_giver(int(q["giver"]))
	Quests.assign_givers(quests, _recent_givers, Bust.GIVER_COUNT, rng)

func _push_recent_giver(g: int) -> void:
	_recent_givers.append(g)
	while _recent_givers.size() > 5:
		_recent_givers.pop_front()

# Fresh fence for the current map (load / migration / crossing a map boundary).
func _init_quests() -> void:
	quests = []
	quests_map = _quest_map()
	_refill_quests()

func _persist() -> void:
	var g := Save.grove()
	g["board"] = board.to_dict()
	g["quests"] = quests
	g["quests_map"] = quests_map
	g["bag"] = bag
	g["rng_state"] = rng.state
	g["water"] = water
	g["regen_ts"] = _regen_ts
	g["last_seen"] = Time.get_unix_time_from_system()
	Save.grove_write()

# --- the fan-out contract (board_decomposition.md, "Architecture decision: coordinator owns state")
# THE one post-mutation beat. Call this after ANY board / bag / quest mutation, whoever triggered
# it: it persists, then fans the refresh out to every board-dependent view — so a new mutation path
# cannot silently forget one of them. It replaces the four-call cluster (_persist + _update_hud +
# _refresh_giver_lights + _refresh_generator_dim) that used to be hand-rolled at every action site.
#
# Two calls cover the four: _refresh_giver_lights IS the board+fence refresh hub — it re-runs the
# generator fade (_refresh_generator_dim), the quest-line item fade and the quest ready marks on the
# same beat (see its body), so the explicit _refresh_generator_dim the old sites tacked on was always
# a second, identical pass over the same nodes.
#
# `hud_deferred` is the ONE named opt-out, and it is a DEFERRAL, not an omission: where a payout
# FLIES to the wallet, FX.reward_arrival ticks the label from its arrival callback (the number is
# meant to change when the coin LANDS). An eager _update_hud there would tick it before the coin
# arrives. Those sites pass true and keep their own arrival callback. Everything else takes the
# default and gets the whole fan-out.
#
# NOT a call site: _load_state (runs before the HUD/fence nodes exist), the water tick (_tick_water /
# _update_water_hud own the water pill, which is outside this fan-out), the persist-before-scene-change
# nav taps, and _grow_generators / _sync_accumulators (internal steps of _rebuild_all, which fans out
# on its own beat).
func _after_board_change(hud_deferred := false) -> void:
	_persist()
	if not hud_deferred:
		_update_hud()
	_refresh_giver_lights()

# the unlock CTA: ready when the NEXT cover-up cluster is unlockable right now (its page open,
# level floor met, affordable) — the Home button breathes to say "go unlock the next region."
func _gate_ready() -> bool:
	return G.any_cluster_ready(Save.grove().get("unlocks", {}), G.level(), Save.coins())

# --- HUD ------------------------------------------------------------------------

func _build_hud() -> void:
	# the shared top bar (owner: one module, currencies in the same place everywhere)
	var hud := Hud.build(self, {
		# water is Save-backed now (the shop grants through Save). The board keeps `water` as a live
		# cache for gameplay (regen/pop); when a shop grant ticks the HUD, re-sync the cache from Save
		# (a grant may have banked OVER the cap; regen pauses above cap) and refresh the refill stack.
		"on_refresh": func() -> void:
			if water != Save.water():
				water = Save.water()
				_regen_ts = Time.get_unix_time_from_system()
			_update_water_hud(),
		# the board shows the shared level badge top-left (mock: board_next_unlock_v1) — tap → the
		# level screen, same as the map.
		"on_level": func() -> void: LevelPopup.open(self)})
		# (no "home" opt → the shared HUD skips its top-left home chip; the bottom nav owns Home now)
	_build_unlock_bar()
	coins_label = hud.coins
	diamonds_label = hud.diamonds
	level_label = hud.level          # S10: store the board's Lv chip (set at build; level is static here)
	_wallet_panel = hud.wallet       # the shared cluster
	# water is the FIRST top-center pill now (Water·Coin·Gem); the board's live value overrides it via
	# _update_water_hud. The board owns only the empty-water REFILL stack (built in _build_water_hud).
	water_label = hud.water
	_water_icon = hud.water_icon
	_water_pill = hud.water_pill     # the whole Water pill panel — breathes while the can is empty (below)
	_open_water = hud.open_water     # the water stall (free refill + 💎 fill) — same as the water pill's +
	_open_shop = hud.open_shop       # the acorn stall — where the bag sends a player who is short
	_hud_refresh = hud.refresh       # tick the wallet + fire on_refresh (re-sync the live water cache from Save)
	_update_hud()

# Water is the FIRST top-center pill (Water·Coin·Gem), bound from the shared HUD (water_label / _water_icon
# in _build_hud) and overridden live via _update_water_hud. The board owns only the empty-water REFILL
# stack — the free/💎 rain refill — pinned top-LEFT below the Lv badge and shown only when water runs out.
# (The free daily refill — a full can, capped + cooled — is in the water SHOP stall now; see shop.gd.)
func _build_water_hud() -> void:
	# at water<=0 (§10 — the friction point): the free/💎 rain refill, shown only when live.
	_refill_stack = VBoxContainer.new()
	_refill_stack.add_theme_constant_override("separation", 8)
	_refill_stack.offset_left = 16.0
	# below the NEXT UNLOCK strip (which now owns the band right under the HUD pills)
	_refill_stack.offset_top = _content_top_px() + _unlock_bar_h_px() + 16.0
	_refill_stack.visible = false
	add_child(_refill_stack)
	refill_btn = Look.button(Strings.t("board.refill.free"), _on_refill, true)
	refill_btn.custom_minimum_size = Vector2(330, 76)
	_refill_stack.add_child(refill_btn)
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
	# the map) ONCE on board open — before the empty check, so a fresh top-up shows. ADDITIVE
	# and OVER-CAP (like the free refill): a player who buys the starter at a full can still gets
	# the paid water as a banked spare, not clamped to nothing. Regen pauses above the cap.
	if not _water_pending_drained:
		_water_pending_drained = true
		var credit := Save.take_water_pending()
		if credit > 0:
			water = water + credit
			_persist()
	# Water is a first-class currency in the shared top bar — always visible on the board now, matching
	# the map. (The old FTUE staged-chrome hide that kept the meter hidden until the 10 free pops were
	# spent is retired; the separate water-COST gate at _ftue_pops_done() — see _charge — is unchanged,
	# so during the free intro the meter simply reads full.)
	_water_icon.visible = true
	water_label.visible = true
	water_label.text = str(water)
	# the empty-water surfaces (§10 the friction point): while the can is empty the offer ALWAYS shows.
	var empty := water <= 0
	var free_ready := Claims.can_show("refill_water")
	# option 1 — no silent wall: the refill button surfaces whenever water <= 0, even when today's free
	# rain is unavailable AND there are too few 🌰 for the paid fill. In that third state it INVITES the water STALL
	# (free daily / IAP) rather than dead-ending in a wobble; the routing lives in _on_refill.
	refill_btn.visible = empty
	if refill_btn.visible:
		if free_ready:
			refill_btn.text = Strings.t("board.refill.free")
		elif Save.diamonds() >= G.REFILL_DIAMOND_COST:
			refill_btn.text = Strings.t("board.refill.paid") % G.REFILL_DIAMOND_COST
		else:
			refill_btn.text = Strings.t("board.refill.shop")
	_refill_stack.visible = refill_btn.visible
	if _refill_stack.visible:
		FX.breathe_once(refill_btn)
	# an always-present state cue: the water pill breathes while the can is empty and settles once
	# refilled — which also re-arms the blocked-tap hint below for the next empty episode.
	if empty:
		FX.breathe_once(_water_pill)
	else:
		FX.breathe_stop(_water_pill)
		_empty_hint_shown = false

# the blocked-tap teaching cue (option 2): tapping a dry generator drifts a hint ANCHORED to the empty
# water pill (it points at what's depleted), fired once per empty episode so rapid taps don't stack
# floaters. Re-armed when the can is refilled (see _update_water_hud). Content reassures — water comes
# back on its own, and the refill offer is right there — so the empty state never reads as "stuck".
func _cue_empty_water() -> void:
	if _empty_hint_shown:
		return
	_empty_hint_shown = true
	var anchor: Control = _water_icon if _water_icon != null and is_instance_valid(_water_icon) else water_label
	if anchor == null or not is_instance_valid(anchor):
		return
	FX.floating_text(self, anchor.get_global_rect().get_center() + Vector2(-140.0, 66.0), Strings.t("board.refill.hint"), CREAM, FS.HEADING)

func _on_refill() -> void:
	if water > 0:
		return
	if Claims.can_show("refill_water"):
		# Keep the claim ledger authoritative: the board's FREE action opens the same stall card
		# used everywhere else instead of bypassing the daily claim.
		if _open_water.is_valid():
			_open_water.call()
		else:
			FX.wobble(refill_btn)
			Audio.play("invalid_soft", -4.0)
		return
	if not Save.spend_diamonds(G.REFILL_DIAMOND_COST):
		# empty, today's free rain unavailable, and too few 🌰 for the paid fill → open the water STALL (free
		# daily top-up / IAP) instead of the old dead-end wobble (§10 "no silent wall"). Fall back to
		# the wobble only if the stall isn't wired (e.g. a test that neutralizes _open_water).
		if _open_water.is_valid():
			_open_water.call()
		else:
			FX.wobble(refill_btn)
			Audio.play("invalid_soft", -4.0)
		return
	water = G.WATER_CAP
	_regen_ts = Time.get_unix_time_from_system()
	Audio.play("rain_refill" if Audio.has("rain_refill") else "level_complete", -3.0)
	var water_target: Control = _water_icon if _water_icon != null and is_instance_valid(_water_icon) else water_label
	var refill_done := func() -> void:
		if not is_instance_valid(self):
			return
		_update_water_hud()
		_update_hud()
	FX.reward_arrival(self, refill_btn.get_global_rect().get_center(), "water", G.WATER_CAP, Color("#9CCDE8"), water_target, refill_done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "board_refill")
	_persist()
	refill_btn.visible = false
	_refill_stack.visible = false

func _update_hud() -> void:
	# the top wallet is Water·Coin·Gem now (no star count). Water is updated live by _update_water_hud.
	coins_label.text = str(Save.coins())
	if diamonds_label != null:
		diamonds_label.text = str(Save.diamonds())
	# The decorate invitation now rides on the centre Home button (the standalone CTA is gone):
	# light it up the moment the frontier map has a spot the player can afford; a fully-done
	# game (no frontier left) leaves it resting.
	_set_home_ready(_gate_ready())

# The Home button is the way back to the decorate hub, so the "you can afford a spot" cue lives
# ON it now: a gentle breathe. On the board stars
# only rise, so this flips off→on once and never back; breathe_once self-guards re-entry.
func _set_home_ready(on: bool) -> void:
	if on and not _gate_was_ready and _gate_ready_seen:
		Audio.play("quest_complete", -2.0)
	_gate_was_ready = on
	_gate_ready_seen = true
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

# A quest is "ready" (deliverable) when its single asked item is on the board RIGHT NOW — the SAME
# notion the giver ✓/bob read (BoardLogic.quest_payable). Quests are endless; none are ever inert.
func _quest_ready(qi: int) -> bool:
	if qi < 0 or qi >= quests.size():
		return false
	return BoardLogic.quest_payable(board, quests[qi])

# Reorder quest indices so DELIVERABLE quests sit at the FRONT of the fence (a stable partition — see
# Quests.ready_first). Display-only: the persisted `quests` array (whose order drives refill RNG, due_gen
# and giver assignment) is untouched. A no-op when the assist flag is off.
func _ready_first_order(idx: Array) -> Array:
	if not Features.on("quest_ready_front"):
		return idx
	var ready: Array = []
	for qi in idx:
		ready.append(_quest_ready(int(qi)))
	return Quests.ready_first(idx, ready)

# Live reorder of the rendered giver cards to match _ready_first_order, run on the refresh beat so a quest
# going deliverable (via a merge) floats to the front WITHOUT a full rebuild. Moves the existing card nodes
# (FX/bust state intact). Reads each card's `ready` flag
# stamped by _refresh_giver_lights. No-op when the flag is off, the row is gone, or the order is unchanged.
func _reorder_giver_row() -> void:
	if not Features.on("quest_ready_front"):
		return
	if _giver_row == null or not is_instance_valid(_giver_row) or giver_chips.is_empty():
		return
	# Desired order = ready-first, then by original quest index within each group — IDENTICAL to what a
	# fresh _rebuild_givers produces, so the live order is self-correcting: a card that loses readiness
	# settles back into its resting (quest-index) slot rather than drifting at the front.
	var by_qi: Array = giver_chips.duplicate()
	by_qi.sort_custom(func(a, b): return int(a.get("qi", -1)) < int(b.get("qi", -1)))
	var ready: Array = []
	for e in by_qi:
		ready.append(bool(e.get("ready", false)))
	var order: Array = Quests.ready_first(by_qi, ready)
	var changed := false
	for i in range(order.size()):
		if int(order[i].get("qi", -1)) != int(giver_chips[i].get("qi", -1)):
			changed = true
			break
	if not changed:
		return
	var base := _giver_row.get_child_count() - giver_chips.size()   # any leading non-card children stay ahead
	for k in range(order.size()):
		var chip: Control = order[k].chip
		if is_instance_valid(chip):
			_giver_row.move_child(chip, base + k)
	giver_chips = order

func _rebuild_givers() -> void:
	for c in giver_bar.get_children():
		c.queue_free()
	giver_chips.clear()
	_giver_row = null
	_refill_quests()                          # §7: size the live fence to the meter before rendering
	var qidx := _ready_first_order(_active_quest_idx())   # deliverable quests render at the FRONT of the fence
	var stands := qidx.size()
	_update_unlock_bar()                      # the level-progress strip lives above the fence now, not in it
	# the fence renders only while quests remain — level progress moved to the NEXT UNLOCK strip.
	if stands == 0:
		return
	# (the full-width fence "wall" paper strip is retired — the cards stand on their own)
	# Cards are a FIXED size (proportional to the band height, so the art never distorts) packed LEFT to
	# right inside a horizontal ScrollContainer, one per metered quest. When the cards FIT the screen they
	# sit left-aligned with spare width on the right
	# (no scroll, as before). When they OVERFLOW a narrow screen the row scrolls horizontally and the next
	# card is left half-visible — the peek that signals "more to the right". Vertical scroll is off, so the
	# busts (which sit within the band height) are never clipped.
	var stand_w := STAND_W_PER_FENCE * _fence_h
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 0.0                                                  # extend the scroll viewport to BOTH screen edges so the cards stay visible right up to the left and right edges as the row scrolls
	scroll.offset_right = 0.0
	# A ScrollContainer ALWAYS clips its children, and the card's shared shadow casts below the card —
	# extend the viewport past the band's bottom edge by the shadow's reach so the cast isn't sliced flat.
	scroll.offset_bottom = Look.shadow_bottom_reach()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER   # drag-scrollable; the scrollbar itself stays hidden
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED       # the band never scrolls vertically (busts stay un-clipped)
	giver_bar.add_child(scroll)
	giver_bar.move_child(scroll, 0)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE   # transparent: a card-touch (PASS) must propagate THROUGH the row to the ScrollContainer — a STOP row (the default) would block the drag and only the gaps would scroll
	row.size_flags_vertical = Control.SIZE_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN   # left-aligned: spare width falls on the right when it all fits
	row.add_theme_constant_override("separation", int(float(_giver_lay().get("gap", QUEST_GAP))))   # workbench-tuned card gap
	scroll.add_child(row)
	_giver_row = row
	var quest_slots := mini(int(G.MAX_GIVERS), qidx.size())
	for k in range(quest_slots):
		var qi: int = qidx[k]
		var stand := _make_giver_stand(qi, quests[qi], stand_w)
		row.add_child(stand.chip)
		giver_chips.append(stand)
	_refresh_giver_lights()

# The NEXT UNLOCK strip shows whenever the zone arc still runs (the same gate the old Purge jar
# used) — ALWAYS, not only once affordable — advertising progress toward the next level unlock.
func _show_unlock_bar() -> bool:
	return Quests.purge_state(_earned()).show

func _purge_progress() -> float:
	return Quests.purge_progress(_earned())

# The strip's height scales with the screen like the rest of the HUD (mock ≈ 10% of width),
# clamped so a wide/landscape viewport doesn't balloon it.
func _unlock_bar_h_px() -> float:
	return clampf(roundf(_view_size().x * UNLOCK_BAR_H_FRAC), 84.0, 132.0)

# Pin the strip full-width under the HUD pills (same side margins as the board / bottom bar).
func _place_unlock_bar(bar_h: float) -> void:
	# the strip lives IN the content stack now (first row, QUEST_SIDE margins via its slot) — only its
	# HEIGHT is set here; the stack's top edge is the one absolute anchor for the whole page column.
	if _unlock_bar == null or not is_instance_valid(_unlock_bar):
		return
	_unlock_bar.custom_minimum_size = Vector2(0, bar_h)
	# explicit pre-layout size so the strip lays out its face immediately (first frame + headless
	# builds, where the container's layout pass hasn't run yet); the slot overrides it on layout.
	_unlock_bar.size = Vector2(maxf(1.0, _view_size().x - QUEST_SIDE * 2.0), bar_h)

# The NEXT UNLOCK strip (mock: ui_redesign_direction_b/board_next_unlock_v1) — replaces the fence
# jar. Fills toward the next level threshold on the coin clock; tapped, it goes HOME to restore
# regions (the jar's tap), and it breathes + turns gold once the next unlock is affordable.
func _build_unlock_bar() -> void:
	_unlock_bar = UnlockBar.new()
	_unlock_bar.name = "NextUnlockBar"
	_unlock_bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# the strip is the FIRST ROW of the content stack — strip → quest fence → board flow RELATIVE to
	# each other; only the stack's top edge is absolute (anchored below the HUD pills / level badge).
	var slot := MarginContainer.new()
	slot.name = "UnlockBarSlot"
	slot.add_theme_constant_override("margin_left", int(QUEST_SIDE))
	slot.add_theme_constant_override("margin_right", int(QUEST_SIDE))
	slot.add_child(_unlock_bar)
	_stack.add_child(slot)
	_stack.move_child(slot, 0)
	_place_unlock_bar(_unlock_bar_h_px())
	var unlock_go := func() -> void:
		Audio.play("button_tap", -2.0)
		_persist()
		SceneWarm.go(get_tree(), "res://engine/scenes/Map.tscn")
	_stand_tap(_unlock_bar, unlock_go)
	_update_unlock_bar()
	if _gate_ready():
		FX.breathe_once(_unlock_bar)

# Refresh the strip's static face (visibility / next level / ready tint) + snap the fill.
func _update_unlock_bar() -> void:
	if _unlock_bar == null or not is_instance_valid(_unlock_bar):
		return
	_unlock_bar.visible = _show_unlock_bar()
	_unlock_bar.set_next_level(G.level_at_coins(_earned()) + 1)
	_unlock_bar.set_ready(_gate_ready())
	_unlock_bar.set_progress(_purge_progress())

func _animate_unlock_bar_from(previous_progress: float) -> void:
	if _unlock_bar == null or not is_instance_valid(_unlock_bar):
		return
	var now := _purge_progress()
	_unlock_bar.visible = _show_unlock_bar()
	_unlock_bar.set_next_level(G.level_at_coins(_earned()) + 1)
	_unlock_bar.set_ready(_gate_ready())
	_unlock_bar.set_progress(previous_progress)
	_unlock_bar.animate_progress_to(now)
	if now >= 1.0:
		FX.breathe_once(_unlock_bar)

func debug_add_progress(amount: int = 5) -> void:
	var before_purge := _purge_progress()
	G.earn_coins(amount)                  # organic — advances the coin clock like real play
	if is_inside_tree():
		_rebuild_givers()
		_refresh_locked_cells()
		_update_hud()
	_animate_unlock_bar_from(before_purge)

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
				action.call()
				stand.accept_event())   # consume a registered tap so it never ALSO fires an ancestor's tap (ask-icon → card deliver); a drag (moved > 24) skips this branch, so the ScrollContainer still gets it

# Build one quest-giver stand. Wave 3: the construction lives in ui/giver_stand.gd;
# the coordinator still owns the quests + delivery and wires the stand's taps back.
func _make_giver_stand(qi: int, q: Dictionary, stand_w: float = STAND_W) -> Dictionary:
	var cfg := {
		"ask_tap": _open_ladder,        # an ask icon tapped while NOT ready -> open its tier ladder
		"item_tap": _on_item_tap,       # an ask icon tapped -> claim if ready, else open the ladder (#3)
		"stand_tap": _on_giver_tap,     # the stand tapped -> try to deliver
		"wire_tap": _stand_tap,         # still-release tap (also resets the idle hint)
		"stand_w": stand_w, "fence_h": _fence_h,
		"map_idx": _quest_map(),        # the giver portrait pool is themed per map (map 0 = original cast)
	}
	# the giver-card LAYOUT is tuned in the UI workbench and SAVED to its config (the quest_card block);
	# read it the SAME way every other element does — soft-load the game-tool kit (engine → game bridge).
	# Absent kit / empty block → GiverStand falls back to its baked-in LAY, so nothing changes until saved.
	cfg["lay"] = _giver_lay()
	return GiverStand.make(qi, q, cfg)

# The resolved giver-card layout: GiverStand's baked defaults with the workbench config (the quest_card
# block) merged over them. Absent kit → the bare GiverStand.LAY defaults.
func _giver_lay() -> Dictionary:
	var L: Dictionary = GiverStand.LAY.duplicate()
	var Kit: GDScript = KIT
	if Kit != null:
		var over: Dictionary = Kit.giver_lay_from_config(Kit.load_config(Kit.CONFIG_PATH))
		for k in over:
			L[k] = over[k]
	return L


# Drag drop-target affordance for the bottom-nav Bag well. Selling moved to the info-bar trashcan, so
# dragging a piece now only advertises stash when the bag has room.
func _show_drag_targets() -> void:
	_highlight_bag_target()

func _hide_drag_targets() -> void:
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
		Strings.t("board.hints.sell_spares"), CREAM, FS.BODY)

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
		e["ready"] = lit                        # deliverable → floats to the front of the fence (see _reorder_giver_row)
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
		var chip: Control = e.chip
		if lit:
			FX.breathe_once(chip)
	_reorder_giver_row()                          # float any now-deliverable card to the front (display-only)
	_refresh_quest_ready_marks()                  # board-side twin: glow every board tile a live quest wants
	_refresh_generator_dim()                      # quest-unused generators fade — re-read on the same beat
	_refresh_item_line_dim()                      # ...and quest-unused LINE items grey out on the same beat

# The asked item codes (line*100+tier) the live fence currently wants, as a set. The fence is endless,
# so this always reflects the current asks — the glow and the tap-to-deliver track them directly.
func _asked_codes() -> Dictionary:
	var out := {}
	for q in quests:
		var it := G.quest_item(q)
		if not it.is_empty():
			out[int(it.line) * 100 + int(it.tier)] = true
	return out

# The index of the first live quest asking for `code` (the leftmost giver in fence order), or -1 when
# nothing wants it. Drives the board-side second-tap: a focused, glowing tile delivers here.
func _quest_for_code(code: int) -> int:
	for i in quests.size():
		var it := G.quest_item(quests[i])
		if not it.is_empty() and int(it.line) * 100 + int(it.tier) == code:
			return i
	return -1

# The giver card wired to quest qi, so a board-side delivery flies the item to the RIGHT giver and pays
# its reward there. Null when qi has no live card (e.g. mid-rebuild).
func _chip_for_qi(qi: int) -> Control:
	for e in giver_chips:
		if int(e.get("qi", -1)) == qi:
			return e.chip
	return null

# Quest-ready glow: every board tile a live quest wants wears a soft gold halo + gentle breathe (the
# board-side twin of the giver ✓/bob). Diffs the asked-codes set against the live piece nodes — adds a
# glow to a newly-wanted tile, clears it from one no longer wanted. Idempotent; runs on the SAME beat as
# the giver lights (every board/quest change), so it tracks merges, deliveries, refills, and inert flips.
func _refresh_quest_ready_marks() -> void:
	if not Features.on("quest_ready_glow"):
		return
	var wanted := _asked_codes()
	for cell in piece_nodes:
		var node: Control = piece_nodes[cell]
		if node == null or not is_instance_valid(node):
			continue
		var glow: Control = node.get_node_or_null("ReadyGlow")
		# the item's own sprite (absent on un-arted placeholder discs) — breathed alongside the halo so the
		# WHOLE tile pulses like a generator (FX.breathe on its holder), not just the glow ring behind it.
		# Kept on the SPRITE, not the holder: the holder is the drag-telegraph's breathe node, and two
		# breathe tweens on one node collide. FX.breathe / breathe_stop are null-safe, so a sprite-less
		# placeholder simply keeps the halo-only pulse.
		var art: Control = node.get_node_or_null(PieceView.ART_NAME)
		if wanted.has(board.item_at(cell)):
			if glow == null:
				var g := PieceView.add_ready_glow(node, csz, _ready_glow_opts)
				if g != null:
					# The paper face stays fixed inside its cell; only the item art pulses.
					# Scaling the overlay can otherwise bridge the deliberate board gutters.
					FX.breathe(art)
		elif glow != null:
			FX.breathe_stop(glow)
			FX.breathe_stop(art)
			glow.queue_free()

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
	# the LINES the open fence NEEDS — each asked line plus a merged line's recipe base lines
	# (G.quest_needed_lines). A line-producing generator no quest needs fades out (GEN_UNUSED).
	# Empty set (the rare no-quest window) → nothing fades; accumulators are exempt.
	var asked_lines := G.quest_needed_lines(_open_quest_lines())
	for cell in gen_nodes:
		var gn: Control = gen_nodes[cell]
		if gn == null or not is_instance_valid(gn):
			continue
		var gid := String(board.gens.get(cell, ""))
		var unused := not asked_lines.is_empty() and gid != "" and not G.is_accumulator(gid) \
			and not asked_lines.has(int(G.gen_def(G.GENERATORS, gid).get("line", 0)))
		gn.modulate = GEN_UNUSED if unused else m
	# gen_node ALIASES the first entry of gen_nodes (see _rebuild_all) — writing it here again would
	# stomp the quest fade the loop just applied. Only a standalone legacy node still takes the plain m.
	if gen_node != null and is_instance_valid(gen_node) and not gen_nodes.values().has(gen_node):
		gen_node.modulate = m

# The items' twin of the generator fade above: GREY OUT every base-line piece whose line no open
# quest asks for, restore the rest. Coins / special drops (chest · water · acorn) / treats are
# collectibles, not quest lines — always full colour. Empty asked set (the rare no-quest window)
# greys nothing. Runs on the same beat as the ready marks (every board/quest change).
func _refresh_item_line_dim() -> void:
	if board == null:
		return
	# asked lines EXPANDED with each merged line's recipe base lines — the ingredients stay lit
	var asked_lines := G.quest_needed_lines(_open_quest_lines())
	for cell in piece_nodes:
		var node: Control = piece_nodes[cell]
		if node == null or not is_instance_valid(node):
			continue
		var code := board.item_at(cell)
		if code <= 0:
			continue
		var line := BoardModel.line_of(code)
		var quest_line := not G.is_coin(code) and not G.SPECIAL_ITEMS.has(line) and not G.is_treat_line(code)
		var unused := not asked_lines.is_empty() and quest_line and not asked_lines.has(line)
		node.modulate = ITEM_UNUSED if unused else Color(1, 1, 1, 1)

# §6 boost indicator — the on-board "this generator is boosted" marker. While a boost is live, every
# generator wears a sparkle overlay (reused gen_sparkle) + a small corner badge counting the taps left;
# both are cleared the moment the boost expires. Rebuilt by _rebuild_all and refreshed on each pop.
func _refresh_boost_indicator() -> void:
	for cell in gen_nodes:
		var live := board.is_gen_boosted(cell)   # §6: each generator lights from its OWN boost
		var taps := board.gen_boost_at(cell)
		var gn: Control = gen_nodes[cell]
		if gn == null or not is_instance_valid(gn):
			continue
		# A bonus/treat generator already shows its OWN taps-left badge in this corner (AccBadge/TreatBadge);
		# don't stack the boost-taps badge on top — they'd overlap into an unreadable double count. The boost
		# still APPLIES to it (its collect/pop multiplies); only the corner count chrome stays the gen's own.
		var owns_badge := G.is_accumulator(board.gen_id_at(cell)) or G.is_treat_gen(board.gen_id_at(cell))
		var spk: Node = gn.get_node_or_null("BoostSparkle")
		var bdg: Node = gn.get_node_or_null("BoostBadge")
		if live:
			if spk == null:
				var s: Control = preload("res://engine/scripts/ui/gen_sparkle.gd").new()
				s.name = "BoostSparkle"
				s.size = Vector2(csz, csz)
				s.mouse_filter = Control.MOUSE_FILTER_IGNORE
				gn.add_child(s)
			if owns_badge:
				if bdg != null:
					bdg.queue_free()             # the gen's own count badge owns this corner
			else:
				if bdg == null:
					bdg = _make_boost_badge()
					gn.add_child(bdg)
				((bdg as Control).get_node("Count") as Label).text = "%d" % taps
		else:
			if spk != null:
				spk.queue_free()
			if bdg != null:
				bdg.queue_free()

# A small cream-on-green corner badge for the boost indicator — the taps left on a boosted generator.
# Sized/positioned relative to the cell; mouse-ignored so it never eats a generator tap.
func _make_boost_badge() -> Control:
	var badge := PanelContainer.new()
	badge.name = "BoostBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(csz * 0.52, -csz * 0.08)   # top-right corner of the generator
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.BTN_PRIMARY
	sb.border_color = Pal.CREAM
	sb.set_corner_radius_all(int(csz * 0.16))
	sb.set_border_width_all(2)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	Look.apply_box_shadow(sb)
	badge.add_theme_stylebox_override("panel", sb)
	var count := Label.new()
	count.name = "Count"
	count.add_theme_font_size_override("font_size", int(csz * 0.26))
	count.add_theme_color_override("font_color", Pal.CREAM)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(count)
	return badge

# --- board rendering --------------------------------------------------------------

func _cell_pos(cell: Vector2i) -> Vector2:
	var step := csz + GAP
	# landscape transposes the grid: model row drives X, model col drives Y (9 across × 7 down).
	if _landscape:
		return Vector2(cell.x * step, cell.y * step)
	return Vector2(cell.y * step, cell.x * step)

func _pos_to_cell(p: Vector2) -> Vector2i:
	var step := csz + GAP
	# inverse of _cell_pos; the returned cell is always a MODEL cell (x in 0..ROWS-1, y in 0..COLS-1).
	if _landscape:
		return Vector2i(clampi(int(p.x / step), 0, G.ROWS - 1), clampi(int(p.y / step), 0, G.COLS - 1))
	return Vector2i(clampi(int(p.y / step), 0, G.ROWS - 1), clampi(int(p.x / step), 0, G.COLS - 1))

# Find the nearest compatible merge whose enlarged cell area contains `pos`. This runs before the exact-cell
# move/swap path, so an intended merge wins near a shared edge without making any other drop target looser.
func _merge_target_at(from: Vector2i, pos: Vector2, drag_is_gen: bool) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := INF
	var candidates: Array = board.gens.keys() if drag_is_gen else piece_nodes.keys()
	for raw_target in candidates:
		var target := Vector2i(raw_target)
		if target == from:
			continue
		var compatible := false
		if drag_is_gen:
			compatible = board.is_gen(from) and board.is_gen(target) \
				and board.gen_id_at(from) == board.gen_id_at(target) \
				and board.gen_tier_at(from) == board.gen_tier_at(target) \
				and board.gen_tier_at(from) < G.GEN_TOP_TIER
		else:
			compatible = board.can_merge(from, target) \
				or _recipe_merge_code(board.item_at(from), board.item_at(target)) > 0
		if not compatible:
			continue
		var hit := Rect2(_cell_pos(target), Vector2(csz, csz)).grow(csz * MERGE_TARGET_GROW)
		if not hit.has_point(pos):
			continue
		var dist := pos.distance_squared_to(_cell_pos(target) + Vector2(csz, csz) / 2.0)
		if dist < best_dist:
			best = target
			best_dist = dist
	return best

func _rebuild_all() -> void:
	_grow_generators()                        # a staged second generator grows in once its level is reached
	_sync_accumulators()                      # §6.C place any newly-unlocked utility accumulators
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
		var gid := String(board.gens[cell])
		var gn := _make_generator(gid, ghl, board.gen_tier_at(cell))
		gn.position = _cell_pos(cell)
		board_area.add_child(gn)
		FX.breathe(gn)
		if _grown_cells.has(cell):            # a just-grown second generator — pop it in
			FX.pop(gn)
		gen_nodes[cell] = gn                  # keyed by CELL now (a gen persists; new ones arrive via gen_bag, §6)
		if G.is_accumulator(gid):             # §6.C show the banked count on a utility accumulator
			_refresh_accumulator_badge(cell)
		elif G.is_treat_gen(gid):             # §6.D show the taps-left on a temp treat generator
			var tb := _make_boost_badge()
			tb.name = "TreatBadge"
			(tb.get_node("Count") as Label).text = "%d" % int(Save.grove().get("treat_clicks", 0))
			gn.add_child(tb)
	if not _grown_cells.is_empty():
		Audio.play("level_complete", -6.0, 1.1)
		_grown_cells = []
	gen_node = gen_nodes.values()[0] if not gen_nodes.is_empty() else null
	# (the §6 burst buy pill was rebuilt here — retired T48 ahead of the UI redesign; the §6 boost
	#  coin sink stays live via _activate_gen_boost, only its on-board pill is gone)
	# PARKED (T17, backlog): the locked-generator preview ("after N spots") was retired with the
	# per-map generator redesign (the next set now arrives on map COMPLETION, not after N spots);
	# if it returns it needs redefining to show the next map's incoming generators.
	_rebuild_pieces()
	# (the board panel — mat + border in one — is the bottom layer, added by _make_board_mat above;
	# there is no separate frame overlay now that the panel carries its own border.)
	_rebuild_givers()
	_rebuild_bag()
	_refresh_generator_dim()   # §6: the freshly-built generators take their full/dimmed state
	_refresh_item_line_dim()   # ...and freshly-built pieces take their quest-line grey state
	_refresh_boost_indicator() # §6: re-light the boost sparkle + count badge if a boost is live
	_update_hud()
	if _selected_cell.x >= 0:  # the wipe above freed the focus frame — redraw it on the still-selected cell
		_show_focus(_selected_cell)
	_maybe_hand_hint()                        # FTUE: the merge / generator-tap teach follows the board

# (The §14 FTUE feature-spotlight wiring — _maybe_spotlight_chrome / _spotlight_chrome_deferred /
# _show_spotlight / _on_spotlight_done, plus the Spotlight/SpotlightOverlay preloads and the
# shop_btn/_spotlight_active members — was removed 2026-06-23 with the dormant spotlight subsystem.
# The redesign (merge + bag hand-gesture spotlights) is specced + parked:
# docs/superpowers/specs/2026-06-23-ftue-hand-gesture-spotlight-design.md.)

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
	# grows the visible item per the shared Slot-cell content_frac. The single chokepoint for every board piece.
	return PieceView.make_piece(code, size, _board_item_inset)

# The board surface is built by the SHARED Kit.board_panel (the SAME builder the workbench previews) — the
# painted rounded badge (badge_rect) or a code-drawn depth border, per the board.frame_style config — plus a
# soft drop shadow. The cells sit on its cream field. See _make_board_mat below.
var FRAME_OUT := 60.0        # how far the board panel extends OUTSIDE the cell grid. Workbench-overridable (board.frame).

# The board panel — the BOTTOM layer of the board, drawn behind the cells. The frame (painted badge or a
# code-drawn depth border) + its drop shadow are built by the SHARED Kit.board_panel, so the workbench
# preview shows the ACTUAL border. Falls back to the code-drawn planter when the kit can't load.
func _make_board_mat() -> Control:
	var Kit: GDScript = KIT
	if Kit == null:
		return PieceView.make_board_mat(_board_w(), _board_h())
	var size := Vector2(_board_w() + FRAME_OUT * 2.0, _board_h() + FRAME_OUT * 2.0)
	var panel: Control = Kit.board_panel(size, Kit.board_panel_opts_from_config(Kit.load_config(Kit.CONFIG_PATH)))
	panel.position = Vector2(-FRAME_OUT, -FRAME_OUT)
	return panel

# #7: the per-cell empty "well" — a single shared builder so both creation sites
# (full rebuild + bramble-clear) stay identical. A soft warm well with a gentle,
# low-alpha rounded outline (reads as an outline, not a hard line) and little
# inner padding, plus a faint shadow for depth.
func _make_slot(cell: Vector2i) -> Control:
	# the open empty well, built on the SHARED slot cell (Kit.slot_cell) — the SAME component the bag
	# uses, reading the SAME workbench "bag_card" style, so the board + bag wells stay in lockstep.
	var Kit: GDScript = KIT
	var opts: Dictionary = Kit.board_cell_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	opts["cell_w"] = csz
	opts["cell_h"] = csz
	# checker parity — the paper-sprite faces alternate open/open-alt so the field reads livelier
	var slot: Control = Kit.slot_cell({"state": "empty", "alt": (cell.x + cell.y) % 2 == 1}, opts)
	slot.position = _cell_pos(cell)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slot

func _rebuild_action_bar_row(row: HBoxContainer, bottom_btn_px: float, action_opts: Dictionary, bottom_bar_h: float, preserve_selection: bool) -> void:
	if row == null:
		return
	var prior_selection := _selected_cell
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	row.add_theme_constant_override("separation", ActionBar.well_gap(bottom_btn_px))
	home_btn = _home_nav_button(bottom_btn_px, action_opts)     # left: the Home tile, OUTSIDE the info tray
	row.add_child(home_btn)
	# centre: the painted cream tray, holding the selected-item info bar and nothing else. The tray is
	# sized to the SAME px box as the Home/Bag tiles beside it, so all three read as one row of equals
	# (bottom_bar_h only sets the band the row centres in).
	row.add_child(ActionBar.offset_slot( \
		ActionBar.info_tray(_build_info_bar(bottom_btn_px, action_opts, bottom_btn_px), bottom_btn_px, action_opts), \
		float(action_opts.get("info_x_frac", 0.0)), "ActionBarInfoOffset"))
	row.add_child(_build_bag_box(bottom_btn_px, action_opts))   # right: the Bag tile, OUTSIDE the info tray
	if preserve_selection and prior_selection.x >= 0 and board != null:
		if board.is_gen(prior_selection):
			_select_generator(prior_selection)
		else:
			_select_item(prior_selection)
	else:
		_clear_selection()                             # the info bar starts in its empty "tap an item" state

func _relayout_action_bar() -> void:
	if bottom_bar == null or not is_instance_valid(bottom_bar):
		return
	var sb_inset := Look.safe_bottom(self)
	var bottom_btn_px := _bottom_button_px()
	var bottom_bar_h := _bottom_bar_h_px(bottom_btn_px)
	var action_opts := ActionBar.opts()
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_right = 0.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_margin := _tray_side_margin_px()
	bottom_bar.offset_left = bar_margin
	bottom_bar.offset_right = _view_size().x - bar_margin
	bottom_bar.offset_top = -bottom_bar_h - BOTTOM_BAR_INSET - sb_inset
	bottom_bar.offset_bottom = -BOTTOM_BAR_INSET - sb_inset
	(bottom_bar as PanelContainer).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := bottom_bar.find_child("ActionBarRow", true, false) as HBoxContainer
	if row != null:
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild_action_bar_row(row, bottom_btn_px, action_opts, bottom_bar_h, true)

func _on_action_bar_viewport_resized() -> void:
	if _action_bar_relayout_queued:
		return
	_action_bar_relayout_queued = true
	_relayout_action_bar_after_resize.call_deferred()

func _relayout_action_bar_after_resize() -> void:
	_action_bar_relayout_queued = false
	if get_viewport() == null:
		return
	var sz := get_viewport_rect().size
	if sz == _last_action_bar_view_size:
		return
	_last_action_bar_view_size = sz
	_relayout_action_bar()

# The Bag well (bottom nav): tap → the full bag overlay; a board item dragged onto it stashes
# (the drop is resolved in _on_release by global-rect). bag_content shows the most-recent stashed
# item (centered, no count badge — the full total lives in the overlay).
func _make_bag_button(px: float, action_opts: Dictionary = {}) -> Button:
	var KitB: GDScript = KIT
	if KitB == null:
		# fallback: the drawn disc + swap icon (pre-sprite path, engine-only safety net). Its "bag" glyph
		# lives INSIDE bag_content (icon_wrap), so _rebuild_bag restores it on the empty state.
		_bag_well_drawn_disc = true
		var d := ActionBar.home_well(px, "bag", "nav_bag.png", _bag_count_text(), -1.0, action_opts)
		ActionBar.clear_button_frame(d)
		d.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bag_content = d.get_meta("icon_wrap") if d.has_meta("icon_wrap") else null
		bag_piece_px = float(d.get_meta("icon_px", px * 0.5))
		_bag_count_lbl = d.get_meta("count_label") if d.has_meta("count_label") else null
		d.pressed.connect(_open_bag_overlay)
		return d
	# The shared code-drawn action button (CutPaperPanel rugged edge + centered bag glyph) is the whole
	# button, over its drop shadow — the same builder the home bottom bar uses. When the bag holds items
	# the most-recent one overlays the drawn glyph (bag_content); the "x/y" count rides the tile's foot.
	# Drag-to-stash / drag-back / highlight all key off the button's global rect, unchanged.
	_bag_well_drawn_disc = false            # the code-drawn well's own centered glyph IS the empty state
	var bag_opts: Dictionary = KitB.action_button_opts_from_config(KitB.load_config(KitB.CONFIG_PATH))
	bag_opts["name"] = "BagWell"
	var b: Button = KitB.action_button("bag", Vector2(px, px), Callable(self, "_open_bag_overlay"), bag_opts)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var content := CenterContainer.new()
	content.name = "BagContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(content)
	bag_content = content
	# the stashed item overlays the tile directly (no cream backing) — sized to FILL the tile so it fully
	# covers the baked satchel (the count still rides the tile foot).
	bag_piece_px = roundf(px)
	_bag_count_lbl = _make_bag_count_label(px)
	b.add_child(_bag_count_lbl)
	_rebuild_bag()
	return b

# The "x/y" bag count riding the foot of the bag tile: cream ink over a dark outline, bottom-centred.
func _make_bag_count_label(px: float) -> Label:
	var lbl := Label.new()
	lbl.name = "BagCount"
	lbl.text = _bag_count_text()
	lbl.theme = load("res://engine/scripts/ui/ui_font.gd").make()
	lbl.add_theme_font_size_override("font_size", int(roundf(px * 0.19)))
	lbl.add_theme_color_override("font_color", Pal.CREAM)
	lbl.add_theme_color_override("font_outline_color", Pal.INK)
	lbl.add_theme_constant_override("outline_size", maxi(2, int(roundf(px * 0.03))))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.anchor_left = 0.0
	lbl.anchor_right = 1.0
	lbl.anchor_top = 0.62
	lbl.anchor_bottom = 1.0
	lbl.offset_bottom = -roundf(px * 0.06)
	return lbl

# The bottom-bar Bag cell: just the swap-icon bag well — the "x/y" count rides INSIDE the disc now
# (see _make_bag_button), so the cell matches the height of the info bar + Home disc beside it.
func _build_bag_box(px: float, action_opts: Dictionary = {}) -> Control:
	bag_btn = _make_bag_button(px, action_opts)
	return bag_btn

func _bottom_button_px() -> float:
	var frac := 0.15
	var Kit: GDScript = KIT
	if Kit != null:
		frac = float(Kit.hud_layout_opts_from_config(Kit.load_config(Kit.CONFIG_PATH)).get("button_w_frac", 0.15))
	# Bounded: a min so it stays tappable on narrow screens, a max so it (and the bar) can't balloon on
	# wide ones — capped to leave the bar within BOTTOM_BAR_MAX (button + pad).
	return clampf(roundf(_view_size().x * frac), BOTTOM_BTN_MIN, BOTTOM_BAR_MAX - BOTTOM_BAR_PAD)

func _bottom_bar_h_px(bottom_btn_px: float) -> float:
	var raw := maxf(BOTTOM_BAR_H, bottom_btn_px + BOTTOM_BAR_PAD)
	var Kit: GDScript = KIT
	if Kit != null:
		var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
		var h: Dictionary = cfg.get("hud_layout", {}) if cfg is Dictionary else {}
		if h.has("bottom_row_h_pct"):
			var frac := float(Kit.hud_layout_opts_from_config(cfg).get("bottom_row_h_frac", 0.0))
			if frac > 0.0:
				raw = maxf(bottom_btn_px, roundf(_view_size().y * frac))
	# Capped: never too short to hold the wells, never tall enough to look weird on wide screens.
	return clampf(raw, BOTTOM_BAR_MIN, BOTTOM_BAR_MAX)

func _quest_row_h_px() -> float:
	var frac := 0.13
	var Kit: GDScript = KIT
	if Kit != null:
		var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
		var h: Dictionary = cfg.get("hud_layout", {}) if cfg is Dictionary else {}
		if h.has("quest_bar_h_pct"):
			frac = float(Kit.hud_layout_opts_from_config(cfg).get("quest_bar_h_frac", frac))
	# Scale with screen HEIGHT (taller screens → taller band, absorbing spare vertical room) and clamp.
	# Cards pack to fit the WIDTH (see _rebuild_givers), so the band height no longer keys off width.
	return clampf(roundf(_view_size().y * frac), QUEST_H_MIN, QUEST_H_MAX)

func _view_size() -> Vector2:
	if is_inside_tree():
		var v := get_viewport_rect().size
		if v.x > 0.0 and v.y > 0.0:
			return v
	return Design.size()

# The Bag's "held / capacity" string, e.g. "1/6" — used both to seed the in-disc overlay and to refresh it.
func _bag_count_text() -> String:
	return "%d/%d" % [bag.size(), _bag_capacity()]

# The Home disc for the bottom bar's left edge: the shared workbench-tuned home button + the Map jump.
func _home_nav_button(px: float, action_opts: Dictionary = {}) -> Button:
	var go := func() -> void:
		Audio.play("button_tap", -2.0)
		_persist()
		SceneWarm.go(get_tree(), "res://engine/scenes/Map.tscn")
	var b: Button
	var KitH: GDScript = KIT
	if KitH != null:
		# the shared code-drawn action button (CutPaperPanel rugged edge + centered home glyph) — the
		# same builder the home bottom bar uses, so the two read identically off one source.
		var ho: Dictionary = KitH.action_button_opts_from_config(KitH.load_config(KitH.CONFIG_PATH))
		ho["name"] = "BoardHomeTile"
		b = KitH.action_button("home", Vector2(px, px), go, ho)
	else:
		b = ActionBar.home_well(px, "house", "nav_home.png", "", -1.0, action_opts)
		ActionBar.clear_button_frame(b)
		b.pressed.connect(go)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

# The center INFO BAR: [info button] [selected piece + name] [trashcan/sell]. Tapping a board item fills it
# (see _select_item); empty otherwise. The info button opens the Tiers ladder; the trashcan sells the item.
# The bar itself is the SHARED kit component (Kit.info_bar — the same one the workbench previews + tunes);
# the board just grabs its mutable sub-nodes (info ⓘ / piece box / name / sell) and drives selection state.
func _build_info_bar(px: float = 130.0, action_opts: Dictionary = {}, bar_h: float = BOTTOM_BAR_H) -> Control:
	var Kit: GDScript = KIT
	if Kit == null:
		return PanelContainer.new()   # engine-only safety net — the grove kit owns the info bar (always present in the bundled game)
	var opts: Dictionary = Kit.info_bar_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	var pill: PanelContainer = Kit.info_bar({"info_action": _on_info_pressed, "sell_action": _on_trash_pressed}, opts)
	pill.name = "ActionBarInfoBar"
	pill.custom_minimum_size.x = 1.0
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pill.add_theme_stylebox_override("panel", ActionBar.info_bar_frame(opts))
	_info_btn = pill.get_meta("info_btn")            # opens the selected item's Tiers ladder
	_info_icon = pill.get_meta("info_icon")          # the selected piece preview (filled in _select_item)
	_info_label = pill.get_meta("name_label")        # "<name> · Tier N" (or the empty prompt)
	_info_desc_label = pill.get_meta("desc_label")   # compact player-use hint under the title
	_info_trash = pill.get_meta("sell_btn")          # sells the selected item; its content shows trash + payout
	_info_trash_count = pill.get_meta("sell_count")  # the payout-amount label, set in _select_item
	_info_trash_coin = pill.get_meta("sell_coin")    # the payout currency icon slot (standard coin/acorn)
	_info_inner_px = float(pill.get_meta("inner_px", px * 0.48))   # the info-button slot scales with the bar's inner-control knob
	_info_item_icon_scale = float(pill.get_meta("item_icon_scale", 0.80)) # artwork scale as a fraction of bar height
	_info_item_px = float(pill.get_meta("item_icon_px", _info_inner_px * _info_item_icon_scale))
	_info_button_hidden = bool(pill.get_meta("hide_info_button", false))
	_capture_info_button_positions()
	_build_burst_chip(opts, _info_trash.get_parent())   # T54: the burst-upgrade chip rides the sell button's slot (generators)
	_build_buy_chip(opts, _info_trash.get_parent())     # T55: the buy-a-copy chip sits just LEFT of the sell button (items)
	return pill

func _capture_info_button_positions() -> void:
	_info_btn_selected_pos = Vector2.ZERO
	_info_btn_empty_pos = Vector2.ZERO
	if _info_btn == null or not is_instance_valid(_info_btn):
		return
	_info_btn_selected_pos = _info_btn.position
	_info_btn_empty_pos = _info_btn_selected_pos
	var slot := _info_btn.get_parent() as Control
	if slot != null:
		var slot_h := slot.size.y if slot.size.y > 0.0 else slot.custom_minimum_size.y
		var btn_h := _info_btn.size.y if _info_btn.size.y > 0.0 else _info_btn.custom_minimum_size.y
		_info_btn_empty_pos.y = (slot_h - btn_h) * 0.5

func _place_info_button(empty_state: bool) -> void:
	if _info_btn == null or not is_instance_valid(_info_btn):
		return
	_info_btn.position = _info_btn_empty_pos if empty_state else _info_btn_selected_pos

# T54 — the burst-upgrade chip (a generator's action). Built from the shared action-chip recipe.
func _build_burst_chip(opts: Dictionary, row: Control) -> void:
	var c := ActionBar.action_chip(opts, row, Strings.t("board.info.burst_label"), _on_burst_chip)
	_info_burst = c.btn
	_info_burst_sb = c.sb
	_info_burst_count = c.count
	_info_burst_coin = c.coin

# T55 — the buy-a-copy chip (a regular item's action, beside sell). Built from the shared recipe.
func _build_buy_chip(opts: Dictionary, row: Control) -> void:
	var c := ActionBar.action_chip(opts, row, Strings.t("board.info.buy_label"), _on_buy_pressed, BoxContainer.ALIGNMENT_END)
	_info_buy = c.btn
	_info_buy_sb = c.sb
	_info_buy_count = c.count
	_info_buy_coin = c.coin
	row.move_child(_info_buy, _info_trash.get_index())   # buy sits just LEFT of the sell button

# Select a board item INTO the info bar: show its piece + name, put "Tier N" in the subtitle, enable the info button, and
# show the trashcan with its sell payout (hidden for generators / raw coins — they aren't deletable here).
func _select_item(cell: Vector2i) -> void:
	var code := board.item_at(cell)
	if code <= 0:
		_clear_selection()
		return
	_selected_cell = cell
	_show_focus(cell)                          # the corner-bracket frame makes the focus visible on the board
	if _info_burst != null and is_instance_valid(_info_burst):
		_info_burst.visible = false           # the burst chip is a GENERATOR action (see _select_generator)
	_place_info_button(false)
	var tier := BoardModel.tier_of(code)
	for c in _info_icon.get_children():
		c.queue_free()
	_info_icon.add_child(PieceView.make_piece(code, _info_item_px, 0.0))
	var nm: String = tr(G.item_display_name(code))
	_info_label.text = nm
	if _info_desc_label != null and is_instance_valid(_info_desc_label):
		var tier_text := "%s %d" % [Strings.t("board.info.tier"), tier]
		var desc := _item_description_for_cell(cell, code)
		_info_desc_label.text = tier_text if desc == "" else "%s · %s" % [tier_text, desc]
		_info_desc_label.visible = true
	_info_btn.visible = not _info_button_hidden
	_info_btn.disabled = _info_button_hidden
	if board.is_gen(cell) or G.is_coin(code) or G.is_special(code):
		_info_trash.visible = false           # generators, coins, and special drops aren't deletable for coins
		if _info_buy != null and is_instance_valid(_info_buy):
			_info_buy.visible = false         # …nor buyable
	else:
		var rw := G.sell_reward(code)         # Vector2i(coins, acorns) — top tier pays the premium
		var gem := rw.y > 0
		_info_trash_count.text = "%d" % (rw.y if gem else rw.x)
		for c in _info_trash_coin.get_children():
			c.queue_free()
		var pay_icon := Look.icon("gem" if gem else "coin", _info_trash_coin.custom_minimum_size.x)
		pay_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_info_trash_coin.add_child(pay_icon)
		_info_trash.visible = true
		_refresh_buy_chip(code)               # T55: a sellable item is also BUYABLE (a copy → the board)

func _item_description_for_cell(cell: Vector2i, code: int) -> String:
	var reward := board.collect_reward_at(cell)
	if not reward.is_empty():
		var amount := int(reward.amount)
		match String(reward.kind):
			"coins":
				return "Tap again to collect %d %s." % [amount, "coin" if amount == 1 else "coins"]
			"acorn":
				return "Tap again to collect %d %s." % [amount, "acorn" if amount == 1 else "acorns"]
			"water":
				return "Tap again to collect %d water." % amount
	return G.item_description(code)

# T54 — select a GENERATOR into the info bar (after a tap pops it): its sprite + name (+ the live boost
# detail), the ⓘ ladder of what it produces, and — in the slot the sell button leaves empty — the boost
# chip. (Generators live in board.gens, not board.items, so item_at() is 0 for them; their own path.)
func _select_generator(cell: Vector2i) -> void:
	if not board.is_gen(cell):
		_clear_selection()
		return
	_selected_cell = cell
	_show_focus(cell)                          # the corner-bracket frame makes the focus visible on the board
	var gid := board.gen_id_at(cell)
	_place_info_button(false)
	for c in _info_icon.get_children():
		c.queue_free()
	var tier := board.gen_tier_at(cell)
	var prev := PieceView.make_generator(gid, _info_item_px, {}, tier)
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_icon.add_child(prev)
	_info_label.text = _gen_info_text(gid, cell)
	if _info_desc_label != null and is_instance_valid(_info_desc_label):
		var desc := G.generator_description(gid)
		if not G.gen_def(G.GENERATORS, gid).is_empty():
			var tier_text := "%s %d" % [Strings.t("board.info.tier"), tier]
			_info_desc_label.text = tier_text if desc == "" else "%s · %s" % [tier_text, desc]
			_info_desc_label.visible = true
		else:
			_info_desc_label.text = desc
			_info_desc_label.visible = desc != ""
	var entries := _gen_line_entries(gid)
	var show_info_btn := not entries.is_empty() and not _info_button_hidden
	_info_btn.visible = show_info_btn
	_info_btn.disabled = not show_info_btn     # ⓘ opens the line ladder unless empty or hidden in the workbench
	if _info_buy != null and is_instance_valid(_info_buy):
		_info_buy.visible = false             # a generator is never buyable as a copy
	# A generator is clearable when it is REDUNDANT (a higher-tier same-line sibling exists — the stranding
	# fix) or RETIRED (§6: the game will never ask its line again — G.gen_retirable). The retired case is the
	# manual path for a player who dismissed the retirement offer, so a dead tool is never stuck on the board.
	var retirable := G.gen_retirable(gid, _quest_level())
	if board.is_redundant_gen(cell) or retirable:
		# price what the BUTTON ACTUALLY DOES: a redundant generator sells for its own tier value, a retired
		# one clears the whole line (its stock too), so they read different payouts from the same source the
		# offer card uses. Showing gen_sell_coins for a retirement would advertise 2-6 coins and pay far more.
		var sell_coins := int(BoardActions.retire_preview(board, bag, int(gid.trim_prefix("gen_"))).coins) if retirable and not board.is_redundant_gen(cell) else G.gen_sell_coins(tier)
		_info_trash_count.text = "%d" % sell_coins
		for ic in _info_trash_coin.get_children():
			ic.queue_free()
		var pay_icon := Look.icon("coin", _info_trash_coin.custom_minimum_size.x)
		pay_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_info_trash_coin.add_child(pay_icon)
		_info_trash.visible = true
		if _info_burst != null and is_instance_valid(_info_burst):
			_info_burst.visible = false       # a generator you're clearing isn't boostable
	else:
		_info_trash.visible = false           # the top/only generator of a line is never sold
		if G.is_accumulator(gid) or G.is_treat_gen(gid):
			if _info_burst != null and is_instance_valid(_info_burst):
				_info_burst.visible = false
		else:
			_refresh_burst_chip()             # the boost chip (full when armable, faded while live)

# The generator's info-bar label: its name, plus — while a boost is live — the boost detail (that the
# boost is on and how many taps are left). Built here so a pop can refresh it live without rebuilding
# the whole info bar (§3 boost detail).
func _gen_info_text(gid: String, cell: Vector2i) -> String:
	var lbl := G.generator_display_name(gid)
	if G.is_treat_gen(gid):
		var clicks := int(Save.grove().get("treat_clicks", 0))
		if clicks > 0:
			lbl += " · %d taps" % clicks
	elif board.is_gen_boosted(cell):
		lbl += " · " + (Strings.t("board.info.boost_detail") % board.gen_boost_at(cell))
	return lbl

# Reset the info bar to its empty "tap an item" state.
func _clear_selection() -> void:
	_selected_cell = Vector2i(-1, -1)
	_hide_focus()
	if _info_icon != null and is_instance_valid(_info_icon):
		for c in _info_icon.get_children():
			c.queue_free()
	if _info_label != null and is_instance_valid(_info_label):
		_info_label.text = Strings.t("board.info.empty_prompt")
	if _info_desc_label != null and is_instance_valid(_info_desc_label):
		_info_desc_label.text = Strings.t("board.info.empty_bag_hint")
		_info_desc_label.visible = _info_desc_label.text != ""
	if _info_btn != null and is_instance_valid(_info_btn):
		_place_info_button(true)
		_info_btn.visible = true
		_info_btn.disabled = false
	if _info_trash != null and is_instance_valid(_info_trash):
		_info_trash.visible = false
	if _info_burst != null and is_instance_valid(_info_burst):
		_info_burst.visible = false
	if _info_buy != null and is_instance_valid(_info_buy):
		_info_buy.visible = false

# Draw the corner-bracket focus frame on `cell`. Lazily built in board_area (recreated after a
# _rebuild_all wipes it); z-lifted so the brackets sit above the resting piece they frame. The frame
# is the only on-board signal of focus — without it the tap-to-focus / tap-again-to-collect flow is
# invisible and reads as "collecting is broken".
func _show_focus(cell: Vector2i) -> void:
	if cell.x < 0 or board_area == null or not is_instance_valid(board_area):
		_hide_focus()
		return
	if _focus_ring == null or not is_instance_valid(_focus_ring):
		_focus_ring = FocusRing.new()
		_focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_focus_ring.z_index = 8                 # above resting pieces (z 0); below a lifted/dragged piece (DRAG_LIFT_Z)
		board_area.add_child(_focus_ring)
	var o := _focus_ring_opts()                  # workbench-tuned colour/proportions (or the shipped look)
	if not o.is_empty():
		_focus_ring.color = o.color
		_focus_ring.halo_color = o.halo_color
		_focus_ring.halo_a = o.halo_a
		_focus_ring.arm_frac = o.arm_frac
		_focus_ring.thick_frac = o.thick_frac
		_focus_ring.pad_frac = o.pad_frac
		_focus_ring.halo = o.halo
	_focus_ring.size = Vector2(csz, csz)
	_focus_ring.position = _cell_pos(cell)
	_focus_ring.visible = true
	_focus_ring.queue_redraw()

func _hide_focus() -> void:
	if _focus_ring != null and is_instance_valid(_focus_ring):
		_focus_ring.visible = false

# The focus-ring look, tuned in the UI workbench (→ "Focus ring") and read through the SAME Kit
# transform the workbench preview uses, so the board matches the preview 1:1. {} → the shipped defaults.
func _focus_ring_opts() -> Dictionary:
	var Kit: GDScript = KIT
	if Kit == null:
		return {}
	return Kit.focus_ring_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))

func _show_locked_cell_info(cell: Vector2i) -> void:
	_clear_selection()
	if _info_label != null and is_instance_valid(_info_label):
		_info_label.text = Strings.t("board.info.unlock_level") % maxi(1, G.cell_min_level(cell))
	if _info_desc_label != null and is_instance_valid(_info_desc_label):
		_info_desc_label.text = ""
		_info_desc_label.visible = false

# T54→boost — drive the boost chip for a selected generator. ALWAYS shown (the single booster never
# "maxes out"): full-color only when a boost can be armed right now (affordable AND none live), and
# DIMMED otherwise — broke, or a boost is already running (no re-buy mid-boost, §2).
func _refresh_burst_chip() -> void:
	if _info_burst == null or not is_instance_valid(_info_burst):
		return
	var cost := G.boost_cost()
	var free := Bucket.boost_charges() > 0           # §10: a stockpiled boost-line charge pays for the next boost
	var live := _selected_cell.x >= 0 and board.is_gen_boosted(_selected_cell)   # THIS generator already boosted
	var ready := (free or Save.coins() >= cost) and not live   # full-color only when arming one now would work
	for c in _info_burst_coin.get_children():
		c.queue_free()
	var coin := Look.icon("coin", _info_burst_coin.custom_minimum_size.x)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_burst_coin.add_child(coin)
	_info_burst_count.text = Strings.t("board.info.boost_free") if free else ("%d" % cost)
	_info_burst_sb.bg_color = Pal.BTN_PRIMARY if ready else Color(Pal.BTN_PRIMARY, 0.42)
	_info_burst_sb.border_color = Pal.BTN_PRIMARY_EDGE if ready else Color(Pal.BTN_PRIMARY_EDGE, 0.42)
	_info_burst.modulate = Color(1, 1, 1, 1.0) if ready else Color(1, 1, 1, 0.7)
	_info_burst.visible = true

# T54→boost — tap the boost chip: activate the temporary boost (the §6/§10 coin sink). A boost already
# live → soft refusal (no re-buy, §2); broke → wallet-side nudge, no spend; success → spend, light the
# on-board indicator, juice the generator, and refresh the chip to its now-faded live state.
func _on_burst_chip() -> void:
	if _selected_cell.x < 0 or not board.is_gen(_selected_cell):
		return
	if board.is_gen_boosted(_selected_cell):
		FX.wobble(_info_burst)                # this generator is already boosted — no re-buy on it
		Audio.play("invalid_soft", -4.0)
		return
	if Save.coins() < G.boost_cost():
		FX.wobble(_info_burst)
		Audio.play("invalid_soft", -4.0)
		FX.floating_text(self, _info_burst.get_global_rect().get_center() - Vector2(70, 78), Strings.t("board.info.burst_need"), CREAM, FS.BODY)
		return
	if _activate_gen_boost(_selected_cell):    # spend + arm THIS generator + persist
		Audio.play("button_tap", -2.0)
		_update_hud()                         # the coin pill ticks down
		_refresh_boost_indicator()            # the sparkle + count badge light up on every generator
		if _selected_cell.x >= 0:
			var gnode: Control = gen_nodes.get(_selected_cell)
			if gnode != null and is_instance_valid(gnode):
				FX.pop(gnode)                 # the generator bounces — its burst just grew
			var ctr := board_area.get_global_transform().origin + _cell_pos(_selected_cell) + Vector2(csz, csz) / 2.0
			FX.celebrate_at(self, ctr, Strings.t("board.feedback.bigger_bursts"), STRAW)
			if board.is_gen(_selected_cell):
				_info_label.text = _gen_info_text(board.gen_id_at(_selected_cell), _selected_cell)
		_refresh_burst_chip()                 # now faded — a boost is live

# T55 — drive the BUY chip for the selected item: its price (G.buy_price — the SPLIT ladder:
# coins at 10× sell for t1-3, Fibonacci acorns from t4), dimmed when the player can't afford it.
# Always offered for a sellable item (buying a copy you already have is "speed, not possibility", §4).
func _refresh_buy_chip(code: int) -> void:
	if _info_buy == null or not is_instance_valid(_info_buy):
		return
	var price := G.buy_price(code)
	var use_gem := price.y > 0
	var cost := price.y if use_gem else price.x
	var afford := (Save.diamonds() if use_gem else Save.coins()) >= cost
	for c in _info_buy_coin.get_children():
		c.queue_free()
	var ic := Look.icon("gem" if use_gem else "coin", _info_buy_coin.custom_minimum_size.x)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_buy_coin.add_child(ic)
	_info_buy_count.text = "%d" % cost
	_info_buy_sb.bg_color = Pal.BTN_PRIMARY if afford else Color(Pal.BTN_PRIMARY, 0.42)
	_info_buy_sb.border_color = Pal.BTN_PRIMARY_EDGE if afford else Color(Pal.BTN_PRIMARY_EDGE, 0.42)
	_info_buy.modulate = Color(1, 1, 1, 1.0) if afford else Color(1, 1, 1, 0.7)
	_info_buy.visible = true

# T55 — tap the buy chip: buy a COPY of the selected item and drop it on the board (the bag when the
# board is full). Broke or no-room → a nudge, no spend. Price is G.buy_price (always > the sell value,
# so there's no buy-low/sell-high loop). The selection stays on the original item; the copy lands elsewhere.
func _on_buy_pressed() -> void:
	if _selected_cell.x < 0:
		return
	var code := board.item_at(_selected_cell)
	if code <= 0 or board.is_gen(_selected_cell) or G.is_coin(code):
		return
	var price := G.buy_price(code)
	var use_gem := price.y > 0
	var cost := price.y if use_gem else price.x
	var have := Save.diamonds() if use_gem else Save.coins()
	if have < cost:
		FX.wobble(_info_buy)
		Audio.play("invalid_soft", -4.0)
		FX.floating_text(self, _info_buy.get_global_rect().get_center() - Vector2(70, 78), Strings.t("board.info.buy_need"), CREAM, FS.BODY)
		return
	# pick a destination first — the board's first empty (non-generator) cell, else the bag — so we never
	# spend without a place to put the copy.
	var dest := Vector2i(-1, -1)
	for c in board.empty_ground_cells():
		if not board.is_gen(c):
			dest = c
			break
	var to_bag := dest.x < 0
	if to_bag and bag.size() >= _bag_capacity():
		FX.wobble(_info_buy)                       # board AND bag are full — nowhere to land
		Audio.play("invalid_soft", -4.0)
		FX.floating_text(self, _info_buy.get_global_rect().get_center() - Vector2(70, 78), Strings.t("board.info.no_room"), CREAM, FS.BODY)
		return
	if not (Save.spend_diamonds(cost) if use_gem else Save.spend(cost, "buy_item")):
		return                                    # safety: affordability re-checked at the spend
	Audio.play("button_tap", -2.0)
	if to_bag:
		bag.append(code)
		_rebuild_bag()
		if bag_btn != null and is_instance_valid(bag_btn):
			FX.celebrate_at(self, bag_btn.get_global_rect().get_center(), Strings.t("board.feedback.bought"), STRAW)
	else:
		board.place(dest, code)
		_mark_seen(code)
		var n := _make_piece(code, csz)           # pop the copy in at its cell (no generator flight)
		n.position = _cell_pos(dest)
		n.scale = Vector2(0.3, 0.3)
		board_area.add_child(n)
		piece_nodes[dest] = n
		var t := n.create_tween()
		t.tween_property(n, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var ctr := board_area.get_global_transform().origin + _cell_pos(dest) + Vector2(csz, csz) / 2.0
		FX.celebrate_at(self, ctr, Strings.t("board.feedback.bought"), STRAW)
	_after_board_change()                         # wallet ticks down, the copy may satisfy a quest, a full board dims the gens
	_refresh_buy_chip(code)                       # re-read affordability (currency dropped)

# The info button → open the board tutorial when nothing is focused, or the selected item's Tiers
# ladder (or, for a generator, the ladder of what it produces) when something is focused.
func _on_info_pressed() -> void:
	if _selected_cell.x < 0:
		_show_board_tutorial(false)
		return
	if board.is_gen(_selected_cell):
		if not Features.on("discovery_ladder"):
			return                                # the drill-down opens tier ladders, gated by the same flag
		var entries := _gen_line_entries(board.gen_id_at(_selected_cell))
		if entries.is_empty():
			return
		# the Producing dialog lists what this generator currently makes; tapping a line drills into its ladder
		# (opened on top — closing it returns here). The dialog STAYS open behind the ladder.
		GenLines.open(self, {
			"entries": entries,
			"on_line": func(line: int) -> void: _open_ladder(line, 1),
		})
		return
	var code := board.item_at(_selected_cell)
	if code <= 0:
		return
	_open_ladder(BoardModel.line_of(code), BoardModel.tier_of(code))

func _maybe_show_board_tutorial_first_run() -> void:
	if Save.board_tutorial_seen():
		return
	_show_board_tutorial(true)

func _show_board_tutorial(mark_seen: bool) -> void:
	var overlay := TutorialImage.open(self, BOARD_TUTORIAL_OVERLAY, BOARD_TUTORIAL_IMAGE)
	if overlay != null and mark_seen:
		Save.mark_board_tutorial_seen()

# The trashcan → sell the selected item for coins (guards generators / coins / a stale selection).
func _on_trash_pressed() -> void:
	if _selected_cell.x < 0:
		return
	var cell := _selected_cell
	if board.is_gen(cell):                         # the sell button clears a REDUNDANT or a RETIRED generator
		if board.is_redundant_gen(cell):
			_sell_generator(cell)
			_clear_selection()
		elif G.gen_retirable(String(board.gen_id_at(cell)), _quest_level()):
			_retire_line(String(board.gen_id_at(cell)))    # §6: clears the generator AND its dead stock
			_clear_selection()
		return
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
		"on_open_shop": func() -> void:
			if _open_shop.is_valid():
				_open_shop.call(),
		"on_balance": func() -> int: return Save.diamonds(),
		"gen_bag": board.gen_bag,
		"gen_bag_tiers": board.gen_bag_tiers,
		"asked_lines": G.quest_needed_lines(_open_quest_lines()).keys(),   # asked + merged-recipe base lines — needed gens breathe in the bag
		"on_place_gen": func(id: String) -> void:
			var cells := board.empty_ground_cells()
			if cells.is_empty():
				Audio.play("invalid_soft", -6.0)
				return
			if not board.place_gen_from_bag(id, Vector2i(cells[0])):
				return
			_rebuild_all()
			_after_board_change(),
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

# The board backdrop — a cut-paper scene picked at random each board entry (clouds/leaves/meadow/
# autumn), so the page feels alive without stealing saturation from the items. Falls back to the
# quiet sky-grain tile, then to the flat SURFACE field, when the art is absent.
const FIELD_BACKDROPS: Array[String] = [
	"ui/board_bg/sunset_clouds.png",
	"ui/board_bg/day_meadow.png",
	"ui/board_bg/forest_leaves.png",
	"ui/board_bg/autumn_grove.png",
]

static func _field_backdrop() -> Control:
	var scene_path := Game.art(FIELD_BACKDROPS[randi() % FIELD_BACKDROPS.size()])
	if ResourceLoader.exists(scene_path):
		var art := TextureRect.new()
		art.texture = load(scene_path)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return art
	var path := Game.art("ui/meadow_v2/texture_sky.png")
	if ResourceLoader.exists(path):
		var bg := TextureRect.new()
		bg.texture = load(path)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_TILE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return bg
	var c := ColorRect.new()
	c.color = Pal.SURFACE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

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

func _make_generator(id: String, hl: Dictionary = {}, tier: int = 1) -> Control:
	return PieceView.make_generator(String(id), csz, hl, tier)

# The GEN-highlight (glow / silhouette outline / sparkle) tuning saved in the UI workbench
# ("generator" block). Absent file/keys → {} → make_generator falls back to its shipped GEN_* consts.
func _gen_highlight_opts() -> Dictionary:
	var Kit: GDScript = KIT
	if Kit == null:
		return {}
	return Kit.gen_highlight_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))

# --- input ---------------------------------------------------------------------

func _on_board_input(event: InputEvent) -> void:
	_idle = 0.0
	if animating:
		if Debug.on() and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)):
			print("[collect] board tap IGNORED — animating gate is true (a merge/anim never cleared it)")
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event is InputEventScreenTouch
	if pressed and event.pressed:
		# emulate_touch_from_mouse delivers BOTH a mouse-button AND a synthesized touch event per click, so
		# one physical press fires here twice. Without this guard the 2nd press re-runs _on_press, which
		# clears the focus the 1st captured — so a collect-on-second-tap reads _press_was_selected=false and
		# merely re-focuses the coin instead of collecting. Process ONE gesture once.
		if _pressing:
			return
		_pressing = true
		_on_press(event.position)
	elif pressed and not event.pressed:
		if not _pressing:
			return                              # ignore the paired duplicate release
		_pressing = false
		_on_release(event.position)
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and (_drag_node != null or _drag_pending):
		# ARMED but not yet lifted: stay a tap until the pointer crosses the slop, then begin the drag
		if _drag_node == null:
			if event.position.distance_to(_press_pos) <= _drag_slop_px():
				return
			_begin_drag()
			if _drag_node == null:
				return
		_drag_follow(event.position)

# The per-update drag FOLLOW (Bundle A tactile): seat the held tile under the pointer, then layer the
# two felt cues — the merge-target TELEGRAPH (glow + breathe + magnet on a valid target) and the held
# tile's LEAN into pointer velocity. A generator drag gets the plain follow only (it never merges, and
# its own lift pose owns its look). Both cues tear down cleanly on release / snap-back (_clear_drag_feel).
func _drag_follow(pos: Vector2) -> void:
	_drag_node.position = pos - Vector2(csz, csz) / 2.0
	if _drag_is_gen:
		return
	_update_telegraph(pos)
	_update_drag_lean(pos)

# Resolve the cell the held tile hovers; if it's a NEW valid merge target, telegraph it (glow + breathe +
# magnet the pair together) and pull the held tile a touch toward it. Moving off a telegraphed target (to a
# non-mergeable cell or a different one) restores the old target first. Mirrors the Bag-highlight idiom
# (DRAG_HILITE + breathe_once / breathe_stop).
func _update_telegraph(pos: Vector2) -> void:
	var target := _merge_target_at(_drag_from, pos, false)
	var valid := target.x >= 0 and piece_nodes.has(target)
	if not valid:
		_clear_telegraph()
		return
	if target == _telegraph_cell:
		# still hovering the same target — keep the held tile leaning toward it (the follow re-seated it).
		_apply_drag_magnet(target)
		return
	_clear_telegraph()                       # moved onto a new valid target — drop the previous glow first
	var tnode: Control = piece_nodes.get(target)
	if tnode == null or not is_instance_valid(tnode):
		return
	_telegraph_cell = target
	_telegraph_node = tnode
	_telegraph_rest = _cell_pos(target)
	tnode.modulate = FX.Tune.TELEGRAPH_GLOW
	# pull the TARGET toward the held tile (the magnet's other half) — a small, steady lean toward the pair centre.
	tnode.position = _telegraph_rest + (_drag_node.position - tnode.position).normalized() * (FX.Tune.TELEGRAPH_MAGNET * csz)
	FX.breathe_once(tnode)
	_apply_drag_magnet(target)

# Pull the HELD tile a fraction of a cell toward the telegraphed target (the magnet, held-tile half). Layered
# ON TOP of the pointer-seated position each follow so it reads as a tug, never a teleport.
func _apply_drag_magnet(target: Vector2i) -> void:
	if _drag_node == null:
		return
	var tcenter := _cell_pos(target)
	var hcenter := _drag_node.position
	_drag_node.position += (tcenter - hcenter).normalized() * (FX.Tune.TELEGRAPH_MAGNET * csz)

# Restore the currently-telegraphed target (modulate + magnet offset + breathe) and forget it. Safe when
# nothing is telegraphed (no-op). The single teardown both the hover-exit and the drag-end call.
func _clear_telegraph() -> void:
	if _telegraph_node != null and is_instance_valid(_telegraph_node):
		FX.breathe_stop(_telegraph_node)
		_telegraph_node.modulate = Color(1, 1, 1, 1.0)
		_telegraph_node.position = _telegraph_rest
	_telegraph_node = null
	_telegraph_cell = Vector2i(-1, -1)
	_telegraph_rest = Vector2.ZERO

# Tilt the held tile INTO pointer velocity, lagged: the lean target is DRAG_LEAN_DEG scaled by the
# normalized horizontal speed of this update, sign following travel direction; we lerp the live lean toward
# it by DRAG_LEAN_LAG (so it trails the motion) and ease toward upright when the pointer is still. Clamped to
# ±DRAG_LEAN_DEG.
func _update_drag_lean(pos: Vector2) -> void:
	if not _drag_lean_seeded:
		_drag_last_pos = pos
		_drag_lean_seeded = true
	var dx := pos.x - _drag_last_pos.x
	_drag_last_pos = pos
	var max_rad := deg_to_rad(FX.Tune.DRAG_LEAN_DEG)
	# a px-per-update delta -> a -1..1 factor (DRAG_LEAN_VEL_REF px reaches full lean), signed by direction.
	var target_lean := clampf(dx / FX.Tune.DRAG_LEAN_VEL_REF, -1.0, 1.0) * max_rad
	_drag_lean = lerpf(_drag_lean, target_lean, FX.Tune.DRAG_LEAN_LAG)
	_drag_node.pivot_offset = _drag_node.size / 2.0 if _drag_node.size.x > 0.0 else _drag_node.custom_minimum_size / 2.0
	_drag_node.rotation = clampf(_drag_lean, -max_rad, max_rad)

# Tear down ALL drag feel (telegraph glow/magnet + held-tile lean) and reset the lean tracker. Called from
# every drag-end path (release, snap-back, stash, gen release) so no glow or rotation can leak past a drop.
func _clear_drag_feel(node: Control = null) -> void:
	_clear_telegraph()
	_drag_lean = 0.0
	_drag_lean_seeded = false
	_drag_last_pos = Vector2.ZERO
	if node != null and is_instance_valid(node):
		node.rotation = 0.0
		GrabFx.release(node)   # drop the grab glow + white rim (the shared drag-end chokepoint)

# Mobile TOUCH SLOP: a press only ARMS a drag — the tile does not lift until the pointer travels
# past this distance. Within it, the gesture stays a TAP (select · inspect · collect · deliver), so
# a wobbly finger can no longer turn a quest delivery or an inspect into an accidental drag.
func _drag_slop_px() -> float:
	return maxf(24.0, csz * 0.22)

func _on_press(pos: Vector2) -> void:
	var cell := _pos_to_cell(pos)
	_press_cell = cell
	_press_pos = pos
	_press_was_selected = (_selected_cell == cell)   # remember focus BEFORE clearing — a collectable collects only on a tap of its already-focused cell
	if _selected_cell.x >= 0:
		_clear_selection()                    # a new board touch resets the info bar (a still tap re-selects)
	_drag_is_gen = board.is_gen(cell)
	_drag_pending = false
	if _drag_is_gen or board.item_at(cell) > 0:   # a generator is a movable piece too (§2/T17)
		_drag_from = cell
		_drag_pending = true                  # ARMED — the lift waits for the slop (see _drag_slop_px)

# The pointer crossed the slop (or a tool asked for the grab directly): NOW the tile lifts —
# scale + z-pop + lifted shadow + grab fx + pickup tap, exactly the old press-time feel.
func _begin_drag() -> void:
	_drag_pending = false
	var cell := _drag_from
	_drag_node = gen_nodes.get(cell) if _drag_is_gen else piece_nodes.get(cell)
	if _drag_node == null:
		return
	_drag_node.z_index = DRAG_LIFT_Z   # above the FTUE hand-hint veil too — a piece being dragged must not dim
	_drag_node.scale = Vector2(1.12, 1.12)
	PieceView.set_lifted(_drag_node, true)    # spread the shadow — the tile lifts off
	GrabFx.grab(_drag_node, _grab_opts)       # glow + white rim + a light pickup tap (workbench-tuned)
	Audio.play("item_pickup", -6.0)
	if not _drag_is_gen:
		_show_drag_targets()   # light the Bag drop target when it can accept a stashed piece

func _on_release(pos: Vector2) -> void:
	if _drag_pending:
		# the pointer never crossed the slop — a pure TAP. Resolve the node QUIETLY (no lift fx,
		# no pickup sound) and fall through: the still-tap branch below owns select/collect/deliver.
		_drag_pending = false
		_drag_node = gen_nodes.get(_drag_from) if _drag_is_gen else piece_nodes.get(_drag_from)
	if _drag_is_gen:
		_release_gen(pos)
		return
	if _drag_node == null:
		var tap := _pos_to_cell(pos)
		if tap == _press_cell and board.is_bramble(tap):
			_show_locked_cell_info(tap)
		return
	var target := _pos_to_cell(pos)
	var from := _drag_from
	if pos.distance_to(_press_pos) > _drag_slop_px():
		var merge_target := _merge_target_at(from, pos, false)
		if merge_target.x >= 0:
			target = merge_target
	var node := _drag_node
	_drag_node = null
	_drag_from = Vector2i(-1, -1)
	node.z_index = 0
	node.scale = Vector2.ONE
	PieceView.set_lifted(node, false)   # back to the tight resting shadow
	_clear_drag_feel(node)   # drop the merge-target telegraph + the held tile's lean (no stuck glow/rotation)
	_hide_drag_targets()   # drag ended — settle the Bag back to rest
	# the bag is a drop target too (global-rect check)
	var gp: Vector2 = board_area.get_global_transform() * pos
	if bag_btn != null and is_instance_valid(bag_btn) and bag_btn.get_global_rect().has_point(gp):
		_stash(from, node)
		return
	var from_code := board.item_at(from)
	var target_code := board.item_at(target)
	if Debug.on() and G.is_collectable(from_code):
		print("[collect] still-tap on collectable %d at %s — was_focused=%s dist=%.1f → %s" % [
			from_code, str(from), str(_press_was_selected), pos.distance_to(_press_pos),
			("COLLECT" if (target == from and from_code > 0 and pos.distance_to(_press_pos) <= _drag_slop_px() and _press_was_selected) else "select/snap-back")])
	if target == from and from_code > 0 and pos.distance_to(_press_pos) <= _drag_slop_px():
		# A still tap selects first. Collectables (coins + §6.B resource drops) collect only
		# on a second tap of the already-focused cell, so dragging never pockets them.
		if G.is_collectable(from_code) and _press_was_selected:
			if G.is_coin(from_code):
				_collect_coin(from, node)
			elif G.is_chest(from_code):
				_open_chest(from, node)    # §6.B second tap OPENS the chest (the key line is retired)
			else:
				_collect_special(from, node)
		elif _press_was_selected and Features.on("quest_ready_glow") and _quest_for_code(from_code) >= 0:
			_deliver_from_board(from)         # second tap of an already-focused, glowing tile → consume it + complete the quest
		elif _press_was_selected and board.collect_reward_at(from).is_empty():
			if node != null and is_instance_valid(node):
				node.position = _cell_pos(from)
			_select_item(from)
			_open_ladder(BoardModel.line_of(from_code), BoardModel.tier_of(from_code))
		else:
			_snap_back(from, node)
			_select_item(from)
	elif board.can_merge(from, target):
		_commit_merge(from, target, node)
	elif _recipe_merge_code(from_code, target_code) > 0:
		_apply_recipe(from, target, node)   # #14: two DIFFERENT base lines at the same tier craft a SPECIAL
	elif board.is_empty_ground(target) and target != from:
		_commit_move(from, target, node)
	elif Features.on("drag_swap") and target != from \
			and board.is_gen(target) and board.swap_gen_with_item(target, from):
		Audio.play("item_drop", -4.0)
		_rebuild_all()
		_after_board_change()
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
	if pos.distance_to(_press_pos) > _drag_slop_px():
		var merge_target := _merge_target_at(from, pos, true)
		if merge_target.x >= 0:
			target = merge_target
	var node := _drag_node
	_drag_node = null
	_drag_from = Vector2i(-1, -1)
	if node != null:
		node.z_index = 0
		node.scale = Vector2.ONE
		PieceView.set_lifted(node, false)   # back to the tight resting shadow
	_clear_drag_feel(node)   # reset the lean tracker (a gen never telegraphs, but never leak a residual tilt)
	if target == from and pos.distance_to(_press_pos) <= _drag_slop_px():
		if node != null:
			node.position = _cell_pos(from)
		if G.is_accumulator(board.gen_id_at(from)):
			_collect_accumulator(from)        # §6.C an accumulator banks a resource — a tap collects it
			if board.is_gen(from):
				_select_generator(from)
		elif G.is_treat_gen(board.gen_id_at(from)):
			_pop_treat(from)                  # §6.D a temp treat generator — a tap pops a premium burst
			if board.is_gen(from):
				_select_generator(from)
		else:
			_pop_seed(from)                   # a still tap pops the generator (merge fuel)
			_end_hand_hint("gen_tap")   # FTUE: a real generator tap ends (or pre-empts) the tap teach
			_select_generator(from)           # …and surfaces the burst-upgrade chip in the info bar (T54)
		return
	var gp: Vector2 = board_area.get_global_transform() * pos
	if bag_btn != null and is_instance_valid(bag_btn) and bag_btn.get_global_rect().has_point(gp):
		if board.store_gen(from):
			_rebuild_all()
			_after_board_change()
			FX.celebrate_at(self, bag_btn.get_global_rect().get_center(), Strings.t("board.feedback.stored"), STRAW)
		elif node != null:
			_snap_back(from, node)
		return
	if target != from and board.is_empty_ground(target) and board.move_gen(from, target):
		Audio.play("item_drop", -3.0)
		_rebuild_all()                        # #1 move (generators are movable-only; new ones arrive via near-end reward → gen_bag)
		_after_board_change()
		return
	if target != from and board.is_gen(target) and board.merge_gens(from, target):   # #8: same-line generators merge → a stronger tier (frees the source cell)
		Audio.play("item_drop", -2.0)
		_rebuild_all()
		_after_board_change()
		return
	if Features.on("drag_swap") and target != from \
			and board.item_at(target) > 0 and not board.is_gen(target) \
			and board.swap_gen_with_item(from, target):
		Audio.play("item_drop", -4.0)
		_rebuild_all()
		_after_board_change()
		return
	if Features.on("drag_swap") and target != from and board.is_gen(target) and board.swap_gens(from, target):
		Audio.play("item_drop", -4.0)
		_rebuild_all()
		_after_board_change()
		return
	if node != null:
		_snap_back(from, node)                # occupied / bramble / different-line generator — refuse

func _snap_back(from: Vector2i, node: Control) -> void:
	var t := node.create_tween()
	t.tween_property(node, "position", _cell_pos(from), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("invalid_soft", -8.0)

# --- actions ---------------------------------------------------------------------

# The live giver quests (the §7 fence stands currently asking). A per-line generator pops only its OWN line
# (narrowed in _pop_seed), so there is no shared windowed pool any more — _pop_seed derives the tapped line's
# `wanted` flag from these for the §6 tier bias. Returns {giver_quests}.
func _pop_pool_ctx() -> Dictionary:
	var giver_quests: Array = []
	for e in giver_chips:
		if int(e.qi) >= 0 and int(e.qi) < quests.size():
			giver_quests.append(quests[int(e.qi)])
	return {"giver_quests": giver_quests}

func _pop_seed(cell: Vector2i = Vector2i(-1, -1)) -> void:
	if cell.x < 0:                            # default: the first live generator (tests / FTUE / no-arg)
		if board.gens.is_empty():
			return
		cell = board.gens.keys()[0]
	var gnode: Control = gen_nodes.get(cell, gen_node)
	# Tap-to-produce: when a generator is DUE (restore count or level-reached quest progress has reached
	# its base line, but the player doesn't own it — board or bag), this tap BIRTHS the new tool instead of
	# popping items. Free (no energy), preempts the pop, and self-heals missing active-line generators. See below.
	if _produce_due_generators():
		return
	var charged := _ftue_pops_done()          # once the FTUE intro pops are spent, each item costs energy
	if charged and water < G.POP_COST:
		FX.wobble(gnode)
		Audio.play("invalid_soft", -4.0)
		_update_water_hud()                # surfaces the refill offer + breathes the empty pill
		_cue_empty_water()                 # + a drifting "water refills over time" hint (once/episode)
		return
	var empties := board.empty_ground_cells()
	if empties.is_empty():
		FX.wobble(gnode)                   # full board pauses the generator for FREE
		Audio.play("invalid_soft", -4.0)
		return
	# Burst-pop (§6): one tap throws a BURST, not just one item. Its odds scale with the generator's
	# TIER (gen redesign #8 — higher tier → more multiples); a live boost swaps in the boosted per-tier
	# odds (T64 — the top tier gains a 4th burst slot). No per-map scale-up. Bound it by what's
	# affordable (energy) and what fits (open cells). Each popped item still costs G.POP_COST.
	# FTUE (§4): during the free-pop intro a tap pops EXACTLY ONE item — burst is suppressed so the
	# 10 free pops are ~10 deliberate frictionless taps (not spent 3-at-a-time) and the counter can't
	# overshoot 10 mid-burst. Burst resumes the moment the free budget is gone (`charged`).
	# (Accumulator/treat taps never reach here — their own collect/pop paths.)
	var burst := 1
	if charged:
		burst = G.gen_burst_count(board.gen_tier_at(cell), rng, board.is_gen_boosted(cell))
	if charged:
		burst = mini(burst, int(water / G.POP_COST))
	burst = mini(burst, empties.size())
	# the spawn decision (landing cell + code) is board_logic's; the active givers' wanted lines AND
	# poppable wanted tiers bias every item's roll (§6). Pool + wanted are fixed across the burst.
	# RNG order is load-bearing.
	# gen redesign #4: a per-line generator pops ONLY its own line (the legacy shared windowed pool is gone).
	var giver_quests: Array = _pop_pool_ctx()["giver_quests"]
	var gen_line := int(G.gen_def(G.GENERATORS, board.gen_id_at(cell)).get("line", 0))
	if gen_line <= 0:
		FX.wobble(gnode)
		Audio.play("invalid_soft", -4.0)
		return
	var pool: Array = [gen_line]
	# `wanted` = this line iff a live giver quest asks for it — it drives the §6 spawn tier-bias below.
	# roll_spawn leans ~ASK_WEIGHT toward the wanted set; with only gen_line here every spawn resolves to
	# this generator's own line (gen redesign #4 — a generator never pops another quest's line).
	var wanted: Array = BoardLogic.wanted_lines(pool, giver_quests)
	# §6 spawn tier-bias is OFF by default (G.ASK_TIER_WEIGHT = 0, owner pacing dial) — skip the dict then.
	var wanted_t: Dictionary = BoardLogic.wanted_tiers(pool, giver_quests) if G.ASK_TIER_WEIGHT > 0.0 else {}
	var g := Save.grove()
	if Audio.has("water_pop"):
		Audio.play("water_pop", -2.0)
	# W2: the spawn flight is COSMETIC and must NOT set `animating` — that flag gates the board
	# input surface, so a 0.22s flight used to EAT the next generator tap. Items are placed in
	# the model immediately; `animating` now guards MERGES only, so rapid taps each land.
	var last_piece: Control = null         # the representative projectile for Feel.launch (one emit per pop)
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
		last_piece = n
		# the grow-in 0.3 -> 1.0 scale is the generator's OWN spawn signature — runs ALONGSIDE the flight.
		var st := n.create_tween()
		st.tween_property(n, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# the position FLIGHT routes through the unified MOVE verb so the workbench-tuned shadow / trail /
		# lean show on the board's most visible tile travel (the merge snap is too brief to read them). The
		# flight FOLLOWS the workbench travel duration_ms (no override), so tuning Move speed is felt here.
		var land_ctr := _cell_pos(pick) + Vector2(csz, csz) / 2.0
		var mt := MoveFx.apply(n, _cell_pos(cell), _cell_pos(pick), "slide", _move_opts)
		if mt != null:
			# JUICE: the tile THUMPS DOWN on arrival — a quiet land (squash + dust puff, no per-seed sound;
			# the pop's water_pop/item_drop is the one shared batch sound). Grow-in = appearance, land = touchdown.
			mt.tween_callback(LandFx.apply.bind(board_area, n, land_ctr, _land_opts, 0.7, true))
	# Unified launch EMIT through the workbench-tuned LaunchFx applier (resolved once in _ready): the
	# generator recoil + a muzzle puff (toss sound stays OFF in the resolved opts — the generator keeps
	# its OWN spawn sound: water_pop above, else the item_drop fallback below). Called ONCE per pop (not
	# per burst seed) with the representative item; the muzzle puff centres on that tile.
	var launch_ctr := (last_piece.position + last_piece.size / 2.0) if (last_piece != null and is_instance_valid(last_piece)) else Vector2.ZERO
	LaunchFx.apply(gnode, last_piece, launch_ctr, _launch_opts, 1.0)
	if not Audio.has("water_pop"):
		Audio.play("item_drop", -3.0, 1.1)
	if board.is_gen_boosted(cell):
		board.consume_gen_boost(cell)      # §6: each charged tap spends one of THIS generator's boost taps
		_refresh_boost_indicator()         # tick the on-board sparkle + count badge down (or clear it)
		if _selected_cell.x >= 0 and board.is_gen(_selected_cell):
			_info_label.text = _gen_info_text(board.gen_id_at(_selected_cell), _selected_cell)
			_refresh_burst_chip()          # re-enables the chip the moment the boost expires
	# §6.D a main-generator tap may pop out a temporary TREAT generator (one live at a time)
	if not _has_treat_gen() and G.rolls_treat_spawn(rng):
		_spawn_treat_gen()
	# §6.C a main-generator tap may also side-spawn a limited-use BONUS generator (one at a time)
	if not _has_bonus_gen() and G.rolls_bonus_spawn(rng):
		_spawn_bonus_gen()
	# gen redesign #8: a tap may also self-produce a duplicate generator (the merge fuel) at GEN_SELF_DUP_RATE.
	if G.rolls_gen_self_dup(rng):
		_self_dup_generator(cell)
	_after_board_change()
	_update_water_hud()        # the pop SPENT water — the water pill sits outside the board fan-out

# Tap-to-produce a DUE generator (the carrier quest is retired). A generator is DUE when an ACTIVE QUEST asks
# for its line and the player owns neither a board copy nor a bagged one (the gen_1 anchor self-heals first);
# see Quests.due_gen. The new tool lands on the first open cell (bag only when the board is full), pops in +
# breathes + glows so it is unmissable. Returns true if it produced one — the tap is then SPENT birthing the
# tool (no energy, no item burst). Self-heals the anchor for fresh/stranded saves, so the next tap catches up.
func _produce_due_generators() -> bool:
	# RULE in the pure action (which gen is owed + place-or-bag it); the scene renders the pop-in + glow.
	var out := BoardActions.produce_due_generators(board, quests)
	if not bool(out.due):
		return false
	var landed: Array = out.landed                # board cells of tools placed this tap (bagged ones have none)
	for gc in landed:
		_grown_cells.append(gc)                   # _rebuild_all pops it in + starts its breathe
	_rebuild_all()                                # renders the new tool(s); _grown_cells drives the pop-in + breathe
	_after_board_change()
	for gc in landed:                             # glow + announce each freshly-landed tool so it can't be missed
		var ctr := board_area.get_global_transform().origin + _cell_pos(gc) + Vector2(csz, csz) / 2.0
		FX.celebrate_at(self, ctr, Strings.t("board.feedback.tool_arrived"), STRAW)
	Audio.play("unlock" if Audio.has("unlock") else "level_complete", -3.0)
	return true

# Gen stranding fix — SELF-DUP (the merge fuel). The pure action spawns a duplicate at the LINE's TOP tier
# so duplicates feed ONE lineage (no sub-tier strand) and a maxed line breeds nothing; the scene renders the
# pop-in. Lands on a free cell, else the bag (BoardActions.self_dup_generator).
func _self_dup_generator(src: Vector2i) -> void:
	var out := BoardActions.self_dup_generator(board, src)
	if out.landed.is_empty() and out.bagged.is_empty():
		return
	for c in out.landed:
		_grown_cells.append(c)
	if not out.landed.is_empty():
		_rebuild_all()
	_after_board_change()

# #14 the special CODE crafted by dragging two DIFFERENT base lines at the SAME tier together (0 if not a
# recipe, Core §6.G). The special pops at the ingredients' tier, then climbs its own ladder.
func _recipe_merge_code(a_code: int, b_code: int) -> int:
	if a_code <= 0 or b_code <= 0:
		return 0
	var at := a_code % 100
	if at != (b_code % 100):
		return 0                              # the two ingredients must be the same tier
	var special_line := G.special_for_pair(int(a_code / 100.0), int(b_code / 100.0))
	return (special_line * 100 + at) if special_line > 0 else 0

# #14 craft the special: consume the source ingredient; the target becomes the special at the same tier.
func _apply_recipe(from: Vector2i, target: Vector2i, node: Control) -> void:
	var code := _recipe_merge_code(board.item_at(from), board.item_at(target))
	if code <= 0:
		_snap_back(from, node)
		return
	board.items[BoardModel.idx(from)] = 0
	board.items[BoardModel.idx(target)] = code
	_mark_seen(code)
	_rebuild_all()
	_after_board_change()
	Audio.play("item_drop", -2.0)

# Arm the temporary boost on ONE generator (§6/§10 coin sink): BOOST_TAPS taps of boosted burst odds on
# `cell`. Refuses (no spend) when the cell holds no generator, that generator is already boosted, or the
# player is broke. Spends BOOST_COST, arms the cell, persists. (Free map-3 charges are wired in next.)
func _activate_gen_boost(cell: Vector2i) -> bool:
	if not board.is_gen(cell) or board.is_gen_boosted(cell):
		return false
	if Bucket.boost_charges() > 0:
		Bucket.spend_boost_charge()       # §10: a free boost-line charge arms it for free (spent on the board)
	elif not Save.spend(G.BOOST_COST, "boost"):
		return false
	board.arm_gen_boost(cell, G.BOOST_TAPS)
	_after_board_change()
	return true

# The info-bar boost chip (T54→boost, T57): on a generator tap the bottom info bar shows the generator
# (preview + name + the live boost detail) and — in the slot the sell button leaves empty for
# generators — a chip to activate the boost. Built in _build_info_bar, driven by _select_item /
# _refresh_burst_chip, tapped via _on_burst_chip. The §6 coin sink lives in _activate_gen_boost above;
# the on-board indicator is _refresh_boost_indicator.

func _commit_merge(a: Vector2i, b: Vector2i, node: Control) -> void:
	var produced := board.merge(a, b)
	piece_nodes.erase(a)
	animating = true
	# the losing piece SLIDES into the winner cell through the unified MOVE verb (accelerate-into-
	# impact). The slide duration is owned by the Merge FX workbench's merge_slide_ms knob, not by the
	# Move workbench's general travel duration_ms, so tuning ordinary travel never makes merges sluggish.
	# The shadow/trail/lean toggles still apply. _after_merge stays the completion callback — chained on
	# the returned tween so the merge still resolves exactly when the slide lands.
	var merge_slide_ms := MergeFx.knob(_merge_opts, "merge_slide_ms")
	var t := MoveFx.apply(node, node.position, _cell_pos(b), "slide", _move_opts, merge_slide_ms)
	if t != null:
		t.tween_callback(_after_merge.bind(a, b, produced, node))
	else:
		_after_merge(a, b, produced, node)   # node went invalid mid-merge — resolve immediately

func _after_merge(_a: Vector2i, b: Vector2i, produced: int, moved: Control) -> void:
	if is_instance_valid(moved):
		moved.queue_free()
	var old: Control = piece_nodes.get(b)
	if old != null and is_instance_valid(old):
		old.queue_free()
	_mark_seen(produced)
	_end_hand_hint("merge")       # FTUE: the player just merged — the merge teach is done, forever
	_note_item_landed(produced)   # W3: first max-tier item → one-time "sell at the stall" hint
	var n := _make_piece(produced, csz)
	n.position = _cell_pos(b)
	board_area.add_child(n)
	piece_nodes[b] = n
	var tier := BoardModel.tier_of(produced)
	var center := _cell_pos(b) + Vector2(csz, csz) / 2.0
	var combo := _bump_combo()
	# the merge IMPACT — squash/flash/shake/hitstop/burst/sound + the neighbour ripple + the big-merge
	# board punch — now runs through the workbench-tuned MergeFx applier (resolved once in _ready), so
	# the Merge workbench's toggles + knobs take effect in-game. intensity=1.0, gate=0 keeps today's
	# board feel; the neighbour list + the board are passed in (the scene owns the grid). MergeFx.apply
	# does the ripple + board_punch INTERNALLY now — the separate scene-side calls were removed below.
	# squash/flash/shake/hitstop/burst/sound + ripple + board punch + the WORLD PUFF (a small grove-scale
	# petal burst that replaced the old giant Ambient.puff motes) + the milestone WORD all fire INSIDE
	# MergeFx.apply now — every cue is a workbench toggle/knob.
	# T63: a §6.G recipe-line (special "treasure" line) merge fires the intensified big-moment feel at EVERY
	# tier — top-band colour/chime/haptic + the reserved shake + board punch — so the premium lines always land.
	GridFx.play_merge(board_area, n, center, tier, combo, _orthogonal_neighbour_nodes(b), _grid_fx_opts, false, G.is_special_line(produced))
	# bundle D: poke the screen-bloom — a PERSISTENT overlay, so it can't live inside apply(); gate + scale it
	# here by the workbench's combo_bloom toggle + bloom_pct knob (the scene owns the world reaction).
	if MergeFx.on(_merge_opts, "combo_bloom") and _combo_bloom != null and is_instance_valid(_combo_bloom):
		_combo_bloom.bump(combo, MergeFx.knob(_merge_opts, "bloom_pct"))
	# a merge beside a sealed cell opens it once the player's Level has reached its §4 gate
	for cell in board.openable_brambles(b, _quest_level()):
		_open_bramble(cell)
	_refresh_locked_cells()   # the open set changed → re-evaluate neighbours' frontier/highlight
	# a little luck: merges sometimes shake a coin loose
	if BoardLogic.rolls_coin_drop(produced, rng):
		_drop_coin_near(b)
	# §6.B a rarer luck: a merge sometimes also shakes a SPECIAL item loose (chest/key/water/acorn/exp)
	if not G.is_special(produced) and G.rolls_special_drop(rng):
		_drop_special_near(b, G.pick_special_drop(rng))
	animating = false
	_after_board_change()

# The up-to-4 ORTHOGONAL neighbour piece nodes of `cell`, gathered from the live grid (piece_nodes,
# keyed by cell). Empty cells and invalid/freed nodes are skipped, so the returned list only ever holds
# real, settled tiles — the verb (Feel.ripple) never animates a missing or in-flight node. Scene-side on
# purpose: the board owns its grid, so the impact verb stays grid-agnostic.
func _orthogonal_neighbour_nodes(cell: Vector2i) -> Array:
	var out: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nb: Control = piece_nodes.get(cell + d)
		if nb != null and is_instance_valid(nb):
			out.append(nb)
	return out

# Extend or restart the cozy merge streak. A merge within COMBO_WINDOW of the previous one
# bumps the count; a longer gap restarts at 1. Returns the new streak length. Cadence is
# BoardLogic.combo_step (pure, unit-tested).
func _bump_combo() -> int:
	var now := Time.get_ticks_msec()
	var dt := float(now - _last_merge_ms) / 1000.0
	_last_merge_ms = now
	_combo_count = BoardLogic.combo_step(_combo_count, dt, FX.Tune.COMBO_WINDOW)
	return _combo_count

# The milestone word ("Nice / Lovely / Wonderful") now fires inside MergeFx.apply as the
# combo_words cue (a workbench toggle/knob), so the old _combo_celebrate scene method is gone.

# The lines the player's open quests currently ask for (one entry per quest, so a line asked by two
# quests is twice as likely to seed an unlocked cell). Empty only in the rare no-quest window.
func _open_quest_lines() -> Array:
	var out: Array = []
	for q in quests:
		var it := G.quest_item(q)
		if not it.is_empty():
			out.append(int(it.line))
	return out

func _open_bramble(cell: Vector2i) -> void:
	# §4: a freshly-opened cell mimics ONE generator pop biased to a RANDOM open quest line. With no
	# open quests (rare), pass -1 so the model falls back to the legacy positional seed.
	var lines := _open_quest_lines()
	var contents := board.open_bramble(cell, BoardLogic.bramble_seed(lines, rng) if not lines.is_empty() else -1)
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
	FX.floating_text(self, board_area.get_global_transform() * (_cell_pos(cell)) - Vector2(10, 40), Strings.t("board.feedback.cleared"), CREAM, FS.HEADING)
	Audio.play("tidy_poof", -2.0)

func _drop_coin_near(near: Vector2i, code: int = -1) -> void:
	var cell := BoardLogic.pick_drop_cell(board, near, rng)
	if cell.x < 0:                                # no open ground → nothing to shake loose
		return
	if code <= 0:
		code = G.COIN_LINE * 100 + 1
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
	# JUICE: the coin TOUCHES DOWN at the end of its grow-in flight — a discrete (loud) Feel.land
	# owns the impact squash + small flash + micro-puff + touch sound. The verb plays the canonical
	# `tidy_poof` itself, so the old inline poof here is dropped (no double-sound).
	var coin_ctr := board_area.get_global_transform() * _cell_pos(cell) + Vector2(csz, csz) / 2.0
	t.chain().tween_callback(func() -> void:
		if n and is_instance_valid(n):
			LandFx.apply(self, n, coin_ctr, _land_opts, 0.8, false)
			Feel.ripple(_orthogonal_neighbour_nodes(cell), coin_ctr, 0.8))   # bundle B: the touchdown jiggles its neighbours

## Debug-only: drop a tier-1 coin onto a free board cell (the debug panel's "Drop coin" button).
## Animates in from the board centre like a merge coin-drop, then persists so the coin survives a
## save/reload and un-dims a generator if this filled the last empty cell.
func debug_drop_coin() -> void:
	if board.empty_ground_cells().is_empty():
		return
	_drop_coin_near(Vector2i(G.ROWS / 2, G.COLS / 2))
	_after_board_change()

## Debug-only: drop a tier-1 acorn onto a free board cell (the debug panel's "Drop acorn" button).
## Uses the normal special-drop placement path so it lands, persists, merges, and tap-collects like a real drop.
func debug_drop_acorn() -> void:
	if board.empty_ground_cells().is_empty():
		return
	_drop_special_near(Vector2i(G.ROWS / 2, G.COLS / 2), 13 * 100 + 1)
	_after_board_change()

func _collect_coin(cell: Vector2i, node: Control) -> void:
	# RULE in the pure action (take the coin + credit the wallet); the scene renders the fly-to-HUD.
	var got := int(BoardActions.collect_coin(board, cell).get("got", 0))
	piece_nodes.erase(cell)
	var at := board_area.get_global_transform() * _cell_pos(cell) + Vector2(csz, csz) / 2.0
	if node != null and is_instance_valid(node):
		at = node.get_global_rect().get_center()
		node.queue_free()
	var coin_done := func() -> void:
		if is_instance_valid(self):
			_update_hud()
	FX.reward_arrival(self, at, "coin", got, STRAW, coins_label, coin_done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "coin_pickup")
	Audio.play("coin_earn", -3.0)
	_after_board_change(true)   # the coin FLIES to the wallet — coin_done ticks the pill on arrival

# §6.B place a SPECIAL drop item near `near` (mirrors _drop_coin_near — the lucky special-item shake).
func _drop_special_near(near: Vector2i, code: int) -> void:
	var cell := BoardLogic.pick_drop_cell(board, near, rng)
	if cell.x < 0:                                # no open ground → nothing to shake loose
		return
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
	# JUICE: the special item TOUCHES DOWN at the end of its grow-in flight — a discrete (loud)
	# Feel.land owns the impact squash + small flash + micro-puff + the canonical touch sound, so
	# the old inline poof here is dropped (no double-sound). Mirrors _drop_coin_near.
	var special_ctr := board_area.get_global_transform() * _cell_pos(cell) + Vector2(csz, csz) / 2.0
	t.chain().tween_callback(func() -> void:
		if n and is_instance_valid(n):
			LandFx.apply(self, n, special_ctr, _land_opts, 0.8, false)
			Feel.ripple(_orthogonal_neighbour_nodes(cell), special_ctr, 0.8))   # bundle B: the touchdown jiggles its neighbours

# §6.B tap-collect a water/acorn/exp item → grant the resource (water banks OVER the cap; acorns premium; exp).
func _collect_special(cell: Vector2i, node: Control) -> void:
	# RULE in the pure action (resolve the reward, take the tile, credit acorn/exp); the scene folds a
	# "water" reward into its live water mirror (a scene field, not Save) and renders.
	var out := BoardActions.collect_special(board, cell)
	if out.is_empty():
		return
	piece_nodes.erase(cell)
	if node != null and is_instance_valid(node):
		node.queue_free()
	if String(out.kind) == "water":
		# Bank OVER the cap (like the free refill + starter credit) — a collect at a full can keeps the
		# spare instead of dissolving the drop; regen pauses above the cap (board_logic.regen) so it holds.
		water = water + int(out.amount)
	Audio.play("coin_earn", -3.0, 1.15)
	_after_board_change()
	_update_water_hud()

# §6.B open a chest with a second TAP (the key line is retired): consume it and credit its
# coins+acorns payout DIRECTLY to the wallet (like every other tap-collect). Coins are ORGANIC
# (add_coins — spendable, but the clock is quests only); acorns skim the piggy bank like other premium earns. (The old
# face-value item spawn died with the 12-tier coin ladder — 3-tier coins can't carry the payout.)
func _open_chest(target: Vector2i, node: Control) -> void:
	var reward := G.chest_open_reward(board.item_at(target))
	board.take(target)
	piece_nodes.erase(target)
	if node != null and is_instance_valid(node):
		node.queue_free()
	var at := board_area.get_global_transform().origin + _cell_pos(target) + Vector2(csz, csz) / 2.0
	var got_coins := int(reward.coins)
	var got_acorns := int(reward.acorns)
	if got_coins > 0:
		Save.add_coins(got_coins)            # spendable only — the clock is quests only (2026-07-25)
		FX.reward_arrival(self, at, "coin", got_coins, STRAW, coins_label, Callable(), FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "chest_open")
	if got_acorns > 0:
		Save.add_diamonds(got_acorns)
		Vault.skim(got_acorns)               # premium earned in play skims the piggy bank (T44)
		FX.floating_reward(self, at + Vector2(0, 40), "gem", got_acorns, Color("#BFE6F2"), FS.HEADING)
	Audio.play("level_complete", -4.0, 1.15)
	_after_board_change()


# §6.C LEGACY MIGRATION (gen redesign 2026-06-28): the old constant-accrual accumulators are retired — they
# are now limited-use BONUS generators that side-spawn off a tap (_spawn_bonus_gen). One-time: strip any
# placed/banked legacy accumulators from the board + bag, then drop the legacy save key. Idempotent after.
func _sync_accumulators() -> void:
	if not Save.grove().has("accumulators"):
		return
	for cell in board.gens.keys():
		if G.is_accumulator(String(board.gens[cell])):
			board.remove_gen(cell)
	board.prune_bag(func(id: String) -> bool: return not G.is_accumulator(id))   # drops legacy accumulators, keeps tiers aligned
	Save.grove().erase("accumulators")
	_persist()

# §6.C a tap on a BONUS generator pops collectable board items (× a burst while a boost is live — a
# boosted pop then spends one boost tap, like a charged generator tap), spends one of its limited taps,
# and VANISHES when the budget runs out. (gen redesign 2026-06-28 — was time-banked accrual.)
func _collect_accumulator(cell: Vector2i) -> void:
	var id := board.gen_id_at(cell)
	var kind := G.accumulator_kind_of(id)
	if kind == "":
		return
	var clicks := int(Save.grove().get("bonus_clicks", 0))
	var gn: Control = gen_nodes.get(cell)
	if clicks <= 0:
		if gn != null:
			FX.wobble(gn)
		Audio.play("invalid_soft", -6.0)
		return
	# §6: a special-item/bonus generator pops a SPREAD of tiers like a normal generator (was a fixed t1) —
	# rolled per drop off the generator curve and CLAMPED to the item's merge ceiling (water/exp top out at
	# SPECIAL_TOP; coins/acorns top high). The LINE is fixed by the accumulator's kind; only the tier varies.
	var base_line := 0
	if kind == "coins":
		base_line = G.COIN_LINE
	else:
		for line in G.SPECIAL_ITEMS:
			var def: Dictionary = G.SPECIAL_ITEMS[line]
			if String(def.get("kind", "")) == kind:
				base_line = int(line)
				break
	if base_line <= 0:
		return
	var item_top := G.merge_top(base_line * 100 + 1)
	var mult := 1
	var boosted := board.is_gen_boosted(cell)
	if boosted:
		mult = G.burst_count(_quest_map(), G.boost_bonus(), rng)
	var drops := mini(mult, board.empty_ground_cells().size())
	if drops <= 0:
		if gn != null:
			FX.wobble(gn)
		Audio.play("invalid_soft", -6.0)
		return
	for _i in drops:
		var item_code := base_line * 100 + BoardLogic.roll_item_tier(rng, item_top)   # a tier off the curve, like a normal pop
		if G.is_coin(item_code):
			_drop_coin_near(cell, item_code)
		else:
			_drop_special_near(cell, item_code)
	clicks -= 1
	if boosted:
		board.consume_gen_boost(cell)      # §6: a boosted collect spends one of this generator's boost taps
		_refresh_boost_indicator()         # tick the on-board sparkle + count badge down
	if gn != null:
		FX.pop(gn)
	Audio.play("water_pop" if Audio.has("water_pop") else "item_drop", -3.0, 1.1)
	if clicks <= 0:
		board.remove_gen(cell)                # the bonus generator is spent → it vanishes (clears its tier too)
		Save.grove().erase("bonus_clicks")
	else:
		Save.grove()["bonus_clicks"] = clicks
	_update_water_hud()
	if board.is_gen(cell):
		_refresh_accumulator_badge(cell)
	else:
		_rebuild_all()
	_after_board_change()

# §6.C draw/update the small taps-left badge on a BONUS generator (reuses the boost-badge chrome).
func _refresh_accumulator_badge(cell: Vector2i) -> void:
	var gn: Control = gen_nodes.get(cell)
	if gn == null:
		return
	if G.accumulator_kind_of(board.gen_id_at(cell)) == "":
		return
	var clicks := int(Save.grove().get("bonus_clicks", 0))
	var badge: Control = gn.get_node_or_null("AccBadge")
	if clicks <= 0:
		if badge != null:
			badge.queue_free()
		return
	if badge == null:
		badge = _make_boost_badge()
		badge.name = "AccBadge"
		gn.add_child(badge)
	(badge.get_node("Count") as Label).text = "%d" % clicks

# §6.C is any limited-use BONUS generator currently on the board or in the bag (one at a time)?
func _has_bonus_gen() -> bool:
	for v in board.gens.values():
		if G.is_accumulator(String(v)):
			return true
	for v in board.gen_bag:
		if G.is_accumulator(String(v)):
			return true
	return false

# §6.C side-spawn a limited-use bonus generator onto a free cell with a random tap budget. Skips if full.
func _spawn_bonus_gen() -> void:
	var kind := G.pick_bonus_kind(rng)
	if kind == "":
		return
	var dest := Vector2i(-1, -1)
	for c in board.empty_ground_cells():
		if not board.gens.has(c):
			dest = c
			break
	if dest == Vector2i(-1, -1):
		return
	board.place_gen(String(G.ACCUMULATORS[kind].id), dest)
	Save.grove()["bonus_clicks"] = G.pick_bonus_clicks(rng)
	_grown_cells.append(dest)
	_rebuild_all()
	Audio.play("level_complete", -5.0, 1.25)

# --- §6.D temporary treat generators (board) ----------------------------------------------------------
func _has_treat_gen() -> bool:
	for v in board.gens.values():
		if G.is_treat_gen(String(v)):
			return true
	for v in board.gen_bag:
		if G.is_treat_gen(String(v)):
			return true
	return false

# Pop a temp treat generator onto a free cell with a random tap budget (saved). Skips if the board is full.
func _spawn_treat_gen() -> void:
	var dest := Vector2i(-1, -1)
	for c in board.empty_ground_cells():
		if not board.gens.has(c):
			dest = c
			break
	if dest == Vector2i(-1, -1):
		return
	board.place_gen(G.treat_gen_id(G.pick_treat_line(_quest_map())), dest)
	Save.grove()["treat_clicks"] = G.pick_treat_clicks(rng)
	_grown_cells.append(dest)             # _rebuild_all pops it in
	_rebuild_all()
	Audio.play("level_complete", -5.0, 1.25)

# A tap on the treat generator pops a burst of its premium line at the head-start tier (no water), often
# also showering a §6.B special drop. Decrements the tap budget; at 0 the treat generator VANISHES.
func _pop_treat(cell: Vector2i) -> void:
	if int(Save.grove().get("treat_clicks", 0)) <= 0:
		return                                # parity with _collect_accumulator: no budget left → no free burst, no -1 underflow
	var line := G.treat_line_of(board.gen_id_at(cell))
	var empties := board.empty_ground_cells()
	if empties.is_empty():
		var gnw: Control = gen_nodes.get(cell)
		if gnw != null:
			FX.wobble(gnw)
		Audio.play("invalid_soft", -6.0)
		return
	var burst := mini(G.burst_count(_quest_map(), 0, rng), empties.size())
	for _b in burst:
		var pick: Vector2i = empties[rng.randi_range(0, empties.size() - 1)]
		var code: int = line * 100 + BoardLogic.roll_item_tier(rng, G.merge_top(line * 100 + 1))   # §6: a SPREAD of tiers like a normal pop (was a fixed TREAT_POP_TIER head start)
		board.place(pick, code)
		empties.erase(pick)
		_mark_seen(code)
		var n := _make_piece(code, csz)
		n.position = _cell_pos(cell)
		n.scale = Vector2(0.3, 0.3)
		board_area.add_child(n)
		piece_nodes[pick] = n
		var t := n.create_tween()
		t.set_parallel(true)
		t.tween_property(n, "position", _cell_pos(pick), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(n, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not empties.is_empty() and rng.randf() < G.TREAT_DROP_RATE:
		_drop_special_near(cell, G.pick_special_drop(rng))   # the treat shower: a §6.B special item too
	var clicks := int(Save.grove().get("treat_clicks", 0)) - 1
	FX.gen_charge(gen_nodes.get(cell))
	Audio.play("water_pop", -2.0, 1.2)
	if clicks <= 0:
		board.remove_gen(cell)                # the treat generator is spent → it vanishes (clears its tier too)
		Save.grove().erase("treat_clicks")
	else:
		Save.grove()["treat_clicks"] = clicks
	_rebuild_all()
	_after_board_change()

func _commit_move(a: Vector2i, b: Vector2i, node: Control) -> void:
	board.move(a, b)
	piece_nodes.erase(a)
	piece_nodes[b] = node
	# JUICE: the tile slides into the empty cell, then THUMPS DOWN on arrival — the workbench-tuned Land
	# feel (squash + dust puff + flash + the land sound + the new neighbour ripple), with the cell's
	# orthogonal neighbours bumped. LandFx owns the touchdown sound now, so the old bare item_drop is gone
	# (keeping it would double with the land sound). Mirrors the generator-pop touchdown at _pop_seed.
	var land_ctr := _cell_pos(b) + Vector2(csz, csz) / 2.0
	GridFx.slide_and_land(board_area, node, _cell_pos(b), land_ctr, _orthogonal_neighbour_nodes(b), _grid_fx_opts, 120)
	_after_board_change()

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
	_after_board_change()

# --- bag --------------------------------------------------------------------------

# §5: the bag holds as many items as the player OWNS slots (6 at start, bought up to 18).
func _bag_capacity() -> int:
	return BoardLogic.bag_capacity(Save.bag_slots())


func _stash(from: Vector2i, node: Control) -> void:
	if not board.collect_reward_at(from).is_empty():
		# The bag stores only item codes; custom-value chest rewards must remain board collectables.
		_snap_back(from, node)
		return
	if bag.size() >= _bag_capacity():
		_snap_back(from, node)
		return
	var code := board.take(from)
	bag.append(code)
	piece_nodes.erase(from)
	var at := board_area.get_global_transform() * _cell_pos(from) + Vector2(csz, csz) / 2.0
	if is_instance_valid(node):
		at = node.get_global_rect().get_center()
		node.queue_free()
	Audio.play("bag_in" if Audio.has("bag_in") else "item_pickup", -2.0)
	_rebuild_bag()
	if bag_btn != null and is_instance_valid(bag_btn):
		# no completion callback: _rebuild_bag() above already refreshed the bottom-bar count.
		FX.reward_arrival(self, at, "bag", 1, STRAW, bag_btn, Callable(), FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "stash_to_bag")
		FX.floating_text(self, bag_btn.get_global_rect().get_center() - Vector2(70, 82), Strings.t("board.feedback.stored"), STRAW, FS.BODY)
	_after_board_change()

# §5 expansion: buy ONE more slot with 💎 at the schedule price, then regrow the bar. Returns whether
# the slot was bought — a refusal (broke) is answered by the bag overlay's shop prompt, not here; the
# bag button is behind that modal, so there is nothing to wobble. Convenience, never a wall (§4/§5).
func _buy_bag_slot() -> bool:
	var price := G.next_bag_slot_price(Save.bag_slots())
	if price <= 0 or not Save.buy_bag_slot(price):
		return false
	Audio.play("level_complete", -4.0, 1.2)
	if bag_btn != null and is_instance_valid(bag_btn):
		FX.celebrate_at(self, bag_btn.get_global_rect().get_center(), Strings.t("board.feedback.bag_plus_one"), STRAW)
	_build_bag_bar()              # one more owned slot → refresh the bag well
	_update_hud()
	return true

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
	_rebuild_bag()
	_after_board_change()
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
		# empty → the code-drawn Bag well's own centered "bag" glyph IS the empty state, so the overlay
		# stays clear. Only the kit-absent drawn-disc fallback keeps its glyph INSIDE bag_content (wiped by
		# the clear above), so it restores it — guarded on the kit actually being loadable to draw one.
		if _bag_well_drawn_disc:
			var KitR: GDScript = KIT
			if KitR != null:
				bag_content.add_child(KitR.make_icon("bag", bag_piece_px))
	else:
		# filled → the most-recent stashed item overlays the tile directly, sized large to cover the satchel.
		bag_content.add_child(_make_piece(int(bag[bag.size() - 1]), bag_piece_px))


func _input(event: InputEvent) -> void:
	var board_release: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
		or (event is InputEventScreenTouch and not event.pressed)
	if _pressing and board_release and board_area != null and is_instance_valid(board_area):
		_pressing = false
		var local: Vector2 = board_area.get_global_transform().affine_inverse() * event.position
		_on_release(local)

func _on_item_tap(qi: int, line: int, tier: int, chip: Control) -> void:
	if qi >= 0 and qi < quests.size() and BoardLogic.quest_payable(board, quests[qi]):
		_on_giver_tap(qi, chip)
	else:
		_open_ladder(line, tier)

func _on_giver_tap(qi: int, chip: Control) -> void:
	if qi < 0 or qi >= quests.size():
		return
	var q: Dictionary = quests[qi]
	if not BoardLogic.quest_payable(board, q):
		FX.wobble(chip)
		Audio.play("invalid_soft", -6.0)
		return
	var it: Dictionary = G.quest_item(q)
	_deliver_quest(qi, board.first_item_of(int(it.line) * 100 + int(it.tier)), chip)

# Board-side delivery (the second-tap affordance): the player tapped an already-focused, glowing tile —
# hand it to the leftmost giver that wants it, consuming THIS exact tile. No-op when nothing wants it
# (no live quest asks for it / the giver card is missing). Mirrors the giver tap, just sourced from the board.
func _deliver_from_board(cell: Vector2i) -> void:
	var qi := _quest_for_code(board.item_at(cell))
	if qi < 0:
		return
	var chip := _chip_for_qi(qi)
	if chip == null:
		return
	_clear_selection()                        # the tile is leaving — drop its focus ring + info bar
	_deliver_quest(qi, cell, chip)

# The ONE delivery path, shared by the giver tap and the board second-tap. Consumes the item at `cell`,
# flies it to `chip`, pays the quest's reward (exp + coins + level-up), and drops the quest from the
# fence. `cell` is explicit so a board-tap consumes the EXACT tile tapped, not just first_item_of(code).
func _deliver_quest(qi: int, cell: Vector2i, chip: Control) -> void:
	# Snapshot the unlock-bar meter BEFORE the action mutates exp/quests — the animation tweens from it.
	var purge_before := _purge_progress()
	# RULE: the whole state transition — consume the tile, drop the quest, remember the ask, advance exp
	# (the ONE place exp earns), pay the coin faucet — lives in the pure, headless-tested action. The scene
	# below is render-only: it reads the returned outcome to drive the fly, reward FX, level dialog, vase.
	var out := BoardActions.deliver_quest(board, quests, _recent_items, qi, cell)
	var sp_coins := int(out.coins)
	var levels_up := int(out.levels_up)
	var n: Control = piece_nodes.get(cell)
	piece_nodes.erase(cell)
	if n != null and is_instance_valid(n):
		var dest := chip.get_global_rect().get_center() - board_area.get_global_transform().origin - Vector2(csz, csz) / 2.0
		var t := n.create_tween()
		t.set_parallel(true)
		t.tween_property(n, "position", dest, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(n, "scale", Vector2(0.4, 0.4), 0.3)
		t.chain().tween_callback(n.queue_free)
	# (generators are no longer delivered here — they arrive when a generator tap produces a DUE tool;
	#  see _produce_due_generators in _pop_seed.)
	if sp_coins > 0:
		var quest_coin_done := func() -> void:
			if is_instance_valid(self):
				_update_hud()
		FX.reward_arrival(self, chip.get_global_rect().get_center() + Vector2(20, 36), "coin", sp_coins, STRAW, coins_label, quest_coin_done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "quest_payout")
	Audio.play("giver_cheer" if Audio.has("giver_cheer") else "merge_success", -2.0, 1.2)
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
	_rebuild_givers()
	# a paying quest FLIES its coins to the wallet — quest_coin_done ticks the pill on arrival
	_after_board_change(sp_coins > 0)
	_animate_unlock_bar_from(purge_before)
	# §10: a quest's coin overflow is the surviving lump coin faucet. Offer to DOUBLE it for a few
	# 💎 — but only when the reward is big enough that the deal beats the shop (G.collect_2x_offered).
	if sp_coins > 0:
		_maybe_offer_2x(sp_coins, chip.get_global_rect().get_center())
	if _gate_ready() and home_btn != null and is_instance_valid(home_btn):
		FX.floating_text(self, home_btn.get_global_rect().get_center() - Vector2(140, 120), Strings.t("board.feedback.ready_to_restore"), STRAW, FS.TITLE)

# The cozy, optional 2× DOUBLER card on the quest COIN reward (the surviving lump coin faucet,
# §7/§10). Shown after a quest pays `got` coins, but ONLY when the reward is big enough that paying
# 💎 to double it beats the shop coin pouch (G.collect_2x_offered). Accept → spend the 💎 price +
# credit a SECOND `got`. Opt-in, dismissible, one at a time, never blocks play. The board frees on
# scene-change, so no nav-dismiss is needed.
func _maybe_offer_2x(got: int, _center: Vector2) -> void:
	if not G.collect_2x_offered(got):
		return
	if not is_inside_tree():
		return
	var cost := G.collect_2x_cost(got)
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
	pl.text = Strings.t("board.double.pitch")
	pl.add_theme_font_size_override("font_size", FS.BODY)
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
	sn0.add_theme_font_size_override("font_size", FS.FINE)
	sn0.add_theme_color_override("font_color", Color(Pal.INK, 0.5))
	sn0.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_child(sn0)
	var arrow := Label.new()
	arrow.text = "→"                                     # the "becomes"
	arrow.add_theme_font_size_override("font_size", FS.BODY)
	arrow.add_theme_color_override("font_color", Color(Pal.BARK, 0.95))
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_child(arrow)
	sub.add_child(Look.icon("coin", 32.0))
	var sn1 := Label.new()
	sn1.text = str(got * 2)                              # the "after" — the doubled total
	sn1.add_theme_font_size_override("font_size", FS.HEADING)
	sn1.add_theme_color_override("font_color", STRAW)
	sn1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_child(sn1)
	# the two ways out — a primary "Double" and a quiet "No thanks" (decline keeps the coins)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	col.add_child(btns)
	btns.add_child(Look.button(Strings.t("board.double.decline"), _dismiss_2x_offer, false))
	btns.add_child(Look.button(Strings.t("board.double.accept") % cost, func() -> void: _accept_2x_offer(got), true))
	add_child(card)
	_2x_offer = card
	FX.pop_in(card)
	FX.breathe_once(card)

# Accept the 2× doubler: re-check the deal, SPEND the 💎 price, credit a SECOND `got` coins,
# celebrate the bonus, tick the wallet, and close the card. Can't afford (or no longer a deal) →
# the card closes cozily with a soft nudge, no spend, the original coins kept.
func _accept_2x_offer(got: int) -> void:
	var at := _2x_offer.get_global_rect().get_center() if _2x_offer != null and is_instance_valid(_2x_offer) else get_global_rect().get_center()
	_dismiss_2x_offer()
	if not G.collect_2x_offered(got) or not Save.spend_diamonds(G.collect_2x_cost(got)):
		Audio.play("invalid_soft", -4.0)
		return
	Save.add_coins(got)                              # the doubled half — the same amount again
	Audio.play("level_complete", -3.0, 1.2)
	var accept_2x_done := func() -> void:
		if is_instance_valid(self):
			_update_hud()
	FX.reward_arrival(self, at, "coin", got, Color("#E3B23C"), coins_label, accept_2x_done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "accept_2x")

# Close the 2× offer card (decline, tap-away, or post-accept). Idempotent.
func _dismiss_2x_offer() -> void:
	if _2x_offer != null and is_instance_valid(_2x_offer):
		_2x_offer.queue_free()
	_2x_offer = null

# sell ANYTHING dragged onto the cart — tier pocket change; cleanup, never income
## Gen stranding fix — sell the selected REDUNDANT generator: the pure action removes it + credits coins;
## the scene re-renders without it (mirrors the merge/store generator paths) and floats the coin payout.
func _sell_generator(cell: Vector2i) -> void:
	var out := BoardActions.sell_generator(board, cell)
	if not bool(out.sold):
		return
	Audio.play("tidy_poof", -4.0, 1.1)
	var coins := int(out.coins)
	if coins > 0:
		var center: Vector2 = _info_trash.get_global_rect().get_center() if (_info_trash != null and is_instance_valid(_info_trash)) else get_global_rect().get_center()
		var done := func() -> void:
			if is_instance_valid(self):
				_update_hud()
		FX.reward_arrival(self, center, "coin", coins, STRAW, coins_label, done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "sale_payout")
	_rebuild_all()
	_after_board_change()

# §6 OFFER the retirement of a line the game will never ask again. Deferred to board ENTRY (a calm moment)
# rather than fired on the level-up that makes it retirable — a modal must never land mid-gesture, and the
# level-up itself happens on a quest delivery. One line at a time; if the player dismisses it, the info-bar
# sell button still clears the generator, so nothing is ever stuck. On the shipped roster this fires three
# times in a whole playthrough.
func _maybe_offer_retirement() -> void:
	if not is_inside_tree() or RetireOffer.is_open(self):
		return
	if not Save.board_tutorial_seen():
		return                                        # never over the FTUE
	var owned: Array = Quests.owned_gens(board.gens, board.gen_bag)
	var offer := G.retirable_gens(owned, _quest_level())
	var declined: Dictionary = Save.grove().get("retire_declined", {})
	var gid := ""
	for g in offer:
		if not declined.has(String(g)):        # offered ONCE; the info-bar sell button is the path back
			gid = String(g)
			break
	if gid == "":
		return
	var line := int(gid.trim_prefix("gen_"))
	var pv: Dictionary = BoardActions.retire_preview(board, bag, line)   # the ONE payout read
	RetireOffer.open(self, {"line": line, "gen_id": gid, "pieces": int(pv.pieces), "coins": int(pv.coins),
		"on_confirm": func() -> void:
			if is_instance_valid(self):
				_retire_line(gid),
		"on_dismiss": func() -> void:
			# remember the decline so the offer does not re-fire on every board entry — it is an offer, not a nag.
			var dm: Dictionary = Save.grove().get("retire_declined", {})
			dm[gid] = true
			Save.grove()["retire_declined"] = dm
			Save.grove_write()})

# §6 LINE RETIREMENT — clear a line the game will never ask again: its generator leaves the board and the
# gen_bag, and every leftover piece of it (board + item bag) is sold. All the decision logic is the pure
# BoardActions.retire_line static (guarded on G.gen_retirable); this just plays the payout and rebuilds.
func _retire_line(gid: String) -> void:
	var out: Dictionary = BoardActions.retire_line(board, bag, gid, _quest_level())
	if not bool(out.retired):
		return
	bag = out.bag
	Audio.play("tidy_poof", -4.0, 1.1)
	var coins := int(out.coins)
	if coins > 0:
		var center: Vector2 = get_global_rect().get_center()
		var done := func() -> void:
			if is_instance_valid(self):
				_update_hud()
		FX.reward_arrival(self, center, "coin", coins, STRAW, coins_label, done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "sale_payout")
	_rebuild_all()
	_after_board_change()

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
	_after_board_change(true)   # _grant_sale FLIES the payout — its arrival callback ticks the wallet

# Y1: pay the sale (t8 → a flat 1💎; t1–t7 → tier coins × the item's per-map band, §6),
# fly the piece into the info-bar sell button, and float the right currency.
func _grant_sale(code: int, node: Control) -> void:
	var reward := G.sell_reward(code)        # Vector2i(coins, diamonds)
	if reward.x > 0:
		Save.add_coins(reward.x)             # SELLING NEVER ADVANCES THE CLOCK (owner call 2026-07-25): a sale is
		                                     # cleanup, and its coins still spend — but only DELIVERING a quest levels you.
	if reward.y > 0:
		Save.add_diamonds(reward.y)
		Vault.skim(reward.y)                  # T44 SKIM-SITE 3/3 (t8-sell): the piggy bank skims a slice of the t8 premium sale (§10)
	var target: Control = _info_trash if (_info_trash != null and is_instance_valid(_info_trash)) else null
	var center: Vector2 = target.get_global_rect().get_center() if (target != null and is_instance_valid(target)) else get_global_rect().get_center()
	if node != null and is_instance_valid(node):
		var dest: Vector2 = center - board_area.get_global_transform().origin - Vector2(csz, csz) / 2.0
		var t := node.create_tween()
		t.set_parallel(true)
		t.tween_property(node, "position", dest, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(node, "scale", Vector2(0.35, 0.35), 0.25)
		t.chain().tween_callback(node.queue_free)
	if reward.y > 0:
		var sale_gem_done := func() -> void:
			if is_instance_valid(self):
				_update_hud()
		FX.reward_arrival(self, center, "gem", reward.y, Color("#A9C7E8"), diamonds_label, sale_gem_done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "sale_payout")
	elif reward.x > 0:
		var sale_coin_done := func() -> void:
			if is_instance_valid(self):
				_update_hud()
		FX.reward_arrival(self, center, "coin", reward.x, STRAW, coins_label, sale_coin_done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "sale_payout")

# The real gate lives on the HOME scene now (buying a spot IS the progression step) —
# this button is the invitation: stars suffice, go decorate.
# The upgrade path: the line's full ladder, tier by tier — grown tiers show their
# art, never-seen tiers show "?", and the tapped/asked tier wears a gold ring.
func _open_ladder(line: int, mark_tier: int) -> void:
	if not Features.on("discovery_ladder") or (not G.LINES.has(line) and not G.SPECIAL_ITEMS.has(line)):
		return
	# gen redesign #9/#15: a base line shows its GENERATOR icon atop the tier grid; a merged (special) line
	# shows its two ingredient items atop the SAME tier grid (its own ladder) — tapping either ingredient
	# opens THAT item's tier screen (Ladder rebuilds the modal in place, so navigation REPLACES, not stacks).
	var header := _ladder_header(line)
	var opts := {
		"header": header,
		"mark_tier": mark_tier,
		"on_pick": func(l: int) -> void: _open_ladder(l, mark_tier),
		"on_gen": func(g: String) -> bool: return _reveal_generator(g),
		"entries": _ladder_entries(line),   # the line's own tier ladder — shown under the recipe for a merged line
	}
	Ladder.open(self, opts)

# Tier-screen generator tap: SHOW the generator — select (highlight) it if it is out on the board;
# if it is bagged, pull it to the first empty ground cell and select it there. Returns whether the
# tap acted (the ladder closes on true); a full board or an absent generator refuses and the tier
# screen stays put.
func _reveal_generator(gid: String) -> bool:
	for c in board.gens:
		if String(board.gens[c]) == gid:
			_select_generator(Vector2i(c))
			return true
	if board.gen_bag.has(gid):
		var cells := board.empty_ground_cells()
		if cells.is_empty() or not board.place_gen_from_bag(gid, Vector2i(cells[0])):
			Audio.play("invalid_soft", -6.0)
			return false
		_rebuild_all()
		_after_board_change()
		_select_generator(Vector2i(cells[0]))
		return true
	return false

# #9 / #15: the tier dialog's header DESCRIPTOR — the GENERATOR that makes a base line ({kind:"generator"}),
# the two-ingredient RECIPE for a crafted special line ({kind:"recipe", lines:[a,b]}), else a plain title.
func _ladder_header(line: int) -> Dictionary:
	var gid := G.gen_for_line(line)
	if gid != "":
		return {"kind": "generator", "gid": gid, "name": G.generator_display_name(gid)}
	var rl: Array = G.recipe_lines(line)
	if rl.size() == 2:
		return {"kind": "recipe", "lines": rl, "name": _ladder_line_name(line)}
	return {"kind": "title", "name": Strings.t("ladder.title")}

func _ladder_line_name(line: int) -> String:
	return String((G.LINES.get(line, {}) as Dictionary).get("name", "line %d" % line))

# The board→Home handoff (req 3/4): ONE evolving home world now — the target is always the home
# scene itself (the per-map decorate jump retired with the map-select).
