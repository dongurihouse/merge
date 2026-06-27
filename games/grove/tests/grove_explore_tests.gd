extends "res://games/grove/tests/grove_test_base.gd"
## grove · explore — guards engine/scripts/core/explore.gd (the acquire model: loadout costs/cfg,
## Rush scoring, grid helpers, the box/unlocked-pool seam, and cross-scene run state). Pure-model
## coverage; the real-time Rush *feel* needs an interactive run. Active suite (in GROVE_TESTS).

const Explore = preload("res://engine/scripts/core/explore.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")

func _initialize() -> void:
	begin("grove · explore acquire")
	_test_loadout()
	_test_scoring()
	_test_grid()
	_test_pool_and_box()
	_test_run_state()
	_test_screens()
	_test_trade_box_icons()
	_test_trade_reward_dialog_layout()
	_test_loadout_uses_toggle_card_callback()
	await _test_loadout_toggle_updates_in_place()
	await _test_loadout_keeps_unaffordable_choices_visible()
	finish()

# a rows×cols grid of empty cells (the Rush tile grid: null or {kind,tier})
func _grid(rows: int, cols: int) -> Array:
	var g := []
	for _r in rows:
		var row := []
		for _c in cols:
			row.append(null)
		g.append(row)
	return g

func _button_text_with_prefix(node: Control, prefix: String) -> String:
	if node is Button and String((node as Button).text).begins_with(prefix):
		return String((node as Button).text)
	for b in node.find_children("", "Button", true, false):
		var text := String((b as Button).text)
		if text.begins_with(prefix):
			return text
	return "<missing>"

func _switch_for_label(node: Control, text: String) -> Button:
	for l in node.find_children("", "Label", true, false):
		if String((l as Label).text) != text:
			continue
		var p: Node = l
		while p != null and p != node:
			if p is PanelContainer:
				for b in (p as Control).find_children("", "Button", true, false):
					if (b as Button).has_meta("on"):
						return b as Button
			p = p.get_parent()
	return null

func _card_for_label(node: Control, text: String) -> PanelContainer:
	for l in node.find_children("", "Label", true, false):
		if String((l as Label).text) != text:
			continue
		var p: Node = l
		while p != null and p != node:
			if p is PanelContainer:
				return p as PanelContainer
			p = p.get_parent()
	return null

func _button_with_text(node: Control, text: String) -> Button:
	if node is Button and String((node as Button).text) == text:
		return node as Button
	for b in node.find_children("", "Button", true, false):
		if String((b as Button).text) == text:
			return b as Button
	return null

func _source_contains(path: String, needle: String) -> bool:
	return FileAccess.get_file_as_string(path).find(needle) != -1

