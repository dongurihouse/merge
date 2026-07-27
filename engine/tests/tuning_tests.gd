extends "res://engine/tests/test_base.gd"
## Headless tests for the OWNER ECONOMY TUNING loader (content.gd.apply_tuning). The HTML tool
## docs/economy_tuning.html writes economy_tuning.json; the game picks it up at load. This verifies
## the curve/board math FOLLOWS an override, a missing file is a no-op, partial files apply only their
## keys, and a malformed grid is rejected — then restores the live dials so it leaves no trace.
##   godot --headless --path . -s res://engine/tests/tuning_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")

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

	# A malformed grid (wrong shape) is rejected; the other keys still apply. The `ERROR: economy_tuning
	# min_level: expected 9 rows × 7 cols…` line this prints is EXPECTED — _coerce_grid used to drop a
	# mis-shaped grid silently, so the board fell back to the const with no signal anywhere.
	_write(path, {"level_step_exp": 9, "min_level": [[1, 2, 3]]})
	var bad := G.apply_tuning(path)
	ok(not bad.has("min_level") and bad.has("level_step_exp"),
		"a wrong-shape min_level grid is ignored while the rest applies")

	# --- THE DERIVED GATES FOLLOW SCENE_END_LEVEL, NOT THE COIN CURVE (re-spined 2026-07-26) ---------
	# The cluster floors and the zone cadence are now derived from the owner-authored SCENE_END_LEVEL
	# band (content._build_cadence) and ZONE_BAND — the coin curve (LEVEL_BASE_COINS/LEVEL_STEP_COINS)
	# only sets the CALENDAR (how long a level takes to earn) and must NOT move either derived table any
	# more. That is the exact opposite of the pre-re-spine guarantee this block used to check — verify
	# the reversal first, since silently regressing back to a coin-driven cadence is the failure mode a
	# re-tune of the curve could reintroduce unnoticed.
	var shipped_cad: Array = [1, 15, 29, 33, 38, 42, 46, 51, 55, 60, 65, 69]
	G.LEVEL_BASE_COINS = cb0
	G.LEVEL_STEP_COINS = cs0
	ok(G.zone_unlock_levels() == shipped_cad, "at the shipped SCENE_END_LEVEL band the cadence is %s" % str(shipped_cad))
	var shipped_floors: Array = []
	for z in G.coverup_pages():
		for c in G.clusters(int(z)):
			shipped_floors.append(G.cluster_min_level(int(z), String((c as Dictionary).id)))
	ok(shipped_floors == [1, 6, 12, 17, 23, 28, 29, 32, 35, 38, 41, 42, 45, 48, 51, 54, 55, 57, 60, 62, 64, 65, 67, 69, 71],
		"at the shipped SCENE_END_LEVEL band the floor ladder is %s" % str(shipped_floors))

	# move the coin curve — neither table may react any more (the whole point of the re-spine)
	G.LEVEL_BASE_COINS = 15
	G.LEVEL_STEP_COINS = 6
	ok(G.zone_unlock_levels() == shipped_cad, "moving the coin curve no longer moves the zone cadence")
	var floors_after_curve_move: Array = []
	for z2 in G.coverup_pages():
		for c2 in G.clusters(int(z2)):
			floors_after_curve_move.append(G.cluster_min_level(int(z2), String((c2 as Dictionary).id)))
	ok(floors_after_curve_move == shipped_floors, "moving the coin curve no longer moves the cluster floors")
	G.LEVEL_BASE_COINS = cb0
	G.LEVEL_STEP_COINS = cs0

	# SCENE_END_LEVEL and ZONE_BAND are plain `const`s — GDScript freezes const arrays (verified: even a
	# single-element assignment on one raises "Array is in read-only state"), so unlike the coin curve
	# they cannot be reassigned or mutated at runtime to simulate an owner re-tune. The one genuinely live
	# input left into the SAME cache is MAPS's per-scene CLUSTER COUNT (content.gd: `static var MAPS`;
	# _cadence_table's key is built from SCENE_END_LEVEL, the per-scene cluster counts, and ZONE_BAND —
	# see _build_cadence). Shrinking Fairy Hollow by one cluster exercises exactly that lever and checks
	# the promise the new model actually makes: the cache is not stale, the scene's LAST cluster still
	# lands exactly on SCENE_END_LEVEL[0] regardless of how many clusters it now has, and scene alignment
	# (the zones half, untouched by this mutation, since it never reads MAPS cluster counts) still holds.
	var maps_snapshot: Array = G.MAPS.duplicate(true)
	var fh_clusters: Array = (G.MAPS[0] as Dictionary).clusters
	fh_clusters.pop_back()
	var moved_floors: Array = []
	for z3 in G.coverup_pages():
		for c3 in G.clusters(int(z3)):
			moved_floors.append(G.cluster_min_level(int(z3), String((c3 as Dictionary).id)))
	ok(moved_floors != shipped_floors, "shrinking a scene's cluster count moves the floor ladder (no stale cache)")
	var fh_last_id := String((G.clusters(0).back() as Dictionary).id)
	ok(G.cluster_min_level(0, fh_last_id) == int(G.SCENE_END_LEVEL[0]),
		"Fairy Hollow's LAST cluster still lands exactly on SCENE_END_LEVEL[0] with one fewer cluster")
	var zi := 0
	var aligned := true
	var moved_cad: Array = G.zone_unlock_levels()
	for p in G.ZONE_BAND.size():
		var win := G.scene_level_window(int(p))
		for _j in int(G.ZONE_BAND[p]):
			if int(moved_cad[zi]) < int(win.x) or int(moved_cad[zi]) > int(win.y):
				aligned = false
			zi += 1
	ok(aligned, "scene alignment still holds after the cluster-count change")

	# restoring the dial (MAPS) restores the shipped tables
	G.MAPS = maps_snapshot
	var restored_floors: Array = []
	for z4 in G.coverup_pages():
		for c4 in G.clusters(int(z4)):
			restored_floors.append(G.cluster_min_level(int(z4), String((c4 as Dictionary).id)))
	ok(restored_floors == shipped_floors, "restoring MAPS restores the shipped floor ladder")
	ok(G.zone_unlock_levels() == shipped_cad, "the zone cadence is unaffected throughout (SCENE_END_LEVEL/ZONE_BAND never moved)")

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

	finish()
