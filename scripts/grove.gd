extends Control
## Ghibli Grove — P1 core feel (TIDY_UP_V2_SPEC §9 P1, water OFF).
## One persistent SAVED board: tap the seed satchel to pop items (random tier,
## ask-weighted line), drag matching plants together to grow them, merge beside
## brambles to clear them, drag onto empty ground to rearrange, stash in the Bag,
## feed top tiers to the Merchant, deliver quest asks to the fox/hedgehog for
## stars, and spend stars at the Restore gate to advance chapters (givers pause
## the moment the gate is affordable — the drive-to-spend loop).

const G = preload("res://scripts/grove_content.gd")
const GroveBoard = preload("res://scripts/grove_board.gd")
const Save = preload("res://scripts/save.gd")
const Palette = preload("res://scripts/palette.gd")
const Audio = preload("res://scripts/audio.gd")
const Music = preload("res://scripts/music.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Look = preload("res://scripts/skin.gd")
const FX = preload("res://scripts/fx.gd")
const Hud = preload("res://scripts/hud.gd")
const Ambient = preload("res://scripts/ambient.gd")
const Features = preload("res://scripts/features.gd")
const HomeScene = preload("res://scripts/home.gd")   # T2: the Decorate jump request

const GAP := 10.0
const BOARD_MARGIN := 12.0       # breathing room each side; the board owns the rest
const FENCE_H := 212.0           # the quest fence band above the grid
const STAND_W := 330.0           # one giver's card width (the row scrolls when full)
const IDLE_HINT_SECS := 4.5      # W1: first idle hint sooner (was 7) → a mergeable pair rocks
const IDLE_RENUDGE_SECS := 4.0   # W1: re-nudge cadence while the player stays idle
const HINT_ROCK_DEG := 6.0       # W1: gentle rock amplitude (was a fast ±0.22rad shake)
const HINT_ROCK_CYCLE := 1.2     # W1: seconds per rock cycle
const HINT_ROCK_CYCLES := 3      # W1: number of slow rock cycles
const BAG_SLOTS := 2
const BASKET_CAP := 3            # Y2: the merchant's basket holds the last 3 sales for buy-back
const PORTER_SECS := 180.0       # Y3: the porter collects the basket every ~3 min
const TREAT_COST := 10           # Z3: an acorn treat for a wandering spirit (a tiny recurring coin sink)

# grove board palette (the night-purples retire here)
const GROUND := Color("#3F6B43")
const GROUND_EDGE := Color("#33402F")
const BRAMBLE_BG := Color("#4A5A3A")
const BRAMBLE_EDGE := Color("#33402F")
const CREAM := Color("#FBF3EA")
const STRAW := Color("#E3B23C")

var board: GroveBoard
var rng := RandomNumberGenerator.new()
var qdone: Array = []
var qdone_chapter := -1            # which chapter qdone belongs to (chapter = spots bought)
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
var giver_bar: Control           # the quest fence (givers pop up over it)
var giver_chips: Array = []        # [{chip, qi}]
var merchant_chip: Control
var merchant_sell_tag: Control       # W3: live "+N🪙" tag at the merchant's shoulder (drag only)
var merchant_sell_tag_label: Label
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

var _press_cell := Vector2i(-1, -1)
var _press_pos := Vector2.ZERO
var _gen_tap := false
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
	Look.background(self, 0.0, "res://assets/ui/bg_grove_board.png")
	var calm_veil := ColorRect.new()
	calm_veil.color = Color("#2A2A1E", 0.20)        # soft warm dim — recede, don't erase
	calm_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	calm_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(calm_veil)
	_load_state()
	# sparse spirit life in the backdrop band above the fence (tap-less on the board)
	_amb_layer = Ambient.build_layer(Vector2(get_viewport_rect().size.x, 320.0),
		Save.grove().get("unlocks", {}), true)
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
	bag_bar.add_child(_lbl(tr("Bag"), 26, Palette.TEXT))
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
		get_tree().change_scene_to_file("res://scenes/Home.tscn"), false)
	home_btn.custom_minimum_size = Vector2(150, 58)
	home_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brow.add_child(home_btn)
	var shop_btn := Button.new()        # the Store, relocated from the top cluster
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
func _hint_pair() -> Array:
	if not Features.on("idle_hint"):
		return []
	var seen := {}
	for i in board.items.size():
		var k: int = board.items[i]
		if k <= 0:
			continue
		var top: int = G.COIN_TOP if G.is_coin(k) else G.TOP_TIER
		if GroveBoard.tier_of(k) >= top:
			continue
		if seen.has(k):
			var pair: Array = [seen[k], GroveBoard.cell_of(i)]
			for cell in pair:
				var n: Control = piece_nodes.get(cell)
				if n != null and is_instance_valid(n):
					FX.rock(n, HINT_ROCK_DEG, HINT_ROCK_CYCLE, HINT_ROCK_CYCLES)   # W1: gentle rock
			return pair
		seen[k] = GroveBoard.cell_of(i)
	return []

