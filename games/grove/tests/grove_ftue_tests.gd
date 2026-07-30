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
const Improvements = preload("res://engine/scripts/core/improvements.gd")
const FeatureGate = preload("res://engine/scripts/core/feature_gate.gd")
const TeachRegistry = preload("res://engine/scripts/ui/teach_registry.gd")

func _initialize() -> void:
	begin("grove · ftue hand hint")
	await process_frame   # prime is_inside_tree() for every manual Board.tscn _ready() below

	await _test_fresh_board_presents_merge_hint()
	await _test_merge_seen_presents_gen_tap_hint()
	await _test_both_seen_presents_nothing()
	await _test_end_hand_hint_flag_off_dismisses_mismatched_id()
	await _test_flag_off_tears_down_live_hint()
	# EVERY improvement kind's seed teach, asserted the same way in both directions (see the
	# section header below): soil is the kind that already worked, magnet the one that did not.
	for kind in [Improvements.KIND_SOIL, Improvements.KIND_MAGNET]:
		await _test_seed_select_hands_off_to_place_chip(String(kind))
		await _test_seed_bag_dismisses_the_teach_at_once(String(kind))
		await _test_seed_sell_ends_the_teach(String(kind))
	finish()

# Boot a fresh Board.tscn in-tree, the way the other grove suites do (fresh() must be called
# first so _load_state() reads the intended save/ledger state).
func _open_board() -> Node:
	return board_host()

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

# --- the improvement-seed teach, PER KIND ---------------------------------------------------
# Every improvement seed teaches in two beats behind one ledger key: "<kind>_seed" points the hand
# at the seed on the board, and selecting that seed hands off to "<kind>_place" on the info bar's
# Place chip. The three sub-tests below are run for EVERY kind, because the bug they pin was a
# soil-only hardcode in three call sites (_select_item / _stash_confirmed / _sell_item) that left
# the magnet teach stuck on a seed the player had already tapped. Parameterised, not copy-pasted:
# a third kind is covered the day Improvements grows one.

# The ledger key `kind`'s seed teach banks — read off the spec array the scene owns, so the test
# cannot drift from the specs the way the old per-kind branches did.
func _seed_ledger(b: Node, kind: String) -> String:
	var spec: Dictionary = TeachRegistry.spec_for(b._teach_specs(), kind + "_seed")
	return String(spec.get("ledger", ""))

func _cell_center(b: Node, cell: Vector2i) -> Vector2:
	return b._cell_pos(cell) + Vector2(b.csz, b.csz) * 0.5

# A board carrying exactly ONE improvement seed of `kind`, with every teach ahead of it in the
# priority order already banked — so the only teach that can be live is that kind's own. The magnet
# leg arms its feature gate the way grove_gating_tests does (_set_level to G.FEATURE_LEVEL).
func _open_seed_teach_board(save_id: String, kind: String) -> Dictionary:
	fresh(save_id)
	Save.mark_board_tutorial_seen()
	for banked in ["merge", "gen_tap", "unlock_weather", "unlock_cascade", "soil"]:
		Save.mark_ftue_seen(String(banked))
	if kind != Improvements.KIND_SOIL:
		Save.mark_ftue_seen("soil_seed")     # the soil beats are behind us; only `kind` may teach
		Save.earn_coins(G.coins_at_level(int(G.FEATURE_LEVEL["magnet"])) - Save.coins_earned_lifetime())
	Save.grove_write()
	var b := _open_board()
	await _settle()
	if kind == Improvements.KIND_MAGNET:
		ok(FeatureGate.armed(kind), "%s setup: the magnet feature gate is armed" % kind)
	var code := Improvements.seed_code_for_kind(kind)
	var empties: Array = b.board.empty_ground_cells()
	var cell: Vector2i = empties[0] if not empties.is_empty() else Vector2i(-1, -1)
	ok(cell.x >= 0, "%s setup: the board offers an empty cell to seed" % kind)
	b.board.place(cell, code)
	b._rebuild_all()
	await _settle()
	ok(b._hand_hint_id == kind + "_seed", "%s setup: the seed teach is live on the board (id %s)" % [kind, b._hand_hint_id])
	return {"b": b, "cell": cell, "code": code}

