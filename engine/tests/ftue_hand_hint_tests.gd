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

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
