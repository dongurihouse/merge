extends SceneTree
## Headless tests for the FTUE hand hints (spec: docs/superpowers/specs/2026-07-23-ftue-hand-hint-design.md).
##   godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd

const Save = preload("res://engine/scripts/core/save.gd")
const Feat = preload("res://engine/scripts/core/features.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

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

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
