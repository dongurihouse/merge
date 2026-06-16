extends SceneTree
## Headless tests for the idle-hint OPENABLE teach-signal (§2): when the idle hint
## highlights a mergeable pair, it also pulses the sealed cell(s) that merging that
## pair would OPEN. The decision is exposed as a pure seam — BoardLogic.openable_for_hint
## (board, pair, player_level) — so we assert it directly, no scene/window/Save.
##   godot --headless --path . -s res://engine/tests/hint_tests.gd
##
## Board geometry: the center 3×3 (incl. the generator at (4,3)) is open at start; the cells
## bordering it are sealed and gate at their grove_data.MIN_LEVEL (the owner's feel dial — re-tuned
## in T37 to open an L1 frontier). These tests read the gates via G.cell_min_level rather than
## pinning table values, so a re-tune of the diamond can't break them — they assert the
## openable-for-hint MECHANISM (§2): a sealed neighbour enters the hint set at/above its gate, not below.

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")

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
	# --- the table is the owner's feel dial (T37); derive the gates the cases use, don't pin them ---
	var g23 := G.cell_min_level(Vector2i(2, 3))    # (3,3)'s sealed orthogonal neighbour
	var g31 := G.cell_min_level(Vector2i(3, 1))    # (3,2)'s sealed neighbours…
	var g22 := G.cell_min_level(Vector2i(2, 2))
	var g41 := G.cell_min_level(Vector2i(4, 1))    # (4,2)'s sealed neighbour
	ok(g23 >= 1 and g31 >= 1 and g22 >= 1 and g41 >= 1, "fixture: the inner-frontier cells border the open center and are sealed")
	ok(G.cell_min_level(Vector2i(3, 3)) == 0 and G.cell_min_level(Vector2i(4, 3)) == 0, "fixture: the center + generator are open at start")

	# === Case 1: merging the pair WOULD open a sealed, level-REACHED cell ===
	# Pair on the open center: (3,3)'s only sealed orthogonal neighbour is (2,3); (4,3) borders open cells.
	var m1 := _board_with_pair(Vector2i(3, 3), Vector2i(4, 3))
	var pair1 := [Vector2i(3, 3), Vector2i(4, 3)]
	var open_at_gate: Array = BoardLogic.openable_for_hint(m1, pair1, g23)
	ok(_has(open_at_gate, Vector2i(2, 3)), "at (2,3)'s gate (L%d): the hint's openable set INCLUDES it" % g23)
	ok(open_at_gate.size() == 1, "only the one eligible neighbour is in the set")
	ok(_no_dupes(open_at_gate), "the openable set has no duplicate cells")

	# === Case 2: below a sealed cell's gate, the level gate keeps it OUT of the set ===
	# Use (3,1) (gate g31 >= 2 in any sane diamond) so "gate - 1" is a real player level.
	var m2 := _board_with_pair(Vector2i(3, 2), Vector2i(4, 2))
	var pair2 := [Vector2i(3, 2), Vector2i(4, 2)]
	if g31 >= 2:
		ok(not _has(BoardLogic.openable_for_hint(m2, pair2, g31 - 1), Vector2i(3, 1)), \
			"below (3,1)'s gate (L%d): the level gate keeps it out of the openable set" % g31)
	ok(_has(BoardLogic.openable_for_hint(m2, pair2, g31), Vector2i(3, 1)), \
		"at (3,1)'s gate (L%d): it enters the openable set" % g31)

	# === Case 3: nothing SEALED is adjacent → empty even at a high Level ===
	# Clear the terrain around the pair so openable_brambles finds no sealed neighbour.
	var m3 := _board_with_pair(Vector2i(3, 3), Vector2i(4, 3))
	for cell in [Vector2i(2, 3), Vector2i(3, 2), Vector2i(3, 4), Vector2i(2, 4),
			Vector2i(4, 2), Vector2i(4, 4), Vector2i(5, 3), Vector2i(1, 3)]:
		m3.terrain[BoardModel.idx(cell)] = 0     # force-open every neighbour cell
	var none_set: Array = BoardLogic.openable_for_hint(m3, pair1, 99)
	ok(none_set.is_empty(), "no sealed neighbour to open → empty set (pulse nothing extra, just the pair)")

	# === Case 4: the seam UNIONS both pair cells' eligible neighbours ===
	# (3,2) borders sealed (3,1) + (2,2); (4,2) borders sealed (4,1). At the highest of their gates, all open.
	var m4 := _board_with_pair(Vector2i(3, 2), Vector2i(4, 2))
	var pair4 := [Vector2i(3, 2), Vector2i(4, 2)]
	var lvl4: int = maxi(maxi(g31, g22), g41)
	var union_l: Array = BoardLogic.openable_for_hint(m4, pair4, lvl4)
	ok(_has(union_l, Vector2i(3, 1)) and _has(union_l, Vector2i(2, 2)), "L%d: includes (3,2)'s sealed neighbours (3,1) and (2,2)" % lvl4)
	ok(_has(union_l, Vector2i(4, 1)), "L%d: ALSO includes (4,2)'s sealed neighbour (4,1) — both pair cells contribute" % lvl4)
	ok(union_l.size() == 3 and _no_dupes(union_l), "the union is exactly the 3 distinct eligible cells")

	# === Case 5: an empty pair (no merge available) opens nothing ===
	ok(BoardLogic.openable_for_hint(m1, [], 99).is_empty(), "an empty pair → empty openable set")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
