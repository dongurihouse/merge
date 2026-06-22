extends SceneTree
## Headless tests for the §7 quest engine: level-based reward, gen_quest shape, the soft gate, the
## near-end generator grant, and current-map askable lines.
##   godot --headless --path . -s res://engine/tests/quest_tests.gd

const G = preload("res://engine/scripts/core/content.gd")

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
	# --- level-based reward: stars=min(level,CAP), coins=max(0,level-CAP), +gems at >=10 ---
	var r1 := G.quest_reward(1)
	ok(int(r1.stars) == 1 and int(r1.coins) == 0 and not r1.has("gems"), "a level-1 quest pays 1★, no coins, no gems")
	var r6 := G.quest_reward(6)
	ok(int(r6.stars) == int(G.STAR_CAP) and int(r6.coins) == 6 - int(G.STAR_CAP), "level 6 caps stars and pays the surplus in coins")
	var r10 := G.quest_reward(10)
	ok(int(r10.get("gems", 0)) == int(G.QUEST_PREMIUM_GEMS), "level 10 also pays premium 💎")
	ok(not G.quest_reward(9).has("gems"), "level 9 pays no premium 💎")
	var capped := true
	for L in range(1, 13):
		if int(G.quest_reward(L).stars) > int(G.STAR_CAP):
			capped = false
	ok(capped, "stars never exceed STAR_CAP across levels 1–12 (§3 pacing)")

	# --- gen_quest: flat {line, tier}, single item, level-scaled, deterministic ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var q1 := G.gen_quest(1, [1, 2, 3, 4], rng)
	ok(q1.has("line") and q1.has("tier") and not q1.has("asks"), "a quest is flat {line, tier} (no asks array)")
	rng.seed = 999
	var hi_lines := [1, 2, 3, 4, 5, 6]
	var all_in_lines := true
	var tier_ok := true
	for _i in 400:
		var q := G.gen_quest(20, hi_lines, rng)
		if not hi_lines.has(int(q.line)):
			all_in_lines = false
		if int(q.tier) > G.TOP_TIER or int(q.tier) < 1:
			tier_ok = false
	ok(all_in_lines, "every quest draws a live line")
	ok(tier_ok, "every regular quest's tier is within 1..TOP_TIER")
	var rA := RandomNumberGenerator.new(); rA.seed = 42
	var rB := RandomNumberGenerator.new(); rB.seed = 42
	ok(str(G.gen_quest(10, hi_lines, rA)) == str(G.gen_quest(10, hi_lines, rB)), "gen_quest is deterministic for a seed")
	# avoid is a set of ITEM codes (line*100+tier): a HARD-excluded item is never asked while any other
	# candidate item is free. (band [4..12] at level 20, tier bell centred on t8.)
	rng.seed = 31
	var item_free := 0       # how often the free roll asks line 5 / tier 8 (code 508 — a high-weight item)
	var item_avoided := 0    # ... when that exact item is in `avoid`
	for _i in 600:
		var qf := G.gen_quest(20, hi_lines, rng)
		if int(qf.line) * 100 + int(qf.tier) == 508:
			item_free += 1
		var qa := G.gen_quest(20, hi_lines, rng, [508])
		if int(qa.line) * 100 + int(qa.tier) == 508:
			item_avoided += 1
	ok(item_free > 0 and item_avoided == 0, "avoid HARD-excludes the asked ITEM (line+tier) while others stay free (%d→%d)" % [item_free, item_avoided])
	# §7 variety is per-ITEM, not per-line: avoiding one (line, tier) still lets a DIFFERENT tier of the
	# same line be asked, so a small line pool is never starved.
	rng.seed = 7
	var saw_line3_other_tier := false
	var saw_308 := false
	for _i in 800:
		var q := G.gen_quest(20, [2, 3, 4], rng, [308])   # avoid only line 3 / tier 8
		if int(q.line) == 3 and int(q.tier) != 8:
			saw_line3_other_tier = true
		if int(q.line) * 100 + int(q.tier) == 308:
			saw_308 = true
	ok(saw_line3_other_tier and not saw_308, "avoiding one tier still allows OTHER tiers of the same line")
	# fallback: when EVERY candidate item is avoided (pool smaller than the avoid window) the pick still
	# resolves — the band is always [4..TOP_TIER], so one line offers TOP-BASE+1 items; avoid them all.
	rng.seed = 9
	var all_line1: Array = []
	for t in range(int(G.QUEST_TIER_BASE), int(G.TOP_TIER) + 1):
		all_line1.append(100 + t)
	var fb_ok := true
	for _i in 200:
		var q := G.gen_quest(0, [1], rng, all_line1)   # every t4..t12 of line 1 avoided
		if not all_line1.has(int(q.line) * 100 + int(q.tier)):
			fb_ok = false
	ok(fb_ok, "avoid relaxes and still resolves when every candidate item is avoided")

	# --- the soft gate (gate_pause): active giver count metered to the next unlock (§7) ---
	ok(G.active_giver_count(0, -1) == 0, "no active givers when every spot is owned (next_cost -1)")
	ok(G.active_giver_count(10, 5) == 0, "the fence empties once the next unlock is affordable (banked ≥ cost)")
	ok(G.active_giver_count(0, 100) == int(G.MAX_GIVERS), "a far-off unlock caps the fence at MAX_GIVERS")
	ok(G.active_giver_count(3, 4) == 1, "one ★ short → a single giver (ceil(1 / stars-per-quest))")
	var shrinks := G.active_giver_count(0, 8) >= G.active_giver_count(4, 8) and G.active_giver_count(4, 8) >= G.active_giver_count(6, 8)
	ok(shrinks, "the active count shrinks monotonically as stars bank toward the unlock")

	# --- due_generators: the tools the player is OWED — for every UNLOCKED map (map_unlocked, the SAME gate
	# --- signal that surfaces a map's quests, NOT where the camera is), that map's generator if not owned
	# --- (board or bag). Keyed on map UNLOCK, not on visiting a map; monotonic + self-healing. Replaces the
	# --- retired carrier path (gens_to_grant): generators now arrive when a tap produces a DUE tool. ---
	var anchor_ids: Array = G.generators_for_map(G.GENERATORS, 0).map(func(g): return String(g.id))
	ok(G.due_generators({}, [], anchor_ids).is_empty(), "fresh game with map 0's tool owned → nothing due")
	ok(str(G.due_generators({}, [], [])) == str(anchor_ids), "an unlocked map missing its tool is due (the self-heal catch-all)")
	# complete map 0 (all spots restored + the gate recorded) → map 1 unlocks → its tool becomes due
	var m0_done := {}
	for sp in G.MAPS[0].spots:
		m0_done[String(sp.id)] = true
	var map1_ids: Array = G.generators_for_map(G.GENERATORS, 1).map(func(g): return String(g.id))
	ok(str(G.due_generators(m0_done, [0], anchor_ids)) == str(map1_ids), "completing+gating map 0 unlocks map 1 → its tool is due")
	ok(G.due_generators(m0_done, [0], anchor_ids + map1_ids).is_empty(), "a tool already owned (board or bag) is not due")
	# map 1 is still incomplete → map 2 stays LOCKED → its tool is never due (unlock-keyed, not visit-keyed)
	if G.MAPS.size() >= 3:
		var due_at_m1 := G.due_generators(m0_done, [0], anchor_ids + map1_ids)
		for mid in G.generators_for_map(G.GENERATORS, 2).map(func(g): return String(g.id)):
			ok(not due_at_m1.has(mid), "a LOCKED map's tool is never due (%s)" % mid)

	# --- askable_lines is CURRENT-MAP only (no anchor union) — equals lines_for_map, sorted ---
	for z in G.MAPS.size():
		var live := G.lines_for_map(G.GENERATORS, z); live.sort()
		ok(str(G.askable_lines(G.GENERATORS, z)) == str(live), "askable_lines(map %d) == lines_for_map sorted (current-map only)" % z)
	var z1_ask := G.askable_lines(G.GENERATORS, 1)
	var z0_only := G.lines_for_map(G.GENERATORS, 0)
	var z1_excludes_z0 := true
	for l in z0_only:
		if z1_ask.has(int(l)):
			z1_excludes_z0 = false
	ok(z1_excludes_z0, "askable_lines(roster, 1) excludes map-0 lines (old-map lines aren't quested)")

	# --- economy ceiling + PREMIUM_TIER pinning ---
	ok(int(G.TOP_TIER) == 12, "the merge/ask ceiling is 12")
	ok(G.water_to_earn_diamond() == int(pow(2, int(G.PREMIUM_TIER) - 1)), "diamond-earn rate pins to PREMIUM_TIER, not TOP_TIER")
	ok(G.sell_reward(int(G.PREMIUM_TIER)) == Vector2i(0, 1), "the flat-1💎 pinnacle is PREMIUM_TIER")
	ok(int(G.sell_reward(int(G.PREMIUM_TIER) + 1).y) == 0, "a tier above PREMIUM_TIER still sells for coins (not premium)")
	var rngc := RandomNumberGenerator.new(); rngc.seed = 5
	var saw_high := false
	for _i in 800:
		if int(G.gen_quest(40, [1,2,3,4,5,6], rngc).tier) >= int(G.PREMIUM_TIER):
			saw_high = true
	ok(saw_high, "a high-level player can be asked at or above the old ceiling")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