func _board_w() -> float:
	return G.COLS * csz + (G.COLS - 1) * GAP

func _board_h() -> float:
	return G.ROWS * csz + (G.ROWS - 1) * GAP

# --- state ----------------------------------------------------------------------

func _load_state() -> void:
	board = GroveBoard.new()
	var now := Time.get_unix_time_from_system()
	var g := Save.grove()
	if g.has("board"):
		board.from_dict(g["board"])
		qdone = Array(g.get("qdone", []))
		qdone_chapter = int(g.get("qdone_chapter", -1))
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
		_reset_qdone()
		_persist()
	board.set_active_gens(_chapter_idx())
	if qdone_chapter != _chapter_idx() or qdone.size() != _chapter().quests.size():
		_reset_qdone()
	for v in board.items:                # everything already growing counts as met
		_mark_seen(int(v))
	for v in bag:
		_mark_seen(int(v))

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
	var seen: Dictionary = Save.grove().get("seen", {})
	var out: Array = []
	for t in range(1, G.TOP_TIER + 1):
		var code := line * 100 + t
		out.append({"tier": t, "code": code, "seen": seen.has(str(code))})
	return out

# offline + online regen share one rule: +1 per REGEN_SECS from the anchor, capped
func _apply_regen(now: float) -> void:
	if water >= G.WATER_CAP:
		_regen_ts = now
		return
	var gained := int((now - _regen_ts) / G.REGEN_SECS)
	if gained > 0:
		water = mini(G.WATER_CAP, water + gained)
		_regen_ts = now if water >= G.WATER_CAP else _regen_ts + gained * G.REGEN_SECS

func _reset_qdone() -> void:
	qdone = []
	qdone_chapter = _chapter_idx()
	for q in _chapter().quests:
		qdone.append(false)

func _persist() -> void:
	var g := Save.grove()
	g["board"] = board.to_dict()
	g["qdone"] = qdone
	g["qdone_chapter"] = qdone_chapter
	g["bag"] = bag
	g["rng_state"] = rng.state
	g["water"] = water
	g["refills_used"] = refills_used
	g["regen_ts"] = _regen_ts
	g["last_seen"] = Time.get_unix_time_from_system()
	Save.grove_write()

func _chapter_idx() -> int:
	return Save.grove().get("unlocks", {}).size()   # chapter = home spots bought

func _chapter() -> Dictionary:
	return G.chapters()[mini(_chapter_idx(), G.chapters().size() - 1)]

func _map_done() -> bool:
	return _chapter_idx() >= G.chapters().size()

# the gate: the givers pause once the frontier zone's cheapest spot that the
# player's LEVEL allows is affordable (level-locked spots can't pause the garden)
func _gate_ready() -> bool:
	var g := Save.grove()
	var lvl := G.level_for_exp(int(g.get("exp", 0)))
	var cost := G.cheapest_spot_cost(g.get("unlocks", {}), lvl)
	return cost > 0 and Save.stars() >= cost

# --- HUD ------------------------------------------------------------------------

func _build_hud() -> void:
	# the shared top bar (owner: one module, currencies in the same place everywhere)
	var hud := Hud.build(self, {"water_grant": func() -> void:
		water = G.WATER_CAP
		_update_water_hud()
		_persist()})
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
	FX.celebrate_at(self, refill_btn.get_global_rect().get_center(), tr("+%d💧") % G.WATER_CAP, Color("#9CCDE8"))
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
	var out: Array = []
	if _map_done():
		return out
	# AA: the star gate is SOFT — the givers keep serving the chapter's FULL pool
	# even past gate-ready (the player may bank stars if they want). The pool is
	# finite, so it exhausts NATURALLY; once it's dry the only thing left to earn is
	# the Decorate gate. (No artificial pause — the old `_gate_ready()` stop is gone.
	# LEVEL-gating of spots is untouched; that lives in cheapest_spot_cost.)
	for i in qdone.size():
		if not qdone[i]:
			out.append(i)
		if out.size() == 5:                   # the fence seats five (owner: show MORE)
			break
	return out

