extends Control
## The board — P1 core feel (water OFF).
## One persistent SAVED board: tap the seed satchel to pop items (random tier,
## ask-weighted line), drag matching plants together to grow them, merge beside
## brambles to clear them, drag onto empty ground to rearrange, stash in the Bag,
## feed top tiers to the Merchant, deliver quest asks to the fox/hedgehog for
## stars, and spend stars at the Restore gate to advance chapters (givers pause
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
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Bust = preload("res://engine/scripts/ui/bust.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const Shop = preload("res://engine/scripts/ui/shop.gd")   # §10: drains shop-bought item-shortcuts into the bag
const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Spotlight = preload("res://engine/scripts/core/spotlight.gd")          # T28: the §14 first-appearance gate
const SpotlightOverlay = preload("res://engine/scripts/ui/spotlight_overlay.gd")  # T28: the veil+pulse+hand guide
const HomeScene = preload("res://engine/scripts/scenes/map.gd")   # T2: the Decorate jump request
const Game = preload("res://engine/scripts/core/game.gd")
const Debug = preload("res://engine/scripts/ui/debug.gd")
const Pal = Game.PALETTE

const GAP := 10.0
const BOARD_MARGIN := 12.0       # breathing room each side; the board owns the rest
const FENCE_H := 212.0           # the quest fence band above the grid
const STAND_W := 330.0           # one giver's card width (the row scrolls when full)
const IDLE_HINT_SECS := 4.5      # W1: first idle hint sooner (was 7) → a mergeable pair rocks
const IDLE_RENUDGE_SECS := 4.0   # W1: re-nudge cadence while the player stays idle
const HINT_ROCK_DEG := 6.0       # W1: gentle rock amplitude (was a fast ±0.22rad shake)
const HINT_ROCK_CYCLE := 1.2     # W1: seconds per rock cycle
const HINT_ROCK_CYCLES := 3      # W1: number of slow rock cycles
const BAG_SLOTS = G.BAG_SLOTS    # the game's data owns the gameplay/economy tuning now
const BASKET_CAP = G.BASKET_CAP
const PORTER_SECS = G.PORTER_SECS
const TREAT_COST = G.TREAT_COST

# grove board palette (the night-purples retire here)
const GROUND = Pal.GROUND
const GROUND_EDGE = Pal.GROUND_EDGE
const BRAMBLE_BG = Pal.BRAMBLE_BG
const BRAMBLE_EDGE = Pal.BRAMBLE_EDGE
const CREAM = Pal.CREAM
const STRAW = Pal.STRAW

# §6: a full board DIMS the generator(s) to a standing "paused" state — popping is free
# while dimmed, so the cue must persist (not a one-shot wobble) until a cell frees up.
# GEN_DIM is the stopped look; GEN_LIT is full modulate (a cell is free → pop again).
const GEN_DIM := Color(1, 1, 1, 0.5)
const GEN_LIT := Color(1, 1, 1, 1.0)

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
var burst_chip: Control            # §6 coin sink: the on-board "upgrade burst" buy pill (board-level, global)
var burst_chip_label: Label
var giver_bar: Control           # the quest fence (givers pop up over it)
var giver_chips: Array = []        # [{chip, qi}]
var merchant_chip: Control
var merchant_sell_tag: Control       # W3: live "+N coin/gem" tag at the merchant's shoulder (drag only)
var merchant_sell_tag_label: Label
var merchant_sell_tag_icon: Control  # the tag's currency sprite — swapped coin↔gem per the dragged item's reward (§13)
# Y2/Y3: the merchant's collection basket — last <=3 sales, each with its EXACT grant
# for an exact buy-back. NOT persisted (the porter clears it within ~3 min anyway).
var basket: Array = []               # [{code, coins, diamonds}]
var basket_chip: Control             # the wicker basket beside the merchant stall
var _porter_timer := 0.0             # Y3: counts up while the basket has anything
var _porter_running := false
var _amb_layer: Control              # Z3: the board's wandering-spirit layer (a treat sends one over)
var gate_btn: Button
var bag_bar: HBoxContainer
var stars_label: Label
var coins_label: Label
var diamonds_label: Label
var level_label: Label            # S10: the shared Lv chip, wired in BOTH scenes
var chapter_label: Label
var bag_slots_ui: Array = []
var _open_shop: Callable = Callable()   # opens the shared Shop (wired from the HUD)
var bottom_bar: PanelContainer   # S1: the [Home | hint] plank row
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

func _ready() -> void:
	UiFont.apply()
	Music.ensure()
	# AF2: the play surface is the lightest thing because the MAT is light — NOT by
	# bleaching the background. A LIGHT veil (AC3) washed the painted meadow to a
	# colorless void; replace it with a gentle warm DIM that recedes the painting
	# while KEEPING its hue (calm ≠ bleached).
	Look.background(self, 0.0, Game.art("ui/bg_grove_board.png"))
	var calm_veil := ColorRect.new()
	calm_veil.color = Color("#2A2A1E", 0.20)        # soft warm dim — recede, don't erase
	calm_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	calm_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(calm_veil)
	_load_state()
	# sparse spirit life in the backdrop band above the fence (tap-less on the board)
	_amb_layer = Ambient.build_layer(Vector2(get_viewport_rect().size.x, 320.0),
		G.character_count(Save.grove().get("unlocks", {})), true)
	add_child(_amb_layer)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# the fence band lives BELOW the pinned HUD chips, never under them
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 64.0 + Look.safe_top(self))
	root.add_child(spacer)

	# S2: the chapter rides a solid CREAM title chip (Look.title_ribbon — ONE source
	# for all titles; the kit ribbon_title nine-patch collapses invisibly at chip
	# height, so the chapter title used to float as plain text). Gold-banner art is
	# an owner look-option (flagged), not guessed.
	var ribbon := Look.title_ribbon("", 30)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE   # single-input-surface law
	chapter_label = ribbon.get_child(0) as Label
	root.add_child(ribbon)

	# the quest fence: a full-width wall the giver animals pop up over, each
	# with a big cream ask-card (item + progress + star reward; ✓ when ready)
	giver_bar = Control.new()
	giver_bar.custom_minimum_size = Vector2(0, FENCE_H)
	giver_bar.size_flags_horizontal = Control.SIZE_FILL
	root.add_child(giver_bar)

	# the Decorate gate rides ON the fence — when it's ready the asks pause,
	# so the wall is exactly where the player's eye already is
	gate_btn = Look.button("", _on_gate, true)
	gate_btn.custom_minimum_size = Vector2(420, 88)
	# the CTA rides ON the busy fence — the kit btn_leaf nine-patch is a pill with
	# transparent ends, so the fence showed through and the button "lost" its
	# background (owner report). A SOLID StyleBoxFlat pill reads clearly on the wall.
	var gate_sb := StyleBoxFlat.new()
	gate_sb.bg_color = Color("#4E7C46")
	gate_sb.set_corner_radius_all(26)
	gate_sb.set_border_width_all(3)
	gate_sb.border_color = Color("#FBF3EA", 0.92)
	gate_sb.shadow_color = Color(0, 0, 0, 0.42)
	gate_sb.shadow_size = 8
	gate_sb.shadow_offset = Vector2(0, 4)
	gate_sb.content_margin_left = 24.0
	gate_sb.content_margin_right = 24.0
	gate_sb.content_margin_top = 12.0
	gate_sb.content_margin_bottom = 12.0
	gate_btn.add_theme_stylebox_override("normal", gate_sb)
	gate_btn.add_theme_stylebox_override("hover", gate_sb)
	gate_btn.add_theme_stylebox_override("disabled", gate_sb)
	var gate_sp := gate_sb.duplicate()
	gate_sp.bg_color = Color("#3F6B43")
	gate_btn.add_theme_stylebox_override("pressed", gate_sp)
	gate_btn.add_theme_color_override("font_color", Color("#FBF3EA"))
	gate_btn.add_theme_color_override("font_hover_color", Color("#FBF3EA"))
	gate_btn.add_theme_color_override("font_pressed_color", Color("#FBF3EA"))
	gate_btn.add_theme_color_override("font_disabled_color", Color("#FBF3EA", 0.6))
	# AA2: the Decorate CTA gets a RESERVED slot — pinned bottom-center of the BOARD,
	# above the Home/hint bar and clear of the fence band, so it never covers a giver
	# or the merchant (the owner's screenshot bug) at any fence population.
	gate_btn.anchor_left = 0.5
	gate_btn.anchor_right = 0.5
	gate_btn.anchor_top = 1.0
	gate_btn.anchor_bottom = 1.0
	gate_btn.offset_left = -210
	gate_btn.offset_right = 210
	var gate_inset := Look.safe_bottom(self)
	gate_btn.offset_top = -206 - gate_inset
	gate_btn.offset_bottom = -118 - gate_inset
	gate_btn.z_index = 10
	add_child(gate_btn)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	board_area = Control.new()
	# the board fills the screen side to side (owner); on wide screens the
	# HEIGHT budget binds instead so the fence/bag rows always fit
	var view := get_viewport_rect().size
	var w_csz := (view.x - 2.0 * BOARD_MARGIN - (G.COLS - 1) * GAP) / float(G.COLS)
	var h_csz := (view.y - 520.0 - (G.ROWS - 1) * GAP) / float(G.ROWS)
	csz = minf(w_csz, h_csz)
	board_area.custom_minimum_size = Vector2(_board_w(), _board_h())
	board_area.gui_input.connect(_on_board_input)
	center.add_child(board_area)

	bag_bar = HBoxContainer.new()
	bag_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bag_bar.add_theme_constant_override("separation", 12)
	bag_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(bag_bar)
	bag_bar.add_child(_lbl(tr("Bag"), 26, Pal.TEXT))
	for i in 3:
		var s := Button.new()
		s.focus_mode = Control.FOCUS_NONE
		s.custom_minimum_size = Vector2(84, 84)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(GROUND_EDGE, 0.6)
		sb.set_corner_radius_all(18)
		sb.set_border_width_all(3)
		sb.border_color = Color(CREAM, 0.35)
		s.add_theme_stylebox_override("normal", sb)
		s.add_theme_stylebox_override("hover", sb)
		s.add_theme_stylebox_override("pressed", sb)
		s.pressed.connect(_on_bag_tap.bind(i))
		bag_bar.add_child(s)
		bag_slots_ui.append(s)
	bag_bar.visible = _chapter_idx() >= 2 or not Features.on("ftue_staged_chrome")

	# S1: a COMPACT icon bar pinned bottom-LEFT — [◀ Home][🛒] (owner 2026-06-13:
	# dropped the inline tooltip; the shop moved here from the top cluster).
	var sb_inset := Look.safe_bottom(self)
	bottom_bar = PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color("#33402F", 0.88)
	bsb.set_corner_radius_all(20)
	bsb.content_margin_left = 10.0
	bsb.content_margin_right = 10.0
	bsb.content_margin_top = 8.0
	bsb.content_margin_bottom = 8.0
	bottom_bar.add_theme_stylebox_override("panel", bsb)
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_right = 0.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.grow_horizontal = Control.GROW_DIRECTION_END   # size to content rightward
	bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN    # ...and upward from the bottom edge
	bottom_bar.offset_left = 12
	bottom_bar.offset_right = 12
	bottom_bar.offset_top = -14 - sb_inset
	bottom_bar.offset_bottom = -14 - sb_inset
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	bottom_bar.add_child(brow)
	var home_btn := Look.button(tr("◀ Home"), func() -> void:
		Audio.play("button_tap", -2.0)
		HomeScene.decorate_map = String(G.MAPS[G.hub_map()].id)   # land on the HUB map
		get_tree().change_scene_to_file("res://engine/scenes/Map.tscn"), false)
	home_btn.custom_minimum_size = Vector2(150, 58)
	home_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brow.add_child(home_btn)
	shop_btn = Button.new()             # the Store, relocated from the top cluster
	shop_btn.flat = true
	shop_btn.focus_mode = Control.FOCUS_NONE
	shop_btn.custom_minimum_size = Vector2(58, 58)
	shop_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sc := Look.icon("cart", 40.0)
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_btn.add_child(sc)
	Look.add_press_juice(shop_btn)
	shop_btn.pressed.connect(func() -> void:
		Audio.play("button_tap", -2.0)
		if _open_shop.is_valid():
			_open_shop.call())
	brow.add_child(shop_btn)
	add_child(bottom_bar)

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
	# §8: the map armed a gate-unveil pointer on completion — point the player (wordlessly) at
	# the gate quest now waiting on the fence. Consume the pointer (fires once); the fence is
	# already built above, so the lone gate stand exists to pulse.
	if _take_gate_cue_map() >= 0:
		_play_gate_cue()

	Debug.mount(self)                    # base/testing debug panel (no-op in prod)

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
# §2: the hint also pulses the sealed cell(s) that merging that pair would OPEN —
# the "this merge unseals that" teach-signal. Same rock vocabulary as the pair.
func _hint_pair() -> Array:
	if not Features.on("idle_hint"):
		return []
	var pair := BoardLogic.find_mergeable_pair(board)
	for cell in pair:
		var n: Control = piece_nodes.get(cell)
		if n != null and is_instance_valid(n):
			FX.rock(n, HINT_ROCK_DEG, HINT_ROCK_CYCLE, HINT_ROCK_CYCLES)   # W1: gentle rock
	for cell in BoardLogic.openable_for_hint(board, pair, _quest_level()):
		var br: Control = bramble_nodes.get(cell)
		if br != null and is_instance_valid(br):
			FX.rock(br, HINT_ROCK_DEG, HINT_ROCK_CYCLE, HINT_ROCK_CYCLES)
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
		board.seed_gens(G.map_of_chapter(_chapter_idx()))   # seed the current map's set (migration)
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
	return Quests.meter_target(_quest_map(), Save.stars(), Save.grove().get("unlocks", {}), _quest_level())

