extends Control
## The board — P1 core feel (water OFF).
## One persistent SAVED board: tap the seed satchel to pop items (random tier,
## ask-weighted line), drag matching plants together to grow them, merge beside
## brambles to clear them, drag onto empty ground to rearrange, stash in the Bag,
## feed top tiers to the Merchant, deliver quest asks to the fox/hedgehog for
## stars, and spend stars at the Restore gate to restore the grove (givers pause
## the moment the gate is affordable — the drive-to-spend loop).

const G = preload("res://engine/scripts/core/content.gd")
static var KIT: GDScript = Game.kit_script()   # the shared UI kit — the one cached handle, not a load() per call site
const Design = preload("res://engine/scripts/core/design.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")
const BoardActions = preload("res://engine/scripts/core/board_actions.gd")
const Improvements = preload("res://engine/scripts/core/improvements.gd")
const Mastery = preload("res://engine/scripts/core/mastery.gd")
const Bucket = preload("res://engine/scripts/core/bucket.gd")   # boost-line charges, spent on the board chip
const Quests = preload("res://engine/scripts/core/quests.gd")
const SaveMigrate = preload("res://engine/scripts/core/save_migrate.gd")   # load-time save hygiene + the above-level purge
const Claims = preload("res://engine/scripts/core/claims.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Music = preload("res://engine/scripts/core/music.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Tuning = preload("res://engine/scripts/core/tuning.gd")   # UI-redesign role dials (Tuning.UiSkin.*)
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const FocusRing = preload("res://engine/scripts/ui/focus_ring.gd")   # the selected-cell corner-bracket highlight
const CascadeOutline = preload("res://engine/scripts/ui/cascade_outline.gd")
const Bust = preload("res://engine/scripts/ui/bust.gd")
const GiverStand = preload("res://engine/scripts/ui/giver_stand.gd")
const BoardFit = preload("res://engine/scripts/ui/board_fit.gd")
const BagOverlay = preload("res://engine/scripts/ui/bag_overlay.gd")   # the tap-to-open full bag (replaces the inline row)
const Ladder = preload("res://engine/scripts/ui/ladder.gd")
const GenLines = preload("res://engine/scripts/ui/gen_lines.gd")
const MasteryRankup = preload("res://engine/scripts/ui/mastery_rankup.gd")
const MasteryRing = preload("res://engine/scripts/ui/mastery_ring.gd")
const SplitPreview = preload("res://engine/scripts/ui/split_preview.gd")
const FarewellCard = preload("res://engine/scripts/ui/farewell_card.gd")   # §8 line farewell sweep card
const Almanac = preload("res://engine/scripts/ui/almanac.gd")   # §8 read-only line status grid
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
const SoilProgressRing = preload("res://engine/scripts/ui/soil_progress_ring.gd")
const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const SkyLogic = preload("res://engine/scripts/core/sky.gd")
const SkyPatch = preload("res://engine/scripts/ui/sky_patch.gd")
const ComboBloom = preload("res://engine/scripts/ui/combo_bloom.gd")
const HandHint = preload("res://engine/scripts/ui/hand_hint.gd")   # FTUE: the merge / generator-tap teach overlay
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
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
const SKY_MARKER_SCREEN_GUTTER := 16.0
static var _sky_marker_icon_cache := {}
const STAND_W := 300.0           # fallback giver box width (merchant stall / preview); the live fence sizes by %
const GIVER_COLS := 4            # legacy fence-slot count (kept for the workbench preview; the live fence packs dynamically)
const STAND_W_PER_FENCE := 1.17  # quest card width as a multiple of the band height — keeps the card art (~1.77:1) undistorted
const QUEST_SIDE := 18.0         # the fence row's left/right inset (aligns with the board's side breathing room)
const QUEST_GAP := 16.0          # fallback gap BETWEEN cards — the workbench quest_card.gap overrides (via _giver_lay)
const UNLOCK_BAR_H_FRAC := 0.10  # the NEXT UNLOCK strip's height as a fraction of screen width (mock: board_next_unlock_v1)
const EDGE_GAP := BoardFit.EDGE_GAP   # the EQUAL page margin: HUD pills → content top == board bottom → bottom bar
const BOTTOM_BAR_INSET := 14.0   # the floating bottom bar's gap off the screen (safe-area) bottom edge
const MASTERY_RANKUP_FX_DELAY := 0.45 # after the 0.3s tile flight and 0.4s wallet arrival settle
const STACK_SEP := 20      # the row gap of the content stack (strip <-> quest fence <-> board)
const IDLE_HINT_SECS := 2.0      # W1: first idle hint sooner (was 7, then 4.5) → a mergeable pair rocks
const IDLE_RENUDGE_SECS := 4.0   # W1: re-nudge cadence while the player stays idle
const HINT_ROCK_DEG := 6.0       # W1: gentle rock amplitude (was a fast ±0.22rad shake)
const HINT_ROCK_CYCLE := 1.2     # W1: seconds per rock cycle
const HINT_ROCK_CYCLES := 3      # W1: number of slow rock cycles
const DRAG_LIFT_Z := HandHint.HAND_HINT_Z + 20   # FTUE: a lifted/dragged piece must stay visible above
                                                  # the hand-hint veil (hand_hint.gd) while a teach is live
const MERGE_TARGET_GROW := 0.30  # merge-only hit area added around each cell; move/swap keep exact-cell targeting
const ANIM_WATCHDOG_SECS := 0.6
const CHAIN_STEP_WATCHDOG_SECS := 2.0
const CHAIN_MIN_N := 3
const CHAIN_PREROLL_MS := 300
const CHAIN_STEP_MS := 250
const CHAIN_STEP_RAMP_ENABLED := true
const CHAIN_STEP_START_MS := 320
const CHAIN_STEP_END_MS := 180
const CHAIN_STEP_RAMP_END_N := 5
const CHAIN_COUNTER_ANCHOR_ORIGIN := true
const CHAIN_LOCK_DIM_ENABLED := true
const CHAIN_LOCK_DIM_ALPHA := 0.86
const CHAIN_AUTO_STEPS_ROLL_LUCKY := true
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
var bag_seed_ranks: Array = []     # PARALLEL to bag: Soil seed rank metadata; non-seeds/default seeds carry 1
var water := G.WATER_CAP
var _regen_ts := 0.0               # regen anchor (unix); advances as water accrues
var _sky_state: Dictionary = {}
var _sky_live_secs := 0.0
var _sky_patch: Control = null
var _sky_marker: Button = null
var _sky_cell_glyph: TextureRect = null
var _sky_docked_star: Control = null
var _star_catch_nodes := {}
var _star_pending_started_secs := -1.0
var _gate_was_ready := false       # edge-detect for the quest_complete cue
var _gate_ready_seen := false      # skip the cue on the first (load-time) call
var _unlock_bar: UnlockBar

var csz := 86.0
var board_area: Control
var slot_nodes := {}
var piece_nodes := {}
var bramble_nodes := {}
var _improvement_art_nodes := {}
var _soil_overlay_nodes := {}
var _magnet_scanning := false
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
var _farewell_check_queued := false
# the bottom-bar INFO BAR: tapping a board item selects it here (its name + an info button that opens the
# Tiers ladder + a trashcan that sells it for coins when it's a deletable, non-generator item).
var _selected_cell := Vector2i(-1, -1)
var _selected_improvement := false  # true when the info bar is showing an empty improved cell, not an item/generator
var _focus_ring: Control = null      # the corner-bracket frame drawn on the selected cell (lazily built in board_area)
var _split_preview: Control = null   # scissors hover preview: dashed target + twin ghosts
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
var _info_seed_place: Button         # Seed item chip: place the selected seed into its own cell
var _info_seed_place_sb: StyleBoxFlat
var _info_seed_place_count: Label
var _info_seed_place_coin: Control
var _info_seed_bag: Button           # Seed item chip: stash the selected seed into the Bag
var _info_seed_bag_sb: StyleBoxFlat
var _info_seed_bag_count: Label
var _info_seed_bag_coin: Control
var _info_unsocket: Button           # Empty improvement chip: convert the improvement back into a seed
var _info_unsocket_sb: StyleBoxFlat
var _info_unsocket_count: Label
var _info_unsocket_coin: Control
var _info_soil_rank: Button          # Empty Soil chip: rank up the selected Soil improvement
var _info_soil_rank_sb: StyleBoxFlat
var _info_soil_rank_count: Label
var _info_soil_rank_coin: Control
var _info_soil_water: Button         # Soil grow-row chip: spend board water to halve the current step once
var _info_soil_water_sb: StyleBoxFlat
var _info_soil_water_count: Label
var _info_soil_water_coin: Control
var _info_mastery_row: HBoxContainer # generator mastery row: pips + slim meter + next reward
var _info_mastery_pips: Array = []
var _info_mastery_progress: ProgressBar
var _info_mastery_next_label: Label
var _info_almanac: Button            # the empty-state Almanac button, shown only when no board cell is selected
var _info_inner_px := 62.4           # the info bar's info-button slot (from the kit's inner-control knob)
var _info_item_icon_scale := 0.80    # selected item/generator art scale as a fraction of the info bar height
var _info_item_px := 62.4            # selected item/generator art size in the info bar
var _mastery_rankup_queue: Array = [] # [{line, rank}] waiting for the celebration modal
var _mastery_rankup_open := false
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
var _rebuild_after_drag := false
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
var _chain_run: Array = []
var _chain_n := 0
var _chain_active := false
var _chain_auto_step := false
var _chain_origin_cell := Vector2i(-1, -1)
var _chain_reward_cell := Vector2i(-1, -1)
var _cascade_outline: Control = null

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
# The cost of the last pop the can could NOT pay (0 = none). A mastered generator's pop costs more than
# 1💧 (§3 tier-scaled cost), so "empty" can no longer mean water<=0 alone or the refill offer would stop
# surfacing for a mastered player whose can floors at cost-1 — §10's "no silent wall". Cleared by
# _update_water_hud the moment the can can pay it again; at cost 1 it reproduces water<=0 exactly.
var _water_short := 0

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
	_refresh_sky_state()
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
	if _land_owed_stars():
		_persist()

	Debug.mount(self)                    # debug/authoring panel (no-op in prod)
	_maybe_show_board_tutorial_first_run.call_deferred()
	_queue_farewell_check.call_deferred()   # §8: old-save migration + calm board-entry farewell chain
	_maybe_soil_ftue.call_deferred()

## Re-read the hour's sky state and rebuild what shows it: the weather layer + the patch marker.
## This is a REAL path, not a debug one — _tick_sky_hour calls it every time the hour turns.
func refresh_weather() -> void:
	_refresh_sky_state()
	var insert_at := get_child_count()
	for child in get_children():
		if child.name == "WeatherLayer":
			insert_at = mini(insert_at, child.get_index())
			remove_child(child)
			child.queue_free()
	var weather := Ambient.build_weather(get_viewport_rect().size, Ambient.weather_now())
	add_child(weather)
	move_child(weather, mini(insert_at, get_child_count() - 1))
	_sync_sky_patch_marker(true)

## The debug overlay reaches this BY NAME (Debug._act_weather → host.call("debug_refresh_weather"),
## same as map.gd's twin), and the shot tool calls it for the sky modes. Both want the real rebuild.
func debug_refresh_weather() -> void:
	refresh_weather()

func _refresh_sky_state() -> void:
	_sky_state = SkyLogic.state(Time.get_unix_time_from_system(), _quest_level(), Ambient.forced_weather)
	_reconcile_starfall_pending_for_sky()

func _tick_sky_hour() -> void:
	# The lane is level-dependent (§3), so a level-up can move it mid-hour — the lane check below
	# catches that and moves patch + marker together.
	var next := SkyLogic.state(Time.get_unix_time_from_system(), _quest_level(), Ambient.forced_weather)
	if _sky_state.is_empty() or int(next.hour) != int(_sky_state.get("hour", -1)) \
			or String(next.sky) != String(_sky_state.get("sky", "")) \
			or int(next.lane) != int(_sky_state.get("lane", -1)):
		if int(SkyLogic.grove_sky_state().get("pending", 0)) > 0:
			_queue_pending_starfall_as_owed()
			Save.grove_write()
		_sky_state = next
		_sky_live_secs = 0.0
		refresh_weather()
		return
	_sky_live_secs += 1.0
	_try_starfall()

func _sync_sky_patch_marker(pop_marker: bool) -> void:
	if board_area == null or not is_instance_valid(board_area):
		return
	_clear_starfall_catch_ui()
	_clear_sky_cell_glyph()
	for node in [_sky_patch, _sky_marker]:
		if node != null and is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()
	_sky_patch = null
	_sky_marker = null
	if _sky_state.is_empty() or not SkyLogic.gate_open():
		return
	var sky := String(_sky_state.get("sky", ""))
	# A CALM hour is chrome-free by design (§2): no wash, no marker, nothing outside the mat and
	# nothing to tap, so the info bar keeps whatever the player last selected. The board reads exactly
	# as it did before weather shipped. Same early-out as "" — the state before the first roll.
	if sky == "" or sky == SkyLogic.SKY_CALM:
		return
	var patch := SkyPatch.new()
	patch.setup(_sky_state, csz, GAP, _landscape)
	board_area.add_child(patch)
	board_area.move_child(patch, _sky_patch_insert_index())
	_sky_patch = patch
	if sky != SkyLogic.SKY_STARFALL:
		_sync_sky_cell_glyph(pop_marker)
		return
	var marker := _make_sky_marker()
	board_area.add_child(marker)
	_sky_marker = marker
	if pop_marker:
		FX.pop(marker)
	_sync_starfall_catch_ui(false, false)

func _sky_patch_insert_index() -> int:
	var insert_at := board_area.get_child_count()
	for nodes in [piece_nodes, gen_nodes]:
		for node in nodes.values():
			if node is Control and is_instance_valid(node) and node.get_parent() == board_area:
				insert_at = mini(insert_at, node.get_index())
	return mini(insert_at, board_area.get_child_count() - 1)

func _clear_sky_cell_glyph() -> void:
	_free_now(_sky_cell_glyph)
	_sky_cell_glyph = null

func _weather_focus_sky() -> bool:
	var sky := String(_sky_state.get("sky", ""))
	return sky == SkyLogic.SKY_SUNBEAM or sky == SkyLogic.SKY_RAIN

func _sky_lane_cells() -> Array:
	var out: Array = []
	var axis := String(_sky_state.get("lane_axis", SkyLogic.AXIS_COLUMN))
	var lane := int(_sky_state.get("lane", 0))
	if axis == SkyLogic.AXIS_ROW:
		for c in G.COLS:
			out.append(Vector2i(lane, c))
	else:
		for r in G.ROWS:
			out.append(Vector2i(r, lane))
	return out

func _sky_icon_cell() -> Vector2i:
	if board == null or _sky_state.is_empty() or not SkyLogic.gate_open() or not _weather_focus_sky():
		return Vector2i(-1, -1)
	var center := _lane_center_cell()
	if board.is_open(center) and not board.is_gen(center):
		return center
	var best := Vector2i(-1, -1)
	var best_dist := 1 << 20
	for raw_cell in _sky_lane_cells():
		var cell := Vector2i(raw_cell)
		if not board.is_open(cell) or board.is_gen(cell):
			continue
		var d := absi(cell.x - center.x) + absi(cell.y - center.y)
		if d < best_dist:
			best = cell
			best_dist = d
	if best.x >= 0:
		return best
	if board.in_bounds(center) and SkyLogic.in_patch(_sky_state, center):
		return center
	return Vector2i(-1, -1)

func _sync_sky_cell_glyph(pop_glyph: bool = false) -> void:
	if board_area == null or not is_instance_valid(board_area) or not _weather_focus_sky():
		return
	var cell := _sky_icon_cell()
	if cell.x < 0:
		return
	var glyph := TextureRect.new()
	glyph.name = "SkyCellGlyph"
	glyph.texture = _sky_marker_texture()
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.modulate = Color(1, 1, 1, 0.28)
	glyph.set_meta("icon_path", _sky_marker_icon_path())
	glyph.set_meta("cell", cell)
	var inset := maxf(8.0, csz * 0.16)
	glyph.position = _cell_pos(cell) + Vector2(inset, inset)
	glyph.custom_minimum_size = Vector2(csz - inset * 2.0, csz - inset * 2.0)
	glyph.size = glyph.custom_minimum_size
	glyph.pivot_offset = glyph.size * 0.5
	board_area.add_child(glyph)
	if _sky_patch != null and is_instance_valid(_sky_patch):
		board_area.move_child(glyph, mini(_sky_patch.get_index() + 1, board_area.get_child_count() - 1))
	_sky_cell_glyph = glyph
	if pop_glyph:
		FX.pop(glyph)

func _make_sky_marker() -> Button:
	var marker := Button.new()
	marker.name = "SkyMarker"
	marker.focus_mode = Control.FOCUS_NONE
	marker.tooltip_text = _sky_info_title()
	marker.text = ""
	marker.custom_minimum_size = Vector2(maxf(34.0, csz * 0.48), maxf(32.0, csz * 0.42))
	marker.size = marker.custom_minimum_size
	marker.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Pal.CREAM, 0.96)
	sb.border_color = Color(Pal.BARK, 0.72)
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.set_corner_radius_all(int(marker.custom_minimum_size.y * 0.5))
	marker.add_theme_stylebox_override("normal", sb)
	marker.add_theme_stylebox_override("hover", sb)
	marker.add_theme_stylebox_override("pressed", sb)
	marker.add_theme_color_override("font_color", Pal.INK)
	var glyph := TextureRect.new()
	glyph.name = "SkyMarkerGlyph"
	glyph.texture = _sky_marker_texture()
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.set_meta("icon_path", _sky_marker_icon_path())
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset := int(maxf(4.0, marker.custom_minimum_size.y * 0.14))
	glyph.offset_left = inset
	glyph.offset_top = inset
	glyph.offset_right = -inset
	glyph.offset_bottom = -inset
	marker.add_child(glyph)
	marker.position = _sky_marker_pos(marker.custom_minimum_size)
	marker.pressed.connect(_on_sky_marker_pressed)
	if not Array(SkyLogic.grove_sky_state().get("owed", [])).is_empty():
		var pip := Label.new()
		pip.name = "OwedPip"
		pip.text = "*"
		pip.add_theme_font_size_override("font_size", int(maxf(10.0, csz * 0.16)))
		pip.add_theme_color_override("font_color", Pal.STRAW)
		pip.position = Vector2(marker.custom_minimum_size.x - 12.0, -4.0)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.add_child(pip)
	return marker

func _sky_marker_pos(marker_size: Vector2) -> Vector2:
	var lane := int(_sky_state.get("lane", 0))
	var lane_axis := String(_sky_state.get("lane_axis", "column"))
	var row_axis := lane_axis == "row"
	var anchor := Vector2i(lane, 0) if row_axis else Vector2i(0, lane)
	var lane_draws_horizontal := row_axis != _landscape
	if lane_draws_horizontal:
		var left_cell := _cell_pos(anchor)
		var pos := left_cell + Vector2(-marker_size.x - 6.0, (csz - marker_size.y) * 0.5)
		var board_global_x := board_area.get_global_rect().position.x if board_area != null and is_instance_valid(board_area) else 0.0
		pos.x = maxf(pos.x, SKY_MARKER_SCREEN_GUTTER - board_global_x)
		pos.x = minf(pos.x, 6.0 - marker_size.x)
		return pos
	var top_cell := _cell_pos(anchor)
	return top_cell + Vector2((csz - marker_size.x) * 0.5, -marker_size.y - 4.0)

func _sky_marker_icon_path() -> String:
	var rels: Dictionary = G.SKY_MARKER_ICON_RELS
	var rel := String(rels.get(String(_sky_state.get("sky", "sunbeam")), rels.get("sunbeam", "")))
	return Game.art(rel)

