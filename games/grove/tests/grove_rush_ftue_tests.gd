extends "res://games/grove/tests/grove_test_base.gd"
## grove · Rush FTUE hand hints — the scene wiring in engine/scripts/scenes/explore_rush.gd
## (_refresh_hand_hint / _hand_hint_cell_rect / _dismiss_hand_hint / _end_hand_hint) driving the reused
## overlay (engine/scripts/ui/hand_hint.gd) on a real, in-tree ExploreRush.tscn.
## Spec: docs/superpowers/specs/2026-07-23-ftue-rush-hand-hint-design.md

## Feat, G and Save are inherited from grove_test_base.gd — redeclaring them is a parse error.
const Explore = preload("res://engine/scripts/core/explore.gd")
const HandHint = preload("res://engine/scripts/ui/hand_hint.gd")

func _initialize() -> void:
	begin("grove · rush ftue hand hint")
	await process_frame   # prime is_inside_tree() before the manual ExploreRush _ready() calls
	await _test_flag_off_presents_nothing()
	await _test_merge_pair_presents_merge_hint()
	await _test_telegraph_presents_treefall_over_merge()
	finish()

# A live, frozen ExploreRush on a known-EMPTY board. _ready()->_start() builds an all-null grid and
# leaves _running = true; freezing _process stops tiles spawning / the treefall clock advancing under us.
func _rush() -> Node:
	Explore.begin_run({})
	Save.mark_rush_intro_seen()   # spend the first-run how-to popup so it can't cover the hint
	var s = rush_host()
	s.set_process(false)          # freeze the frame loop; we drive state by hand
	return s

func _live_hand_hint(s: Node) -> Control:
	for c in s.get_children():
		if c is Control and (c as Control).get_script() == HandHint and not bool(c.get("dismissed")):
			return c as Control
	return null

func _test_flag_off_presents_nothing() -> void:
	fresh("rush_ftue_flag_off")
	var orig := bool(Feat.FLAGS.get("ftue_rush_hint", true))
	Feat.FLAGS["ftue_rush_hint"] = false
	var s := _rush()
	s._grid[8][0] = {"kind": 1, "tier": 1, "node": null}
	s._grid[8][1] = {"kind": 1, "tier": 1, "node": null}
	s._refresh_hand_hint()
	ok(_live_hand_hint(s) == null, "flag off: a mergeable pair presents no hint")
	Feat.FLAGS["ftue_rush_hint"] = orig
	await drop(s)

func _test_merge_pair_presents_merge_hint() -> void:
	fresh("rush_ftue_merge")
	var s := _rush()
	# a mergeable pair on the bottom row
	s._grid[8][0] = {"kind": 1, "tier": 1, "node": null}
	s._grid[8][1] = {"kind": 1, "tier": 1, "node": null}
	s._refresh_hand_hint()
	var hint := _live_hand_hint(s)
	ok(hint != null, "a mergeable pair presents a live hand hint")
	ok(hint != null and hint.gesture == HandHint.GESTURE_TAP, "...as the tap gesture")
	ok(s._hand_hint_id == "rush_merge", "...and the scene tracks the rush_merge id")
	# the taught cell rect lines up with the real board cell geometry
	var want := Rect2(s._board.position + s._cell_rest(8, 0), Vector2(s._tile_px(), s._tile_px()))
	ok(s._hand_hint_cell_rect(8, 0).is_equal_approx(want), "the rect matches the board cell geometry")
	# performing the merge banks it and clears the hint; a second refresh does not re-present
	s._end_hand_hint("rush_merge")
	ok(Save.ftue_seen("rush_merge"), "the merge teach is marked seen")
	ok(_live_hand_hint(s) == null, "...and the hint is dismissed")
	s._refresh_hand_hint()
	ok(_live_hand_hint(s) == null, "a seen merge teach never re-presents")
	await drop(s)

func _test_telegraph_presents_treefall_over_merge() -> void:
	fresh("rush_ftue_treefall")
	var s := _rush()
	# a mergeable pair (merge unseen) AND a telegraph over a filled column 3
	s._grid[8][0] = {"kind": 1, "tier": 1, "node": null}
	s._grid[8][1] = {"kind": 1, "tier": 1, "node": null}
	s._grid[8][3] = {"kind": 2, "tier": 1, "node": null}
	s._tf = {"ph": "tele", "t": 0.0, "col": 3, "next": 9.0}
	s._refresh_hand_hint()
	var hint := _live_hand_hint(s)
	ok(hint != null and s._hand_hint_id == "rush_treefall", "a telegraph beats an unseen merge teach")
	var want := Rect2(s._board.position + s._cell_rest(8, 3), Vector2(s._tile_px(), s._tile_px()))
	ok(s._hand_hint_cell_rect(8, 3).is_equal_approx(want), "the treefall hint points at the bottom tile of the doomed column")
	# dodging (a fling out of the danger column) banks it; the telegraph then yields to the merge teach
	s._end_hand_hint("rush_treefall")
	ok(Save.ftue_seen("rush_treefall"), "the dodge teach is marked seen")
	ok(s._hand_hint_id == "rush_merge", "with the treefall seen, the merge teach follows during the same telegraph")
	await drop(s)
