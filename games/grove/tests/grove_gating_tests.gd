extends "res://games/grove/tests/grove_test_base.gd"
## Feature level gating: the unlock table, FeatureGate's two states, the teach
## registry, and the mastery reveal clamp. Spec: docs/superpowers/specs/2026-07-29-feature-level-gating-design.md

const FeatureGate = preload("res://engine/scripts/core/feature_gate.gd")
const Improvements = preload("res://engine/scripts/core/improvements.gd")
const Mastery = preload("res://engine/scripts/core/mastery.gd")
const ShopUI = preload("res://engine/scripts/ui/shop.gd")
const SkyLogic = preload("res://engine/scripts/core/sky.gd")

func _initialize() -> void:
	begin("grove · feature gating")
	await process_frame
	_test_table_thresholds()
	_test_unknown_id_fails_closed()
	_test_revealed_is_separate_from_armed()
	_test_weather_gate_needs_the_level()
	_test_magnet_seed_cannot_drop_before_its_level()
	_test_soil_ftue_level_comes_from_the_table()
	_test_mastery_rank_is_clamped_until_revealed()
	finish()

## Set the coin clock so G.level() reads exactly `lvl`.
func _set_level(lvl: int) -> void:
	Save.earn_coins(G.coins_at_level(lvl) - Save.coins_earned_lifetime())

func _test_table_thresholds() -> void:
	for id in G.FEATURE_LEVEL:
		var want := int(G.FEATURE_LEVEL[id])
		fresh("gate_" + String(id))
		_set_level(want - 1)
		ok(not FeatureGate.armed(String(id)),
			"%s is dormant at L%d (one below its gate)" % [id, want - 1])
		fresh("gate_on_" + String(id))
		_set_level(want)
		ok(FeatureGate.armed(String(id)) == _extra_met(String(id)),
			"%s arms at L%d once its extra condition is met" % [id, want])

## The AND terms that are NOT the level. A fresh save meets none of them, so this documents
## which ids can arm on level alone.
func _extra_met(id: String) -> bool:
	return id == "cascade" or id == "mastery" or id == "magnet"

func _test_unknown_id_fails_closed() -> void:
	fresh("gate_unknown")
	ok(not FeatureGate.armed("no_such_feature"),
		"an unknown gate id fails CLOSED (never leaks an ungated feature)")

func _test_revealed_is_separate_from_armed() -> void:
	fresh("gate_reveal")
	_set_level(G.FEATURE_LEVEL["cascade"])
	ok(FeatureGate.armed("cascade"), "cascade arms at its level")
	ok(not FeatureGate.revealed("cascade"), "arming does NOT reveal")
	FeatureGate.mark_revealed("cascade")
	ok(FeatureGate.revealed("cascade"), "mark_revealed persists to the ftue ledger")

func _test_weather_gate_needs_the_level() -> void:
	fresh("gate_weather_level")
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	_set_level(G.FEATURE_LEVEL["weather"] - 1)
	ok(not SkyLogic.gate_open(),
		"both FTUE verbs seen is no longer enough — the weather gate also needs L%d" % int(G.FEATURE_LEVEL["weather"]))
	_set_level(G.FEATURE_LEVEL["weather"])
	ok(SkyLogic.gate_open(), "weather opens at its level with both verbs seen")

func _test_magnet_seed_cannot_drop_before_its_level() -> void:
	fresh("gate_magnet_drop")
	_set_level(G.FEATURE_LEVEL["magnet"] - 1)
	var magnet_line := Improvements.seed_line_for_kind(Improvements.KIND_MAGNET)
	var seen_below := 0
	# A SEED SWEEP, not one seed: a single stream proves nothing about a weighted table.
	for s in range(1, 60):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		for _i in range(40):
			if int(G.pick_special_drop(rng, [magnet_line]) / 100.0) == magnet_line:
				seen_below += 1
	ok(seen_below == 0,
		"the magnet seed line never drops while the gate is unarmed (%d hits over 59 seeds)" % seen_below)

func _test_soil_ftue_level_comes_from_the_table() -> void:
	ok(int(G.FEATURE_LEVEL["soil"]) == 13,
		"the soil teach's level is the table's 13, not the retired literal 6")

func _test_mastery_rank_is_clamped_until_revealed() -> void:
	fresh("gate_mastery_clamp")
	_set_level(G.FEATURE_LEVEL["mastery"])
	var line := int(G.ZONE_BASE_LINES[0])
	# Bank a meter well past threshold 2 — the case that would otherwise dump scissors
	# in the same beat as the mastery reveal.
	Save.grove()["mastery"] = {str(line): int(G.MASTERY_THRESHOLDS[2])}
	ok(Mastery.true_rank(line) >= 3, "the banked meter really is past rank 2")
	ok(Mastery.rank(line) == 1, "rank reads 1 while mastery is unrevealed")
	ok(not ShopUI.scissors_available(),
		"scissors CANNOT unlock in the same beat as the mastery reveal")
	FeatureGate.mark_revealed("mastery")
	ok(Mastery.rank(line) == Mastery.true_rank(line), "the clamp lifts on reveal")
	ok(ShopUI.scissors_available(), "scissors becomes available once mastery is revealed")
