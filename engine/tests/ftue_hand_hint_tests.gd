extends SceneTree
## Headless tests for the FTUE hand hints (spec: docs/superpowers/specs/2026-07-23-ftue-hand-hint-design.md).
##   godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd

const Save = preload("res://engine/scripts/core/save.gd")
const Feat = preload("res://engine/scripts/core/features.gd")
const HandHint = preload("res://engine/scripts/ui/hand_hint.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# The overlay must never eat a touch — the player performs the real gesture through it.
func _all_ignore_mouse(n: Node) -> bool:
	if n is Control and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for c in n.get_children():
		if not _all_ignore_mouse(c):
			return false
	return true

# --- veil geometry helpers ---------------------------------------------------------------
# cutouts() only asserts the LOGICAL bright rects; these read the real ColorRect band children
# _rebuild_veil()/_subtract() produced, so the rectangle-subtraction geometry itself is under
# test, not just what it's supposed to produce.

# The dim's actual ColorRect bands, as Rect2 in host space.
func _veil_bands(overlay: Control) -> Array:
	var out: Array = []
	for c in overlay._veil.get_children():
		if c is ColorRect:
			out.append(Rect2((c as ColorRect).position, (c as ColorRect).size))
	return out

func _sum_area(rects: Array) -> float:
	var total := 0.0
	for r in rects:
		var rr := r as Rect2
		total += rr.size.x * rr.size.y
	return total

# The union area of 1-2 rects (cutouts() never returns more) — a plain sum double-counts a
# shared overlap, so this subtracts the shared intersection once.
func _rect_union_area(rects: Array) -> float:
	if rects.is_empty():
		return 0.0
	if rects.size() == 1:
		return _sum_area(rects)
	var a := rects[0] as Rect2
	var b := rects[1] as Rect2
	var inter := a.intersection(b)
	var inter_area := 0.0
	if inter.size.x > 0.0 and inter.size.y > 0.0:
		inter_area = inter.size.x * inter.size.y
	return (a.size.x * a.size.y) + (b.size.x * b.size.y) - inter_area

# True iff no rect in `rects_a` has positive-area overlap with any rect in `rects_b`.
func _no_overlap(rects_a: Array, rects_b: Array) -> bool:
	for a in rects_a:
		for b in rects_b:
			var inter := (a as Rect2).intersection(b as Rect2)
			if inter.size.x > 0.01 and inter.size.y > 0.01:
				return false
	return true

# True iff no two rects WITHIN `rects` overlap each other (the bands must tile disjointly).
func _no_self_overlap(rects: Array) -> bool:
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			var inter := (rects[i] as Rect2).intersection(rects[j] as Rect2)
			if inter.size.x > 0.01 and inter.size.y > 0.01:
				return false
	return true

func _all_sizes_nonnegative(rects: Array) -> bool:
	for r in rects:
		var rr := r as Rect2
		if rr.size.x < 0.0 or rr.size.y < 0.0:
			return false
	return true

# Point Save at a clean temp dir (never touches the real save).
func fresh(name: String) -> void:
	var dir := "user://tu_ftue_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _initialize() -> void:
	print("== FTUE hand hint tests ==")

	# --- the seen-once ledger ---
	fresh("ledger")
	ok(not Save.ftue_seen("merge"), "fresh save: merge is unseen")
	ok(not Save.ftue_seen("gen_tap"), "fresh save: gen_tap is unseen")
	ok(not Save.ftue_seen("nonsense"), "an unknown id reads as unseen (never crashes)")

	Save.mark_ftue_seen("merge")
	ok(Save.ftue_seen("merge"), "marking merge makes it seen")
	ok(not Save.ftue_seen("gen_tap"), "marking merge leaves gen_tap alone")

	Save.mark_ftue_seen("merge")
	ok(Save.ftue_seen("merge"), "marking twice is idempotent")

	Save.load_now()   # round-trip through the JSON file
	ok(Save.ftue_seen("merge"), "seen state survives a reload")
	ok(not Save.ftue_seen("gen_tap"), "unseen state survives a reload")

	# An old save with no ftue_seen key at all deep-merges over the defaults.
	fresh("oldsave")
	Save.data.erase("ftue_seen")
	ok(not Save.ftue_seen("merge"), "a save missing the ftue_seen key reads as unseen (no migration)")

	# --- the flag ---
	ok(Feat.FLAGS.has("ftue_hand_hint"), "the ftue_hand_hint flag exists")
	ok(Feat.on("ftue_hand_hint"), "the ftue_hand_hint flag defaults ON")

	# --- the overlay ---
	var host := Control.new()
	host.size = Vector2(800, 1200)
	root.add_child(host)

	var src := Rect2(100, 200, 60, 60)
	var dst := Rect2(300, 200, 60, 60)

	var drag: Control = HandHint.present(host, HandHint.GESTURE_DRAG, src, dst)
	ok(drag != null, "drag: present returns an overlay")
	ok(drag.get_parent() == host, "drag: the overlay is parented to the host")
	ok(drag.gesture == HandHint.GESTURE_DRAG, "drag: the gesture is recorded")
	var cuts: Array = drag.cutouts()
	ok(cuts.size() == 2, "drag: two cutouts (source + target)")
	ok((cuts[0] as Rect2).get_center().is_equal_approx(src.get_center()), "drag: cutout 0 is centred on the source")
	ok((cuts[1] as Rect2).get_center().is_equal_approx(dst.get_center()), "drag: cutout 1 is centred on the target")
	ok(_all_ignore_mouse(drag), "drag: every node in the overlay ignores mouse input (never blocks play)")

	drag.retarget(Rect2(0, 0, 60, 60), Rect2(200, 0, 60, 60))
	var moved: Array = drag.cutouts()
	ok((moved[0] as Rect2).get_center().is_equal_approx(Vector2(30, 30)), "retarget: cutout 0 follows the new source")
	ok((moved[1] as Rect2).get_center().is_equal_approx(Vector2(230, 30)), "retarget: cutout 1 follows the new target")
	ok(drag.get_parent() == host, "retarget: the overlay stays live (no re-present)")

	# retarget() must NOT restart the loop when the geometry hasn't actually moved (the spec's "in
	# place... without restarting its loop") — a rebuild that leaves the cells where they were must
	# not snap the hand back to the source mid-glide. A genuine move is allowed to restart it.
	var tween_unchanged: Tween = drag._tween
	drag.retarget(Rect2(0, 0, 60, 60), Rect2(200, 0, 60, 60))   # the SAME rects as just above
	ok(drag._tween == tween_unchanged, "retarget: unchanged geometry keeps the same loop tween running (no restart)")
	var tween_before_move: Tween = drag._tween
	drag.retarget(Rect2(5, 5, 60, 60), Rect2(205, 5, 60, 60))   # genuinely moved
	ok(drag._tween != tween_before_move, "retarget: geometry that actually moved DOES restart the loop tween")

	drag.dismiss()
	ok(drag.dismissed, "dismiss: the overlay is marked dismissed immediately (the fade then frees it)")

	var tap: Control = HandHint.present(host, HandHint.GESTURE_TAP, Rect2(), dst)
	ok(tap != null, "tap: present returns an overlay")
	ok(tap.cutouts().size() == 1, "tap: one cutout (the target only)")
	ok(_all_ignore_mouse(tap), "tap: every node ignores mouse input")
	tap.dismiss()

	# A FRESH host, so the dismissed-but-still-fading overlays above can't be miscounted here.
	var host2 := Control.new()
	host2.size = Vector2(800, 1200)
	root.add_child(host2)
	Feat.FLAGS["ftue_hand_hint"] = false
	ok(HandHint.present(host2, HandHint.GESTURE_TAP, Rect2(), dst) == null, "flag off: present returns null")
	ok(host2.get_child_count() == 0, "flag off: nothing is added to the host")
	Feat.FLAGS["ftue_hand_hint"] = true

	# --- the veil's rectangle-subtraction geometry ---
	# _rebuild_veil()/_subtract() build the dim as real ColorRect bands covering the screen minus
	# each grown cutout; these measure the actual bands rather than just the logical cutouts().
	var vhost := Control.new()
	vhost.size = Vector2(800, 600)
	root.add_child(vhost)
	var vhost_area := vhost.size.x * vhost.size.y

	# one cutout (tap)
	var v_tap: Control = HandHint.present(vhost, HandHint.GESTURE_TAP, Rect2(), Rect2(300, 200, 60, 60))
	var v_tap_cuts: Array = v_tap.cutouts()
	var v_tap_bands := _veil_bands(v_tap)
	ok(is_equal_approx(_sum_area(v_tap_bands), vhost_area - _rect_union_area(v_tap_cuts)),
		"veil: tap bands' total area == host area minus the grown cutout")
	ok(_no_overlap(v_tap_bands, v_tap_cuts), "veil: tap bands never overlap the cutout")
	v_tap.dismiss()

	# two cutouts, disjoint (drag)
	var v_drag: Control = HandHint.present(vhost, HandHint.GESTURE_DRAG, Rect2(50, 50, 60, 60), Rect2(500, 400, 60, 60))
	var v_drag_cuts: Array = v_drag.cutouts()
	var v_drag_bands := _veil_bands(v_drag)
	ok(is_equal_approx(_sum_area(v_drag_bands), vhost_area - _rect_union_area(v_drag_cuts)),
		"veil: drag bands' total area == host area minus both grown cutouts")
	ok(_no_overlap(v_drag_bands, v_drag_cuts), "veil: drag bands never overlap either cutout")
	v_drag.dismiss()

	# two cutouts that OVERLAP each other
	var v_ov: Control = HandHint.present(vhost, HandHint.GESTURE_DRAG, Rect2(100, 100, 100, 100), Rect2(150, 130, 100, 100))
	var v_ov_cuts: Array = v_ov.cutouts()
	var v_ov_bands := _veil_bands(v_ov)
	ok(is_equal_approx(_sum_area(v_ov_bands), vhost_area - _rect_union_area(v_ov_cuts)),
		"veil: overlapping cutouts — bands' total area == host area minus the UNION (no double-counted area)")
	ok(_no_self_overlap(v_ov_bands), "veil: overlapping cutouts — the bands themselves have no gaps or overlaps")
	ok(_no_overlap(v_ov_bands, v_ov_cuts), "veil: overlapping cutouts — no band overlaps either cutout")
	v_ov.dismiss()

	# a cutout lying partly offscreen
	var v_off: Control = HandHint.present(vhost, HandHint.GESTURE_TAP, Rect2(), Rect2(-20, 250, 60, 60))
	var v_off_cuts: Array = v_off.cutouts()
	var v_off_bands := _veil_bands(v_off)
	var v_off_onscreen: Rect2 = (v_off_cuts[0] as Rect2).intersection(Rect2(Vector2.ZERO, vhost.size))
	var v_off_onscreen_area := 0.0
	if v_off_onscreen.size.x > 0.0 and v_off_onscreen.size.y > 0.0:
		v_off_onscreen_area = v_off_onscreen.size.x * v_off_onscreen.size.y
	ok(is_equal_approx(_sum_area(v_off_bands), vhost_area - v_off_onscreen_area),
		"veil: an off-screen-partial cutout — bands still tile the visible screen (only the on-screen sliver is punched out)")
	ok(_all_sizes_nonnegative(v_off_bands), "veil: an off-screen-partial cutout — no band has a negative size")
	ok(_no_overlap(v_off_bands, v_off_cuts), "veil: an off-screen-partial cutout — no band overlaps the (clipped) cutout")
	v_off.dismiss()

	# --- retarget() after dismiss() is a no-op ---
	# dismiss() starts a fade-then-queue_free tween; a mis-sequenced caller must not be able to
	# restart a looping tween (or rebuild the veil) on a node that is already dying.
	var v_guard: Control = HandHint.present(vhost, HandHint.GESTURE_TAP, Rect2(), Rect2(300, 200, 60, 60))
	v_guard.dismiss()
	var guard_cuts_before: Array = v_guard.cutouts()
	v_guard.retarget(Rect2(0, 0, 10, 10), Rect2(0, 0, 10, 10))
	var guard_cuts_after: Array = v_guard.cutouts()
	ok((guard_cuts_after[0] as Rect2).is_equal_approx(guard_cuts_before[0] as Rect2),
		"retarget after dismiss: a no-op — the target doesn't move")

	# --- double-dim guard: presenting a new hint must not leave a fading old one compositing too ---
	# dismiss() fades its veil over 0.18s before queue_free; a caller that immediately presents a
	# NEW hint on the same host (board.gd's merge -> gen_tap handoff) used to leave both veils live
	# at once, stacking to roughly double the intended dim. present() must free a stale hint outright.
	var swap_host := Control.new()
	swap_host.size = Vector2(400, 300)
	root.add_child(swap_host)
	var first: Control = HandHint.present(swap_host, HandHint.GESTURE_DRAG, Rect2(0, 0, 50, 50), Rect2(200, 0, 50, 50))
	first.dismiss()   # starts the 0.18s fade — still in the tree, still compositing
	var second: Control = HandHint.present(swap_host, HandHint.GESTURE_TAP, Rect2(), Rect2(200, 0, 50, 50))
	ok(not is_instance_valid(first), "double-dim guard: presenting a new hint frees a still-fading old one immediately")
	var live_hint_nodes := 0
	for c in swap_host.get_children():
		if c is Control and (c as Control).get_script() == HandHint:
			live_hint_nodes += 1
	ok(live_hint_nodes == 1, "double-dim guard: only ONE hand-hint node composites on the host at a time")
	second.dismiss()

	# --- eligibility order (pure seam — no scene needed) ---
	# merge first; gen_tap only once merge is seen; nothing once both are seen.
	ok(HandHint.next_hint_id(false, false, true, true) == "merge", "fresh board: merge is the eligible hint")
	ok(HandHint.next_hint_id(true, false, true, true) == "gen_tap", "merge seen: gen_tap follows")
	ok(HandHint.next_hint_id(true, true, true, true) == "", "both seen: nothing is eligible")
	ok(HandHint.next_hint_id(false, false, false, true) == "", "no mergeable pair: the merge hint waits (does not skip ahead)")
	ok(HandHint.next_hint_id(true, false, true, false) == "", "no generator node: gen_tap waits")
	# skip-if-already-done: the player popped the generator during the merge hint.
	ok(HandHint.next_hint_id(false, true, true, true) == "merge", "gen_tap already done: merge still shows")
	ok(HandHint.next_hint_id(true, true, true, true) == "", "gen_tap already done: it never shows afterwards")

	# --- regression: a live hint must be torn down when the flag flips off, not stuck forever ---
	# board.gd's _maybe_hand_hint / _end_hand_hint now call dismiss() on any live overlay BEFORE
	# their own flag early-return (the bug: both used to early-return first, so a hint already on
	# screen when ftue_hand_hint flipped off could never be cleared — even a real merge no-op'd).
	# The board-level orchestration itself (_maybe_hand_hint / _end_hand_hint) needs a real,
	# fully-in-tree Board.tscn instance to assert directly. That was attempted here first: it
	# instantiates (its own deps are all static preloads, no project autoloads needed), but calling
	# its _ready() the way games/grove/tests/grove_test_base.gd's board tests do only works there
	# because, by the point they reach it, an earlier awaited call in that same suite has already
	# pumped a frame — is_inside_tree() is true by then. This bare, frame-naive suite never pumps
	# one, so _ready() runs while the node has been add_child()'d but NOT yet actually entered the
	# tree: get_tree() returns null partway through (board.gd's own _rebuild_all → _maybe_hand_hint
	# hits `await get_tree().process_frame` on that null tree and errors), plus Timer/viewport
	# calls fail the same way — real engine errors, not a false pass. Standing up a genuine frame
	# pump here is more than a minimal, in-scope change to this file, so board-level coverage is
	# left to a grove-suite follow-up; what's proven directly below is the overlay-level mechanism
	# the board-level fix depends on.
	#
	# HandHint.dismiss() carries no flag gate of its own, so a live overlay CAN still be torn down
	# after the flag has already flipped off. If dismiss() ever grew its own
	# "if not Features.on(...): return" guard, board.gd's fix would silently stop working even
	# though it calls dismiss() correctly — this catches that.
	var v_flagflip: Control = HandHint.present(vhost, HandHint.GESTURE_TAP, Rect2(), Rect2(300, 200, 60, 60))
	ok(v_flagflip != null, "flag-flip: a hint can be live while the flag is on")
	Feat.FLAGS["ftue_hand_hint"] = false
	ok(not v_flagflip.dismissed, "flag-flip: flipping the flag off, by itself, does not touch a live overlay")
	v_flagflip.dismiss()
	ok(v_flagflip.dismissed, "flag-flip: dismiss() still tears the overlay down after the flag is off")
	Feat.FLAGS["ftue_hand_hint"] = true

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
