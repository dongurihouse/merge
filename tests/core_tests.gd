extends SceneTree
## Headless tests for the drag-any-to-any core + drawers.
##   godot --headless -s res://tests/core_tests.gd
const Board = preload("res://scripts/board.gd")
var _pass := 0
var _fail := 0
func ok(c: bool, l: String) -> void:
	if c:
		_pass += 1
		print("  PASS  ", l)
	else:
		_fail += 1
		print("  FAIL  ", l)

func _initialize() -> void:
	print("== core tests ==")
	# drawer (-2) is not a piece, and blocks is_cleared until popped
	var b := Board.new(1, 3, [101, 0, Board.DRAWER], 3)
	ok(not Board.is_piece(Board.DRAWER), "DRAWER is not a piece")
	ok(not b.is_cleared(), "closed drawer keeps board not-cleared")
	b.grid = [0, 0, 0]
	ok(b.is_cleared(), "empty board is cleared")
	# drag-any-to-any: two of the same code merge regardless of position (apply_merge)
	var b2 := Board.new(1, 3, [101, 0, 101], 3)
	b2.apply_merge(0, 0, 0, 2)        # non-adjacent same-code merge
	ok(b2.at(0, 0) == 0 and b2.at(0, 2) == 102, "non-adjacent same-code merge bumps a tier")
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
