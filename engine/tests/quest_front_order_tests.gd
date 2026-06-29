extends SceneTree
## Headless tests for the FENCE ORDER assist (board.gd + core/quests.gd::ready_first): a quest whose
## asked item is on the board (DELIVERABLE) floats to the FRONT of the giver fence so the player can
## find and hand it in at a glance. Drives the live Board scene with the board's OWN generated quests
## (real fence + giver cards), reordering through the REAL hooks: _rebuild_givers (initial layout) and
## _refresh_giver_lights (the live beat every board change runs). Display-only — the persisted `quests`
## array order is never mutated. Gated by Features.on("quest_ready_front").
##   godot --headless --path . -s res://engine/tests/quest_front_order_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Quests = preload("res://engine/scripts/core/quests.gd")
const Features = preload("res://engine/scripts/core/features.gd")
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

func fresh(name: String) -> void:
	var dir := "user://tu_qfront_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _board() -> Node:
	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(scn)
	if scn.board == null:
		scn._ready()
	return scn

# The qi rendered on each giver card, left→right (the fence's bookkeeping order).
func _rendered_order(scn) -> Array:
	var out: Array = []
	for e in scn.giver_chips:
		out.append(int(e.get("qi", -1)))
	return out

# The qi of each giver card as it actually sits in the live row, left→right (the VISUAL order —
# the leading Purge card, if any, is skipped since it is not a giver chip).
func _row_child_qi(scn) -> Array:
	var chip_to_qi := {}
	for e in scn.giver_chips:
		chip_to_qi[e.chip] = int(e.get("qi", -1))
	var out: Array = []
	for child in scn._giver_row.get_children():
		if chip_to_qi.has(child):
			out.append(int(chip_to_qi[child]))
	return out

func _payable_count(scn) -> int:
	var n := 0
	for q in scn.quests:
		if BoardLogic.quest_payable(scn.board, q):
			n += 1
	return n

# Place the asked item for quest `qi` on a free board cell, so that quest becomes deliverable.
func _make_payable(scn, qi: int) -> void:
	var it: Dictionary = G.quest_item(scn.quests[qi])
	var code := int(it.line) * 100 + int(it.tier)
	var cell: Vector2i = scn.board.empty_ground_cells()[0]
	scn.board.place(cell, code)
	scn._rebuild_pieces()

func _seq(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append(i)
	return out

func _initialize() -> void:
	print("== Quest fence front-order tests ==")

	# --- Part A: a DELIVERABLE quest renders at the FRONT after a rebuild; the rest hold their order ---
	fresh("rebuild")
	var scn = _board()
	scn._rebuild_givers()
	ok(scn.quests.size() >= 3, "the fresh fence carries at least three quests")
	ok(_payable_count(scn) == 0, "no quest is deliverable on the fresh board")
	ok(_rendered_order(scn) == _seq(scn.quests.size()), "the fence starts in array order")
	var n: int = scn.quests.size()
	var target := n - 1                                 # the LAST quest — a real jump to the front
	_make_payable(scn, target)
	ok(_payable_count(scn) == 1, "exactly one quest is now deliverable")
	ok(BoardLogic.quest_payable(scn.board, scn.quests[target]), "the target (last) quest is the deliverable one")
	scn._rebuild_givers()
	var order: Array = _rendered_order(scn)
	ok(order[0] == target, "the deliverable quest renders at the FRONT of the fence (qi %d first)" % target)
	var rest_expected: Array = []
	for i in range(n):
		if i != target:
			rest_expected.append(i)
	ok(order.slice(1) == rest_expected, "the remaining quests hold their original order behind it (stable)")
	ok(scn.quests.size() == n, "the persisted quests array is NOT mutated by the display reorder")
	scn.free()

	# --- Part B: LIVE reorder on the refresh beat — a quest going deliverable floats to the front WITHOUT
	# a full rebuild (the hook every merge/board change runs is _refresh_giver_lights, not _rebuild_givers) ---
	fresh("live")
	scn = _board()
	scn._rebuild_givers()
	ok(_rendered_order(scn) == _seq(scn.quests.size()), "the fence starts in array order (nothing deliverable)")
	var t2: int = scn.quests.size() - 1
	_make_payable(scn, t2)
	scn._refresh_giver_lights()                         # the LIVE beat — no _rebuild_givers
	ok(_rendered_order(scn)[0] == t2, "becoming deliverable floats the card to the front on the live refresh beat")
	ok(_row_child_qi(scn)[0] == t2, "the live row reorders its actual child cards to match (visual order)")
	# losing deliverability returns the card to its place (symmetric — take the item back off the board)
	scn.board.take(scn.board.first_item_of(_payable_code(scn, t2)))
	scn._rebuild_pieces()
	scn._refresh_giver_lights()
	ok(_rendered_order(scn) == _seq(scn.quests.size()), "no longer deliverable → the card settles back to array order")
	scn.free()

	# --- Part C: the feature flag gates it — flag OFF leaves the fence in array order ---
	Features.FLAGS["quest_ready_front"] = false
	fresh("flagoff")
	scn = _board()
	var t3: int = scn.quests.size() - 1
	_make_payable(scn, t3)
	scn._rebuild_givers()
	ok(_rendered_order(scn)[0] == 0, "flag off (rebuild) → the fence keeps array order even with a deliverable quest")
	scn._refresh_giver_lights()
	ok(_rendered_order(scn)[0] == 0, "flag off (live beat) → still no reorder")
	Features.FLAGS["quest_ready_front"] = true
	scn.free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)

# The asked item code for quest qi (line*100+tier).
func _payable_code(scn, qi: int) -> int:
	var it: Dictionary = G.quest_item(scn.quests[qi])
	return int(it.line) * 100 + int(it.tier)
