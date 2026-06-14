extends SceneTree
## Headless tests for the Grove P1 core: board model, content sanity, dispenser
## policy, chapter gate math, persistence.
##   godot --headless --path . -s res://tests/grove_tests.gd

const G = preload("res://engine/scripts/grove_content.gd")
const GroveBoard = preload("res://engine/scripts/grove_board.gd")
const Save = preload("res://engine/scripts/save.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# --- R3: pixel-right asserts (eng rule 14) -------------------------------------
# Composited UI (panel + icon + label + offsets) is where 10px misalignment hides
# at full-screen scale. These ASSERT the composition headlessly. Call after the
# host is in-tree and laid out (await a frame) so global rects are real.

# `panel` fully contains `content` with at least `minpad` on every side (nothing
# pokes out) AND symmetric gaps — left≈right, top≈bottom within tol (even, not
# lopsided). H and V padding may differ (a pill is fine); each axis must match
# itself. Returns true/logs.
func assert_wraps(panel: Control, content: Control, minpad: float, tol: float, label: String) -> bool:
	var p := panel.get_global_rect()
	var c := content.get_global_rect()
	var left := c.position.x - p.position.x
	var right := p.end.x - c.end.x
	var top := c.position.y - p.position.y
	var bottom := p.end.y - c.end.y
	var bad := ""
	for pair in [["left", left], ["right", right], ["top", top], ["bottom", bottom]]:
		if float(pair[1]) < minpad - tol:
			bad += " %s=%.1f<%.0f" % [pair[0], pair[1], minpad]
	if absf(left - right) > tol:
		bad += " L/R asym %.1f/%.1f" % [left, right]
	if absf(top - bottom) > tol:
		bad += " T/B asym %.1f/%.1f" % [top, bottom]
	ok(bad == "", "%s — plank wraps content (≥%.0f, symmetric ±%.0f)%s" % [label, minpad, tol, bad])
	return bad == ""

# `content`'s center sits on `box`'s center within tol, on the requested axes.
func assert_centered(box: Control, content: Control, axes: String, tol: float, label: String) -> bool:
	var b := box.get_global_rect().get_center()
	var c := content.get_global_rect().get_center()
	var bad := ""
	if "h" in axes and absf(b.x - c.x) > tol:
		bad += " dx=%.1f" % (c.x - b.x)
	if "v" in axes and absf(b.y - c.y) > tol:
		bad += " dy=%.1f" % (c.y - b.y)
	ok(bad == "", "%s — content centered (%s, ±%.0f)%s" % [label, axes, tol, bad])
	return bad == ""

# The map's single-input-surface invariant: every Control under `node` must
# IGNORE the mouse, or it silently eats taps before clip.gui_input (bug class ×3).
func _all_ignore(node: Node) -> bool:
	for child in node.get_children():
		if child is Control and (child as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			print("    offender: %s (%s)" % [child.get_path(), child.get_class()])
			return false
		if not _all_ignore(child):
			return false
	return true

# A still-tap (press+release, no drift) straight into the interior's handler.
func _int_tap(h, at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	h._on_interior_input(down)
	var up := down.duplicate()
	up.pressed = false
	h._on_interior_input(up)

# W2: a tap through the BOARD input surface (the animating gate lives here) — used
# to prove rapid generator taps are no longer dropped mid spawn-flight.
func _tap_board(h, at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	h._on_board_input(down)
	var up := down.duplicate()
	up.pressed = false
	h._on_board_input(up)

# Count the purchasable cards of the MOST RECENT shop overlay (meta shop_buy) —
# a UI-shape smoke that survives storefront restyles.
func _shop_rows(host: Control) -> int:
	var overlay: Control = host.get_child(host.get_child_count() - 1)
	var n := 0
	for b in overlay.find_children("*", "Button", true, false):
		if b.has_meta("shop_buy"):
			n += 1
	return n

# Direct Panel children of board_area = the ground tiles (mat/brambles/pieces
# are Control holders) — the J-bug parity counter.
func _panel_count(area: Control) -> int:
	var n := 0
	for c in area.get_children():
		if c is Panel:
			n += 1
	return n

func fresh(name: String) -> void:
	var dir := "user://tu_test_grove_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _initialize() -> void:
	print("== Grove tests ==")

	# 1. board genesis
	var b: GroveBoard = GroveBoard.new()
	ok(b.is_open(G.GEN_CELL) and b.item_at(G.GEN_CELL) == 0, "generator cell open and empty")
	ok(b.is_open(Vector2i(3, 2)) and b.is_open(Vector2i(5, 4)), "center 3x3 starts open")
	ok(b.is_bramble(Vector2i(0, 0)) and b.is_bramble(Vector2i(8, 6)), "edges start brambled")
	ok(b.terrain[GroveBoard.idx(Vector2i(4, 1))] == 2, "first frontier opens on ANY merge (req t2)")
	ok(b.terrain[GroveBoard.idx(Vector2i(3, 1))] == 2, "ring 2 stays any-line req t2")
	ok(b.terrain[GroveBoard.idx(Vector2i(1, 3))] == 4, "ring 3 needs a produced t4 (any line)")
	# the screen edge is END GAME: t5 of the LATE lines (top=mushroom, bottom=honey)
	ok(GroveBoard.gate_line_of(b.terrain[GroveBoard.idx(Vector2i(0, 0))]) == 3 \
		and GroveBoard.gate_req_of(b.terrain[GroveBoard.idx(Vector2i(0, 0))]) == 5, \
		"top edge wants mushroom t5 (the compost's line)")
	ok(GroveBoard.gate_line_of(b.terrain[GroveBoard.idx(Vector2i(8, 6))]) == 4 \
		and GroveBoard.gate_req_of(b.terrain[GroveBoard.idx(Vector2i(8, 6))]) == 5, \
		"bottom edge wants honey t5 (the beehive's line)")
	ok(GroveBoard.line_of(G.bramble_contents(Vector2i(0, 0))) == 3, \
		"a gated bramble's contents seed its own line")
	# legacy saves stored the bare tier: value 3 still decodes as any-line req t3
	ok(GroveBoard.gate_line_of(3) == 0 and GroveBoard.gate_req_of(3) == 3, \
		"legacy bare-tier terrain decodes unchanged")
	ok(b.item_at(Vector2i(3, 2)) == 101, "starter items placed")

	# 2. merge rules
	ok(b.can_merge(Vector2i(3, 2), Vector2i(3, 4)), "same code merges")
	ok(not b.can_merge(Vector2i(3, 2), Vector2i(5, 2)), "different lines never merge")
	var produced := b.merge(Vector2i(3, 2), Vector2i(3, 4))
	ok(produced == 102 and b.item_at(Vector2i(3, 2)) == 0 and b.item_at(Vector2i(3, 4)) == 102, \
		"merge consumes src and bumps dst")
	b.place(Vector2i(3, 2), 108)
	b.place(Vector2i(4, 2), 108)
	ok(not b.can_merge(Vector2i(3, 2), Vector2i(4, 2)), "top tier (t8) never merges")
	ok(b.top_tier_cells().size() == 2, "top tiers visible to the merchant")

	# 3. move / bramble opening
	b.move(Vector2i(3, 4), Vector2i(3, 3))
	ok(b.item_at(Vector2i(3, 3)) == 102 and b.item_at(Vector2i(3, 4)) == 0, "move relocates an item")
	var openable: Array = b.openable_brambles(Vector2i(3, 3), 102)
	ok(openable.has(Vector2i(2, 3)), "any merge (produced t2) opens the first frontier")
	var contents := b.open_bramble(Vector2i(2, 3))
	ok(b.is_open(Vector2i(2, 3)) and b.item_at(Vector2i(2, 3)) == contents and contents == G.bramble_contents(Vector2i(2, 3)), \
		"opening a bramble reveals its deterministic contents")
	ok(not b.openable_brambles(Vector2i(2, 3), 103).has(Vector2i(1, 3)), "ring 3 ignores a t3 merge")
	ok(b.openable_brambles(Vector2i(2, 3), 104).has(Vector2i(1, 3)), "a produced t4 opens ring 3 (any line)")
	# the line gate: a flower t5 beside the top edge does NOTHING; mushroom t5 opens it
	var bgate: GroveBoard = GroveBoard.new()
	for rr in range(1, 4):
		bgate.terrain[GroveBoard.idx(Vector2i(rr, 0))] = 0    # carve a lane to the corner
	bgate.place(Vector2i(1, 0), 105)
	ok(not bgate.openable_brambles(Vector2i(1, 0), 105).has(Vector2i(0, 0)), \
		"flower t5 can NOT open the mushroom-gated top edge")
	ok(bgate.openable_brambles(Vector2i(1, 0), 305).has(Vector2i(0, 0)), \
		"mushroom t5 opens the top edge gate")

	# 4. pigeonhole helper
	ok(b.any_pair_exists() == false or b.any_pair_exists(), "pair query runs")
	var b2: GroveBoard = GroveBoard.new()
	ok(b2.any_pair_exists(), "fresh board has mergeable pairs")

	# 5. persistence roundtrip
	var d := b.to_dict()
	var b3: GroveBoard = GroveBoard.new()
	b3.from_dict(d)
	ok(Array(b3.items) == Array(b.items) and Array(b3.terrain) == Array(b.terrain), \
		"board roundtrips through to_dict/from_dict")

	# 6. P4 content validity: 40 ramp-built chapters, owner rules, debut ordering
	var chs := G.chapters()
	var total_spots := 0
	for z in G.ZONES.size():
		total_spots += G.ZONES[z].spots.size()
	ok(chs.size() == total_spots, "one chapter per home spot (%d)" % total_spots)
	var rules_ok := true
	var debut_ok := true
	for i in chs.size():
		var ch: Dictionary = chs[i]
		var debuted := G.lines_debuted(i)
		for q in ch.quests:
			if int(q.stars) < 1 or int(q.stars) > 3:
				rules_ok = false
			for ask in G.quest_asks(q):
				if int(ask.get("count", 1)) > 2:
					rules_ok = false
				if int(ask.tier) < 2 or int(ask.tier) > G.TOP_TIER - 1:
					rules_ok = false
				if not debuted.has(int(ask.line)):
					debut_ok = false
	ok(rules_ok, "every quest pays 1-3 stars; each ask t2-t7, count <= 2 (owner rules)")
	ok(debut_ok, "no chapter asks for a line before its generator debuts")
	var first_l3 := -1
	var first_l4 := -1
	for i in chs.size():
		for q in chs[i].quests:
			for ask in G.quest_asks(q):
				if int(ask.line) == 3 and first_l3 < 0:
					first_l3 = i
				if int(ask.line) == 4 and first_l4 < 0:
					first_l4 = i
	ok(first_l3 >= 16, "the mushroom line first appears with the compost bin (chapter 17+)")
	ok(first_l4 >= 26, "the honey line first appears with the beehive (chapter 27+)")
	ok(first_l4 > 0 and first_l4 < chs.size(), "honey asks DO arrive before the map ends")

	# 6b-X: difficulty GROWS — multi-LINE stretch quests appear (2 lines in zone 3,
	# reaching 3 lines in zone 4+), they're 2-3★, and t8 NEVER appears (diamond pinnacle).
	var max_asks := 0
	var max_asks_z3 := 0
	var any_t8 := false
	var multi_is_skippable := true
	for i in chs.size():
		var z3 := G.zone_of_chapter(i)
		var n_multi := 0
		for q in chs[i].quests:
			var na: int = G.quest_asks(q).size()
			max_asks = maxi(max_asks, na)
			if z3 == 2:
				max_asks_z3 = maxi(max_asks_z3, na)
			if na >= 2:
				n_multi += 1
				if int(q.stars) < 2:
					multi_is_skippable = false   # a multi-ask must pay 2-3★
			for ask in G.quest_asks(q):
				if int(ask.tier) >= G.TOP_TIER:
					any_t8 = true
		# the multi-LINE stretch must stay within slack (never forced on the player)
		if n_multi > int(chs[i].slack):
			multi_is_skippable = false
	ok(max_asks_z3 >= 2, "zone 3 (compost era) introduces 2-line asks")
	ok(max_asks >= 3, "zone 4+ (beehive era) reaches 3-line asks")
	ok(not any_t8, "no quest ever asks for t8 — it is the diamond pinnacle (order Y)")
	ok(multi_is_skippable, "every multi-line ask pays >=2 stars AND stays within slack (skippable stretch)")

	# 6b. CUMULATIVE worst-case affordability: cheapest payouts always fund the
	# cheapest-first spot purchases — the gate can never strand the player
	var bank := 0
	var costs: Array = []
	for z in G.ZONES.size():
		var zc: Array = []
		for sp in G.ZONES[z].spots:
			zc.append(int(sp.cost))
		zc.sort()
		costs.append_array(zc)               # cheapest-first inside each sequential zone
	var afford_ok := true
	for i in chs.size():
		var ch2: Dictionary = chs[i]
		var pays: Array = []
		for q in ch2.quests:
			pays.append(int(q.stars))
		pays.sort()
		var needed: int = ch2.quests.size() - int(ch2.slack)
		for k in needed:
			bank += pays[k]
		if bank < int(costs[i]):
			afford_ok = false
		bank -= int(costs[i])
	ok(afford_ok, "worst-case star income funds every spot, cumulatively, to map end")

	# 6c. the compost bin reveals at its chapter and sheds its bramble
	var bg: GroveBoard = GroveBoard.new()
	ok(not bg.is_gen(Vector2i(2, 1)), "compost cell starts as plain bramble")
	var fresh_cells: Array = bg.set_active_gens(16)
	ok(fresh_cells.has(Vector2i(2, 1)) and bg.is_gen(Vector2i(2, 1)) and bg.is_open(Vector2i(2, 1)), \
		"chapter 16 reveals the compost bin and clears its bramble")
	ok(not bg.is_gen(Vector2i(6, 5)), "the beehive waits for its own era")
	# 6d. the beehive reveals at 26 — and an item caught on its cell hops away safely
	var bh: GroveBoard = GroveBoard.new()
	bh.set_active_gens(16)
	bh.terrain[GroveBoard.idx(Vector2i(6, 5))] = 0
	bh.place(Vector2i(6, 5), 204)              # a player item parked on the future hive
	var before_count := 0
	for v in bh.items:
		if v == 204:
			before_count += 1
	var fresh_hive: Array = bh.set_active_gens(26)
	ok(fresh_hive.has(Vector2i(6, 5)) and bh.is_gen(Vector2i(6, 5)), "chapter 26 reveals the beehive")
	var after_count := 0
	for v in bh.items:
		if v == 204:
			after_count += 1
	ok(after_count == before_count and bh.item_at(Vector2i(6, 5)) == 0, \
		"an item on the revealing generator's cell relocates, never vanishes")

	# 7. dispenser odds well-formed
	var total := 0.0
	for p in G.TIER_ODDS:
		total += p
	ok(absf(total - 1.0) < 0.001, "tier odds sum to 1")
	ok(G.TIER_ODDS[0] > G.TIER_ODDS[1] and G.TIER_ODDS[1] > G.TIER_ODDS[2], "tier odds decay")

	# 8. starter economy: each line's starters can produce a t2 (first quests achievable)
	var counts := {}
	for cell in G.STARTER_ITEMS:
		var k: int = G.STARTER_ITEMS[cell]
		counts[k] = int(counts.get(k, 0)) + 1
	ok(int(counts.get(101, 0)) >= 2 and int(counts.get(201, 0)) >= 2, "starters give each line a pair")

	# 9. stars currency (Save)
	fresh("stars")
	ok(Save.stars() == 0, "stars default 0")
	Save.add_stars(3)
	ok(Save.stars() == 3, "add_stars banks")
	ok(Save.spend_stars(3) and Save.stars() == 0, "spend_stars deducts")
	ok(not Save.spend_stars(1), "spend_stars refuses when broke")

	# 10. the SCENE stands up and plays headless (merge → bramble → deliver → gate)
	fresh("scene")
	var scn = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(scn)
	if scn.board == null:
		scn._ready()
	ok(scn.board != null and scn.board.bramble_count() > 0, "grove scene builds with a brambled board")
	var half: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
	scn._on_press(scn._cell_pos(Vector2i(3, 2)) + half)
	scn._on_release(scn._cell_pos(Vector2i(3, 4)) + half)
	ok(scn.board.item_at(Vector2i(3, 4)) == 102, "drag-merge grows t1+t1 into t2")
	await create_timer(0.35).timeout
	ok(scn.board.is_open(Vector2i(2, 4)), "the merge cleared an adjacent first-frontier bramble")
	ok(scn.board.item_at(Vector2i(2, 4)) > 0, "the cleared bramble revealed its contents")

	var items_before := 0
	for v in scn.board.items:
		if v > 0:
			items_before += 1
	scn._pop_seed()
	await create_timer(0.3).timeout
	var items_after := 0
	for v in scn.board.items:
		if v > 0:
			items_after += 1
	ok(items_after == items_before + 1, "the satchel pops one item onto the board")

	# deliver: chapter 1's first quest wants flower t2 (code 102) — we just made one
	ok(not scn.giver_chips.is_empty(), "givers are on duty")

	# AB5: frameless fence anatomy — the ask rides a content-sized pill (no
	# band-filling parchment card), the pill sits BELOW the bust, and the
	# ready-check is present but hidden (the old border ring is gone).
	await create_timer(0.05).timeout
	for e in scn.giver_chips:
		var gstand: Control = e.chip
		var gpills := gstand.find_children("*", "PanelContainer", true, false)
		ok(gpills.size() >= 1, "AB: the giver ask rides a pill")
		if not gpills.is_empty():
			var gpill: Control = gpills[0]
			var ghb := gpill.find_children("*", "HBoxContainer", true, false)
			if not ghb.is_empty():
				assert_wraps(gpill, ghb[0], 6.0, 8.0, "AB ask pill hugs its content")
			ok(gpill.get_rect().position.y >= 100.0, "AB pill rides below the bust, on the fence")
		# AB3: the check is the ONLY ready affordance (the border ring is deleted);
		# its visibility is driven by board state, so assert presence, not momentary vis.
		var gck: Control = e.check
		ok(gck != null and is_instance_valid(gck) and gck is Panel, "AB ready-check node present (ring deleted)")
	var qi: int = scn.giver_chips[0].qi
	var dq: Dictionary = scn._chapter().quests[qi]
	# clear the open board first so EVERY ask fits regardless of prior test state
	# (determinism: a crowded board could otherwise starve a multi-ask delivery)
	for ci in scn.board.items.size():
		if scn.board.items[ci] > 0 and not G.is_coin(scn.board.items[ci]):
			scn.board.items[ci] = 0
	var demp: Array = scn.board.empty_ground_cells()
	var dei := 0
	for ask in G.quest_asks(dq):
		var ac: int = int(ask.line) * 100 + int(ask.tier)
		for n in int(ask.count):
			if dei < demp.size():
				scn.board.place(demp[dei], ac)
				dei += 1
	scn._rebuild_pieces()
	var stars_before := Save.stars()
	scn._on_giver_tap(qi, scn.giver_chips[0].chip)
	ok(Save.stars() > stars_before, "delivery pays stars (all asks satisfied)")
	ok(scn.qdone[qi], "delivery marks the quest done")

	# AA: the star gate is SOFT — banking stars does NOT pause the givers; the finite
	# pool exhausts naturally, and only THEN is Decorate the lone move.
	Save.add_stars(10)
	scn._rebuild_givers()
	scn._update_hud()
	ok(scn._gate_ready(), "AA: the gate is affordable (cheapest frontier spot)")
	ok(not scn.giver_chips.is_empty(), "AA: givers KEEP serving past gate-ready (bank stars if you want)")
	ok(scn.gate_btn.visible, "AA: the Decorate CTA appears at gate-ready")
	# AA2: the CTA's reserved slot never covers a giver/merchant pill (any population)
	var aa_gate: Rect2 = scn.gate_btn.get_global_rect()
	var aa_clear := true
	for e in scn.giver_chips:
		if aa_gate.intersects((e.chip as Control).get_global_rect()):
			aa_clear = false
	if scn.merchant_chip != null and is_instance_valid(scn.merchant_chip):
		if aa_gate.intersects(scn.merchant_chip.get_global_rect()):
			aa_clear = false
	ok(aa_clear, "AA2: the Decorate CTA's reserved slot covers no giver/merchant")
	# AA: finish the WHOLE pool → the fence runs dry, the CTA is the only move left
	for qd in scn.qdone.size():
		scn.qdone[qd] = true
	scn._rebuild_givers()
	scn._update_hud()
	ok(scn._active_quest_idx().is_empty(), "AA: the chapter's pool exhausts naturally (fence runs dry)")
	ok(scn.gate_btn.visible, "AA: with the pool dry, Decorate is the only move")
	for qd2 in scn.qdone.size():
		scn.qdone[qd2] = false                # restore for the buy test below
	scn._rebuild_givers()
	# buying a home spot IS the chapter gate: chapter derives from unlocks
	var ch_before: int = scn._chapter_idx()
	var gu := Save.grove()
	var first_spot: String = G.ZONES[0].spots[0].id
	gu["unlocks"] = {first_spot: true}
	Save.grove_write()
	ok(scn._chapter_idx() == ch_before + 1, "a home purchase advances the board's chapter")

	# persistence: a fresh scene resumes the same board
	var snapshot := Array(scn.board.items)
	var scn2 = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(scn2)
	if scn2.board == null:
		scn2._ready()
	ok(Array(scn2.board.items) == snapshot and scn2._chapter_idx() == scn._chapter_idx(), \
		"a fresh scene resumes the persisted board and chapter")

	# 11. P2 — water economy + coins
	fresh("p2")
	var s2 = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(s2)
	if s2.board == null:
		s2._ready()
	ok(s2.water == G.WATER_CAP, "fresh grove starts at the water cap")
	Save.grove()["pops"] = 10                 # past the FTUE free pops (tested in P5)
	var w0: int = s2.water
	s2._pop_seed()
	await create_timer(0.3).timeout
	ok(s2.water == w0 - G.POP_COST, "a pop costs water")

	s2.water = 0
	var pieces_before := 0
	for v in s2.board.items:
		if v > 0:
			pieces_before += 1
	s2._pop_seed()
	await create_timer(0.25).timeout
	var pieces_after := 0
	for v in s2.board.items:
		if v > 0:
			pieces_after += 1
	ok(pieces_after == pieces_before, "no water → the satchel pops nothing")
	s2._update_water_hud()
	ok(s2.refill_btn.visible, "the free-refill offer appears on empty")
	s2._on_refill()
	ok(s2.water == G.WATER_CAP and s2.refills_used == 1, "free refill fills to cap, once counted")

	# regen: 10 simulated minutes → +5
	s2.water = 50
	s2._regen_ts = Time.get_unix_time_from_system() - 600.0
	s2._tick_water()
	ok(s2.water == 55, "regen pays +1 per 2 minutes (offline math)")

	# the chapter water gift now pays on the HOME spot purchase (tested in 14b)

	# coins: drop → tap-collect → wallet
	var coins0 := Save.coins()
	s2._drop_coin_near(Vector2i(4, 3))
	await create_timer(0.3).timeout
	var coin_cell := Vector2i(-1, -1)
	for i in s2.board.items.size():
		if s2.board.items[i] > 0 and G.is_coin(s2.board.items[i]):
			coin_cell = GroveBoard.cell_of(i)
			break
	ok(coin_cell != Vector2i(-1, -1), "a coin dropped onto the board")
	var chalf: Vector2 = Vector2(s2.csz, s2.csz) / 2.0
	s2._on_press(s2._cell_pos(coin_cell) + chalf)
	s2._on_release(s2._cell_pos(coin_cell) + chalf)
	ok(Save.coins() == coins0 + 1, "tapping a coin pockets its value")
	ok(s2.board.item_at(coin_cell) == 0, "the collected coin left the board")

	# coin merge rules (model): c1+c1 merges, c3 is capped
	var bc: GroveBoard = GroveBoard.new()
	bc.place(Vector2i(3, 2), 901)
	bc.place(Vector2i(3, 4), 901)
	ok(bc.can_merge(Vector2i(3, 2), Vector2i(3, 4)), "coins merge with coins")
	bc.place(Vector2i(5, 2), 903)
	bc.place(Vector2i(5, 4), 903)
	ok(not bc.can_merge(Vector2i(5, 2), Vector2i(5, 4)), "top coin (25) never merges")
	ok(bc.top_tier_cells().is_empty(), "coins are never merchant goods")

	# 12. win-back: away 3 days with low water → full cap on return
	fresh("winback")
	var gw := Save.grove()
	gw["board"] = GroveBoard.new().to_dict()
	gw["water"] = 10
	gw["regen_ts"] = Time.get_unix_time_from_system() - 3 * 86400.0
	gw["last_seen"] = Time.get_unix_time_from_system() - 3 * 86400.0
	Save.grove_write()
	var s3 = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(s3)
	if s3.board == null:
		s3._ready()
	ok(s3.water == G.WATER_CAP, "returning after days away finds full water")

	# 12b. a cold load at chapter 16+ draws EVERY active generator, not just the satchel
	fresh("twogens")
	var gtg := Save.grove()
	var ul16 := {}
	for z in 2:
		for sp in G.ZONES[z].spots:
			ul16[String(sp.id)] = true
	gtg["unlocks"] = ul16
	Save.grove_write()
	var s4 = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(s4)
	if s4.board == null:
		s4._ready()
	ok(s4.gen_nodes.size() == 2, "chapter-16 rebuild draws both the satchel and the compost bin")
	ok(s4.gen_node == s4.gen_nodes.get(0), "gen_node still points at the starter satchel")

	# 12b2. a runtime-opened cell's ground tile sits ABOVE the mat (owner's
	# "no border" bug: move_child(slot, 0) hid the tile behind the moss)
	fresh("opentile")
	var s4b = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(s4b)
	if s4b.board == null:
		s4b._ready()
	var mat_ref: Node = s4b.board_area.get_child(0)
	var slots_before: int = _panel_count(s4b.board_area)
	s4b._open_bramble(Vector2i(2, 3))          # the first frontier
	ok(s4b.board_area.get_child(0) == mat_ref, "the mat stays child 0 after a runtime open")
	var new_slot: Control = s4b.slot_nodes[Vector2i(2, 3)]
	ok(new_slot.get_index() >= 1, "the freed cell's tile sits ABOVE the mat (index >= 1)")
	ok(_panel_count(s4b.board_area) == slots_before + 1, "exactly one new ground tile")
	var live_slots: int = _panel_count(s4b.board_area)
	s4b._rebuild_all()
	await create_timer(0.1).timeout            # let the rebuild's queue_frees flush
	ok(_panel_count(s4b.board_area) == live_slots, \
		"runtime tiles match a fresh rebuild of the same board (parity)")

	# 12c. the idle wiggle hint finds a real mergeable pair (starters pair up)
	var hint: Array = s3._hint_pair()
	ok(hint.size() == 2 and s3.board.item_at(hint[0]) == s3.board.item_at(hint[1]) \
		and s3.board.can_merge(hint[0], hint[1]), "the idle hint wiggles a true mergeable pair")

	# 12d. the fence shows MORE asks at once (owner: not just two)
	ok(s3.giver_chips.size() >= 3, "the quest fence seats 3+ givers (%d shown)" % s3.giver_chips.size())

	# 13. P3 — zones/spots content sanity + level math
	var zones_ok := true
	for z in G.ZONES.size():
		var n: int = G.ZONES[z].spots.size()
		if n < 8 or n > 10:
			zones_ok = false
		var seen_ids := {}
		for s in G.ZONES[z].spots:
			if int(s.cost) < 3 or int(s.cost) > 5:
				zones_ok = false
			seen_ids[String(s.id)] = true
		if seen_ids.size() != n:
			zones_ok = false
	ok(zones_ok, "every zone has 8-10 unique spots costing 3-5 stars (owner pacing)")
	var asc := true
	for i in range(1, G.LEVEL_XP.size()):
		if G.LEVEL_XP[i] <= G.LEVEL_XP[i - 1]:
			asc = false
	ok(asc, "level thresholds ascend")
	ok(G.level_for_exp(0) == 1 and G.level_for_exp(60) == 2 and G.level_for_exp(139) == 2, \
		"level_for_exp maps thresholds correctly")

	# 14. P3 — the HOME scene: buy → exp → level-up water gift → zone gating → resume
	fresh("home")
	var h = load("res://engine/scenes/Home.tscn").instantiate()
	get_root().add_child(h)
	if h.vista == null:
		h._ready()
	ok(h.zone_unlocked(0) and not h.zone_unlocked(1), "farmhouse open, barn locked, on a fresh save")
	# the interior model (order K): the map holds ONLY closed chests; tapping a
	# zone walks INSIDE — a full-screen room listing every unlockable
	ok(h.spot_hits.is_empty() and h.interior == null, "all closed on arrival — no floating buttons")
	ok(h.zone_stars_left(0) == 31, "the closed chest can state the stars left inside (31)")
	# R2: the zone pin — status in a plank, centered h+v, anchored bottom-center
	# UNDER the building with one shared offset (rect guard; crop is the eye proof)
	await create_timer(0.05).timeout
	var poi0: Control = h.zone_nodes[0]
	var plank0: Control = null
	for ch in poi0.get_children():
		if ch is PanelContainer:
			plank0 = ch
	ok(plank0 != null, "R2: the zone pin has a status plank")
	assert_centered(poi0, plank0, "h", 2.0, "R2 pin plank under building")
	assert_centered(plank0, plank0.get_child(0), "hv", 2.0, "R2 status text in plank")
	ok(plank0.offset_top >= G.POI_SIZE, "R2: the plank sits below the building art")
	# the offset is SHARED — every zone's plank uses the same offset_top
	var shared := true
	for zz in h.zone_nodes.size():
		for ch in h.zone_nodes[zz].get_children():
			if ch is PanelContainer and not is_equal_approx(ch.offset_top, plank0.offset_top):
				shared = false
	ok(shared, "R2: all five zones share ONE status-plank offset")
	h._open_interior(0)
	ok(h.interior != null, "the interior takeover opens")
	ok(h.spot_hits.size() == G.ZONES[0].spots.size(), "the room lists every unlockable inside")
	# systemic guard (3rd input-swallow bug): ONE input surface per layer —
	# every Control under the vista AND under the interior root IGNOREs
	ok(_all_ignore(h.vista), "every vista descendant IGNOREs mouse (single input surface)")
	ok(_all_ignore(h.interior), "every interior descendant IGNOREs mouse too")
	h._close_interior()
	ok(h.interior == null and h.spot_hits.is_empty(), "back closes the room")
	h._open_interior(0)
	Save.add_stars(100)
	var card := Control.new()                 # host for stand-in tap nodes
	get_root().add_child(card)
	var pin := Button.new()
	card.add_child(pin)
	# level gates: rank 2 wants L2 — a fresh L1 player can't buy it, no stars move
	ok(G.spot_level_req(0, 0) == 1 and G.spot_level_req(0, 2) == 2, "spot gates derive from rank")
	var stars0 := Save.stars()
	h._on_spot_tap(0, 2, pin, Vector2(300, 300))
	ok(not h.spot_owned(String(G.ZONES[0].spots[2].id)) and Save.stars() == stars0, \
		"a level-locked item refuses the purchase (greyed, not buyable)")
	h._on_spot_tap(0, 0, pin, Vector2(300, 300))
	ok(h.spot_owned("fh_chest"), "buying a spot records the unlock")
	ok(Save.stars() == stars0 - 3, "the spot's stars were spent")
	ok(h.exp_points == 30, "the unlock granted cost*10 exp")
	ok(h.interior != null, "the interior STAYS OPEN across a purchase")
	# OS back: the GO_BACK notification closes the room (and only the room)
	h.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await create_timer(0.1).timeout
	ok(h.interior == null, "OS back closes the interior")
	# every way OUT of the room (owner report: "no way to go back")
	h._open_interior(0)
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	h._unhandled_input(esc)
	ok(h.interior == null, "Esc (ui_cancel) closes the interior")
	h._open_interior(0)
	_int_tap(h, h._back_hit.get_center())
	ok(h.interior == null, "the round back button closes the room")
	h._open_interior(0)
	var vsz: Vector2 = h.get_viewport_rect().size
	_int_tap(h, Vector2(8, vsz.y - 8.0))   # bottom-left corner is surround at any aspect
	ok(h.interior == null, "a tap on the dark surround steps back out")
	h._open_interior(0)
	_int_tap(h, h._int_art_rect.get_center())
	ok(h.interior != null, "a tap on the room art itself STAYS inside")
	h._close_interior()
	h._open_interior(0)
	# the gate cost ignores level-locked spots (givers must never pause for one)
	ok(G.cheapest_spot_cost({}, 1) == 3, "gate cost sees the level-1 spots")
	var ul_two := {String(G.ZONES[0].spots[0].id): true, String(G.ZONES[0].spots[1].id): true}
	ok(G.cheapest_spot_cost(ul_two, 1) == -2, "all-remaining-locked reports -2 (gate stays quiet)")

	# level-up: push exp to the L2 threshold and watch the water gift land
	var g2 := Save.grove()
	g2["water"] = 10
	h.exp_points = 55
	h._grant_exp(10)                          # 65 ≥ 60 → level 2
	ok(int(Save.grove().get("water", 0)) == 10 + G.LEVEL_WATER_GIFT, "level-up gifts water")

	# buy out the whole farmhouse (rank order keeps every gate met) → the barn opens
	for i in G.ZONES[0].spots.size():
		var sid: String = G.ZONES[0].spots[i].id
		if not h.spot_owned(sid):
			h._on_spot_tap(0, i, Button.new(), Vector2(300, 300))
	ok(h.zone_complete(0), "all farmhouse spots bought")
	ok(h.zone_unlocked(1), "completing a zone opens the next (sequential gating)")
	h._persist()

	# 14a2. customization: the owned item itself offers coin/diamond looks
	var vars0: Array = G.spot_variants(0, 0)
	ok(vars0.size() == 3 and String(vars0[1].currency) == "coins" and String(vars0[2].currency) == "diamonds" \
		and int(vars0[1].cost) > 0 and int(vars0[2].cost) > 0, "each spot offers a coin and a diamond variant")
	Save.grove()["custom"] = {"fh_chest": "gem"}
	ok(String(h._spot_variant(0, 0).id) == "gem", "the chosen variant persists and resolves")
	# the customize strip is INLINE in the room — no modal, no veil (K carries F2)
	h._customize_spot = "fh_chest"
	h._build_interior()
	ok(h.variant_hits.size() == 3, "the inline strip exposes all 3 variants as chips")
	ok(_all_ignore(h.interior), "the strip keeps the single-input-surface rule")
	Save.add_coins(100)
	var coins_v0 := Save.coins()
	var coin_vid := ""
	var coin_cost := 0
	for v in G.spot_variants(0, 0):
		if String(v.currency) == "coins":
			coin_vid = String(v.id)
			coin_cost = int(v.cost)
	h._apply_variant(0, 0, coin_vid, Vector2(300, 300))
	ok(String(h._spot_variant(0, 0).id) == coin_vid and Save.coins() == coins_v0 - coin_cost, \
		"a swatch tap pays coins and dresses the item in place")
	ok(h.variant_hits.is_empty() and h._customize_spot == "", "the strip tucks away after applying")
	ok(h.interior != null, "customizing keeps you in the room")
	h._close_interior()

	# 14a3. Q save migration: a pre-Q save (old spot ids) renames in place on the
	# shared grove() accessor — ownership AND chosen variant survive, counts intact.
	# Old ids are sourced from the rename map itself (no stale literals in tests).
	fresh("qmig")
	var ren: Dictionary = Save._SPOT_ID_RENAMES
	var first_old: String = ren.keys()[0]
	var gm := Save.grove()
	var u_seed := {}
	for old in ren:
		u_seed[old] = true
	gm["unlocks"] = u_seed
	gm["custom"] = {first_old: "gem"}
	Save.grove()                              # the accessor migrates on read
	var um: Dictionary = Save.grove().get("unlocks", {})
	var cm: Dictionary = Save.grove().get("custom", {})
	var all_renamed := true
	for old in ren:
		if um.has(old) or not um.has(String(ren[old])):
			all_renamed = false
	ok(all_renamed, "Q migration renames ALL unlock ids old→new (ownership survives)")
	ok(um.size() == ren.size(), "migration preserves the unlock COUNT (chapters/stars intact)")
	ok(String(cm.get(String(ren[first_old]), "")) == "gem" and not cm.has(first_old), \
		"Q migration renames custom old→new (chosen look survives)")
	Save.grove()                              # idempotent: a second pass changes nothing
	ok(Save.grove().get("unlocks", {}).size() == ren.size() and not Save.grove().get("unlocks", {}).has(first_old), \
		"Q migration is idempotent")

	# 14b. an orchard-era purchase pays its chapter's water gift (z4 ramp gifts 4;
	# earlier zones gift 0 by sim derivation)
	var gw2 := Save.grove()
	var ul24 := {}
	for z4 in 3:                             # zones 1-3 fully bought → chapter 24
		for sp in G.ZONES[z4].spots:
			ul24[String(sp.id)] = true
	gw2["unlocks"] = ul24
	h.unlocks = ul24
	gw2["water"] = 50
	h.exp_points = 1500                      # past the level table: no level-up water
	Save.add_stars(10)
	h._on_spot_tap(3, 0, Button.new(), Vector2(300, 300))   # closing ch 24 → zone 4 → gift 4
	ok(int(Save.grove().get("water", 0)) == 54, "the home purchase pays the chapter's water gift")

	# 14c. the pigeonhole proof in motion: worst-case cheapest-first buying is
	# NEVER stranded by a level gate, all the way to the end of the map
	var sim_ul := {}
	var sim_exp := 0
	var strand := false
	while sim_ul.size() < G.chapters().size():
		var lvl_now := G.level_for_exp(sim_exp)
		var pick_z := -1
		var pick_k := -1
		var pick_cost := 99
		for z5 in G.ZONES.size():
			var zone_missing := false
			for k5 in G.ZONES[z5].spots.size():
				if sim_ul.has(String(G.ZONES[z5].spots[k5].id)):
					continue
				zone_missing = true
				if G.spot_level_req(z5, k5) <= lvl_now and int(G.ZONES[z5].spots[k5].cost) < pick_cost:
					pick_cost = int(G.ZONES[z5].spots[k5].cost)
					pick_z = z5
					pick_k = k5
			if zone_missing:
				break                          # zones open sequentially
		if pick_z < 0:
			strand = true
			break
		sim_ul[String(G.ZONES[pick_z].spots[pick_k].id)] = true
		sim_exp += pick_cost * G.EXP_PER_STAR
	ok(not strand, "level gates never strand the map (worst-case order, all 40 spots)")

	# a fresh Home resumes the same progress
	var h2 = load("res://engine/scenes/Home.tscn").instantiate()
	get_root().add_child(h2)
	if h2.vista == null:
		h2._ready()
	ok(h2.zone_complete(0) and h2.exp_points == h.exp_points, "home progress persists across scenes")

	# 15. P5 — sell anything, diamonds, FTUE staging
	fresh("p5")
	var s5 = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(s5)
	if s5.board == null:
		s5._ready()
	# FTUE: the first ten SUCCESSFUL pops are free; the eleventh starts the meter
	s5.board.take(Vector2i(3, 2))            # make room (a virgin board has 2 empties)
	s5.board.take(Vector2i(3, 4))
	s5._rebuild_pieces()
	Save.grove()["pops"] = 9
	s5._pop_seed()                            # the 10th intro pop — still free
	await create_timer(0.25).timeout
	ok(s5.water == G.WATER_CAP, "the FTUE intro pops are free (the verb before the meter)")
	s5._pop_seed()                            # the 11th — the meter begins
	await create_timer(0.25).timeout
	ok(s5.water == G.WATER_CAP - 1, "the eleventh pop starts costing water")
	ok(s5.merchant_chip == null, "the merchant waits for the first spot (chapter 1)")

	# sell anything: a t3 flower pays 3 coins and leaves the board
	Save.grove()["unlocks"] = {String(G.ZONES[0].spots[0].id): true}
	Save.grove_write()
	s5._rebuild_givers()
	ok(s5.merchant_chip != null, "the merchant arrives with chapter 1")
	s5.board.place(Vector2i(3, 3), 103)
	s5._rebuild_pieces()
	var c0 := Save.coins()
	s5._sell_item(Vector2i(3, 3), s5.piece_nodes.get(Vector2i(3, 3)))
	ok(Save.coins() == c0 + 3 and s5.board.item_at(Vector2i(3, 3)) == 0, \
		"selling a t3 pays 3 coins and clears the cell")
	ok(G.sell_value(108) == 8 and G.sell_value(201) == 1, "sell value scales with tier")

	# diamonds: accessors + paid rain once the freebies are spent
	ok(Save.diamonds() == 0, "diamonds default 0")
	Save.add_diamonds(30)
	s5.refills_used = G.FREE_REFILLS
	s5.water = 0
	s5._update_water_hud()
	ok(s5.refill_btn.visible, "paid rain offered when diamonds suffice")
	s5._on_refill()
	ok(s5.water == G.WATER_CAP and Save.diamonds() == 30 - G.REFILL_DIAMOND_COST, \
		"paid rain fills the cap and spends diamonds")

	# the third bag slot: buy with diamonds, capacity grows
	ok(s5._bag_capacity() == 2, "bag starts at two slots")
	Save.add_diamonds(G.BAG3_DIAMOND_COST)
	s5._on_bag_tap(2)
	ok(bool(Save.grove().get("bag3", false)) and s5._bag_capacity() == 3, \
		"the third bag slot purchase sticks")

	# home grants: a level-up pays diamonds too
	var h5 = load("res://engine/scenes/Home.tscn").instantiate()
	get_root().add_child(h5)
	if h5.vista == null:
		h5._ready()
	var d0 := Save.diamonds()
	h5.exp_points = int(G.LEVEL_XP[1]) - 5
	h5._grant_exp(10)
	ok(Save.diamonds() == d0 + G.LEVEL_DIAMONDS, "level-ups pay diamonds")

	# 16. the discovery log + the upgrade-path card (tap an item → its ladder;
	# unseen tiers stay "?")
	fresh("ladder")
	var s6 = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(s6)
	if s6.board == null:
		s6._ready()
	var lad: Array = s6._ladder_entries(1)
	ok(lad.size() == G.TOP_TIER, "the ladder lists every tier of the line")
	ok(bool(lad[0].seen) and not bool(lad[1].seen), "starters are known; tier 2 still a mystery")
	var h6: Vector2 = Vector2(s6.csz, s6.csz) / 2.0
	s6._on_press(s6._cell_pos(Vector2i(3, 2)) + h6)
	s6._on_release(s6._cell_pos(Vector2i(3, 4)) + h6)
	await create_timer(0.3).timeout
	ok(bool(s6._ladder_entries(1)[1].seen), "merging writes the produced tier into the log")
	ok(not bool(s6._ladder_entries(3)[0].seen), "an undebuted line stays fully unknown")
	var kids0: int = s6.get_child_count()
	s6._open_ladder(1, 2)
	ok(s6.get_child_count() == kids0 + 1, "the upgrade-path card opens over the board")
	var persisted: Dictionary = Save.grove().get("seen", {})
	ok(persisted.has("102"), "the discovery log persists in the save")

	# 17. the Shop: diamond packs grant, cash confirm grants directly (no rails yet)
	fresh("shop")
	var Shop = load("res://engine/scripts/shop.gd")
	ok(not Shop.buy_coin_pack(), "the coin pack refuses without diamonds")
	Save.add_diamonds(30)
	var coins_before := Save.coins()
	ok(Shop.buy_coin_pack(), "the coin pack sells")
	ok(Save.coins() == coins_before + Shop.COIN_PACK and Save.diamonds() == 30 - Shop.COIN_PACK_GEM_COST, \
		"coin pack: -%d💎 +%d🪙" % [Shop.COIN_PACK_GEM_COST, Shop.COIN_PACK])
	var gems_before := Save.diamonds()
	Shop.grant_cash_pack(0)
	ok(Save.diamonds() == gems_before + int(Shop.CASH_PACKS[0].gems), \
		"confirming a cash pack adds the diamonds directly")
	ok(Shop.buy_water() and Save.diamonds() == gems_before + int(Shop.CASH_PACKS[0].gems) - G.REFILL_DIAMOND_COST, \
		"the water purchase spends its diamonds (price = G.REFILL_DIAMOND_COST)")
	var s7 = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(s7)
	if s7.board == null:
		s7._ready()
	var kids7: int = s7.get_child_count()
	Shop.open(s7, {})
	ok(s7.get_child_count() == kids7 + 1, "the storefront opens over the board")
	# the water row appears ONLY when the host can grant water
	var rows_plain := _shop_rows(s7)
	Shop.open(s7, {"water_grant": func() -> void: pass})
	var rows_water := _shop_rows(s7)
	ok(rows_water == rows_plain + 1, "the water row appears only with a water_grant (%d -> %d)" % [rows_plain, rows_water])

	# 18. the HUD module: same labels, same pixels, in BOTH scenes
	var h7 = load("res://engine/scenes/Home.tscn").instantiate()
	get_root().add_child(h7)
	if h7.vista == null:
		h7._ready()
	var kids_h7: int = h7.get_child_count()
	Shop.open(h7, {})
	ok(h7.get_child_count() == kids_h7 + 1, "the storefront opens over the home map too")
	ok(s7.stars_label != null and s7.coins_label != null and s7.diamonds_label != null, \
		"the board's HUD labels exist")
	ok(h7.stars_label != null and h7.coins_label != null, "home's HUD labels exist")
	Save.add_stars(3)
	h7._update_hud()
	await create_timer(0.6).timeout            # numbers TICK toward the target (§6)
	ok(h7.stars_label.text == str(Save.stars()), "the module refresh keeps the wallet live (ticked)")
	var p_grove: Control = s7.stars_label.get_parent().get_parent()
	var p_home: Control = h7.stars_label.get_parent().get_parent()
	ok(p_grove.offset_top == p_home.offset_top and p_grove.offset_right == p_home.offset_right, \
		"the wallet panel sits at IDENTICAL offsets in both scenes")
	# R1: the plank wraps the WHOLE cluster — even (symmetric) padding, the row
	# (store basket + ★/🪙/💧) fully inside (rect guard; the crop is the eye proof)
	await create_timer(0.05).timeout            # let the panel lay out
	var row_home: Control = h7.stars_label.get_parent()
	assert_wraps(p_home, row_home, 10.0, 4.0, "R1 wallet")
	var store_btn: Control = row_home.get_child(0)
	ok(p_home.get_global_rect().grow(-4.0).encloses(store_btn.get_global_rect()), \
		"R1: the store button sits fully inside the plank")

	# 19. order L — ambient life + weather
	fresh("ambient")
	var Ambient = load("res://engine/scripts/ambient.gd")
	ok(G.completed_zones({}) == 0, "no zones done on a fresh save")
	var full0 := {}
	for sp0 in G.ZONES[0].spots:
		full0[String(sp0.id)] = true
	ok(G.completed_zones(full0) == 1 and Ambient.spirit_count(full0) == 2, \
		"spirit count = 1 + completed zones")
	var alayer: Control = Ambient.build_layer(Vector2(1000, 1000), full0)
	ok(alayer.get_child_count() == 2, "the layer carries that many spirits")
	ok(_all_ignore(alayer), "spirits never eat input")
	alayer.free()
	var ga := Save.grove()
	ga["winback_until"] = Time.get_unix_time_from_system() + 60.0
	ok(Ambient.weather_now(false) == "rain", "the win-back minute rains")
	ok(Ambient.weather_now(true) == "breeze", "calm mode WINS: breeze, never rain")
	Ambient.forced_weather = "snow"
	ok(Ambient.weather_now(true) == "snow", "shot tools can force a state")
	Ambient.forced_weather = ""
	var h8 = load("res://engine/scenes/Home.tscn").instantiate()
	get_root().add_child(h8)
	if h8.vista == null:
		h8._ready()
	ok(h8.vista.get_node_or_null("AmbientLayer") != null, "the map carries the spirit layer")
	ok(h8.get_node_or_null("WeatherLayer") != null, "the map carries the weather layer")
	ok(_all_ignore(h8.vista), "the map guard stays green with spirits wandering")
	var s8 = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(s8)
	if s8.board == null:
		s8._ready()
	ok(s8.get_node_or_null("AmbientLayer") != null and s8.get_node_or_null("WeatherLayer") != null, \
		"the board carries both layers (sparse band)")

	# 20. order N — feature flags: all-ON is proven by the whole sweep (zero
	# behavior change); two flip smokes prove the guards actually disconnect
	var Features = load("res://engine/scripts/features.gd")
	ok(Features.on("idle_hint") and Features.on("nonexistent_flag_xyz"), \
		"known flags read true; unknown ids warn + default ON (typo-proof)")
	Features.FLAGS["idle_hint"] = false
	ok(s8._hint_pair().is_empty(), "idle_hint OFF: _hint_pair returns [] and wiggles nothing")
	Features.FLAGS["idle_hint"] = true
	fresh("flagpop")
	Features.FLAGS["ftue_free_pops"] = false
	var s9 = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(s9)
	if s9.board == null:
		s9._ready()
	s9.board.take(Vector2i(3, 2))             # a virgin board has 2 empties — make room
	s9._rebuild_pieces()
	s9._pop_seed()
	await create_timer(0.25).timeout
	ok(s9.water == G.WATER_CAP - 1, "ftue_free_pops OFF: the FIRST pop costs water")
	Features.FLAGS["ftue_free_pops"] = true

	# 21. R4 — sweep the composited UI with the pixel-right asserts. Each element
	# now has PERMANENT rect coverage (the law's durable value); a failure here is
	# a real misalignment to fix. (wallet was R1; zone pin R2.)
	fresh("r4")
	# water chip (board, top-left) — reveal past the FTUE stage, then assert it wraps
	var sb4 = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(sb4)
	if sb4.board == null:
		sb4._ready()
	Save.grove()["pops"] = 10                 # FTUE done → the water chip shows
	sb4._update_water_hud()
	await create_timer(0.05).timeout
	var wchip: Control = sb4.water_label.get_parent().get_parent()
	var wrow: Control = sb4.water_label.get_parent()
	assert_wraps(wchip, wrow, 5.0, 4.0, "R4 water chip")
	# level chip (home, top-left)
	var h4 = load("res://engine/scenes/Home.tscn").instantiate()
	get_root().add_child(h4)
	if h4.vista == null:
		h4._ready()
	await create_timer(0.05).timeout
	# the level number now nests inside a sprout-avatar Control, so walk up to the
	# pill (PanelContainer) and assert it wraps its content row evenly.
	var lchip: Control = h4.level_label
	while lchip != null and not (lchip is PanelContainer):
		lchip = lchip.get_parent()
	var lrow4: Control = lchip.get_child(0)
	assert_wraps(lchip, lrow4, 5.0, 2.0, "R4 level chip")     # ±2: catches lopsided margins
	# interior pin (a locked spot) — the price pin wraps its row (S7 nests pins
	# in a centered stack, so search the subtree, and FAIL loudly if absent)
	h4._open_interior(0)
	await create_timer(0.05).timeout
	var pin_panel: Control = null
	for hit in h4.spot_hits:
		var node: Control = hit.node
		var found: Array = node.find_children("*", "PanelContainer", true, false)
		if not found.is_empty():
			pin_panel = found[0]
			break
	ok(pin_panel != null and pin_panel.get_child_count() > 0, "R4/S7: an interior price pin exists")
	if pin_panel != null and pin_panel.get_child_count() > 0:
		assert_wraps(pin_panel, pin_panel.get_child(0), 4.0, 4.0, "R4 interior pin")
	h4._close_interior()

	# 22. U1 — item backing (contrast): ON puts a soft dark ellipse UNDER the item
	# (first child = bottom); OFF leaves the item bare. Flag item_backing.
	Features.FLAGS["item_backing"] = true
	var pc_on: Control = sb4._make_piece(101, 100.0)
	ok(pc_on.get_child(0) is TextureRect and pc_on.get_child(0).modulate.a < 0.5, \
		"item_backing ON: a soft low-alpha ellipse sits under the item")
	ok(_all_ignore(pc_on), "U1: the backing never eats input")
	Features.FLAGS["item_backing"] = false
	var pc_off: Control = sb4._make_piece(101, 100.0)
	ok(pc_off.get_child(0).modulate.a > 0.9, "item_backing OFF: the item is bare (no backing)")
	Features.FLAGS["item_backing"] = true   # AF3: ON is the default (now a contact shadow)

	# 23. P — drag-to-swap two unlocked items (flag drag_swap)
	# P1: the model — swap trades codes, a coin swaps like anything, it persists
	var pb := GroveBoard.new()
	var pa := Vector2i(4, 4)
	var pbc := Vector2i(4, 5)
	pb.terrain[GroveBoard.idx(pa)] = 0
	pb.terrain[GroveBoard.idx(pbc)] = 0
	pb.place(pa, 101)
	pb.place(pbc, 203)
	pb.swap(pa, pbc)
	ok(pb.item_at(pa) == 203 and pb.item_at(pbc) == 101, "P1: swap trades two item codes")
	var pcoin := G.COIN_LINE * 100 + 1
	pb.place(pa, pcoin)
	pb.swap(pa, pbc)                          # pbc held 101
	ok(pb.item_at(pa) == 101 and pb.item_at(pbc) == pcoin, "P1: a coin swaps like any item")
	var pb2 := GroveBoard.new()
	pb2.from_dict(pb.to_dict())
	ok(pb2.item_at(pa) == 101 and pb2.item_at(pbc) == pcoin, "P1: to_dict/from_dict preserves the swapped board")

	# P2: the drop chain (real _on_press → _on_release drives)
	fresh("pswap")
	Features.FLAGS["drag_swap"] = true
	var sp = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(sp)
	if sp.board == null:
		sp._ready()
	var phalf: Vector2 = Vector2(sp.csz, sp.csz) / 2.0
	var es: Array = sp.board.empty_ground_cells()
	var c1 := Vector2i(es[0])
	var c2 := Vector2i(es[1])
	# occupied-different → swap; BOTH piece_nodes update
	sp.board.place(c1, 101)
	sp.board.place(c2, 203)
	sp._rebuild_pieces()
	sp._on_press(sp._cell_pos(c1) + phalf)
	sp._on_release(sp._cell_pos(c2) + phalf)
	ok(sp.board.item_at(c1) == 203 and sp.board.item_at(c2) == 101, "P2: occupied-different target → swap")
	ok(sp.piece_nodes.has(c1) and sp.piece_nodes.has(c2), "P2: piece_nodes updated for BOTH cells")
	# same-code → MERGE keeps precedence (never swaps)
	sp.board.place(c1, 101)
	sp.board.place(c2, 101)
	sp._rebuild_pieces()
	sp._on_press(sp._cell_pos(c1) + phalf)
	sp._on_release(sp._cell_pos(c2) + phalf)
	ok(sp.board.item_at(c2) == 102 and sp.board.item_at(c1) == 0, "P2: same-code drop MERGES (precedence over swap)")
	# flag OFF → snap-back, nothing swaps
	Features.FLAGS["drag_swap"] = false
	sp.board.place(c1, 101)
	sp.board.place(c2, 203)
	sp._rebuild_pieces()
	sp._on_press(sp._cell_pos(c1) + phalf)
	sp._on_release(sp._cell_pos(c2) + phalf)
	ok(sp.board.item_at(c1) == 101 and sp.board.item_at(c2) == 203, "P2: drag_swap OFF → snap-back (no swap)")
	Features.FLAGS["drag_swap"] = true
	# drop on a generator cell → snap-back (never swaps with a generator)
	var gcell := Vector2i(G.GEN_CELL)
	sp.board.place(c1, 101)
	sp._rebuild_pieces()
	sp._on_press(sp._cell_pos(c1) + phalf)
	sp._on_release(sp._cell_pos(gcell) + phalf)
	ok(sp.board.item_at(c1) == 101, "P2: drop on a generator cell → snap-back")

	# 24. T — Decorate flow goes WHERE the player decorates
	var HomeScript = load("res://engine/scripts/home.gd")
	# T1: opening an interior persists last_zone
	fresh("tlast")
	var ht = load("res://engine/scenes/Home.tscn").instantiate()
	get_root().add_child(ht)
	if ht.vista == null:
		ht._ready()
	ht._open_interior(0)
	ok(String(Save.grove().get("last_zone", "")) == "farmhouse", "T1: opening a room persists last_zone")
	ht._close_interior()
	# T1: sanitize — an unknown id is dropped on load
	Save.grove()["last_zone"] = "atlantis"
	var ht2 = load("res://engine/scenes/Home.tscn").instantiate()
	get_root().add_child(ht2)
	if ht2.vista == null:
		ht2._ready()
	ok(not Save.grove().has("last_zone"), "T1: an unknown last_zone is scrubbed on load")
	ok(ht2.interior == null, "T1: fresh arrival (no jump request) lands on the map")
	# T2: the Decorate jump — interior pre-opened, NO map flash (asserted before any frame)
	Save.grove()["last_zone"] = "farmhouse"
	HomeScript.decorate_zone = "farmhouse"
	var ht3 = load("res://engine/scenes/Home.tscn").instantiate()
	get_root().add_child(ht3)
	if ht3.vista == null:
		ht3._ready()
	ok(ht3.interior != null and ht3._interior_zone == 0, \
		"T2: Decorate pre-opens last_zone's interior (asserted pre-frame: no map flash)")
	ok(HomeScript.decorate_zone == "", "T2: the jump request is one-shot (consumed)")
	# T2: an unknown jump request falls through to the map
	HomeScript.decorate_zone = "atlantis"
	var ht4 = load("res://engine/scenes/Home.tscn").instantiate()
	get_root().add_child(ht4)
	if ht4.vista == null:
		ht4._ready()
	ok(ht4.interior == null, "T2: an unknown jump request falls through to the map")
	# T3: the interior CTA sits in the SAME slot/size as the map's garden CTA
	await create_timer(0.05).timeout
	var map_cta: Control = ht3._chrome_nodes[0]
	var int_cta: Control = null
	for ch in ht3.interior.get_children():
		if ch is Button:
			int_cta = ch
	ok(int_cta != null, "T3: the interior carries the board CTA")
	var rm := map_cta.get_global_rect()
	var ri := int_cta.get_global_rect()
	ok(rm.position.distance_to(ri.position) <= 1.0 and (rm.size - ri.size).length() <= 1.0, \
		"T3: interior CTA rect == map CTA rect (same slot, same size)")
	ok(ht3._int_cta == int_cta, "T3: the tap zone IS the CTA's own laid-out rect (no dup math)")
	ok(_all_ignore(ht3.interior), "T3: the CTA keeps the single-input-surface rule")
	ht3._close_interior()

	# 25. order O — music degrades SILENTLY on a BARE engine. Audio is skin and the
	# real takes are archived, so ensure() must be a quiet no-op (never create a
	# player to crash on). The full A/B playlist-alternation logic ships + is tested
	# WITH the audio skin (needs takes on disk); here we only guard the engine never
	# crashes/hangs without it. (T16: this test used to assume real music on disk.)
	var Music = load("res://engine/scripts/music.gd")
	fresh("omusic")
	Music.stop()
	Music.ensure()
	ok(Music._player == null or not Music._player.playing, "O: no audio skin → ensure() is a silent no-op (no crash/hang)")
	Save.set_setting("music", false)
	Music.refresh()
	ok(Music._player == null or not Music._player.playing, "O: music Off → refresh() leaves the bed silent")
	Save.set_setting("music", true)
	Music.stop()
	Music.take_dir = "res://assets/nonexistent/"
	Music.ensure()
	ok(Music._player == null or not Music._player.playing, "O: zero takes on disk → ensure() is a silent no-op (no crash)")
	Music.take_dir = "res://assets/music/"
	ok(Music._takes().size() == 0, "O: audio skin archived → no takes resolve (bare engine)")

	# 26. order S — placement asserts (S1 bottom bar · S4 chips never clip)
	fresh("sui")
	var ss = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(ss)
	if ss.board == null:
		ss._ready()
	await create_timer(0.05).timeout
	var vp: Rect2 = ss.get_viewport_rect()
	ok(vp.encloses(ss.bottom_bar.get_global_rect()), "S1: the bottom bar sits fully on-screen")
	var bb_row: Control = ss.bottom_bar.get_child(0)
	var bb_home: Control = bb_row.get_child(0)
	ok(ss.bottom_bar.get_global_rect().grow(-2.0).encloses(bb_home.get_global_rect()), \
		"S1: the Home button sits fully inside the plank (was half-clipped)")
	var bb_shop: Control = bb_row.get_child(1)
	ok(ss.bottom_bar.get_global_rect().grow(-2.0).encloses(bb_shop.get_global_rect()), \
		"S1: the shop button sits fully inside the plank")
	assert_wraps(ss.bottom_bar, bb_row, 6.0, 4.0, "S1 bottom bar")
	# S4: every chip fully on-screen, both scenes (refill asserts when visible)
	Save.grove()["pops"] = 10
	ss._update_water_hud()
	await create_timer(0.05).timeout
	var wchip4: Control = ss.water_label.get_parent().get_parent()
	ok(vp.encloses(wchip4.get_global_rect()), "S4: the water chip sits fully on-screen (board)")
	ok(vp.encloses(ss.stars_label.get_parent().get_parent().get_global_rect()), \
		"S4: the wallet sits fully on-screen (board)")
	ok(vp.encloses(ss.level_label.get_parent().get_parent().get_global_rect()), \
		"S4/S10: the Lv chip sits fully on-screen (board — the module ships it to BOTH scenes)")
	ok(not wchip4.get_global_rect().intersects(ss.level_label.get_parent().get_parent().get_global_rect()), \
		"S4: the water chip and the Lv chip do NOT overlap (owner 2026-06-12)")
	var hs = load("res://engine/scenes/Home.tscn").instantiate()
	get_root().add_child(hs)
	if hs.vista == null:
		hs._ready()
	await create_timer(0.05).timeout
	ok(hs.get_viewport_rect().encloses(hs.level_label.get_parent().get_parent().get_global_rect()), \
		"S4: the Lv chip sits fully on-screen (home)")
	ok(hs.get_viewport_rect().encloses(hs.stars_label.get_parent().get_parent().get_global_rect()), \
		"S4: the wallet sits fully on-screen (home)")

	# S2: the chapter title rides a CENTERED ribbon chip (was floating plain text)
	var s2_ribbon: Control = ss.chapter_label.get_parent()
	ok(absf(s2_ribbon.get_global_rect().get_center().x - vp.get_center().x) <= 6.0, \
		"S2: the chapter ribbon is centered on screen (dx=%.1f)" % (s2_ribbon.get_global_rect().get_center().x - vp.get_center().x))
	assert_centered(s2_ribbon, ss.chapter_label, "h", 4.0, "S2 chapter label on its ribbon")

	# S2/S6 regression guards: the chapter chip AND buttons must be SOLID pills —
	# the kit nine-patches (ribbon_title / btn_leaf) collapse invisibly at chip and
	# button heights (margins > the rect), which is how both shipped as floating text.
	ok(s2_ribbon.get_theme_stylebox("panel") is StyleBoxFlat, \
		"S2: the chapter chip is a solid pill (not the collapsing ribbon_title nine-patch)")
	var _skin = load("res://engine/scripts/skin.gd")
	var _pbtn: Button = _skin.button("X", Callable(), true)
	ok(_pbtn.get_theme_stylebox("normal") is StyleBoxFlat, \
		"S6: primary buttons are solid pills (not the collapsing btn_leaf nine-patch)")
	ok(_pbtn.get_theme_constant("outline_size") == 0, \
		"S6: button labels carry no world-outline on the solid pill (panel-text law)")
	_pbtn.queue_free()
	var _sbtn: Button = _skin.button("Y", Callable(), false)
	ok(_sbtn.get_theme_stylebox("normal") is StyleBoxFlat, "S6: secondary buttons are solid pills too")
	ok(_sbtn.alignment == HORIZONTAL_ALIGNMENT_CENTER, "S6: button labels center in the pill")
	_sbtn.queue_free()

	# S4: the rain-refill chip never clips (it shipped as a half-off-screen sliver)
	ss.water = 0
	ss._update_water_hud()
	await create_timer(0.05).timeout
	ok(ss.refill_btn.visible, "S4: the refill offer shows when water is empty")
	ok(vp.encloses(ss.refill_btn.get_global_rect()), "S4: the refill button sits fully on-screen (was a sliver)")
	ss.water = G.WATER_CAP
	ss._update_water_hud()

	# S1: nothing clips at the TALLER aspect either (owner named 1080×1920 + 1080×2340)
	get_root().size = Vector2i(1080, 2340)
	await create_timer(0.06).timeout
	var vp2: Rect2 = ss.get_viewport_rect()
	ok(absf(vp2.size.y - 2340.0) < 2.0, "S1: viewport actually grew to the tall aspect (got %.0f)" % vp2.size.y)
	ok(vp2.encloses(ss.bottom_bar.get_global_rect()), "S1: bottom bar fully on-screen at 1080×2340")
	ok(ss.bottom_bar.get_global_rect().grow(-2.0).encloses(ss.bottom_bar.get_child(0).get_child(1).get_global_rect()), \
		"S1: the shop button stays inside the plank at 1080×2340")
	get_root().size = Vector2i(1080, 1920)
	await create_timer(0.06).timeout

	# --- order W: board feel ----------------------------------------------------
	var ws = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(ws)
	if ws.board == null:
		ws._ready()
	await create_timer(0.05).timeout
	# W1: the idle merge hint comes SOONER and rocks gently (was 7s + a fast shake)
	ok(absf(float(ws.IDLE_HINT_SECS) - 4.5) < 0.01, "W1: first idle hint at 4.5s (was 7)")
	ok(int(ws.HINT_ROCK_CYCLES) >= 2 and float(ws.HINT_ROCK_DEG) <= 10.0, \
		"W1: the hint is a gentle multi-cycle rock, not a one-off fast shake")
	for cc in [Vector2i(1, 3), Vector2i(2, 3)]:
		ws.board.terrain[GroveBoard.idx(cc)] = 0
		ws.board.place(cc, 101)
	ws._rebuild_pieces()
	ok(not ws._hint_pair().is_empty(), "W1: _hint_pair finds a mergeable pair to rock")
	# W2: rapid generator taps must NEVER be dropped by the animating gate. Open a
	# comfortable region, fire 5 board taps WITHOUT awaiting the 0.22s spawn flight.
	for cc in [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5)]:
		ws.board.terrain[GroveBoard.idx(cc)] = 0
		ws.board.items[GroveBoard.idx(cc)] = 0
	ws._rebuild_pieces()
	var w_before := 0
	for v in ws.board.items:
		if v > 0:
			w_before += 1
	var ghalf := Vector2(ws.csz, ws.csz) / 2.0
	var gpos: Vector2 = ws._cell_pos(Vector2i(G.GEN_CELL)) + ghalf
	for i in 5:
		_tap_board(ws, gpos)
	var w_after := 0
	for v in ws.board.items:
		if v > 0:
			w_after += 1
	ok(w_after - w_before == 5, \
		"W2: 5 rapid generator taps land 5 items (animating no longer eats taps) — got %d" % (w_after - w_before))
	# W3: sell discoverability. (a) the first MAX-TIER item floats a one-time hint.
	var top_code := 100 + G.TOP_TIER
	Save.grove().erase("seen_sell_hint")
	var lbls0: int = ws.find_children("*", "Label", true, false).size()
	ws._note_item_landed(top_code)
	ok(bool(Save.grove().get("seen_sell_hint", false)), "W3: a max-tier landing sets the persisted seen flag")
	var lbls1: int = ws.find_children("*", "Label", true, false).size()
	ok(lbls1 > lbls0, "W3: the one-time sell hint floater appears on the first max-tier item")
	ws._note_item_landed(top_code)
	ok(ws.find_children("*", "Label", true, false).size() == lbls1, "W3: the sell hint never fires twice")
	# (b) the merchant brightens + shows a live +N🪙 tag while an item is dragged
	var Feat = load("res://engine/scripts/features.gd")
	Feat.FLAGS["ftue_staged_chrome"] = false
	ws._rebuild_givers()
	await create_timer(0.05).timeout
	ok(ws.merchant_chip != null, "W3: merchant present for the affordance test")
	ws._show_sell_affordance(top_code)
	ok(ws.merchant_sell_tag.visible and ws.merchant_chip.modulate.a >= 0.99, \
		"W3: dragging brightens the stall + shows the sell tag")
	ok(String(ws.merchant_sell_tag_label.text) == "+1💎", \
		"W3/Y1: the tag shows the t8 reward as a diamond (+1💎)")
	ws._hide_sell_affordance()
	ok(not ws.merchant_sell_tag.visible, "W3: releasing the drag hides the sell tag")
	# X3: the giver pill renders one [item icon + n/m] pair PER ASK (1-3), no second card
	var x3_3: Dictionary = ws._make_giver_stand(0, {"asks": [
		{"line": 1, "tier": 3, "count": 1}, {"line": 2, "tier": 4, "count": 1},
		{"line": 3, "tier": 3, "count": 1}], "stars": 3})
	ok(x3_3.asks.size() == 3, "X3: a 3-ask quest renders 3 item pairs in one pill")
	var x3_1: Dictionary = ws._make_giver_stand(1, {"asks": [{"line": 1, "tier": 2, "count": 1}], "stars": 1})
	ok(x3_1.asks.size() == 1, "X3: a single-ask quest renders 1 pair")
	x3_3.chip.queue_free()
	x3_1.chip.queue_free()
	Feat.FLAGS["ftue_staged_chrome"] = true
	ws.queue_free()

	# V1: a locked generator (compost = GENERATORS[1], line 3, appears_at 16)
	# previews once a line-3 edge bramble is revealed (adjacent to an open cell).
	fresh("v1")   # the W2 taps persist a board; start V1 from a guaranteed-clean save
	var gv = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(gv)
	if gv.board == null:
		gv._ready()
	await create_timer(0.05).timeout
	ok(not gv._gen_line_revealed(1), "V1: no preview while the compost line is unrevealed")
	gv.board.terrain[GroveBoard.idx(Vector2i(1, 3))] = 0   # open the neighbor of edge bramble (0,3)
	gv._rebuild_all()
	await create_timer(0.05).timeout
	ok(gv._gen_line_revealed(1), "V1: compost line reads revealed once its edge bramble is open-adjacent")
	ok(gv.gen_preview_cells.has(Vector2i(G.GENERATORS[1].cell)), "V1: the compost preview renders at its cell")
	gv.queue_free()

	# --- order Y: selling v2 — the diamond pinnacle + the porter's basket --------
	fresh("y")
	var Feat2 = load("res://engine/scripts/features.gd")
	Feat2.FLAGS["ftue_staged_chrome"] = false   # merchant + basket present on a fresh board
	Feat2.FLAGS["porter_collect"] = false        # test the MECHANICS, not the drift animation
	var ys = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(ys)
	if ys.board == null:
		ys._ready()
	await create_timer(0.05).timeout
	ys._rebuild_givers()
	await create_timer(0.05).timeout
	ok(ys.basket_chip != null, "Y2: the merchant has a collection basket")
	# Y1: a t8 sells for exactly 1💎 (no coins); a t5 for 5🪙
	var yt8 := 100 + G.TOP_TIER
	var yd0: int = Save.diamonds()
	var yc0: int = Save.coins()
	ys._grant_sale(yt8, null)
	ok(Save.diamonds() == yd0 + 1 and Save.coins() == yc0, "Y1: a t8 sells for exactly 1💎, no coins")
	ys._grant_sale(105, null)
	ok(Save.coins() == yc0 + 5, "Y1: a t5 sells for 5🪙")
	ok(ys.basket.size() == 2, "Y2: sales land in the basket")
	# Y2: buy back the t8 — EXACT refund (the 1💎 returns), item back on a free cell
	var yd1: int = Save.diamonds()
	var yopen0: int = ys.board.empty_ground_cells().size()
	ys._buy_back(0)
	ok(Save.diamonds() == yd1 - 1, "Y2: buy-back refunds EXACTLY the 1💎 granted (no arbitrage)")
	ok(ys.board.empty_ground_cells().size() == yopen0 - 1, "Y2: the bought-back item returns to a free cell")
	ok(ys.basket.size() == 1, "Y2: the sale leaves the basket on buy-back")
	# Y2: a FULL board blocks buy-back (wobble, no refund, sale kept)
	for yfc in ys.board.empty_ground_cells():
		ys.board.place(yfc, 101)
	var ycfull: int = Save.coins()
	ys._buy_back(0)
	ok(Save.coins() == ycfull and ys.basket.size() == 1, "Y2: full-board buy-back is blocked (no refund, sale kept)")
	# Y2/Y3: a 4th sale overflows cap-3 → the porter collects at once
	ys.basket.clear()
	ys._rebuild_basket()
	for yi4 in 4:
		ys._record_sale(105, Vector2i(5, 0))
	ok(ys.basket.is_empty(), "Y2/Y3: a 4th sale overflows cap-3 → the porter collects (basket emptied)")
	# Y3: the timer collects after ~3 min (buy-back window closes)
	ys._record_sale(105, Vector2i(5, 0))
	ok(ys.basket.size() == 1, "Y3: a sale arms the porter timer")
	ys._porter_tick(ys.PORTER_SECS + 1.0)
	ok(ys.basket.is_empty(), "Y3: the porter collects the basket after ~3 min")
	Feat2.FLAGS["ftue_staged_chrome"] = true
	Feat2.FLAGS["porter_collect"] = true
	ys.queue_free()
	# Y4 invariant: the water↔diamond round trip loses >=10x — never a water pump
	ok(G.water_to_earn_diamond() >= 10 * G.water_a_diamond_buys(), \
		"Y4: water to EARN 1💎 (%d) >= 10x the water 1💎 BUYS (%d)" % [G.water_to_earn_diamond(), G.water_a_diamond_buys()])

	# --- order Z: the coin sink — wayside decorations -----------------------------
	var zways := G.waysides()
	ok(zways.size() == 20, "Z1: 20 wayside plots (4 per zone × 5)")
	var zcoin_ok := true
	var zgate_ok := true
	var z_spot_ids := {}
	for zz in G.ZONES.size():
		for zsp in G.ZONES[zz].spots:
			z_spot_ids[String(zsp.id)] = true
	for w in zways:
		if int(w.cost) <= 0:
			zcoin_ok = false
		if int(w.zone_req) < 0 or int(w.zone_req) >= G.ZONES.size() or z_spot_ids.has(String(w.id)):
			zgate_ok = false
	ok(zcoin_ok, "Z1: every wayside is coin-priced (cost > 0)")
	ok(zgate_ok, "Z4: no wayside gates progression (distinct from spots, valid zone_req)")
	ok(G.wayside_sink_capacity() >= 1500 and G.wayside_sink_capacity() <= 2200, \
		"Z4: the wayside sink (%d🪙) is ~1.5–2k — absorbs the lifetime faucet" % G.wayside_sink_capacity())
	# Z2 buy logic: a wayside is dormant until its zone is restored, then coin-buyable, one-time
	fresh("z")
	var Feat3 = load("res://engine/scripts/features.gd")
	Feat3.FLAGS["ftue_staged_chrome"] = false
	var zs = load("res://engine/scenes/Home.tscn").instantiate()
	get_root().add_child(zs)
	if zs.vista == null:
		zs._ready()
	await create_timer(0.05).timeout
	var zw0: Dictionary = G.waysides()[0]            # zone_req 0
	ok(not G.wayside_available(zw0, zs.unlocks), "Z2: a wayside is dormant until its zone is restored")
	ok(not zs.buy_wayside(zw0), "Z2: can't buy a dormant wayside")
	for zsp in G.ZONES[0].spots:
		zs.unlocks[String(zsp.id)] = true            # restore zone 0
	ok(G.wayside_available(zw0, zs.unlocks), "Z2: the wayside opens once its zone is restored")
	ok(not zs.buy_wayside(zw0), "Z2: can't buy without coins (fresh = 0)")
	Save.add_coins(int(zw0.cost) + 50)
	var zc0: int = Save.coins()
	ok(zs.buy_wayside(zw0), "Z2: buy succeeds once available + affordable")
	ok(Save.coins() == zc0 - int(zw0.cost), "Z2: buying spends EXACTLY the coin cost")
	ok(zs.wayside_owned(String(zw0.id)), "Z2: the wayside is now owned")
	ok(not zs.buy_wayside(zw0), "Z2: a wayside is one-time (no re-buy)")
	# Z2 (T14): the TAP TARGET must cover the price PIN, not just the sprite. The
	# "🌰N" chip hangs below the holder; if the hit-test is only the holder, tapping
	# the visible price affordance misses and the plot reads as un-clickable.
	Save.add_coins(300)
	zs._build_vista()                                # rebuild so way_0_1 shows its pin
	await create_timer(0.05).timeout
	var zw1_node: Control = null
	for zhit in zs.wayside_hits:
		if String(zhit.w.id) == "way_0_1":
			zw1_node = zhit.node
	ok(zw1_node != null, "Z2: way_0_1 (an available plot) is on the map")
	var zw1_pin: Control = null
	for zch in zw1_node.get_children():
		if zch is PanelContainer:
			zw1_pin = zch
	ok(zw1_pin != null, "Z2: an available plot shows a price pin")
	# the pin sits (partly) OUTSIDE the holder — exactly the tap that fails today
	var zpin_c: Vector2 = zw1_pin.get_global_rect().get_center()
	ok(not zw1_node.get_global_rect().has_point(zpin_c),
		"Z2: (regression witness) the price pin's center is outside the bare holder rect")
	ok(not zs.wayside_owned("way_0_1"), "Z2: way_0_1 unowned before the pin tap")
	zs._on_map_tap(zpin_c)                            # tap the PRICE PIN, as a player would
	ok(zs.wayside_owned("way_0_1"),
		"Z2: tapping the PRICE PIN buys the plot (tap target covers the pin)")
	Feat3.FLAGS["ftue_staged_chrome"] = true
	zs.queue_free()

	# Z3: spirit treats — a 10🪙 recurring sink. Spend deducts exactly, rapid-buy is
	# independent (graceful), and you can't overspend.
	fresh("z3")
	Feat3.FLAGS["spirit_treats"] = true
	var z3 = load("res://engine/scenes/Grove.tscn").instantiate()
	get_root().add_child(z3)
	if z3.board == null:
		z3._ready()
	await create_timer(0.05).timeout
	Save.add_coins(40)
	var z3c0: int = Save.coins()
	z3._buy_treat()
	ok(Save.coins() == z3c0 - z3.TREAT_COST, "Z3: a treat costs exactly 10🪙")
	z3._buy_treat()
	z3._buy_treat()
	ok(Save.coins() == z3c0 - 3 * z3.TREAT_COST, "Z3: rapid treats each deduct independently (graceful)")
	Save.spend(Save.coins())                 # drain to 0
	z3._buy_treat()
	ok(Save.coins() == 0, "Z3: no treat without coins (no overspend)")
	z3.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
