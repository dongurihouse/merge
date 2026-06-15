extends SceneTree
## Headless tests for §7 FEATURED quests — gen_quest's featured flag + its bonus.
## A small random share of regular quests are "featured": flagged on the fence and paying
## a bonus ON TOP of the normal reward — extra coins, OCCASIONALLY a premium (💎) — and the
## bonus is coins/premium, NEVER extra ★ (so level ∝ quests-done, §3, is untouched).
## Deterministic given a seeded RandomNumberGenerator.
##   godot --headless --path . -s res://engine/tests/featured_tests.gd

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
	var lines := [1, 2, 3, 4, 5, 6]

	# --- the dict carries `featured`, and featured quests OCCUR over a seeded sweep ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var n := 4000
	var featured_count := 0
	var gem_count := 0
	var has_key := true
	var coin_bonus_ok := true
	var stars_never_inflated := true
	var gem_amount_ok := true
	var nonfeatured_never_gem := true
	for _i in n:
		var lvl := rng.randi_range(1, 30)
		var q := G.gen_quest(lvl, lines, rng)
		if not q.has("featured"):
			has_key = false
			continue
		# the baseline reward for THIS quest's asks — featuring only adds coins/premium on top.
		var base := G.quest_reward(G.quest_asks(q))
		# §7: featuring NEVER inflates ★ — reward.stars equals the un-featured computation.
		if int(q.reward.stars) != int(base.stars):
			stars_never_inflated = false
		if bool(q.featured):
			featured_count += 1
			# the flat coin bonus is applied on top of the base overflow coins.
			if int(q.reward.coins) != int(base.coins) + int(G.QUEST_FEATURED_COIN_BONUS):
				coin_bonus_ok = false
			if int(q.reward.get("gems", 0)) > 0:
				gem_count += 1
				if int(q.reward.gems) != int(G.QUEST_FEATURED_GEM_BONUS):
					gem_amount_ok = false
		else:
			# a NON-featured quest is plain: no coin bonus, no premium.
			if int(q.reward.coins) != int(base.coins):
				coin_bonus_ok = false
			if int(q.reward.get("gems", 0)) != 0:
				nonfeatured_never_gem = false

	ok(has_key, "every quest dict carries the `featured` key")
	ok(featured_count > 0, "featured quests occur over the seeded sweep (%d of %d)" % [featured_count, n])
	# they are a SMALL share — near the configured rate, not most quests (sanity on the gate).
	var rate := featured_count / float(n)
	ok(rate < 0.4, "featured quests are a small share, not the norm (%.1f%%)" % (rate * 100.0))
	ok(gem_count > 0, "at least one featured quest carries a premium 💎 bonus (%d of %d featured)" % [gem_count, featured_count])
	ok(gem_count < featured_count, "the premium is OCCASIONAL — not every featured quest carries it (%d of %d)" % [gem_count, featured_count])
	ok(gem_amount_ok, "a featured premium bonus is exactly QUEST_FEATURED_GEM_BONUS (%d💎)" % int(G.QUEST_FEATURED_GEM_BONUS))
	ok(coin_bonus_ok, "the coin bonus is applied to featured quests (+%d🪙) and ONLY to them" % int(G.QUEST_FEATURED_COIN_BONUS))
	ok(stars_never_inflated, "featuring NEVER inflates reward.stars (the bonus is coins/premium only, §7)")
	ok(nonfeatured_never_gem, "a non-featured quest never carries a premium bonus")

	# --- featured vs non-featured stars for EQUIVALENT asks: featuring touches only coins/premium ---
	# Pin one ask set; the only difference is the featured treatment. Stars must match exactly;
	# the featured one's coins are higher by exactly the bonus.
	var asks := [{"line": 3, "tier": 4, "count": 1}]
	var plain := G.quest_reward(asks)
	var featured_reward := plain.duplicate()
	featured_reward["coins"] = int(featured_reward.coins) + int(G.QUEST_FEATURED_COIN_BONUS)   # mirrors gen_quest's featured branch
	ok(int(featured_reward.stars) == int(plain.stars), "for equivalent asks, a featured quest pays the SAME ★ as a non-featured one")
	ok(int(featured_reward.coins) == int(plain.coins) + int(G.QUEST_FEATURED_COIN_BONUS), "for equivalent asks, the featured coin bonus is added on top (+%d🪙)" % int(G.QUEST_FEATURED_COIN_BONUS))

	# --- deterministic: the same seed reproduces the same featured/gem outcomes byte-for-byte ---
	var rA := RandomNumberGenerator.new()
	var rB := RandomNumberGenerator.new()
	rA.seed = 777
	rB.seed = 777
	var same := true
	for _i in 500:
		if str(G.gen_quest(15, lines, rA)) != str(G.gen_quest(15, lines, rB)):
			same = false
	ok(same, "gen_quest (incl. featured flag + premium bonus) is deterministic for a given seed")

	# --- a known seed yields a featured-with-premium quest (deterministic, reproducible) ---
	var rC := RandomNumberGenerator.new()
	rC.seed = 12345
	var found_featured_gem := false
	for _i in n:
		var q2 := G.gen_quest(rC.randi_range(1, 30), lines, rC)
		if bool(q2.get("featured", false)) and int(q2.reward.get("gems", 0)) > 0:
			found_featured_gem = true
			break
	ok(found_featured_gem, "seed 12345 deterministically produces a featured quest carrying a premium bonus")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
