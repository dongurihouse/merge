extends SceneTree
## Headless tests for the §6 ANCHOR-LINE EXEMPTION — the anchor generator's lines stay
## LIVE and ASKABLE for the life of the save, even past the map they debuted in (T30).
## The bug: regular quest generation drew its line set from `lines_for_map` (the static
## map roster), so past map 1 no quest ever asked the anchor's lines — dead output. The
## fix routes regular quests through `askable_lines` = current-map lines ∪ anchor lines.
## Uses the REAL grove roster (G.GENERATORS) so the asserts reflect the shipped anchor flag.
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

# The grove anchor: seed_satchel (map 0) emits Wildflower(1) + Berry(2) and is flagged
# `anchor: true`; pantry_crock (map 0) emits Mushroom(3) + Honey(4) and is NOT flagged.
const ANCHOR_LINES := [1, 2]            # the exempt lines (never retire)
const NONANCHOR_Z0 := [3, 4]            # map-0 lines that DO retire when map 1 is left

func _initialize() -> void:
	# --- the anchor flag is read off the roster: union of every anchor-flagged gen's lines ---
	ok(str(G.anchor_lines(G.GENERATORS)) == str(ANCHOR_LINES), "anchor_lines reads the flag off the roster → the Wildflower+Berry pair [1, 2] (got %s)" % str(G.anchor_lines(G.GENERATORS)))

	# --- map 0 (the anchor's debut map): askable == the live roster, the union is a no-op ---
	var z0_live := G.lines_for_map(G.GENERATORS, 0)
	var z0_ask := G.askable_lines(G.GENERATORS, 0)
	z0_live.sort()
	ok(str(z0_ask) == str(z0_live), "at map 0 askable_lines == lines_for_map (anchor already live — behaviour unchanged)")
	ok(z0_ask.has(1) and z0_ask.has(2), "map-0 askable still includes the anchor lines 1/2")
	ok(z0_ask.has(3) and z0_ask.has(4), "map-0 askable still includes the non-anchor map-0 lines 3/4 (live at their own map)")

	# --- the bug fix: at map >= 1 the anchor lines stay ASKABLE; non-anchor map-0 lines do NOT ---
	for z in range(1, G.MAPS.size()):
		var ask := G.askable_lines(G.GENERATORS, z)
		var live := G.lines_for_map(G.GENERATORS, z)
		var anchor_in := ask.has(1) and ask.has(2)
		ok(anchor_in, "at map %d the anchor lines 1/2 are askable (the exemption holds past the debut map)" % z)
		var nonanchor_excluded := not ask.has(3) and not ask.has(4)
		ok(nonanchor_excluded, "at map %d the non-anchor map-0 lines 3/4 are EXCLUDED (they retired — no-strand/retirement invariant)" % z)
		# every current-map line is still present (the anchor is ADDED, nothing dropped)
		var current_present := true
		for l in live:
			if not ask.has(int(l)):
				current_present = false
		ok(current_present, "at map %d every current-map line is still askable (anchor is added, not substituted)" % z)
		# askable is exactly current-map ∪ anchor, deduped — no stray retired line leaks in
		var expected := live.duplicate()
		for l in ANCHOR_LINES:
			if not expected.has(int(l)):
				expected.append(int(l))
		expected.sort()
		ok(str(ask) == str(expected), "at map %d askable_lines == current-map ∪ anchor exactly (no other retired line leaks) — got %s" % [z, str(ask)])

	# --- retirement invariant double-check: a DEEPER map's earlier non-anchor lines stay retired ---
	# map 2 must NOT see map-1's lines (5/6/7/8) — only its own + the anchor.
	var z2 := G.askable_lines(G.GENERATORS, 2)
	var z1_lines := G.lines_for_map(G.GENERATORS, 1)
	var z1_retired := true
	for l in z1_lines:
		if z2.has(int(l)):
			z1_retired = false
	ok(z1_retired, "at map 2 the map-1 lines have retired (only the anchor is exempt, not every earlier line)")

	# --- gen_quest at a LATER map CAN produce an ask on an anchor line (the dead-output fix) ---
	# Sample across seeds: with askable_lines feeding gen_quest, the anchor lines must be reachable.
	var rng := RandomNumberGenerator.new()
	var anchor_asks := 0
	var nonanchor_z0_asks := 0
	var all_in_askable := true
	var never_t8 := true
	var z := 2                                  # a map well past the anchor's debut
	var askable := G.askable_lines(G.GENERATORS, z)
	for s in 200:
		rng.seed = s
		var aq := G.gen_quest(20, askable, rng)
		var li := int(aq.line)
		if ANCHOR_LINES.has(li):
			anchor_asks += 1
		if NONANCHOR_Z0.has(li):
			nonanchor_z0_asks += 1
		if not askable.has(li):
			all_in_askable = false
		if int(aq.tier) > G.TOP_TIER or int(aq.tier) < 1:
			never_t8 = false
	ok(anchor_asks > 0, "at a later map gen_quest CAN ask an anchor line (anchor is live output again — %d hits across seeds)" % anchor_asks)
	ok(nonanchor_z0_asks == 0, "at a later map gen_quest NEVER asks a retired non-anchor map-0 line (%d hits)" % nonanchor_z0_asks)
	ok(all_in_askable, "every generated ask draws from the askable set (producible on the live board)")
	ok(never_t8, "a regular quest tier is within 1..TOP_TIER even with the anchor in the pool")

	# --- the anchor must NOT dominate: the fresh current-map lines still lead (§7 newest-weighting) ---
	# The anchor is the OLDEST in the sorted askable list, so it should be asked LESS than the newest.
	rng.seed = 7
	var oldest_anchor := 0
	var newest_hits := 0
	var newest := int(askable[askable.size() - 1])
	for _i in 600:
		var aq2 := G.gen_quest(20, askable, rng)
		if int(aq2.line) == 1:                # an anchor line (oldest)
			oldest_anchor += 1
		if int(aq2.line) == newest:
			newest_hits += 1
	ok(newest_hits > oldest_anchor, "the anchor stays a MINOR ask — the newest current-map line still dominates (%d newest vs %d anchor)" % [newest_hits, oldest_anchor])

	# --- DECISION (recorded): gate_quest stays MAP-SCOPED — the anchor is NOT folded into a
	# --- later map's gate. The anchor exemption is a REGULAR-quest rule (§6/§7); the gate asks the
	# --- map's own ceiling lines. Lock that: a later gate must draw only from that map's lines. ---
	var gq := G.gate_quest(G.GENERATORS, 2, rng)
	var z2_live := G.lines_for_map(G.GENERATORS, 2)
	var gate_anchor_free := not ANCHOR_LINES.has(int(gq.line)) and z2_live.has(int(gq.line))
	ok(gate_anchor_free, "DECISION: the later-map gate quest stays map-scoped (asks only that map's lines, never the anchor) — scope-tight, keeps quest_tests' gate asserts intact")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
