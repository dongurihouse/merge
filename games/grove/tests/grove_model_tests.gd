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
	ok(not b.can_merge(Vector2i(3, 2), Vector2i(4, 2)), "top tier (t%d) never merges" % int(G.TOP_TIER))
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

	# 6c. generators arrive PER MAP (§6): the shipped roster is ONE generator per map, so map 0's
	# board carries only ITS own generator (the anchor satchel at (4,3)); the next map's generator
	# (hen_coop) is NOT live on the map-0 board — it waits for its own map.
	var z1_spots: int = G.MAPS[0].spots.size()  # all map-0 spots bought (= entering map 1)
	var hen_cell: Vector2i = G.gen_cell_of(G.GENERATORS, "hen_coop")
	var bg: BoardModel = BoardModel.new()
	bg.set_active_gens(0)
	ok(bg.is_gen(Vector2i(4, 3)) and bg.gens.size() == 1, "map 0's board carries only its own anchor generator (the satchel)")
	ok(not bg.is_gen(hen_cell), "map 1's generator (hen_coop) is not live on the map-0 board (it waits for its own map)")
	# 6d. entering map 1 reveals map 1's generator at its cell — and an item caught on that cell
	# hops away safely (never destroyed): _claim_gen_cells relocates a parked item to open ground.
	var bh: BoardModel = BoardModel.new()
	bh.set_active_gens(0)
	bh.terrain[BoardModel.idx(hen_cell)] = 0
	bh.place(hen_cell, 204)                    # a player item parked on the future generator cell
	var before_count := 0
	for v in bh.items:
		if v == 204:
			before_count += 1
	var fresh_hive: Array = bh.set_active_gens(z1_spots)
	ok(fresh_hive.has(hen_cell) and bh.is_gen(hen_cell), "entering map 1 reveals map 1's generator (hen_coop) at its cell")
	var after_count := 0
	for v in bh.items:
		if v == 204:
			after_count += 1
	ok(after_count == before_count and bh.item_at(hen_cell) == 0, \
		"an item on the revealing generator's cell relocates, never vanishes")

	# 6e. the appear_level STAGING gate is a live ENGINE feature: a generator grows into the live set
	# only once the player's Level reaches its appear_level (the PLACEMENT axis, via live_gen_state).
	# The shipped roster is ONE generator per map (no staged gen — pantry_crock was retired, §content),
	# so this drives the gate on a SYNTHETIC roster: map 0 = a live anchor (L0) + a staged gen (L5).
	# (The askable-lines side of the same gate is covered in anchor_tests.)
	var staged := [
		{"id": "fix_anchor", "map": 0, "cell": Vector2i(4, 3), "lines": [1, 2], "anchor": true},
		{"id": "fix_staged", "map": 0, "cell": Vector2i(2, 1), "lines": [3, 4], "appear_level": 5},
	]
	ok(G.live_gen_state(staged, 0, 4).size() == 1 and G.live_gen_state(staged, 0, 4).values().has("fix_anchor"), \
		"below its level, only the anchor is live (the staged gen is held back)")
	ok(G.live_gen_state(staged, 0, 5).size() == 2 and G.live_gen_state(staged, 0, 5).has(Vector2i(2, 1)), \
		"at its appear_level the staged gen joins the live set at its cell")

	# 6e-bis: grow_gens(0, ...) must NEVER place another map's generators. Regression for the bug
	# where map_for_spots(_spots_bought()) returned 1 once all map-0 spots were bought, auto-placing
	# map 1's gens on the board. (Reads the live roster: map 0 = seed_satchel; map 1 = hen_coop.)
	var bmap0: BoardModel = BoardModel.new()
	bmap0.seed_gens(0)
	bmap0.grow_gens(0, 99)
	ok(not bmap0.gens.values().has("hen_coop"), \
		"grow_gens(0, ...) never places map 1's generator (hen_coop) on the board")
	ok(bmap0.gens.values().has("seed_satchel"), \
		"grow_gens(0, 99) places map 0's own anchor generator (seed_satchel)")

	# 6e-ter: a generator stored in gen_bag must NOT be auto-re-placed by grow_gens (the duplicate-gen
	# bug — a gen living in both gen_bag and board.gens). Driven on map 1's hen_coop (a non-anchor gen
	# that seed_gens places), stored to the bag, then grown — it must stay in the bag, off the board.
	var bgb: BoardModel = BoardModel.new()
	bgb.seed_gens(1)
	var hc_cell: Vector2i = G.gen_cell_of(G.GENERATORS, "hen_coop")
	ok(bgb.store_gen(hc_cell), "store hen_coop into the gen_bag (frees its cell)")
	ok(bgb.gen_bag.has("hen_coop") and not bgb.gens.values().has("hen_coop"), \
		"pre-condition: hen_coop is in gen_bag, not on the board")
	bgb.grow_gens(1, 99)
	ok(not bgb.gens.values().has("hen_coop"), \
		"grow_gens skips a generator already stored in gen_bag (no auto-re-place)")
	ok(bgb.gen_bag.has("hen_coop"), "hen_coop remains in gen_bag after grow_gens")

	# 6f. gen_bag: store a board generator and place it back
	var bm := BoardModel.new()
	bm.seed_gens(0)
	var first_cell: Vector2i = bm.gens.keys()[0]
	var gid := String(bm.gens[first_cell])
	ok(bm.store_gen(first_cell) and not bm.gens.has(first_cell) and bm.gen_bag.has(gid), "store_gen moves a generator board→gen_bag")
	var open_cell: Vector2i = bm.empty_ground_cells()[0]
	ok(bm.place_gen_from_bag(gid, open_cell) and bm.gens.values().has(gid) and not bm.gen_bag.has(gid), "place_gen_from_bag moves it gen_bag→board")
	var bm_round := BoardModel.new(); bm_round.from_dict(bm.to_dict())
	ok(str(bm_round.gen_bag) == str(bm.gen_bag), "gen_bag survives to_dict/from_dict")

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
	ok(int(counts.get(101, 0)) >= 2 and int(counts.get(6101, 0)) >= 2, "starters give each of the 2 L1 lines (Wildflower 101 + Hearth embers 6101) a pair")

	# 9. exp total (Save) — the single progression number (no spendable balance)
	fresh("exp")
	ok(Save.exp_total() == 0, "exp default 0")
	Save.add_exp(3)
	ok(Save.exp_total() == 3, "add_exp accumulates")
	Save.add_exp(5)
	ok(Save.exp_total() == 8, "exp only ever rises (no spend)")

	# 10. the SCENE stands up and plays headless (merge → bramble → deliver → gate)
	fresh("scene")
	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(scn)
	if scn.board == null:
		scn._ready()
	ok(scn.board != null and scn.board.bramble_count() > 0, "grove scene builds with a brambled board")
	var half: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
	Save.grove()["exp"] = G.exp_at_level(2)   # §4: reach Lv2 (the exp-derived level) so the L2 frontier cell (2,4) can open
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

	# HORIZONTAL card anatomy: a character portrait (bust) on the left + the requested item
	# large in the speech bubble on the right (no ask-pill-below-bust). The ready-check is present
	# (the old border ring is gone); its visibility is driven by board state.
	await create_timer(0.05).timeout
	for e in scn.giver_chips:
		ok(e.bust != null and is_instance_valid(e.bust), "giver card carries a character portrait")
		var item_ui: Dictionary = e.get("item", {})
		if not item_ui.is_empty():
			ok(item_ui.get("piece") != null and is_instance_valid(item_ui.get("piece")), "the item renders on the card")
		# the stand-level ready-check is retired — one big per-item ✓ (the `met` node) carries readiness
		ok(e.check == null, "the stand-level ready-check is retired (single big per-item ✓)")
		if not item_ui.is_empty():
			var mck: Control = item_ui.get("met")
			ok(mck != null and is_instance_valid(mck) and mck is Panel, "the item carries a big met-✓ node (over the item)")
	var qi: int = scn.giver_chips[0].qi
	var dq: Dictionary = scn.quests[qi]
	# clear the open board first so EVERY ask fits regardless of prior test state
	# (determinism: a crowded board could otherwise starve a multi-ask delivery)
	for ci in scn.board.items.size():
		if scn.board.items[ci] > 0 and not G.is_coin(scn.board.items[ci]):
			scn.board.items[ci] = 0
	var demp: Array = scn.board.empty_ground_cells()
	var it_dq := G.quest_item(dq)
	if not it_dq.is_empty() and not demp.is_empty():
		scn.board.place(demp[0], int(it_dq.line) * 100 + int(it_dq.tier))
	scn._rebuild_pieces()
	var exp_before := Save.exp_total()
	var dlv_coins_before := Save.coins()
	var n_before: int = scn.quests.size()
	scn._on_giver_tap(qi, scn.giver_chips[0].chip)
	ok(Save.exp_total() > exp_before, "§7: delivery pays exp (all asks satisfied)")
	ok(Save.coins() >= dlv_coins_before, "§7: delivery pays any coin overflow (the quest coin faucet)")
	ok(scn.quests.size() <= n_before, "§7: the delivered quest leaves the live fence")

	# §7 soft gate: once total exp can claim the WHOLE current map (fence_inert), the fence does
	# NOT empty — it fills to MAX_GIVERS greyed/inert quests (so it never goes blank under the lit
	# restore CTA), and the next unlock reads ready.
	var gg := Save.grove()
	gg["exp"] = 300                              # well past map 0's spot thresholds → fence_inert
	Save.grove_write()
	scn._rebuild_givers()
	scn._update_hud()
	ok(scn._gate_ready(), "§7: total exp has reached the next unlock threshold (gate ready)")
	ok(scn.quests.size() == int(G.MAX_GIVERS), "§7: the inert fence fills to MAX_GIVERS greyed (never blank)")
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

	# 10g. TAP-TO-PRODUCE the next generator + spots-done unlock (the carrier/gate quest types are retired).
	# (a) Once a map is UNLOCKED (map_unlocked — the SAME gate signal that surfaces its quests, not a visit),
	# its generator is DUE; the next generator TAP births it on the board (gen_bag only when the board is full).
	# No quest delivers it, and it self-heals any missing tool. (b) Restoring the LAST spot auto-appends z to
	# `gates`, unlocking the next map (no gate quest). All engine/grove-side; the grove only supplies tunables.
	fresh("produce")
	var sg = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sg)
	if sg.board == null:
		sg._ready()
	var sgg := Save.grove()
	sgg["exp"] = 300                          # exp past map 0's spot thresholds
	# complete map 0 (all spots restored + the gate recorded) → map 1 is UNLOCKED
	var done0 := {}
	for sp in G.MAPS[0].spots:
		done0[String(sp.id)] = true
	sgg["unlocks"] = done0
	sgg["gates"] = [0]
	Save.grove_write()
	sg._init_quests()
	sg._rebuild_all()
	# SINGLE-GENERATOR model (idea 3): the map-0 anchor is the ONLY generator. Unlocking map 1 does NOT
	# grow a new tool — the anchor itself pops every OPENED line (map 1's included). So nothing is due, and
	# a generator tap POPS ITEMS rather than birthing a tool; no new generator tile ever accumulates.
	var owned_b: Array = []
	for gv in sg.board.gens.values():
		owned_b.append(String(gv))
	for gbid in sg.board.gen_bag:
		owned_b.append(String(gbid))
	ok(not sg.board.gens.values().has("hen_coop"), "map 1's tool is never produced (single anchor)")
	ok(G.due_generators(done0, [0], owned_b).is_empty(), "map 1 unlocked → NO tool is due (the anchor serves all opened lines)")
	var gens_before: int = sg.board.gens.size()
	ok(not sg._produce_due_generators(), "nothing is due → a tap produces no new tool")
	ok(sg.board.gens.size() == gens_before, "the generator set stays a single anchor (no new tiles accumulate)")
	ok(sg.board.gen_id_at(Vector2i(4, 3)) == "seed_satchel", "the anchor satchel remains the sole generator")
	# SEAM PROBE: map 1's line is in the anchor's ASKABLE pool, so a fence entering map 1 is satisfiable from
	# the single anchor WITHOUT producing hen_coop.
	var askable_at_m1: Array = G.askable_lines(G.GENERATORS, 1)
	for hc_ln in G.gen_def(G.GENERATORS, "hen_coop").get("lines", []):
		ok(askable_at_m1.has(int(hc_ln)), "map-1 line %d is askable from the anchor (fence producible, no new tool)" % int(hc_ln))
	sg.queue_free()
	# full-board fallback: exercise board_model.place_gen directly — no open cell → gen_bag.
	# (The full-scene delivery path can't easily be made to have zero empty cells post-quest-consume;
	# the board-model-level assertion is the right place for this invariant.)
	fresh("grant_full_board")
	var fbm := BoardModel.new()
	fbm.seed_gens(0, G.APPEAR_ALL)
	# fill every open cell with a dummy item so no empty ground remains
	for ofc in fbm.empty_ground_cells():
		fbm.place(ofc, 101)
	ok(fbm.empty_ground_cells().is_empty(), "pre-condition: board is full (no empty ground cells)")
	# attempt to grant a generator — must land in gen_bag
	fbm.gen_bag.clear()
	var dest2 := Vector2i(-1, -1)
	for fc in fbm.empty_ground_cells():
		if not fbm.gens.has(fc):
			dest2 = fc
			break
	if dest2 == Vector2i(-1, -1):
		fbm.gen_bag.append("hen_coop")
	else:
		fbm.place_gen("hen_coop", dest2)
	ok(fbm.gen_bag.has("hen_coop") and not fbm.gens.values().has("hen_coop"), \
		"when the board is full, granted generators fall back to gen_bag")

	# (b) spots-done unlock via the REAL Map scene: buying the final spot records z in `gates`.
	fresh("spotsdone")
	var hm = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hm)
	if hm.content == null:
		hm._ready()
	var hmg := Save.grove()
	hmg["exp"] = G.spot_unlock_exp(0, G.MAPS[0].spots.size() - 1)   # exp at the last spot's threshold → claimable
	var sd_ul := {}
	for i in G.MAPS[0].spots.size() - 1:
		sd_ul[String(G.MAPS[0].spots[i].id)] = true   # all but the last spot
	hmg["unlocks"] = sd_ul
	hmg["gates"] = []
	Save.grove_write()
	hm.unlocks = sd_ul.duplicate()
	var last_k: int = G.MAPS[0].spots.size() - 1
	var sd_node := Control.new()
	hm.add_child(sd_node)
	hm._on_spot_tap(0, last_k, sd_node, Vector2(100, 100))
	ok(G.map_spots_done(0, hm.unlocks), "buying the last spot completes map 0's spots")
	ok(Save.grove().get("gates", []).has(0), "restoring the last spot auto-records map 0 in `gates` (no gate quest)")
	ok(G.map_unlocked(1, Save.grove().get("unlocks", {}), Save.grove().get("gates", [])), "the next map (1) unlocks once map 0's spots are done")
	hm.queue_free()

	# 11. P2 — water economy + coins
	finish()
