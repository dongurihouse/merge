extends SceneTree
## Headless tests for core/quests.gd — the §7 fence-COMPOSITION layer that sits above
## the quest engine in content.gd (G.gen_quest / gate_quest / active_giver_count). board.gd's
## instance methods (_quest_map/_refill_quests/_gate_pending/…) are thin Save-reading wrappers
## over these pure statics, so the fence decision is testable with no scene/window/Save.
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

	# --- gate_pending: map 0 is not spot-complete on a fresh game → no gate yet ---
	ok(not Quests.gate_pending(0, {}, []), "map 0's gate is not pending until its spots are restored")

	# --- gate_ready: 0★ can't afford the next spot; a huge bank at max level can ---
	ok(not Quests.gate_ready(0, 0, {}, 1), "0★ → the next unlock is not affordable (not ready)")
	ok(Quests.gate_ready(0, 999999, {}, 99), "a huge ★ bank at max level can afford the next spot (ready)")

	# --- meter_target: bounded 0..MAX_GIVERS, and shrinks as ★ bank toward the unlock (§7 soft gate) ---
	var tgt := Quests.meter_target(0, 0, {}, 1)
	ok(tgt >= 0 and tgt <= int(G.MAX_GIVERS), "the metered fence size stays within 0..MAX_GIVERS (got %d)" % tgt)
	ok(Quests.meter_target(0, 0, {}, 99) >= Quests.meter_target(0, 100000, {}, 99), "the fence shrinks monotonically as ★ bank toward the unlock")

	# --- pending_grant_quests: map 0 (first map) has no predecessor generators to hand in ---
	ok(Quests.pending_grant_quests(0, {}).is_empty(), "the first map has no pending generator-grant hand-ins")

	# --- refill: the normal stream fills to the metered target with non-gate quests ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var r := Quests.refill([], 0, {}, [], {}, 0, 1, rng)
	ok(r.size() == tgt, "refill fills an empty fence to exactly the metered target (%d)" % tgt)
	var no_gate := true
	for q in r:
		if bool(q.get("gate", false)):
			no_gate = false
	ok(no_gate, "the normal stream carries no gate quest")

	# --- refill is deterministic for a given seed (the rng is seeded + persisted; order is load-bearing) ---
	var rA := RandomNumberGenerator.new(); rA.seed = 7
	var rB := RandomNumberGenerator.new(); rB.seed = 7
	ok(str(Quests.refill([], 0, {}, [], {}, 0, 1, rA)) == str(Quests.refill([], 0, {}, [], {}, 0, 1, rB)), "refill is deterministic for a given seed")

	# --- refill trims an over-full fence back down to the target ---
	var over: Array = []
	for _i in tgt + 3:
		over.append({"asks": [], "reward": {"stars": 1, "coins": 0}})
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 1
	ok(Quests.refill(over, 0, {}, [], {}, 0, 1, rng2).size() == tgt, "refill trims an over-full fence to the metered target")

	# --- ladder_entries: one row per tier, code = line*100+tier, seen flagged from the save's `seen` set ---
	var lad := Quests.ladder_entries({}, 1)
	ok(lad.size() == int(G.TOP_TIER), "the ladder has one entry per tier (1..TOP_TIER)")
	ok(int(lad[0].tier) == 1 and int(lad[0].code) == 101 and not bool(lad[0].seen), "tier 1 of line 1 is code 101, unseen on a fresh save")
	ok(int(lad[int(G.TOP_TIER) - 1].code) == 100 + int(G.TOP_TIER), "the top entry is line*100 + TOP_TIER")
	ok(bool(Quests.ladder_entries({"101": true}, 1)[0].seen), "a code in the `seen` set marks that tier seen")
	ok(not bool(Quests.ladder_entries({"101": true}, 1)[1].seen), "an unseen tier stays unseen")

	# --- §6/§7 generator-grant SCHEDULING: a new map opens with its hand-in and surfaces extra
	# --- grants ONE AT A TIME (spread through the map), the regular stream filling the slots
	# --- between — NOT all grants at once. Map index 2 (Pond) has two hand-ins in the live roster
	# --- (reed_bed←hen_coop, creel←dairy_stall). ---
	var z2_gens := {Vector2i(2, 1): "hen_coop", Vector2i(6, 5): "dairy_stall"}
	ok(Quests.pending_grant_quests(2, z2_gens).size() == 2, "fixture: map 2 has two pending generator-grant hand-ins")
	var rngz := RandomNumberGenerator.new(); rngz.seed = 11
	var fence2 := Quests.refill([], 2, {}, [], z2_gens, 0, 99, rngz)
	ok(fence2.filter(func(q): return q.has("grant")).size() == 1, "only ONE generator-grant shows at a time (the rest spread through the map)")
	ok(fence2.size() >= 1 and bool(fence2[0].has("grant")), "the map's first stand is the generator-grant hand-in")
	var tgt2 := Quests.meter_target(2, 0, {}, 99)
	if tgt2 >= 2:
		ok(fence2.filter(func(q): return not q.has("grant") and not bool(q.get("gate", false))).size() >= 1, "the regular generated stream fills the slots between hand-ins")
		ok(fence2.size() == tgt2, "the fence still meters to the soft-gate target (lead grant + regular = target)")
	# handing the lead grant in (hen_coop → reed_bed) surfaces the NEXT grant (creel) — spread.
	var z2_after := {Vector2i(2, 1): "reed_bed", Vector2i(6, 5): "dairy_stall"}
	var lead_after := Quests.refill([], 2, {}, [], z2_after, 0, 99, RandomNumberGenerator.new()).filter(func(q): return q.has("grant"))
	ok(lead_after.size() == 1 and String(lead_after[0].grant.grants) == "creel", "after the first hand-in, the NEXT grant (creel) surfaces")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
