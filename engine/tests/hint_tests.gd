extends SceneTree
## Headless tests for the idle-hint OPENABLE teach-signal (§2): when the idle hint
## highlights a mergeable pair, it also pulses the sealed cell(s) that merging that
## pair would OPEN. The decision is exposed as a pure seam — Board.openable_for_hint
## (board, pair, player_level) — so we assert it directly, no scene/window/Save.
##   godot --headless --path . -s res://engine/tests/hint_tests.gd
##
## Board geometry under test (grove_data.MIN_LEVEL, 9×7, generator at (4,3)):
##   r2: [8, 6, 2, 2, 2, 6, 8]      sealed cells unseal at their listed Level (§4)
##   r3: [6, 3, 0, 0, 0, 3, 6]      0 = open at start (center 3×3 + the generator)
##   r4: [4, 3, 0, 0, 0, 3, 4]
## So (2,3) is sealed at L2; (3,1)/(4,1) at L3; (2,2) at L2 — all border the open center.

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const Board = preload("res://engine/scripts/scenes/board.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# A bare board with a matching mergeable pair placed at `a` and `b` (same line/tier).
func _board_with_pair(a: Vector2i, b: Vector2i) -> BoardModel:
	var m := BoardModel.new()
	m.place(a, 1 * 100 + 1)      # line 1, tier 1
	m.place(b, 1 * 100 + 1)
	return m

func _has(arr: Array, cell: Vector2i) -> bool:
	return arr.has(cell)

func _no_dupes(arr: Array) -> bool:
	var seen := {}
	for c in arr:
		if seen.has(c):
			return false
		seen[c] = true
	return true

func _initialize() -> void:
	# --- guard the fixture: the table values the cases below rely on ---
	ok(G.cell_min_level(Vector2i(2, 3)) == 2, "fixture: (2,3) is sealed at L2")
	ok(G.cell_min_level(Vector2i(3, 1)) == 3, "fixture: (3,1) is sealed at L3")
	ok(G.cell_min_level(Vector2i(4, 1)) == 3, "fixture: (4,1) is sealed at L3")
	ok(G.cell_min_level(Vector2i(2, 2)) == 2, "fixture: (2,2) is sealed at L2")
	ok(G.cell_min_level(Vector2i(3, 3)) == 0, "fixture: (3,3) is open at start")
	ok(G.cell_min_level(Vector2i(4, 3)) == 0, "fixture: (4,3) (the generator) is open at start")

	# === Case 1: merging the pair WOULD open a sealed, level-REACHED cell ===
	# Pair on the open center: (3,3) borders sealed (2,3)[L2]; (4,3) borders only open cells.
	var m1 := _board_with_pair(Vector2i(3, 3), Vector2i(4, 3))
	var pair1 := [Vector2i(3, 3), Vector2i(4, 3)]
	var open_at_l2: Array = Board.openable_for_hint(m1, pair1, 2)
	ok(_has(open_at_l2, Vector2i(2, 3)), "L2: the hint's openable set INCLUDES the sealed level-reached neighbour (2,3)")
	ok(open_at_l2.size() == 1, "L2: only the one eligible neighbour is in the set")
	ok(_no_dupes(open_at_l2), "the openable set has no duplicate cells")

	# === Case 2: the same merge, but the player's Level has NOT reached the gate ===
	var open_at_l1: Array = Board.openable_for_hint(m1, pair1, 1)
	ok(open_at_l1.is_empty(), "L1 (< (2,3)'s min_level): nothing would open yet → empty set")

	# === Case 3: nothing SEALED is adjacent → empty even at a high Level ===
	# Clear the terrain around the pair so openable_brambles finds no sealed neighbour.
	var m3 := _board_with_pair(Vector2i(3, 3), Vector2i(4, 3))
	for cell in [Vector2i(2, 3), Vector2i(3, 2), Vector2i(3, 4), Vector2i(2, 4),
			Vector2i(4, 2), Vector2i(4, 4), Vector2i(5, 3), Vector2i(1, 3)]:
		m3.terrain[BoardModel.idx(cell)] = 0     # force-open every neighbour cell
	var none_set: Array = Board.openable_for_hint(m3, pair1, 99)
	ok(none_set.is_empty(), "no sealed neighbour to open → empty set (pulse nothing extra, just the pair)")

	# === Case 4: the seam UNIONS both pair cells' eligible neighbours ===
	# (3,2) borders sealed (3,1)[L3] + (2,2)[L2]; (4,2) borders sealed (4,1)[L3].
	var m4 := _board_with_pair(Vector2i(3, 2), Vector2i(4, 2))
	var pair4 := [Vector2i(3, 2), Vector2i(4, 2)]
	var union_l3: Array = Board.openable_for_hint(m4, pair4, 3)
	ok(_has(union_l3, Vector2i(3, 1)) and _has(union_l3, Vector2i(2, 2)), "L3: includes (3,2)'s sealed neighbours (3,1) and (2,2)")
	ok(_has(union_l3, Vector2i(4, 1)), "L3: ALSO includes (4,2)'s sealed neighbour (4,1) — both pair cells contribute")
	ok(union_l3.size() == 3 and _no_dupes(union_l3), "the union is exactly the 3 distinct eligible cells")

	# === Case 5: an empty pair (no merge available) opens nothing ===
	ok(Board.openable_for_hint(m1, [], 99).is_empty(), "an empty pair → empty openable set")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
