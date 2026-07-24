extends "res://games/grove/tests/grove_test_base.gd"
## grove · FTUE hand hint — board-level wiring for the merge / generator-tap teach overlays
## (engine/scripts/scenes/board.gd: _maybe_hand_hint / _hand_hint_eligible / _hand_hint_gen_cell /
## _hand_hint_rects / _dismiss_hand_hint / _end_hand_hint), driving the real overlay
## (engine/scripts/ui/hand_hint.gd) on a real, in-tree Board.tscn.
##
## engine/tests/ftue_hand_hint_tests.gd exercises the overlay alone on a bare Control host and
## cannot prove this wiring (a reviewer confirmed it still passes with the board.gd fix reverted).
## That file's own regression comment explains why a board-level assertion was abandoned THERE: its
## bare-SceneTree harness never pumps a frame before the first Board.tscn _ready(), so
## is_inside_tree() reads false partway through _ready() and `await get_tree().process_frame`
## (inside _maybe_hand_hint) errors off a null tree.
##
## This suite dodges that the same way grove_shop_tests.gd's board sections do: an `await
## process_frame` runs before the FIRST manual Board.tscn _ready() call, so by the time _ready()
## runs the suite is already executing inside a real frame and add_child()'d nodes enter the tree
## normally.
##
## New suite (not folded into an existing one): none of the active suites are about FTUE /
## onboarding — grove_board_actions_tests is the pure no-scene action layer; grove_explore_tests,
## grove_shop_tests, and the *_workbench suites cover unrelated surfaces (explore rush, IAP/shop,
## art-authoring tools). grove_shop_tests.gd already instantiates Board.tscn repeatedly and is the
## closest fit mechanically, but it's already the largest suite and topically about monetization,
## not FTUE — a fresh, focused suite reads better and keeps this slice independently runnable
## (`make test-one SUITE=games/grove/tests/grove_ftue_tests`). Registered in the Makefile's
## GROVE_TESTS.

const HandHint = preload("res://engine/scripts/ui/hand_hint.gd")

func _initialize() -> void:
	begin("grove · ftue hand hint")
	await process_frame   # prime is_inside_tree() for every manual Board.tscn _ready() below

	await _test_fresh_board_presents_merge_hint()
	await _test_merge_seen_presents_gen_tap_hint()
	await _test_both_seen_presents_nothing()
	await _test_end_hand_hint_flag_off_dismisses_mismatched_id()
	await _test_flag_off_tears_down_live_hint()
	finish()

# Boot a fresh Board.tscn in-tree, the way the other grove suites do (fresh() must be called
# first so _load_state() reads the intended save/ledger state).
func _open_board() -> Node:
	var b = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(b)
	if b.board == null:
		b._ready()
	return b

# Let _maybe_hand_hint's `await get_tree().process_frame` (fired off at the end of _rebuild_all,
# not awaited by its caller) resolve before the test reads the board's hint state.
func _settle() -> void:
	await process_frame
	await process_frame

# Any hand-hint overlay child of `b` (matched by SCRIPT, not name — a dismiss()-in-flight node
# briefly coexisting with a freshly-presented one gets auto-renamed "HandHint2" by add_child's
# own collision handling, so name-matching silently misses it), dismissed or not.
func _any_hand_hint(b: Node) -> Control:
	for c in b.get_children():
		if c is Control and (c as Control).get_script() == HandHint:
			return c as Control
	return null

# The live (not-yet-dismissed) hand-hint child of `b`, or null. A dismiss() fades over ~0.18s
# before queue_free — a swap can briefly leave an old, dismissed node alongside a new live one —
# so this filters for the one that hasn't been told to dismiss.
func _live_hand_hint(b: Node) -> Control:
	for c in b.get_children():
		if c is Control and (c as Control).get_script() == HandHint and not bool(c.get("dismissed")):
			return c as Control
	return null

func _test_fresh_board_presents_merge_hint() -> void:
	fresh("ftue_merge_fresh")
	var b := _open_board()
	await _settle()
	var hint := _live_hand_hint(b)
	ok(hint != null, "a fresh ledger on a fresh board presents a live HandHint overlay")
	ok(hint != null and hint.gesture == HandHint.GESTURE_DRAG, "...and it's the drag (merge) gesture")
	ok(b._hand_hint_id == "merge", "the board's own hint id tracks 'merge'")
	b.queue_free()

func _test_merge_seen_presents_gen_tap_hint() -> void:
	fresh("ftue_gen_tap")
	var b := _open_board()
	await _settle()
	ok(b._hand_hint_id == "merge", "setup: the merge hint is live before it's marked seen")
	var old_hint: Control = b._hand_hint
	Save.mark_ftue_seen("merge")
	b._rebuild_all()                      # the real trigger: _maybe_hand_hint runs at its end
	await _settle()
	var hint := _live_hand_hint(b)
	ok(hint != null, "marking merge seen and rebuilding presents a live HandHint overlay")
	ok(hint != old_hint, "...a NEW overlay (the merge hint was swapped out, not retargeted)")
	ok(hint != null and hint.gesture == HandHint.GESTURE_TAP, "...and it's the tap (generator) gesture")
	ok(b._hand_hint_id == "gen_tap", "the board's own hint id tracks 'gen_tap'")
	b.queue_free()

func _test_both_seen_presents_nothing() -> void:
	fresh("ftue_both_seen")
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	var b := _open_board()
	await _settle()
	ok(b._hand_hint == null, "with both hints seen, nothing is presented (no live overlay)")
	ok(_any_hand_hint(b) == null, "...and no hand-hint node is in the tree at all")
	b.queue_free()

# Finding B: _end_hand_hint's dismiss must not stay gated on `_hand_hint_id == id` once the flag
# is off — a live hint of a DIFFERENT id must not linger until some later, unrelated rebuild.
func _test_end_hand_hint_flag_off_dismisses_mismatched_id() -> void:
	fresh("ftue_end_hint_mismatch")
	var b := _open_board()
	await _settle()
	ok(b._hand_hint_id == "merge", "setup: the live hint is the merge teach")
	var live: Control = b._hand_hint
	var orig := bool(Feat.FLAGS.get("ftue_hand_hint", true))
	Feat.FLAGS["ftue_hand_hint"] = false
	b._end_hand_hint("gen_tap")           # a MISMATCHED id — the old id-gated dismiss would skip this
	ok(b._hand_hint == null, "flag off + a mismatched id still tears down the live hint")
	ok(live != null and live.dismissed, "...and the overlay itself was told to dismiss")
	Feat.FLAGS["ftue_hand_hint"] = orig
	b.queue_free()

# The regression itself: a hint live on screen must be torn down the moment the flag flips off
# and the board rebuilds — not left stuck until some later merge/tap no-ops it away.
func _test_flag_off_tears_down_live_hint() -> void:
	fresh("ftue_flag_off_teardown")
	var b := _open_board()
	await _settle()
	var live: Control = b._hand_hint
	ok(live != null and is_instance_valid(live) and not live.dismissed,
		"setup: a hint is live before the flag flips off")
	var orig := bool(Feat.FLAGS.get("ftue_hand_hint", true))
	Feat.FLAGS["ftue_hand_hint"] = false
	b._rebuild_all()                      # the real trigger path (_maybe_hand_hint runs at its end)
	await _settle()
	ok(b._hand_hint == null, "REGRESSION: flipping the flag off and rebuilding clears the board's hint reference")
	ok(live != null and live.dismissed, "REGRESSION: ...and the overlay itself was told to dismiss (not just orphaned)")
	Feat.FLAGS["ftue_hand_hint"] = orig
	b.queue_free()