func _rebuild_givers() -> void:
	for c in giver_bar.get_children():
		if c != gate_btn:
			c.queue_free()
	giver_chips.clear()
	var quests := _active_quest_idx()
	var with_merchant := _chapter_idx() >= 1 or not Features.on("ftue_staged_chrome")
	var stands := quests.size() + (1 if with_merchant else 0)
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
	# (tools/cutout_bg.gd), so the SCENE shows through its gaps — no brown slab
	# behind it. The slab survives only as a FALLBACK when the fence art is absent.
	if ResourceLoader.exists("res://assets/ui/fence_grove.png"):
		var wt := TextureRect.new()
		wt.texture = load("res://assets/ui/fence_grove.png")
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
	for k in quests.size():
		var qi: int = quests[k]
		var stand := _make_giver_stand(qi, _chapter().quests[qi])
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
	_giver_bob(bust)
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
	pay_lbl.text = "+%d" % int(q.stars)
	pay_lbl.add_theme_font_size_override("font_size", 24)
	pay_lbl.add_theme_color_override("font_color", STRAW)
	pay_lbl.add_theme_color_override("font_outline_color", Color("#33402F"))
	pay_lbl.add_theme_constant_override("outline_size", 5)
	pay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pay.add_child(pay_lbl)
	pay.position = Vector2(STAND_W / 2.0 + 30.0, 6.0)
	stand.add_child(pay)
	# AB3: the ready check docks on the pill's TOP-LEFT corner (no ring border)
	var check := _ready_check()
	stand.add_child(check)
	_dock_check(check, pill, stand)
	_stand_tap(stand, func() -> void: _on_giver_tap(qi, stand))
	return {"chip": stand, "qi": qi, "asks": ask_uis, "check": check}

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