# Current map fully spot-restored but its great-spirit GATE not yet delivered? Then the gate
# quest is the lone fence stand (§7) — delivering it unlocks the next map.
func _gate_pending() -> bool:
	return Quests.gate_pending(_quest_map(), Save.grove().get("unlocks", {}), _gates())

# §8 wordless map→board pointer. The map arms Save's gate_pointer on completion (the silent
# handoff); the board consumes it on open. Take the pending pointer (clears it so it fires
# exactly once) and decide whether a cue is due: only when it points at the CURRENT frontier
# map AND that gate is genuinely pending (the lone gate stand is on the fence to point at).
# Returns the map to cue, or -1 (nothing armed, or stale — consumed silently either way).
func _take_gate_cue_map() -> int:
	var z := Save.take_gate_pointer()
	if z >= 0 and z == _quest_map() and _gate_pending():
		return z
	return -1

# Play the wordless cue toward the just-unveiled gate quest: a sparkle burst over the lone
# gate stand plus a pop on its chip — no text the player must read (§13 no-required-reading).
# The gate stand is the sole fence stand when the gate is pending, so it is giver_chips[0].
func _play_gate_cue() -> void:
	if giver_chips.is_empty():
		return
	var chip: Control = giver_chips[0].get("chip")
	if chip == null or not is_instance_valid(chip):
		return
	FX.pop(chip)
	FX.breathe_once(chip)
	if Features.on("celebrate_bursts"):
		FX.burst(self, chip.get_global_rect().get_center(), STRAW)   # FX.burst's own default count
	Audio.play("level_complete", -6.0, 1.2)

# Top up / trim the live fence to the metered count with freshly generated quests (§7); once the
# map is fully restored, the fence becomes the lone authored GATE quest. Deterministic via the rng.
func _refill_quests() -> void:
	quests = Quests.refill(quests, _quest_map(), Save.grove().get("unlocks", {}), _gates(), board.gens, Save.stars(), _quest_level(), rng)

