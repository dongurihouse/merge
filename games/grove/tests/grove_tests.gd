extends SceneTree
## Headless tests for the Grove P1 core: board model, content sanity, dispenser
## policy, chapter gate math, persistence.
##   godot --headless --path . -s res://games/grove/tests/grove_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const Save = preload("res://engine/scripts/core/save.gd")

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

# A still-tap (press+release, no drift) straight into the map's single input
# surface (content.gui_input → _on_input). `at` is a global point; content is a
# full-rect Control at the origin, so gui_input positions equal globals.
func _map_tap_at(h, at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	h._on_input(down)
	var up := down.duplicate()
	up.pressed = false
	h._on_input(up)

# The global-rect center of a hit node (spot/card) — where a player would tap.
func _hit_center(node: Control) -> Vector2:
	return node.get_global_rect().get_center()

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
	var b: BoardModel = BoardModel.new()
	ok(b.is_open(G.GEN_CELL) and b.item_at(G.GEN_CELL) == 0, "generator cell open and empty")
	ok(b.is_open(Vector2i(3, 2)) and b.is_open(Vector2i(5, 4)), "center 3x3 starts open")
	ok(b.is_bramble(Vector2i(0, 0)) and b.is_bramble(Vector2i(8, 6)), "edges start brambled")
	ok(b.terrain[BoardModel.idx(Vector2i(4, 1))] == 2, "first frontier opens on ANY merge (req t2)")
	ok(b.terrain[BoardModel.idx(Vector2i(3, 1))] == 2, "ring 2 stays any-line req t2")
	ok(b.terrain[BoardModel.idx(Vector2i(1, 3))] == 4, "ring 3 needs a produced t4 (any line)")
	# the screen edge is END GAME: t5 of the LATE lines (top=mushroom, bottom=honey)
	ok(BoardModel.gate_line_of(b.terrain[BoardModel.idx(Vector2i(0, 0))]) == 3 \
		and BoardModel.gate_req_of(b.terrain[BoardModel.idx(Vector2i(0, 0))]) == 5, \
		"top edge wants mushroom t5 (the compost's line)")
	ok(BoardModel.gate_line_of(b.terrain[BoardModel.idx(Vector2i(8, 6))]) == 4 \
		and BoardModel.gate_req_of(b.terrain[BoardModel.idx(Vector2i(8, 6))]) == 5, \
		"bottom edge wants honey t5 (the beehive's line)")
	ok(BoardModel.line_of(G.bramble_contents(Vector2i(0, 0))) == 3, \
		"a gated bramble's contents seed its own line")
	# legacy saves stored the bare tier: value 3 still decodes as any-line req t3
	ok(BoardModel.gate_line_of(3) == 0 and BoardModel.gate_req_of(3) == 3, \
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
	var bgate: BoardModel = BoardModel.new()
	for rr in range(1, 4):
		bgate.terrain[BoardModel.idx(Vector2i(rr, 0))] = 0    # carve a lane to the corner
	bgate.place(Vector2i(1, 0), 105)
	ok(not bgate.openable_brambles(Vector2i(1, 0), 105).has(Vector2i(0, 0)), \
		"flower t5 can NOT open the mushroom-gated top edge")
	ok(bgate.openable_brambles(Vector2i(1, 0), 305).has(Vector2i(0, 0)), \
		"mushroom t5 opens the top edge gate")

	# 4. pigeonhole helper
	ok(b.any_pair_exists() == false or b.any_pair_exists(), "pair query runs")
	var b2: BoardModel = BoardModel.new()
	ok(b2.any_pair_exists(), "fresh board has mergeable pairs")

	# 5. persistence roundtrip
	var d := b.to_dict()
	var b3: BoardModel = BoardModel.new()
	b3.from_dict(d)
	ok(Array(b3.items) == Array(b.items) and Array(b3.terrain) == Array(b.terrain), \
		"board roundtrips through to_dict/from_dict")

	# 6. The §7 GENERATED-quest model — asks, the capped stars+coins reward, the metered fence,
	# and the gate quest — is covered by quest_tests (engine) + the gate/grant/delivery tests
	# above. The old deterministic per-chapter ramp + its byte-for-byte affordability proof are
	# RETIRED (chapters()/ZONE_RAMP/_quest_stars gone); the no-strand guarantee now rests on the
	# guardrails (every ask producible) + the Monte-Carlo sim (games/grove/tools/grove_sim.gd).

	# 6c. generators arrive PER ZONE (§6). Zone 0 grants both starters (satchel + compost);
	# the surplus generator's cell (6,5) reveals only when the player enters zone 1.
	var z1_chapter := G.ZONES[0].spots.size()      # first chapter of zone 1 (all zone-0 spots bought)
	var bg: BoardModel = BoardModel.new()
	bg.set_active_gens(0)
	ok(bg.is_gen(Vector2i(4, 3)) and bg.is_gen(Vector2i(2, 1)), "zone 0 grants both starters (satchel + compost)")
	ok(not bg.is_gen(Vector2i(6, 5)), "the zone-1 surplus generator waits for its own zone")
	# 6d. entering zone 1 reveals the surplus generator at (6,5) — and an item caught on
	# that cell hops away safely (never destroyed).
	var bh: BoardModel = BoardModel.new()
	bh.set_active_gens(0)
	bh.terrain[BoardModel.idx(Vector2i(6, 5))] = 0
	bh.place(Vector2i(6, 5), 204)              # a player item parked on the future generator cell
	var before_count := 0
	for v in bh.items:
		if v == 204:
			before_count += 1
	var fresh_hive: Array = bh.set_active_gens(z1_chapter)
	ok(fresh_hive.has(Vector2i(6, 5)) and bh.is_gen(Vector2i(6, 5)), "entering zone 1 reveals the surplus generator")
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
	var scn = load("res://engine/scenes/Board.tscn").instantiate()
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
	ok(items_after >= items_before + 1, "the satchel pops a burst (≥1 item) onto the board")

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
	var dq: Dictionary = scn.quests[qi]
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
	var dlv_coins_before := Save.coins()
	var n_before: int = scn.quests.size()
	scn._on_giver_tap(qi, scn.giver_chips[0].chip)
	ok(Save.stars() > stars_before, "§7: delivery pays stars (all asks satisfied)")
	ok(Save.coins() >= dlv_coins_before, "§7: delivery pays any coin overflow (the quest coin faucet)")
	ok(scn.quests.size() <= n_before, "§7: the delivered quest leaves the live fence")

	# §7 soft gate: the fence is METERED to the next unlock — with enough banked stars + level
	# the next spot is affordable, so the fence EMPTIES (the wordless "go restore" signal).
	var gg := Save.grove()
	gg["stars_earned"] = 300
	Save.grove_write()
	Save.add_stars(300)
	scn._rebuild_givers()
	scn._update_hud()
	ok(scn._gate_ready(), "§7: the next unlock is affordable (gate ready)")
	ok(scn.quests.is_empty(), "§7: the metered fence empties once the next unlock is affordable")
	ok(scn.gate_btn.visible, "§7: the restore CTA appears when affordable")
	# the CTA's reserved slot never covers a giver/merchant pill (any population)
	var aa_gate: Rect2 = scn.gate_btn.get_global_rect()
	var aa_clear := true
	for e in scn.giver_chips:
		if aa_gate.intersects((e.chip as Control).get_global_rect()):
			aa_clear = false
	if scn.merchant_chip != null and is_instance_valid(scn.merchant_chip):
		if aa_gate.intersects(scn.merchant_chip.get_global_rect()):
			aa_clear = false
	ok(aa_clear, "the restore CTA's reserved slot covers no giver/merchant")
	# buying a home spot advances the board's progress: it derives from unlocks
	var ch_before: int = scn._chapter_idx()
	var gu := Save.grove()
	var first_spot: String = G.ZONES[0].spots[0].id
	gu["unlocks"] = {first_spot: true}
	Save.grove_write()
	ok(scn._chapter_idx() == ch_before + 1, "a home purchase advances the board's progress (unlocks)")

	# persistence: a fresh scene resumes the same board + progress
	var snapshot := Array(scn.board.items)
	var scn2 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(scn2)
	if scn2.board == null:
		scn2._ready()
	ok(Array(scn2.board.items) == snapshot and scn2._chapter_idx() == scn._chapter_idx(), \
		"a fresh scene resumes the persisted board and progress")

	# 10g. §7 GATE quest: restoring all of map 1's spots unveils the great-spirit's gate on the
	# fence; delivering its top-tier asks records the gate, grants the next map's generators, and
	# opens map 2 (the completion chain). All engine-side; the grove only supplies the tunables.
	fresh("gatequest")
	var sg = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sg)
	if sg.board == null:
		sg._ready()
	var sgg := Save.grove()
	sgg["stars_earned"] = 300                 # level past map 1's spot gates
	var gate_ul := {}
	for sp in G.ZONES[0].spots:
		gate_ul[String(sp.id)] = true         # all of map 1 spot-restored
	sgg["unlocks"] = gate_ul
	sgg["gates"] = []
	Save.grove_write()
	sg._init_quests()
	sg._rebuild_givers()
	ok(sg.quests.size() == 1 and bool(sg.quests[0].get("gate", false)), "§7: a fully-restored map shows the lone gate quest")
	var gateq: Dictionary = sg.quests[0]
	for ci in sg.board.items.size():
		if sg.board.items[ci] > 0 and not G.is_coin(sg.board.items[ci]):
			sg.board.items[ci] = 0
	var gemp: Array = sg.board.empty_ground_cells()
	var gix := 0
	for ask in G.quest_asks(gateq):
		var gcode: int = int(ask.line) * 100 + int(ask.tier)
		for _n in int(ask.count):
			if gix < gemp.size():
				sg.board.place(gemp[gix], gcode)
				gix += 1
	sg._rebuild_pieces()
	var gate_stars_b := Save.stars()
	sg._on_giver_tap(0, sg.giver_chips[0].chip)
	ok(Save.grove().get("gates", []).has(0), "§7: delivering the gate records it for map 1")
	ok(G.zone_unlocked(1, Save.grove().get("unlocks", {}), Save.grove().get("gates", [])), "§7: map 2 unlocks once the gate is delivered")
	ok(Save.stars() > gate_stars_b, "§7: the gate pays its large authored reward")
	ok(sg.board.gen_id_at(Vector2i(6, 5)) == "dairy_stall", "§7: the next map's SURPLUS generator appears outright (dairy stall)")
	ok(sg.board.gen_id_at(Vector2i(4, 3)) == "seed_satchel" and sg.board.gen_id_at(Vector2i(2, 1)) == "pantry_crock", "§7: the anchor satchel stays; the pantry crock waits to be handed in")
	# the new map opens with its generator-grant hand-in(s) on the fence (§6)
	var grant_qi := -1
	for gqi in sg.quests.size():
		if sg.quests[gqi].has("grant") and String(sg.quests[gqi].grant.grants) == "hen_coop":
			grant_qi = gqi
	ok(grant_qi >= 0, "§7: the new map opens with the hen coop's grant quest (hand in the pantry crock)")
	sg._on_giver_tap(grant_qi, sg.giver_chips[grant_qi].chip)
	ok(sg.board.gen_id_at(Vector2i(2, 1)) == "hen_coop", "§7: handing the pantry crock in installs the hen coop — the new line goes live")
	sg.queue_free()

	# 11. P2 — water economy + coins
	fresh("p2")
	var s2 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s2)
	if s2.board == null:
		s2._ready()
	ok(s2.water == G.WATER_CAP, "fresh grove starts at the water cap")
	Save.grove()["pops"] = 10                 # past the FTUE free pops (tested in P5)
	var w0: int = s2.water
	var pop_items_b := 0
	for v in s2.board.items:
		if v > 0:
			pop_items_b += 1
	s2._pop_seed()
	await create_timer(0.3).timeout
	var pop_burst := -pop_items_b
	for v in s2.board.items:
		if v > 0:
			pop_burst += 1
	ok(pop_burst >= 1, "a tap pops a burst of at least one item")
	ok(s2.water == w0 - pop_burst * G.POP_COST, "each item in the burst costs one energy")

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

	# the burst pops above may have filled the virgin board — clear the playfield so the coin lands
	for ci in s2.board.items.size():
		if s2.board.items[ci] > 0 and not G.is_coin(s2.board.items[ci]):
			s2.board.items[ci] = 0
	s2._rebuild_pieces()

	# coins: drop → tap-collect → wallet
	var coins0 := Save.coins()
	s2._drop_coin_near(Vector2i(4, 3))
	await create_timer(0.3).timeout
	var coin_cell := Vector2i(-1, -1)
	for i in s2.board.items.size():
		if s2.board.items[i] > 0 and G.is_coin(s2.board.items[i]):
			coin_cell = BoardModel.cell_of(i)
			break
	ok(coin_cell != Vector2i(-1, -1), "a coin dropped onto the board")
	var chalf: Vector2 = Vector2(s2.csz, s2.csz) / 2.0
	s2._on_press(s2._cell_pos(coin_cell) + chalf)
	s2._on_release(s2._cell_pos(coin_cell) + chalf)
	ok(Save.coins() == coins0 + 1, "tapping a coin pockets its value")
	ok(s2.board.item_at(coin_cell) == 0, "the collected coin left the board")

	# coin merge rules (model): c1+c1 merges, c3 is capped
	var bc: BoardModel = BoardModel.new()
	bc.place(Vector2i(3, 2), 901)
	bc.place(Vector2i(3, 4), 901)
	ok(bc.can_merge(Vector2i(3, 2), Vector2i(3, 4)), "coins merge with coins")
	bc.place(Vector2i(5, 2), 903)
	bc.place(Vector2i(5, 4), 903)
	ok(not bc.can_merge(Vector2i(5, 2), Vector2i(5, 4)), "top coin (25) never merges")
	ok(bc.top_tier_cells().is_empty(), "coins are never merchant goods")

	# 11b. BURST-POP (§6) + the burst-upgrade COIN SINK — both engine-side; the grove only sets the
	# odds/scale/cost dials. One tap throws a burst that scales with the map + the paid upgrade, each
	# item costing one energy. The upgrade spends coins, raises the burst, persists, and caps.
	fresh("burst")
	var sbp = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbp)
	if sbp.board == null:
		sbp._ready()
	Save.grove()["pops"] = 50                 # well past the FTUE — the energy meter is on
	ok(sbp._gen_burst_level() == 0, "the burst-upgrade starts at level 0")
	Save.add_coins(10000)
	var bu_c0 := Save.coins()
	ok(sbp._upgrade_gen_burst(), "the burst-upgrade buys with coins")
	ok(Save.coins() == bu_c0 - G.burst_upgrade_cost(0), "the burst-upgrade spends coins (the sink)")
	ok(sbp._gen_burst_level() == 1, "the burst-upgrade raises the burst level")
	ok(sbp._upgrade_gen_burst() and sbp._gen_burst_level() == 2, "a second burst-upgrade stacks")
	# clear a wide-open area so the burst is bounded only by its own size (not by board space)
	for ci in sbp.board.items.size():
		if sbp.board.items[ci] > 0 and not G.is_coin(sbp.board.items[ci]):
			sbp.board.items[ci] = 0
	sbp._rebuild_pieces()
	sbp.water = G.WATER_CAP
	var bw0: int = sbp.water
	var bb := 0
	for v in sbp.board.items:
		if v > 0:
			bb += 1
	sbp._pop_seed()
	await create_timer(0.3).timeout
	var burst_got := -bb
	for v in sbp.board.items:
		if v > 0:
			burst_got += 1
	ok(burst_got >= 3, "with the upgrade a single tap throws a burst of ≥3 items (map 1, level 2)")
	ok(sbp.water == bw0 - burst_got * G.POP_COST, "each burst item costs one energy")
	# the sink caps: drive to the max level, then the upgrade refuses
	while sbp._gen_burst_level() < G.burst_upgrade_max():
		sbp._upgrade_gen_burst()
	ok(not sbp._upgrade_gen_burst(), "the burst-upgrade caps — no buy past the max level")
	# the burst level rides the save
	var saved_lvl: int = sbp._gen_burst_level()
	var sbp2 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbp2)
	if sbp2.board == null:
		sbp2._ready()
	ok(sbp2._gen_burst_level() == saved_lvl, "the burst-upgrade level persists across scenes")
	sbp.queue_free()
	sbp2.queue_free()

	# 12. win-back: away 3 days with low water → full cap on return
	fresh("winback")
	var gw := Save.grove()
	gw["board"] = BoardModel.new().to_dict()
	gw["water"] = 10
	gw["regen_ts"] = Time.get_unix_time_from_system() - 3 * 86400.0
	gw["last_seen"] = Time.get_unix_time_from_system() - 3 * 86400.0
	Save.grove_write()
	var s3 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s3)
	if s3.board == null:
		s3._ready()
	ok(s3.water == G.WATER_CAP, "returning after days away finds full water")

	# 12b. a cold load mid-game draws EVERY live generator of the CURRENT zone (§6), not just
	# one — completing maps 1+2 puts the player in map 3/Pond (2 generators: reed bed + creel;
	# the anchor satchel's cold-load persistence is the parked engine follow-up, BACKLOG).
	fresh("twogens")
	var gtg := Save.grove()
	var ul16 := {}
	for z in 2:
		for sp in G.ZONES[z].spots:
			ul16[String(sp.id)] = true
	gtg["unlocks"] = ul16
	Save.grove_write()
	var s4 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s4)
	if s4.board == null:
		s4._ready()
	ok(s4.gen_nodes.size() == 2, "a cold load in map 3/Pond draws both of the map's generators (reed bed + creel)")
	ok(s4.gen_node != null and s4.gen_nodes.values().has(s4.gen_node), "gen_node points at a live generator (not the stale index-0 satchel)")

	# 12c. generators are MOVABLE (#1) and arrive by GRANT HAND-IN (#2) on the live board,
	# and the scene re-renders both (§6). A fresh board is map 1: seed satchel (4,3) + pantry crock (2,1).
	fresh("genmech")
	var s4c = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s4c)
	if s4c.board == null:
		s4c._ready()
	ok(s4c.board.gen_id_at(Vector2i(4, 3)) == "seed_satchel" and s4c.board.gen_id_at(Vector2i(2, 1)) == "pantry_crock", "12c: a fresh board seeds the zone-0 generators")
	s4c.board.items[BoardModel.idx(Vector2i(4, 4))] = 0       # clear the destination
	ok(s4c.board.move_gen(Vector2i(4, 3), Vector2i(4, 4)), "12c: the satchel moves to an empty cell (#1)")
	s4c._rebuild_all()
	ok(s4c.gen_nodes.has(Vector2i(4, 4)) and not s4c.gen_nodes.has(Vector2i(4, 3)), "12c: the moved generator re-renders at its new cell")
	ok(s4c.board.grant_gen("hen_coop"), "12c: a generator-grant quest hands the pantry crock in for the hen coop (#2)")
	s4c._rebuild_all()
	ok(s4c.board.gen_id_at(Vector2i(2, 1)) == "hen_coop" and s4c.board.gen_id_at(Vector2i(4, 4)) == "seed_satchel" and s4c.board.gens.size() == 2, "12c: granted — hen coop at the crock's cell; the moved anchor satchel untouched")
	ok(s4c.gen_nodes.has(Vector2i(2, 1)) and s4c.gen_nodes.has(Vector2i(4, 4)), "12c: the re-render reflects the grant + the moved anchor")
	s4c.queue_free()

	# 12b2. a runtime-opened cell's ground tile sits ABOVE the mat (owner's
	# "no border" bug: move_child(slot, 0) hid the tile behind the moss)
	fresh("opentile")
	var s4b = load("res://engine/scenes/Board.tscn").instantiate()
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

	# 12d. §7: the fence is METERED to the next unlock — it seats exactly active_giver_count
	# stands (shrinking as stars bank, capped at MAX_GIVERS), not a fixed pool.
	var s3_nxt: int = G.cheapest_spot_cost(Save.grove().get("unlocks", {}), G.level_for_stars(int(Save.grove().get("stars_earned", 0))))
	ok(s3.giver_chips.size() == G.active_giver_count(Save.stars(), s3_nxt), "§7: the fence seats exactly the metered giver count (%d shown)" % s3.giver_chips.size())
	ok(s3.giver_chips.size() <= int(G.MAX_GIVERS), "§7: the fence never exceeds MAX_GIVERS stands")

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
	# 13c. the stars-driven level clock (one uncapped Level, driven by stars EARNED)
	ok(G.level_for_stars(0) == 1 and G.level_for_stars(5) == 1 and G.level_for_stars(6) == 2, \
		"level_for_stars maps cumulative-earned thresholds")
	ok(G.level_for_stars(126) == 10, "L10 lands at 126 earned stars (= the old L10 exp/10)")
	ok(G.level_for_stars(126 + G.LEVEL_STARS_TAIL) == 11 and G.level_for_stars(100000) > 50, \
		"the level clock is UNCAPPED — a flat tail past the table")
	ok(G.stars_at_level(1) == 0 and G.stars_at_level(2) == 6 and G.stars_at_level(10) == 126 \
		and G.stars_at_level(11) == 126 + G.LEVEL_STARS_TAIL, "stars_at_level inverts the curve")
	# earn_stars bumps the spendable balance AND the earned clock; a level-up gifts water+gems
	fresh("earn")
	var ge := Save.grove()
	ge["stars_earned"] = 5
	ge["water"] = 10
	var gained := G.earn_stars(2)              # 5 -> 7 crosses the L2 line (6)
	ok(gained == 1, "earn_stars returns the number of levels gained")
	ok(int(Save.grove()["stars_earned"]) == 7 and Save.stars() == 2, \
		"earn_stars accrues BOTH the earned clock and the spendable balance")
	ok(int(Save.grove()["water"]) == 10 + G.LEVEL_WATER_GIFT and Save.diamonds() == G.LEVEL_DIAMONDS, \
		"a level-up gifts water + diamonds, once per level")
	ok(G.earn_stars(1) == 0, "earning within a level gains no level (no extra gift)")

	# 14. P3 — the HOME scene (NEW map model): a map IS one image with restoration
	# SPOTS placed on it; discrete maps via the map-select. boot → buy → gate → resume.
	fresh("home")
	var h = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h)
	if h.content == null:
		h._ready()
	await create_timer(0.05).timeout
	# boot lands ON a map: the frontier (fresh save → the hub, map 0), every spot live
	ok(h._view == "map" and h._map_idx == G.hub_zone(), "boot opens the frontier map (fresh → the hub)")
	ok(h.content != null, "the single input surface exists")
	ok(h.spot_hits.size() == G.ZONES[h._map_idx].spots.size(), "the open map seats every spot as a hit")
	# the single-input-surface rule (3rd input-swallow bug): EVERY descendant of
	# content IGNOREs the mouse — only content's gui_input resolves taps
	ok(_all_ignore(h.content), "every content descendant IGNOREs mouse (single input surface)")
	ok(h.zone_unlocked(0) and not h.zone_unlocked(1), "farmhouse open, barn locked, on a fresh save")

	# a spot BUY, driven through the REAL spot node: give stars, tap an
	# affordable + level-ok spot (k=0 fh_hearth, L1, 3★) → owned, stars debited,
	# the view stays a map (no takeover/scene change).
	Save.add_stars(100)
	# level gates derive from rank: k=0 is L1 (buyable now), k=2 wants L2 (greyed)
	ok(G.spot_level_req(0, 0) == 1 and G.spot_level_req(0, 2) == 2, "spot gates derive from rank")
	var stars0 := Save.stars()
	var locked_node: Control = h.spot_hits[2].node
	h._on_spot_tap(0, 2, locked_node, _hit_center(locked_node))
	ok(not h.spot_owned(String(G.ZONES[0].spots[2].id)) and Save.stars() == stars0, \
		"a level-locked spot refuses the purchase (greyed, no stars move)")
	var hearth_id: String = G.ZONES[0].spots[0].id
	var buy_node: Control = h.spot_hits[0].node
	h._on_spot_tap(0, 0, buy_node, _hit_center(buy_node))
	ok(h.spot_owned(hearth_id), "buying a spot records the unlock")
	ok(Save.stars() == stars0 - int(G.ZONES[0].spots[0].cost), "the spot's stars were spent")
	ok(G.level_for_stars(int(Save.grove().get("stars_earned", 0))) == 1, \
		"buying a spot does NOT raise Level (Level rides stars EARNED, not spent)")
	ok(h._view == "map", "the view stays a map across a purchase (no takeover)")

	# the customize strip: opening the inline variant strip on an OWNED spot keeps
	# the single-input-surface rule and stays in map view (no modal, no veil)
	h._customize_spot = hearth_id
	h._build_map()
	ok(h.variant_hits.size() == 3, "the owned spot's inline strip exposes all 3 variants as chips")
	ok(_all_ignore(h.content), "the strip keeps the single-input-surface rule")
	ok(h._view == "map", "customizing keeps you on the map")
	h._customize_spot = ""
	h._build_map()

	# the MAP-SELECT view: every map is a card. an UNLOCKED card opens that map; a
	# LOCKED card stays put (wobble). drive taps through the real input surface.
	h._open_select()
	ok(h._view == "select", "the atlas button opens the map-select view")
	ok(h.select_hits.size() == G.ZONES.size(), "the select view seats one card per map")
	ok(_all_ignore(h.content), "every select descendant IGNOREs mouse (single input surface)")
	await create_timer(0.05).timeout
	# tapping the LOCKED barn card (z=1) does nothing — still in select
	var locked_card: Control = null
	for hit in h.select_hits:
		if int(hit.z) == 1:
			locked_card = hit.node
	_map_tap_at(h, _hit_center(locked_card))
	ok(h._view == "select", "tapping a LOCKED map card stays in the select view")
	# tapping the UNLOCKED farmhouse card (z=0) opens that map
	var open_card: Control = null
	for hit in h.select_hits:
		if int(hit.z) == 0:
			open_card = hit.node
	_map_tap_at(h, _hit_center(open_card))
	ok(h._view == "map" and h._map_idx == 0, "tapping an UNLOCKED map card opens that map")

	# the completion chain: spot-restoring map 0 does NOT open map 1 — its gate
	# quest must land first. buy all of map 0 (earn past its L-gates), then inject
	# gates=[0] (gate delivery really happens on the board; here we simulate it).
	Save.grove()["stars_earned"] = G.stars_at_level(3)   # clear the farmhouse's L-gates
	for i in G.ZONES[0].spots.size():
		var sid: String = G.ZONES[0].spots[i].id
		if not h.spot_owned(sid):
			h._on_spot_tap(0, i, h.spot_hits[i].node, _hit_center(h.spot_hits[i].node))
	ok(h.zone_complete(0), "all farmhouse spots restored")
	ok(not h.zone_unlocked(1), "§7: spot-completing a map does NOT open the next — its gate quest must land first")
	var gg2 := Save.grove()
	var gt2: Array = gg2.get("gates", [])
	gt2.append(0)                             # the great-spirit's gate, delivered
	gg2["gates"] = gt2
	Save.grove_write()
	ok(h.zone_unlocked(1), "§7: delivering the map's gate opens the next (the completion chain)")
	h._persist()

	# 14a2. customization values: each owned spot offers a coin + a diamond look, and
	# a chosen variant persists + resolves; applying it pays and stays on the map.
	var vars0: Array = G.spot_variants(0, 0)
	ok(vars0.size() == 3 and String(vars0[1].currency) == "coins" and String(vars0[2].currency) == "diamonds" \
		and int(vars0[1].cost) > 0 and int(vars0[2].cost) > 0, "each spot offers a coin and a diamond variant")
	Save.grove()["custom"] = {hearth_id: "gem"}
	ok(String(h._spot_variant(0, 0).id) == "gem", "the chosen variant persists and resolves")
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
	ok(h._view == "map", "customizing keeps you on the map")

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

	# 14b. §7: buying a spot grants NO per-spot water — the old per-chapter gift is retired
	# (water comes from level-ups only), so the purchase leaves water unchanged.
	var gw2 := Save.grove()
	var ul24 := {}
	for z4 in 3:                             # maps 1-3 (zones 0-2) fully spot-restored
		for sp in G.ZONES[z4].spots:
			ul24[String(sp.id)] = true
	gw2["unlocks"] = ul24
	h.unlocks = ul24
	gw2["water"] = 50
	gw2["stars_earned"] = 200                # high Level clears the orchard gates
	gw2["gates"] = [0, 1, 2]                  # §7: maps 1-3 gated through → zone 4 spots are buyable
	Save.add_stars(10)
	h._on_spot_tap(3, 0, Button.new(), Vector2(300, 300))
	ok(int(Save.grove().get("water", 0)) == 50, "§7: a home purchase grants no per-spot water (water is level-ups only)")

	# 14c. the pigeonhole proof in motion: worst-case cheapest-first buying is
	# NEVER stranded by a level gate, all the way to the end of the map
	var sim_ul := {}
	var sim_earned := 0
	var strand := false
	var all_spots := 0
	for zc in G.ZONES.size():
		all_spots += G.ZONES[zc].spots.size()
	while sim_ul.size() < all_spots:
		var lvl_now := G.level_for_stars(sim_earned)
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
		sim_earned += pick_cost                  # worst case: earn exactly what you spend
	ok(not strand, "level gates never strand the map (worst-case order, earn==spend, all 40 spots)")

	# a fresh Home resumes the same progress
	var h2 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h2)
	if h2.content == null:
		h2._ready()
	ok(h2.zone_complete(0), "home progress persists across scenes")

	# 15. P5 — sell anything, diamonds, FTUE staging
	fresh("p5")
	var s5 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s5)
	if s5.board == null:
		s5._ready()
	# FTUE: the intro pops are free; once they're spent the meter begins. A tap now throws a
	# BURST (1-3 items), so drive the boundary by the pop count and assert the charge tracks the
	# burst size — each popped item is one energy. Clear a few cells for the burst to fill.
	for cc in [Vector2i(3, 2), Vector2i(3, 4), Vector2i(3, 3), Vector2i(4, 2), Vector2i(2, 2)]:
		s5.board.take(cc)
	s5._rebuild_pieces()
	Save.grove()["pops"] = 0
	s5.water = G.WATER_CAP
	s5._pop_seed()                            # an intro pop — still free
	await create_timer(0.25).timeout
	ok(s5.water == G.WATER_CAP, "the FTUE intro pops are free (the verb before the meter)")
	Save.grove()["pops"] = 20                 # well past the 10 free intro pops → the meter is on
	s5.water = G.WATER_CAP
	var ftue_b := 0
	for v in s5.board.items:
		if v > 0:
			ftue_b += 1
	s5._pop_seed()
	await create_timer(0.25).timeout
	var ftue_n := -ftue_b
	for v in s5.board.items:
		if v > 0:
			ftue_n += 1
	ok(ftue_n >= 1 and s5.water == G.WATER_CAP - ftue_n * G.POP_COST, "past the FTUE the meter charges one energy per burst item")
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
	var h5 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h5)
	if h5.content == null:
		h5._ready()
	var d0 := Save.diamonds()
	Save.grove()["stars_earned"] = G.stars_at_level(2) - 1     # one star short of L2
	G.earn_stars(1)                                            # crosses into L2
	ok(Save.diamonds() == d0 + G.LEVEL_DIAMONDS, "a level-up pays diamonds")

	# 16. the discovery log + the upgrade-path card (tap an item → its ladder;
	# unseen tiers stay "?")
	fresh("ladder")
	var s6 = load("res://engine/scenes/Board.tscn").instantiate()
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
	var Shop = load("res://engine/scripts/ui/shop.gd")
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
	var s7 = load("res://engine/scenes/Board.tscn").instantiate()
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
	var h7 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h7)
	if h7.content == null:
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
	var Ambient = load("res://engine/scripts/ui/ambient.gd")
	ok(G.completed_zones({}) == 0, "no zones done on a fresh save")
	var full0 := {}
	for sp0 in G.ZONES[0].spots:
		full0[String(sp0.id)] = true
	ok(G.completed_zones(full0) == 1 and G.character_count(full0) == 2, \
		"character count = 1 + completed zones")
	var alayer: Control = Ambient.build_layer(Vector2(1000, 1000), G.character_count(full0))
	ok(alayer.get_child_count() == 2, "the layer carries that many characters")
	ok(_all_ignore(alayer), "spirits never eat input")
	alayer.free()
	var ga := Save.grove()
	ga["winback_until"] = Time.get_unix_time_from_system() + 60.0
	ok(Ambient.weather_now(false) == "rain", "the win-back minute rains")
	ok(Ambient.weather_now(true) == "breeze", "calm mode WINS: breeze, never rain")
	Ambient.forced_weather = "snow"
	ok(Ambient.weather_now(true) == "snow", "shot tools can force a state")
	Ambient.forced_weather = ""
	var h8 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h8)
	if h8.content == null:
		h8._ready()
	ok(h8.content.get_node_or_null("AmbientLayer") != null, "the map carries the spirit layer")
	ok(h8.get_node_or_null("WeatherLayer") != null, "the map carries the weather layer")
	ok(_all_ignore(h8.content), "the map guard stays green with spirits wandering")
	var s8 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s8)
	if s8.board == null:
		s8._ready()
	ok(s8.get_node_or_null("AmbientLayer") != null and s8.get_node_or_null("WeatherLayer") != null, \
		"the board carries both layers (sparse band)")

	# 20. order N — feature flags: all-ON is proven by the whole sweep (zero
	# behavior change); two flip smokes prove the guards actually disconnect
	var Features = load("res://engine/scripts/core/features.gd")
	ok(Features.on("idle_hint") and Features.on("nonexistent_flag_xyz"), \
		"known flags read true; unknown ids warn + default ON (typo-proof)")
	Features.FLAGS["idle_hint"] = false
	ok(s8._hint_pair().is_empty(), "idle_hint OFF: _hint_pair returns [] and wiggles nothing")
	Features.FLAGS["idle_hint"] = true
	fresh("flagpop")
	Features.FLAGS["ftue_free_pops"] = false
	var s9 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(s9)
	if s9.board == null:
		s9._ready()
	s9.board.take(Vector2i(3, 2))             # a virgin board has 2 empties — make room
	s9._rebuild_pieces()
	var s9b := 0
	for v in s9.board.items:
		if v > 0:
			s9b += 1
	s9._pop_seed()
	await create_timer(0.25).timeout
	var s9n := -s9b
	for v in s9.board.items:
		if v > 0:
			s9n += 1
	ok(s9n >= 1 and s9.water == G.WATER_CAP - s9n * G.POP_COST, "ftue_free_pops OFF: the FIRST pop costs water (no free intro)")
	Features.FLAGS["ftue_free_pops"] = true

	# 21. R4 — sweep the composited UI with the pixel-right asserts. Each element
	# now has PERMANENT rect coverage (the law's durable value); a failure here is
	# a real misalignment to fix. (wallet was R1; zone pin R2.)
	fresh("r4")
	# water chip (board, top-left) — reveal past the FTUE stage, then assert it wraps
	var sb4 = load("res://engine/scenes/Board.tscn").instantiate()
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
	var h4 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(h4)
	if h4.content == null:
		h4._ready()
	await create_timer(0.05).timeout
	# the level number now nests inside a sprout-avatar Control, so walk up to the
	# pill (PanelContainer) and assert it wraps its content row evenly.
	var lchip: Control = h4.level_label
	while lchip != null and not (lchip is PanelContainer):
		lchip = lchip.get_parent()
	var lrow4: Control = lchip.get_child(0)
	assert_wraps(lchip, lrow4, 5.0, 2.0, "R4 level chip")     # ±2: catches lopsided margins
	# map spot pin (an unowned, fresh-save spot) — the price pin wraps its row (S7
	# nests pins in a centered stack, so search the subtree, and FAIL loudly if absent)
	await create_timer(0.05).timeout
	var pin_panel: Control = null
	for hit in h4.spot_hits:
		var node: Control = hit.node
		var found: Array = node.find_children("*", "PanelContainer", true, false)
		if not found.is_empty():
			pin_panel = found[0]
			break
	ok(pin_panel != null and pin_panel.get_child_count() > 0, "R4/S7: a map spot price pin exists")
	if pin_panel != null and pin_panel.get_child_count() > 0:
		assert_wraps(pin_panel, pin_panel.get_child(0), 4.0, 4.0, "R4 spot pin")

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
	var pb := BoardModel.new()
	var pa := Vector2i(4, 4)
	var pbc := Vector2i(4, 5)
	pb.terrain[BoardModel.idx(pa)] = 0
	pb.terrain[BoardModel.idx(pbc)] = 0
	pb.place(pa, 101)
	pb.place(pbc, 203)
	pb.swap(pa, pbc)
	ok(pb.item_at(pa) == 203 and pb.item_at(pbc) == 101, "P1: swap trades two item codes")
	var pcoin := G.COIN_LINE * 100 + 1
	pb.place(pa, pcoin)
	pb.swap(pa, pbc)                          # pbc held 101
	ok(pb.item_at(pa) == 101 and pb.item_at(pbc) == pcoin, "P1: a coin swaps like any item")
	var pb2 := BoardModel.new()
	pb2.from_dict(pb.to_dict())
	ok(pb2.item_at(pa) == 101 and pb2.item_at(pbc) == pcoin, "P1: to_dict/from_dict preserves the swapped board")

	# P2: the drop chain (real _on_press → _on_release drives)
	fresh("pswap")
	Features.FLAGS["drag_swap"] = true
	var sp = load("res://engine/scenes/Board.tscn").instantiate()
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

	# 24. T — the Decorate jump goes to the MAP the player was decorating (NEW model:
	# decorate_zone opens that MAP, not an interior). Boot lands ON a map view.
	var HomeScript = load("res://engine/scripts/scenes/map.gd")
	# T1: opening a map persists last_zone
	fresh("tlast")
	var ht = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(ht)
	if ht.content == null:
		ht._ready()
	ht._open_map(0)
	ok(String(Save.grove().get("last_zone", "")) == "farmhouse", "T1: opening a map persists last_zone")
	# T1: sanitize — an unknown last_zone never survives a boot. _load_state drops it,
	# then the boot opens the frontier and re-records a VALID map id in its place.
	Save.grove()["last_zone"] = "atlantis"
	var ht2 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(ht2)
	if ht2.content == null:
		ht2._ready()
	ok(G.zone_for_id(String(Save.grove().get("last_zone", ""))) >= 0, \
		"T1: an unknown last_zone is scrubbed on load (boot re-records a valid map)")
	ok(ht2._view == "map", "T1: fresh arrival (no jump request) lands on a map view")
	# T2: the Decorate jump — opens the named map directly, NO map-select flash
	# (asserted before any frame), and the request is one-shot
	HomeScript.decorate_zone = "farmhouse"
	var ht3 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(ht3)
	if ht3.content == null:
		ht3._ready()
	ok(ht3._view == "map" and ht3._map_idx == 0, \
		"T2: Decorate opens the named map directly (asserted pre-frame: no select flash)")
	ok(HomeScript.decorate_zone == "", "T2: the jump request is one-shot (consumed)")
	# T2: an unknown jump request falls through to the frontier map
	HomeScript.decorate_zone = "atlantis"
	var ht4 = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(ht4)
	if ht4.content == null:
		ht4._ready()
	ok(ht4._view == "map", "T2: an unknown jump request falls through to the frontier map")

	# 25. order O — music degrades SILENTLY on a BARE engine. Audio is skin and the
	# real takes are archived, so ensure() must be a quiet no-op (never create a
	# player to crash on). The full A/B playlist-alternation logic ships + is tested
	# WITH the audio skin (needs takes on disk); here we only guard the engine never
	# crashes/hangs without it. (T16: this test used to assume real music on disk.)
	var Music = load("res://engine/scripts/core/music.gd")
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
	var ss = load("res://engine/scenes/Board.tscn").instantiate()
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
	var hs = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hs)
	if hs.content == null:
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
	var _skin = load("res://engine/scripts/ui/skin.gd")
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
	var ws = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(ws)
	if ws.board == null:
		ws._ready()
	await create_timer(0.05).timeout
	# W1: the idle merge hint comes SOONER and rocks gently (was 7s + a fast shake)
	ok(absf(float(ws.IDLE_HINT_SECS) - 4.5) < 0.01, "W1: first idle hint at 4.5s (was 7)")
	ok(int(ws.HINT_ROCK_CYCLES) >= 2 and float(ws.HINT_ROCK_DEG) <= 10.0, \
		"W1: the hint is a gentle multi-cycle rock, not a one-off fast shake")
	for cc in [Vector2i(1, 3), Vector2i(2, 3)]:
		ws.board.terrain[BoardModel.idx(cc)] = 0
		ws.board.place(cc, 101)
	ws._rebuild_pieces()
	ok(not ws._hint_pair().is_empty(), "W1: _hint_pair finds a mergeable pair to rock")
	# W2: rapid generator taps must NEVER be dropped by the animating gate. Open a
	# comfortable region, fire 5 board taps WITHOUT awaiting the 0.22s spawn flight.
	for wy in [1, 2, 4, 5]:                    # open a wide region so 5 bursts can never fill the board
		for wx in range(1, 8):
			var wc := Vector2i(wx, wy)
			ws.board.terrain[BoardModel.idx(wc)] = 0
			ws.board.items[BoardModel.idx(wc)] = 0
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
	ok(w_after - w_before >= 5, \
		"W2: 5 rapid generator taps each land a burst — none eaten by the animating gate (≥5 items) — got %d" % (w_after - w_before))
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
	var Feat = load("res://engine/scripts/core/features.gd")
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

	# V1 (the locked-generator "after N spots" preview) is PARKED with T17: it was keyed on
	# the old per-chapter `appears_at`; under per-zone generators the next set arrives on zone
	# COMPLETION, so the preview needs redefining alongside §6/§7. Test removed with the feature.

	# --- order Y: selling v2 — the diamond pinnacle + the porter's basket --------
	fresh("y")
	var Feat2 = load("res://engine/scripts/core/features.gd")
	Feat2.FLAGS["ftue_staged_chrome"] = false   # merchant + basket present on a fresh board
	Feat2.FLAGS["porter_collect"] = false        # test the MECHANICS, not the drift animation
	var ys = load("res://engine/scenes/Board.tscn").instantiate()
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

	# --- order Z: the coin sink — spirit treats -----------------------------------
	# (Z1/Z2 wayside on-map decorations are RETIRED with the old free-pan overworld:
	# the NEW map model is one image with restoration spots, no on-map wayside plots —
	# G.waysides()/wayside_available/buy_wayside/_on_map_tap no longer exist.)
	var Feat3 = load("res://engine/scripts/core/features.gd")
	# Z3: spirit treats — a 10🪙 recurring sink. Spend deducts exactly, rapid-buy is
	# independent (graceful), and you can't overspend.
	fresh("z3")
	Feat3.FLAGS["spirit_treats"] = true
	var z3 = load("res://engine/scenes/Board.tscn").instantiate()
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
