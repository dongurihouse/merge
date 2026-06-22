extends SceneTree
## Headless tests for core/quests.gd — the §7 fence-COMPOSITION layer that sits above
## the quest engine in content.gd (G.gen_quest / active_giver_count). board.gd's instance
## methods (_quest_map/_refill_quests/…) are thin Save-reading wrappers over these pure
## statics, so the fence decision is testable with no scene/window/Save.
##   godot --headless --path . -s res://engine/tests/quest_fence_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const Quests = preload("res://engine/scripts/core/quests.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _initialize() -> void:
	# --- reward readers: new {reward:{…}} shape and the legacy flat {stars} shape ---
	var q_new := {"reward": {"stars": 3, "coins": 5, "gems": 1}}
	ok(Quests.stars(q_new) == 3, "stars() reads reward.stars")
	ok(Quests.coins(q_new) == 5, "coins() reads reward.coins")
	ok(Quests.gems(q_new) == 1, "gems() reads reward.gems")
	var q_legacy := {"stars": 2}
	ok(Quests.stars(q_legacy) == 2, "stars() falls back to the flat legacy key")
	ok(Quests.coins(q_legacy) == 0 and Quests.gems(q_legacy) == 0, "legacy quests pay no coins/gems")
	ok(Quests.gems({"reward": {"stars": 1, "coins": 0}}) == 0, "a normal (non-featured) quest has 0 gems")

	# --- map / map_done on a fresh game (no spots owned, no gates delivered) ---
	ok(Quests.current_map({}, []) == 0, "a fresh game's frontier is map 0")
	ok(not Quests.map_done({}, []), "a fresh game is not map-done (a frontier exists)")

	# --- gate_ready: 0★ can't afford the next spot; a huge bank can (stars are the only gate) ---
	ok(not Quests.gate_ready(0, 0, {}), "0★ → the next unlock is not affordable (not ready)")
	ok(Quests.gate_ready(0, 999999, {}), "a huge ★ bank can afford the next spot (ready)")

	# --- purge_state: the fence Purge card SHOWs while a frontier remains (always, not only when ready),
	# --- is READY (breathes) when the cheapest unlock is affordable, and carries the banked ★ to display ---
	var ps_poor := Quests.purge_state(0, 0, {}, [])
	ok(ps_poor.show and not ps_poor.ready, "purge card shows on a fresh map even with 0★ (greyed, not ready)")
	ok(int(ps_poor.stars) == 0, "purge card carries the banked star count (0)")
	var ps_rich := Quests.purge_state(0, 999999, {}, [])
	ok(ps_rich.show and ps_rich.ready, "purge card is ready (breathes) once the cheapest unlock is affordable")
	ok(int(ps_rich.stars) == 999999, "purge card carries the banked star count (999999)")
	# a fully restored game (every spot + gate done) → no frontier → the purge card hides
	var all_done := {}
	for zz in G.MAPS.size():
		for sp in G.MAPS[zz].spots:
			all_done[String(sp.id)] = true
	var all_gates: Array = []
	for zz in G.MAPS.size():
		all_gates.append(zz)
	if Quests.map_done(all_done, all_gates):
		ok(not Quests.purge_state(0, 999999, all_done, all_gates).show, "purge card hides once the whole map is done")

	# --- meter_target: bounded 0..MAX_GIVERS, and shrinks as ★ bank toward finishing the map (§7) ---
	var tgt := Quests.meter_target(0, 0, {})
	ok(tgt >= 0 and tgt <= int(G.MAX_GIVERS), "the metered fence size stays within 0..MAX_GIVERS (got %d)" % tgt)
	ok(Quests.meter_target(0, 0, {}) >= Quests.meter_target(0, 100000, {}), "the fence shrinks monotonically as ★ bank toward finishing the map")

	# --- owned_gens: the union of board generators and gen_bag ids ---
	ok(str(Quests.owned_gens({Vector2i(0, 0): "a", Vector2i(1, 1): "b"}, ["c"])) == str(["a", "b", "c"]), "owned_gens unions board generators and the gen_bag")

	# --- stars_remaining: the unowned spot costs minus the banked stars, floored at 0 ---
	var z0_left := G.map_stars_left(0, {})
	ok(Quests.stars_remaining(0, {}, 0) == z0_left, "stars_remaining with 0 banked = the map's total unowned spot cost")
	ok(Quests.stars_remaining(0, {}, 999999) == 0, "stars_remaining floors at 0 once banked covers the spots")

	# --- refill: the normal stream fills to the metered target with non-gate/grant quests ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var r := Quests.refill([], 0, {}, [], {}, [], 0, 1, rng)
	ok(r.size() == tgt, "refill fills an empty fence to exactly the metered target (%d)" % tgt)
	var no_special := true
	for q in r:
		if bool(q.get("gate", false)) or q.has("grant"):
			no_special = false
	ok(no_special, "the normal stream carries no gate or grant quest")

	# --- refill is deterministic for a given seed (the rng is seeded + persisted; order is load-bearing) ---
	var rA := RandomNumberGenerator.new(); rA.seed = 7
	var rB := RandomNumberGenerator.new(); rB.seed = 7
	ok(str(Quests.refill([], 0, {}, [], {}, [], 0, 1, rA)) == str(Quests.refill([], 0, {}, [], {}, [], 0, 1, rB)), "refill is deterministic for a given seed")

	# --- refill trims an over-full fence back down to the target ---
	var over: Array = []
	for _i in tgt + 3:
		over.append({"line": 1, "tier": 1, "reward": {"stars": 1, "coins": 0}})
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 1
	ok(Quests.refill(over, 0, {}, [], {}, [], 0, 1, rng2).size() == tgt, "refill trims an over-full fence to the metered target")

	# --- item anti-repeat (§7): refill steers a NEW ask off the recent-items window (the last ≤5 asked
	# --- item codes, line*100+tier) — a HARD exclusion (the same item-code avoid set the concurrent-fence
	# --- stands use). When the item pool is too small to honour the whole window it relaxes the OLDEST
	# --- asks first, never the freshest. A different TIER of the same line still counts as variety. ---
	var pool := G.askable_lines(G.GENERATORS, 0, 99)
	if pool.size() >= 2:
		# target the newest line at its tier-bell centre (the most-asked item) so the free count is non-zero
		var fence_hi := clampi(int(G.QUEST_TIER_BASE) + int(6 / float(G.QUEST_LEVELS_PER_TIER)), int(G.QUEST_TIER_BASE), int(G.TOP_TIER))
		var rl_target := int(pool[pool.size() - 1]) * 100 + int((int(G.QUEST_TIER_BASE) + fence_hi) / 2)
		var rl_free := 0
		var rl_avoid := 0
		for s in 200:
			var rf := RandomNumberGenerator.new(); rf.seed = s
			for q in Quests.refill([], 0, {}, [], {}, [], 0, 6, rf):
				var it := G.quest_item(q)
				if int(it.line) * 100 + int(it.tier) == rl_target:
					rl_free += 1
			var ra := RandomNumberGenerator.new(); ra.seed = s
			for q in Quests.refill([], 0, {}, [], {}, [], 0, 6, ra, [rl_target]):
				var it := G.quest_item(q)
				if int(it.line) * 100 + int(it.tier) == rl_target:
					rl_avoid += 1
		ok(rl_free > 0 and rl_avoid < rl_free, "refill steers new asks off the recent-items window (%d→%d)" % [rl_free, rl_avoid])
		# determinism is preserved with a recent-items window (same seed → same fence)
		var rd1 := RandomNumberGenerator.new(); rd1.seed = 9
		var rd2 := RandomNumberGenerator.new(); rd2.seed = 9
		ok(str(Quests.refill([], 0, {}, [], {}, [], 0, 6, rd1, [rl_target])) == str(Quests.refill([], 0, {}, [], {}, [], 0, 6, rd2, [rl_target])), "refill stays deterministic with a recent-items window")

	# --- NO TWO IN A ROW on the smallest real pool: map-0 has just 2 lines, so the recent window (5)
	# --- is bigger than the early item pool. Priority relaxation must still keep CONSECUTIVE asks
	# --- distinct (the bug: the old soft fallback repeated). A rolling window mirrors board.gd. ---
	var small_lines := [1, 2]
	for lvl in [0, 1, 4, 8]:
		var rr := RandomNumberGenerator.new(); rr.seed = 99 + lvl
		var recent: Array = []
		var prev := -1
		var dupes := 0
		var seen := {}
		for _i in 300:
			var q := G.gen_quest(lvl, small_lines, rr, recent)
			var code := int(q.line) * 100 + int(q.tier)
			seen[code] = true
			if code == prev:
				dupes += 1
			prev = code
			recent.append(code)
			while recent.size() > 5:
				recent.pop_front()
		ok(dupes == 0, "level %d: no two asks in a row on map-0's 2-line pool (%d distinct items, %d dupes)" % [lvl, seen.size(), dupes])
	# concurrent fence stands stay distinct on a small pool too (mirrors refill's avoid construction)
	var rf2 := RandomNumberGenerator.new(); rf2.seed = 7
	var fence: Array = []
	for _s in int(G.MAX_GIVERS):
		var q := G.gen_quest(8, small_lines, rf2, fence.duplicate())
		fence.append(int(q.line) * 100 + int(q.tier))
	var uniq := {}
	for c in fence:
		uniq[c] = true
	ok(uniq.size() == fence.size(), "concurrent fence stands stay distinct on a small pool (%d/%d unique)" % [uniq.size(), fence.size()])

	# --- ladder_entries: one row per tier, code = line*100+tier, seen flagged from the save's `seen` set ---
	var lad := Quests.ladder_entries({}, 1)
	ok(lad.size() == int(G.TOP_TIER), "the ladder has one entry per tier (1..TOP_TIER)")
	ok(int(lad[0].tier) == 1 and int(lad[0].code) == 101 and not bool(lad[0].seen), "tier 1 of line 1 is code 101, unseen on a fresh save")
	ok(int(lad[int(G.TOP_TIER) - 1].code) == 100 + int(G.TOP_TIER), "the top entry is line*100 + TOP_TIER")
	ok(bool(Quests.ladder_entries({"101": true}, 1)[0].seen), "a code in the `seen` set marks that tier seen")
	ok(not bool(Quests.ladder_entries({"101": true}, 1)[1].seen), "an unseen tier stays unseen")

	# --- the NEAR-END generator grant: while finishing map z, when the stars still needed to restore
	# --- its remaining spots ≤ GEN_GRANT_REMAINING_STARS AND map z+1's generators aren't yet owned,
	# --- EXACTLY ONE ordinary quest carries reward.generators (the next map's unowned tools → gen_bag).
	# --- No gate/grant quest type — it rides an ordinary quest. Scenario: all of map 0's spots bought
	# --- except the last (cost 5), so one spot remains and a non-empty metered fence still exists.
	var ne_ul := {}
	for i in G.MAPS[0].spots.size() - 1:
		ne_ul[String(G.MAPS[0].spots[i].id)] = true
	var rngz := RandomNumberGenerator.new(); rngz.seed = 11
	var nfence := Quests.refill([], 0, ne_ul, [], {}, [], 1, 6, rngz)
	ok(Quests.stars_remaining(0, ne_ul, 1) <= int(G.GEN_GRANT_REMAINING_STARS), "the scenario is near-end (stars_remaining ≤ GEN_GRANT_REMAINING_STARS)")
	ok(not nfence.is_empty(), "the metered fence is still non-empty near the end (a quest can carry the grant)")
	var carriers := nfence.filter(func(q): return q.has("reward") and (q.reward as Dictionary).has("generators"))
	ok(carriers.size() == 1, "EXACTLY one quest carries reward.generators near the end of the map")
	ok(str(carriers[0].reward.generators) == str(G.gens_to_grant(G.GENERATORS, 0, [])), "the carried generators are map 1's unowned ids (hen_coop + dairy_stall)")
	var no_special2 := true
	for q in nfence:
		if bool(q.get("gate", false)) or q.has("grant"):
			no_special2 = false
	ok(no_special2, "the near-end fence is ordinary quests — no gate/grant quest type")

	# --- idempotent: a later refill with the carrier already present never duplicates onto a second quest ---
	var refilled := Quests.refill(nfence, 0, ne_ul, [], {}, [], 1, 6, RandomNumberGenerator.new())
	ok(refilled.filter(func(q): return q.has("reward") and (q.reward as Dictionary).has("generators")).size() == 1, "a later refill keeps exactly one generator-carrying quest (no duplication)")

	# --- once owned (in the gen_bag), the grant stops surfacing ---
	var owned_fence := Quests.refill([], 0, ne_ul, [], {}, ["hen_coop", "dairy_stall"], 1, 6, RandomNumberGenerator.new())
	ok(owned_fence.filter(func(q): return q.has("reward") and (q.reward as Dictionary).has("generators")).is_empty(), "no quest carries the grant once both next-map generators are owned (in gen_bag)")

	# --- the final map grants nothing (no next map) ---
	var last := G.MAPS.size() - 1
	var last_ul := {}
	for i in G.MAPS[last].spots.size() - 1:
		last_ul[String(G.MAPS[last].spots[i].id)] = true
	var last_fence := Quests.refill([], last, last_ul, [], {}, [], 1, 6, RandomNumberGenerator.new())
	ok(last_fence.filter(func(q): return q.has("reward") and (q.reward as Dictionary).has("generators")).is_empty(), "the final map's near-end quests carry no generator grant (nothing to grant)")

	# --- fence_inert (req 1 GREY TRIGGER): the fence goes INERT (greyed, NOT hidden) once the banked ★ can
	# --- finish the WHOLE current map — the exact point the active meter used to empty to nothing. False
	# --- while the player still needs ★, and false on a spots-done map (that map is complete, not a frontier).
	ok(not Quests.fence_inert(0, 0, {}), "fence_inert is false on a fresh map with 0★ (still earning)")
	var z0_cost := G.map_stars_left(0, {})
	ok(not Quests.fence_inert(0, z0_cost - 1, {}), "fence_inert is false one ★ short of finishing the map")
	ok(Quests.fence_inert(0, z0_cost, {}), "fence_inert flips true the moment banked ★ can finish the whole map")
	ok(Quests.fence_inert(0, 999999, {}), "fence_inert stays true with a huge ★ bank")
	var z0_full := {}
	for sp in G.MAPS[0].spots:
		z0_full[String(sp.id)] = true
	ok(not Quests.fence_inert(0, 999999, z0_full), "fence_inert is false on a spots-done map (no frontier work left)")

	# --- refill INERT: instead of emptying when you can finish the map, the fence fills to MAX_GIVERS with
	# --- quests the board renders GREYED + inert, so the fence never goes blank under the lit Purge card. ---
	var rin := Quests.refill([], 0, {}, [], {}, [], 999999, 1, RandomNumberGenerator.new())
	ok(rin.size() == int(G.MAX_GIVERS), "refill fills the inert fence to MAX_GIVERS (greyed), not empty")

	# --- refill INERT keeps the generator-carrier DELIVERABLE: a quest carrying reward.generators stays on
	# --- the fence at out[0] (always rendered, the board keeps it active) so the next map's tools still get
	# --- delivered even though the rest of the fence is greyed. Scenario: map 0 near its end, banked == the
	# --- last spot's cost (can finish the map → inert), map 1's generators not yet owned. ---
	var ne_in := {}
	for i in G.MAPS[0].spots.size() - 1:
		ne_in[String(G.MAPS[0].spots[i].id)] = true
	var ne_cost := G.map_stars_left(0, ne_in)
	ok(Quests.fence_inert(0, ne_cost, ne_in), "the near-end fence with banked == remaining cost is inert")
	var rin2 := Quests.refill([], 0, ne_in, [], {}, [], ne_cost, 6, RandomNumberGenerator.new())
	ok(rin2.size() == int(G.MAX_GIVERS), "the inert near-end fence is full (MAX_GIVERS)")
	var in_carriers := rin2.filter(func(q): return q.has("reward") and (q.reward as Dictionary).has("generators"))
	ok(in_carriers.size() == 1, "the inert fence still carries exactly one generator-grant quest")
	ok(rin2[0].has("reward") and (rin2[0].reward as Dictionary).has("generators"), "the generator-carrier sits at out[0] (always rendered → stays deliverable)")

	# --- home_map_id (req 3/4 HOME TARGET): the map id the board's Home/Purge jump targets — the LATEST
	# --- not-fully-unlocked map (the frontier), and the FIRST map once everything is complete. ---
	ok(Quests.home_map_id({}, []) == String(G.MAPS[0].id), "a fresh game's home target is the first map")
	var m0_done := {}
	for sp in G.MAPS[0].spots:
		m0_done[String(sp.id)] = true
	if G.MAPS.size() >= 2:
		ok(Quests.home_map_id(m0_done, [0]) == String(G.MAPS[1].id), "with map 0 complete, the home target advances to map 1 (the frontier)")
	# everything complete → no frontier → home falls back to the FIRST map. Guarded on map_done like the
	# purge-hides test above: today's maps 1+ carry zero regions (a zero-region map never reports done), so
	# the all-complete state is unreachable and this assertion sleeps until those maps gain regions. The
	# first-map OUTCOME is still exercised reachably by the fresh-game assertion above (frontier 0 → MAPS[0]).
	var every := {}
	for zz in G.MAPS.size():
		for sp in G.MAPS[zz].spots:
			every[String(sp.id)] = true
	var every_gate: Array = []
	for zz in G.MAPS.size():
		every_gate.append(zz)
	if Quests.map_done(every, every_gate):
		ok(Quests.home_map_id(every, every_gate) == String(G.MAPS[0].id), "with everything complete, the home target falls back to the first map")

	# --- the GENERATOR-DELIVERY GATE: a non-final map's COMPLETION — restoring its LAST spot — is refused
	# --- until the next map's generator is owned (delivered to the board or the gen_bag). This is the hard
	# --- guard behind the near-end carrier: a player can no longer bank enough ★ to buy the final spot and
	# --- skip into the next map without ever taking that map's tool (the bug that stranded a Barn save with
	# --- no producer). A non-completing spot is never gated; the final map (no next gen) is never gated. ---
	var gate_ul := {}
	for i in G.MAPS[0].spots.size() - 1:
		gate_ul[String(G.MAPS[0].spots[i].id)] = true
	var gate_last := String(G.MAPS[0].spots[G.MAPS[0].spots.size() - 1].id)
	var gate_first := String(G.MAPS[0].spots[0].id)
	ok(Quests.gen_gate_blocks_spot(0, gate_last, gate_ul, []), "the completing spot is blocked while the next map's generator is unowned")
	ok(not Quests.gen_gate_blocks_spot(0, gate_last, gate_ul, G.gens_to_grant(G.GENERATORS, 0, [])), "the completing spot is allowed once the next map's generator is owned")
	ok(not Quests.gen_gate_blocks_spot(0, gate_first, {}, []), "a non-completing spot purchase is never gated")
	var glast := G.MAPS.size() - 1
	var glast_ul := {}
	for i in G.MAPS[glast].spots.size() - 1:
		glast_ul[String(G.MAPS[glast].spots[i].id)] = true
	var glast_last := String(G.MAPS[glast].spots[G.MAPS[glast].spots.size() - 1].id)
	ok(not Quests.gen_gate_blocks_spot(glast, glast_last, glast_ul, []), "the final map's completion is never gated (no next generator)")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