# §6: the current map's generator-grant hand-ins not yet claimed — each asks for a previous-map
# generator (still on the board) and rewards a new line. The map opens with these before its
# regular stream; once handed in, the new generators are live and regular quests resume.
func _pending_grant_quests() -> Array:
	return Quests.pending_grant_quests(_quest_map(), board.gens)

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

func _chapter_idx() -> int:
	return Save.grove().get("unlocks", {}).size()   # chapter = home spots bought

func _map_done() -> bool:                     # every map fully complete (spots + gate) — no frontier left
	return Quests.map_done(Save.grove().get("unlocks", {}), _gates())

# the restore CTA: ready once the CURRENT map's cheapest level-affordable spot is affordable.
# Scoped to the frontier map (gate-aware), so a fully-restored map (gate pending) is NOT
# "ready to restore" — the move there is delivering the gate quest, not buying a spot.
func _gate_ready() -> bool:
	return Quests.gate_ready(_quest_map(), Save.stars(), Save.grove().get("unlocks", {}), _quest_level())

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
		"home": func() -> void:
			Audio.play("button_tap", -2.0)
			HomeScene.decorate_map = String(G.MAPS[G.hub_map()].id)   # land on the HUB map
			get_tree().change_scene_to_file("res://engine/scenes/Map.tscn")})
	stars_label = hud.stars
	coins_label = hud.coins
	diamonds_label = hud.diamonds
	level_label = hud.level          # S10: store the board's Lv chip (set at build; exp is static here)
	_wallet_panel = hud.wallet       # water joins this cluster (see _build_water_hud)
	_open_shop = hud.open_shop       # the bottom-bar shop button opens it
	_update_hud()

# water lives in the shared currency cluster (top-right) next to the other
# currencies — no second row (owner 2026-06-13). The refill OFFER stays a separate
# button, shown only when empty.
func _build_water_hud() -> void:
	var row: HBoxContainer = _wallet_panel.get_child(0)
	_water_icon = Look.icon("water", 40.0)
	_water_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_water_icon)
	water_label = Label.new()
	water_label.add_theme_font_size_override("font_size", 34)
	water_label.add_theme_color_override("font_color", Color("#33402F"))   # dark, like the other currency labels
	water_label.add_theme_constant_override("outline_size", 0)
	water_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	water_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(water_label)
	refill_btn = Look.button(tr("Rain ☔ free refill"), _on_refill, true)
	refill_btn.custom_minimum_size = Vector2(330, 76)
	refill_btn.offset_left = 16.0
	refill_btn.offset_top = 16.0 + Look.safe_top(self) + 84.0   # top-left under the Lv chip; only shown at empty
	refill_btn.visible = false
	add_child(refill_btn)
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
	# FTUE: water stays hidden until the free intro pops are spent — hide just the
	# water icon + count, not the shared currency cluster
	var show_water := _ftue_pops_done() or not Features.on("ftue_staged_chrome")
	_water_icon.visible = show_water
	water_label.visible = show_water
	water_label.text = str(water)
	var free_left := refills_used < G.FREE_REFILLS
	refill_btn.visible = water <= 0 and (free_left or Save.diamonds() >= G.REFILL_DIAMOND_COST)
	if refill_btn.visible:
		refill_btn.text = tr("Rain ☔ free refill") if free_left else tr("Rain ☔ %d💎") % G.REFILL_DIAMOND_COST
		FX.breathe_once(refill_btn)

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
	refill_btn.visible = false
	_persist()
	_update_water_hud()
	_update_hud()

func _update_hud() -> void:
	stars_label.text = str(Save.stars())
	coins_label.text = str(Save.coins())
	if diamonds_label != null:
		diamonds_label.text = str(Save.diamonds())
	if _map_done():
		chapter_label.text = tr("The grove rests — more to grow soon ✿")
		gate_btn.visible = false
		return
	chapter_label.text = tr("Chapter %d") % (_chapter_idx() + 1)
	var ready := _gate_ready()
	gate_btn.text = tr("✿ Decorate!")
	gate_btn.visible = ready
	gate_btn.disabled = not ready
	gate_btn.modulate = Color(1, 1, 1, 1.0 if ready else 0.55)
	if ready:
		# AA2: at gate-ready the CTA breathes; once the chapter's quest pool runs DRY
		# (nothing left to earn) it ESCALATES to a hop — the soft nudge to advance.
		if _active_quest_idx().is_empty():
			FX.pop(gate_btn)
		else:
			FX.breathe_once(gate_btn)

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
		if c != gate_btn:
			c.queue_free()
	giver_chips.clear()
	_refill_quests()                          # §7: size the live fence to the meter before rendering
	var qidx := _active_quest_idx()
	var with_merchant := _chapter_idx() >= 1 or not Features.on("ftue_staged_chrome")
	var stands := qidx.size() + (1 if with_merchant else 0)
	merchant_chip = null
	if stands == 0:
		return
	# the fence wall — one bordered strip; busts and cards pop up over its edge
	var wall := Control.new()
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall.offset_top = 64.0
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	giver_bar.add_child(wall)
	giver_bar.move_child(wall, 0)
	# AB/owner fix: the fence sprite's background is now cut to transparent
	# (games/tools/cutout_bg.gd), so the SCENE shows through its gaps — no brown slab
	# behind it. The slab survives only as a FALLBACK when the fence art is absent.
	if ResourceLoader.exists(Game.art("ui/fence_grove.png")):
		var wt := TextureRect.new()
		wt.texture = load(Game.art("ui/fence_grove.png"))
		wt.set_anchors_preset(Control.PRESET_FULL_RECT)
		wt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wt.stretch_mode = TextureRect.STRETCH_SCALE
		wt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wall.add_child(wt)
	else:
		var wall_bg := Panel.new()
		wall_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		var ws := StyleBoxFlat.new()
		ws.bg_color = Color("#6E4B2F", 0.94)
		ws.set_corner_radius_all(18)
		ws.set_border_width_all(4)
		ws.border_color = Color("#3D2A1B")
		ws.shadow_color = Color(0, 0, 0, 0.3)
		ws.shadow_size = 6
		ws.shadow_offset = Vector2(0, 4)
		wall_bg.add_theme_stylebox_override("panel", ws)
		wall_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wall.add_child(wall_bg)
	# the stands scroll horizontally when the chapter is generous (cards stay BIG)
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
	if with_merchant:
		var ms := _make_merchant_stand()
		row.add_child(ms)
		merchant_chip = ms
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