func _sky_marker_texture() -> Texture2D:
	var sky := String(_sky_state.get("sky", "sunbeam"))
	var path := _sky_marker_icon_path()
	if ResourceLoader.exists(path):
		return load(path)
	if _sky_marker_icon_cache.has(sky):
		return _sky_marker_icon_cache[sky]
	var tex := _draw_sky_marker_texture(sky)
	_sky_marker_icon_cache[sky] = tex
	return tex

func _draw_sky_marker_texture(sky: String) -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match sky:
		"rain":
			_paint_cloud_icon(img)
		"starfall":
			_paint_star_icon(img)
		_:
			_paint_sun_icon(img)
	return ImageTexture.create_from_image(img)

func _paint_sun_icon(img: Image) -> void:
	var gold := Color(Pal.STRAW, 1.0)
	var edge := Color(Pal.BARK, 0.72)
	var ctr := Vector2i(32, 32)
	for p in [Vector2i(32, 8), Vector2i(32, 56), Vector2i(8, 32), Vector2i(56, 32), Vector2i(15, 15), Vector2i(49, 15), Vector2i(15, 49), Vector2i(49, 49)]:
		_paint_line(img, ctr, p, edge, 2)
		_paint_line(img, ctr, p, gold, 1)
	_paint_circle(img, ctr, 17, edge)
	_paint_circle(img, ctr, 14, gold)

func _paint_cloud_icon(img: Image) -> void:
	var blue := Color(Pal.SKY, 1.0)
	var edge := Color(Pal.BARK, 0.70)
	for c in [Vector2i(24, 30), Vector2i(34, 24), Vector2i(44, 31)]:
		_paint_circle(img, c, 13, edge)
	for c in [Vector2i(24, 30), Vector2i(34, 24), Vector2i(44, 31)]:
		_paint_circle(img, c, 10, blue)
	_paint_rect(img, Rect2i(17, 30, 34, 13), edge)
	_paint_rect(img, Rect2i(19, 29, 30, 12), blue)
	for x in [22, 34, 46]:
		_paint_line(img, Vector2i(x, 47), Vector2i(x - 3, 56), edge, 2)
		_paint_line(img, Vector2i(x, 47), Vector2i(x - 3, 56), blue, 1)

func _paint_star_icon(img: Image) -> void:
	var gold := Color(Pal.STRAW, 1.0)
	var edge := Color(Pal.BARK, 0.72)
	var pts := [
		Vector2i(32, 7), Vector2i(39, 25), Vector2i(58, 25), Vector2i(43, 37),
		Vector2i(49, 57), Vector2i(32, 45), Vector2i(15, 57), Vector2i(21, 37),
		Vector2i(6, 25), Vector2i(25, 25),
	]
	_paint_polygon(img, pts, edge)
	var inner := []
	for p in pts:
		var v := Vector2(32, 32) + (Vector2(p) - Vector2(32, 32)) * 0.82
		inner.append(Vector2i(roundi(v.x), roundi(v.y)))
	_paint_polygon(img, inner, gold)

