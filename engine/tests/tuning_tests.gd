extends SceneTree
## Headless tests for the OWNER ECONOMY TUNING loader (content.gd.apply_tuning). The HTML tool
## docs/economy_tuning.html writes economy_tuning.json; the game picks it up at load. This verifies
## the curve/board math FOLLOWS an override, a missing file is a no-op, partial files apply only their
## keys, and a malformed grid is rejected — then restores the live dials so it leaves no trace.
##   godot --headless --path . -s res://engine/tests/tuning_tests.gd

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

func _write(path: String, obj: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(obj))
	f.close()

func _initialize() -> void:
	# snapshot the live dials so the suite leaves them exactly as found
	var b0 := G.LEVEL_BASE_EXP
	var s0 := G.LEVEL_STEP_EXP
	var c0 := G.QUEST_CLICKS_PER_EXP
	var e0 := G.ENDGAME_CLICKS
	var g0 := G.MIN_LEVEL

	var path := "user://tuning_tests_tmp.json"
	_write(path, {
		"level_base_exp": 11, "level_step_exp": 0, "quest_clicks_per_exp": 5, "endgame_clicks": 4242,
		"min_level": [[1,1,1,1,1,1,1],[1,1,1,1,1,1,1],[1,1,1,1,1,1,1],[1,1,0,0,0,1,1],[1,1,0,0,0,1,1],
			[1,1,0,0,0,1,1],[1,1,1,1,1,1,1],[1,1,1,1,1,1,1],[1,1,1,1,1,1,1]],
	})
	var applied := G.apply_tuning(path)
	ok(applied.size() == 5, "apply_tuning reports all 5 keys applied")
	ok(G.LEVEL_BASE_EXP == 11 and G.LEVEL_STEP_EXP == 0, "the level curve is overridden")
	ok(G.exp_at_level(3) == 22, "exp_at_level FOLLOWS the override (base 11 · step 0 → L3 = 2×11 = 22)")
	ok(G.QUEST_CLICKS_PER_EXP == 5, "quest_clicks_per_exp is overridden")
	ok(int(G.quest_reward(5).exp) == int(round(16.0 / 5.0)), "quest_reward exp follows the clicks-per-exp override (t5 = 16 clicks)")
	ok(G.ENDGAME_CLICKS == 4242, "the endgame-clicks anchor is overridden")
	ok(G.cell_min_level(Vector2i(0, 0)) == 1 and G.cell_min_level(Vector2i(4, 3)) == 0,
		"the MIN_LEVEL board grid is overridden (corner → 1, center → 0)")

	# a missing file is a clean no-op (dials unchanged from what we just set)
	var none := G.apply_tuning("user://tuning_tests_does_not_exist.json")
	ok(none.is_empty() and G.LEVEL_BASE_EXP == 11, "a missing tuning file changes nothing")

	# a partial file overrides ONLY its named keys
	_write(path, {"level_base_exp": 7})
	var part := G.apply_tuning(path)
	ok(part.size() == 1 and G.LEVEL_BASE_EXP == 7 and G.LEVEL_STEP_EXP == 0,
		"a partial file overrides only its named keys")

	# a malformed grid (wrong shape) is rejected; the other keys still apply
	_write(path, {"level_step_exp": 9, "min_level": [[1, 2, 3]]})
	var bad := G.apply_tuning(path)
	ok(not bad.has("min_level") and bad.has("level_step_exp"),
		"a wrong-shape min_level grid is ignored while the rest applies")

	# restore the live dials and verify
	G.LEVEL_BASE_EXP = b0
	G.LEVEL_STEP_EXP = s0
	G.QUEST_CLICKS_PER_EXP = c0
	G.ENDGAME_CLICKS = e0
	G.MIN_LEVEL = g0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ok(G.exp_at_level(3) == b0 * 2 + s0, "the live dials are restored after the suite")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
