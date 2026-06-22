extends SceneTree
## Headless tests for ASKABLE LINES — now CURRENT-MAP ONLY (the anchor-line exemption is retired:
## generators persist, no hand-in, no retirement-driven exemption). A regular quest may ask only
## the current map's live lines; old-map lines are not quested. Uses the REAL grove roster.
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
	# --- askable_lines == lines_for_map (sorted), at EVERY map — no anchor union ---
	for z in G.MAPS.size():
		var live := G.lines_for_map(G.GENERATORS, z)
		live.sort()
		ok(str(G.askable_lines(G.GENERATORS, z)) == str(live), "at map %d askable_lines == lines_for_map sorted (current-map only)" % z)

	# --- map 0: its own four lines are askable ---
	var z0 := G.askable_lines(G.GENERATORS, 0)
	for l in Z0_LINES:
		ok(z0.has(l), "map-0 askable includes its own line %d" % l)

	# --- past map 0, the map-0 lines are NOT askable (no exemption — old-map lines retire from quests) ---
	for z in range(1, G.MAPS.size()):
		var ask := G.askable_lines(G.GENERATORS, z)
		var none_z0 := true
		for l in Z0_LINES:
			if ask.has(int(l)):
				none_z0 = false
		ok(none_z0, "at map %d NO map-0 line is askable (anchor exemption retired)" % z)
		# every current-map line is present, and ONLY those (askable is exactly the live set)
		var live := G.lines_for_map(G.GENERATORS, z); live.sort()
		ok(str(ask) == str(live), "at map %d askable is exactly the current-map live set (no stray line)" % z)

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

	# --- gen_quest at a later map draws only from the current-map askable set ---
	var rng := RandomNumberGenerator.new()
	var z := 2
	var askable := G.askable_lines(G.GENERATORS, z)
	var all_in := true
	var z0_leak := 0
	var tier_ok := true
	for s in 200:
		rng.seed = s
		var aq := G.gen_quest(20, askable, rng)
		var li := int(aq.line)
		if not askable.has(li):
			all_in = false
		if Z0_LINES.has(li):
			z0_leak += 1
		if int(aq.tier) < 1 or int(aq.tier) > G.TOP_TIER:
			tier_ok = false
	ok(all_in, "every generated ask draws from the current-map askable set (producible on the board)")
	ok(z0_leak == 0, "no generated ask ever lands on a retired map-0 line (%d hits)" % z0_leak)
	ok(tier_ok, "a regular quest tier stays within 1..TOP_TIER")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