func _paint_rect(img: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_set_icon_pixel(img, x, y, color)

func _paint_circle(img: Image, center: Vector2i, radius: int, color: Color) -> void:
	var r2 := radius * radius
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if (Vector2i(x, y) - center).length_squared() <= r2:
				_set_icon_pixel(img, x, y, color)

func _paint_line(img: Image, a: Vector2i, b: Vector2i, color: Color, width: int) -> void:
	var steps := maxi(1, int((b - a).length()))
	for i in range(steps + 1):
		var p := Vector2(a).lerp(Vector2(b), float(i) / float(steps))
		_paint_circle(img, Vector2i(roundi(p.x), roundi(p.y)), width, color)

func _paint_polygon(img: Image, pts: Array, color: Color) -> void:
	var min_y := 64
	var max_y := 0
	for p in pts:
		min_y = mini(min_y, int(p.y))
		max_y = maxi(max_y, int(p.y))
	for y in range(min_y, max_y + 1):
		var nodes: Array = []
		var j := pts.size() - 1
		for i in pts.size():
			var pi: Vector2i = pts[i]
			var pj: Vector2i = pts[j]
			if (pi.y < y and pj.y >= y) or (pj.y < y and pi.y >= y):
				nodes.append(int(pi.x + float(y - pi.y) / float(pj.y - pi.y) * float(pj.x - pi.x)))
			j = i
		nodes.sort()
		for n in range(0, nodes.size(), 2):
			if n + 1 >= nodes.size():
				break
			for x in range(int(nodes[n]), int(nodes[n + 1]) + 1):
				_set_icon_pixel(img, x, y, color)

func _set_icon_pixel(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, color)

func _sky_info_title() -> String:
	return Strings.t("board.sky.%s.title" % String(_sky_state.get("sky", "sunbeam")))

func _sky_info_desc() -> String:
	if String(_sky_state.get("sky", "")) == SkyLogic.SKY_STARFALL and int(SkyLogic.grove_sky_state().get("pending", 0)) > 0:
		if _star_catch_cells().is_empty():
			return Strings.t("board.sky.starfall.blocked")
		return Strings.t("board.sky.starfall.catch")
	return Strings.t("board.sky.%s.desc" % String(_sky_state.get("sky", "sunbeam")))

func _weather_info_for_cell(cell: Vector2i) -> String:
	if not _is_weather_focus_cell(cell):
		return ""
	return "%s: %s" % [_sky_info_title(), _sky_info_desc()]

func _is_weather_focus_cell(cell: Vector2i) -> bool:
	if board == null or cell.x < 0 or _sky_state.is_empty() or not SkyLogic.gate_open() or not _weather_focus_sky():
		return false
	return board.in_bounds(cell) and SkyLogic.in_patch(_sky_state, cell)

func _write_sky_info_bar() -> void:
	if _info_label == null or not is_instance_valid(_info_label):
		return
	_place_info_button(false)
	_hide_mastery_info_row()
	_hide_soil_chips()
	_hide_seed_chips()
	_hide_improvement_chips()
	if _info_almanac != null and is_instance_valid(_info_almanac):
		_info_almanac.visible = false
	if _info_icon != null and is_instance_valid(_info_icon):
		for c in _info_icon.get_children():
			c.queue_free()
		var glyph := TextureRect.new()
		glyph.name = "SkyInfoGlyph"
		glyph.texture = _sky_marker_texture()
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.custom_minimum_size = Vector2(_info_item_px, _info_item_px)
		glyph.size = glyph.custom_minimum_size
		glyph.set_meta("icon_path", _sky_marker_icon_path())
		_info_icon.add_child(glyph)
	_info_label.text = _sky_info_title()
	if _info_desc_label != null and is_instance_valid(_info_desc_label):
		_info_desc_label.text = _sky_info_desc()
		_info_desc_label.visible = true
	if _info_btn != null and is_instance_valid(_info_btn):
		_info_btn.visible = false
		_info_btn.disabled = true
	if _info_trash != null and is_instance_valid(_info_trash):
		_info_trash.visible = false
	if _info_burst != null and is_instance_valid(_info_burst):
		_info_burst.visible = false
	if _info_buy != null and is_instance_valid(_info_buy):
		_info_buy.visible = false

func _select_sky_cell(cell: Vector2i) -> bool:
	if not _is_weather_focus_cell(cell):
		return false
	_selected_cell = cell
	_selected_improvement = false
	_show_focus(cell)
	_write_sky_info_bar()
	return true

func _on_sky_marker_pressed() -> void:
	_selected_cell = Vector2i(-1, -1)
	_selected_improvement = false
	_hide_focus()
	_write_sky_info_bar()

func _reconcile_starfall_pending_for_sky() -> void:
	var sky_save := SkyLogic.grove_sky_state()
	var pending := int(sky_save.get("pending", 0))
	if pending <= 0:
		_star_pending_started_secs = -1.0
		return
	var same_live_starfall := SkyLogic.gate_open() \
		and String(_sky_state.get("sky", "")) == SkyLogic.SKY_STARFALL \
		and int(_sky_state.get("hour", -1)) == int(sky_save.get("paid_hour", -2))
	if same_live_starfall:
		if _star_pending_started_secs < 0.0:
			_star_pending_started_secs = _sky_live_secs
		return
	_queue_pending_starfall_as_owed()
	Save.grove_write()

func _queue_pending_starfall_as_owed() -> int:
	var sky_save := SkyLogic.grove_sky_state()
	var code := int(sky_save.get("pending", 0))
	if code <= 0:
		return 0
	var owed: Array = sky_save.get("owed", [])
	owed.append(code)
	sky_save["owed"] = owed
	sky_save["pending"] = 0
	_star_pending_started_secs = -1.0
	_clear_starfall_catch_ui()
	return code

func _pending_star_code() -> int:
	return int(SkyLogic.grove_sky_state().get("pending", 0))

func _star_lane_cells() -> Array:
	return _sky_lane_cells()

func _star_catch_cells() -> Array:
	var out: Array = []
	if _pending_star_code() <= 0 or String(_sky_state.get("sky", "")) != SkyLogic.SKY_STARFALL or not SkyLogic.gate_open():
		return out
	for cell in _star_lane_cells():
		if board.is_empty_ground(Vector2i(cell)):
			out.append(Vector2i(cell))
	return out

## UNPARENT before freeing, never queue_free alone. `queue_free` runs at the end of the frame, so a node
## freed this way keeps its NAME until then — and a rebuild in the same frame (the roll re-derives the
## dock, then replays it as an arrival) would find the name taken and get "DockedStar2", which every
## `find_child("DockedStar")` then misses. `_sync_sky_patch_marker` already unparents for this reason.
func _free_now(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()

func _clear_starfall_catch_ui() -> void:
	_free_now(_sky_docked_star)
	_sky_docked_star = null
	for cell in _star_catch_nodes.keys():
		var node: Control = _star_catch_nodes[cell]
		if node != null and is_instance_valid(node):
			FX.breathe_stop(node)
			node.modulate = Color(1, 1, 1, 1)
			if node.has_meta("starfall_catch_cell"):
				node.remove_meta("starfall_catch_cell")
	_star_catch_nodes.clear()
	if board_area != null and is_instance_valid(board_area):
		for flight in board_area.find_children("DockedStarFlight", "Control", true, false):
			_free_now(flight)

## Re-derive §5.4's docked star and lit lane cells from save state — the ONE implementation of both.
## Two callers, and the flags are what separate them:
##   `_sync_sky_patch_marker` (false, false) — a plain re-derive: rebuild, reflow, orientation flip,
##      resume. The star is simply there; it did not just arrive, and the info bar is left alone.
##   `_try_starfall` (true, true) — §5.4's ARRIVAL BEAT: hold the dock hidden, fly the piece in from
##      off-screen, then auto-announce the catch line (only when nothing is selected).
func _sync_starfall_catch_ui(animate_arrival: bool, auto_announce: bool) -> void:
	_clear_starfall_catch_ui()
	var code := _pending_star_code()
	if code <= 0 or String(_sky_state.get("sky", "")) != SkyLogic.SKY_STARFALL:
		return
	if _sky_marker == null or not is_instance_valid(_sky_marker):
		return
	_sky_docked_star = _make_docked_star(code)
	_sky_docked_star.visible = not animate_arrival
	_sky_marker.add_child(_sky_docked_star)
	_start_docked_star_bob(_sky_docked_star)
	for cell in _star_catch_cells():
		var slot: Control = slot_nodes.get(Vector2i(cell))
		if slot != null and is_instance_valid(slot):
			slot.modulate = DRAG_HILITE
			slot.set_meta("starfall_catch_cell", true)
			FX.breathe_once(slot)
			_star_catch_nodes[Vector2i(cell)] = slot
	if animate_arrival:
		_play_star_arrival(code)
	if auto_announce and _selected_cell.x < 0:
		_on_sky_marker_pressed()

func _make_docked_star(code: int) -> Control:
	var n := _make_piece(code, csz)
	n.name = "DockedStar"
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scale := minf(0.58, maxf(0.34, (_sky_marker.size.y * 0.82) / csz))
	n.scale = Vector2(scale, scale)
	# POSITION BY CENTRE, never by the scaled visual's top-left. `Control.scale` scales about
	# `pivot_offset`, and PieceView pins every piece holder's pivot to its own centre — so the holder's
	# RENDERED top-left is `position + pivot_offset * (1 - scale)`, not `position`. Treating `position`
	# as the visual's top-left docked the star `csz * (1 - scale) / 2` (~42 px) down-and-right of the
	# chip, straddling the mat and covering the first cell row, while the node-tree arithmetic still read
	# as centred. Rendered centre is exactly `position + pivot_offset`, so solve for that instead — the
	# same identity `_star_marker_piece_pos` already relies on for the flight and landing pieces.
	n.pivot_offset = Vector2(csz, csz) * 0.5
	n.position = _sky_marker.size * 0.5 - n.pivot_offset
	n.z_index = 8
	return n

func _start_docked_star_bob(node: Control) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base := node.position
	var t := node.create_tween()
	t.set_loops()
	t.tween_property(node, "position", base + Vector2(0, -3.0), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "position", base + Vector2(0, 2.0), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Where a cell-sized piece holder must be POSITIONED for it to render centred on the marker chip.
## Pivot-true at any scale without a scale term: a piece holder pivots at its own centre, so its
## rendered centre is `position + csz/2` whatever `scale` is — the flight piece (0.55 → 0.42) and the
## landing piece (0.55 → 1.0) both ride this. Do not "correct" it by the scale factor.
func _star_marker_piece_pos() -> Vector2:
	if _sky_marker != null and is_instance_valid(_sky_marker):
		return _sky_marker.position + _sky_marker.size * 0.5 - Vector2(csz, csz) * 0.5
	return _cell_pos(_lane_center_cell())

func _star_arrival_start_pos() -> Vector2:
	var marker_pos := _star_marker_piece_pos()
	var board_rect := Rect2(Vector2.ZERO, Vector2(_board_w(), _board_h()))
	if _sky_marker != null and is_instance_valid(_sky_marker):
		if _sky_marker.position.x < board_rect.position.x:
			return Vector2(-csz * 1.55, marker_pos.y)
		if _sky_marker.position.y < board_rect.position.y:
			return Vector2(marker_pos.x, -csz * 1.55)
	return Vector2(marker_pos.x, -csz * 1.55)

func _play_star_arrival(code: int) -> void:
	if board_area == null or not is_instance_valid(board_area):
		return
	var fly := _make_piece(code, csz)
	fly.name = "DockedStarFlight"
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.scale = Vector2(0.55, 0.55)
	var from := _star_arrival_start_pos()
	var to := _star_marker_piece_pos()
	fly.position = from
	fly.z_index = 12
	board_area.add_child(fly)
	var t := MoveFx.apply(fly, from, to, "arc", _move_opts)
	if t == null:
		fly.queue_free()
		if _sky_docked_star != null and is_instance_valid(_sky_docked_star):
			_sky_docked_star.visible = true
		return
	t.parallel().tween_property(fly, "scale", Vector2(0.42, 0.42), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(func() -> void:
		if fly != null and is_instance_valid(fly):
			fly.queue_free()
		if _pending_star_code() == code and _sky_docked_star != null and is_instance_valid(_sky_docked_star):
			_sky_docked_star.visible = true)

## Take the star OFF the marker: clear `sky.pending`, stop the catch clock, tear down the dock and the
## lit lane rings. Shared by both resolutions — only WHERE it goes next differs.
func _take_pending_star() -> void:
	SkyLogic.grove_sky_state()["pending"] = 0
	_star_pending_started_secs = -1.0
	_clear_starfall_catch_ui()

## The shared tail of BOTH resolutions. A caught star and an uncaught one land the same piece on the same
## board, so everything downstream has to be identical: re-derive the marker (the owed pip may have just
## appeared or cleared), then the one post-mutation beat — magnet scans, the improvements reconcile, the
## owed-star drain, the persist and the HUD/fence refresh. The uncaught path used to only persist, so a
## star the player let time out quietly skipped half of what the same star caught would have run.
func _finish_star_resolution() -> void:
	_sync_sky_patch_marker(false)
	_after_board_change()

func _catch_pending_star_at(cell: Vector2i) -> bool:
	var code := _pending_star_code()
	if code <= 0 or not _star_catch_cells().has(cell):
		return false
	var from := _star_marker_piece_pos()
	_take_pending_star()
	_place_star_code_at(code, cell, from)
	_finish_star_resolution()
	return true

func _resolve_pending_starfall_uncaught() -> bool:
	var code := _pending_star_code()
	if code <= 0:
		return false
	var from := _star_marker_piece_pos()
	_take_pending_star()
	var landed := _land_star_code(code, from)
	if not landed:
		# §5.6's last resort — no free cell anywhere. It stays OWED and lands on the first
		# _after_board_change that finds one, any hour, persisting across restarts.
		var owed: Array = SkyLogic.grove_sky_state().get("owed", [])
		owed.append(code)
		SkyLogic.grove_sky_state()["owed"] = owed
	_finish_star_resolution()
	return landed

func _try_starfall() -> void:
	if _sky_state.is_empty() or String(_sky_state.get("sky", "")) != "starfall":
		return
	if _pending_star_code() > 0:
		if _star_pending_started_secs < 0.0:
			_star_pending_started_secs = _sky_live_secs
		if _sky_live_secs - _star_pending_started_secs < float(G.STAR_CATCH_SECS):
			return
		# The uncaught landing flies a piece in and runs the same landing recipe the roll does, so it
		# defers for the same two reasons the roll below does: a merge/land tween already owns the board,
		# or a dialog is covering it. Deferring never risks the star — it stays pending, and the next
		# 1 Hz tick (or the hour turn, or the board exit) resolves it the moment the board is free again.
		if animating or _modal_open():
			return
		_resolve_pending_starfall_uncaught()
		return
	if not SkyLogic.gate_open() or _sky_live_secs < float(G.STAR_DELAY) or animating or _modal_open():
		return
	var sky_save := SkyLogic.grove_sky_state()
	var hour := int(_sky_state.get("hour", -1))
	if hour <= int(sky_save.get("paid_hour", -1)):
		return
	var lines := _star_lines()
	var asked := BoardLogic.asked_items(quests)
	var code := SkyLogic.star_pick(hour, lines, asked)
	sky_save["paid_hour"] = hour
	if code > 0:
		sky_save["pending"] = code
		_star_pending_started_secs = _sky_live_secs
		_sync_sky_patch_marker(false)         # the marker must exist to dock onto, and its owed pip re-derives
		_sync_starfall_catch_ui(true, true)   # §5.4's arrival beat — fly it in, then announce
	Save.grove_write()

func _star_lines() -> Array:
	var out: Array = []
	for l in G.active_lines(_quest_level()):
		if not out.has(int(l)):
			out.append(int(l))
	for l in G.quest_needed_lines(_open_quest_lines()).keys():
		if not out.has(int(l)):
			out.append(int(l))
	return out

func _modal_open() -> bool:
	for child in get_children():
		if child is Control and (child as Control).visible and int((child as Control).z_index) >= Overlay.MODAL_Z:
			return true
	return false

func _land_owed_stars() -> bool:
	if _sky_state.is_empty() or not SkyLogic.gate_open():
		return false
	var sky_save := SkyLogic.grove_sky_state()
	var owed: Array = sky_save.get("owed", [])
	var landed := false
	while not owed.is_empty():
		var code := int(owed[0])
		if not _land_star_code(code):
			break
		owed.pop_front()
		landed = true
	sky_save["owed"] = owed
	if landed:
		_sync_sky_patch_marker(false)
	return landed

func _land_star_code(code: int, from_pos: Variant = null) -> bool:
	var cell := _star_landing_cell()
	if cell.x < 0:
		return false
	return _place_star_code_at(code, cell, from_pos)

func _place_star_code_at(code: int, cell: Vector2i, from_pos: Variant = null) -> bool:
	board.place(cell, code)
	_mark_seen(code)
	if board_area != null and is_instance_valid(board_area):
		var n := _make_piece(code, csz)
		var from: Vector2 = from_pos if from_pos is Vector2 else _star_start_pos(cell)
		var to := _cell_pos(cell)
		n.position = from
		n.scale = Vector2(0.55, 0.55)
		board_area.add_child(n)
		piece_nodes[cell] = n
		var t := MoveFx.apply(n, from, to, "arc", _move_opts)
		if t != null:
			t.parallel().tween_property(n, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var ctr := board_area.get_global_transform() * to + Vector2(csz, csz) / 2.0
			t.chain().tween_callback(func() -> void:
				if n and is_instance_valid(n):
					LandFx.apply(self, n, ctr, _land_opts, 0.9, false)
					Feel.ripple(_orthogonal_neighbour_nodes(cell), ctr, 0.9))
	return true

func _star_landing_cell() -> Vector2i:
	var lane_cells: Array = []
	var axis := String(_sky_state.get("lane_axis", "column"))
	var lane := int(_sky_state.get("lane", 0))
	if axis == "row":
		for c in G.COLS:
			var cell := Vector2i(lane, c)
			if board.is_open(cell) and board.item_at(cell) == 0 and not board.is_gen(cell):
				lane_cells.append(cell)
	else:
		for r in G.ROWS:
			var cell := Vector2i(r, lane)
			if board.is_open(cell) and board.item_at(cell) == 0 and not board.is_gen(cell):
				lane_cells.append(cell)
	if not lane_cells.is_empty():
		var rng_star := RandomNumberGenerator.new()
		rng_star.seed = int(absi(hash(int(_sky_state.get("hour", 0)) * 31337 + 19)))
		return lane_cells[rng_star.randi_range(0, lane_cells.size() - 1)]
	var rng_fallback := RandomNumberGenerator.new()
	rng_fallback.seed = int(absi(hash(int(_sky_state.get("hour", 0)) * 31337 + 29)))
	return BoardLogic.pick_drop_cell(board, _lane_center_cell(), rng_fallback)

func _lane_center_cell() -> Vector2i:
	var lane := int(_sky_state.get("lane", 0))
	if String(_sky_state.get("lane_axis", "column")) == "row":
		return Vector2i(lane, int(G.COLS / 2))
	return Vector2i(int(G.ROWS / 2), lane)

func _star_start_pos(cell: Vector2i) -> Vector2:
	var target := _cell_pos(cell)
	return Vector2(target.x, -csz * 1.4)

# After a quiet spell, a pair that can merge wiggles to show the next step
# (owner: ~5-10s of inactivity). Re-nudges gently while the player stays idle.
func _process(delta: float) -> void:
	if board == null:
		return
	# Watchdog: `animating` gates ALL board taps. Single merges should clear quickly; cascades reuse the
	# same gate across several paced steps, so each step gets its own longer callback guard.
	if animating:
		_anim_t += delta
		var watchdog_secs := CHAIN_STEP_WATCHDOG_SECS if _chain_active else ANIM_WATCHDOG_SECS
		if _anim_t > watchdog_secs:
			if _chain_active:
				_finish_chain()
				_after_board_change()
			else:
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
# Three one-time teaches, in ledger order: drag-to-merge, tap-the-generator, then (from L6)
# place-the-Soil-seed. Specs: docs/superpowers/specs/2026-07-23-ftue-hand-hint-design.md and
# §5 of 2026-07-26-cell-improvements-design.md.
#
# The soil teach runs as TWO beats behind ONE persisted key (`soil_seed`): id "soil_seed"
# points at the seed on the board, and once the seed is selected id "soil_place" moves the
# hand onto the info bar's Place chip. "soil_place" is transient — only "soil_seed" is ever
# written to the ledger, by Place (taught) or Sell (the seed is gone). Bagging DISMISSES
# without writing, so pulling the seed back out teaches again.
#
# Re-evaluated from BOTH _rebuild_all and _after_board_change: the latter is the real
# post-mutation fan-out, and a plain move/swap/stash does not rebuild, so hooking only the
# rebuild left the hand stranded on the vacated cell. A live hint RETARGETS rather than
# restarting, and both entry points are safe to have in flight at once.

func _maybe_hand_hint() -> void:
	if not Features.on("ftue_hand_hint"):
		_dismiss_hand_hint()   # the flag can flip off while a hint is live — tear it down, not stuck forever
		return
	if _hand_hint_ledger_complete():
		_dismiss_hand_hint()
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
	if Save.ftue_seen("soil") and not Save.ftue_seen("soil_seed"):
		if _soil_place_hint_ready():
			return "soil_place"
		if not _soil_seed_hint_cell().is_empty():
			return "soil_seed"
	var has_pair := not BoardLogic.find_mergeable_pair(board).is_empty()
	var has_gen := not gen_cell.is_empty()
	return HandHint.next_hint_id(Save.ftue_seen("merge"), Save.ftue_seen("gen_tap"), has_pair, has_gen)

# "No teach can possibly be live" — the cheap gate that lets _maybe_hand_hint bail BEFORE its
# frame await, since _after_board_change calls it on every board mutation. It reads the ledger
# only (no board scan), so it is deliberately a touch more permissive than _hand_hint_eligible:
# it may say "not complete" when the board happens to offer nothing, and eligibility then
# returns "" a frame later. It must never say "complete" while a teach could still fire.
#
# KEEP IN SYNC with _hand_hint_eligible(): a new teach added there and forgotten here is
# short-circuited before eligibility ever runs — it silently never appears, with no error and
# no failing test.
func _hand_hint_ledger_complete() -> bool:
	var soil_complete := not Save.ftue_seen("soil") or Save.ftue_seen("soil_seed")
	return Save.ftue_seen("merge") and Save.ftue_seen("gen_tap") and soil_complete

func _soil_place_hint_ready() -> bool:
	if _selected_cell.x < 0:
		return false
	if board.item_at(_selected_cell) != Improvements.seed_code_for_kind(Improvements.KIND_SOIL):
		return false
	return _info_seed_place != null and is_instance_valid(_info_seed_place) and _info_seed_place.visible

func _soil_seed_hint_cell() -> Array:
	var code := Improvements.seed_code_for_kind(Improvements.KIND_SOIL)
	for cell in piece_nodes.keys():
		if board.item_at(cell) == code:
			var n: Control = piece_nodes.get(cell)
			if n != null and is_instance_valid(n):
				return [cell]
	return []

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
	if id == "soil_seed":
		var seed_cell := _soil_seed_hint_cell()
		if seed_cell.is_empty():
			return []
		return [Rect2(), _cell_local_rect(seed_cell[0])]
	if id == "soil_place":
		if not _soil_place_hint_ready():
			return []
		return [_cell_local_rect(_selected_cell), _local_rect(_info_seed_place)]
	if gen_cell.is_empty():
		return []
	var gn: Control = gen_nodes.get(gen_cell[0])
	if gn == null or not is_instance_valid(gn):
		return []
	return [Rect2(), _local_rect(gn)]

func _cell_local_rect(cell: Vector2i) -> Rect2:
	if board_area == null or not is_instance_valid(board_area):
		return Rect2()
	var gp: Vector2 = board_area.get_global_transform() * _cell_pos(cell)
	return Rect2(gp - get_global_rect().position, Vector2(csz, csz))

func _local_rect(n: Control) -> Rect2:
	var gr := n.get_global_rect()
	return Rect2(gr.position - get_global_rect().position, gr.size)

func _dismiss_soil_seed_teach() -> void:
	if _hand_hint_id == "soil_seed" or _hand_hint_id == "soil_place":
		_dismiss_hand_hint()

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
	if _hand_hint_id == id or (id == "soil_seed" and _hand_hint_id == "soil_place"):
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
	if _drag_node != null or animating or _chain_active:
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
	var cfg: Dictionary = Game.kit_config()
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

func _sanitize_saved_bag_seed_ranks(raw: Array, items: Array) -> Dictionary:
	var out: Array = []
	var changed := raw.size() != items.size()
	for i in items.size():
		var code := int(items[i])
		var rank := int(raw[i]) if i < raw.size() else 1
		if Improvements.kind_for_seed(code) == Improvements.KIND_SOIL:
			var clamped := clampi(rank, 1, int(G.SOIL_MAX_RANK))
			out.append(clamped)
			if clamped != rank:
				changed = true
		else:
			out.append(1)
			if i < raw.size() and int(raw[i]) != 1:
				changed = true
	return {"ranks": out, "changed": changed}

# Save hygiene lives in core/save_migrate.gd (headless-testable; see engine/tests/save_migrate_tests.gd).
# This wrapper stays because it owns the scene's run-state: it feeds the model/bag/quests in and assigns
# the filtered arrays back. Returns true if anything was removed (→ the caller re-persists).
func _purge_above_level_content() -> bool:
	var r := SaveMigrate.purge_above_level_content(board, bag, quests, _quest_level())
	var kept_seed_ranks: Array = []
	for i in Array(r["bag_kept"]):
		kept_seed_ranks.append(int(bag_seed_ranks[int(i)]) if int(i) < bag_seed_ranks.size() else 1)
	bag = r["bag"]
	bag_seed_ranks = kept_seed_ranks      # PARALLEL to bag — filtered on the same surviving indices
	quests = r["quests"]
	return bool(r["changed"])

func _load_state() -> void:
	board = BoardModel.new()
	var now := Time.get_unix_time_from_system()
	var g := Save.grove()
	var save_dirty := SaveMigrate.sanitize_seen(g)
	if g.has("board"):
		save_dirty = board.from_dict(g["board"]) or save_dirty
		var quest_clean := SaveMigrate.sanitize_quests(Array(g.get("quests", [])))
		quests = quest_clean["quests"]
		save_dirty = bool(quest_clean["changed"]) or save_dirty
		quests_map = int(g.get("quests_map", -1))
		var bag_clean := SaveMigrate.sanitize_item_bag(Array(g.get("bag", [])))
		bag = bag_clean["items"]
		save_dirty = bool(bag_clean["changed"]) or save_dirty
		var seed_rank_clean := _sanitize_saved_bag_seed_ranks(Array(g.get("bag_seed_ranks", [])), bag)
		bag_seed_ranks = seed_rank_clean["ranks"]
		save_dirty = bool(seed_rank_clean["changed"]) or save_dirty
		# strip any generator/item/quest above the player's level under the scene-aligned cadence (migrates
		# older saves; idempotent no-op once clean). Runs after the board + quests + bag are loaded.
		save_dirty = _purge_above_level_content() or save_dirty
		rng.state = int(g.get("rng_state", 0))
		water = int(g.get("water", G.WATER_CAP))
		_regen_ts = float(g.get("regen_ts", now))
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
	save_dirty = _drain_scissors_pending() or save_dirty
	for v in board.items:                # everything already growing counts as met
		_mark_seen(int(v))
	for v in bag:
		_mark_seen(int(v))
	save_dirty = _reconcile_improvements(now, false) or save_dirty
	save_dirty = _scan_magnets(false) or save_dirty
	if save_dirty:
		_persist()

# --- the discovery log: which items has this player ever grown? -------------------
# Powers the upgrade-path card (unseen tiers show as "?"). The rules live in core/quests.gd; these
# wrappers only supply the Save read.

# The WRITE rule lives in Quests.mark_seen; the scene adds the LADDER BACKFILL — a Soil-grown or
# merged piece can be the first of its line the player ever holds, and an almanac ladder with holes
# below it reads as a bug. Marks every tier up to this code's.
func _mark_seen(code: int) -> void:
	if code <= 0 or G.is_coin(code):
		return
	var g := Save.grove()
	var line := BoardModel.line_of(code)
	for t in range(1, BoardModel.tier_of(code) + 1):
		Quests.mark_seen(g, line * 100 + t)

# [{tier, code, seen}] for a line's full ladder (pure — tests use it directly).
func _ladder_entries(line: int) -> Array:
	return Quests.ladder_entries(Save.grove().get("seen", {}), line)

# [{line, seen, in_pool, code}] for the Producing dialog.
func _gen_line_entries(gid: String) -> Array:
	return Quests.gen_line_entries(gid, Save.grove().get("seen", {}))

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

## Write the live board/quest/bag/water state. ORDINARY and NON-DESTRUCTIVE: a dozen mutation paths
## call this, so it must never consume a live catch. It deliberately does NOT resolve a pending Starfall
## — `sky.pending` is already on disk from the moment the star docks, and `_reconcile_starfall_pending_for_sky`
## decides on the next open whether it is still catchable or now owed, so nothing is lost by leaving it be.
## The one path that DOES resolve is the board exit; it says so out loud in `_persist_leaving_board`.
func _persist() -> void:
	var g := Save.grove()
	g["board"] = board.to_dict()
	g["quests"] = quests
	g["quests_map"] = quests_map
	g["bag"] = bag
	g["bag_seed_ranks"] = bag_seed_ranks
	g["rng_state"] = rng.state
	g["water"] = water
	g["regen_ts"] = _regen_ts
	Save.grove_write()

## §5.6's third fallback, in ONE place: leaving the board OWES a pending Starfall — it lands on the next
## board-change beat with a free cell, any hour, persisting across restarts — and then saves. This is the
## only caller that resolves; every other persist path leaves a live catch alone.
func _persist_leaving_board() -> void:
	_queue_pending_starfall_as_owed()
	_persist()

## The ONE board exit. Both Map nav taps (the NEXT UNLOCK strip and the Home disc) route through it, so a
## third one cannot quietly skip the leave beat above. grove_sky_tests pins that this is the file's only
## `SceneWarm.go`.
func _leave_board_for_map() -> void:
	_persist_leaving_board()
	SceneWarm.go(get_tree(), "res://engine/scenes/Map.tscn")

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
	_land_owed_stars()
	var changed := _reconcile_improvements(Time.get_unix_time_from_system(), false)
	if _scan_magnets():
		changed = true
		_reconcile_improvements(Time.get_unix_time_from_system(), false)
	var needs_rebuild := changed or (_rebuild_after_drag and not _drag_active())
	if needs_rebuild and board_area != null and is_instance_valid(board_area):
		if _drag_active():
			_rebuild_after_drag = true
			_rebuild_soil_overlays()
		else:
			_rebuild_after_drag = false
			_rebuild_all()
	_persist()
	if not hud_deferred:
		_update_hud()
	_refresh_giver_lights()
	_refresh_cascade_outline()
	_refresh_mastery_chrome()
	if _selected_cell.x >= 0 and board.is_gen(_selected_cell):
		_refresh_selected_generator_mastery()
	# FTUE: retarget or dismiss the teach after EVERY mutation, not just the ones that rebuild.
	# A move/swap/stash reparents the node and lands here without a rebuild, so hooking only
	# _rebuild_all left the hand bobbing over the cell the seed had just left. Cheap once the
	# ledger is complete — _hand_hint_ledger_complete() bails before the frame await.
	_maybe_hand_hint()

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
		"place_scissors": _shop_scissors_place,
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
	if _rebuild_after_drag and not _drag_active() and board_area != null and is_instance_valid(board_area):
		_rebuild_after_drag = false
		_rebuild_all()
	var before := water
	var now := Time.get_unix_time_from_system()
	_apply_regen(now)
	var changed := _reconcile_improvements(now, false)
	if changed and _scan_magnets(false):
		changed = true
	if changed and board_area != null and is_instance_valid(board_area):
		if _drag_active():
			_rebuild_after_drag = true
			_rebuild_soil_overlays()
		else:
			_rebuild_after_drag = false
			_rebuild_all()
	else:
		_rebuild_soil_overlays()
	_refresh_selected_soil_info()
	_update_water_hud()
	if water != before or changed:
		_persist()
	_tick_sky_hour()

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
	# "Empty" = can't pay the pop that was last refused (_water_short); with an unmastered 1💧 pop that
	# is exactly water<=0, so this is unchanged for rank-0 play. Self-clears once the can can pay again.
	if water >= _water_short:
		_water_short = 0
	var empty := water < maxi(1, _water_short)
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

# Send the player to the water STALL (free daily top-up / IAP). Falls back to the dead-end wobble only
# if the stall isn't wired (e.g. a test that neutralizes _open_water).
func _open_water_stall_or_wobble() -> void:
	if _open_water.is_valid():
		_open_water.call()
	else:
		FX.wobble(refill_btn)
		Audio.play("invalid_soft", -4.0)

func _on_refill() -> void:
	if water >= maxi(1, _water_short):   # water>0 for an unmastered 1💧 pop; see _water_short
		return
	if Claims.can_show("refill_water"):
		# Keep the claim ledger authoritative: the board's FREE action opens the same stall card
		# used everywhere else instead of bypassing the daily claim.
		_open_water_stall_or_wobble()
		return
	if not Save.spend_diamonds(G.REFILL_DIAMOND_COST):
		# empty, today's free rain unavailable, and too few 🌰 for the paid fill → open the water STALL
		# instead of the old dead-end wobble (§10 "no silent wall").
		_open_water_stall_or_wobble()
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
	FX.reward_arrival(self, refill_btn.get_global_rect().get_center(), "water", G.WATER_CAP, FX.reward_color("water"), water_target, refill_done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "board_refill")
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
		_leave_board_for_map()
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

# Refresh the face, then REWIND the fill to `previous_progress` and tween it forward to the live value.
func _animate_unlock_bar_from(previous_progress: float) -> void:
	if _unlock_bar == null or not is_instance_valid(_unlock_bar):
		return
	var now := _purge_progress()
	_update_unlock_bar()
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
		var over: Dictionary = Kit.giver_lay_from_config(Game.kit_config())
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

func _ensure_cascade_outline() -> Control:
	if not Features.on("cascade") or board_area == null or not is_instance_valid(board_area):
		if _cascade_outline != null and is_instance_valid(_cascade_outline):
			_cascade_outline.queue_free()
		_cascade_outline = null
		return null
	if _cascade_outline == null or not is_instance_valid(_cascade_outline) \
			or _cascade_outline.is_queued_for_deletion() or _cascade_outline.get_parent() != board_area:
		if _cascade_outline != null and is_instance_valid(_cascade_outline):
			if _cascade_outline.get_parent() != null:
				_cascade_outline.get_parent().remove_child(_cascade_outline)
			_cascade_outline.queue_free()
		_cascade_outline = CascadeOutline.new()
		board_area.add_child(_cascade_outline)
	_cascade_outline.configure(Vector2(_board_w(), _board_h()), csz, Callable(self, "_cell_pos"))
	_position_cascade_outline()
	return _cascade_outline

func _position_cascade_outline() -> void:
	if _cascade_outline == null or not is_instance_valid(_cascade_outline) \
			or _cascade_outline.get_parent() != board_area:
		return
	var insert_at := board_area.get_child_count() - 1
	for raw_node in gen_nodes.values() + piece_nodes.values():
		var n := raw_node as Node
		if n != null and is_instance_valid(n) and not n.is_queued_for_deletion() and n.get_parent() == board_area:
			insert_at = mini(insert_at, n.get_index())
	board_area.move_child(_cascade_outline, clampi(insert_at, 0, board_area.get_child_count() - 1))

func _armed_cascade_marks(entries: Array) -> Array:
	var out: Array = []
	for raw in entries:
		if raw is Dictionary and int((raw as Dictionary).get("n", 0)) >= CHAIN_MIN_N:
			out.append((raw as Dictionary).duplicate(true))
	return out

func _refresh_cascade_outline() -> void:
	if board == null or board_area == null or not is_instance_valid(board_area):
		return
	var outline := _ensure_cascade_outline()
	if outline == null:
		return
	outline.set_ladders(_armed_cascade_marks(BoardLogic.ready_ladders(board)))
	outline.set_runways(BoardLogic.runways(board, CHAIN_MIN_N))

func _show_cascade_drag_guides(from: Vector2i) -> void:
	if not Features.on("cascade") or board == null or board.is_gen(from):
		return
	var code := board.item_at(from)
	if code <= 0:
		return
	var occupied := {}
	var pads := _merge_target_pads(from)
	var fires := false
	for raw_pad in pads:
		if raw_pad is Dictionary:
			occupied[Vector2i((raw_pad as Dictionary).get("cell", Vector2i(-1, -1)))] = true
			fires = fires or String((raw_pad as Dictionary).get("kind", "")) == "cascade"
	# Everything below lands on an EMPTY cell, and dropping on an empty cell is a move — it never
	# reaches _prepare_chain, so it fires nothing. These are STAGING marks: they say "put it here
	# and the ladder grows", never "put it here and it goes off". Hence kind, and hence no ×n:
	# a number on an empty cell advertises a cascade the drop does not perform.
	var staged: Array = []
	for raw in BoardLogic.chain_placements(board, from, code):
		if raw is Dictionary:
			var entry: Dictionary = (raw as Dictionary).duplicate(true)
			if int(entry.get("n", 0)) < CHAIN_MIN_N:
				continue
			entry["line"] = BoardModel.line_of(code)
			entry["kind"] = "stage"
			staged.append(entry)
			occupied[Vector2i(entry.get("cell", Vector2i(-1, -1)))] = true
	staged.append_array(_cascade_extension_pads(from, code, occupied))
	# One place for the eye: when the held piece has a merge that actually cascades, that target is
	# the answer, so the staging cells around it are noise competing with it.
	if not fires:
		pads.append_array(staged)
	var outline := _ensure_cascade_outline()
	if outline != null:
		outline.set_ghost_pads(pads)

func _merge_target_pads(from: Vector2i) -> Array:
	var out: Array = []
	if board == null:
		return out
	var code := board.item_at(from)
	if code <= 0:
		return out
	for raw_target in piece_nodes.keys():
		var target := Vector2i(raw_target)
		if target == from or not board.can_merge(from, target):
			continue
		var n := 1 + BoardLogic.chain_path(board, from, target).size()
		var entry := {
			"cell": target,
			"line": BoardModel.line_of(code),
			# The ONLY mark that carries a ×n: an occupied cell you can drop onto, whose merge
			# really does run a chain. Anything short of CHAIN_MIN_N is an ordinary merge.
			"kind": "cascade" if n >= CHAIN_MIN_N else "merge",
			"n": maxi(2, n),
		}
		out.append(entry)
	out.sort_custom(func(a, b): return BoardModel.idx(Vector2i((a as Dictionary).get("cell", Vector2i.ZERO))) < BoardModel.idx(Vector2i((b as Dictionary).get("cell", Vector2i.ZERO))))
	return out

func _cascade_extension_pads(from: Vector2i, code: int, occupied: Dictionary) -> Array:
	var out: Array = []
	var line := BoardModel.line_of(code)
	var components: Array = []
	for raw in _armed_cascade_marks(BoardLogic.ready_ladders(board)):
		if raw is Dictionary and int((raw as Dictionary).get("line", 0)) == line:
			components.append({"cells": Array((raw as Dictionary).get("cells", [])), "line": line})
	for raw in BoardLogic.runways(board, CHAIN_MIN_N):
		if raw is Dictionary and int((raw as Dictionary).get("line", 0)) == line:
			components.append({"cells": Array((raw as Dictionary).get("cells", [])), "line": line})
	var seen := {}
	for comp in components:
		for entry in _extension_pads_for_component(from, code, Array((comp as Dictionary).get("cells", [])), occupied):
			var cell := Vector2i((entry as Dictionary).get("cell", Vector2i(-1, -1)))
			if cell.x < 0 or seen.has(cell):
				continue
			seen[cell] = true
			out.append(entry)
	out.sort_custom(func(a, b): return BoardModel.idx(Vector2i((a as Dictionary).get("cell", Vector2i.ZERO))) < BoardModel.idx(Vector2i((b as Dictionary).get("cell", Vector2i.ZERO))))
	return out

func _extension_pads_for_component(from: Vector2i, code: int, cells: Array, occupied: Dictionary) -> Array:
	var out: Array = []
	if cells.is_empty():
		return out
	var held_tier := BoardModel.tier_of(code)
	var min_tier := 9999
	var max_tier := -1
	for raw in cells:
		var tier := BoardModel.tier_of(board.item_at(Vector2i(raw)))
		min_tier = mini(min_tier, tier)
		max_tier = maxi(max_tier, tier)
	var edge_tier := -1
	if held_tier == min_tier - 1:
		edge_tier = min_tier
	elif held_tier == max_tier + 1:
		edge_tier = max_tier
	else:
		return out
	for raw in cells:
		var base := Vector2i(raw)
		if BoardModel.tier_of(board.item_at(base)) != edge_tier:
			continue
		for raw_d in BoardLogic.ORTHO_DIRS:
			var cell := base + Vector2i(raw_d)
			if not _can_show_extension_pad(cell, from, occupied):
				continue
			out.append({"cell": cell, "line": BoardModel.line_of(code), "kind": "stage"})
	return out

func _can_show_extension_pad(cell: Vector2i, from: Vector2i, occupied: Dictionary) -> bool:
	if cell == from or occupied.has(cell) or board == null or not board.in_bounds(cell):
		return false
	if not board.is_empty_ground(cell):
		return false
	return not board.gens.has(cell)

func _clear_cascade_drag_guides() -> void:
	if _cascade_outline != null and is_instance_valid(_cascade_outline):
		_cascade_outline.clear_guides()

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
				or _recipe_merge_code(board.item_at(from), board.item_at(target)) > 0 \
				or (Features.on("scissors") and BoardActions.can_split_piece(board, from, target))
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
	_refresh_sky_state()
	_grow_generators()                        # a staged second generator grows in once its level is reached
	_sync_accumulators()                      # §6.C place any newly-unlocked utility accumulators
	for n in board_area.get_children():
		n.queue_free()
	slot_nodes.clear()
	piece_nodes.clear()
	bramble_nodes.clear()
	_focus_ring = null
	_improvement_art_nodes.clear()
	_soil_overlay_nodes.clear()
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
	_rebuild_improvement_art()
	_sync_sky_patch_marker(false)
	_refresh_cascade_outline()
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
	_rebuild_soil_overlays()
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
	var panel: Control = Kit.board_panel(size, Kit.board_panel_opts_from_config(Game.kit_config()))
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

func _improvements_enabled() -> bool:
	return Features.on("improvements")

func _load_optional_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var import_path := path + ".import"
	if FileAccess.file_exists(import_path):
		var cfg := ConfigFile.new()
		if cfg.load(import_path) == OK:
			var remap := String(cfg.get_value("remap", "path", ""))
			if remap != "" and not FileAccess.file_exists(remap):
				return null
	return ResourceLoader.load(path) as Texture2D

func _reconcile_improvements(now: float = -1.0, render := true) -> bool:
	if board == null or not _improvements_enabled():
		return false
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var before := _improvements_state_key()
	var grown: Array = board.reconcile_improvements(now)
	var after := _improvements_state_key()
	for cell in grown:
		_mark_seen(board.item_at(cell))
	var changed := before != after or not grown.is_empty()
	if render and board_area != null and is_instance_valid(board_area):
		_rebuild_soil_overlays()
	return changed

func _improvements_state_key() -> String:
	if board == null:
		return ""
	var rows: Array = []
	for raw_cell in board.improvements.keys():
		var cell := Vector2i(raw_cell)
		var row := board.improvement_at(cell)
		rows.append([
			cell.x,
			cell.y,
			String(row.get("kind", "")),
			int(row.get("rank", 1)),
			int(row.get("code", 0)),
			float(row.get("ends_at", 0.0)),
			bool(row.get("watered", false)),
		])
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) == int(b[0]):
			return int(a[1]) < int(b[1])
		return int(a[0]) < int(b[0]))
	return str(rows)

func _improvement_cells(kind: String = "") -> Array:
	var out: Array = []
	if board == null:
		return out
	for raw_cell in board.improvements.keys():
		var cell := Vector2i(raw_cell)
		var row := board.improvement_at(cell)
		if kind == "" or String(row.get("kind", "")) == kind:
			out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return BoardModel.idx(a) < BoardModel.idx(b))
	return out

func _clear_improvement_art() -> void:
	for n in _improvement_art_nodes.values():
		if n != null and is_instance_valid(n):
			n.queue_free()
	_improvement_art_nodes.clear()

func _rebuild_improvement_art() -> void:
	_clear_improvement_art()
	if board == null or board_area == null or not _improvements_enabled():
		return
	for cell in _improvement_cells():
		var row := board.improvement_at(cell)
		var art := _make_improvement_art(cell, row)
		board_area.add_child(art)
		_improvement_art_nodes[cell] = art

func _make_improvement_art(cell: Vector2i, row: Dictionary) -> Control:
	var kind := String(row.get("kind", ""))
	var holder := Control.new()
	holder.name = "ImprovementArt_%d_%d" % [cell.x, cell.y]
	holder.position = _cell_pos(cell)
	holder.custom_minimum_size = Vector2(csz, csz)
	holder.size = Vector2(csz, csz)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_meta("improvement_kind", kind)
	var texture_path := Look.kit("kit/cell_soil.png" if kind == Improvements.KIND_SOIL else "kit/cell_magnet.png")
	var texture := _load_optional_texture(texture_path)
	if texture != null:
		var tex := TextureRect.new()
		tex.texture = texture
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tex)
	else:
		var panel := Panel.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#8A6A3B") if kind == Improvements.KIND_SOIL else Color("#60737F")
		sb.border_color = Color(Pal.INK, 0.18)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(maxi(8, int(roundf(csz * 0.16))))
		panel.add_theme_stylebox_override("panel", sb)
		holder.add_child(panel)
	if kind == Improvements.KIND_SOIL:
		_add_soil_pips(holder, int(row.get("rank", 1)))
	return holder

func _add_soil_pips(holder: Control, rank: int) -> void:
	var pip_path := Look.kit("kit/pip_leaf.png")
	var pip_tex := _load_optional_texture(pip_path)
	var pip_px := clampf(csz * 0.16, 12.0, 22.0)
	for i in clampi(rank, 1, int(G.SOIL_MAX_RANK)):
		var pip: Control
		if pip_tex != null:
			var t := TextureRect.new()
			t.texture = pip_tex
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pip = t
		else:
			var p := Panel.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Pal.BTN_PRIMARY
			sb.border_color = Pal.BTN_PRIMARY_EDGE
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(int(roundf(pip_px * 0.50)))
			p.add_theme_stylebox_override("panel", sb)
			pip = p
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.custom_minimum_size = Vector2(pip_px, pip_px)
		pip.size = Vector2(pip_px, pip_px)
		pip.position = Vector2(6.0 + float(i) * (pip_px * 0.72), csz - pip_px - 6.0)
		holder.add_child(pip)

func _clear_soil_overlays() -> void:
	for n in _soil_overlay_nodes.values():
		if n != null and is_instance_valid(n):
			n.queue_free()
	_soil_overlay_nodes.clear()

func _rebuild_soil_overlays() -> void:
	_clear_soil_overlays()
	if board == null or board_area == null or not _improvements_enabled():
		return
	for cell in board.growing_cells():
		var ov := _make_soil_overlay(cell)
		board_area.add_child(ov)
		_soil_overlay_nodes[cell] = ov

func _make_soil_overlay(cell: Vector2i) -> Control:
	var holder := Control.new()
	holder.name = "SoilProgress_%d_%d" % [cell.x, cell.y]
	holder.position = _cell_pos(cell)
	holder.custom_minimum_size = Vector2(csz, csz)
	holder.size = Vector2(csz, csz)
	holder.z_index = 12
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_meta("soil_progress", true)
	var ring := SoilProgressRing.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Contrast, not decoration. The old LEAF-on-earth ring (0.18 track / 0.86 fill) measured 1.17:1
	# against its own backdrop — invisible over 91% of the arc, and worse at phone size. A mid-tone
	# green cannot win against BOTH the warm earth patch and the piece art sitting on it, so the ring
	# stops relying on the backdrop: a dark INK groove carries the track and outlines the fill (see
	# soil_progress_ring.outline_width), and the fill is a LIGHT green that pops out of that groove.
	ring.line_width = maxf(4.0, csz * 0.062)
	ring.outline_width = maxf(1.5, csz * 0.017)
	ring.track_color = Color(Pal.INK, 0.55)
	ring.fill_color = Pal.MEADOW
	ring.progress = _soil_progress_fraction(cell)
	holder.add_child(ring)
	var remaining := board.soil_remaining(cell, Time.get_unix_time_from_system())
	if remaining >= 900.0:
		var chip := PanelContainer.new()
		chip.name = "SoilTimeChip"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(Pal.CREAM, 0.94)
		csb.border_color = Color(Pal.INK, 0.22)
		csb.set_border_width_all(1)
		csb.set_corner_radius_all(8)
		csb.content_margin_left = 7
		csb.content_margin_right = 7
		csb.content_margin_top = 3
		csb.content_margin_bottom = 3
		chip.add_theme_stylebox_override("panel", csb)
		var lbl := Label.new()
		lbl.text = _format_improvement_time_short(remaining)
		lbl.add_theme_font_size_override("font_size", FS.FINE)
		lbl.add_theme_color_override("font_color", Pal.INK)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(lbl)
		# Keep the countdown INSIDE its own cell. It used to sit at a hand-placed (0.56·csz, -0.05·csz),
		# which pushed a ~72px chip past the cell's right edge and 6px ABOVE its top — the countdown
		# clipped into the neighbouring cell above. Anchored to the cell's top-right with a small inset
		# and grown LEFT/DOWN instead, so a wider label ("2d 3h") eats into its OWN cell. The preset runs
		# after the label is parented because PRESET_MODE_MINSIZE measures the chip's minimum size.
		var chip_inset := maxi(3, int(roundf(csz * 0.045)))
		chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, chip_inset)
		chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		chip.grow_vertical = Control.GROW_DIRECTION_END
		holder.add_child(chip)
	return holder