# AB1: slow ±4px sine bob (~3s) once the bust is in the tree (giver_bob)
func _giver_bob(bust: Control) -> void:
	if not Features.on("giver_bob"):
		return
	bust.tree_entered.connect(func() -> void:
		if not is_instance_valid(bust) or not bust.is_inside_tree():
			return
		var by := bust.position.y
		var tw := bust.create_tween().set_loops()
		tw.tween_property(bust, "position:y", by - 4.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(bust, "position:y", by, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))


# AB1: a FRAMELESS giver — the chest-up cutout IS the UI element (no panel, no
# border). Pops over the fence rail. Art-missing fallback is a ROUND initial chip
# (never a square).
func _bust(which: int, px: float = 124.0) -> Control:
	var face := Control.new()
	face.custom_minimum_size = Vector2(px, px)
	face.size = Vector2(px, px)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://assets/map/giver_%s.png" % (["fox", "hedgehog", "squirrel"][which])
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		# owner 2026-06-13: the frameless cutout blended into the painted scene.
		# A soft drop shadow + a cream rim (scaled silhouette copies behind) lift it
		# off the background without a hard square frame.
		var center := Vector2(px / 2.0, px / 2.0)
		var shadow := _bust_layer(tex)
		shadow.modulate = Color(0, 0, 0, 0.40)
		shadow.pivot_offset = center
		shadow.scale = Vector2(1.04, 1.04)
		shadow.position = Vector2(0, 7)
		face.add_child(shadow)
		var rim := _bust_layer(tex)
		rim.modulate = CREAM
		rim.pivot_offset = center
		rim.scale = Vector2(1.11, 1.11)
		face.add_child(rim)
		face.add_child(_bust_layer(tex))
	else:
		var chip := Panel.new()                 # round, not square
		chip.set_anchors_preset(Control.PRESET_FULL_RECT)
		var cs := StyleBoxFlat.new()
		cs.bg_color = [Color("#C96F4A"), Color("#8A5A3B"), Color("#7FA65A")][which % 3]
		cs.set_corner_radius_all(int(px / 2.0))
		cs.set_border_width_all(3)
		cs.border_color = CREAM
		chip.add_theme_stylebox_override("panel", cs)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var init := Label.new()
		init.text = ["F", "H", "S"][which % 3]
		init.set_anchors_preset(Control.PRESET_FULL_RECT)
		init.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		init.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		init.add_theme_font_size_override("font_size", int(px * 0.32))
		init.add_theme_color_override("font_color", CREAM)
		init.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(init)
		face.add_child(chip)
	return face

# one full-rect, aspect-centered copy of a bust texture (used for the bust itself
# plus its drop-shadow and cream-rim layers).
func _bust_layer(tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _mini_item(code: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(52, 52)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := _make_piece(code, 52.0)
	holder.add_child(n)
	return holder

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
		if ResourceLoader.exists("res://assets/map/spirit_acorn.png"):
			var ac := TextureRect.new()
			ac.texture = load("res://assets/map/spirit_acorn.png")
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
			var rw := G.sell_reward(code)          # Y1: a t8 shows "+1💎", else "+N🪙"
			merchant_sell_tag_label.text = ("+%d💎" % rw.y) if rw.y > 0 else ("+%d" % rw.x)
		merchant_sell_tag.visible = true

func _hide_sell_affordance() -> void:
	if merchant_sell_tag != null and is_instance_valid(merchant_sell_tag):
		merchant_sell_tag.visible = false
	_refresh_giver_lights()   # restores the merchant's has-top modulate

# W3: the first time a MAX-TIER item lands on the board, a one-time floater points
# the player at the stall (persisted seen-flag — never nags twice).
func _note_item_landed(code: int) -> void:
	if not Features.on("sell_hints") or G.is_coin(code) or GroveBoard.tier_of(code) < G.TOP_TIER:
		return
	var g := Save.grove()
	if bool(g.get("seen_sell_hint", false)):
		return
	g["seen_sell_hint"] = true
	FX.floating_text(self, Vector2(get_global_rect().get_center().x - 250, 220),
		tr("the merchant buys spares — drag it to his stall"), CREAM, 28)

func _refresh_giver_lights() -> void:
	for e in giver_chips:
		# X3: the giver is ready only when EVERY ask is satisfied; each ask shows its own n/m
		var lit := true
		for ask in e.asks:
			var have := mini(board.count_of(int(ask.code)), int(ask.need))
			if have < int(ask.need):
				lit = false
			var prog: Label = ask.prog
			if prog != null and is_instance_valid(prog):
				prog.text = "%d/%d" % [have, int(ask.need)]
		var ready_ui := lit and Features.on("quest_ready_check")
		var check: Control = e.check
		if check != null and is_instance_valid(check):
			check.visible = ready_ui     # AB3: the check IS the ready state (no ring)
		var chip: Control = e.chip
		chip.modulate = Color(1, 1, 1, 1.0 if lit else 0.78)
		if lit:
			FX.breathe_once(chip)
	if merchant_chip != null and is_instance_valid(merchant_chip):
		var has_top := not board.top_tier_cells().is_empty()
		merchant_chip.modulate = Color(1, 1, 1, 1.0 if has_top else 0.6)

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
				sb.set_corner_radius_all(16)
				sb.set_border_width_all(2)
				sb.border_color = Color("#8A7A52", 0.45)
				sb.shadow_color = Color(0, 0, 0, 0.13)
				sb.shadow_size = 5
				sb.shadow_offset = Vector2(0, 2)
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
	for gi in G.active_gen_indices(_chapter_idx()):
		var gn := _make_generator(gi)
		gn.position = _cell_pos(Vector2i(G.GENERATORS[gi].cell))
		board_area.add_child(gn)
		FX.breathe(gn)
		gen_nodes[gi] = gn
	gen_node = gen_nodes.get(0)
	# V1: locked generators preview — the moment a bramble gated on a generator's
	# line is REVEALED, its future cell shows a greyed silhouette + "after N spots"
	# so the edge stops reading as impossible. (The cell stays bramble; no gameplay
	# change — tapping it just floats the name.)
	gen_preview_cells.clear()
	if Features.on("gen_preview"):
		var ch := _chapter_idx()
		for gi in G.GENERATORS.size():
			if ch >= int(G.GENERATORS[gi].appears_at):
				continue                     # already arrived (rendered above)
			if not _gen_line_revealed(gi):
				continue
			var cell := Vector2i(G.GENERATORS[gi].cell)
			var pv := _make_gen_preview(gi)
			pv.position = _cell_pos(cell)
			board_area.add_child(pv)
			gen_preview_cells[cell] = gi
	_rebuild_pieces()
	_rebuild_givers()
	_rebuild_bag()
	_update_hud()

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

# S3/AC: the bramble art reads near-BLACK on the light tray — heavier than
# anything else. A multiply-modulate can't lift black; this warm-lift shader adds
# a deep MOSS-BROWN floor and rides the texture on top with a warm gain, so the
# nests read as warm earth (not black) while keeping their detail. One shared mat.
const BRAMBLE_WARM_SHADER := "
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 moss = vec3(0.40, 0.32, 0.18);
	vec3 outc = min(moss + c.rgb * vec3(1.25, 1.10, 0.80), vec3(0.92));
	COLOR = vec4(outc, c.a) * COLOR;
}"
static var _bramble_material: ShaderMaterial
static func _bramble_mat() -> ShaderMaterial:
	if _bramble_material == null:
		var sh := Shader.new()
		sh.code = BRAMBLE_WARM_SHADER
		_bramble_material = ShaderMaterial.new()
		_bramble_material.shader = sh
	return _bramble_material

# U1: a soft white radial ellipse (alpha fades to 0 at the rim); modulated to the
# warm-earth backing colour at the call site. Cached — one texture for the board.
static var _backing: Texture2D
static func _backing_tex() -> Texture2D:
	if _backing == null:
		var w := 96
		var h := 64
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var cx := (w - 1) / 2.0
		var cy := (h - 1) / 2.0
		for y in h:
			for x in w:
				var nx := (float(x) - cx) / cx
				var ny := (float(y) - cy) / cy
				var a := clampf(1.0 - sqrt(nx * nx + ny * ny), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))   # squared = feathered rim
		_backing = ImageTexture.create_from_image(img)
	return _backing

func _make_piece(code: int, size: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.size = Vector2(size, size)
	holder.pivot_offset = Vector2(size, size) / 2.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# AF3: a soft warm CONTACT SHADOW under the item (first child = bottom) — tight
	# and LOW (it grounds the piece on the light mat), not the old centered dark
	# ellipse that vanished on a light surface. Warm-grey, ~28% alpha, never eats input.
	if Features.on("item_backing"):
		var back := TextureRect.new()
		back.texture = _backing_tex()
		var bw := size * 0.62
		var bh := size * 0.22
		back.position = Vector2((size - bw) / 2.0, size * 0.70)   # low — a contact shadow
		back.size = Vector2(bw, bh)
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_SCALE
		back.modulate = Color("#3E342A", 0.30)                    # warm-grey, soft
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(back)
	var path := G.item_tex_path(code)
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		var inset := size * 0.06
		t.offset_left = inset
		t.offset_top = inset
		t.offset_right = -inset
		t.offset_bottom = -inset
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(t)
		return holder
	# coins: a gold disc with its value (tap to pocket)
	if G.is_coin(code):
		var cdisc := Panel.new()
		var cd := size * (0.5 + 0.1 * GroveBoard.tier_of(code))
		cdisc.size = Vector2(cd, cd)
		cdisc.position = (Vector2(size, size) - cdisc.size) / 2.0
		var csb := StyleBoxFlat.new()
		csb.bg_color = STRAW
		csb.set_corner_radius_all(int(cd / 2.0))
		csb.set_border_width_all(3)
		csb.border_color = Color("#C98A2B")
		cdisc.add_theme_stylebox_override("panel", csb)
		cdisc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(cdisc)
		var clbl := Label.new()
		clbl.text = str(G.coin_value(code))
		clbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		clbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clbl.add_theme_font_size_override("font_size", int(size * 0.26))
		clbl.add_theme_color_override("font_color", Color("#6B4A12"))
		clbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(clbl)
		return holder
	# placeholder: line-colored disc that grows with tier + tier number
	var tier := GroveBoard.tier_of(code)
	var line := GroveBoard.line_of(code)
	var disc := Panel.new()
	var dsz := size * (0.5 + 0.06 * tier)
	disc.size = Vector2(dsz, dsz)
	disc.position = (Vector2(size, size) - disc.size) / 2.0
	var sb := StyleBoxFlat.new()
	var base: Color = G.LINES[line].color if G.LINES.has(line) else Palette.TEXT_MUTED
	sb.bg_color = base.lerp(Color.WHITE, 0.06 * tier)
	sb.set_corner_radius_all(int(dsz / 2.0))
	sb.set_border_width_all(3)
	sb.border_color = GROUND_EDGE
	disc.add_theme_stylebox_override("panel", sb)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(disc)
	var lbl := Label.new()
	lbl.text = str(tier)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", int(size * 0.3))
	lbl.add_theme_color_override("font_color", GROUND_EDGE)
	lbl.add_theme_color_override("font_outline_color", CREAM)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	return holder

# Rounded-corner mask in PIXELS (owner: rounded corners + pop are back; the
# previous UV feather read as a flat square). Soft 8px melt at the rim only.
const MAT_MASK_SHADER := "
shader_type canvas_item;
uniform vec2 rect_size = vec2(1080.0, 1400.0);
uniform float radius_px = 28.0;
uniform float feather_px = 8.0;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * rect_size;
	vec2 b = rect_size * 0.5 - vec2(radius_px);
	vec2 q = abs(p) - b;
	float d = length(max(q, vec2(0.0))) - radius_px;
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(-feather_px, 0.0, d);
}"

# The garden-bed mat: ONE object with screen juice — rounded under-panel with a
# bordered, shadowed pop-out edge, a light rim catch, and the moss (cropped past
# any baked border) masked to matching rounded corners on top.
func _make_board_mat() -> Control:
	var pad := 20.0
	var mat := Control.new()
	mat.position = Vector2(-pad, -pad)
	mat.size = Vector2(_board_w() + pad * 2.0, _board_h() + pad * 2.0)
	mat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# H retune: a THIN warm soil edge hugging the moss (was near-black green
	# pooling into a dark crescent at every corner); cream rim deleted.
	var under := Panel.new()
	under.set_anchors_preset(Control.PRESET_FULL_RECT)
	var us := StyleBoxFlat.new()
	us.bg_color = Color("#4A3A28", 0.9)
	us.set_corner_radius_all(32)
	us.set_border_width_all(3)
	us.border_color = Color("#3A2D1E")
	us.shadow_color = Color(0, 0, 0, 0.38)
	us.shadow_size = 12
	us.shadow_offset = Vector2(0, 7)
	under.add_theme_stylebox_override("panel", us)
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat.add_child(under)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MAT_MASK_SHADER
	sm.shader = sh
	var inset := 5.0
	sm.set_shader_parameter("rect_size", mat.size - Vector2(inset, inset) * 2.0)
	sm.set_shader_parameter("radius_px", 27.0)
	sm.set_shader_parameter("feather_px", 5.0)
	var moss: Texture2D = null
	for pth in ["res://assets/ui/tray_grove_tall.png", "res://assets/ui/tray_grove.png"]:
		if ResourceLoader.exists(pth):
			var base: Texture2D = load(pth)
			var at := AtlasTexture.new()
			at.atlas = base
			var sz := Vector2(base.get_size())
			at.region = Rect2(sz * 0.13, sz * 0.74)   # the calm moss interior only
			moss = at
			break
	if moss != null:
		var t := TextureRect.new()
		t.texture = moss
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.offset_left = inset
		t.offset_top = inset
		t.offset_right = -inset
		t.offset_bottom = -inset
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.material = sm
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mat.add_child(t)
	else:
		var c := ColorRect.new()
		c.color = Color("#557B47")
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.offset_left = inset
		c.offset_top = inset
		c.offset_right = -inset
		c.offset_bottom = -inset
		c.material = sm
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mat.add_child(c)
	return mat


func _make_bramble(cell: Vector2i) -> Control:
	var terr: int = board.terrain[GroveBoard.idx(cell)]
	var req := GroveBoard.gate_req_of(terr)
	var gate := GroveBoard.gate_line_of(terr)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(csz, csz)
	holder.size = Vector2(csz, csz)
	holder.pivot_offset = Vector2(csz, csz) / 2.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := mini(req - 1, 3)
	var path := "res://assets/ui/bramble_%d.png" % ring
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# S3/AC: lift the near-black nest toward deep moss-brown (warm-lift shader —
		# a multiply-modulate can't brighten true black; this adds a warm floor)
		t.material = _bramble_mat()
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(t)
	else:
		var p := Panel.new()
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = BRAMBLE_BG.darkened(0.06 * req)
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(3)
		sb.border_color = BRAMBLE_EDGE
		p.add_theme_stylebox_override("panel", sb)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(p)
	# the padlock ghost: which produced tier opens me — tinted by the gate's
	# line when only that generator's plants will do (mushroom tan, honey gold)
	if ResourceLoader.exists(Look.KIT + "icon_star.png"):
		var brow := HBoxContainer.new()
		brow.alignment = BoxContainer.ALIGNMENT_CENTER
		brow.set_anchors_preset(Control.PRESET_FULL_RECT)
		brow.add_theme_constant_override("separation", 2)
		brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		brow.add_child(Look.icon("star", csz * 0.2))
		var bnum := Label.new()
		bnum.text = str(req)
		bnum.add_theme_font_size_override("font_size", int(csz * 0.26))
		var bcol := Color(CREAM, 0.5)
		if gate > 0 and G.LINES.has(gate):
			bcol = Color(G.LINES[gate].color, 0.95)
		bnum.add_theme_color_override("font_color", bcol)
		bnum.add_theme_color_override("font_outline_color", BRAMBLE_EDGE)
		bnum.add_theme_constant_override("outline_size", 5)
		brow.add_child(bnum)
		holder.add_child(brow)
		return holder
	var badge := Label.new()
	badge.text = tr("✿%d") % req
	badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", int(csz * 0.26))
	var badge_col := Color(CREAM, 0.5)
	if gate > 0 and G.LINES.has(gate):
		badge_col = Color(G.LINES[gate].color, 0.95)
	badge.add_theme_color_override("font_color", badge_col)
	badge.add_theme_color_override("font_outline_color", BRAMBLE_EDGE)
	badge.add_theme_constant_override("outline_size", 5)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(badge)
	return holder

func _make_generator(gi: int = 0) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(csz, csz)
	holder.size = Vector2(csz, csz)
	holder.pivot_offset = Vector2(csz, csz) / 2.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: String = G.GENERATORS[gi].tex
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(t)
		return holder
	var p := Panel.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#8A5A3B")
	sb.set_corner_radius_all(int(csz * 0.3))
	sb.set_border_width_all(4)
	sb.border_color = STRAW
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(p)
	var lbl := Label.new()
	lbl.text = tr(String(G.GENERATORS[gi].label))
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", int(csz * 0.24))
	lbl.add_theme_color_override("font_color", CREAM)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	return holder

# V1: a locked generator's line is "revealed" once any bramble gated on that line
# sits next to an open cell — i.e. the player has expanded to meet it.
func _gen_line_revealed(gi: int) -> bool:
	var lines: Array = G.GENERATORS[gi].lines
	for r in G.ROWS:
		for c in G.COLS:
			var cell := Vector2i(r, c)
			if not board.is_bramble(cell):
				continue
			if not lines.has(GroveBoard.gate_line_of(board.terrain[GroveBoard.idx(cell)])):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = cell + d
				if board.in_bounds(n) and board.is_open(n):
					return true
	return false

# V1: the greyed silhouette + "after N spots" chip at a locked generator's cell.
func _make_gen_preview(gi: int) -> Control:
	var gen: Dictionary = G.GENERATORS[gi]
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(csz, csz)
	holder.size = Vector2(csz, csz)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := String(gen.get("tex", ""))
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		var inset := csz * 0.16
		t.position = Vector2(inset, inset * 0.4)
		t.size = Vector2(csz - inset * 2.0, csz - inset * 2.0)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.modulate = Color(0.30, 0.28, 0.24, 0.5)     # greyed/ghosted silhouette
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(t)
	var n_more := maxi(1, int(gen.appears_at) - _chapter_idx())
	var chip := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(GROUND_EDGE, 0.82)
	cs.set_corner_radius_all(11)
	cs.content_margin_left = 8.0
	cs.content_margin_right = 8.0
	cs.content_margin_top = 3.0
	cs.content_margin_bottom = 3.0
	chip.add_theme_stylebox_override("panel", cs)
	chip.anchor_left = 0.5
	chip.anchor_right = 0.5
	chip.anchor_top = 1.0
	chip.anchor_bottom = 1.0
	chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	chip.offset_top = -4.0 - csz * 0.30
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl := Label.new()
	cl.text = tr("after %d spots") % n_more
	cl.add_theme_font_size_override("font_size", maxi(14, int(csz * 0.135)))
	cl.add_theme_color_override("font_color", CREAM)
	cl.add_theme_constant_override("outline_size", 0)
	chip.add_child(cl)
	holder.add_child(chip)
	return holder

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
	_gen_tap = G.gen_index_at(cell, _chapter_idx()) >= 0
	if _gen_tap:
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
	if _gen_tap:
		_gen_tap = false
		var gi := G.gen_index_at(_pos_to_cell(pos), _chapter_idx())
		if gi >= 0 and _pos_to_cell(pos) == _press_cell:
			_pop_seed(gi)
		return
	# V1: tapping a locked-generator preview floats its name + arrival count
	var rel_cell := _pos_to_cell(pos)
	if gen_preview_cells.has(rel_cell) and rel_cell == _press_cell and _drag_node == null:
		var pgi: int = gen_preview_cells[rel_cell]
		var n_more := maxi(1, int(G.GENERATORS[pgi].appears_at) - _chapter_idx())
		var gp2: Vector2 = board_area.get_global_transform() * pos
		FX.floating_text(self, gp2 - Vector2(90, 46),
			"%s — %s" % [tr(String(G.GENERATORS[pgi].label)), tr("after %d spots") % n_more], CREAM, 26)
		Audio.play("button_tap", -8.0)
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
		_open_ladder(GroveBoard.line_of(board.item_at(from)), GroveBoard.tier_of(board.item_at(from)))
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

func _snap_back(from: Vector2i, node: Control) -> void:
	var t := node.create_tween()
	t.tween_property(node, "position", _cell_pos(from), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("invalid_soft", -8.0)

# --- actions ---------------------------------------------------------------------

func _pop_seed(gi: int = 0) -> void:
	var gnode: Control = gen_nodes.get(gi, gen_node)
	if _ftue_pops_done() and water < G.POP_COST:
		FX.wobble(gnode)
		Audio.play("invalid_soft", -4.0)
		_update_water_hud()                # surfaces the refill offer if available
		return
	var empties := board.empty_ground_cells()
	if empties.is_empty():
		FX.wobble(gnode)                   # full board pauses the generator for FREE
		Audio.play("invalid_soft", -4.0)
		return
	# FTUE: the first ten pops are on the house — the verb before the meter
	var g := Save.grove()
	if _ftue_pops_done():
		water -= G.POP_COST
	g["pops"] = int(g.get("pops", 0)) + 1
	if Audio.has("water_pop"):
		Audio.play("water_pop", -2.0)
	# nearest few cells to this generator, then a random one of those
	var gcell: Vector2i = Vector2i(G.GENERATORS[gi].cell)
	empties.sort_custom(func(a, b): return _dist_to(a, gcell) < _dist_to(b, gcell))
	var pick: Vector2i = empties[rng.randi_range(0, mini(2, empties.size() - 1))]
	# line: this generator's lines, leaning toward what the givers want
	var pool: Array = G.GENERATORS[gi].lines
	var wanted: Array = []
	for e in giver_chips:
		var q: Dictionary = _chapter().quests[e.qi]
		for ask in G.quest_asks(q):
			if pool.has(int(ask.line)) and not wanted.has(int(ask.line)):
				wanted.append(int(ask.line))
	var line: int
	if not wanted.is_empty() and rng.randf() < G.ASK_WEIGHT:
		line = wanted[rng.randi_range(0, wanted.size() - 1)]
	else:
		line = int(pool[rng.randi_range(0, pool.size() - 1)])
	var roll := rng.randf()
	var tier := 1
	var acc := 0.0
	for i in G.TIER_ODDS.size():
		acc += G.TIER_ODDS[i]
		if roll <= acc:
			tier = i + 1
			break
	var code := line * 100 + tier
	board.place(pick, code)
	_mark_seen(code)
	_note_item_landed(code)   # W3: a spawned max-tier item also triggers the one-time hint
	var n := _make_piece(code, csz)
	n.position = _cell_pos(gcell)
	n.scale = Vector2(0.3, 0.3)
	board_area.add_child(n)
	piece_nodes[pick] = n
	# W2: the spawn flight is COSMETIC and must NOT set `animating` — that flag gates
	# the board input surface, so a 0.22s flight used to EAT the next generator tap.
	# The item is already placed in the model (board.place above); rapid taps each
	# spawn into their own cell and fly independently. `animating` now guards MERGES
	# only (mid-transition board state), so N rapid taps land N pops (water permitting).
	var t := n.create_tween()
	t.set_parallel(true)
	t.tween_property(n, "position", _cell_pos(pick), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	FX.pop(gnode)
	if not Audio.has("water_pop"):
		Audio.play("item_drop", -3.0, 1.1)
	_persist()
	_refresh_giver_lights()
	_update_water_hud()

func _dist(cell: Vector2i) -> int:
	return _dist_to(cell, G.GEN_CELL)

func _dist_to(cell: Vector2i, to: Vector2i) -> int:
	return absi(cell.x - to.x) + absi(cell.y - to.y)

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
	var tier := GroveBoard.tier_of(produced)
	FX.burst(board_area, _cell_pos(b) + Vector2(csz, csz) / 2.0, STRAW if tier >= 4 else Color("#7FA65A"), 10 + tier * 3)
	Audio.play("merge_success" if tier >= 4 else "merge_soft", -1.0, clampf(0.95 + 0.03 * tier, 0.9, 1.3))
	# growth beside brambles clears them (line-gated edges want the right plant)
	for cell in board.openable_brambles(b, produced):
		_open_bramble(cell)
	# a little luck: merges sometimes shake a coin loose
	if not G.is_coin(produced) and rng.randf() < G.COIN_DROP_RATE:
		_drop_coin_near(b)
	animating = false
	_persist()
	_refresh_giver_lights()
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
	return BAG_SLOTS + (1 if bool(Save.grove().get("bag3", false)) else 0)

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
	empties.sort_custom(func(a, b): return _dist(a) < _dist(b))
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
			var lock := Label.new()                  # the buyable third slot
			lock.text = tr("+ %d💎") % G.BAG3_DIAMOND_COST
			lock.set_anchors_preset(Control.PRESET_FULL_RECT)
			lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock.add_theme_font_size_override("font_size", 22)
			lock.add_theme_color_override("font_color", Color(CREAM, 0.55))
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s.add_child(lock)
			continue
		if i < bag.size():
			var mini_n := _make_piece(int(bag[i]), 76.0)
			mini_n.position = Vector2(4, 4)
			mini_n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s.add_child(mini_n)

# --- givers / merchant / gate actions ----------------------------------------------

func _on_giver_tap(qi: int, chip: Control) -> void:
	var q: Dictionary = _chapter().quests[qi]
	var asks: Array = G.quest_asks(q)
	# X3: deliver only when EVERY ask is payable (multi-ask delivers all-or-nothing)
	for ask in asks:
		if board.count_of(int(ask.line) * 100 + int(ask.tier)) < int(ask.count):
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
	qdone[qi] = true
	Save.add_stars(int(q.stars))
	FX.celebrate_at(self, chip.get_global_rect().get_center(), tr("+%d★") % int(q.stars), STRAW)
	Audio.play("giver_cheer" if Audio.has("giver_cheer") else "merge_success", -2.0, 1.2)
	_persist()
	_rebuild_givers()
	_update_hud()
	if _gate_ready():
		FX.floating_text(self, gate_btn.get_global_rect().get_center() - Vector2(140, 70), tr("Ready to restore!"), STRAW, 40)

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
		FX.floating_text(self, center - Vector2(30, 60), tr("+%d💎") % reward.y, Color("#A9C7E8"), 30)
		if Features.on("fly_to_wallet") and stars_label != null:
			FX.fly_to_wallet(self, center, Look.icon("gem", 30.0), diamonds_label)
	else:
		FX.floating_text(self, center - Vector2(30, 60), "+%d" % reward.x, STRAW, 30)
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
	if not ResourceLoader.exists("res://assets/map/spirit_porter.png"):
		return
	_porter_running = true
	var sp := TextureRect.new()
	sp.texture = load("res://assets/map/spirit_porter.png")
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
	# the atlas you visit on purpose. Fresh save (no last_zone) → the map, as ever.
	HomeScene.decorate_zone = String(Save.grove().get("last_zone", ""))
	get_tree().change_scene_to_file("res://scenes/Home.tscn")

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
