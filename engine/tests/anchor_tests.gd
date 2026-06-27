extends SceneTree
## Headless tests for ASKABLE LINES — a ROLLING WINDOW of the last LINE_WINDOW maps (the current map +
## the previous LINE_WINDOW-1): a regular quest may ask any line in that window; older lines RETIRE off
## the fence (Wildflower drops out by map 3). Uses the REAL grove roster.
##   godot --headless --path . -s res://engine/tests/anchor_tests.gd

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

# map-0 lines: seed_satchel emits Wildflower(1). (One line per map now — line code == map number;
# map 0's sole generator emits its single line.)
const Z0_LINES := [1]

func _initialize() -> void:
	# --- askable_lines == the ROLLING WINDOW of the last LINE_WINDOW maps, at EVERY map (older lines retire) ---
	for z in G.MAPS.size():
		ok(str(G.askable_lines(G.GENERATORS, z)) == str(_window_lines(z)), "at map %d askable_lines == the rolling-window lines" % z)

	# --- map 0: its own line(s) are askable ---
	var z0 := G.askable_lines(G.GENERATORS, 0)
	for l in Z0_LINES:
		ok(z0.has(l), "map-0 askable includes its own line %d" % l)

	# --- map 0 ALSO emits the Farm content lines (61-66), WIRED onto the seed_satchel anchor and STAGED
	# via min_level so the tiny FTUE board grows in gradually. Hearth embers (61) is LIVE at L1 (the board's
	# 2nd starting line); the rest grow in across L2–6, all live by L6 — before the Barn opens. ---
	var farm_lines := [61, 62, 63, 64, 65, 66]
	var z0_hi := G.askable_lines(G.GENERATORS, 0, 99)
	var all_farm_hi := true
	for fl in farm_lines:
		if not z0_hi.has(int(fl)):
			all_farm_hi = false
	ok(all_farm_hi, "map-0 pool includes all 6 Farm lines (61-66) at high level")
	# the board OPENS with TWO live lines: the anchor (1) + Hearth embers (61, min_level 1)
	var z0_l1 := G.askable_lines(G.GENERATORS, 0, 1)
	ok(z0_l1.has(1) and z0_l1.has(61), "map-0 starts with 2 live lines at L1: Wildflower(1) + Hearth embers(61)")
	ok(not z0_l1.has(62), "the next Farm line (62) is still gated out at L1 (staged)")
	var z0_l6 := G.askable_lines(G.GENERATORS, 0, 6)
	var all_farm_l6 := true
	for fl in farm_lines:
		if not z0_l6.has(int(fl)):
			all_farm_l6 = false
	ok(all_farm_l6, "all 6 Farm lines are live by L6 (staged in before the Barn opens)")

	# --- the ROLLING WINDOW: map-0 lines stay askable only while map 0 is within the last LINE_WINDOW maps
	# (maps 1-2), then RETIRE from map 3 on — late-game quests can no longer ask Wildflower(1). ---
	for z in range(1, G.MAPS.size()):
		var ask := G.askable_lines(G.GENERATORS, z)
		var in_window := z <= G.LINE_WINDOW - 1            # map 0 is in the window iff z < LINE_WINDOW
		ok(ask.has(1) == in_window, "at map %d Wildflower(1) is %s (rolling window of %d maps)" % [z, "askable" if in_window else "RETIRED", G.LINE_WINDOW])
		ok(str(ask) == str(_window_lines(z)), "at map %d askable is exactly the rolling-window lines" % z)

	# --- `level` still gates a not-yet-grown generator's lines out (the staging invariant). The
	# shipped roster is one generator per map (no staged gen), so drive the gate on a SYNTHETIC
	# roster: map 0 = a live anchor (L0) + a staged gen (appear_level 5) emitting lines 3,4. ---
	var staged := [
		{"id": "fix_anchor", "map": 0, "cell": Vector2i(4, 3), "lines": [1, 2], "anchor": true},
		{"id": "fix_staged", "map": 0, "cell": Vector2i(2, 1), "lines": [3, 4], "appear_level": 5},
	]
	ok(not G.askable_lines(staged, 0, 4).has(3) and not G.askable_lines(staged, 0, 4).has(4), \
		"a staged gen's lines (3,4) are NOT askable before it grows in (level gate)")
	ok(G.askable_lines(staged, 0, 5).has(3) and G.askable_lines(staged, 0, 5).has(4), \
		"a staged gen's lines become askable once it appears at its level")

	# --- gen_quest at a later map draws from the rolling-window askable set (at map 2 that still includes
	# map-0 lines — maps 0,1,2 all fit a 3-map window) ---
	var rng := RandomNumberGenerator.new()
	var z := 2
	var askable := G.askable_lines(G.GENERATORS, z)
	var all_in := true
	var tier_ok := true
	for s in 200:
		rng.seed = s
		var aq := G.gen_quest(20, askable, rng)
		var li := int(aq.line)
		if not askable.has(li):
			all_in = false
		if int(aq.tier) < 1 or int(aq.tier) > G.TOP_TIER:
			tier_ok = false
	ok(all_in, "every generated ask draws from the rolling-window askable set (producible on the board)")
	for l in Z0_LINES:
		ok(askable.has(int(l)), "a map-0 line is still asked at map 2 (within the 3-map rolling window)")
	ok(tier_ok, "a regular quest tier stays within 1..TOP_TIER")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)

# All lines ASKABLE at `map` = the union of the last LINE_WINDOW maps' lines (the rolling window), sorted.
func _window_lines(map: int) -> Array:
	var out: Array = []
	for z in range(maxi(0, map - G.LINE_WINDOW + 1), map + 1):
		for l in G.lines_for_map(G.GENERATORS, z):
			if not out.has(int(l)):
				out.append(int(l))
	out.sort()
	return out