func _soil_progress_fraction(cell: Vector2i) -> float:
	var row := board.improvement_at(cell)
	var code := int(row.get("code", 0))
	if code <= 0:
		return 0.0
	var duration := Improvements.soil_step_seconds(code, int(row.get("rank", 1)))
	if duration <= 0.0:
		return 1.0
	var remaining := board.soil_remaining(cell, Time.get_unix_time_from_system())
	return 1.0 - clampf(remaining / duration, 0.0, 1.0)

func _format_improvement_time(secs: float) -> String:
	var s := int(ceil(maxf(0.0, secs)))
	if s <= 0:
		return "ready"
	var days := int(s / 86400)
	s %= 86400
	var hours := int(s / 3600)
	s %= 3600
	var mins := int(s / 60)
	if days > 0:
		return "%dd %dh" % [days, hours]
	if hours > 0:
		return "%dh %dm" % [hours, mins] if mins > 0 else "%dh" % hours
	if mins > 0:
		return "%dm" % mins
	return "%ds" % s

func _format_improvement_time_short(secs: float) -> String:
	var s := int(ceil(maxf(0.0, secs)))
	if s >= 86400:
		return "%dd" % int(ceil(float(s) / 86400.0))
	if s >= 3600:
		return "%dh" % int(ceil(float(s) / 3600.0))
	if s >= 60:
		return "%dm" % int(ceil(float(s) / 60.0))
	return "%ds" % s

func _soil_info_title(cell: Vector2i) -> String:
	var code := board.item_at(cell)
	var row := board.improvement_at(cell)
	var target := mini(int(G.merge_top(code)), BoardModel.tier_of(code) + Improvements.grow_amount(int(row.get("rank", 1))))
	return "Growing to t%d - %s" % [target, _format_improvement_time(board.soil_remaining(cell, Time.get_unix_time_from_system()))]

func _place_seed(cell: Vector2i) -> bool:
	if not _improvements_enabled():
		return false
	var seed_kind := Improvements.kind_for_seed(board.item_at(cell))
	var out := BoardActions.place_seed(board, cell)
	if not bool(out.get("placed", false)):
		Audio.play("invalid_soft", -6.0)
		if _info_seed_place != null and is_instance_valid(_info_seed_place):
			FX.wobble(_info_seed_place)
		return false
	if seed_kind == Improvements.KIND_SOIL:
		_end_hand_hint("soil_seed")
	Audio.play("button_tap", -2.0)
	_rebuild_all()
	_after_board_change()
	_select_improvement_cell(cell)
	var art: Control = _improvement_art_nodes.get(cell)
	if art != null and is_instance_valid(art):
		FX.pop(art)
	return true

func _on_seed_place() -> void:
	if _selected_cell.x >= 0:
		_place_seed(_selected_cell)

func _on_seed_bag() -> void:
	if _selected_cell.x < 0:
		return
	var node: Control = piece_nodes.get(_selected_cell)
	if node == null or not is_instance_valid(node):
		return
	_stash(_selected_cell, node)
	_clear_selection()

func _select_improvement_cell(cell: Vector2i) -> void:
	if not board.has_improvement(cell) or board.item_at(cell) > 0:
		_clear_selection()
		return
	_selected_cell = cell
	_selected_improvement = true
	_show_focus(cell)
	if _info_burst != null and is_instance_valid(_info_burst):
		_info_burst.visible = false
	if _info_buy != null and is_instance_valid(_info_buy):
		_info_buy.visible = false
	if _info_trash != null and is_instance_valid(_info_trash):
		_info_trash.visible = false
	_hide_seed_chips()
	_hide_soil_chips()
	_place_info_button(false)
	var row := board.improvement_at(cell)
	var kind := String(row.get("kind", ""))
	for c in _info_icon.get_children():
		c.queue_free()
	var seed_code := Improvements.seed_code_for_kind(kind)
	if seed_code > 0:
		_info_icon.add_child(PieceView.make_piece(seed_code, _info_item_px, 0.0))
	_info_label.text = "Soil rank %d" % int(row.get("rank", 1)) if kind == Improvements.KIND_SOIL else "Magnet"
	if _info_desc_label != null and is_instance_valid(_info_desc_label):
		var cap := Improvements.cap_for(kind)
		_info_desc_label.text = "%d/%d placed" % [board.improvement_count(kind), cap]
		_info_desc_label.visible = true
	_info_btn.visible = false
	_info_btn.disabled = true
	_refresh_improvement_chips(cell)

func _unsocket_improvement(cell: Vector2i) -> bool:
	if _defer_soil_reset([cell], "Unsocket", func() -> void: _unsocket_improvement_confirmed(cell)):
		return false
	return _unsocket_improvement_confirmed(cell)

func _unsocket_improvement_confirmed(cell: Vector2i) -> bool:
	var out := BoardActions.unsocket_improvement(board, cell)
	if not bool(out.get("unsocketed", false)):
		Audio.play("invalid_soft", -6.0)
		if _info_unsocket != null and is_instance_valid(_info_unsocket):
			FX.wobble(_info_unsocket)
		return false
	Audio.play("button_tap", -2.0)
	_rebuild_all()
	_after_board_change()
	if board.item_at(cell) > 0:
		_select_item(cell)
	return true

func _on_unsocket_improvement() -> void:
	if _selected_cell.x >= 0:
		_unsocket_improvement(_selected_cell)

func _on_soil_rank() -> void:
	if _selected_cell.x >= 0:
		_rank_soil(_selected_cell)