# THE BUG: selecting the seed is not a board mutation, so nothing re-evaluates the teach unless the
# selection path does it — and it only did for soil. The hand stayed on a seed the player had
# already tapped, forever.
func _test_seed_select_hands_off_to_place_chip(kind: String) -> void:
	var setup := await _open_seed_teach_board("ftue_%s_select" % kind, kind)
	var b: Node = setup.b
	var cell: Vector2i = setup.cell
	_tap_board(b, _cell_center(b, cell))
	await _settle()
	ok(b._selected_cell == cell, "%s: tapping the seed selects its cell" % kind)
	ok(b._info_seed_place != null and b._info_seed_place.visible, "%s: ...and the Place chip appears" % kind)
	ok(b._hand_hint_id == kind + "_place",
		"%s: REGRESSION — selecting the seed hands the teach off to the Place beat (id %s)" % [kind, b._hand_hint_id])
	var hint := _live_hand_hint(b)
	var chip: Rect2 = b._local_rect(b._info_seed_place)
	var seed_rect: Rect2 = b._cell_local_rect(cell)
	var dst: Rect2 = hint._dst if hint != null else Rect2()
	ok(hint != null and dst.get_center().distance_to(chip.get_center()) <= 1.0,
		"%s: ...and the hand TARGETS the Place chip (%s vs chip %s)" % [kind, dst.get_center(), chip.get_center()])
	ok(hint != null and dst.get_center().distance_to(seed_rect.get_center()) > 1.0,
		"%s: ...not the cell the player already tapped" % kind)
	ok(not Save.ftue_seen(_seed_ledger(b, kind)), "%s: selecting the seed does not bank the lesson" % kind)
	b.queue_free()

# Bagging removes the taught thing WITHOUT teaching, so the hand must come down on the spot — not
# linger over an empty cell until _maybe_hand_hint's next frame await catches up.
func _test_seed_bag_dismisses_the_teach_at_once(kind: String) -> void:
	var setup := await _open_seed_teach_board("ftue_%s_bag" % kind, kind)
	var b: Node = setup.b
	var cell: Vector2i = setup.cell
	var code := int(setup.code)
	var ledger := _seed_ledger(b, kind)
	b._stash(cell, b.piece_nodes.get(cell))
	ok(b._hand_hint == null,
		"%s: REGRESSION — bagging the seed dismisses its teach at once (id %s)" % [kind, b._hand_hint_id])
	await _settle()
	ok(b.bag.has(code), "%s: bagging the seed stores it in the bag" % kind)
	ok(not Save.ftue_seen(ledger), "%s: bagging does not bank the lesson (%s stays unseen)" % [kind, ledger])
	b.queue_free()

# Selling takes the taught seed away, so the hand must come down AT ONCE for every kind. Whether the
# lesson is also BANKED (never taught again) is a per-kind call declared on the spec — soil's ledger
# is a pure teach record, magnet's doubles as the feature-unlock record _maybe_magnet_stage reads —
# so this reads the declaration rather than restating it, and asserts BOTH polarities really occur.
func _test_seed_sell_ends_the_teach(kind: String) -> void:
	var setup := await _open_seed_teach_board("ftue_%s_sell" % kind, kind)
	var b: Node = setup.b
	var cell: Vector2i = setup.cell
	var ledger := _seed_ledger(b, kind)
	_tap_board(b, _cell_center(b, cell))
	await _settle()
	b._on_trash_pressed()
	ok(b._hand_hint == null,
		"%s: REGRESSION — selling the seed takes the hand off it at once (id %s)" % [kind, b._hand_hint_id])
	await _settle()
	ok(b.board.item_at(cell) == 0, "%s: the Sell chip removes the seed from the board" % kind)
	var banks: bool = b._seed_teach_banks_on_sell(kind)
	ok(banks == (kind == Improvements.KIND_SOIL),
		"%s: the sell rule is declared on the spec (bank_on_sell %s)" % [kind, banks])
	ok(Save.ftue_seen(ledger) == banks,
		"%s: selling %s the lesson (%s %s seen)" % [kind, "banks" if banks else "does NOT bank", ledger, "is" if banks else "is not"])
	ok(b._hand_hint == null, "%s: ...and no teach is left pointing at the sold seed" % kind)
	b.queue_free()
