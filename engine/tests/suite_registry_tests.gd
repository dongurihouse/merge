extends "res://engine/tests/test_base.gd"
## Guard: every *_tests.gd on disk is actually WIRED INTO the Makefile.
##   godot --headless --path . -s res://engine/tests/suite_registry_tests.gd
##
## The runner only runs what the Makefile's TESTS variable names. So a new suite file is not
## "not yet passing" — it simply never executes, and its absence looks exactly like success:
## the sweep stays green, the count goes up by zero, and nobody notices the coverage was
## never there. Same in reverse: a name left in the Makefile after its file is renamed or
## deleted makes the runner fail on a missing path, or (worse) quietly skip it.
##
## This is the same hand-synced-list problem that had README.md advertising five grove suites
## that no longer existed. Documentation drift is cosmetic; THIS drift is missing coverage.

const TEST_DIRS := ["res://engine/tests/", "res://games/grove/tests/", "res://games/tools/tests/"]
## Shared bases, not suites — they define helpers and are `extends`-ed, never run alone.
const NOT_SUITES := ["test_base.gd", "grove_test_base.gd", "smoke.gd"]

func _suite_files() -> Array:
	var out: Array = []
	for d in TEST_DIRS:
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".gd") and not NOT_SUITES.has(f):
				out.append(d.trim_prefix("res://") + f.trim_suffix(".gd"))
	out.sort()
	return out

## The suite paths named by the Makefile's TESTS chain (ENGINE_TESTS + TOOLS_TESTS + GROVE_TESTS).
func _makefile_suites() -> Array:
	var f := FileAccess.open("res://Makefile", FileAccess.READ)
	if f == null:
		return []
	var out: Array = []
	for line in f.get_as_text().split("\n"):
		if not (line.begins_with("ENGINE_TESTS") or line.begins_with("GROVE_TESTS") \
			or line.begins_with("TOOLS_TESTS")):
			continue
		if line.begins_with("ENGINE_TESTS_DISABLED") or line.begins_with("GROVE_TESTS_DISABLED"):
			continue
		for tok in line.split(" "):
			var t := tok.strip_edges()
			if t.ends_with("_tests") and t.contains("/"):
				out.append(t)
	f.close()
	out.sort()
	return out

func _initialize() -> void:
	var on_disk := _suite_files()
	var wired := _makefile_suites()

	# Anti-Potemkin: if either side comes back empty the parser broke, and every
	# comparison below would pass vacuously while reporting a clean tree.
	ok(on_disk.size() >= 20, "found the suite files on disk (%d)" % on_disk.size())
	ok(wired.size() >= 20, "parsed the Makefile's TESTS lists (%d)" % wired.size())

	var missing: Array = []
	for s in on_disk:
		if not wired.has(s):
			missing.append(s)
	if not missing.is_empty():
		print("  ----------------------------------------------------------------")
		print("  suites on disk that the Makefile never runs:")
		for m in missing:
			print("    ", m)
		print("  add each to ENGINE_TESTS / GROVE_TESTS / TOOLS_TESTS in the Makefile,")
		print("  or to NOT_SUITES here if it is a shared base rather than a suite.")
		print("  ----------------------------------------------------------------")
	ok(missing.is_empty(), "every *_tests.gd on disk is wired into the Makefile (%d unwired)" % missing.size())

	var ghosts: Array = []
	for s in wired:
		if not on_disk.has(s):
			ghosts.append(s)
	if not ghosts.is_empty():
		print("  Makefile names suites with no file: ", ", ".join(ghosts))
	ok(ghosts.is_empty(), "every suite the Makefile names exists on disk (%d missing)" % ghosts.size())

	finish()
