extends "res://games/grove/tests/grove_test_base.gd"
## grove · model — split from the grove_tests monolith; shares grove_test_base.gd.

func _initialize() -> void:
	begin("grove · model")

	# 1. board genesis
	var b: BoardModel = BoardModel.new()
	ok(b.is_open(G.GEN_CELL) and b.item_at(G.GEN_CELL) == 0, "generator cell open and empty")
	ok(b.is_open(Vector2i(3, 2)) and b.is_open(Vector2i(5, 4)), "center 3x3 starts open")
	ok(b.is_bramble(Vector2i(0, 0)) and b.is_bramble(Vector2i(8, 6)), "edges start brambled")
	# §4 per-cell LEVEL gate (replaces the old tier-ring encoding): G.cell_min_level. MIN_LEVEL is the
	# owner's feel dial (T37 — re-tuned to open an L1 frontier), so these assert the MECHANISM
	# (gradient-agnostic, derived from cell_min_level), not fixed table values.
	var g_inner := G.cell_min_level(Vector2i(2, 3))    # a center-adjacent frontier cell
	var g_next := G.cell_min_level(Vector2i(1, 3))     # one ring further out
	var g_corner := G.cell_min_level(Vector2i(0, 0))   # a far corner
	ok(G.cell_min_level(G.GEN_CELL) == 0 and G.cell_min_level(Vector2i(3, 2)) == 0, \
		"the center 3x3 + generator are open at start (min_level 0)")
	ok(g_inner >= 1, "the inner frontier is sealed but reachable early (gates at L%d)" % g_inner)
	ok(g_next > g_inner and g_corner > g_next, \
		"the gradient rises strictly outward (inner L%d < ring L%d < corner L%d)" % [g_inner, g_next, g_corner])
	ok(b.terrain[BoardModel.idx(Vector2i(2, 3))] != 0 and b.terrain[BoardModel.idx(Vector2i(0, 0))] != 0, \
		"a sealed cell's terrain is non-zero (inspectable; the gate reads the static table, not this value)")
	ok(BoardModel.line_of(G.bramble_contents(Vector2i(0, 0))) in [1, 2], \
		"an opened cell reveals a positional anchor-line (1-2) seed")
	ok(b.item_at(Vector2i(3, 2)) == 101, "starter items placed")

	# 2. merge rules
	ok(b.can_merge(Vector2i(3, 2), Vector2i(3, 4)), "same code merges")
	ok(not b.can_merge(Vector2i(3, 2), Vector2i(5, 2)), "different lines never merge")
	var produced := b.merge(Vector2i(3, 2), Vector2i(3, 4))
	ok(produced == 102 and b.item_at(Vector2i(3, 2)) == 0 and b.item_at(Vector2i(3, 4)) == 102, \
		"merge consumes src and bumps dst")
	b.place(Vector2i(3, 2), 100 + G.TOP_TIER)
	b.place(Vector2i(4, 2), 100 + G.TOP_TIER)
	ok(not b.can_merge(Vector2i(3, 2), Vector2i(4, 2)), "top tier (t%d) never merges" % G.TOP_TIER)
	ok(b.top_tier_cells().size() == 2, "top tiers visible to the merchant")

	# 3. move / the §4 level gate (merge-openable once the player's Level reaches the cell's min)
	b.move(Vector2i(3, 4), Vector2i(3, 3))
	ok(b.item_at(Vector2i(3, 3)) == 102 and b.item_at(Vector2i(3, 4)) == 0, "move relocates an item")
	# (2,3) is (3,3)'s sealed neighbour, gating at g_inner: a merge there opens it AT g_inner.
	ok(b.openable_brambles(Vector2i(3, 3), g_inner).has(Vector2i(2, 3)), \
		"at the cell's min_level (L%d), any adjacent merge opens it (no tier/line requirement)" % g_inner)
	if g_inner >= 2:
		ok(not b.openable_brambles(Vector2i(3, 3), g_inner - 1).has(Vector2i(2, 3)), \
			"below the cell's min_level, an adjacent merge opens nothing")
	var contents := b.open_bramble(Vector2i(2, 3))
	ok(b.is_open(Vector2i(2, 3)) and b.item_at(Vector2i(2, 3)) == contents and contents == G.bramble_contents(Vector2i(2, 3)), \
		"opening a cell reveals its deterministic contents")
	# the gradient holds outward: (1,3) gates at g_next > g_inner — sealed just below it, opens at it
	b.place(Vector2i(2, 3), 102)              # an item on the freshly-opened cell
	ok(not b.openable_brambles(Vector2i(2, 3), g_next - 1).has(Vector2i(1, 3)), \
		"the outer cell (1,3) stays sealed at L%d (below its L%d gate)" % [g_next - 1, g_next])
	ok(b.openable_brambles(Vector2i(2, 3), g_next).has(Vector2i(1, 3)), \
		"the outer cell (1,3) opens once the player reaches its gate (L%d)" % g_next)

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

	# 6c. generators arrive PER MAP (§6). Map 0 grants both starters (satchel + compost);
	# the surplus generator's cell (6,5) reveals only when the player enters map 1.
	var z1_spots: int = G.MAPS[0].spots.size()  # all map-0 spots bought (= entering map 1)
	var bg: BoardModel = BoardModel.new()
	bg.set_active_gens(0)
	ok(bg.is_gen(Vector2i(4, 3)) and bg.is_gen(Vector2i(2, 1)), "map 0 grants both starters (satchel + compost)")
	ok(not bg.is_gen(Vector2i(6, 5)), "the map-1 surplus generator waits for its own map")
	# 6d. entering map 1 reveals the surplus generator at (6,5) — and an item caught on
	# that cell hops away safely (never destroyed).
	var bh: BoardModel = BoardModel.new()
	bh.set_active_gens(0)
	bh.terrain[BoardModel.idx(Vector2i(6, 5))] = 0
	bh.place(Vector2i(6, 5), 204)              # a player item parked on the future generator cell
	var before_count := 0
	for v in bh.items:
		if v == 204:
			before_count += 1
	var fresh_hive: Array = bh.set_active_gens(z1_spots)
	ok(fresh_hive.has(Vector2i(6, 5)) and bh.is_gen(Vector2i(6, 5)), "entering map 1 reveals the surplus generator")
	var after_count := 0
	for v in bh.items:
		if v == 204:
			after_count += 1
	ok(after_count == before_count and bh.item_at(Vector2i(6, 5)) == 0, \
		"an item on the revealing generator's cell relocates, never vanishes")

	# 6e. the SECOND map-0 generator (pantry_crock) is STAGED via appear_level — it grows in only
	# once the player's Level reaches it, so a new player opens with ONE generator + its lines, not
	# two. The gate covers BOTH placement (live_gen_state/seed) AND askable lines (so the fence never
	# asks for a line nothing on the board can produce yet). Read the dial off the def → retune-proof.
	var pantry_def := G.gen_def(G.GENERATORS, "pantry_crock")
	var pantry_lvl := int(pantry_def.get("appear_level", 0))
	var pantry_cell: Vector2i = pantry_def.cell
	var below := pantry_lvl - 1
	ok(pantry_lvl > 0, "the pantry crock is staged (appear_level L%d > 0)" % pantry_lvl)
	ok(G.live_gen_state(G.GENERATORS, 0, below).size() == 1, "below its level, map 0 places only the anchor satchel")
	ok(G.live_gen_state(G.GENERATORS, 0, pantry_lvl).has(pantry_cell), "at its level, the pantry joins the live set")
	ok(not G.askable_lines(G.GENERATORS, 0, below).has(3), "the pantry's lines are NOT askable before it appears")
	ok(G.askable_lines(G.GENERATORS, 0, pantry_lvl).has(3) and G.askable_lines(G.GENERATORS, 0, pantry_lvl).has(4), \
		"the pantry's lines (3,4) become askable when it appears")
	var bs: BoardModel = BoardModel.new()
	bs.seed_gens(0, below)
	ok(bs.is_gen(G.GEN_CELL) and not bs.is_gen(pantry_cell), "seeding below the level places only the anchor")
	ok(bs.grow_surplus_gens(0, below).is_empty(), "nothing grows in below the level")
	var grown: Array = bs.grow_surplus_gens(0, pantry_lvl)
	ok(grown.has("pantry_crock") and bs.is_gen(pantry_cell), "reaching the level grows the pantry in at its cell")
	ok(bs.grow_surplus_gens(0, pantry_lvl).is_empty(), "growing is idempotent (no duplicate install)")

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
	Save.grove()["stars_earned"] = G.stars_at_level(2)   # §4: reach Lv2 (level clock only) so the L2 frontier cell (2,4) can open
	scn._on_press(scn._cell_pos(Vector2i(3, 2)) + half)
	scn._on_release(scn._cell_pos(Vector2i(3, 4)) + half)
	ok(scn.board.item_at(Vector2i(3, 4)) == 102, "drag-merge grows t1+t1 into t2")
	await create_timer(0.35).timeout
	ok(scn.board.is_open(Vector2i(2, 4)), "at Lv2 the merge cleared the adjacent L2 frontier cell")
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

	# deliver: map 1's first quest wants flower t2 (code 102) — we just made one
	ok(not scn.giver_chips.is_empty(), "givers are on duty")

	# HORIZONTAL card anatomy: a character portrait (bust) on the left + the requested item(s)
	# large in the speech bubble on the right (no ask-pill-below-bust). The ready-check is present
	# (the old border ring is gone); its visibility is driven by board state.
	await create_timer(0.05).timeout
	for e in scn.giver_chips:
		ok(e.bust != null and is_instance_valid(e.bust), "giver card carries a character portrait")
		ok(not (e.asks as Array).is_empty(), "giver card shows at least one requested item")
		for au in e.asks:
			ok(au.get("piece") != null and is_instance_valid(au.get("piece")), "the ask item renders on the card")
		# the stand-level ready-check is retired — one big per-ask ✓ (the `met` node) carries readiness
		ok(e.check == null, "the stand-level ready-check is retired (single big per-ask ✓)")
		for au2 in e.asks:
			var mck: Control = au2.get("met")
			ok(mck != null and is_instance_valid(mck) and mck is Panel, "the ask carries a big met-✓ node (over the item)")
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
	# the restore invitation now LIGHTS the centre Home button (the standalone Decorate CTA is retired):
	# Home breathes the moment a spot is affordable
	ok(scn.home_btn != null and scn.home_btn.has_meta("_fx_breathing"), "§7: the Home button breathes when a spot is affordable")
	# the Home button lives in the bottom nav, structurally clear of the fence — it can't cover a giver/merchant pill
	# buying a home spot advances the board's progress: it derives from unlocks
	var spots_before: int = scn._spots_bought()
	var gu := Save.grove()
	var first_spot: String = G.MAPS[0].spots[0].id
	gu["unlocks"] = {first_spot: true}
	Save.grove_write()
	ok(scn._spots_bought() == spots_before + 1, "a home purchase advances the board's progress (unlocks)")

	# persistence: a fresh scene resumes the same board + progress
	var snapshot := Array(scn.board.items)
	var scn2 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(scn2)
	if scn2.board == null:
		scn2._ready()
	ok(Array(scn2.board.items) == snapshot and scn2._spots_bought() == scn._spots_bought(), \
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
	for sp in G.MAPS[0].spots:
		gate_ul[String(sp.id)] = true         # all of map 1 spot-restored
	sgg["unlocks"] = gate_ul
	sgg["gates"] = []
	Save.grove_write()
	# the pantry crock is now STAGED (appear_level 5): in real play it grows in during map-0 play,
	# long before the map is fully restored. This fast-forward seeded the board at L1 (satchel only),
	# so install the pantry as map-0 play would have — the cross-map hand-in (pantry → hen coop) below
	# needs it present on the board.
	sg.board.grow_surplus_gens(0, 99)
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
	ok(G.map_unlocked(1, Save.grove().get("unlocks", {}), Save.grove().get("gates", [])), "§7: map 2 unlocks once the gate is delivered")
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
	finish()