func _rank_soil(cell: Vector2i) -> bool:
	var out := BoardActions.rank_soil(board, cell)
	if not bool(out.get("ranked", false)):
		if _info_soil_rank != null and is_instance_valid(_info_soil_rank):
			FX.wobble(_info_soil_rank)
		Audio.play("invalid_soft", -6.0)
		return false
	_rebuild_all()
	_after_board_change()
	if board.has_improvement(cell) and board.item_at(cell) == 0:
		_select_improvement_cell(cell)
	return true

func _water_soil(cell: Vector2i, now: float = -1.0) -> bool:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	if water < int(G.SOIL_WATER_COST):
		if _info_soil_water != null and is_instance_valid(_info_soil_water):
			FX.wobble(_info_soil_water)
		Audio.play("invalid_soft", -6.0)
		return false
	var out := BoardActions.water_soil(board, cell, now)
	if not bool(out.get("watered", false)):
		return false
	water -= int(G.SOIL_WATER_COST)
	_update_water_hud()
	_after_board_change()
	_refresh_selected_soil_info()
	return true

func _on_soil_water() -> void:
	if _selected_cell.x >= 0:
		_water_soil(_selected_cell)

func _chain_armed_cell() -> Vector2i:
	if chain_running() and not _chain_run.is_empty():
		return Vector2i(_chain_run[0])
	return Vector2i(-1, -1)

func _scan_magnets(render := true) -> bool:
	if _magnet_scanning or not _improvements_enabled() or board == null:
		return false
	_magnet_scanning = true
	var changed := false
	var guard := 0
	while guard < 64:
		var merged_any := false
		for magnet_cell in _improvement_cells(Improvements.KIND_MAGNET):
			var out := BoardActions.magnet_merge_once(board, magnet_cell, _asked_codes(), board.growing_cells(), _chain_armed_cell())
			if not bool(out.get("merged", false)):
				continue
			_mark_seen(int(out.get("code", 0)))
			_after_magnet_merge(out, render)
			changed = true
			merged_any = true
			break
		if not merged_any:
			break
		guard += 1
	_magnet_scanning = false
	return changed

func _after_magnet_merge(out: Dictionary, render := true) -> void:
	var target := Vector2i(out.get("to", Vector2i(-1, -1)))
	if target.x < 0:
		return
	var opened: Array = board.openable_brambles(target, _quest_level())
	if opened.is_empty():
		return
	for cell in opened:
		if render and board_area != null and is_instance_valid(board_area):
			_open_bramble(cell, true)
		else:
			var contents := board.open_bramble(cell, -1)
			_mark_seen(contents)
	if render:
		_refresh_locked_cells()

func _maybe_soil_ftue() -> void:
	if not _improvements_enabled() or Save.ftue_seen("soil") or not Save.board_tutorial_seen():
		return
	if G.level() < 6:
		return
	var code := Improvements.seed_code_for_kind(Improvements.KIND_SOIL)
	var granted := false
	var has_path := _has_unplaced_seed(Improvements.KIND_SOIL) \
		or board.improvement_count(Improvements.KIND_SOIL) >= Improvements.cap_for(Improvements.KIND_SOIL)
	if not has_path:
		var dest := Vector2i(-1, -1)
		for c in board.empty_ground_cells():
			if board.can_build_improvement(c):
				dest = c
				break
		if dest.x >= 0:
			board.place(dest, code)
			granted = true
		elif bag.size() < _bag_capacity():
			_bag_append(code)
			granted = true
		if not granted:
			_maybe_hand_hint()
			return
	Save.mark_ftue_seen("soil")
	if granted:
		_rebuild_all()
		_after_board_change()
	else:
		_maybe_hand_hint()
	if is_inside_tree():
		FX.floating_text(self, Vector2(get_global_rect().get_center().x - 260, 220), "A seed of good earth! Tap it to choose a spot.", CREAM, FS.BODY)

func _has_unplaced_seed(kind: String) -> bool:
	var code := Improvements.seed_code_for_kind(kind)
	if code <= 0:
		return false
	for v in board.items:
		if int(v) == code:
			return true
	for v in bag:
		if int(v) == code:
			return true
	return false

func _soil_reset_confirm_cell(cells: Array) -> Vector2i:
	if board == null or not _improvements_enabled():
		return Vector2i(-1, -1)
	for raw_cell in cells:
		var cell := Vector2i(raw_cell)
		if board.is_growing(cell) and board.growing_from_tier(cell) >= 7:
			return cell
	return Vector2i(-1, -1)

func _defer_soil_reset(cells: Array, verb: String, proceed: Callable, cancel: Callable = Callable()) -> bool:
	var cell := _soil_reset_confirm_cell(cells)
	if cell.x < 0:
		return false
	_show_soil_reset_confirm(cell, verb, proceed, cancel)
	return true

func _show_soil_reset_confirm(cell: Vector2i, verb: String, proceed: Callable, cancel: Callable = Callable()) -> void:
	if Overlay.is_open(self, "SoilResetConfirm"):
		return
	var m := Overlay.modal(self, "SoilResetConfirm", {"ink": Pal.GROUND_EDGE, "alpha": 0.50, "dismissable": false})
	var card := PanelContainer.new()
	card.name = "SoilResetCard"
	card.set_meta("soil_reset_confirm", true)
	card.custom_minimum_size = Vector2(460, 230)
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	var title := Label.new()
	title.text = "Keep growing?"
	title.add_theme_font_size_override("font_size", FS.HEADING)
	title.add_theme_color_override("font_color", Pal.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var msg := Label.new()
	msg.text = "This restarts %s of growing. %s it anyway?" % [_format_improvement_time(board.soil_remaining(cell, Time.get_unix_time_from_system())), verb]
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", FS.BODY)
	msg.add_theme_color_override("font_color", Pal.INK)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var keep_action := func() -> void:
		if m.dismiss.is_valid():
			m.dismiss.call()
		if cancel.is_valid():
			cancel.call()
	var go_action := func() -> void:
		if m.dismiss.is_valid():
			m.dismiss.call()
		if proceed.is_valid():
			proceed.call()
	row.add_child(Look.button("Keep growing", keep_action, true))
	var go := Look.button("%s it" % verb, go_action, false)
	go.name = "SoilResetConfirmGo"
	row.add_child(go)
	(m.center as CenterContainer).add_child(card)

func _rebuild_action_bar_row(row: HBoxContainer, bottom_btn_px: float, action_opts: Dictionary, bottom_bar_h: float, preserve_selection: bool) -> void:
	if row == null:
		return
	var prior_selection := _selected_cell
	var prior_improvement := _selected_improvement
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
		if prior_improvement and board.has_improvement(prior_selection) and board.item_at(prior_selection) == 0:
			_select_improvement_cell(prior_selection)
		elif board.is_gen(prior_selection):
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
	var bag_opts: Dictionary = KitB.action_button_opts_from_config(Game.kit_config())
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

# The kit's RESOLVED hud_layout dials, or {} on a kit-less build. The kit's resolver owns every
# default percentage (games/grove/ui_kit.gd: hud_layout_opts_from_config) — the three sizers below
# keep NO private copy of one; kit-less they fall back to their own engine constant instead.
func _hud_layout() -> Dictionary:
	var Kit: GDScript = KIT
	if Kit == null:
		return {}
	return Kit.hud_layout_opts_from_config(Game.kit_config())

func _bottom_button_px() -> float:
	var lay := _hud_layout()
	# Kit-less: the ActionBar fallback well size stands in (BOTTOM_BTN_PX is exactly that fallback).
	var px := BOTTOM_BTN_PX if lay.is_empty() else roundf(_view_size().x * float(lay.button_w_frac))
	# Bounded: a min so it stays tappable on narrow screens, a max so it (and the bar) can't balloon on
	# wide ones — capped to leave the bar within BOTTOM_BAR_MAX (button + pad).
	return clampf(px, BOTTOM_BTN_MIN, BOTTOM_BAR_MAX - BOTTOM_BAR_PAD)

func _bottom_bar_h_px(bottom_btn_px: float) -> float:
	var raw := maxf(BOTTOM_BAR_H, bottom_btn_px + BOTTOM_BAR_PAD)
	var lay := _hud_layout()
	if lay.has("bottom_row_h_frac"):
		# 0 means "unset" for this dial (the resolver's own default) — the button+pad height stands.
		var frac := float(lay.bottom_row_h_frac)
		if frac > 0.0:
			raw = maxf(bottom_btn_px, roundf(_view_size().y * frac))
	# Capped: never too short to hold the wells, never tall enough to look weird on wide screens.
	return clampf(raw, BOTTOM_BAR_MIN, BOTTOM_BAR_MAX)

func _quest_row_h_px() -> float:
	var lay := _hud_layout()
	# Scale with screen HEIGHT (taller screens → taller band, absorbing spare vertical room) and clamp.
	# Cards pack to fit the WIDTH (see _rebuild_givers), so the band height no longer keys off width.
	# Kit-less: FENCE_H, the engine's own fence band (the seed of _fence_h, which this drives).
	var h := FENCE_H if lay.is_empty() else roundf(_view_size().y * float(lay.quest_bar_h_frac))
	return clampf(h, QUEST_H_MIN, QUEST_H_MAX)

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
		_leave_board_for_map()
	var b: Button
	var KitH: GDScript = KIT
	if KitH != null:
		# the shared code-drawn action button (CutPaperPanel rugged edge + centered home glyph) — the
		# same builder the home bottom bar uses, so the two read identically off one source.
		var ho: Dictionary = KitH.action_button_opts_from_config(Game.kit_config())
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
	var opts: Dictionary = Kit.info_bar_opts_from_config(Game.kit_config())
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
	_install_mastery_info_row()
	_capture_info_button_positions()
	_build_burst_chip(opts, _info_trash.get_parent())   # T54: the burst-upgrade chip rides the sell button's slot (generators)
	_build_buy_chip(opts, _info_trash.get_parent())     # T55: the buy-a-copy chip sits just LEFT of the sell button (items)
	_build_seed_chips(opts, _info_trash.get_parent())   # Improvement seeds: Place + Bag actions
	_build_improvement_chips(opts, _info_trash.get_parent()) # Empty improvements: Rank + Unsocket actions
	_build_soil_chips(opts, _info_trash.get_parent())   # Cell improvements: growing pieces expose the water chip
	_build_almanac_chip(opts, _info_trash.get_parent()) # §8: empty info-tray entry for away/complete lines
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

func _build_seed_chips(opts: Dictionary, row: Control) -> void:
	var place := ActionBar.action_chip(opts, row, "Place", _on_seed_place, BoxContainer.ALIGNMENT_END)
	_info_seed_place = place.btn
	_info_seed_place_sb = place.sb
	_info_seed_place_count = place.count
	_info_seed_place_coin = place.coin
	row.move_child(_info_seed_place, _info_trash.get_index())
	var bag_chip := ActionBar.action_chip(opts, row, "Bag", _on_seed_bag, BoxContainer.ALIGNMENT_END)
	_info_seed_bag = bag_chip.btn
	_info_seed_bag_sb = bag_chip.sb
	_info_seed_bag_count = bag_chip.count
	_info_seed_bag_coin = bag_chip.coin
	row.move_child(_info_seed_bag, _info_trash.get_index())

func _build_improvement_chips(opts: Dictionary, row: Control) -> void:
	var rank := ActionBar.action_chip(opts, row, "Rank", _on_soil_rank, BoxContainer.ALIGNMENT_END)
	_info_soil_rank = rank.btn
	_info_soil_rank_sb = rank.sb
	_info_soil_rank_count = rank.count
	_info_soil_rank_coin = rank.coin
	row.move_child(_info_soil_rank, _info_trash.get_index())
	var unsocket := ActionBar.action_chip(opts, row, "Unsocket", _on_unsocket_improvement, BoxContainer.ALIGNMENT_END)
	_info_unsocket = unsocket.btn
	_info_unsocket_sb = unsocket.sb
	_info_unsocket_count = unsocket.count
	_info_unsocket_coin = unsocket.coin
	row.move_child(_info_unsocket, _info_trash.get_index())

func _build_soil_chips(opts: Dictionary, row: Control) -> void:
	var water_chip := ActionBar.action_chip(opts, row, "Water", _on_soil_water, BoxContainer.ALIGNMENT_END)
	_info_soil_water = water_chip.btn
	_info_soil_water_sb = water_chip.sb
	_info_soil_water_count = water_chip.count
	_info_soil_water_coin = water_chip.coin
	row.move_child(_info_soil_water, _info_trash.get_index())

func _hide_soil_chips() -> void:
	if _info_soil_water != null and is_instance_valid(_info_soil_water):
		_info_soil_water.visible = false

func _hide_seed_chips() -> void:
	if _info_seed_place != null and is_instance_valid(_info_seed_place):
		_info_seed_place.visible = false
	if _info_seed_bag != null and is_instance_valid(_info_seed_bag):
		_info_seed_bag.visible = false

func _hide_improvement_chips() -> void:
	if _info_unsocket != null and is_instance_valid(_info_unsocket):
		_info_unsocket.visible = false
	if _info_soil_rank != null and is_instance_valid(_info_soil_rank):
		_info_soil_rank.visible = false

func _set_action_chip(btn: Button, sb: StyleBoxFlat, coin_slot: Control, count: Label, icon: String, text: String, ready: bool) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	for c in coin_slot.get_children():
		c.queue_free()
	var ic := Look.icon(icon, coin_slot.custom_minimum_size.x)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_slot.add_child(ic)
	count.text = text
	sb.bg_color = Pal.BTN_PRIMARY if ready else Color(Pal.BTN_PRIMARY, 0.42)
	sb.border_color = Pal.BTN_PRIMARY_EDGE if ready else Color(Pal.BTN_PRIMARY_EDGE, 0.42)
	btn.modulate = Color(1, 1, 1, 1.0) if ready else Color(1, 1, 1, 0.7)
	btn.visible = true

func _refresh_seed_chips(cell: Vector2i) -> void:
	if _info_seed_place == null or _info_seed_bag == null:
		return
	var can_place := board.can_place_seed(cell)
	var can_bag := bag.size() < _bag_capacity() and board.collect_reward_at(cell).is_empty()
	_set_action_chip(_info_seed_place, _info_seed_place_sb, _info_seed_place_coin, _info_seed_place_count, "check", "", can_place)
	_set_action_chip(_info_seed_bag, _info_seed_bag_sb, _info_seed_bag_coin, _info_seed_bag_count, "bag", "", can_bag)

func _refresh_improvement_chips(cell: Vector2i) -> void:
	if _info_unsocket == null:
		return
	var row := board.improvement_at(cell)
	var kind := String(row.get("kind", ""))
	var price := Improvements.unsocket_price(kind)
	var use_gem := price.y > 0
	var cost := price.y if use_gem else price.x
	var afford := (Save.diamonds() if use_gem else Save.coins()) >= cost
	_set_action_chip(_info_unsocket, _info_unsocket_sb, _info_unsocket_coin, _info_unsocket_count, "gem" if use_gem else "coin", "%d" % cost, afford)
	if _info_soil_rank == null:
		return
	if kind != Improvements.KIND_SOIL:
		_info_soil_rank.visible = false
		return
	var rank_price := Improvements.soil_rank_price(int(row.get("rank", 1)))
	var rank_ready := rank_price > 0 and Save.coins() >= rank_price
	_set_action_chip(_info_soil_rank, _info_soil_rank_sb, _info_soil_rank_coin, _info_soil_rank_count, "coin", "%d" % rank_price if rank_price > 0 else "Max", rank_ready)

func _refresh_soil_chips(cell: Vector2i) -> void:
	if _info_soil_water == null:
		return
	if not board.is_growing(cell):
		_hide_soil_chips()
		return
	var row := board.improvement_at(cell)
	var watered := bool(row.get("watered", false))
	var water_ready := water >= int(G.SOIL_WATER_COST) and not watered
	_set_action_chip(_info_soil_water, _info_soil_water_sb, _info_soil_water_coin, _info_soil_water_count, "water", "%d" % int(G.SOIL_WATER_COST), water_ready)

func _refresh_selected_soil_info() -> void:
	if _selected_cell.x < 0 or _info_label == null or not is_instance_valid(_info_label):
		return
	if board == null:
		return
	if _selected_improvement and board.has_improvement(_selected_cell):
		_select_improvement_cell(_selected_cell)
		return
	# A GENERATOR lives in board.gens, never in board.items — item_at() reads 0 on its cell, so without
	# this branch the tray for a just-tapped generator fell through to _clear_selection() below and the
	# next water tick silently defocused it (~0.7s after the tap). Nothing the generator tray shows reads
	# `water` — the title/tier/boost detail, the mastery row and the burst chip are driven by coins, boost
	# charges and pops — and each of those has its own refresh hook (_refresh_selected_generator_mastery()
	# from _after_board_change, the pop path's own relabel). So this HOLDS the selection rather than
	# rebuilding it: re-running _select_generator() every regen tick would just churn the preview sprite.
	if board.is_gen(_selected_cell):
		return
	if board.is_growing(_selected_cell):
		_info_label.text = _soil_info_title(_selected_cell)
		_refresh_soil_chips(_selected_cell)
	elif board.item_at(_selected_cell) > 0:
		_select_item(_selected_cell)
	else:
		_clear_selection()

func _build_almanac_chip(opts: Dictionary, row: Control) -> void:
	var KitA: GDScript = KIT
	if KitA == null:
		return
	var chip_opts: Dictionary = KitA.action_button_opts_from_config(Game.kit_config())
	chip_opts["name"] = "AlmanacInfoButton"
	chip_opts["tooltip"] = Strings.t("almanac.chip")
	chip_opts["icon_scale"] = minf(float(chip_opts.get("icon_scale", 0.9)), 0.78)
	_info_almanac = KitA.action_button("almanac", Vector2(_info_inner_px, _info_inner_px), _open_almanac, chip_opts)
	_info_almanac.set_meta("action_role", "almanac")
	_info_almanac.size_flags_horizontal = Control.SIZE_SHRINK_END
	_info_almanac.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_info_almanac)

