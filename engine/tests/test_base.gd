extends SceneTree
## Shared harness for every headless suite — the assert counter, the PASS/FAIL lines,
## the isolated save dir, and the footer the runner parses.
## NOT a runnable suite (no _tests suffix); suites do:
##   extends "res://engine/tests/test_base.gd"
##
## THE PRINTED FORMAT IS A CONTRACT. engine/tools/run_suites.py does not trust exit
## codes — it counts lines starting with "  PASS", takes the failed count from the
## "== N passed, M failed ==" footer, and treats a missing footer as a CRASH. Change
## those strings here and every suite reports wrong at once, so don't.

const _TSave = preload("res://engine/scripts/core/save.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# The suite's OWN user:// save-dir prefix. Suites run in parallel (JOBS=4) against one
# shared user:// tree, so two suites sharing a prefix would clobber each other's saves
# intermittently — the worst kind of flake. Every suite that calls fresh() overrides
# this with the prefix it has always used.
func save_prefix() -> String:
	return "tu_"

# Point Save at an empty per-test directory under this suite's prefix. `prefix`
# overrides save_prefix() for a one-off directory; normally leave it out.
func fresh(name: String, prefix: String = "") -> void:
	var dir := "user://" + (prefix if prefix != "" else save_prefix()) + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	_TSave.configure_for_test(dir)

# The footer the runner parses, then the exit code. Every suite ends on this.
func finish() -> void:
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