# AB: the giver pops over the fence UNFRAMED — the chest-up cutout IS the UI.
# The ask rides a small content-sized cream pill UNDER them; the +N★ reward
# floats at the shoulder; a green check docks on the pill's corner when payable.
# No card, no border ring (the owner's "square" + "white slab" both gone) — the
# fence breathes around it.
func _make_giver_stand(qi: int, q: Dictionary) -> Dictionary:
	var stand := Control.new()
	stand.custom_minimum_size = Vector2(STAND_W, FENCE_H)
	stand.pivot_offset = Vector2(STAND_W / 2.0, FENCE_H * 0.6)
	var bust := _bust(qi % 2, 124.0)
	bust.position = Vector2((STAND_W - 124.0) / 2.0, 0.0)
	stand.add_child(bust)
	# Tier 2 §2: the idle-bob is NOT started here — it now means "deliverable", so
	# _refresh_giver_lights gates it per giver via _giver_is_payable. (The bust is
	# returned in the chip entry so the refresh can reach it.)
	# juice: the giver pops in when its stand enters the tree (deferred so the
	# tween is never created on a not-yet-in-tree node — matches _giver_bob)
	bust.tree_entered.connect(func() -> void:
		if is_instance_valid(bust) and bust.is_inside_tree():
			FX.pop_in(bust), CONNECT_ONE_SHOT)
	# the ask PILL — hugs [item icon + n/m] PER ASK (X3: 1–3 asks), centered under
	# the bust, on the fence. The capacity is the same pill; multi-ask just adds pairs.
	var pill := _ask_pill()
	pill.offset_top = 122.0
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(inner)
	var asks: Array = G.quest_asks(q)
	var ask_uis: Array = []
	if q.has("grant"):                        # §6: a generator-grant quest shows the NEW generator to receive
		var gdef: Dictionary = G.gen_def(G.GENERATORS, String(q.grant.grants))
		var gtex := Game.art(String(gdef.get("tex", "")))
		if ResourceLoader.exists(gtex):
			var gicon := TextureRect.new()
			gicon.texture = load(gtex)
			gicon.custom_minimum_size = Vector2(56, 56)
			gicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			gicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			gicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(gicon)
		var glbl := Label.new()
		glbl.text = tr("✿ new tool")
		glbl.add_theme_font_size_override("font_size", 22)
		glbl.add_theme_color_override("font_color", Color("#33402F"))
		glbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(glbl)
	var isz := 52.0 if asks.size() >= 2 else 56.0
	for ai in asks.size():
		var ask: Dictionary = asks[ai]
		var aline := int(ask.line)
		var atier := int(ask.tier)
		var acode := aline * 100 + atier
		if ai > 0:                              # a "+" joins the pairs of a multi-ask
			var plus := Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", 24)
			plus.add_theme_color_override("font_color", Color("#8A5A3B"))
			plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(plus)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(isz, isz)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP   # tapping the ITEM shows its ladder
		icon.add_child(_make_piece(acode, isz))
		_stand_tap(icon, func() -> void: _open_ladder(aline, atier))
		inner.add_child(icon)
		var prog := Label.new()
		prog.add_theme_font_size_override("font_size", 28)
		prog.add_theme_color_override("font_color", Color("#33402F"))
		prog.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(prog)
		ask_uis.append({"code": acode, "need": int(ask.count), "prog": prog})
	stand.add_child(pill)
	# AB3: the +N★ reward floats at the bust's shoulder — a bare star + count (no
	# chip slab; an ink outline lifts the number off the scene)
	var pay := HBoxContainer.new()
	pay.add_theme_constant_override("separation", 1)
	pay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pay.add_child(Look.icon("star", 30.0))
	var pay_lbl := Label.new()
	pay_lbl.text = "+%d" % _quest_stars(q)
	pay_lbl.add_theme_font_size_override("font_size", 24)
	pay_lbl.add_theme_color_override("font_color", STRAW)
	pay_lbl.add_theme_color_override("font_outline_color", Color("#33402F"))
	pay_lbl.add_theme_constant_override("outline_size", 5)
	pay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pay.add_child(pay_lbl)
	pay.position = Vector2(STAND_W / 2.0 + 30.0, 6.0)
	stand.add_child(pay)
	# §7 FEATURED: a small random share of regular quests are featured — flag it on the fence.
	# A code-drawn gold ribbon sits above the bust ("this one's special"); when the featured
	# bonus rolled a premium, a +N💎 rides the shoulder under the ★. The bonus is coins/premium,
	# never extra ★ (the ★ shoulder above is untouched by featuring).
	if bool(q.get("featured", false)):
		var ribbon := _featured_ribbon()
		ribbon.position = Vector2((STAND_W - 122.0) / 2.0, -2.0)
		stand.add_child(ribbon)
		var feat_gems := _quest_gems(q)
		if feat_gems > 0:
			var gem_pay := HBoxContainer.new()
			gem_pay.add_theme_constant_override("separation", 1)
			gem_pay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gem_pay.add_child(Look.icon("gem", 26.0))
			var gem_lbl := Label.new()
			gem_lbl.text = "+%d" % feat_gems
			gem_lbl.add_theme_font_size_override("font_size", 22)
			gem_lbl.add_theme_color_override("font_color", Color("#BFE6F2"))
			gem_lbl.add_theme_color_override("font_outline_color", Color("#33402F"))
			gem_lbl.add_theme_constant_override("outline_size", 5)
			gem_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			gem_pay.add_child(gem_lbl)
			gem_pay.position = Vector2(STAND_W / 2.0 + 30.0, 38.0)
			stand.add_child(gem_pay)
	# AB3: the ready check docks on the pill's TOP-LEFT corner (no ring border)
	var check := _ready_check()
	stand.add_child(check)
	_dock_check(check, pill, stand)
	_stand_tap(stand, func() -> void: _on_giver_tap(qi, stand))
	return {"chip": stand, "qi": qi, "asks": ask_uis, "check": check, "bust": bust}

# AB2: the shared ask pill — content-sized cream tray (StyleBoxFlat, soft warm
# border + shadow), anchored to center on its parent's x and grow both ways.
func _ask_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("#FBF6EC", 0.96)
	ps.set_corner_radius_all(18)
	ps.set_border_width_all(2)
	ps.border_color = Color("#C9A66B", 0.85)
	ps.shadow_color = Color(0, 0, 0, 0.22)
	ps.shadow_size = 4
	ps.shadow_offset = Vector2(0, 2)
	ps.content_margin_left = 14.0
	ps.content_margin_right = 16.0
	ps.content_margin_top = 7.0
	ps.content_margin_bottom = 7.0
	pill.add_theme_stylebox_override("panel", ps)
	pill.anchor_left = 0.5
	pill.anchor_right = 0.5
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pill

# §7 FEATURED: a code-drawn gold ribbon that crowns a featured giver's stand — a clear
# "this one's special" highlight on the fence (no art exists; Look-kit warm palette). A
# straw-gold pill, deeper-gold border + soft shadow, holding a ★ glyph + a "Featured" caption.
func _featured_ribbon() -> PanelContainer:
	var ribbon := PanelContainer.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = STRAW                        # the warm straw-gold accent the fence already uses
	rs.set_corner_radius_all(11)
	rs.set_border_width_all(2)
	rs.border_color = Color("#8A5A3B")         # the bark-brown border the asks/plus use
	rs.shadow_color = Color(0, 0, 0, 0.28)
	rs.shadow_size = 4
	rs.shadow_offset = Vector2(0, 2)
	rs.content_margin_left = 10.0
	rs.content_margin_right = 12.0
	rs.content_margin_top = 3.0
	rs.content_margin_bottom = 3.0
	ribbon.add_theme_stylebox_override("panel", rs)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.add_child(row)
	var star := Look.icon("star", 20.0)
	star.modulate = Color("#FBF3EA")           # a cream star reads on the straw fill
	row.add_child(star)
	var lbl := Label.new()
	lbl.text = tr("Featured")
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color("#4A2F1B"))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	return ribbon

