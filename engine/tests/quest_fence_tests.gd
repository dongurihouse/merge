extends SceneTree
## Headless tests for core/quests.gd — the §7 fence-COMPOSITION layer that sits above
## the quest engine in content.gd (G.gen_quest / active_giver_count). board.gd's instance
## methods (_quest_map/_refill_quests/…) are thin Save-reading wrappers over these pure
## statics, so the fence decision is testable with no scene/window/Save.
##   godot --headless --path . -s res://engine/tests/quest_fence_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const Quests = preload("res://engine/scripts/core/quests.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")

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
	# --- reward readers: new {reward:{…}} shape and the legacy flat {exp} shape ---
	var q_new := {"reward": {"exp": 3, "coins": 5, "gems": 1}}
	ok(Quests.exp(q_new) == 3, "exp() reads reward.exp")
	ok(Quests.coins(q_new) == 5, "coins() reads reward.coins")
	ok(Quests.gems(q_new) == 1, "gems() reads reward.gems")
	var q_legacy := {"exp": 2}
	ok(Quests.exp(q_legacy) == 2, "exp() falls back to the flat legacy key")
	ok(Quests.coins(q_legacy) == 0 and Quests.gems(q_legacy) == 0, "legacy quests pay no coins/gems")
	ok(Quests.gems({"reward": {"exp": 1, "coins": 0}}) == 0, "a normal (non-featured) quest has 0 gems")
	# a reward dict that OMITS a key must read 0, never crash (a coins-only / gems-only reward — e.g. the
	# workbench's demo giver). Dot-access (q.reward.exp) blew up here; the readers .get() with a default now.
	ok(Quests.exp({"reward": {"coins": 4}}) == 0, "exp() reads 0 from a reward with no exp (no crash)")
	ok(Quests.coins({"reward": {"exp": 2}}) == 0, "coins() reads 0 from a reward with no coins (no crash)")

	# --- map / map_done on a fresh game (no spots owned, no gates delivered) ---
	ok(Quests.current_map({}, []) == 0, "a fresh game's frontier is map 0")
	ok(not Quests.map_done({}, []), "a fresh game is not map-done (a frontier exists)")

	# --- gate_ready: the FIRST spot costs one even increment (spot_unlock_exp(0,0) > 0), so a fresh
	# --- map is NOT claimable at 0 exp — it becomes ready only once exp reaches that threshold ---
	var own0 := {String(G.MAPS[0].spots[0].id): true}
	var first_cost := G.spot_unlock_exp(0, 0)
	ok(first_cost > 0, "the first spot is no longer free — it costs one even increment of exp")
	ok(not Quests.gate_ready(0, 0, {}), "a fresh map is NOT claimable at 0 exp (the first unlock costs exp)")
	ok(Quests.gate_ready(0, first_cost, {}), "the first spot becomes claimable once exp reaches its threshold")
	ok(not Quests.gate_ready(0, 0, own0), "with spot 0 claimed, 0 exp can't reach spot 1's threshold (not ready)")
	ok(Quests.gate_ready(0, 999999, {}), "a huge exp total clears the next spot's threshold (ready)")
	ok(is_equal_approx(Quests.purge_progress(0, 0, {}), 0.0), "purge progress starts empty on a fresh map")
	ok(is_equal_approx(Quests.purge_progress(0, first_cost, {}), 1.0), "purge progress reaches full at the next unlock threshold")
	if G.MAPS[0].spots.size() > 1:
		var second_cost := G.spot_unlock_exp(0, 1)
		ok(is_equal_approx(Quests.purge_progress(0, first_cost, own0), 0.0), "purge progress resets after claiming the first spot")
		ok(is_equal_approx(Quests.purge_progress(0, second_cost, own0), 1.0), "purge progress fills to the next claimed spot threshold")

	# --- purge_state: the fence Purge card SHOWs while a frontier remains (always), is READY when total
	# --- exp clears the next threshold, and carries the exp total to display ---
	var ps_poor := Quests.purge_state(0, 0, own0, [])
	ok(ps_poor.show and not ps_poor.ready, "purge card shows but is not ready when 0 exp is short of spot 1")
	ok(int(ps_poor.exp) == 0, "purge card carries the exp total (0)")
	var ps_rich := Quests.purge_state(0, 999999, {}, [])
	ok(ps_rich.show and ps_rich.ready, "purge card is ready (breathes) once exp clears the next threshold")
	ok(int(ps_rich.exp) == 999999, "purge card carries the exp total (999999)")
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

	# --- exp_remaining: exp still needed to make the whole map claimable (highest threshold − exp), floored at 0 ---
	var z0_left := G.map_finish_exp(0, {})
	ok(Quests.exp_remaining(0, {}, 0) == z0_left, "exp_remaining with 0 exp = the map's highest unclaimed threshold")
	ok(Quests.exp_remaining(0, {}, 999999) == 0, "exp_remaining floors at 0 once exp covers every spot")

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
		over.append({"line": 1, "tier": 1, "reward": {"exp": 1, "coins": 0}})
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 1
	ok(Quests.refill(over, 0, {}, [], {}, [], 0, 1, rng2).size() == tgt, "refill trims an over-full fence to the metered target")

	# --- BIRTH-ON-TAP board invariant: a fresh map-0 board seeds + grows to the ANCHOR ONLY (gen_1 / line 1) —
	# --- the produceable set the fence must match. grow_gens is the legacy appear_level staging path; with
	# --- appear_level retired (every gen defaults to 0) it must NOT place the cell-less birth-on-tap gens
	# --- (gen_2..5) — doing so dropped a phantom gen onto the (-1,-1) sentinel cell, which then read as
	# --- "owned" and blocked the real generator's birth-on-tap (board._produce_due_generators). ---
	var pbm := BoardModel.new()
	pbm.seed_gens(0)
	pbm.grow_gens(0, 99)                                # high level: the old path grew EVERY map-0 gen in at once
	ok(not pbm.gens.has(Vector2i(-1, -1)), "grow_gens never registers a phantom generator at the (-1,-1) sentinel")
	var pbm_lines: Array = []
	for pbm_id in pbm.gens.values():
		pbm_lines.append(int(G.gen_def(G.GENERATORS, String(pbm_id)).get("line", 0)))
	pbm_lines.sort()
	ok(pbm_lines == [1], "a fresh map-0 board is anchor-only (line 1); birth-on-tap gens are not grown by level")

	# --- item anti-repeat (§7): refill steers a NEW ask off the recent-items window (the last ≤5 asked
	# --- item codes, line*100+tier) — a HARD exclusion (the same item-code avoid set the concurrent-fence
	# --- stands use). When the item pool is too small to honour the whole window it relaxes the OLDEST
	# --- asks first, never the freshest. A different TIER of the same line still counts as variety. ---
	# #12: the quest pool is the rolling window of the last QUEST_GEN_CAP base lines at the current zone —
	# drive a realistic mid-map-0 progression (6 spots restored → lines 1-5) so the pool has ≥2 lines.
	var rl_unl := {}
	for i in 6:
		rl_unl[str(i)] = true
	var pool := G.quest_base_lines(rl_unl.size())
	if pool.size() >= 2:
		# target the newest line at its tier-bell centre (the most-asked item) so the free count is non-zero
		var fence_hi := clampi(int(G.QUEST_TIER_BASE) + int(6 / float(G.QUEST_LEVELS_PER_TIER)), int(G.QUEST_TIER_BASE), int(G.TOP_TIER))
		var rl_target := int(pool[pool.size() - 1]) * 100 + int((int(G.QUEST_TIER_BASE) + fence_hi) / 2)
		var rl_free := 0
		var rl_avoid := 0
		for s in 200:
			var rf := RandomNumberGenerator.new(); rf.seed = s
			for q in Quests.refill([], 0, rl_unl, [], {}, [], 0, 6, rf):
				var it := G.quest_item(q)
				if int(it.line) * 100 + int(it.tier) == rl_target:
					rl_free += 1
			var ra := RandomNumberGenerator.new(); ra.seed = s
			for q in Quests.refill([], 0, rl_unl, [], {}, [], 0, 6, ra, [rl_target]):
				var it := G.quest_item(q)
				if int(it.line) * 100 + int(it.tier) == rl_target:
					rl_avoid += 1
		ok(rl_free > 0 and rl_avoid < rl_free, "refill steers new asks off the recent-items window (%d→%d)" % [rl_free, rl_avoid])
		# determinism is preserved with a recent-items window (same seed → same fence)
		var rd1 := RandomNumberGenerator.new(); rd1.seed = 9
		var rd2 := RandomNumberGenerator.new(); rd2.seed = 9
		ok(str(Quests.refill([], 0, {}, [], {}, [], 0, 6, rd1, [rl_target])) == str(Quests.refill([], 0, {}, [], {}, [], 0, 6, rd2, [rl_target])), "refill stays deterministic with a recent-items window")

	# --- NO TWO IN A ROW on a tiny pool: a 2-line pool is smaller than the recent window (5), so
	# --- priority relaxation must still keep CONSECUTIVE asks distinct (the bug: the old soft fallback
	# --- repeated). Uses a fixed 2-line pool to model the early FTUE board. Mirrors board.gd's window. ---
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

	# --- the carrier mechanism is RETIRED: refill NEVER attaches reward.generators (generators now arrive
	# --- when a generator tap produces a DUE tool — see G.due_generators / board._produce_due_generators).
	# --- Scenario: all of map 0's spots bought except the last, so a non-empty metered fence still exists. ---
	var ne_ul := {}
	for i in G.MAPS[0].spots.size() - 1:
		ne_ul[String(G.MAPS[0].spots[i].id)] = true
	var rngz := RandomNumberGenerator.new(); rngz.seed = 11
	var nfence := Quests.refill([], 0, ne_ul, [], {}, [], 1, 6, rngz)
	ok(not nfence.is_empty(), "the metered fence is non-empty near the end of the map")
	ok(nfence.filter(func(q): return q.has("reward") and (q.reward as Dictionary).has("generators")).is_empty(), "refill never attaches reward.generators (carrier retired)")
	var no_special2 := true
	for q in nfence:
		if bool(q.get("gate", false)) or q.has("grant"):
			no_special2 = false
	ok(no_special2, "the near-end fence is ordinary quests — no gate/grant/generator quest type")

	# --- fence_inert (req 1 GREY TRIGGER): the fence goes INERT (greyed, NOT hidden) once the banked ★ can
	# --- finish the WHOLE current map — the exact point the active meter used to empty to nothing. False
	# --- while the player still needs ★, and false on a spots-done map (that map is complete, not a frontier).
	ok(not Quests.fence_inert(0, 0, {}), "fence_inert is false on a fresh map with 0 exp (still earning)")
	var z0_cost := G.map_finish_exp(0, {})
	ok(not Quests.fence_inert(0, z0_cost - 1, {}), "fence_inert is false one exp short of finishing the map")
	ok(Quests.fence_inert(0, z0_cost, {}), "fence_inert flips true the moment exp can claim the whole map")
	ok(Quests.fence_inert(0, 999999, {}), "fence_inert stays true with a huge exp total")
	var z0_full := {}
	for sp in G.MAPS[0].spots:
		z0_full[String(sp.id)] = true
	ok(not Quests.fence_inert(0, 999999, z0_full), "fence_inert is false on a spots-done map (no frontier work left)")

	# --- refill INERT: instead of emptying when you can finish the map, the fence fills to MAX_GIVERS with
	# --- quests the board renders GREYED + inert, so the fence never goes blank under the lit Purge card. ---
	var rin := Quests.refill([], 0, {}, [], {}, [], 999999, 1, RandomNumberGenerator.new())
	ok(rin.size() == int(G.MAX_GIVERS), "refill fills the inert fence to MAX_GIVERS (greyed), not empty")

	# --- refill INERT carries NO generator quest either (carrier retired): the inert fence is ordinary greyed
	# --- quests; the next map's tool is produced by a generator tap once that map unlocks, not delivered here. ---
	var ne_in := {}
	for i in G.MAPS[0].spots.size() - 1:
		ne_in[String(G.MAPS[0].spots[i].id)] = true
	var ne_cost := G.map_finish_exp(0, ne_in)
	ok(Quests.fence_inert(0, ne_cost, ne_in), "the near-end fence with exp == the last threshold is inert")
	var rin2 := Quests.refill([], 0, ne_in, [], {}, [], ne_cost, 6, RandomNumberGenerator.new())
	ok(rin2.size() == int(G.MAX_GIVERS), "the inert near-end fence is full (MAX_GIVERS)")
	ok(rin2.filter(func(q): return q.has("reward") and (q.reward as Dictionary).has("generators")).is_empty(), "the inert fence attaches no generator reward (carrier retired)")

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

	# --- giver FACES (req: "no same quest giver on screen"): board.gd assigns each quest a portrait index.
	# --- pick_giver's HARD rule is on-screen uniqueness — never a face already on a LIVE quest; the recency
	# --- window is a SOFT preference, relaxed BEFORE uniqueness when the pool is too small to honour both. ---
	var gpool := 16
	# never returns a face already on a live quest (the on-screen rule), across many seeds
	var hard_ok := true
	for s in 200:
		var rg := RandomNumberGenerator.new(); rg.seed = s
		var pick := Quests.pick_giver([0, 1, 2], [], gpool, rg)
		if [0, 1, 2].has(pick) or pick < 0 or pick >= gpool:
			hard_ok = false
	ok(hard_ok, "pick_giver never returns a face already on a live quest")
	# avoids the recency window too when the pool has room (soft variety honoured)
	var soft_ok := true
	for s in 200:
		var rg2 := RandomNumberGenerator.new(); rg2.seed = s
		var pick2 := Quests.pick_giver([0], [1, 2, 3], gpool, rg2)
		if [0, 1, 2, 3].has(pick2):
			soft_ok = false
	ok(soft_ok, "pick_giver avoids the recency window when the pool has room")
	# pool too small for both rules → drop recency, KEEP uniqueness (pool 5, used+recent cover all 5 faces)
	var relax_ok := true
	for s in 50:
		var rg3 := RandomNumberGenerator.new(); rg3.seed = s
		var pick3 := Quests.pick_giver([0, 1], [2, 3, 4], 5, rg3)
		if [0, 1].has(pick3) or pick3 < 0 or pick3 >= 5:
			relax_ok = false
	ok(relax_ok, "pick_giver relaxes recency before uniqueness when the pool is tight")
	# graceful: when EVERY face is already in use it still returns a valid index (cannot avoid a repeat, no crash)
	var fb := Quests.pick_giver([0, 1, 2], [], 3, RandomNumberGenerator.new())
	ok(fb >= 0 and fb < 3, "pick_giver returns a valid index even when the whole pool is in use (graceful)")

	# assign_givers: fill every quest's face + de-dupe collisions so no two LIVE quests share one
	var gq: Array = [{}, {}, {}, {}, {}]
	var grecent: Array = []
	Quests.assign_givers(gq, grecent, gpool, RandomNumberGenerator.new())
	var all_have := true
	var gseen := {}
	for q in gq:
		if not q.has("giver"):
			all_have = false
		else:
			gseen[int(q["giver"])] = true
	ok(all_have, "assign_givers gives every quest a face")
	ok(gseen.size() == gq.size(), "assign_givers leaves no two live quests sharing a face (%d/%d unique)" % [gseen.size(), gq.size()])
	ok(grecent.size() == gq.size(), "assign_givers records each pick in the recency window")
	# de-dupes a PRE-EXISTING collision (a save written before this fix could carry two equal faces)
	var dup: Array = [{"giver": 3}, {"giver": 3}, {"giver": 7}]
	Quests.assign_givers(dup, [], gpool, RandomNumberGenerator.new())
	ok(int(dup[0]["giver"]) != int(dup[1]["giver"]) and int(dup[1]["giver"]) != int(dup[2]["giver"]) and int(dup[0]["giver"]) != int(dup[2]["giver"]), "assign_givers reassigns a pre-existing duplicate so the fence is distinct")
	# STABILITY: an already-distinct set is left untouched (faces must not churn on every refill)
	var stable: Array = [{"giver": 5}, {"giver": 6}, {"giver": 7}]
	Quests.assign_givers(stable, [], gpool, RandomNumberGenerator.new())
	ok(int(stable[0]["giver"]) == 5 and int(stable[1]["giver"]) == 6 and int(stable[2]["giver"]) == 7, "assign_givers leaves an already-distinct fence unchanged (stable faces)")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