func _push_tap(gpos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = gpos
	down.global_position = gpos
	get_root().push_input(down, true)
	var up := down.duplicate()
	up.pressed = false
	get_root().push_input(up, true)

# --- loadout: coin cost + the Rush cfg the boosts resolve to ----------------------
func _test_loadout() -> void:
	fresh("explore_loadout")
	ok(Explore.loadout_cost({}) == 0, "an empty loadout costs nothing")
	ok(Explore.loadout_cost({"time": true, "drops": true}) == 120 + 100, "loadout cost sums the equipped boosts")

	# §1 an expedition has a DEFAULT MINIMUM cost (MIN_COST) — the acquisition coin sink — and boosts add on top.
	ok(Explore.start_cost({}) == Explore.MIN_COST, "an empty expedition still costs the default MIN_COST")
	ok(Explore.start_cost({"drops": true}) == Explore.MIN_COST + 100, "boosts add ON TOP of the base minimum")
	Save.spend(Save.coins())               # zero the wallet, then set a known balance
	Save.add_coins(300)
	ok(Explore.can_start({}), "can set off with the base minimum covered (300 ≥ 150)")
	ok(Explore.can_start({"drops": true}), "can set off when coins (300) cover base+boost (250)")
	ok(not Explore.can_start({"focus": true}), "cannot set off when base+boost (350) exceeds coins (300)")

	var base: Dictionary = Explore.rush_cfg({})
	ok(base.time == Explore.BASE_TIME, "no-boost run length is BASE_TIME")
	ok(base.spawn_mul == 1.0 and base.calm_mul == 1.0 and base.t2 == 0.0, "no-boost cfg is the neutral baseline")
	ok((base.lines as Array).size() == Explore.RUSH_LINES.size(), "all lines are in play without the focus boost")
	var full: Dictionary = Explore.rush_cfg({"time": true, "drops": true, "calm": true, "lucky": true, "focus": true})
	ok(full.time == Explore.BASE_TIME + 15.0, "the time boost adds 15s")
	ok(full.spawn_mul < 1.0, "the drops boost shortens the spawn interval")
	ok(full.calm_mul > 1.0, "the calm boost rarefies treefalls")
	ok(full.t2 > 0.0, "the lucky boost enables tier-2 drops")
	ok((full.lines as Array).size() == 2, "the focus boost restricts play to 2 lines")

# --- Rush scoring: non-linear value, combo, multiplier, spawn cadence -------------
func _test_scoring() -> void:
	ok(Explore.merge_base(1) == 10, "a t1 merge is worth 10 base")
	ok(Explore.merge_base(2) == 20 and Explore.merge_base(3) == 40, "base value doubles per tier (non-linear)")
	ok(Explore.merge_points(3, 2.0) == Explore.merge_base(3) * 2, "points scale by the live multiplier")

	ok(Explore.combo_after(2, 0.5) == 3, "a merge within the window climbs the combo")
	ok(Explore.combo_after(5, 2.0) == 1, "a merge after the window restarts the combo at 1")

	ok(absf(Explore.mult_after_merge(1.0, 1) - 1.12) < 0.001, "each merge nudges the multiplier up")
	ok(Explore.mult_after_merge(1.0, 4) > Explore.mult_after_merge(1.0, 1), "building a high tier bumps it more")
	ok(Explore.mult_after_merge(Explore.MULT_CAP, 4) == Explore.MULT_CAP, "the multiplier is capped at MULT_CAP")
	ok(Explore.mult_decay(2.0, 0.1, 0.0) == 2.0, "the multiplier holds steady inside the post-merge grace window")
	ok(Explore.mult_decay(2.0, 0.1, Explore.MULT_GRACE + 0.5) < 2.0, "the multiplier bleeds once the grace window passes")
	ok(absf(Explore.mult_decay(2.0, 1.0, 5.0) - (2.0 - Explore.MULT_DECAY)) < 0.001, "past the grace window it bleeds at MULT_DECAY per second")
	ok(Explore.mult_decay(1.0, 5.0, 9.0) == 1.0, "the multiplier never decays below 1")
	ok(Explore.clean_dodge_mult(1.0) > 1.0, "a clean dodge bumps the multiplier")

	ok(Explore.spawn_interval(0.0, 1.0) > Explore.spawn_interval(1.0, 1.0), "drops accelerate as the run progresses")
	ok(Explore.spawn_interval(0.0, 0.72) < Explore.spawn_interval(0.0, 1.0), "the drops boost shortens the interval")

# --- grid helpers: match, gravity, fill, fling, timber, full ---------------------
func _test_grid() -> void:
	var g := _grid(3, 3)
	g[2][0] = {"kind": "leaf", "tier": 1}
	g[2][1] = {"kind": "leaf", "tier": 1}
	ok(Explore.neighbor_match(g, 2, 0) == Vector2i(2, 1), "neighbor_match finds an adjacent same kind+tier")
	g[2][1] = {"kind": "petal", "tier": 1}
	ok(Explore.neighbor_match(g, 2, 0) == Vector2i(-1, -1), "no match when the neighbour's kind differs")
	g[2][1] = {"kind": "leaf", "tier": 2}
	ok(Explore.neighbor_match(g, 2, 0) == Vector2i(-1, -1), "no match when the neighbour's tier differs")
	# the Rush uses INTEGER line indices as kinds (RUSH_LINES = [1,2,3]); neighbor_match must handle them
	# (str(), not String() — String(int) has no constructor and crashed every tap-merge in the Rush)
	var gi := _grid(3, 3)
	gi[2][0] = {"kind": 1, "tier": 1}
	gi[2][1] = {"kind": 1, "tier": 1}
	ok(Explore.neighbor_match(gi, 2, 0) == Vector2i(2, 1), "neighbor_match matches integer (line-index) kinds")
	gi[2][1] = {"kind": 2, "tier": 1}
	ok(Explore.neighbor_match(gi, 2, 0) == Vector2i(-1, -1), "no match when integer kinds differ")

	var g2 := _grid(3, 3)
	g2[0][1] = {"kind": "leaf", "tier": 1}
	Explore.gravity(g2)
	ok(g2[2][1] != null and g2[0][1] == null, "gravity drops a floating tile to the bottom")
	ok(Explore.column_fill(g2, 1) == 1, "column_fill counts a column's tiles")

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var g3 := _grid(2, 3)
	g3[1][0] = {"kind": "leaf", "tier": 1}
	ok(Explore.fling_target(g3, 0, 1, rng) == 2, "fling_target avoids the source and the danger column")

	var g4 := _grid(3, 2)
	g4[2][0] = {"kind": "leaf", "tier": 1}
	g4[1][0] = {"kind": "leaf", "tier": 2}
	ok(Explore.timber_hits(g4, 0) == 2 and Explore.timber_hits(g4, 1) == 0, "timber_hits counts a column (0 = a clean dodge)")

	var g5 := _grid(1, 2)
	ok(not Explore.board_full(g5), "a board with an empty cell is not full")
	g5[0][0] = {"kind": "leaf", "tier": 1}
	g5[0][1] = {"kind": "leaf", "tier": 1}
	ok(Explore.board_full(g5), "board_full is true when every cell is occupied")

# --- the box seam: unlocked pool + roll ------------------------------------------
func _test_pool_and_box() -> void:
	fresh("explore_pool")
	ok(Explore.unlocked_pool({}, []).is_empty(), "the box pool is empty with no completed map")

	var z := 0
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	ok(G.can_populate(z, unl, [z]), "map 0 complete (the pool precondition)")
	var pool: Array = Explore.unlocked_pool(unl, [z])
	ok(not pool.is_empty(), "a completed map fills the box pool")
	var want := {}
	for ln in G.resident_lines(z):
		want[String(ln.id)] = true
	var all_in := true
	for k in pool:
		if not want.has(k):
			all_in = false
	ok(all_in and pool.size() == want.size(), "the pool is exactly the completed map's offered kinds")

	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	ok(pool.has(Explore.roll_kind(pool, rng)), "roll_kind returns a kind from the pool")
	ok(Explore.roll_kind([], rng) == "", "rolling an empty pool yields the empty string")

# --- run state: carried across the three scenes, score spent on boxes ------------
func _test_run_state() -> void:
	Explore.begin_run({"drops": true})
	ok(Explore.score() == 0, "a fresh run starts at score 0")
	ok(bool(Explore.run().equip.get("drops", false)), "the run carries the chosen loadout")
	Explore.add_score(250)
	ok(Explore.score() == 250, "add_score accrues the run score")
	ok(not Explore.buy_box(300), "a box the run can't afford is refused")
	ok(Explore.score() == 250, "a refused box leaves the score intact")
	ok(Explore.buy_box(250), "an affordable box is bought")
	ok(Explore.score() == 0, "buying a box debits its cost from the score")

# --- the Rush/Trade screens: build smoke + the Trade→hand seam -------------------
func _test_screens() -> void:
	fresh("explore_screens")
	# (Load out is now an overlay dialog on the map — map.gd::_open_expedition — not a scene.)
	for path in ["res://engine/scenes/ExploreRush.tscn", "res://engine/scenes/ExploreTrade.tscn"]:
		var s = load(path).instantiate()
		get_root().add_child(s)
		if s.get_child_count() == 0:        # headless -s defers _ready a frame; build it now
			s._ready()
		ok(s.get_child_count() > 0, "%s builds a non-empty tree" % String(path).get_file())
		s.queue_free()

	# the seam: buying a box on the Trade screen lands a pool kind in the habitat hand
	fresh("explore_trade_seam")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	Explore.begin_run({})
	Explore.add_score(400)
	var pool: Array = Explore.unlocked_pool(unl, [z])
	var hand_before := Habitat.hand().size()
	var t = load("res://engine/scenes/ExploreTrade.tscn").instantiate()
	get_root().add_child(t)
	if t.get_child_count() == 0:
		t._ready()
	t._on_buy(Explore.BOXES[0])          # pouch = 1 resident
	ok(Habitat.hand().size() == hand_before + 1, "opening a pouch on the Trade screen adds one spirit to the hand")
	ok(pool.has(String(Habitat.hand()[Habitat.hand().size() - 1].kind)), "the box-spirit's kind comes from the unlocked pool")
	var box_tier := int(Habitat.hand()[Habitat.hand().size() - 1].tier)
	ok(box_tier >= 1 and box_tier <= 4, "the box-spirit rolls a generator tier (1–4)")

	# a pricier box opens to MORE residents (pouch 1 / chest 4 / vault 8)
	ok(int(Explore.BOXES[0].residents) == 1 and int(Explore.BOXES[1].residents) == 4 and int(Explore.BOXES[2].residents) == 8,
		"the three boxes yield 1 / 4 / 8 residents")
	Explore.add_score(int(Explore.BOXES[2].cost))
	var before_vault := Habitat.hand().size()
	t._on_buy(Explore.BOXES[2])          # vault = 8 residents
	ok(Habitat.hand().size() == before_vault + int(Explore.BOXES[2].residents), "a vault opens to %d residents at once" % int(Explore.BOXES[2].residents))

	var piglet_reveal: Control = t._spirit_widget("piglet", 72.0)
	ok(piglet_reveal.find_child("SpiritEye0", true, false) != null and piglet_reveal.find_child("SpiritEye1", true, false) != null,
		"an unarted box-spirit reveal shows placeholder face details instead of a blank disc")
	t.queue_free()

func _test_trade_box_icons() -> void:
	var expected := {
		"pouch": "rush_box_pouch",
		"chest": "rush_box_chest",
		"vault": "rush_box_vault",
	}
	var Kit: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
	var trade = load("res://engine/scenes/ExploreTrade.tscn").instantiate()
	get_root().add_child(trade)
	for b in Explore.BOXES:
		var id := String(b.get("id", ""))
		var icon_id := String(b.get("icon", ""))
		ok(icon_id == String(expected.get(id, "")), "%s trade box declares its tier icon id" % id)
		ok(ResourceLoader.exists("res://games/grove/assets/ui/rush/%s.png" % icon_id),
			"%s trade box icon exists as a Rush UI asset" % id)
		var card: Control = trade._box_card(Kit, b)
		ok(String(card.get_meta("box_icon", "")) == icon_id, "%s trade card records the icon id it renders" % id)
		ok(card.find_child("RushRewardIcon", true, false) != null, "%s trade card has a named reward icon node" % id)
		card.free()
	trade.queue_free()

func _test_trade_reward_dialog_layout() -> void:
	var trade = load("res://engine/scenes/ExploreTrade.tscn").instantiate()
	for _i in 12:
		trade._revealed.append("ember")
	get_root().add_child(trade)
	if trade.get_child_count() == 0:
		trade._ready()
	var dialog := trade.find_child("TradeDialog", true, false) as Control
	ok(dialog != null, "Trade uses the shared framed dialog instead of a loose full-page layout")
	ok(dialog != null and dialog.find_child("DialogBanner", true, false) != null,
		"the Trade dialog carries the standard banner chrome")
	var reveal_scroll := trade.find_child("RevealScroll", true, false) as ScrollContainer
	ok(reveal_scroll != null, "revealed spirits live in a bounded scroll area")
	ok(reveal_scroll != null and reveal_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"the revealed spirits cannot widen the dialog with a horizontal scroll")
	ok(reveal_scroll != null and reveal_scroll.custom_minimum_size.x <= 460.0,
		"the reveal area has a capped width so reward claims do not shift the screen")
	ok(reveal_scroll != null and reveal_scroll.custom_minimum_size.y >= 232.0,
		"the reveal area shows a full vault's two rows before scrolling")
	var grid := trade.find_child("RevealGrid", true, false) as GridContainer
	ok(grid != null and grid.columns == 4, "revealed spirits wrap into a compact four-column grid")
	var cards: Array = []
	if grid != null:
		for child in grid.get_children():
			if child is PanelContainer and (child as PanelContainer).has_meta("spirit_reveal_card"):
				cards.append(child)
	ok(cards.size() == 12, "each revealed spirit renders as its own card")
	if cards.size() > 0:
		var first := cards[0] as PanelContainer
		ok(first.custom_minimum_size.x >= 88.0 and first.custom_minimum_size.y >= 108.0,
			"spirit reveal cards have a stable footprint")
		var icon := first.find_child("SpiritIcon", true, false) as Control
		var name := first.find_child("SpiritName", true, false) as Label
		ok(icon != null and icon.custom_minimum_size == Vector2(56.0, 56.0),
			"spirit card icons sit in a fixed centered square")
		ok(name != null and name.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
			"spirit names center under their icons")
	trade.queue_free()

func _test_loadout_uses_toggle_card_callback() -> void:
	var map_src := "res://engine/scripts/scenes/map.gd"
	ok(_source_contains(map_src, "\"on_toggle\": make_loadout_toggle.call(id)"),
		"loadout rows use toggle_card's on_toggle callback as the single toggle path")
	ok(not _source_contains(map_src, "sw.pressed.connect(on_switch_pressed"),
		"loadout rows do not add a second switch pressed handler")

func _test_loadout_toggle_updates_in_place() -> void:
	fresh("explore_loadout_overlay")
	Save.spend(Save.coins())
	Save.add_coins(1000)
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_expedition()
	await process_frame
	var overlay := map.get_node_or_null("ExpeditionOverlay") as Control
	ok(overlay != null, "the map opens the expedition loadout overlay")
	if overlay == null:
		map.queue_free()
		await process_frame
		return
	var cc := overlay.get_child(1) as CenterContainer
	var dialog_before := cc.get_child(0) as Control
	var sw: Button = _switch_for_label(dialog_before, "Lantern")
	ok(sw != null, "the Lantern loadout row has a switch to toggle")
	if sw == null:
		map.queue_free()
		await process_frame
		return
	ok(sw.get_global_rect().size.x > 0.0 and sw.get_global_rect().size.y > 0.0,
		"the Lantern switch has a real hit rect")
	_push_tap(_hit_center(sw))
	await process_frame
	ok(cc.get_child_count() == 1, "toggling a boost does not queue a replacement dialog")
	ok(cc.get_child(0) == dialog_before, "the same loadout dialog instance remains after a toggle")
	var cost_after := _button_text_with_prefix(dialog_before, "Cost")
	ok(cost_after == "Cost 270", "the total cost chip updates in place after toggling Lantern (%s)" % cost_after)
	ok(bool(sw.get_meta("on")), "a real tap leaves the Lantern switch on after an affordable toggle")
	_push_tap(_hit_center(sw))
	await process_frame
	ok(not bool(sw.get_meta("on")), "a second real tap toggles Lantern back off")
	var cost_off := _button_text_with_prefix(dialog_before, "Cost")
	ok(cost_off == "Cost 150", "the total cost chip returns to base cost after toggling Lantern off (%s)" % cost_off)
	var card := _card_for_label(dialog_before, "Lantern")
	ok(card != null, "the Lantern loadout row has a mail-style card tap target")
	if card != null:
		_push_tap(_hit_center(card))
		await process_frame
		ok(is_instance_valid(dialog_before), "tapping the loadout row keeps the dialog open")
		if is_instance_valid(dialog_before):
			ok(bool(sw.get_meta("on")), "tapping the mail-style row toggles Lantern on")
			var row_cost := _button_text_with_prefix(dialog_before, "Cost")
			ok(row_cost == "Cost 270", "row-tapping Lantern updates the total cost (%s)" % row_cost)
	await process_frame
	ok(cc.get_child_count() == 1 and cc.get_child(0) == dialog_before, "the original loadout dialog survives the next frame")
	map.queue_free()
	await process_frame

func _test_loadout_keeps_unaffordable_choices_visible() -> void:
	fresh("explore_loadout_unaffordable")
	Save.spend(Save.coins())
	Save.add_coins(300)
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_expedition()
	await process_frame
	var overlay := map.get_node_or_null("ExpeditionOverlay") as Control
	ok(overlay != null, "the low-wallet loadout overlay opens")
	if overlay == null:
		map.queue_free()
		await process_frame
		return
	var cc := overlay.get_child(1) as CenterContainer
	var dialog := cc.get_child(0) as Control
	var focus_sw: Button = _switch_for_label(dialog, "Focus totem")
	var go := _button_with_text(dialog, "Set off")
	ok(focus_sw != null, "the Focus totem row has a switch")
	ok(go != null, "the loadout dialog has a Set off button")
	if focus_sw == null or go == null:
		map.queue_free()
		await process_frame
		return
	_push_tap(_hit_center(focus_sw))
	await process_frame
	var cost_after := _button_text_with_prefix(dialog, "Cost")
	ok(bool(focus_sw.get_meta("on")), "an unaffordable boost still stays visibly selected")
	ok(cost_after == "Cost 350", "the total cost still shows the selected unaffordable boost (%s)" % cost_after)
	ok(go.disabled, "Set off is disabled while the selected total exceeds the wallet")
	_push_tap(_hit_center(focus_sw))
	await process_frame
	var cost_off := _button_text_with_prefix(dialog, "Cost")
	ok(not bool(focus_sw.get_meta("on")), "tapping the unaffordable boost again turns it off")
	ok(cost_off == "Cost 150", "turning it off returns to the base cost (%s)" % cost_off)
	ok(not go.disabled, "Set off is re-enabled once the selected total is affordable")
	map.queue_free()
	await process_frame