# Select a board item INTO the info bar: show its piece + name, put "Tier N" in the subtitle, enable the info button, and
# show the trashcan with its sell payout (hidden for generators / raw coins — they aren't deletable here).
func _select_item(cell: Vector2i) -> void:
	var code := board.item_at(cell)
	if code <= 0:
		_clear_selection()
		return
	_selected_cell = cell
	_selected_improvement = false
	_show_focus(cell)                          # the corner-bracket frame makes the focus visible on the board
	if _info_burst != null and is_instance_valid(_info_burst):
		_info_burst.visible = false           # the burst chip is a GENERATOR action (see _select_generator)
	_hide_soil_chips()
	_hide_seed_chips()
	_hide_improvement_chips()
	if _info_almanac != null and is_instance_valid(_info_almanac):
		_info_almanac.visible = false
	_place_info_button(false)
	var tier := BoardModel.tier_of(code)
	var seed_kind := Improvements.kind_for_seed(code)
	for c in _info_icon.get_children():
		c.queue_free()
	_info_icon.add_child(PieceView.make_piece(code, _info_item_px, 0.0))
	var nm: String = tr(G.item_display_name(code))
	_info_label.text = _soil_info_title(cell) if board.is_growing(cell) else nm
	if _info_desc_label != null and is_instance_valid(_info_desc_label):
		_hide_mastery_info_row()
		var tier_text := "%s %d" % [Strings.t("board.info.tier"), tier]
		var desc := _item_description_for_cell(cell, code)
		var weather_desc := _weather_info_for_cell(cell)
		if weather_desc != "":
			desc = weather_desc if desc == "" else "%s · %s" % [desc, weather_desc]
		_info_desc_label.text = tier_text if desc == "" else "%s · %s" % [tier_text, desc]
		_info_desc_label.visible = true
	var show_info := seed_kind == "" and not _info_button_hidden
	_info_btn.visible = show_info
	_info_btn.disabled = not show_info
	if board.is_gen(cell) or G.is_coin(code) or (G.is_special(code) and seed_kind == ""):
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
		if seed_kind != "":
			if _info_buy != null and is_instance_valid(_info_buy):
				_info_buy.visible = false
			_refresh_seed_chips(cell)
			if seed_kind == Improvements.KIND_SOIL:
				_maybe_hand_hint()
		else:
			_refresh_buy_chip(code)               # T55: a sellable item is also BUYABLE (a copy → the board)
		if board.is_growing(cell):
			_refresh_soil_chips(cell)

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
	_selected_improvement = false
	_show_focus(cell)                          # the corner-bracket frame makes the focus visible on the board
	var gid := board.gen_id_at(cell)
	_place_info_button(false)
	if _info_almanac != null and is_instance_valid(_info_almanac):
		_info_almanac.visible = false
	for c in _info_icon.get_children():
		c.queue_free()
	var tier := board.gen_tier_at(cell)
	var prev := PieceView.make_generator(gid, _info_item_px, {}, tier)
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_icon.add_child(prev)
	_info_label.text = _gen_info_text(gid, cell)
	if _info_desc_label != null and is_instance_valid(_info_desc_label):
		var line := _gen_line(gid)
		if Features.on("mastery") and G.ZONE_BASE_LINES.has(line):
			_show_mastery_info_row(line)
		else:
			_hide_mastery_info_row()
			var desc := G.generator_description(gid)
			_info_desc_label.text = desc
			_info_desc_label.visible = desc != ""
	var entries := _gen_line_entries(gid)
	var show_info_btn := not entries.is_empty() and not _info_button_hidden
	_info_btn.visible = show_info_btn
	_info_btn.disabled = not show_info_btn     # ⓘ opens the line ladder unless empty or hidden in the workbench
	if _info_buy != null and is_instance_valid(_info_buy):
		_info_buy.visible = false             # a generator is never buyable as a copy
	_hide_soil_chips()
	_hide_seed_chips()
	_hide_improvement_chips()
	# A generator is clearable only when it is REDUNDANT (a higher-tier same-line sibling exists — the
	# stranding fix). Not-currently-needed lines are now swept by the automatic farewell card, so the
	# info tray never carries a second manual line-clearing path.
	if board.is_redundant_gen(cell):
		var sell_coins := G.gen_sell_coins(tier)
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
	if not G.gen_def(G.GENERATORS, gid).is_empty():
		lbl += " · %s %d" % [Strings.t("board.info.tier"), board.gen_tier_at(cell)]
	if G.is_treat_gen(gid):
		var clicks := int(Save.grove().get("treat_clicks", 0))
		if clicks > 0:
			lbl += " · %d taps" % clicks
	elif board.is_gen_boosted(cell):
		lbl += " · " + (Strings.t("board.info.boost_detail") % board.gen_boost_at(cell))
	return lbl

func _refresh_selected_generator_mastery() -> void:
	if _info_label == null or _info_desc_label == null:
		return
	if not is_instance_valid(_info_label) or not is_instance_valid(_info_desc_label):
		return
	var gid := board.gen_id_at(_selected_cell)
	if gid == "":
		return
	_info_label.text = _gen_info_text(gid, _selected_cell)
	var line := _gen_line(gid)
	if Features.on("mastery") and G.ZONE_BASE_LINES.has(line):
		_show_mastery_info_row(line)

func _mastery_info_text(line: int) -> String:
	var rank := Mastery.rank(line)
	var meter := Mastery.meter(line)
	var next := Mastery.next_threshold(line)
	var pips := ""
	for i in range(G.MASTERY_THRESHOLDS.size()):
		pips += "●" if i < rank else "○"
	var progress := Strings.t("mastery.info.maxed") if rank >= G.MASTERY_THRESHOLDS.size() else "%d/%d" % [meter, next]
	return "%s · %s · %s" % [pips, progress, _mastery_next_text(rank)]

func _mastery_next_text(rank: int) -> String:
	if rank >= G.MASTERY_THRESHOLDS.size():
		return Strings.t("mastery.info.maxed")
	var next_rank := rank + 1
	var w := Mastery.tier_window_for_rank(next_rank)
	if next_rank % 2 == 1:
		return Strings.t("mastery.info.next_reach") % w.y
	return Strings.t("mastery.info.next_start") % w.x

func _install_mastery_info_row() -> void:
	if _info_desc_label == null or not is_instance_valid(_info_desc_label):
		return
	var parent := _info_desc_label.get_parent()
	if parent == null:
		return
	var row := HBoxContainer.new()
	row.name = "MasteryInfoRow"
	row.visible = false
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.custom_minimum_size.y = maxf(14.0, _info_desc_label.custom_minimum_size.y)
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	parent.move_child(row, _info_desc_label.get_index() + 1)
	_info_mastery_row = row
	var pip_row := HBoxContainer.new()
	pip_row.name = "MasteryPips"
	pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pip_row.add_theme_constant_override("separation", 3)
	row.add_child(pip_row)
	_info_mastery_pips.clear()
	for i in range(G.MASTERY_THRESHOLDS.size()):
		var pip := PanelContainer.new()
		pip.name = "Pip%d" % (i + 1)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.custom_minimum_size = Vector2(9, 9)
		pip_row.add_child(pip)
		_info_mastery_pips.append(pip)
	# The row's width is PINNED at 391px on the 1080-wide design canvas (the generator icon and the
	# Boost chip beside it are already at their minimums, so nothing more can be taken). Minus the
	# pip row (93) and two 8px separations that leaves 282px to split between the meter and the
	# next-reward text. The TEXT is the payload — an ellipsised "next: po…" says nothing — so the
	# label takes the lion's share of that split (ratio 2.5 ⇒ ~201px, enough for the widest string)
	# and the meter keeps the remainder (~80px) over a 76px floor that stops it collapsing on a
	# narrower row. Splitting evenly (both EXPAND at ratio 1, meter floor 120) is what trimmed the
	# label to "next: po…".
	var bar := ProgressBar.new()
	bar.name = "MasteryProgress"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.custom_minimum_size = Vector2(76, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	_info_mastery_progress = bar
	var lbl := Label.new()
	lbl.name = "MasteryNext"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_stretch_ratio = 2.5
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _info_desc_label.get_theme_font_size("font_size"))
	lbl.add_theme_color_override("font_color", Pal.INK)
	row.add_child(lbl)
	_info_mastery_next_label = lbl

func _hide_mastery_info_row() -> void:
	if _info_mastery_row != null and is_instance_valid(_info_mastery_row):
		_info_mastery_row.visible = false

func _show_mastery_info_row(line: int) -> void:
	if _info_desc_label != null and is_instance_valid(_info_desc_label):
		_info_desc_label.visible = false
	if _info_mastery_row == null or not is_instance_valid(_info_mastery_row):
		_info_desc_label.text = _mastery_info_text(line)
		_info_desc_label.visible = true
		return
	var rank := Mastery.rank(line)
	var color := _line_color(line)
	for i in range(_info_mastery_pips.size()):
		var pip := _info_mastery_pips[i] as PanelContainer
		if pip == null or not is_instance_valid(pip):
			continue
		var filled := i < rank
		var sb := StyleBoxFlat.new()
		sb.bg_color = color if filled else Pal.CREAM
		sb.border_color = color if filled else Pal.INK
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(99)
		pip.add_theme_stylebox_override("panel", sb)
	if _info_mastery_progress != null and is_instance_valid(_info_mastery_progress):
		_info_mastery_progress.value = Mastery.rank_progress(line)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("#FBF3EA", 0.72)
		bg.set_corner_radius_all(7)
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		fill.set_corner_radius_all(7)
		_info_mastery_progress.add_theme_stylebox_override("background", bg)
		_info_mastery_progress.add_theme_stylebox_override("fill", fill)
	if _info_mastery_next_label != null and is_instance_valid(_info_mastery_next_label):
		_info_mastery_next_label.text = _mastery_next_text(rank)
	_info_mastery_row.visible = true

# Reset the info bar to its empty "tap an item" state.
func _clear_selection() -> void:
	_selected_cell = Vector2i(-1, -1)
	_selected_improvement = false
	_hide_focus()
	if _info_icon != null and is_instance_valid(_info_icon):
		for c in _info_icon.get_children():
			c.queue_free()
	if _info_label != null and is_instance_valid(_info_label):
		_info_label.text = Strings.t("board.info.empty_prompt")
	if _info_desc_label != null and is_instance_valid(_info_desc_label):
		_hide_mastery_info_row()
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
	_hide_seed_chips()
	_hide_improvement_chips()
	_hide_soil_chips()
	if _info_almanac != null and is_instance_valid(_info_almanac):
		_info_almanac.visible = Features.on("discovery_ladder")
		_info_almanac.disabled = not Features.on("discovery_ladder")

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
	return Kit.focus_ring_opts_from_config(Game.kit_config())

func _show_locked_cell_info(cell: Vector2i) -> void:
	_clear_selection()
	if _info_label != null and is_instance_valid(_info_label):
		_info_label.text = Strings.t("board.info.unlock_level") % maxi(1, G.cell_min_level(cell))
	if _info_desc_label != null and is_instance_valid(_info_desc_label):
		_hide_mastery_info_row()
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
	if code <= 0 or board.is_gen(_selected_cell) or G.is_coin(code) or G.is_special(code):
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
		_bag_append(code)
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

func _place_scissors_tool(commit: bool) -> bool:
	if not Features.on("scissors"):
		return false
	var code := int(G.SCISSORS_LINE) * 100 + 1
	var dest := Vector2i(-1, -1)
	for c in board.empty_ground_cells():
		if not board.is_gen(c):
			dest = c
			break
	if dest.x >= 0:
		if commit:
			board.place(dest, code)
			_mark_seen(code)
		return true
	if bag.size() >= _bag_capacity():
		return false
	if commit:
		_bag_append(code)      # through the aligned seam — a raw bag.append() desyncs bag_seed_ranks
		_mark_seen(code)
	return true

func _shop_scissors_place(commit: bool) -> bool:
	if not _place_scissors_tool(commit):
		return false
	if commit:
		_rebuild_all()
		_after_board_change()
	return true

func _drain_scissors_pending() -> bool:
	if not Features.on("scissors"):
		return false
	var pending := Save.take_scissors_pending()
	if pending <= 0:
		return false
	var placed := 0
	var remaining := 0
	for _i in range(pending):
		if _place_scissors_tool(true):
			placed += 1
		else:
			remaining += 1
	if remaining > 0:
		Save.add_scissors_pending(remaining)
	return placed > 0

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
	if Improvements.is_seed(code):
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
	if board.is_gen(cell):                         # the sell button only clears a REDUNDANT generator
		if board.is_redundant_gen(cell):
			_sell_generator(cell)
			_clear_selection()
		return
	var code := board.item_at(cell)
	if code <= 0 or board.is_gen(cell) or G.is_coin(code):
		return
	var node: Control = piece_nodes.get(cell)
	if node == null:
		return
	if _defer_soil_reset([cell], "Sell", func() -> void:
		_sell_item(cell, node)
		_clear_selection()):
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
	var gn := PieceView.make_generator(String(id), csz, hl, tier)
	_attach_mastery_chrome(gn, String(id))
	return gn

func _gen_line(gid: String) -> int:
	var def := G.gen_def(G.GENERATORS, gid)
	return int(def.get("line", 0))

func _line_color(line: int) -> Color:
	var def: Dictionary = G.LINES.get(line, {})
	return def.get("color", STRAW)

func _attach_mastery_chrome(gn: Control, gid: String) -> void:
	if not Features.on("mastery"):
		return
	var line := _gen_line(gid)
	if line <= 0 or Mastery.meter(line) <= 0:
		return
	var ring := MasteryRing.new()
	ring.name = "MasteryRing"
	ring.size = Vector2(csz, csz)
	ring.custom_minimum_size = ring.size
	ring.ring_color = _line_color(line)
	ring.progress = Mastery.rank_progress(line)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = 6
	gn.add_child(ring)
	_add_mastery_trim(gn, Mastery.rank(line))

func _refresh_mastery_chrome() -> void:
	if not Features.on("mastery"):
		return
	for cell in gen_nodes:
		var gn: Control = gen_nodes[cell]
		if gn == null or not is_instance_valid(gn):
			continue
		var line := _gen_line(board.gen_id_at(cell))
		var ring := gn.get_node_or_null("MasteryRing") as MasteryRing
		if Mastery.meter(line) <= 0:
			if ring != null:
				ring.queue_free()
			continue
		if ring == null:
			_attach_mastery_chrome(gn, board.gen_id_at(cell))
		else:
			ring.ring_color = _line_color(line)
			ring.progress = Mastery.rank_progress(line)
		_refresh_mastery_trim(gn, Mastery.rank(line))

func _add_mastery_trim(gn: Control, rank: int) -> void:
	var trim := _mastery_trim(rank)
	if trim != null:
		gn.add_child(trim)

func _refresh_mastery_trim(gn: Control, rank: int) -> void:
	var old := gn.get_node_or_null("MasteryTrim") as TextureRect
	var tex := _mastery_trim_texture(rank)
	if tex == null:
		if old != null:
			old.queue_free()
		return
	if old != null:
		old.texture = tex
		return
	var tr := _mastery_trim_from_texture(tex)
	gn.add_child(tr)

func _mastery_trim(rank: int) -> TextureRect:
	var tex := _mastery_trim_texture(rank)
	return _mastery_trim_from_texture(tex) if tex != null else null

func _mastery_trim_texture(rank: int) -> Texture2D:
	var idx := clampi(int(rank / 2), 0, 4)
	if idx <= 0:
		return null
	var path := Look.kit("mastery_trim_%d.png" % idx)
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	return tex

func _mastery_trim_from_texture(tex: Texture2D) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = "MasteryTrim"
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = Vector2(csz * 0.34, csz * 0.34)
	tr.position = Vector2(csz * 0.06, csz * 0.62)
	tr.z_index = 7
	return tr

# The GEN-highlight (glow / silhouette outline / sparkle) tuning saved in the UI workbench
# ("generator" block). Absent file/keys → {} → make_generator falls back to its shipped GEN_* consts.
func _gen_highlight_opts() -> Dictionary:
	var Kit: GDScript = KIT
	if Kit == null:
		return {}
	return Kit.gen_highlight_opts_from_config(Game.kit_config())

# --- input ---------------------------------------------------------------------

func _on_board_input(event: InputEvent) -> void:
	_idle = 0.0
	if animating or _chain_active:
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
		if _split_preview == null:
			_apply_drag_magnet(target)
		return
	_clear_telegraph()                       # moved onto a new valid target — drop the previous glow first
	var tnode: Control = piece_nodes.get(target)
	if tnode == null or not is_instance_valid(tnode):
		return
	_telegraph_cell = target
	_telegraph_node = tnode
	_telegraph_rest = _cell_pos(target)
	if Features.on("scissors") and BoardActions.can_split_piece(board, _drag_from, target):
		tnode.modulate = Color(1, 1, 1, 0.32)
		var target_code := board.item_at(target)
		var twin_code := BoardModel.line_of(target_code) * 100 + BoardModel.tier_of(target_code) - 1
		_show_split_preview(target, twin_code)
	else:
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
	_clear_split_preview()
	if _telegraph_node != null and is_instance_valid(_telegraph_node):
		FX.breathe_stop(_telegraph_node)
		_telegraph_node.modulate = Color(1, 1, 1, 1.0)
		_telegraph_node.position = _telegraph_rest
	_telegraph_node = null
	_telegraph_cell = Vector2i(-1, -1)
	_telegraph_rest = Vector2.ZERO

func _show_split_preview(cell: Vector2i, code: int) -> void:
	_clear_split_preview()
	var prev := SplitPreview.new()
	prev.name = "SplitPreview"
	prev.setup(code, csz)
	prev.position = _cell_pos(cell)
	prev.z_index = 9
	board_area.add_child(prev)
	_split_preview = prev

func _clear_split_preview() -> void:
	if _split_preview != null and is_instance_valid(_split_preview):
		_split_preview.queue_free()
	_split_preview = null

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
	_clear_cascade_drag_guides()
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

func _drag_active() -> bool:
	return _drag_pending or _drag_node != null

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
		_show_cascade_drag_guides(cell)
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
		if tap == _press_cell and pos.distance_to(_press_pos) <= _drag_slop_px() and _catch_pending_star_at(tap):
			return
		if tap == _press_cell and pos.distance_to(_press_pos) <= _drag_slop_px() and _select_sky_cell(tap):
			return
		if tap == _press_cell and board.is_bramble(tap):
			_show_locked_cell_info(tap)
		elif tap == _press_cell and board.has_improvement(tap) and board.item_at(tap) == 0:
			_select_improvement_cell(tap)
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
			if not Improvements.is_seed(from_code):
				_open_ladder(BoardModel.line_of(from_code), BoardModel.tier_of(from_code))
		else:
			_snap_back(from, node)
			_select_item(from)
	elif board.can_merge(from, target):
		_commit_merge(from, target, node)
	elif _recipe_merge_code(from_code, target_code) > 0:
		_apply_recipe(from, target, node)   # #14: two DIFFERENT base lines at the same tier craft a SPECIAL
	elif Features.on("scissors") and BoardActions.can_split_piece(board, from, target):
		_split_piece(from, target, node)
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
	# What this tap COSTS. A MASTERED line pops from a raised tier window (§3), so one pop is worth
	# 2^(lo-1) tier-1 items — it is priced off that window low (G.pop_cost) or rank would collapse the
	# water sink (sim I2). All three reads below are PURE (no rng), so the contractual draw order
	# further down is untouched; at rank 0 / mastery off the window low is 1 and the cost is G.POP_COST.
	var giver_quests: Array = _pop_pool_ctx()["giver_quests"]
	var gen_line := int(G.gen_def(G.GENERATORS, board.gen_id_at(cell)).get("line", 0))
	var mastery_window := Mastery.window(gen_line, giver_quests)
	var pop_cost := G.pop_cost(mastery_window.x)
	if charged and water < pop_cost:
		_water_short = pop_cost            # a mastered pop can cost >1: "empty" means "can't afford THIS tap"
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
	# affordable (energy) and what fits (open cells). Each popped item costs `G.pop_cost(lo)` off
	# the burst's ONE mastery window, so the whole burst is priced the same — the clamp below is
	# what keeps a burst from overdrawing the can.
	# FTUE (§4): during the free-pop intro a tap pops EXACTLY ONE item — burst is suppressed so the
	# 10 free pops are ~10 deliberate frictionless taps (not spent 3-at-a-time) and the counter can't
	# overshoot 10 mid-burst. Burst resumes the moment the free budget is gone (`charged`).
	# (Accumulator/treat taps never reach here — their own collect/pop paths.)
	var burst := 1
	if charged:
		burst = G.gen_burst_count(board.gen_tier_at(cell), rng, board.is_gen_boosted(cell))
	if charged:
		burst = mini(burst, int(water / pop_cost))
	burst = mini(burst, empties.size())
	# the spawn decision (landing cell + code) is board_logic's; the active givers' wanted lines AND
	# poppable wanted tiers bias every item's roll (§6). Pool + wanted are fixed across the burst.
	# RNG order is load-bearing.
	# gen redesign #4: a per-line generator pops ONLY its own line (the legacy shared windowed pool is gone).
	# `giver_quests` / `gen_line` / `mastery_window` were read above (they price the tap) — reused here.
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
			water -= pop_cost
		g["pops"] = int(g.get("pops", 0)) + 1
		var spawn := BoardLogic.roll_spawn(empties, cell, pool, wanted, rng, wanted_t, G.ASK_TIER_WEIGHT, mastery_window.x, mastery_window.y)
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
	return BoardActions.recipe_merge_code(a_code, b_code)