func _ready_check() -> Panel:
	var check := Panel.new()
	check.custom_minimum_size = Vector2(40, 40)
	check.size = Vector2(40, 40)
	var ck_bg := StyleBoxFlat.new()
	ck_bg.bg_color = Color("#5CAF5C")
	ck_bg.set_corner_radius_all(20)
	ck_bg.set_border_width_all(3)
	ck_bg.border_color = Color("#FBF3EA")
	check.add_theme_stylebox_override("panel", ck_bg)
	var ck_icon := Look.icon("check", 26.0)
	ck_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ck_icon is Label:
		(ck_icon as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(ck_icon as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	check.add_child(ck_icon)
	check.visible = false
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return check

# keep the check pinned to the (content-sized, centered) pill's top-left corner
func _dock_check(check: Control, pill: Control, stand: Control) -> void:
	var dock := func() -> void:
		if not (is_instance_valid(check) and is_instance_valid(pill) and is_instance_valid(stand)):
			return
		check.position = pill.get_global_rect().position - stand.get_global_rect().position - Vector2(14.0, 14.0)
	pill.resized.connect(dock)
	dock.call_deferred()

# AB1: slow ±4px sine bob (~3s) on a bust. Tier 2 §2: the bob now carries "ready"
# information — only a DELIVERABLE giver bobs, so callers gate it with `active`
# (driven by _giver_is_payable in _refresh_giver_lights). The merchant, which is not
# a deliverable giver, keeps the default always-on bob.
#
# Idempotent + reversible: the live loop tween is parked in the "bob_tw" meta and the
# rest-Y baseline in "bob_y" (captured ONCE, so toggling never drifts the baseline
# mid-flight). active=true starts the loop if not already running; active=false kills
# it and settles the bust back to rest.
func _giver_bob(bust: Control, active: bool = true) -> void:
	if not Features.on("giver_bob"):
		return
	if not bust.has_meta("bob_y"):
		bust.set_meta("bob_y", bust.position.y)
		bust.set_meta("bob_tw", null)         # seed so later get_meta("bob_tw") never errors on a missing key (Godot 4.6 logs even with a default)
	if not active:
		_giver_bob_stop(bust)
		return
	var existing: Variant = bust.get_meta("bob_tw") if bust.has_meta("bob_tw") else null
	if existing is Tween and (existing as Tween).is_valid():
		return                                    # already bobbing — don't stack tweens
	# start now if already in the tree (the reactive payable case), else on entry
	if bust.is_inside_tree():
		_giver_bob_start(bust)
	else:
		bust.tree_entered.connect(func() -> void:
			# only (re)start if still wanted, and not already bobbing, when we enter the tree
			if not is_instance_valid(bust) or not bust.is_inside_tree():
				return
			# bob_tw may be unseeded here (e.g. the merchant bust): get_meta(key, null) ERRORS on a
			# missing key in Godot 4.6 — guard with has_meta to avoid the stderr spam (T35 missed this read)
			var tw: Variant = bust.get_meta("bob_tw") if bust.has_meta("bob_tw") else null
			if not (tw is Tween and (tw as Tween).is_valid()):
				_giver_bob_start(bust), CONNECT_ONE_SHOT)

func _giver_bob_start(bust: Control) -> void:
	var by: float = bust.get_meta("bob_y", bust.position.y)
	var tw := bust.create_tween().set_loops()
	tw.tween_property(bust, "position:y", by - 4.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(bust, "position:y", by, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bust.set_meta("bob_tw", tw)

func _giver_bob_stop(bust: Control) -> void:
	if bust.has_meta("bob_tw"):
		var existing: Variant = bust.get_meta("bob_tw")
		if existing is Tween and (existing as Tween).is_valid():
			(existing as Tween).kill()
		bust.set_meta("bob_tw", null)
	if bust.has_meta("bob_y"):
		bust.position.y = bust.get_meta("bob_y")   # settle to rest


# AB1: a FRAMELESS giver — the chest-up cutout IS the UI element (no panel, no
# border). Pops over the fence rail. Art-missing fallback is a ROUND initial chip
# (never a square).
func _bust(which: int, px: float = 124.0) -> Control:
	return Bust.make(which, px)

func _bust_layer(tex: Texture2D) -> TextureRect:
	return Bust.layer(tex)

func _mini_item(code: int) -> Control:
	return PieceView.mini_item(code)

# The merchant keeps the right end of the fence — same card anatomy.
func _make_merchant_stand() -> Control:
	var stand := Control.new()
	stand.custom_minimum_size = Vector2(STAND_W, FENCE_H)
	stand.pivot_offset = Vector2(STAND_W / 2.0, FENCE_H * 0.6)
	var bust := _bust(2, 124.0)              # AB4: frameless, like the givers
	bust.position = Vector2((STAND_W - 124.0) / 2.0, 0.0)
	stand.add_child(bust)
	_giver_bob(bust)
	var pill := _ask_pill()                  # the trade rides the same pill (W3 brightens it)
	pill.offset_top = 130.0
	var lbl := Label.new()
	lbl.text = tr("top \u25b6 +%d") % G.MERCHANT_COINS
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color("#6E4B2F"))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(lbl)
	stand.add_child(pill)
	# W3: a live "+N🪙" sell tag at the shoulder, shown only WHILE an item is dragged
	# (the dragged item's own sell_value) — the AB3 reward-chip convention.
	var tag := Look.stat_chip("coin", "")
	merchant_sell_tag = tag.node
	merchant_sell_tag_label = tag.label
	merchant_sell_tag_icon = tag.icon
	merchant_sell_tag_icon.set_meta("icon_id", "coin")   # the chip is built with the coin icon — track it for swaps
	(merchant_sell_tag_label as Label).add_theme_font_size_override("font_size", 22)
	merchant_sell_tag.position = Vector2(STAND_W / 2.0 + 30.0, 6.0)
	merchant_sell_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	merchant_sell_tag.visible = false
	stand.add_child(merchant_sell_tag)
	# Y2: the collection basket rides at the merchant's feet — sold items land here
	# and stay buy-backable until the porter collects. A wicker tray of <=3 sale chips.
	basket_chip = PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color("#9C7A4E", 0.96)        # wicker
	bsb.set_corner_radius_all(12)
	bsb.set_border_width_all(2)
	bsb.border_color = Color("#6E4B2F")
	bsb.shadow_color = Color(0, 0, 0, 0.22)
	bsb.shadow_size = 4
	bsb.content_margin_left = 8.0
	bsb.content_margin_right = 8.0
	bsb.content_margin_top = 5.0
	bsb.content_margin_bottom = 5.0
	basket_chip.add_theme_stylebox_override("panel", bsb)
	basket_chip.position = Vector2(STAND_W / 2.0 - 56.0, FENCE_H - 62.0)
	basket_chip.visible = false
	stand.add_child(basket_chip)
	_rebuild_basket()
	# Z3: a 10🪙 acorn treat at the stall — tap it and a wandering spirit scurries
	# over to nibble (a tiny, endlessly-repeatable coin sink between wayside buys).
	if Features.on("spirit_treats"):
		var treat := PanelContainer.new()
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color("#FBF6EC", 0.96)
		tsb.set_corner_radius_all(14)
		tsb.set_border_width_all(2)
		tsb.border_color = Color("#C9A66B", 0.9)
		tsb.shadow_color = Color(0, 0, 0, 0.22)
		tsb.shadow_size = 4
		tsb.content_margin_left = 8.0
		tsb.content_margin_right = 8.0
		tsb.content_margin_top = 4.0
		tsb.content_margin_bottom = 5.0
		treat.add_theme_stylebox_override("panel", tsb)
		var trow := HBoxContainer.new()
		trow.add_theme_constant_override("separation", 3)
		trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		treat.add_child(trow)
		if ResourceLoader.exists(Game.art("map/spirit_acorn.png")):
			var ac := TextureRect.new()
			ac.texture = load(Game.art("map/spirit_acorn.png"))
			ac.custom_minimum_size = Vector2(30, 30)
			ac.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ac.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ac.mouse_filter = Control.MOUSE_FILTER_IGNORE
			trow.add_child(ac)
		var tl := Label.new()
		tl.text = "%d" % TREAT_COST
		tl.add_theme_font_size_override("font_size", 22)
		tl.add_theme_color_override("font_color", Color("#33402F"))
		tl.add_theme_constant_override("outline_size", 0)
		trow.add_child(tl)
		trow.add_child(Look.icon("coin", 22.0))
		treat.position = Vector2(-22.0, 8.0)        # the merchant's shoulder-left
		_stand_tap(treat, _buy_treat)
		stand.add_child(treat)
	_stand_tap(stand, _on_merchant_tap)
	return stand

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

# W3: while ANY item is dragged, the merchant's stall brightens and a "+N🪙" tag
# (the dragged item's sell value) appears at his shoulder — the sell affordance.
func _show_sell_affordance(code: int) -> void:
	if not Features.on("sell_hints") or merchant_chip == null or not is_instance_valid(merchant_chip):
		return
	merchant_chip.modulate = Color(1, 1, 1, 1.0)
	if merchant_sell_tag != null and is_instance_valid(merchant_sell_tag):
		if merchant_sell_tag_label != null and is_instance_valid(merchant_sell_tag_label):
			var rw := G.sell_reward(code)          # Y1: a t8 sells for 1 gem, else N coins
			# §13: the number is pure ASCII ("+N") and the currency rides as a Look.icon
			# sprite (swapped coin↔gem) — never an emoji baked into the label text.
			var icon_id := "gem" if rw.y > 0 else "coin"
			var amount := rw.y if rw.y > 0 else rw.x
			merchant_sell_tag_label.text = "+%d" % amount
			_swap_tag_icon(icon_id)
		merchant_sell_tag.visible = true

func _hide_sell_affordance() -> void:
	if merchant_sell_tag != null and is_instance_valid(merchant_sell_tag):
		merchant_sell_tag.visible = false
	_refresh_giver_lights()   # restores the merchant's has-top modulate

# §13: swap the shoulder tag's currency sprite (coin↔gem) in place. The icon is the
# first child of the stat_chip row; we replace the node so it stays a Look.icon sprite
# (art-swappable) rather than re-coloring a baked emoji glyph.
func _swap_tag_icon(icon_id: String) -> void:
	if merchant_sell_tag_icon == null or not is_instance_valid(merchant_sell_tag_icon):
		return
	if merchant_sell_tag_icon.has_meta("icon_id") and String(merchant_sell_tag_icon.get_meta("icon_id")) == icon_id:
		return                                   # already showing this currency — nothing to do
	var row := merchant_sell_tag_icon.get_parent()
	if row == null:
		return
	var slot := merchant_sell_tag_icon.get_index()
	merchant_sell_tag_icon.queue_free()
	var fresh := Look.icon(icon_id, Look.Tune.ICON_PX)
	fresh.set_meta("icon_id", icon_id)
	row.add_child(fresh)
	row.move_child(fresh, slot)
	merchant_sell_tag_icon = fresh

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

# X3 / Tier 2 §2: the one notion of "deliverable" — every ask of this giver is fully
# on the board RIGHT NOW (the player could deliver it this instant). This is the SAME
# per-ask `count_of >= need` test that drives the green ✓ and matches
# BoardLogic.quest_payable (which works on the raw {line,tier,count} ask shape; here
# the asks are the UI {code,need} shape). A pure boolean, asserted by tests, that
# both the ✓ and the bob read so they can never diverge. Also refreshes each ask's n/m.
func _giver_is_payable(e: Dictionary) -> bool:
	var payable := true
	for ask in e.asks:
		var have := mini(board.count_of(int(ask.code)), int(ask.need))
		if have < int(ask.need):
			payable = false
		var prog: Label = ask.prog
		if prog != null and is_instance_valid(prog):
			prog.text = "%d/%d" % [have, int(ask.need)]
	return payable

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
			_giver_bob(bust, lit)
		var chip: Control = e.chip
		chip.modulate = Color(1, 1, 1, 1.0 if lit else 0.78)
		if lit:
			FX.breathe_once(chip)
	if merchant_chip != null and is_instance_valid(merchant_chip):
		var has_top := not board.top_tier_cells().is_empty()
		merchant_chip.modulate = Color(1, 1, 1, 1.0 if has_top else 0.6)

# §6: dim EVERY live generator to a standing "paused" look while the board has no free
# cell (popping is free while dimmed — only the cue is missing), and restore full modulate
# the instant a cell frees up. Called from every event that changes board fullness (pop,
# merge, sell, deliver, coin collect/drop, buy-back, refill, rebuild). Mirrors the
# giver-lights refresh: read board state, write modulate — no scattered ad-hoc writes.
# Safe alongside FX.breathe (that tweens scale, not modulate).
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
				var slot := Panel.new()
				slot.position = _cell_pos(cell)
				slot.size = Vector2(csz, csz)
				var sb := StyleBoxFlat.new()
				# AF4: a soft warm WELL (was a flat translucent green square) — a touch
				# darker+warmer than the light mat, with a gentle shadow for depth
				sb.bg_color = Color("#C7BB94", 0.55)
				sb.set_corner_radius_all(28)
				sb.set_border_width_all(2)
				sb.border_color = Color("#8A7A52", 0.32)
				sb.shadow_color = Color(0, 0, 0, 0.22)
				sb.shadow_size = 8
				sb.shadow_offset = Vector2(0, 3)
				slot.add_theme_stylebox_override("panel", sb)
				slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		gen_nodes[cell] = gn                  # keyed by CELL now (a gen can move, or be replaced by a hand-in grant)
	gen_node = gen_nodes.values()[0] if not gen_nodes.is_empty() else null
	_rebuild_burst_chip()                     # §6 coin sink: the "upgrade burst" buy pill on the primary generator
	# PARKED (T17): the locked-generator preview ("after N spots") was keyed on the old
	# per-chapter `appears_at`. Under per-map generators the next set arrives on map
	# COMPLETION, not after N spots — the preview needs redefining (show the next map's
	# incoming generators) alongside §6/§7. Disabled for now; the `gen_preview` flag stays.
	gen_preview_cells.clear()
	_rebuild_pieces()
	_rebuild_givers()
	_rebuild_bag()
	_refresh_generator_dim()   # §6: the freshly-built generators take their full/dimmed state
	_update_hud()
	_maybe_spotlight_chrome()

# T28 (§14): the instant a staged chrome feature FIRST appears, announce it once — a
# spotlight + pulse over it and a mimed tap/drag guide. Driven from _rebuild_all (which
# runs on every state change), but the first-appearance GATE (Spotlight.should_spotlight)
# fires each only once, ever. Target rects must be laid out, so resolve on the next frame.
# Only the chrome that is currently VISIBLE is eligible (merchant ch1+, bag ch2+, §14).
func _maybe_spotlight_chrome() -> void:
	if not Features.on("ftue_feature_spotlight"):
		return
	# nothing eligible? skip the deferred work entirely.
	if Spotlight.should_spotlight("merchant") or Spotlight.should_spotlight("bag") \
			or Spotlight.should_spotlight("shop"):
		_spotlight_chrome_deferred.call_deferred()

func _spotlight_chrome_deferred() -> void:
	await get_tree().process_frame              # let busts/slots get real global rects
	if not is_instance_valid(self) or not is_inside_tree():
		return
	# one at a time, in the staged order, so we never stack overlays. Merchant first
	# (appears earliest), then the bag, then the shop.
	if merchant_chip != null and is_instance_valid(merchant_chip) and Spotlight.should_spotlight("merchant"):
		_show_spotlight("merchant", merchant_chip)
		return
	if bag_bar != null and bag_bar.visible and not bag_slots_ui.is_empty() \
			and is_instance_valid(bag_slots_ui[0]) and Spotlight.should_spotlight("bag"):
		_show_spotlight("bag", bag_slots_ui[0])
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

func _make_board_mat() -> Control:
	return PieceView.make_board_mat(_board_w(), _board_h())


func _make_bramble(cell: Vector2i) -> Control:
	return PieceView.make_bramble(cell, csz)

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
			Audio.play("item_pickup", -6.0)
		return
	if board.item_at(cell) > 0:
		_drag_from = cell
		_drag_node = piece_nodes.get(cell)
		if _drag_node != null:
			_drag_node.z_index = 20
			_drag_node.scale = Vector2(1.12, 1.12)
			Audio.play("item_pickup", -6.0)
			_show_sell_affordance(board.item_at(cell))   # W3: the stall brightens + shoulder tag

func _on_release(pos: Vector2) -> void:
	if _drag_is_gen:
		_release_gen(pos)
		return
	if _drag_node == null:
		return
	var target := _pos_to_cell(pos)
	var from := _drag_from
	var node := _drag_node
	_drag_node = null
	_drag_from = Vector2i(-1, -1)
	node.z_index = 0
	node.scale = Vector2.ONE
	_hide_sell_affordance()   # W3: drag ended — drop the tag, restore the stall's modulate
	# the bag and the merchant's cart are drop targets too (global-rect check)
	var gp: Vector2 = board_area.get_global_transform() * pos
	for i in bag_slots_ui.size():
		if bag_slots_ui[i].get_global_rect().has_point(gp):
			_stash(from, node)
			return
	if merchant_chip != null and is_instance_valid(merchant_chip) \
			and merchant_chip.get_global_rect().has_point(gp):
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
	if target == from and pos.distance_to(_press_pos) <= 18.0:
		if node != null:
			node.position = _cell_pos(from)
		_pop_seed(from)                       # a still tap pops the generator (merge fuel)
		return
	var gp: Vector2 = board_area.get_global_transform() * pos
	if merchant_chip != null and is_instance_valid(merchant_chip) \
			and merchant_chip.get_global_rect().has_point(gp):
		if node != null:
			_snap_back(from, node)            # never sold
		return
	if target != from and board.is_empty_ground(target) and board.move_gen(from, target):
		Audio.play("item_drop", -3.0)
		_persist()
		_rebuild_all()                        # #1 move (generators are movable-only; grants arrive by hand-in quest)
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
	# the spawn decision (landing cell + code) is board_logic's; the active givers' wanted lines
	# bias every item's roll. Pool + wanted are fixed across the burst. RNG order is load-bearing.
	var pool: Array = G.gen_def(G.GENERATORS, board.gen_id_at(cell)).get("lines", [])
	var giver_quests: Array = []
	for e in giver_chips:
		if int(e.qi) >= 0 and int(e.qi) < quests.size():
			giver_quests.append(quests[int(e.qi)])
	var wanted: Array = BoardLogic.wanted_lines(pool, giver_quests)
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
		var spawn := BoardLogic.roll_spawn(empties, cell, pool, wanted, rng)
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

# The on-board burst-upgrade buy pill (§6 coin sink). The burst level is GLOBAL — one `burst_lvl`
# sizing every generator (spec §8: "board-level… independent of the hub") — so ONE pill, anchored
# to the primary generator, is the whole control. Rebuilt with the board (freed by _rebuild_all's
# child sweep). A still child with MOUSE_FILTER_STOP, so its tap buys and never pops the gen under it.
func _rebuild_burst_chip() -> void:
	burst_chip = null
	burst_chip_label = null
	if board.gens.is_empty():
		return
	var anchor: Vector2i = board.gens.keys()[0]
	var chip := Look.stat_chip("coin", "")
	burst_chip = chip.node
	burst_chip_label = chip.label
	(burst_chip_label as Label).add_theme_font_size_override("font_size", 18)
	burst_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	burst_chip.z_index = 12
	burst_chip.gui_input.connect(_on_burst_chip_input)
	board_area.add_child(burst_chip)
	_refresh_burst_chip()                      # sets the label → its width is known for centering
	var w: float = burst_chip.get_combined_minimum_size().x
	burst_chip.position = _cell_pos(anchor) + Vector2((csz - w) / 2.0, csz - 12.0)

func _on_burst_chip_input(ev: InputEvent) -> void:
	var pressed: bool = (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT) or ev is InputEventScreenTouch
	if pressed and ev.pressed:
		_try_buy_burst()

# Repaint the pill from the live level/cost — used right after a buy (no full board rebuild).
func _refresh_burst_chip() -> void:
	if burst_chip_label == null or not is_instance_valid(burst_chip_label):
		return
	var lvl := _gen_burst_level()
	var cost := G.burst_upgrade_cost(lvl)
	if cost < 0:
		burst_chip_label.text = tr("Burst L%d ✦") % lvl       # maxed — no further buy
	else:
		burst_chip_label.text = tr("Burst L%d ▸ %d") % [lvl, cost]

# Tap handler for the burst pill: spend coins to raise the burst one level, with feedback. Refuses
# (a wobble) when maxed or broke — _upgrade_gen_burst() owns the spend + cap rules. Testable directly.
func _try_buy_burst() -> void:
	if burst_chip == null or not is_instance_valid(burst_chip):
		return
	if G.burst_upgrade_cost(_gen_burst_level()) < 0:
		FX.wobble(burst_chip)                 # already at the top of the ladder
		Audio.play("invalid_soft", -4.0)
		return
	if not _upgrade_gen_burst():
		FX.wobble(burst_chip)                 # can't afford it
		Audio.play("invalid_soft", -4.0)
		_update_hud()                         # nudge the coin pill so the wall reads
		return
	FX.pop(burst_chip)
	Audio.play("merge_success", -2.0)
	FX.floating_text(self, burst_chip.get_global_rect().get_center() - Vector2(0, 24), tr("Burst L%d!") % _gen_burst_level(), STRAW, 30)
	_refresh_burst_chip()
	_update_hud()

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
	var slot := Panel.new()
	slot.position = _cell_pos(cell)
	slot.size = Vector2(csz, csz)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GROUND, 0.38)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(GROUND_EDGE, 0.5)
	slot.add_theme_stylebox_override("panel", sb)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

func _bag_capacity() -> int:
	return BoardLogic.bag_capacity(bool(Save.grove().get("bag3", false)))

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

func _on_bag_tap(i: int) -> void:
	# the third slot sells itself before it serves
	if i == BAG_SLOTS and not bool(Save.grove().get("bag3", false)):
		if Save.spend_diamonds(G.BAG3_DIAMOND_COST):
			Save.grove()["bag3"] = true
			Save.grove_write()
			Audio.play("level_complete", -4.0, 1.2)
			FX.celebrate_at(self, bag_slots_ui[i].get_global_rect().get_center(), tr("Bag +1!"), STRAW)
			_rebuild_bag()
			_update_hud()
		else:
			FX.wobble(bag_slots_ui[i])
			Audio.play("invalid_soft", -4.0)
		return
	if i >= bag.size():
		return
	var empties := board.empty_ground_cells()
	if empties.is_empty():
		FX.wobble(bag_slots_ui[i])
		Audio.play("invalid_soft", -4.0)
		return
	empties.sort_custom(func(a, b): return BoardLogic.dist_to_gen(a) < BoardLogic.dist_to_gen(b))
	var cell: Vector2i = empties[0]
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

func _rebuild_bag() -> void:
	bag_bar.visible = _chapter_idx() >= 2
	for i in bag_slots_ui.size():
		var s: Button = bag_slots_ui[i]
		for c in s.get_children():
			c.queue_free()
		if i == BAG_SLOTS and not bool(Save.grove().get("bag3", false)):
			# §13: the buyable third slot's price — gem SPRITE + a number-only "+N" label
			# (centered), never an emoji baked into the text.
			var lock := HBoxContainer.new()
			lock.set_anchors_preset(Control.PRESET_FULL_RECT)
			lock.alignment = BoxContainer.ALIGNMENT_CENTER
			lock.add_theme_constant_override("separation", 2)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var lock_ic := Look.icon("gem", 22.0)
			lock_ic.modulate = Color(CREAM, 0.55)
			lock.add_child(lock_ic)
			var lock_lbl := Label.new()
			lock_lbl.text = "+%d" % G.BAG3_DIAMOND_COST
			lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock_lbl.add_theme_font_size_override("font_size", 22)
			lock_lbl.add_theme_color_override("font_color", Color(CREAM, 0.55))
			lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lock.add_child(lock_lbl)
			s.add_child(lock)
			continue
		if i < bag.size():
			var mini_n := _make_piece(int(bag[i]), 76.0)
			mini_n.position = Vector2(4, 4)
			mini_n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s.add_child(mini_n)

# --- givers / merchant / gate actions ----------------------------------------------

func _on_giver_tap(qi: int, chip: Control) -> void:
	if qi < 0 or qi >= quests.size():
		return
	var q: Dictionary = quests[qi]
	if q.has("grant"):                        # §6/§7: a generator-grant quest — hand a generator in, not items
		_deliver_grant(qi, q, chip)
		return
	if q.get("gate", false):                  # §7: the great-spirit's gate quest — deliver to unlock the next map
		_deliver_gate(qi, q, chip)
		return
	var asks: Array = G.quest_asks(q)
	# X3: deliver only when EVERY ask is payable (multi-ask delivers all-or-nothing)
	if not BoardLogic.quest_payable(board, asks):
		FX.wobble(chip)
		Audio.play("invalid_soft", -6.0)
		return
	var flight := 0
	for ask in asks:
		var code := int(ask.line) * 100 + int(ask.tier)
		for k in int(ask.count):
			var cell := board.first_item_of(code)
			board.take(cell)
			var n: Control = piece_nodes.get(cell)
			piece_nodes.erase(cell)
			if n != null and is_instance_valid(n):
				var dest := chip.get_global_rect().get_center() - board_area.get_global_transform().origin - Vector2(csz, csz) / 2.0
				var t := n.create_tween()
				t.set_parallel(true)
				t.tween_property(n, "position", dest, 0.3 + 0.08 * flight).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				t.tween_property(n, "scale", Vector2(0.4, 0.4), 0.3 + 0.08 * flight)
				t.chain().tween_callback(n.queue_free)
			flight += 1
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
	FX.celebrate_reward(self, chip.get_global_rect().get_center(), "star", sp_stars, STRAW)
	if sp_coins > 0:
		FX.floating_reward(self, chip.get_global_rect().get_center() + Vector2(20, 36), "coin", sp_coins, STRAW, 26)
	if sp_gems > 0:
		FX.floating_reward(self, chip.get_global_rect().get_center() + Vector2(20, 64), "gem", sp_gems, Color("#BFE6F2"), 26)
	Audio.play("giver_cheer" if Audio.has("giver_cheer") else "merge_success", -2.0, 1.2)
	if levels_up > 0:
		water = int(Save.grove().get("water", water))   # re-sync the local after the level-up gift
		_update_water_hud()
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
	if _gate_ready():
		FX.floating_text(self, gate_btn.get_global_rect().get_center() - Vector2(140, 70), tr("Ready to restore!"), STRAW, 40)

## A generator-grant quest (§6): hand the predecessor generator in, install the granted
## one in its place, retire the old line. The §7 trigger; mirrors the item-delivery glue
## above (authored grant quests are scheduled by §7 — none are in the live script yet).
func _deliver_grant(qi: int, q: Dictionary, chip: Control) -> void:
	if not board.grant_gen(String(q.grant.grants)):
		FX.wobble(chip)                       # the predecessor generator isn't on the board
		Audio.play("invalid_soft", -6.0)
		return
	quests.remove_at(qi)
	var levels_up := G.earn_stars(_quest_stars(q))
	FX.celebrate_reward(self, chip.get_global_rect().get_center(), "star", _quest_stars(q), STRAW)
	Audio.play("giver_cheer" if Audio.has("giver_cheer") else "merge_success", -2.0, 1.2)
	if levels_up > 0:
		water = int(Save.grove().get("water", water))   # re-sync after the level-up gift
		_update_water_hud()
	_persist()
	_rebuild_all()                            # the granted generator changed — redraw the board
	_rebuild_givers()
	_update_hud()

## The great-spirit GATE quest (§7): the map's capstone. Deliver its top-tier asks → mark the
## gate done (the next map unlocks), grant the next map's generators, pay the large reward, and
## regenerate the fence for the new map. All-or-nothing like any delivery.
func _deliver_gate(qi: int, q: Dictionary, chip: Control) -> void:
	var asks: Array = G.quest_asks(q)
	if not BoardLogic.quest_payable(board, asks):
		FX.wobble(chip)
		Audio.play("invalid_soft", -6.0)
		return
	for ask in asks:
		var code := int(ask.line) * 100 + int(ask.tier)
		for _k in int(ask.count):
			board.take(board.first_item_of(code))
	var z := _quest_map()
	var g := Save.grove()
	var gates: Array = g.get("gates", [])
	if not gates.has(z):
		gates.append(z)
	g["gates"] = gates                        # §7: the gate is delivered → the next map unlocks
	Save.grove_write()
	if z + 1 < G.MAPS.size():                # the next map opens: its SURPLUS generators appear now;
		for sid in G.surplus_gen_ids(G.GENERATORS, z + 1):   # the hand-in ones arrive via grant quests (§6)
			board.place_surplus_gen(String(sid), G.gen_cell_of(G.GENERATORS, String(sid)))
	quests.remove_at(qi)
	var levels_up := G.earn_stars(_quest_stars(q))
	if _quest_coins(q) > 0:
		Save.add_coins(_quest_coins(q))
	# §13: the message stays text; the star reward rides an icon+number floater (no emoji).
	FX.celebrate_at(self, chip.get_global_rect().get_center(), tr("%s restored!") % tr(G.MAPS[z].name), STRAW)
	FX.floating_reward(self, chip.get_global_rect().get_center() + Vector2(0, 40), "star", _quest_stars(q), STRAW)
	Audio.play("level_complete" if Audio.has("level_complete") else "merge_success", -1.0)
	if levels_up > 0:
		water = int(Save.grove().get("water", water))
		_update_water_hud()
	_init_quests()                            # fresh fence for the newly opened map
	_persist()
	_rebuild_all()
	_rebuild_givers()
	_update_hud()

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

func _on_merchant_tap() -> void:
	var tops := board.top_tier_cells()
	if tops.is_empty():
		FX.wobble(merchant_chip)
		Audio.play("invalid_soft", -6.0)
		return
	var cell: Vector2i = tops[0]
	var code := board.item_at(cell)
	board.take(cell)
	var n: Control = piece_nodes.get(cell)
	piece_nodes.erase(cell)
	_grant_sale(code, n)
	Audio.play("tidy_poof", -1.0)
	_persist()
	_refresh_giver_lights()
	_refresh_generator_dim()   # §6: the merchant took a top-tier item → un-dim if the board was full
	_update_hud()

# Y1/Y2: pay the sale (t8 → 1💎, else 1-7🪙), fly the piece into the basket, float
# the right currency, and RECORD the sale so it can be bought back until the porter comes.
func _grant_sale(code: int, node: Control) -> void:
	var reward := G.sell_reward(code)        # Vector2i(coins, diamonds)
	if reward.x > 0:
		Save.add_coins(reward.x)
	if reward.y > 0:
		Save.add_diamonds(reward.y)
	var target: Control = basket_chip if (basket_chip != null and is_instance_valid(basket_chip)) else merchant_chip
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
	if not ResourceLoader.exists(Game.art("map/spirit_porter.png")):
		return
	_porter_running = true
	var sp := TextureRect.new()
	sp.texture = load(Game.art("map/spirit_porter.png"))
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

# The real gate lives on the HOME scene now (buying a spot IS the chapter) —
# this button is the invitation: stars suffice, go decorate.
# The upgrade path: the line's full ladder, tier by tier — grown tiers show their
# art, never-seen tiers show "?", and the tapped/asked tier wears a gold ring.
func _open_ladder(line: int, mark_tier: int) -> void:
	if not Features.on("discovery_ladder") or not G.LINES.has(line):
		return
	Audio.play("button_tap", -4.0)
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(GROUND_EDGE, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.kit_panel("parchment"))
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	col.add_child(_lbl(tr(String(G.LINES[line].name)), 34, GROUND_EDGE))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for e in _ladder_entries(line):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(112, 112)
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(GROUND, 0.18) if bool(e.seen) else Color(GROUND_EDGE, 0.16)
		ss.set_corner_radius_all(18)
		ss.set_border_width_all(4 if int(e.tier) == mark_tier else 2)
		ss.border_color = STRAW if int(e.tier) == mark_tier else Color(GROUND_EDGE, 0.35)
		slot.add_theme_stylebox_override("panel", ss)
		if bool(e.seen):
			var ic := _make_piece(int(e.code), 104.0)
			ic.position = Vector2(4, 4)
			slot.add_child(ic)
		else:
			var q := Look.icon("question", 52.0)
			q.set_anchors_preset(Control.PRESET_FULL_RECT)
			if q is Label:
				(q as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				(q as Label).add_theme_color_override("font_color", Color(CREAM, 0.45))
				(q as Label).add_theme_color_override("font_outline_color", GROUND_EDGE)
				(q as Label).add_theme_constant_override("outline_size", 6)
			slot.add_child(q)
		row.add_child(slot)
	FX.pop_in(card)

func _on_gate() -> void:
	if not _gate_ready():
		return
	Audio.play("button_tap", -2.0)
	_persist()
	# T2: Decorate jumps straight INTO the room you were decorating — the map is
	# the atlas you visit on purpose. Fresh save (no last_map) → the map, as ever.
	HomeScene.decorate_map = String(Save.grove().get("last_map", ""))
	get_tree().change_scene_to_file("res://engine/scenes/Map.tscn")

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
