extends SceneTree
## Headless tests for the §7 quest engine: level-based reward, gen_quest shape, gate quest, and the soft gate.
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
	rng.seed = 31
	var newest_free := 0
	var newest_avoided := 0
	for _i in 600:
		if int(G.gen_quest(20, hi_lines, rng).line) == 6:
			newest_free += 1
		if int(G.gen_quest(20, hi_lines, rng, [6]).line) == 6:
			newest_avoided += 1
	ok(newest_avoided * 3 < newest_free, "avoid steers the ask off the fenced line (%d→%d)" % [newest_free, newest_avoided])

	# --- the soft gate (gate_pause): active giver count metered to the next unlock (§7) ---
	ok(G.active_giver_count(0, -1) == 0, "no active givers when every spot is owned (next_cost -1)")
	ok(G.active_giver_count(10, 5) == 0, "the fence empties once the next unlock is affordable (banked ≥ cost)")
	ok(G.active_giver_count(0, 100) == int(G.MAX_GIVERS), "a far-off unlock caps the fence at MAX_GIVERS")
	ok(G.active_giver_count(3, 4) == 1, "one ★ short → a single giver (ceil(1 / stars-per-quest))")
	var shrinks := G.active_giver_count(0, 8) >= G.active_giver_count(4, 8) and G.active_giver_count(4, 8) >= G.active_giver_count(6, 8)
	ok(shrinks, "the active count shrinks monotonically as stars bank toward the unlock")

	# --- the authored great-spirit GATE quest: single top-tier ask, large reward, unlocks next map (§7) ---
	var gq := G.gate_quest(G.GENERATORS, 0, rng)
	ok(bool(gq.get("gate", false)), "the gate quest is flagged `gate`")
	ok(gq.has("line"), "the gate quest has a `line` field (flat single-item)")
	var map1_ceiling := mini(int(G.GATE_TIER_BASE) + 0, int(G.TOP_TIER))
	ok(int(gq.tier) == map1_ceiling, "map 1's gate asks its ceiling tier t%d" % map1_ceiling)
	ok(int(gq.reward.stars) == int(G.GATE_STARS) and int(gq.reward.coins) > int(G.GATE_COIN_BONUS), "the gate pays its large authored reward (★ + big coins)")
	var gq_last := G.gate_quest(G.GENERATORS, G.MAPS.size() - 1, rng)
	var last_map_ceiling := mini(int(G.GATE_TIER_BASE) + G.MAPS.size() - 1, int(G.TOP_TIER))
	ok(int(gq_last.tier) == last_map_ceiling, "the final map's gate climbs to its ceiling tier t%d (capped at TOP_TIER t%d)" % [last_map_ceiling, int(G.TOP_TIER)])

	# --- §7: the gate's line is randomized — varies across seeds ---
	var z0_lines := G.lines_for_map(G.GENERATORS, 0)
	if z0_lines.size() > 1:
		var line_set := {}
		for s in 24:
			var rs := RandomNumberGenerator.new(); rs.seed = s
			line_set[int(G.gate_quest(G.GENERATORS, 0, rs).line)] = true
		ok(line_set.size() >= 2, "the gate's asked line VARIES across seeds (%d distinct lines)" % line_set.size())
	var rr1 := RandomNumberGenerator.new(); rr1.seed = 99
	var rr2 := RandomNumberGenerator.new(); rr2.seed = 99
	ok(str(G.gate_quest(G.GENERATORS, 0, rr1)) == str(G.gate_quest(G.GENERATORS, 0, rr2)), "the gate is deterministic for a given seed (reproducible)")
	var det_gq := G.gate_quest(G.GENERATORS, 0)    # rng omitted → deterministic fallback: richest line
	var rich := G.lines_for_map(G.GENERATORS, 0); rich.sort()
	ok(int(det_gq.line) == int(rich[rich.size() - 1]), "rng==null falls back to the deterministic richest line")

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