func chain_running() -> bool:
	return _chain_active

func _prepare_chain(a: Vector2i, b: Vector2i) -> void:
	_chain_run = []
	_chain_n = 0
	_chain_active = false
	_chain_auto_step = false
	_chain_origin_cell = Vector2i(-1, -1)
	_chain_reward_cell = Vector2i(-1, -1)
	if not Features.on("cascade"):
		_refresh_chain_lock_dim()
		return
	_chain_run = BoardLogic.chain_path(board, a, b)
	if 1 + _chain_run.size() >= CHAIN_MIN_N:
		_chain_n = 1
		_chain_active = true
		_chain_origin_cell = b
	else:
		_chain_run = []
	_refresh_chain_lock_dim()

func _schedule_chain_step(current: Vector2i) -> void:
	if not _chain_active or _chain_run.is_empty():
		_finish_chain()
		return
	if _chain_n == 1 and not _chain_auto_step and CHAIN_PREROLL_MS > 0:
		_show_chain_preroll(current)
		var tree := get_tree()
		if tree != null:
			tree.create_timer(float(CHAIN_PREROLL_MS) / 1000.0).timeout.connect(_run_chain_step.bind(current))
		else:
			_run_chain_step.call_deferred(current)
		return
	_run_chain_step.call_deferred(current)

func _show_chain_preroll(current: Vector2i) -> void:
	if board == null or _chain_run.is_empty():
		return
	var outline := _ensure_cascade_outline()
	if outline == null:
		return
	var cells: Array = [current]
	for raw in _chain_run:
		cells.append(Vector2i(raw))
	outline.set_ladders([{
		"cells": cells,
		"line": BoardModel.line_of(board.item_at(current)),
		"n": 1 + _chain_run.size(),
		"top_cell": Vector2i(_chain_run[_chain_run.size() - 1]),
	}])
	outline.modulate = Color(1, 1, 1, 0.76)
	var t := outline.create_tween()
	t.tween_property(outline, "modulate:a", 1.0, 0.12)
	t.tween_property(outline, "modulate:a", 0.82, 0.08)
	t.tween_property(outline, "modulate:a", 1.0, 0.10)

func _run_chain_step(current: Vector2i) -> void:
	if not _chain_active or _chain_run.is_empty():
		_finish_chain()
		return
	var partner := Vector2i(_chain_run.pop_front())
	if not board.can_merge(current, partner):
		_finish_chain()
		_after_board_change()
		return
	var node: Control = piece_nodes.get(current)
	var produced := board.merge(current, partner)
	piece_nodes.erase(current)
	_chain_n += 1
	_chain_auto_step = true
	animating = true
	_anim_t = 0.0
	var merge_slide_ms := _chain_step_ms_for_n(_chain_n)
	if node != null and is_instance_valid(node):
		MoveFx.apply(node, node.position, _cell_pos(partner), "slide", _move_opts, merge_slide_ms)
		var tree := get_tree()
		if tree != null:
			tree.create_timer(float(merge_slide_ms) / 1000.0).timeout.connect(_after_merge.bind(current, partner, produced, node, true))
		else:
			_after_merge(current, partner, produced, node, true)
	else:
		_after_merge(current, partner, produced, node, true)

func _finish_chain() -> void:
	_chain_run = []
	_chain_n = 0
	_chain_active = false
	_chain_auto_step = false
	_chain_origin_cell = Vector2i(-1, -1)
	_chain_reward_cell = Vector2i(-1, -1)
	animating = false
	_anim_t = 0.0
	_refresh_chain_lock_dim()

func _chain_step_ms_for_n(n: int) -> int:
	if not CHAIN_STEP_RAMP_ENABLED:
		return CHAIN_STEP_MS
	var span := maxi(1, CHAIN_STEP_RAMP_END_N - 2)
	var t := clampf(float(n - 2) / float(span), 0.0, 1.0)
	return int(roundf(lerpf(float(CHAIN_STEP_START_MS), float(CHAIN_STEP_END_MS), t)))

func _refresh_chain_lock_dim() -> void:
	if board_area == null or not is_instance_valid(board_area):
		return
	var alpha := CHAIN_LOCK_DIM_ALPHA if _chain_active and CHAIN_LOCK_DIM_ENABLED else 1.0
	board_area.modulate = Color(1, 1, 1, alpha)

func _chain_reward_code(n: int) -> int:
	return BoardLogic.chain_reward_code(n)

func _apply_chain_reward(vacated: Vector2i) -> void:
	var reward_code := _chain_reward_code(_chain_n)
	if reward_code <= 0:
		return
	if _chain_n == 3:
		_chain_reward_cell = vacated
		_birth_chain_reward(_chain_reward_cell, reward_code)
	elif _chain_reward_cell.x >= 0:
		_replace_chain_reward(_chain_reward_cell, reward_code)

func _birth_chain_reward(cell: Vector2i, code: int) -> void:
	if not board.is_empty_ground(cell):
		return
	board.place(cell, code)
	_mark_seen(code)
	var n := _make_piece(code, csz)
	n.position = _cell_pos(cell)
	board_area.add_child(n)
	piece_nodes[cell] = n
	FX.pop(n)

func _replace_chain_reward(cell: Vector2i, code: int) -> void:
	if not board.in_bounds(cell) or board.item_at(cell) <= 0:
		return
	var old: Control = piece_nodes.get(cell)
	if old != null and is_instance_valid(old):
		old.queue_free()
	board.place(cell, code)
	_mark_seen(code)
	var n := _make_piece(code, csz)
	n.position = _cell_pos(cell)
	board_area.add_child(n)
	piece_nodes[cell] = n
	FX.pop(n)

func _show_chain_step_feedback(cell: Vector2i, produced: int) -> void:
	var counter_cell := _chain_counter_cell(cell)
	var at := board_area.get_global_transform() * (_cell_pos(counter_cell) + Vector2(csz, csz) / 2.0)
	var floater_size := FS.HEADING + maxi(0, mini(_chain_n, 7) - 2) * 2
	FX.floating_text(self, at + Vector2(csz * 0.18, -csz * 0.38), "×%d" % _chain_n, CREAM, floater_size)
	if _chain_n >= 5:
		FX.burst(board_area, _cell_pos(cell) + Vector2(csz, csz) / 2.0, G.line_color(produced), 24)

func _chain_counter_cell(step_cell: Vector2i) -> Vector2i:
	if CHAIN_COUNTER_ANCHOR_ORIGIN and board != null and board.in_bounds(_chain_origin_cell):
		return _chain_origin_cell
	return step_cell

# #14 craft the special: consume the source ingredient; the target becomes the special at the same tier.
func _apply_recipe(from: Vector2i, target: Vector2i, node: Control) -> void:
	if _defer_soil_reset([from, target], "Merge", func() -> void: _apply_recipe_confirmed(from, target, node), func() -> void: _snap_back(from, node)):
		return
	_apply_recipe_confirmed(from, target, node)

func _apply_recipe_confirmed(from: Vector2i, target: Vector2i, node: Control) -> void:
	# The chain is armed BEFORE the action: BoardActions.apply_recipe mutates the board, and
	# chain_path has to read the PRE-merge cells to find the run the craft tips off.
	_prepare_chain(from, target)
	var out := BoardActions.apply_recipe(board, from, target)
	if out.is_empty():
		_finish_chain()               # nothing merged — drop the run we armed above
		_snap_back(from, node)
		return
	var code := int(out.code)
	_mark_seen(code)
	_queue_mastery_rankups(out.get("rank_ups", {}))
	_rebuild_all()
	if _chain_active:
		animating = true
		_anim_t = 0.0
		_after_board_change()
		_schedule_chain_step(target)
	else:
		_after_board_change()
	_schedule_mastery_rankup(MASTERY_RANKUP_FX_DELAY)
	Audio.play("item_drop", -2.0)

func _split_piece(from: Vector2i, target: Vector2i, node: Control) -> void:
	if _defer_soil_reset([target], "Split", func() -> void: _split_piece_confirmed(from, target, node), func() -> void: _snap_back(from, node)):
		return
	_split_piece_confirmed(from, target, node)

func _split_piece_confirmed(from: Vector2i, target: Vector2i, node: Control) -> void:
	var out := BoardActions.split_piece(board, from, target)
	if out.is_empty():
		_snap_back(from, node)
		return
	_mark_seen(int(out.code))
	_rebuild_all()
	_after_board_change()
	Audio.play("item_drop", -2.0, 1.18)

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
	if _defer_soil_reset([a, b], "Merge", func() -> void: _commit_merge_confirmed(a, b, node), func() -> void: _snap_back(a, node)):
		return
	_commit_merge_confirmed(a, b, node)

func _commit_merge_confirmed(a: Vector2i, b: Vector2i, node: Control) -> void:
	_prepare_chain(a, b)
	var produced := board.merge(a, b)
	piece_nodes.erase(a)
	animating = true
	_anim_t = 0.0
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

func _after_merge(_a: Vector2i, b: Vector2i, produced: int, moved: Control, was_chain_step := false) -> void:
	was_chain_step = was_chain_step or _chain_auto_step
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
	if was_chain_step:
		_show_chain_step_feedback(b, produced)
		_apply_chain_reward(_a)
	# bundle D: poke the screen-bloom — a PERSISTENT overlay, so it can't live inside apply(); gate + scale it
	# here by the workbench's combo_bloom toggle + bloom_pct knob (the scene owns the world reaction).
	if MergeFx.on(_merge_opts, "combo_bloom") and _combo_bloom != null and is_instance_valid(_combo_bloom):
		_combo_bloom.bump(combo, MergeFx.knob(_merge_opts, "bloom_pct"))
	# a merge beside a sealed cell opens it once the player's Level has reached its §4 gate
	for cell in board.openable_brambles(b, _quest_level()):
		_open_bramble(cell)
	_refresh_locked_cells()   # the open set changed → re-evaluate neighbours' frontier/highlight
	# a little luck: merges sometimes shake a coin/special loose — the sky decides what falls, and the
	# improvement-seed filter keeps a kind the player already holds (or has at cap) out of the draw.
	# A cascade's AUTO steps roll it too (CHAIN_AUTO_STEPS_ROLL_LUCKY): every step is a real merge.
	var roll_lucky := not was_chain_step or CHAIN_AUTO_STEPS_ROLL_LUCKY
	if roll_lucky:
		var in_patch := SkyLogic.gate_open() and SkyLogic.in_patch(_sky_state, b)
		for drop in BoardLogic.roll_merge_drops(produced, rng, _sky_state, in_patch, _blocked_seed_drop_lines()):
			var code := int(drop)
			if G.is_coin(code):
				_drop_coin_near(b, code)
			else:
				_drop_special_near(b, code)
	_chain_auto_step = false
	var keep_running := _chain_active and not _chain_run.is_empty()
	if keep_running:
		_after_board_change()
		_schedule_chain_step(b)
	else:
		_finish_chain()
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

func _open_bramble(cell: Vector2i, deterministic := false) -> void:
	# §4: a freshly-opened cell mimics ONE generator pop biased to a RANDOM open quest line. With no
	# open quests (rare), pass -1 so the model falls back to the legacy positional seed.
	var lines := _open_quest_lines()
	var seed := -1
	if not deterministic and not lines.is_empty():
		seed = BoardLogic.bramble_seed(lines, rng)
	var contents := board.open_bramble(cell, seed)
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

# THE lucky-drop landing: shake `code` loose onto one of the open cells nearest `near` and fly it in.
# Shared by the coin drop and the §6.B special drop — they were byte-identical apart from the coin's
# default code, which now lives in _drop_coin_near.
# JUICE: the piece TOUCHES DOWN at the end of its grow-in flight — a discrete (loud) LandFx.apply
# owns the impact squash + small flash + micro-puff + touch sound. The verb plays the canonical
# `tidy_poof` itself, so the old inline poof here is dropped (no double-sound).
func _drop_item_near(near: Vector2i, code: int) -> void:
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
	var ctr := board_area.get_global_transform() * _cell_pos(cell) + Vector2(csz, csz) / 2.0
	t.chain().tween_callback(func() -> void:
		if n and is_instance_valid(n):
			LandFx.apply(self, n, ctr, _land_opts, 0.8, false)
			Feel.ripple(_orthogonal_neighbour_nodes(cell), ctr, 0.8))   # bundle B: the touchdown jiggles its neighbours

# A merge shakes a coin loose. `code` <= 0 (the default) means a plain t1 coin.
func _drop_coin_near(near: Vector2i, code: int = -1) -> void:
	_drop_item_near(near, code if code > 0 else G.COIN_LINE * 100 + 1)

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
	_drop_special_near(Vector2i(G.ROWS / 2, G.COLS / 2), G.ACORN_LINE * 100 + 1)
	_after_board_change()

## The tier-1 code the debug spawns place: the FIRST picture-book line (ascending) that is still
## producible and that no live quest is asking for. Deterministic on purpose — these buttons must
## never touch the board RNG, whose stream is persisted and order-sensitive. The quest skip is
## load-bearing for "Pop magnet": magnet_merge_once refuses any pair a giver wants, so seeding an
## asked code would leave the button silently doing nothing. 0 when the roster has no usable line.
func _debug_spawn_code() -> int:
	var asked := _asked_codes()
	var lines: Array = G.LINES.keys()
	lines.sort()
	for line in lines:
		var code := int(line) * 100 + 1
		if G.is_valid_item_code(code) and not asked.has(code):
			return code
	return 0

## Debug-only: the plain empty ground inside a magnet's 3×3 range — where a debug pair can land.
## Skips the magnet's own cell and every other improved cell: an item parked on a Soil in range
## starts growing, and the magnet rule stands down on growing cells. Board-index order, no RNG.
func _debug_magnet_room(magnet_cell: Vector2i) -> Array:
	var out: Array = []
	if board == null:
		return out
	for raw_cell in Improvements.range_cells(board, magnet_cell):
		var cell := Vector2i(raw_cell)
		if cell == magnet_cell or board.has_improvement(cell):
			continue
		if board.is_empty_ground(cell):
			out.append(cell)
	return out

## Debug-only: where a debug-BUILT improvement of `kind` goes — the FIRST cell in board-index order
## that can_build_improvement() allows and that (for a Magnet) still has room for a pair in its 3×3
## range. Deterministic on purpose: these buttons must never touch the board RNG, whose stream is
## persisted and order-sensitive. Never overwrites a player's item, a generator or an existing
## improvement, and never exceeds the kind's cap. (-1, -1) when the board has no room for one.
func _debug_build_cell(kind: String) -> Vector2i:
	if board == null or board.improvement_count(kind) >= Improvements.cap_for(kind):
		return Vector2i(-1, -1)
	for raw_cell in board.empty_ground_cells():
		var cell := Vector2i(raw_cell)
		if not board.can_build_improvement(cell):
			continue
		if kind == Improvements.KIND_MAGNET and _debug_magnet_room(cell).size() < 2:
			continue
		return cell
	return Vector2i(-1, -1)

## Debug-only feedback: put the owner's eye on the cell a debug button just changed — SELECT it (the
## focus ring frames it and the info bar names it and its tier), bounce its piece, and shout above it.
## One cell moving on a forty-item board is invisible otherwise, which is exactly what made these
## buttons read as dead. Called after _after_board_change, so piece_nodes holds the rebuilt node.
func _debug_spotlight(cell: Vector2i, shout: String) -> void:
	if board == null or cell.x < 0:
		return
	if board.item_at(cell) > 0:
		_select_item(cell)
	elif board.has_improvement(cell):
		_select_improvement_cell(cell)
	if board_area == null or not is_instance_valid(board_area):
		return
	var node: Control = piece_nodes.get(cell)
	if node != null and is_instance_valid(node):
		FX.pop(node)
	var ctr: Vector2 = board_area.get_global_transform() * _cell_pos(cell) + Vector2(csz, csz) / 2.0
	FX.celebrate_at(self, ctr, shout, STRAW)

## Debug-only: land a Soil growth step right now (the debug panel's "Pop soil" button), so a tier pop
## can be watched without waiting out the step timer. ONE press works from ANY board state: every
## growing Soil has its step expired; a board whose soils are all BARE gets a deterministic tier-1
## item dropped on the first one; a board with NO Soil at all gets one BUILT on the first free cell
## first. The changed cell is then spotlighted, and every dead end prints why instead of returning
## silently — a quiet no-op is unreadable from "the button is broken".
## The pop itself is left to _after_board_change's own reconcile — reconciling HERE would consume the
## change and leave that call with nothing to report, so the piece art would keep the old tier.
## No _reflect — the new tier rebuilds live and _after_board_change persists it (no scene reload).
func debug_pop_soil() -> void:
	if board == null or not _improvements_enabled():
		print("[debug] Pop soil: improvements are switched off — there is nothing to pop.")
		return
	var now := Time.get_unix_time_from_system()
	var soils := _improvement_cells(Improvements.KIND_SOIL)
	if soils.is_empty():
		var site := _debug_build_cell(Improvements.KIND_SOIL)
		if site.x < 0:
			print("[debug] Pop soil: no Soil placed and no free cell to build one on (%d/%d placed)." % [
				board.improvement_count(Improvements.KIND_SOIL), Improvements.cap_for(Improvements.KIND_SOIL)])
			return
		board.build_improvement(site, Improvements.KIND_SOIL)
		soils = [site]
	var popped := Vector2i(-1, -1)
	for raw_cell in soils:
		var cell := Vector2i(raw_cell)
		if board.expire_soil_step(cell, now) and popped.x < 0:
			popped = cell
	if popped.x < 0:
		var code := _debug_spawn_code()
		if code <= 0:
			print("[debug] Pop soil: every producible line is quest-asked right now — nothing safe to seed.")
			return
		for raw_cell in soils:
			var cell := Vector2i(raw_cell)
			if board.item_at(cell) != 0:
				continue                     # a soil holding an already-topped item cannot pop
			board.place(cell, code)
			if board.expire_soil_step(cell, now):
				popped = cell
			break
	if popped.x < 0:
		print("[debug] Pop soil: every placed Soil holds an item that cannot grow any further.")
		return
	var was := board.item_at(popped)
	_after_board_change()
	_debug_spotlight(popped, "Soil pop")
	print("[debug] Pop soil: %s grew %d -> %d." % [popped, was, board.item_at(popped)])

