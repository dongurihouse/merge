extends SceneTree
## Headless tests for the §7 quest engine: level-based reward, gen_quest shape, the soft gate, the
## near-end generator grant, and current-map askable lines.
##   godot --headless --path . -s res://engine/tests/quest_tests.gd

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

	# --- §7 PER-LINE exp ramp + MERGER (special-line) reward: later lines pay more exp; a merger pays
	# QUEST_MERGE_REWARD_FACTOR × its two recipe source lines' COMBINED reward (exp & coins) ---
	var bases: Array = G.ZONE_BASE_LINES
	var first_base := int(bases[0])
	var last_base := int(bases[bases.size() - 1])
	ok(is_equal_approx(G.line_exp_mult(first_base), 1.0), "the first base line's exp multiplier is 1.0 (baseline unchanged)")
	ok(is_equal_approx(G.line_exp_mult(last_base), float(G.QUEST_EXP_LINE_SPREAD)), "the last base line's exp multiplier is QUEST_EXP_LINE_SPREAD")
	var mult_rising := true
	for i in range(1, bases.size()):
		if G.line_exp_mult(int(bases[i])) < G.line_exp_mult(int(bases[i - 1])):
			mult_rising = false
	ok(mult_rising, "line_exp_mult rises monotonically along the base-line rank")
	ok(is_equal_approx(G.line_exp_mult(71), 1.0), "a special/merger line has no rank multiplier (1.0 — it derives its reward from its sources)")
	# a base line: a later line pays MORE exp than the first at the same tier; coins stay map-driven (rank-free)
	ok(int(G.quest_reward_for_line(first_base, 8, 0).exp) == int(G.quest_reward(8, 0).exp), "the first base line's t8 exp is unchanged from the flat reward")
	ok(int(G.quest_reward_for_line(last_base, 8, 0).exp) > int(G.quest_reward_for_line(first_base, 8, 0).exp), "a later base line pays more t8 exp than the first (per-line ramp)")
	ok(int(G.quest_reward_for_line(last_base, 8, 0).coins) == int(G.quest_reward(8, 0).coins), "the per-line ramp lifts EXP only — base-line coins still follow the per-map curve")
	# a merger line (71): exp & coins == FACTOR × the two recipe sources' combined reward, and it beats a base ask
	var z71 := G.zone_of_line(71)
	var srcs71: Array = G.zone_recipe(z71)
	ok(srcs71.size() == 2, "the special line 71 resolves to two recipe source lines")
	var s0 := int(srcs71[0])
	var s1 := int(srcs71[1])
	var sr0 := G.quest_reward_for_line(s0, 8, G.zone_map(G.zone_of_line(s0)))
	var sr1 := G.quest_reward_for_line(s1, 8, G.zone_map(G.zone_of_line(s1)))
	var exp_expected := maxi(1, int(round(float(G.QUEST_MERGE_REWARD_FACTOR) * (float(sr0.exp) + float(sr1.exp)))))
	var coin_expected := maxi(0, int(round(float(G.QUEST_MERGE_REWARD_FACTOR) * (float(sr0.coins) + float(sr1.coins)))))
	var m71 := G.quest_reward_for_line(71, 8, 0)
	ok(int(m71.exp) == exp_expected, "a merger quest's exp = round(FACTOR × combined source exp) = %d" % exp_expected)
	ok(int(m71.coins) == coin_expected, "a merger quest's coins = round(FACTOR × combined source coins) = %d" % coin_expected)
	ok(int(m71.exp) > int(G.quest_reward(8, 0).exp), "a merger quest pays MORE exp than a base quest of the same tier")
	# gen_quest wires the line-aware reward: a single-line pool always asks that line and pays its line-aware exp
	var rngm := RandomNumberGenerator.new(); rngm.seed = 77
	var qm := G.gen_quest(20, [71], rngm)
	ok(int(qm.line) == 71 and int(G.quest_reward_for_line(71, int(qm.tier), 0).exp) == int(qm.reward.exp), "gen_quest pays a merger line its line-aware exp")
	var rngb := RandomNumberGenerator.new(); rngb.seed = 77
	var qb := G.gen_quest(20, [first_base], rngb)
	ok(int(qb.line) == first_base and int(G.quest_reward(int(qb.tier), 0).exp) == int(qb.reward.exp), "gen_quest pays the first base line its (unchanged) flat exp")

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
	# degenerate guard: an empty line pool must not crash on items[0] (a -1 _weighted_index). Unreachable in
	# play (refill always passes ≥1 line) but a one-line safety net — return {} so callers see "no ask".
	ok(G.gen_quest(0, [], rng, [], 0).is_empty(), "gen_quest on an EMPTY line pool returns {} (no items[0] crash)")
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

	# --- due_gen: QUEST-DRIVEN birth-on-tap (gen redesign — LINE_WINDOW retired). A generator is born only
	# when an active quest asks for a line whose generator the player lacks; the gen_1 anchor self-heals FIRST
	# so the very first tap always produces. Reaching a zone no longer grants a tool on its own — quests do. ---
	ok(Quests.due_gen([], []) == "gen_1", "fresh game: the anchor (gen_1) is due even before any quest")
	ok(Quests.due_gen([], ["gen_1"]) == "", "anchor owned + no quest asking → nothing due (progression alone grants no tool)")
	ok(Quests.due_gen([{"line": 2, "tier": 1}], ["gen_1"]) == "gen_2", "a quest asking line 2 makes its generator due")
	ok(Quests.due_gen([{"line": 2, "tier": 1}], ["gen_1", "gen_2"]) == "", "nothing due once the asked line's generator is owned")
	# a SPECIAL quest (71 = merge of base lines 1+2) pulls its missing INGREDIENT generator
	ok(Quests.due_gen([{"line": 71, "tier": 1}], ["gen_1"]) == "gen_2", "a special quest births its missing ingredient generator")
	ok(Quests.due_gen([{"line": 71, "tier": 1}], ["gen_1", "gen_2"]) == "", "a special quest is satisfied once both ingredient generators are owned")

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
