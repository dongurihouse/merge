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

func _line_counts(qs: Array) -> Dictionary:
	var out := {}
	for q in qs:
		var it := G.quest_item(q)
		if it.is_empty():
			continue
		var line := int(it.line)
		out[line] = int(out.get(line, 0)) + 1
	return out

func _max_line_count(qs: Array) -> int:
	var out := 0
	for count in _line_counts(qs).values():
		out = maxi(out, int(count))
	return out

func _unique_item_count(qs: Array) -> int:
	var seen := {}
	for q in qs:
		var it := G.quest_item(q)
		if it.is_empty():
			continue
		seen[int(it.line) * 100 + int(it.tier)] = true
	return seen.size()

func _initialize() -> void:
	# --- reward reader: the {reward:{coins,gems}} shape (coins-only since the coin-clock redesign) ---
	var q_new := {"reward": {"coins": 5, "gems": 1}}
	ok(Quests.coins(q_new) == 5, "coins() reads reward.coins")
	ok(Quests.gems(q_new) == 1, "gems() reads reward.gems")
	var q_legacy := {"exp": 2}
	ok(Quests.coins(q_legacy) == 0 and Quests.gems(q_legacy) == 0, "legacy quests pay no coins/gems")
	ok(Quests.gems({"reward": {"coins": 0}}) == 0, "a normal (non-featured) quest has 0 gems")
	# a reward dict that OMITS a key must read 0, never crash (e.g. the workbench's demo giver).
	ok(Quests.coins({"reward": {"gems": 2}}) == 0, "coins() reads 0 from a reward with no coins (no crash)")

	# --- current_band: the reward band follows the level-reached zone through the frozen banding ---
	ok(Quests.current_band(1) == 0, "a fresh game (L1) pays at band 0")
	ok(Quests.current_band(99) == G.ZONE_BAND.size() - 1, "a maxed level pays at the last band")

	# --- the vase = the level bar on the coin clock: fills toward the NEXT level threshold ---
	var l2_cost := G.coins_at_level(2)
	ok(l2_cost > 0, "the first level-up costs organic coins")
	ok(is_equal_approx(Quests.purge_progress(0), 0.0), "purge progress starts empty on a fresh save")
	ok(is_equal_approx(Quests.purge_progress(l2_cost), 0.0), "purge progress resets at the moment of a level-up")
	# "one coin short" needs a level-up GAP bigger than a couple of coins to be distinguishable from
	# "just reset" — the re-spined curve's very first gap (L1→L2) is LEVEL_BASE_COINS itself (solved to a
	# small value for the 25-day calendar), too thin for that fencepost. The gap grows every level
	# (LEVEL_STEP_COINS), so probe a level deep enough into the curve that the gap is comfortably >10 coins.
	var deep_lvl := 20
	var deep_cost := G.coins_at_level(deep_lvl + 1)
	ok(deep_cost - G.coins_at_level(deep_lvl) > 10, "fixture: the L%d→L%d gap is wide enough to test the fencepost" % [deep_lvl, deep_lvl + 1])
	ok(Quests.purge_progress(deep_cost - 1) > 0.9, "purge progress is nearly full one coin short of the level")

	# --- purge_state: ALWAYS shows (endless fence — levels are unbounded), READY at the brim, carries earned ---
	var ps_poor := Quests.purge_state(0)
	ok(ps_poor.show and not ps_poor.ready, "purge card shows but is not ready on a fresh save")
	ok(int(ps_poor.exp) == 0, "purge card carries the earned total (0)")
	var arc_done := G.arc_finish_threshold()
	ok(Quests.purge_state(arc_done).show, "purge card still shows at the old arc threshold (endless fence)")
	ok(Quests.purge_state(arc_done * 10).show, "purge card still shows far past the old arc threshold")

	# --- meter_target: the live fence is ALWAYS full (MAX_GIVERS) — quests are endless, no arc taper ---
	ok(int(G.MAX_GIVERS) == 8, "the quest fence caps at 8 live quest cards")
	ok(Quests.meter_target() == int(G.MAX_GIVERS), "meter_target is a flat MAX_GIVERS (no taper)")

	# --- owned_gens: the union of board generators and gen_bag ids ---
	ok(str(Quests.owned_gens({Vector2i(0, 0): "a", Vector2i(1, 1): "b"}, ["c"])) == str(["a", "b", "c"]), "owned_gens unions board generators and the gen_bag")

	# --- refill: the normal stream fills to the metered target with non-gate/grant quests ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var r := Quests.refill([], 0, {}, [], 0, 1, rng)
	ok(r.size() == 4, "a fresh one-line game shows only 4 quests, not the full fence (%d)" % r.size())
	ok(_max_line_count(r) <= 4, "fresh quests never exceed the 4-per-line cap")
	ok(_unique_item_count(r) == r.size(), "fresh quests keep distinct item-code asks while capped")
	var no_special := true
	for q in r:
		if bool(q.get("gate", false)) or q.has("grant"):
			no_special = false
	ok(no_special, "the normal stream carries no gate or grant quest")

	# With enough live lines, the fence can still fill to the global cap, while no single line
	# occupies more than four cards. DERIVED, not hardcoded: the window holds 2 lines exactly once the
	# second zone unlocks (see G.zone_unlock_level(1) / second_zone_level below), which is enough for
	# 2 x MAX_QUESTS_PER_LINE = MAX_GIVERS.
	var multi_line_level := G.zone_unlock_level(1)
	var full_unl := {}
	for i in 6:
		full_unl[str(i)] = true
	var rf_full := RandomNumberGenerator.new(); rf_full.seed = 4242
	var full_fence := Quests.refill([], 0, {}, [], 0, multi_line_level, rf_full)
	ok(full_fence.size() == int(G.MAX_GIVERS), "a multi-line pool can fill the 8-card fence")
	ok(_max_line_count(full_fence) <= 4, "the live fence allows at most 4 quests from any single line")
	ok(_unique_item_count(full_fence) == full_fence.size(), "the full fence keeps distinct concurrent item-code asks")

	# Quest ask variety follows level progress, not restored-zone count: a player who keeps doing quests
	# without claiming new restore spots should still see newer lines enter the fence.
	var rl_level := RandomNumberGenerator.new(); rl_level.seed = 4242
	var level_fence := Quests.refill([], 0, {}, [], 0, multi_line_level, rl_level)
	var level_counts := _line_counts(level_fence)
	ok(level_fence.size() == int(G.MAX_GIVERS), "a high-level player with no new zones restored still fills the 8-card fence")
	ok(level_counts.size() >= 2, "level-based quest progress includes newer lines even when unlocks are empty")
	ok(_max_line_count(level_fence) <= 4, "level-based quest progress still respects the 4-per-line cap")
	ok(_unique_item_count(level_fence) == level_fence.size(), "level-based quest progress keeps distinct concurrent item-code asks")

	# --- refill is deterministic for a given seed (the rng is seeded + persisted; order is load-bearing) ---
	var rA := RandomNumberGenerator.new(); rA.seed = 7
	var rB := RandomNumberGenerator.new(); rB.seed = 7
	ok(str(Quests.refill([], 0, {}, [], 0, 1, rA)) == str(Quests.refill([], 0, {}, [], 0, 1, rB)), "refill is deterministic for a given seed")

	# --- refill trims an over-full fence back down to the target ---
	var over: Array = []
	for _i in int(G.MAX_GIVERS) + 3:
		over.append({"line": 1, "tier": 1, "reward": {"coins": 1}})
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 1
	ok(Quests.refill(over, 0, {}, [], 0, 1, rng2).size() == 4, "refill trims an over-full one-line fence to the line-capped target")

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
	ok(pbm_lines == [1], "a fresh map-0 board is anchor-only (line 1); birth-on-tap gens are not pre-grown by grow_gens")

	# --- item anti-repeat (§7): refill steers a NEW ask off the recent-items window (the last ≤5 asked
	# --- item codes, line*100+tier) — a HARD exclusion (the same item-code avoid set the concurrent-fence
	# --- stands use). When the item pool is too small to honour the whole window it relaxes the OLDEST
	# --- asks first, never the freshest. A different TIER of the same line still counts as variety. ---
	# §7: the quest pool is the ACTIVE-LINE WINDOW reached by level — drive a realistic mid-map-0
	# progression (level 6 → multiple lines) so the pool has ≥2 lines.
	var rl_unl := {}
	for i in 6:
		rl_unl[str(i)] = true
	var anti_repeat_level := 6
	var pool := G.active_lines(anti_repeat_level)
	if pool.size() >= 2:
		# target the newest line at its tier-bell centre (the most-asked item) so the free count is non-zero
		var fence_hi := clampi(int(G.QUEST_TIER_BASE) + int(anti_repeat_level / float(G.QUEST_LEVELS_PER_TIER)), int(G.QUEST_TIER_BASE), int(G.TOP_TIER))
		var rl_target := int(pool[pool.size() - 1]) * 100 + int((int(G.QUEST_TIER_BASE) + fence_hi) / 2)
		var rl_free := 0
		var rl_avoid := 0
		for s in 200:
			var rf := RandomNumberGenerator.new(); rf.seed = s
			for q in Quests.refill([], 0, {}, [], 0, anti_repeat_level, rf):
				var it := G.quest_item(q)
				if int(it.line) * 100 + int(it.tier) == rl_target:
					rl_free += 1
			var ra := RandomNumberGenerator.new(); ra.seed = s
			for q in Quests.refill([], 0, {}, [], 0, anti_repeat_level, ra, [rl_target]):
				var it := G.quest_item(q)
				if int(it.line) * 100 + int(it.tier) == rl_target:
					rl_avoid += 1
		ok(rl_free > 0 and rl_avoid < rl_free, "refill steers new asks off the recent-items window (%d→%d)" % [rl_free, rl_avoid])
		# determinism is preserved with a recent-items window (same seed → same fence)
		var rd1 := RandomNumberGenerator.new(); rd1.seed = 9
		var rd2 := RandomNumberGenerator.new(); rd2.seed = 9
		ok(str(Quests.refill([], 0, {}, [], 0, anti_repeat_level, rd1, [rl_target])) == str(Quests.refill([], 0, {}, [], 0, anti_repeat_level, rd2, [rl_target])), "refill stays deterministic with a recent-items window")

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
	# --- when a generator tap produces a DUE tool — see Quests.due_gen / board._produce_due_generators).
	# --- Scenario: all of map 0's spots bought except the last, so a non-empty metered fence still exists. ---
	var rngz := RandomNumberGenerator.new(); rngz.seed = 11
	var nfence := Quests.refill([], 0, {}, [], 1, 6, rngz)
	ok(not nfence.is_empty(), "the metered fence is non-empty near the end of the map")
	ok(nfence.filter(func(q): return q.has("reward") and (q.reward as Dictionary).has("generators")).is_empty(), "refill never attaches reward.generators (carrier retired)")
	var no_special2 := true
	for q in nfence:
		if bool(q.get("gate", false)) or q.has("grant"):
			no_special2 = false
	ok(no_special2, "the near-end fence is ordinary quests — no gate/grant/generator quest type")

	# --- ENDLESS FENCE (2026-07-23, owner call): the fence NEVER goes inert/grey and NEVER tapers. The old
	# --- fence_inert "endgame quiet" is retired — at the time it gated on the 12-zone quest roster (all zones
	# --- by ~L13), far short of the real map/cluster arc (25 clusters → ~L26), greying the fence out mid-game.
	# --- The zone cadence is now derived from the owner-authored SCENE_END_LEVEL band (re-spined 2026-07-26;
	# --- 12 zones to L54, 25 clusters to L58), but the fence still does not gate on either: past the old
	# --- arc-finish threshold (and far beyond) refill still fills a FULL fence of ordinary, live quests. ---
	var deep_earned := G.arc_finish_threshold() * 5
	var rdeep := Quests.refill([], 0, {}, [], deep_earned, multi_line_level, RandomNumberGenerator.new())
	ok(rdeep.size() == int(G.MAX_GIVERS), "the fence stays full (MAX_GIVERS) far past the old arc threshold")
	ok(_max_line_count(rdeep) <= 4, "the endless fence still obeys the 4-per-line cap")
	ok(rdeep.filter(func(q): return q.has("grant") or bool(q.get("gate", false))).is_empty(), "the endless fence is ordinary quests — no gate/grant type")
	ok(rdeep.filter(func(q): return q.has("reward") and (q.reward as Dictionary).has("generators")).is_empty(), "the endless fence attaches no generator reward (carrier retired)")

	# --- earned no longer affects the fence size: a fresh save and a deep-endgame save both fill the same full
	# --- fence for the same level/line pool (earned is ignored by refill now). ---
	var rfresh := RandomNumberGenerator.new(); rfresh.seed = 99
	var rlate := RandomNumberGenerator.new(); rlate.seed = 99
	ok(str(Quests.refill([], 0, {}, [], 0, 6, rfresh)) == str(Quests.refill([], 0, {}, [], deep_earned, 6, rlate)), "refill ignores earned — same full fence early and late")

	# --- a one-line pool is still line-capped to 4 (the endless fence respects per-line caps, not just MAX_GIVERS) ---
	var rone := Quests.refill([], 0, {}, [], deep_earned, 1, RandomNumberGenerator.new())
	ok(rone.size() == 4, "a one-line endless fence is line-capped to 4")

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

	# --- §7 ACTIVE-LINE WINDOW: no-strand over the whole level arc (2026-07-25) ---------------------------
	# The window tightened to ACTIVE_LINE_WINDOW lines, so the two things that could strand a player are
	# (a) the fence starving — too few lines to fill MAX_GIVERS at 4 quests each — and (b) a quest for a
	# line the board can never produce. Both are checked here at EVERY level across the arc AND deep into
	# the endgame re-roll, on several seeds. (`grove_sim` would be the broader check, but it is stale
	# against the coin-clock redesign and crashes on main — see the branch notes.)
	var w_starve := 0
	var w_unproducible := 0
	var w_offwindow := 0
	for lv in range(1, 61):
		var want := mini(int(G.MAX_GIVERS), G.active_lines(lv).size() * int(G.MAX_QUESTS_PER_LINE))
		for sd in 6:
			var wr := RandomNumberGenerator.new(); wr.seed = sd * 977 + lv
			var wf := Quests.refill([], 0, {}, [], 0, lv, wr)
			if wf.size() < want:
				w_starve += 1
			for q in wf:
				var wit := G.quest_item(q)
				if wit.is_empty():
					continue
				# every asked line must resolve to at least one BASE generator — that generator is what
				# birth-on-tap delivers, so the ask is always producible even when the line is a special
				# whose ingredient LINES left the window.
				if G.gens_for_quest_line(int(wit.line)).is_empty():
					w_unproducible += 1
				if not G.active_lines(lv).has(int(wit.line)):
					w_offwindow += 1
	ok(w_starve == 0, "the fence fills to its line capacity at every level L1-L60 (%d starved refills)" % w_starve)
	ok(w_unproducible == 0, "every generated ask resolves to a birthable generator — no-strand (%d unproducible)" % w_unproducible)
	ok(w_offwindow == 0, "every generated ask comes from the active-line window (%d strays)" % w_offwindow)
	# A full fence needs 2+ lines (MAX_QUESTS_PER_LINE per line). Derived from the cadence, not hardcoded:
	# the window widens to 2 lines exactly when the SECOND zone unlocks, so that is when the fence can fill.
	var second_zone_level := G.zone_unlock_level(1)
	ok(mini(int(G.MAX_GIVERS), G.active_lines(second_zone_level).size() * int(G.MAX_QUESTS_PER_LINE)) == int(G.MAX_GIVERS), "the fence can fill all MAX_GIVERS stands from the second zone (L%d) on" % second_zone_level)
	ok(G.active_lines(second_zone_level - 1).size() == 1, "before the second zone the FTUE fence runs on the single anchor line")

	# --- A QUEST RETIRES WITH ITS LINE (2026-07-25 regression guard) ------------------------------------
	# refill used to keep every non-gate stand regardless of line, so a quest whose line had left the
	# ACTIVE-LINE WINDOW sat on the fence forever: unfillable (the board greys its items as junk via
	# quest_needed_lines, which reads the window) yet still counting against MAX_GIVERS. grove_sim measured
	# the end state — the fence silted up with stale stands and quest income hit ZERO at ~L16, permanently,
	# for the rest of the run. This asserts the drop directly, at the refill boundary.
	var stale_level := 16
	var stale_live := G.active_lines(stale_level)
	var stale_line := 0
	for zl in G.ZONE_BASE_LINES:                       # any base line the window has already rolled past
		if not stale_live.has(int(zl)):
			stale_line = int(zl)
			break
	ok(stale_line > 0, "the L%d window (%s) has rolled past at least one line — a stale stand is possible" % [stale_level, str(stale_live)])
	var stale_fence: Array = [{"line": stale_line, "tier": 7, "reward": {"coins": 9}}]
	var sr := RandomNumberGenerator.new(); sr.seed = 4242
	var after := Quests.refill(stale_fence, 0, {}, [], 0, stale_level, sr)
	var kept_stale := 0
	for q in after:
		var qi := G.quest_item(q)
		if not qi.is_empty() and int(qi.line) == stale_line:
			kept_stale += 1
	ok(kept_stale == 0, "refill DROPS a stand whose line left the window (line %d at L%d) — no dead fence slots" % [stale_line, stale_level])
	ok(after.size() == mini(int(G.MAX_GIVERS), stale_live.size() * int(G.MAX_QUESTS_PER_LINE)), "the dropped slot is refilled immediately — the fence stays full")
	for q in after:
		var qi2 := G.quest_item(q)
		ok(qi2.is_empty() or stale_live.has(int(qi2.line)), "every surviving stand asks a line inside the active window")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
