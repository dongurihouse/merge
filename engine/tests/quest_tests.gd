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
	# --- EFFORT-BASED reward: exp=round(clicks/7), coins=round(clicks/cpc[map]×depth), NO acorns ---
	var r4 := G.quest_reward(4)            # t4 = 8 clicks
	ok(int(r4.exp) == int(round(8.0 / float(G.QUEST_CLICKS_PER_EXP))) and not r4.has("gems"), "a t4 quest pays round(8/7)=1 exp and no acorns")
	var r8 := G.quest_reward(8)            # t8 = 128 clicks
	ok(int(r8.exp) == int(round(128.0 / float(G.QUEST_CLICKS_PER_EXP))), "t8 exp = round(128/7) = 18 (effort-based)")
	ok(int(r8.coins) > int(r4.coins), "a deeper-tier quest pays more coins than a shallow one")
	ok(int(G.quest_reward(8, 4).coins) > int(G.quest_reward(8, 0).coins), "later maps pay more coins for the same tier (per-map cpc)")
	var rising := true
	var no_acorns := true
	for L in range(5, 13):
		if int(G.quest_reward(L).exp) <= int(G.quest_reward(L - 1).exp):
			rising = false
		if int(G.quest_reward(L).get("gems", 0)) > 0:
			no_acorns = false
	ok(rising, "exp rises monotonically with tier (effort-based, uncapped)")
	ok(no_acorns, "no quest pays acorns across t4–t12 (Option A — milestone/IAP only)")

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
	# SINGLE-GENERATOR model (idea 3): later maps NEVER grow their own tool — the one map-0 anchor pops
	# every opened line. So unlocking map 1 makes NO new tool due; only a MISSING anchor is ever due.
	ok(G.due_generators(m0_done, [0], anchor_ids).is_empty(), "unlocking map 1 makes NO new tool due (the single anchor serves all lines)")
	for mid in G.generators_for_map(G.GENERATORS, 1).map(func(g): return String(g.id)):
		ok(not G.due_generators(m0_done, [0], anchor_ids).has(mid), "a later map's tool is never due (%s)" % mid)
	ok(str(G.due_generators(m0_done, [0], [])) == str(anchor_ids), "a MISSING anchor is still self-healed (the only thing ever due)")

	# --- askable_lines is ALL OPENED lines (maps 0..map) — old lines no longer retire (idea 3) ---
	for z in G.MAPS.size():
		var opened: Array = []
		for zz in z + 1:
			for l in G.lines_for_map(G.GENERATORS, zz):
				if not opened.has(int(l)):
					opened.append(int(l))
		opened.sort()
		ok(str(G.askable_lines(G.GENERATORS, z)) == str(opened), "askable_lines(map %d) == all opened lines (0..map)" % z)
	var z1_ask := G.askable_lines(G.GENERATORS, 1)
	var z0_only := G.lines_for_map(G.GENERATORS, 0)
	var z1_includes_z0 := true
	for l in z0_only:
		if not z1_ask.has(int(l)):
			z1_includes_z0 = false
	ok(z1_includes_z0, "askable_lines(roster, 1) INCLUDES map-0 lines (opened lines stay askable)")

	# --- economy ceiling + sell economy (Option A: no premium-sell pinnacle, every tier → coins) ---
	ok(int(G.TOP_TIER) == 12, "the merge/ask ceiling is 12")
	ok(int(G.sell_reward(int(G.PREMIUM_TIER)).y) == 0 and int(G.sell_reward(int(G.PREMIUM_TIER)).x) > 0, "t8 (former pinnacle) now sells for COINS, not acorns (Option A)")
	ok(int(G.sell_reward(int(G.TOP_TIER)).y) == 0, "no tier mints acorns on sale (selling never pays premium)")
	var rngc := RandomNumberGenerator.new(); rngc.seed = 5
	var saw_high := false
	for _i in 800:
		if int(G.gen_quest(40, [1,2,3,4,5,6], rngc).tier) >= int(G.PREMIUM_TIER):
			saw_high = true
	ok(saw_high, "a high-level player can be asked at or above the old ceiling")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
