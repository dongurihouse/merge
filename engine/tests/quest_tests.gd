extends SceneTree
## Headless tests for the §7 generated-quest engine. Today: the reward — expected
## generator-clicks → stars-first (capped) + coins-overflow. (The ask-GENERATOR's
## level→asks/tier curve + line weighting land once their tunables are set.)
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

func near(a: float, b: float) -> bool:
	return abs(a - b) < 0.01

func _initialize() -> void:
	# --- avg pop value: TIER_ODDS-weighted t1-equivalents per pop (≈1.59 for [.65,.25,.09,.01]) ---
	ok(near(G.avg_pop_value(), 1.59), "avg pop value is the TIER_ODDS-weighted t1-equivalent (got %.4f)" % G.avg_pop_value())

	# --- expected clicks = Σ count×2^(tier-1) raw value / avg pop value ---
	ok(near(G.quest_expected_clicks([{"line": 1, "tier": 1, "count": 1}]), 1.0 / 1.59), "one t1 item ≈ 0.63 clicks")
	ok(near(G.quest_expected_clicks([{"line": 1, "tier": 4, "count": 1}]), 8.0 / 1.59), "one t4 item ≈ 5.03 clicks (8 t1-equivalents)")
	ok(near(G.quest_expected_clicks([{"line": 2, "tier": 2, "count": 2}]), 4.0 / 1.59), "two t2 items ≈ 2.52 clicks (4 t1-equivalents)")
	ok(near(G.quest_expected_clicks([{"line": 1, "tier": 3, "count": 1}, {"line": 2, "tier": 3, "count": 1}]), 8.0 / 1.59), "two t3 asks sum their raw value (8 t1-equivalents)")

	# --- reward: value = clicks × CLICK_TO_VALUE; stars = clamp(round(value), 1, STAR_CAP); coins = overflow ---
	var r1 := G.quest_reward([{"line": 1, "tier": 1, "count": 1}])
	ok(int(r1.stars) == 1 and int(r1.coins) == 0, "a t1 ask pays the 1★ floor, no coins")
	var r4 := G.quest_reward([{"line": 1, "tier": 4, "count": 1}])
	ok(int(r4.stars) == 3 and int(r4.coins) == 2, "a t4 ask caps at 3★ and pays the 2-value overflow as coins")
	var rbig := G.quest_reward([{"line": 1, "tier": 5, "count": 1}, {"line": 2, "tier": 5, "count": 1}, {"line": 3, "tier": 5, "count": 1}])
	ok(int(rbig.stars) == int(G.STAR_CAP) and int(rbig.coins) > 0, "a deep 3-ask quest stays at STAR_CAP ★ and dumps the rest into coins")

	# --- the §3 pacing invariant: stars-per-quest never exceeds STAR_CAP (level ∝ quest COUNT) ---
	var capped := true
	for t in range(1, 8):
		if int(G.quest_reward([{"line": 1, "tier": t, "count": 3}]).stars) > int(G.STAR_CAP):
			capped = false
	ok(capped, "stars never exceed STAR_CAP across tiers t1–t7 (level stays gated by quest count, §3/§7)")
	ok(int(G.quest_reward([{"line": 1, "tier": 1, "count": 1}]).stars) >= 1, "every quest pays at least 1★ (no zero-star quest)")

	# --- coins absorb click-variance: same ★, more coins for the deeper ask ---
	ok(int(G.quest_reward([{"line": 1, "tier": 6, "count": 1}]).coins) > int(r4.coins), "a deeper single ask pays the same ★ but strictly more coins")

	# --- the ask-generator: level-scaled asks, newest-weighted lines, never asks t8 (§7) ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	ok(int(G.gen_quest(1, [1, 2, 3, 4], rng).asks.size()) == 1, "a level-1 quest is a single ask")

	rng.seed = 999
	var hi_lines := [1, 2, 3, 4, 5, 6]
	var newest := 6
	var max_asks := 0
	var all_in_lines := true
	var never_t8 := true
	var count_ok := true
	var star_cap_ok := true
	var newest_tier_capped := true
	for _i in 400:
		var q := G.gen_quest(20, hi_lines, rng)
		max_asks = maxi(max_asks, int(q.asks.size()))
		for a in q.asks:
			if not hi_lines.has(int(a.line)):
				all_in_lines = false
			if int(a.tier) >= G.TOP_TIER or int(a.tier) < 1:
				never_t8 = false
			if int(a.count) < 1 or int(a.count) > 2:
				count_ok = false
			if int(a.line) == newest and int(a.tier) > 3:
				newest_tier_capped = false
		if int(q.reward.stars) > int(G.STAR_CAP):
			star_cap_ok = false
	ok(max_asks == 3, "a high-level quest can carry up to 3 asks")
	ok(all_in_lines, "every generated ask draws from the live lines (producible)")
	ok(never_t8, "a regular quest never asks t8 / an out-of-range tier (t8 = gate-only)")
	ok(count_ok, "ask counts stay 1–2")
	ok(star_cap_ok, "a generated quest's reward ★ never exceeds STAR_CAP")
	ok(newest_tier_capped, "the freshly-debuted (newest) line eases in at ≤ t3")

	rng.seed = 7
	var oldest_hits := 0
	var newest_hits := 0
	for _i in 600:
		for a in G.gen_quest(20, hi_lines, rng).asks:
			if int(a.line) == 1:
				oldest_hits += 1
			if int(a.line) == newest:
				newest_hits += 1
	ok(newest_hits > oldest_hits, "asks lean toward the newest/highest-value line (%d vs %d)" % [newest_hits, oldest_hits])

	var rA := RandomNumberGenerator.new()
	var rB := RandomNumberGenerator.new()
	rA.seed = 42
	rB.seed = 42
	ok(str(G.gen_quest(10, hi_lines, rA)) == str(G.gen_quest(10, hi_lines, rB)), "gen_quest is deterministic for a given seed")

	# --- the soft gate (gate_pause): active giver count metered to the next unlock (§7) ---
	ok(G.active_giver_count(0, -1) == 0, "no active givers when every spot is owned (next_cost -1)")
	ok(G.active_giver_count(0, -2) == int(G.MAX_GIVERS), "the whole frontier level-locked → full fence (pump ★ to level up)")
	ok(G.active_giver_count(10, 5) == 0, "the fence empties once the next unlock is affordable (banked ≥ cost)")
	ok(G.active_giver_count(0, 100) == int(G.MAX_GIVERS), "a far-off unlock caps the fence at MAX_GIVERS")
	ok(G.active_giver_count(3, 4) == 1, "one ★ short → a single giver (ceil(1 / stars-per-quest))")
	var shrinks := G.active_giver_count(0, 8) >= G.active_giver_count(4, 8) and G.active_giver_count(4, 8) >= G.active_giver_count(6, 8)
	ok(shrinks, "the active count shrinks monotonically as stars bank toward the unlock")

	# --- the authored great-spirit GATE quest: top-tier asks, large reward, unlocks next map (§7) ---
	var gq := G.gate_quest(G.GENERATORS, 0, rng)
	ok(bool(gq.get("gate", false)), "the gate quest is flagged `gate`")
	var map1_ceiling := mini(int(G.GATE_TIER_BASE) + 0, int(G.TOP_TIER))
	var all_ceiling := true
	var gate_lines := {}
	for a in gq.asks:
		if int(a.tier) != map1_ceiling:
			all_ceiling = false
		gate_lines[int(a.line)] = true
	ok(all_ceiling, "map 1's gate asks its ceiling tier t%d (not the engine top yet)" % map1_ceiling)
	ok(gq.asks.size() == gate_lines.size(), "the gate asks distinct lines (no duplicate ask)")
	ok(gq.asks.size() == mini(int(G.GATE_ASK_COUNT), G.lines_for_map(G.GENERATORS, 0).size()), "the gate asks GATE_ASK_COUNT of the map's lines")
	ok(int(gq.reward.stars) == int(G.GATE_STARS) and int(gq.reward.coins) > int(G.GATE_COIN_BONUS), "the gate pays its large authored reward (★ + big coins)")
	var gq_last := G.gate_quest(G.GENERATORS, G.MAPS.size() - 1, rng)
	var last_is_top := true
	for a in gq_last.asks:
		if int(a.tier) != int(G.TOP_TIER):
			last_is_top = false
	ok(last_is_top, "the final map's gate climbs to the engine top tier (t%d)" % int(G.TOP_TIER))

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
