extends SceneTree
## Headless tests for the generator MECHANIC (T17): per-zone roster derivation,
## the merge-to-evolve op, line retirement, movable generators.
##   godot --headless --path . -s res://engine/tests/mechanics_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
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

## A fixture roster (independent of the live grove data): zone 0 grants 2 generators
## outright; zone 1 brings 3 — two EVOLVE from zone 0's pair, one is a surplus grant.
func _fixture() -> Array:
	return [
		{"id": "g0a", "zone": 0, "lines": [1, 2], "evolves_from": "", "cell": Vector2i(4, 3)},
		{"id": "g0b", "zone": 0, "lines": [3, 4], "evolves_from": "", "cell": Vector2i(2, 1)},
		{"id": "g1a", "zone": 1, "lines": [5, 6], "evolves_from": "g0a"},
		{"id": "g1b", "zone": 1, "lines": [7, 8], "evolves_from": "g0b"},
		{"id": "g1c", "zone": 1, "lines": [10, 11], "evolves_from": "", "cell": Vector2i(6, 5)},
	]

func _initialize() -> void:
	var r := _fixture()

	# --- per-zone roster derivation (replaces appears_at accumulation) ---
	ok(G.generators_for_zone(r, 0).size() == 2, "zone 0 has 2 generators")
	ok(G.generators_for_zone(r, 1).size() == 3, "zone 1 has 3 generators")
	ok(G.lines_for_zone(r, 1) == [5, 6, 7, 8, 10, 11], "zone 1's live lines are its 3 generators' 6 lines")
	ok(G.retired_lines(r, 1) == [1, 2, 3, 4], "zone 0's 4 lines retire once zone 1 is live")
	ok(G.lines_for_zone(r, 0) == [1, 2, 3, 4], "zone 0's live lines are its own 4")
	ok(G.retired_lines(r, 0) == [], "nothing is retired while in zone 0")

	# --- the evolve lineage: which grant consumes which predecessor ---
	ok(G.evolve_map(r) == {"g1a": "g0a", "g1b": "g0b"}, "the 2 evolving generators map to their zone-0 predecessors")
	ok(G.surplus_gen_ids(r, 1) == ["g1c"], "the surplus generator is granted outright (no predecessor)")

	# --- the §6 invariant: every generator emits exactly 2 lines ---
	var two_each := true
	for g in r:
		if int((g.lines as Array).size()) != 2:
			two_each = false
	ok(two_each, "every generator emits exactly 2 lines")

	# --- the evolve-merge op + line retirement (the core, §6) ---
	var center := Vector2i(4, 3)
	var other := Vector2i(2, 1)
	var st := {center: "g0a", other: "g0b"}            # zone-0 live set: g0a + g0b
	ok(G.gen_live_lines(st, r) == [1, 2, 3, 4], "zone-0 state: all 4 starter lines live")
	ok(G.gen_can_evolve(st, r, center, "g1a"), "g1a may evolve onto its predecessor g0a")
	ok(not G.gen_can_evolve(st, r, center, "g1b"), "g1b may NOT evolve onto g0a (wrong predecessor)")
	ok(not G.gen_can_evolve(st, r, center, "g1c"), "a surplus grant has no predecessor to evolve onto")
	ok(not G.gen_can_evolve(st, r, Vector2i(0, 0), "g1a"), "can't evolve onto a cell with no generator")
	var st2 := G.gen_evolve(st, r, center, "g1a")      # g0a consumed → g1a takes its cell
	ok(st2[center] == "g1a", "the new generator installs at the consumed one's cell")
	ok(not st2.values().has("g0a"), "the old generator is consumed (gone)")
	ok(G.gen_live_lines(st2, r) == [3, 4, 5, 6], "g0a's lines 1,2 retire; g1a's 5,6 go live; g0b's 3,4 stay")
	ok(st[center] == "g0a", "evolve does not mutate the input state (returns a new map)")
	var st_inv := G.gen_evolve(st, r, center, "g1b")   # invalid: wrong predecessor
	ok(st_inv[center] == "g0a", "an invalid evolve is a no-op (old generator stays put)")

	# --- cell resolution + the live set per zone (interim "grant on zone entry") ---
	ok(G.gen_cell_of(r, "g0a") == Vector2i(4, 3), "a granted generator sits at its own cell")
	ok(G.gen_cell_of(r, "g1a") == Vector2i(4, 3), "an evolved generator inherits its predecessor's cell")
	ok(G.gen_cell_of(r, "g1c") == Vector2i(6, 5), "a surplus generator has its own cell")
	var s0 := G.live_gen_state(r, 0)
	ok(s0.size() == 2 and s0[Vector2i(4, 3)] == "g0a" and s0[Vector2i(2, 1)] == "g0b", "zone 0 live set: the 2 starters at their cells")
	var s1 := G.live_gen_state(r, 1)
	ok(s1.size() == 3 and s1[Vector2i(4, 3)] == "g1a" and s1[Vector2i(2, 1)] == "g1b" and s1[Vector2i(6, 5)] == "g1c", "zone 1 live set: 2 evolved (inherited cells) + 1 surplus")

	# --- the board model's STATEFUL, persisted generator map (movable #1 · evolve #2 · save #3) ---
	# Uses the LIVE grove roster (G.GENERATORS): satchel + compost in zone 0; z1a evolves_from satchel.
	var bm := BoardModel.new()
	bm.seed_gens(0)
	ok(bm.is_gen(Vector2i(4, 3)) and bm.is_gen(Vector2i(2, 1)) and bm.gens.size() == 2, "seed_gens(0): the 2 zone-0 starters are live")
	ok(bm.gen_id_at(Vector2i(4, 3)) == "satchel", "the center cell holds the satchel")
	ok(bm.gen_id_at(Vector2i(0, 0)) == "", "a non-generator cell has no generator id")
	# #1 movable: a generator relocates to an empty open cell, refuses an occupied/gen cell
	var dest := Vector2i(4, 4)
	bm.items[BoardModel.idx(dest)] = 0            # clear the starter item there
	ok(bm.move_gen(Vector2i(4, 3), dest), "a generator moves to an empty open cell")
	ok(bm.is_gen(dest) and not bm.is_gen(Vector2i(4, 3)), "moved: generator at the destination, gone from the origin")
	ok(not bm.move_gen(dest, Vector2i(2, 1)), "a generator can't move onto another generator")
	bm.move_gen(dest, Vector2i(4, 3))             # put it back
	# #2 evolve: deliver z1a as a grant (interim/debug stand-in for §7), merge it onto the satchel
	bm.gens[Vector2i(4, 4)] = "z1a"
	ok(not bm.evolve_gen(Vector2i(2, 1), Vector2i(4, 4)), "the grant won't evolve onto the wrong predecessor (compost)")
	ok(bm.evolve_gen(Vector2i(4, 3), Vector2i(4, 4)), "the grant evolves onto its predecessor, the satchel")
	ok(bm.gen_id_at(Vector2i(4, 3)) == "z1a" and not bm.gens.has(Vector2i(4, 4)), "old consumed; z1a installed at the satchel cell; grant cell freed")
	# #3 persistence: gens survive a save round-trip
	var blob := bm.to_dict()
	var bm2 := BoardModel.new()
	bm2.from_dict(blob)
	ok(bm2.gen_id_at(Vector2i(4, 3)) == "z1a" and bm2.is_gen(Vector2i(2, 1)) and bm2.gens.size() == 2, "the generator map round-trips through to_dict/from_dict")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