## Debug-only: make a Magnet do its auto-merge right now (the debug panel's "Pop magnet" button) by
## dropping a matching pair into its 3×3 range, so the pull can be watched on demand. ONE press works
## from ANY board state: the first placed Magnet with two free cells in range is used; when none has
## room — including when none is placed at all — one is BUILT on a cell that does have room.
## The pair goes on plain empty ground only (see _debug_magnet_room). _after_board_change runs the
## scan, so the merge itself takes the normal path. (A cascade in flight makes the rule stand down;
## the pair then merges on the scan that follows the chain, so the drop is never wasted.) The result
## is spotlighted, and every dead end prints why instead of returning silently.
## No _reflect — the pair lands and merges live, and _after_board_change persists it (no scene reload).
func debug_pop_magnet() -> void:
	if board == null or not _improvements_enabled():
		print("[debug] Pop magnet: improvements are switched off — there is nothing to pop.")
		return
	var code := _debug_spawn_code()
	if code <= 0:
		print("[debug] Pop magnet: every producible line is quest-asked right now — nothing safe to seed.")
		return
	var magnet := Vector2i(-1, -1)
	var room: Array = []
	for raw_cell in _improvement_cells(Improvements.KIND_MAGNET):
		var cell := Vector2i(raw_cell)
		var free_cells := _debug_magnet_room(cell)
		if free_cells.size() >= 2:           # a boxed-in Magnet is skipped for the next one that has room
			magnet = cell
			room = free_cells
			break
	if magnet.x < 0:
		magnet = _debug_build_cell(Improvements.KIND_MAGNET)
		if magnet.x < 0:
			print("[debug] Pop magnet: no placed Magnet has two free cells in range and there is nowhere to build one (%d/%d placed)." % [
				board.improvement_count(Improvements.KIND_MAGNET), Improvements.cap_for(Improvements.KIND_MAGNET)])
			return
		board.build_improvement(magnet, Improvements.KIND_MAGNET)
		room = _debug_magnet_room(magnet)
	var a := Vector2i(room[0])
	var b := Vector2i(room[1])
	board.place(a, code)
	board.place(b, code)
	_after_board_change()
	# _after_board_change rebuilds only when something CHANGED. If the magnet stood down, the pair
	# would sit in the model unrendered until the next rebuild — so draw it here instead. (The scan
	# runs before that call's own _rebuild_all, so the quest set it checks is the one _debug_spawn_code
	# filtered against; a rebuild first could refill the quests and re-ask the code mid-flight.)
	var stood_down := board.item_at(a) == code and board.item_at(b) == code
	if stood_down and board_area != null and is_instance_valid(board_area) and not _drag_active():
		_rebuild_all()
	# where to point: whichever half of the pair survived the pull. Neither, when the merged result
	# merged onward in the same scan — then the Magnet itself is the story.
	var focus := a if board.item_at(a) > 0 else b
	if board.item_at(focus) <= 0:
		focus = magnet
	_debug_spotlight(focus, "Magnet pull")
	if stood_down:
		print("[debug] Pop magnet: seeded a %d pair at %s/%s — a chain is running, so the Magnet at %s pulls it on the next scan." % [code, a, b, magnet])
	else:
		print("[debug] Pop magnet: the Magnet at %s pulled the seeded %d pair at %s/%s together." % [magnet, code, a, b])

## Debug-only: move the mastery rank of EVERY generator standing on the board by `delta` (the debug
## panel's "Gen rank ±1" buttons), so the raised pop windows and the rank-up card can be exercised
## without grinding the meter. A generator on a non-base line simply no-ops inside Mastery.set_rank —
## only base lines carry a meter. No scene reload: _after_board_change repaints the mastery rings and
## the selected generator's info row in place.
func debug_bump_mastery(delta: int) -> void:
	for raw_line in G.gen_live_lines(board.gens, G.GENERATORS):
		var line := int(raw_line)
		Mastery.set_rank(line, clampi(Mastery.rank(line) + delta, 0, G.MASTERY_THRESHOLDS.size()))
	_after_board_change()

func _blocked_seed_drop_lines() -> Array:
	if not _improvements_enabled():
		return [
			Improvements.seed_line_for_kind(Improvements.KIND_SOIL),
			Improvements.seed_line_for_kind(Improvements.KIND_MAGNET),
		]
	return Improvements.blocked_seed_drop_lines(board, bag)

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

# §6.B place a SPECIAL drop item near `near` (the lucky special-item shake) — same landing as the coin.
func _drop_special_near(near: Vector2i, code: int) -> void:
	_drop_item_near(near, code)

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

# Is any generator matching `pred` (an id -> bool Callable) on the board or in the gen bag?
func _board_has_gen(pred: Callable) -> bool:
	for v in board.gens.values():
		if pred.call(String(v)):
			return true
	for v in board.gen_bag:
		if pred.call(String(v)):
			return true
	return false

# §6.C is any limited-use BONUS generator currently on the board or in the bag (one at a time)?
func _has_bonus_gen() -> bool:
	return _board_has_gen(func(id: String) -> bool: return G.is_accumulator(id))

# Place `gid` on the first free cell with no generator, bank its tap budget under `clicks_key`, and pop
# it in. No-op when the board is full. `clicks` is a Callable so its rng draw happens ONLY after a cell
# is found — the rng is seeded + persisted, so the draw must not fire on the full-board path.
func _spawn_gen_on_free_cell(gid: String, clicks_key: String, clicks: Callable) -> void:
	var dest := Vector2i(-1, -1)
	for c in board.empty_ground_cells():
		if not board.gens.has(c):
			dest = c
			break
	if dest == Vector2i(-1, -1):
		return
	board.place_gen(gid, dest)
	Save.grove()[clicks_key] = int(clicks.call())
	_grown_cells.append(dest)             # _rebuild_all pops it in
	_rebuild_all()
	Audio.play("level_complete", -5.0, 1.25)

# §6.C side-spawn a limited-use bonus generator onto a free cell with a random tap budget. Skips if full.
# The KIND is drawn before the free-cell search, as it always was — a full board still consumes that draw.
func _spawn_bonus_gen() -> void:
	var kind := G.pick_bonus_kind(rng)
	if kind == "":
		return
	_spawn_gen_on_free_cell(String(G.ACCUMULATORS[kind].id), "bonus_clicks", func() -> int: return G.pick_bonus_clicks(rng))

# --- §6.D temporary treat generators (board) ----------------------------------------------------------
func _has_treat_gen() -> bool:
	return _board_has_gen(func(id: String) -> bool: return G.is_treat_gen(id))

# Pop a temp treat generator onto a free cell with a random tap budget (saved). Skips if the board is full.
# The line pick takes no rng (it is a per-map table lookup), so resolving the id up front is rng-neutral.
func _spawn_treat_gen() -> void:
	_spawn_gen_on_free_cell(G.treat_gen_id(G.pick_treat_line(_quest_map())), "treat_clicks", func() -> int: return G.pick_treat_clicks(rng))

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
		_drop_special_near(cell, G.pick_special_drop(rng, _blocked_seed_drop_lines()))   # the treat shower: a §6.B special item too
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
	if _defer_soil_reset([a], "Move", func() -> void: _commit_move_confirmed(a, b, node), func() -> void: _snap_back(a, node)):
		return
	_commit_move_confirmed(a, b, node)

func _commit_move_confirmed(a: Vector2i, b: Vector2i, node: Control) -> void:
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
	if _defer_soil_reset([a, b], "Move", func() -> void: _commit_swap_confirmed(a, b, node), func() -> void: _snap_back(a, node)):
		return
	_commit_swap_confirmed(a, b, node)

func _commit_swap_confirmed(a: Vector2i, b: Vector2i, node: Control) -> void:
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

func _bag_seed_rank_at(i: int) -> int:
	if i < 0 or i >= bag.size():
		return 1
	var code := int(bag[i])
	if Improvements.kind_for_seed(code) != Improvements.KIND_SOIL:
		return 1
	return clampi(int(bag_seed_ranks[i]) if i < bag_seed_ranks.size() else 1, 1, int(G.SOIL_MAX_RANK))

# Pad/trim bag_seed_ranks to `n` entries (a missing rank defaults to 1). The bag's parallel-array
# invariant is "equal sizes", and it is re-established only HERE: the two mutators below call this
# before touching either array, so a caller that wrote `bag` directly (the screenshot tools and a
# couple of test fixtures assign `scn.bag = [...]`) cannot leave the two out of step. Without it an
# append lands at the wrong index and a LATER seed reads its rank off the end of the array and
# silently arrives as rank 1 — an off-by-one here mis-assigns ranks to the WRONG seed.
func _bag_ranks_align_to(n: int) -> void:
	while bag_seed_ranks.size() < n:
		bag_seed_ranks.append(1)
	if bag_seed_ranks.size() > n:
		bag_seed_ranks.resize(n)

# The ONE way to put an item in the bag (cf. BoardModel.bag_add for generators). Never call
# bag.append() directly — that is what dropped the rank of the seed stashed after a bagged tool.
func _bag_append(code: int, seed_rank: int = 1) -> void:
	_bag_ranks_align_to(bag.size())     # align to the PRE-append bag so the new rank lands at the new index
	bag.append(code)
	if Improvements.kind_for_seed(code) == Improvements.KIND_SOIL:
		bag_seed_ranks.append(clampi(seed_rank, 1, int(G.SOIL_MAX_RANK)))
	else:
		bag_seed_ranks.append(1)

# The ONE way to take an item out of the bag. Returns the rank that travelled with it so the caller
# can hand it straight back to the board (see _retrieve_from_bag).
func _bag_remove_at(i: int) -> int:
	var rank := _bag_seed_rank_at(i)
	_bag_ranks_align_to(bag.size())     # equal sizes, so the one index removes exactly one pair
	bag.remove_at(i)
	bag_seed_ranks.remove_at(i)
	return rank


func _stash(from: Vector2i, node: Control) -> void:
	if not board.collect_reward_at(from).is_empty():
		# The bag stores only item codes; custom-value chest rewards must remain board collectables.
		_snap_back(from, node)
		return
	if bag.size() >= _bag_capacity():
		_snap_back(from, node)
		return
	if _defer_soil_reset([from], "Stash", func() -> void: _stash_confirmed(from, node), func() -> void: _snap_back(from, node)):
		return
	_stash_confirmed(from, node)

func _stash_confirmed(from: Vector2i, node: Control) -> void:
	var rank := board.seed_rank_at(from)
	var code := board.take(from)
	if Improvements.kind_for_seed(code) == Improvements.KIND_SOIL:
		_dismiss_soil_seed_teach()
	_bag_append(code, rank)
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
	var seed_rank := _bag_remove_at(i)
	board.place(cell, code)
	board.set_seed_rank(cell, seed_rank)
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
	var cell := board.first_item_of(int(it.line) * 100 + int(it.tier))
	if _defer_soil_reset([cell], "Deliver", func() -> void: _deliver_quest(qi, cell, chip)):
		return
	_deliver_quest(qi, cell, chip)

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
	if _defer_soil_reset([cell], "Deliver", func() -> void: _deliver_from_board_confirmed(cell, qi, chip)):
		return
	_deliver_from_board_confirmed(cell, qi, chip)

func _deliver_from_board_confirmed(cell: Vector2i, qi: int, chip: Control) -> void:
	_clear_selection()                        # the tile is leaving — drop its focus ring + info bar
	_deliver_quest(qi, cell, chip)

# The ONE delivery path, shared by the giver tap and the board second-tap. Consumes the item at `cell`,
# flies it to `chip`, pays the quest's reward (exp + coins + level-up), and drops the quest from the
# fence. `cell` is explicit so a board-tap consumes the EXACT tile tapped, not just first_item_of(code).
func _queue_mastery_rankups(rank_ups: Dictionary) -> void:
	if not Features.on("mastery") or rank_ups.is_empty():
		return
	for raw_line in rank_ups.keys():
		var line := int(raw_line)
		var target_rank := Mastery.rank(line)
		if target_rank <= Mastery.seen_rank(line):
			continue
		var replaced := false
		for i in range(_mastery_rankup_queue.size()):
			var queued: Dictionary = _mastery_rankup_queue[i]
			if int(queued.get("line", 0)) == line:
				queued["rank"] = maxi(int(queued.get("rank", 0)), target_rank)
				_mastery_rankup_queue[i] = queued
				replaced = true
				break
		if not replaced:
			_mastery_rankup_queue.append({"line": line, "rank": target_rank})

func _schedule_mastery_rankup(delay_seconds := 0.0) -> void:
	if not Features.on("mastery") or _mastery_rankup_queue.is_empty():
		return
	if delay_seconds <= 0.0 or not is_inside_tree():
		call_deferred("_show_next_mastery_rankup")
		return
	var timer := get_tree().create_timer(delay_seconds)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			_show_next_mastery_rankup())

func _show_next_mastery_rankup() -> void:
	if _mastery_rankup_open or _mastery_rankup_queue.is_empty():
		return
	if Overlay.is_open(self, LevelPopup.OVERLAY_NAME):
		return
	var entry: Dictionary = _mastery_rankup_queue.pop_front()
	var line := int(entry.get("line", 0))
	var rank := int(entry.get("rank", 0))
	var overlay := MasteryRankup.open(self, {"line": line, "rank": rank, "window": Mastery.window(line, quests)})
	if overlay == null:
		return
	Mastery.mark_seen_rank(line, rank)
	_mastery_rankup_open = true
	overlay.tree_exited.connect(func() -> void:
		_mastery_rankup_open = false
		if is_instance_valid(self):
			call_deferred("_show_next_mastery_rankup"))

func _deliver_quest(qi: int, cell: Vector2i, chip: Control) -> void:
	# Snapshot the unlock-bar meter BEFORE the action mutates exp/quests — the animation tweens from it.
	var purge_before := _purge_progress()
	# RULE: the whole state transition — consume the tile, drop the quest, remember the ask, advance exp
	# (the ONE place exp earns), pay the coin faucet — lives in the pure, headless-tested action. The scene
	# below is render-only: it reads the returned outcome to drive the fly, reward FX, level dialog, vase.
	var out := BoardActions.deliver_quest(board, quests, _recent_items, qi, cell)
	_queue_mastery_rankups(out.get("rank_ups", {}))
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
				_update_hud()
				_rebuild_givers()
				_refresh_giver_lights()
				_queue_farewell_check()
				_show_next_mastery_rankup())
		else:
			_schedule_mastery_rankup(MASTERY_RANKUP_FX_DELAY)
	else:
		_schedule_mastery_rankup(MASTERY_RANKUP_FX_DELAY)
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

# Queue one calm farewell sweep after board entry or after the level-up ceremony has closed. The queued
# seam keeps the card out of active gestures and lets any just-refilled quest fence settle first: a check
# that lands mid-gesture (or on a held info-tray selection) RE-QUEUES ITSELF one frame later instead of
# parking on a flag, so the card is deferred but never dropped — every gesture end is covered, including
# the ones that clear no selection (a bare tap on empty ground) and so have no seam of their own.
func _queue_farewell_check() -> void:
	if _farewell_check_queued:
		return
	_farewell_check_queued = true
	_run_farewell_check.call_deferred()

func _run_farewell_check() -> void:
	_farewell_check_queued = false
	if _farewell_check_waiting_for_player():
		_queue_farewell_check_after_frame()
		return
	_show_next_farewell()

func _show_next_farewell() -> void:
	if not is_inside_tree() or board == null or FarewellCard.is_open(self):
		return
	if _farewell_check_waiting_for_player():
		_queue_farewell_check_after_frame()   # defence in depth: a direct caller never pops a card into a live gesture
		return
	if not Save.board_tutorial_seen():
		return
	var due := BoardActions.farewells_due(board, _quest_level())
	if due.is_empty():
		return
	var entry: Dictionary = due[0]
	var line := int(entry.get("line", 0))
	var next_need: Dictionary = (entry.get("next_need", {}) as Dictionary).duplicate(true)
	var preview := BoardActions.farewell_preview(board, line)
	FarewellCard.open(self, {
		"line": line,
		"next_need": next_need,
		"pieces": int(preview.pieces),
		"coins": int(preview.coins),
		"on_close": Callable(self, "_on_farewell_card_closed").bind(line, next_need),
	})

func _farewell_check_waiting_for_player() -> bool:
	return _selected_cell.x >= 0 or _drag_active() or _pressing

func _on_farewell_card_closed(line: int, next_need: Dictionary) -> void:
	_sweep_farewell(line, next_need)

func _sweep_farewell(line: int, next_need: Dictionary) -> void:
	var out := BoardActions.sweep_line(board, int(line))
	var coins := int(out.get("coins", 0))
	if next_need.is_empty():
		var g := Save.grove()
		var retired: Dictionary = g.get("retired", {})
		retired[str(int(line))] = true
		g["retired"] = retired
		Save.grove_write()
	Audio.play("tidy_poof", -4.0, 1.1)
	if coins > 0:
		var center: Vector2 = get_global_rect().get_center()
		var done := func() -> void:
			if is_instance_valid(self):
				_update_hud()
		FX.reward_arrival(self, center, "coin", coins, STRAW, coins_label, done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "sale_payout")
	_clear_selection()
	_rebuild_all()
	_after_board_change(coins > 0)
	_queue_farewell_check_after_frame()

func _queue_farewell_check_after_frame() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(self):
		_queue_farewell_check()

func _open_almanac() -> void:
	if not Features.on("discovery_ladder"):
		return
	Almanac.open(self, {
		"entries": _almanac_entries(),
		"on_line": func(line: int) -> void:
			_open_ladder(line, 1, _almanac_ladder_suffix(line)),
	})

func _almanac_entries() -> Array:
	var seen: Dictionary = Save.grove().get("seen", {})
	var z := G.quest_zone_for_level(_quest_level())
	var out: Array = []
	for zi in G.ZONE_COUNT:
		var line := G.zone_line(int(zi))
		if line <= 0 or not G.LINES.has(line):
			continue
		var code := Quests.lowest_seen_code(line, seen)
		var next_need := G.next_need(line, _quest_level())
		var state := "producing" if G.line_needed_at_zone(line, z) else ("away" if not next_need.is_empty() else "complete")
		out.append({
			"line": line,
			"seen": code > 0,
			"code": code,
			"state": state,
			"back_level": int(next_need.get("level", 0)),
			"for_line": int(next_need.get("for_line", 0)),
		})
	return out

# The ladder-title suffix for ONE line: the same state _almanac_entries derives per row, read for the
# single row asked about (building all twelve to keep one is a Quests.lowest_seen_code + G.next_need
# per zone, thrown away). A line outside the zone roster (treat lines, drops) has no almanac row at all,
# and a line the current window still needs is "producing" — both carry no suffix.
func _almanac_ladder_suffix(line: int) -> String:
	if not G.LINES.has(int(line)) or G.zone_of_line(int(line)) < 0:
		return ""
	var lvl := _quest_level()
	if G.line_needed_at_zone(int(line), G.quest_zone_for_level(lvl)):
		return ""
	var next_need := G.next_need(int(line), lvl)
	if next_need.is_empty():
		return Strings.t("almanac.complete")
	return Strings.t("almanac.ladder_back") % [int(next_need.get("level", 0)), G.item_display_name(int(next_need.get("for_line", 0)) * 100 + 1)]

func _sell_item(from: Vector2i, node: Control) -> void:
	var code := board.item_at(from)
	if code <= 0:
		return
	if G.is_coin(code):
		_collect_coin(from, node)          # coins are money already — pocket them
		return
	if Improvements.kind_for_seed(code) == Improvements.KIND_SOIL:
		_end_hand_hint("soil_seed")
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
		FX.reward_arrival(self, center, "gem", reward.y, FX.reward_color("gem"), diamonds_label, sale_gem_done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "sale_payout")
	elif reward.x > 0:
		var sale_coin_done := func() -> void:
			if is_instance_valid(self):
				_update_hud()
		FX.reward_arrival(self, center, "coin", reward.x, STRAW, coins_label, sale_coin_done, FX.reward_fx_icon_size(), "+", FX.reward_fx_trail_count(), "sale_payout")

# The real gate lives on the HOME scene now (buying a spot IS the progression step) —
# this button is the invitation: stars suffice, go decorate.
# The upgrade path: the line's full ladder, tier by tier — grown tiers show their
# art, never-seen tiers show "?", and the tapped/asked tier wears a gold ring.
func _open_ladder(line: int, mark_tier: int, status_suffix: String = "") -> void:
	if not Features.on("discovery_ladder") or (not G.LINES.has(line) and not G.SPECIAL_ITEMS.has(line)):
		return
	# gen redesign #9/#15: a base line shows its GENERATOR icon atop the tier grid; a merged (special) line
	# shows its two ingredient items atop the SAME tier grid (its own ladder) — tapping either ingredient
	# opens THAT item's tier screen (Ladder rebuilds the modal in place, so navigation REPLACES, not stacks).
	var header := Quests.ladder_header(line, status_suffix)
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

# The board→Home handoff (req 3/4): ONE evolving home world now — the target is always the home
# scene itself (the per-map decorate jump retired with the map-select).
