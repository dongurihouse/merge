extends SceneTree
## Headless tests for the OWNER ECONOMY TUNING loader (content.gd.apply_tuning). The HTML tool
## docs/economy_tuning.html writes economy_tuning.json; the game picks it up at load. This verifies
## the curve/board math FOLLOWS an override, a missing file is a no-op, partial files apply only their
## keys, and a malformed grid is rejected — then restores the live dials so it leaves no trace.
##   godot --headless --path . -s res://engine/tests/tuning_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")

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
	var cb0 := G.LEVEL_BASE_COINS
	var cs0 := G.LEVEL_STEP_COINS
	var g0 := G.MIN_LEVEL

	var path := "user://tuning_tests_tmp.json"
	_write(path, {
		"level_base_coins": 25, "level_step_coins": 9,
		"level_base_exp": 11, "level_step_exp": 0, "quest_clicks_per_exp": 5,
		"min_level": [[1,1,1,1,1,1,1],[1,1,1,1,1,1,1],[1,1,1,1,1,1,1],[1,1,0,0,0,1,1],[1,1,0,0,0,1,1],
			[1,1,0,0,0,1,1],[1,1,1,1,1,1,1],[1,1,1,1,1,1,1],[1,1,1,1,1,1,1]],
	})
	var applied := G.apply_tuning(path)
	ok(applied.size() == 6, "apply_tuning reports all 6 keys applied")
	# THE LIVE LEVEL CLOCK. content.gd levels off COINS, so these two are the dials that actually
	# move player pacing — they were absent from economy_tuning.json until 2026-07-24, which meant
	# the owner's tuning tool edited only dead exp dials while this curve silently used its fallback.
	ok(G.LEVEL_BASE_COINS == 25 and G.LEVEL_STEP_COINS == 9, "the live COIN level clock is overridden")
	ok(G.coins_at_level(3) == 25 * 2 + 9, "coins_at_level FOLLOWS the override (2×25 + 9)")
	ok(G.LEVEL_BASE_EXP == 11 and G.LEVEL_STEP_EXP == 0, "the level curve is overridden")
	ok(G.exp_at_level(3) == 22, "exp_at_level FOLLOWS the override (base 11 · step 0 → L3 = 2×11 = 22)")
	ok(G.QUEST_CLICKS_PER_EXP == 5, "quest_clicks_per_exp is overridden")
	# coins-only reward: the folded PROGRESSION slice follows the clicks-per-exp override
	var t5_spend := int(round(16.0 / float(G.QUEST_CLICKS_PER_COIN[0]) * pow(G.QUEST_COIN_DEPTH, 5 - G.QUEST_TIER_BASE)))
	ok(int(G.quest_reward(5).coins) == int(round(16.0 / 5.0)) + t5_spend, "quest_reward's progression slice follows the clicks-per-exp override (t5 = 16 clicks)")
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

	# --- THE DERIVED GATES FOLLOW THE CURVE (2026-07-25) ---------------------------------------------
	# The cluster floors and the zone cadence are derived from the cluster COST ladder through the coin
	# curve. This is the guard that stops them being hand-authored back out of step: move the curve, and
	# BOTH tables must move with it, with scene alignment intact. The cadence cache is keyed on these
	# dials, so no explicit rebuild call exists to forget.
	var shipped_cad: Array = [1, 5, 8, 12, 16, 20, 26, 32, 38, 50, 62, 75]
	G.LEVEL_BASE_COINS = cb0
	G.LEVEL_STEP_COINS = cs0
	ok(G.zone_unlock_levels() == shipped_cad, "at the shipped curve the cadence is %s" % str(shipped_cad))
	var shipped_top := G.cluster_min_level(0, "lantern_gate")

	# HALVE the curve: every threshold is cheaper, so every gate must arrive EARLIER.
	G.LEVEL_BASE_COINS = 15
	G.LEVEL_STEP_COINS = 6
	var cheap_cad: Array = G.zone_unlock_levels()
	var cheap_top := G.cluster_min_level(0, "lantern_gate")
	ok(cheap_cad != shipped_cad, "halving the curve moves the zone cadence (no stale cache)")
	ok(cheap_cad.size() == G.ZONE_COUNT, "the moved cadence still has one level per zone")
	var cheap_rising := true
	for i in range(1, cheap_cad.size()):
		if int(cheap_cad[i]) <= int(cheap_cad[i - 1]):
			cheap_rising = false
	ok(cheap_rising, "the moved cadence is still strictly increasing")
	ok(cheap_top > shipped_top, "a cheaper curve puts Fairy Hollow's last cluster at a HIGHER level (%d > %d)" % [cheap_top, shipped_top])

	# scene alignment survives the move — this is the property that used to be hand-maintained
	var zi := 0
	var aligned := true
	for p in G.ZONE_BAND.size():
		var win := G.scene_level_window(int(p))
		for _j in int(G.ZONE_BAND[p]):
			if int(cheap_cad[zi]) < int(win.x) or int(cheap_cad[zi]) > int(win.y):
				aligned = false
			zi += 1
	ok(aligned, "every zone still lands inside its own scene's window after the curve moves")

	# the floors track level_at_coins of the cumulative cost at the MOVED curve too
	var floors_track := true
	var fi := 0
	for z in G.coverup_pages():
		for c in G.clusters(int(z)):
			if G.cluster_min_level(int(z), String((c as Dictionary).id)) != G.level_at_coins(G.cumulative_cluster_cost(fi)):
				floors_track = false
			fi += 1
	ok(floors_track, "every cluster floor still equals level_at_coins(cumulative cost) at the moved curve")

	# restore the live dials and verify
	G.LEVEL_BASE_EXP = b0
	G.LEVEL_STEP_EXP = s0
	G.QUEST_CLICKS_PER_EXP = c0
	G.LEVEL_BASE_COINS = cb0
	G.LEVEL_STEP_COINS = cs0
	G.MIN_LEVEL = g0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ok(G.exp_at_level(3) == b0 * 2 + s0, "the live dials are restored after the suite")
	ok(G.zone_unlock_levels() == shipped_cad, "the derived cadence is back to the shipped table after the suite restores the dials")

	# --- the global font scale (FontScale) -----------------------------------------------
	# SIX tiers, each a fixed % of BASE, each measured off the 1080x1920 concept screens.
	# These pin the ramp so an accidental nudge (which would resize text ACROSS the app) fails loudly.
	ok(FS.BASE == 40, "FontScale.BASE is the 40px theme default")
	var ramp := [[FS.FINE, 28], [FS.BODY, 32], [FS.HEADING, 40], [FS.TITLE, 52],
		[FS.DISPLAY, 64], [FS.BANNER, 120], [FS.TOOL, 16]]
	var ramp_ok := true
	for pair in ramp:
		if pair[0] != pair[1]:
			ramp_ok = false
	ok(ramp_ok, "every FontScale tier resolves to its documented pixel size")
	ok(UiFont.make().default_font_size == FS.BASE, "the installed theme default follows FontScale.BASE")

	# The scale is deliberately SMALL: six shipped tiers + one dev-tool size. If this grows,
	# someone re-introduced a bespoke size instead of reusing a tier.
	ok(FS.TIERS.size() == 7, "the scale stays at six shipped tiers plus TOOL")
	# TIERS is the whole ladder, ascending — the workbench's font sliders step over exactly this.
	var tiers_sorted := true
	for i in range(1, FS.TIERS.size()):
		if FS.TIERS[i] < FS.TIERS[i - 1]:
			tiers_sorted = false
	ok(tiers_sorted and FS.TIERS.size() == ramp.size(), "FontScale.TIERS lists every tier, ascending")
	# Each tier's CAP height is what the mock was measured at: cap = 0.744 * font_size
	# (the live face's ratio, measured by font_calibrate_shot.gd). Guards the mock derivation.
	var cap_ok := true
	for pair in [[FS.FINE, 21], [FS.BODY, 24], [FS.HEADING, 30], [FS.TITLE, 39],
			[FS.DISPLAY, 48], [FS.BANNER, 89]]:
		if absi(int(round(float(pair[0]) * 0.744)) - int(pair[1])) > 1:
			cap_ok = false
	ok(cap_ok, "every tier's cap height matches the height measured off the concept mocks")
	# snap() migrates a loose px onto the ladder; ties round UP.
	ok(FS.snap(30) == 32 and FS.snap(45) == 40 and FS.snap(1000) == FS.BANNER,
		"FontScale.snap rounds a loose px to the nearest tier (ties up, clamped to the ladder)")
	var in_range: Array = FS.tiers_in(28, 52)
	ok(in_range == [28, 32, 40, 52], "FontScale.tiers_in returns only the tiers inside the range")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
