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

# map-0 base lines: the 4 per-line generators at zones 0,1,3,4 (gen redesign — was the seed_satchel anchor
# emitting Wildflower + the staged Farm lines). Under the live [6,4,7,4,4] layout map 0 has 6 spots = zones
# 0-5 (4 base + the specials at zones 2/5); line 5 sits at zone 6 = map 1's first base line.
const Z0_LINES := [1, 2, 3, 4]

func _initialize() -> void:
	# --- askable_lines == the ROLLING WINDOW of the last LINE_WINDOW maps, at EVERY map (older lines retire) ---
	for z in G.MAPS.size():
		ok(str(G.askable_lines(G.GENERATORS, z)) == str(_window_lines(z)), "at map %d askable_lines == the rolling-window lines" % z)

	# --- map 0: its own line(s) are askable ---
	var z0 := G.askable_lines(G.GENERATORS, 0)
	for l in Z0_LINES:
		ok(z0.has(l), "map-0 askable includes its own line %d" % l)

	# --- gen redesign: map 0 hosts its 4 per-line BASE generators (lines 1-4 at zones 0,1,3,4); the old
	# Farm-line (61-66) min_level staging is RETIRED — every base line is live the moment its zone opens. ---
	var z0_all := G.askable_lines(G.GENERATORS, 0, 99)
	var m0_ok := true
	for l in Z0_LINES:
		if not z0_all.has(int(l)):
			m0_ok = false
	ok(m0_ok, "map-0's askable set is exactly its 4 per-line base lines")
	ok(not z0_all.has(61) and not z0_all.has(62), "the retired Farm lines (61-66) no longer appear in the pool")

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
		{"id": "fix_anchor", "map": 0, "cell": Vector2i(4, 3), "line": 1, "anchor": true},
		{"id": "fix_staged", "map": 0, "cell": Vector2i(2, 1), "line": 3, "appear_level": 5},
	]
	ok(not G.askable_lines(staged, 0, 4).has(3), \
		"a staged gen's line (3) is NOT askable before it grows in (appear_level gate)")
	ok(G.askable_lines(staged, 0, 5).has(3), \
		"a staged gen's line becomes askable once it appears at its level")

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
