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

# --- the guards' shared coverage function --------------------------------------------------
#
# Every .gd file under `dir`, as res:// paths. `deep` (the default) walks subdirectories, so a
# NEW engine/scripts/<layer>/ is covered the day it appears instead of silently escaping the
# scan; `deep := false` stays in the one directory. `dir` may be spelled with or without a
# trailing slash.
#
# This lives here because it is the COVERAGE function of const_ssot_tests, palette_ssot_tests,
# layering_tests, feature_flag_registry_tests and strings_tests. A walker that quietly misses a
# directory makes every one of those guards report green over unscanned code — the same failure
# suite_registry_tests.gd exists to catch one level up. One copy, so "every .gd file" means one
# thing.
#
# DOTTED ENTRIES ARE SKIPPED, deliberately. `.godot/` (the import cache), `.claude/`,
# `.scratch/` and `.superpowers/` hold caches and agent scratch — copies of source that nothing
# ships and no guard should judge. DirAccess already hides them (`include_hidden` defaults to
# false), so the skips below change no path today (measured: identical sets for all five guards,
# every root); they are written out so the coverage rule is STATED here rather than inherited
# from an engine default that a Godot upgrade could flip under us. Turning them off is a
# coverage decision, not a cleanup.
func gd_files(dir: String, deep := true) -> PackedStringArray:
	var out := PackedStringArray()
	var root: String = dir if dir.ends_with("/") else dir + "/"
	var d := DirAccess.open(root)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd") and not f.begins_with("."):
			out.append(root + f)
	if deep:
		for sub in d.get_directories():
			if not sub.begins_with("."):
				out.append_array(gd_files(root + sub + "/", true))
	return out

# The whole text of `path`, or "" if it cannot be opened. The guards' file slurp: an unreadable
# path reads as empty rather than crashing the sweep, so one bad path costs one scan, not a
# suite. (Six suites each carried this.)
func read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t

# The footer the runner parses, then the exit code. Every suite ends on this.
func finish() -> void:
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
