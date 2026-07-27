extends "res://engine/tests/test_base.gd"
## Guard: every suite on disk is actually WIRED INTO the Makefile, and the docs name the same set.
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
##
##  1. GODOT SUITES (*_tests.gd) vs ENGINE_TESTS / TOOLS_TESTS / GROVE_TESTS.
##  2. PYTHON SUITES (*_tests.py, test_*.py) vs PY_TESTS, and SHELL SUITES vs SH_TESTS. Section 1
##     matched only *.gd in three named directories, so a python suite was invisible twice over —
##     wrong extension AND, for games/grove/tools/tests/, a directory nobody scanned. That is
##     exactly how two python suites sat unrun until they were found by hand.
##  3. THE DOCS (README.md, CLAUDE.md) vs GROVE_TESTS. CLAUDE.md says "keep this line in step
##     with it", which is a promise, not a mechanism — const_ssot_tests.gd:7-8 makes the same
##     point. They agree today; this is what keeps them agreeing. Order-insensitive: the two
##     docs list the suites in different orders and there is no reason to force a prose rewrite.

const TEST_DIRS := ["res://engine/tests/", "res://games/grove/tests/", "res://games/tools/tests/",
	"res://games/grove/tools/tests/"]
## Shared bases, not suites — they define helpers and are `extends`-ed, never run alone.
const NOT_SUITES := ["test_base.gd", "grove_test_base.gd", "smoke.gd"]

## Roots the python/shell scan walks. Tree-wide on purpose: the whole failure mode of section 1
## was a suite living somewhere the scan did not look.
const SCRIPT_ROOTS := ["res://engine/", "res://games/", "res://tools/", "res://build/"]

## Python/shell files that LOOK like a suite but are not wired, deliberately. Keyed by res:// path
## (NOT by line, and not by a directory prefix that could swallow a future real suite). One line
## of reason each — an entry here is a decision, not a backlog item.
const NOT_SCRIPT_SUITES := {
	"res://games/grove/assets/_archive/fairy_hollow_elements_v4/09_reconstruction/test_compose_reconstruction.py":
		"archived asset-reconstruction scratch under assets/_archive/, kept as a record of how that drop was rebuilt — it is not a guard of shipping behaviour and its inputs are archived raws, so wiring it into the sweep would only couple `make test` to an inert folder",
}

## The docs that must name the grove suite set, and the token shape they name them by.
const DOC_PATHS := ["res://README.md", "res://CLAUDE.md"]

func _initialize() -> void:
	print("== Suite registry guard ==")
	_check_godot_suites()
	_check_script_suites()
	_check_docs()
	finish()

# --- 1. godot suites -----------------------------------------------------------------------

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
	var out: Array = []
	for name in ["ENGINE_TESTS", "TOOLS_TESTS", "GROVE_TESTS"]:
		for t in _makefile_list(name):
			if t.ends_with("_tests") and t.contains("/"):
				out.append(t)
	out.sort()
	return out

func _check_godot_suites() -> void:
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

# --- 2. python + shell suites --------------------------------------------------------------

func _check_script_suites() -> void:
	_check_non_godot("PY_TESTS", ".py", "make test-config")
	_check_non_godot("SH_TESTS", ".sh", "make test-config")

## One extension's worth of the same comparison. `wired` comes from the Makefile variable;
## `on_disk` is every `*_tests.<ext>` / `test_*.<ext>` under SCRIPT_ROOTS.
func _check_non_godot(var_name: String, ext: String, target: String) -> void:
	var on_disk := _script_suites(ext)
	var wired: Array = []
	for t in _makefile_list(var_name):
		if t.ends_with(ext):
			wired.append(t)
	on_disk.sort()
	wired.sort()

	# KNOWN-POSITIVE for both halves: a scanner that reports nothing is a bug until it has been
	# shown finding something, and an unparsed Makefile variable would make the diff vacuous.
	ok(on_disk.size() >= 2, "the %s scan finds suite files on disk (%d)" % [ext, on_disk.size()])
	ok(wired.size() >= 2, "parsed the Makefile's %s list (%d)" % [var_name, wired.size()])

	var missing: Array = []
	var allowed := 0
	for s in on_disk:
		if wired.has(s):
			continue
		if NOT_SCRIPT_SUITES.has("res://" + s):
			allowed += 1
			continue
		missing.append(s)
	if not missing.is_empty():
		print("  ----------------------------------------------------------------")
		print("  %s suites on disk that %s never runs:" % [ext, target])
		for m in missing:
			print("    ", m)
		print("  add each to %s in the Makefile, or to NOT_SCRIPT_SUITES here with the reason." % var_name)
		print("  a suite that only hangs off its own target is absent from the sweep everyone runs.")
		print("  ----------------------------------------------------------------")
	ok(missing.is_empty(), "every %s suite on disk is wired into %s (%d unwired, %d allowlisted)" % \
		[ext, var_name, missing.size(), allowed])

	var ghosts: Array = []
	for s in wired:
		if not FileAccess.file_exists("res://" + s):
			ghosts.append(s)
	if not ghosts.is_empty():
		print("  %s names files that do not exist: " % var_name, ", ".join(ghosts))
	ok(ghosts.is_empty(), "every file %s names exists on disk (%d missing)" % [var_name, ghosts.size()])

	# A stale exemption is a hole that silently re-opens.
	var stale: Array = []
	for key in NOT_SCRIPT_SUITES:
		if String(key).ends_with(ext) and not FileAccess.file_exists(key):
			stale.append(key)
	ok(stale.is_empty(), "every NOT_SCRIPT_SUITES %s entry still exists%s" % \
		[ext, "" if stale.is_empty() else " — stale: " + ", ".join(stale)])

## Every `*_tests.<ext>` / `test_*.<ext>` under SCRIPT_ROOTS, as repo-relative paths.
func _script_suites(ext: String) -> Array:
	var out: Array = []
	for root in SCRIPT_ROOTS:
		for raw in _files_deep(root, ext):
			var p := String(raw)
			var f := p.get_file()
			if f.begins_with("test_") or f.trim_suffix(ext).ends_with("_tests"):
				out.append(p.trim_prefix("res://"))
	return out

func _files_deep(dir: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir + f)
	for sub in d.get_directories():
		if not sub.begins_with("."):
			out.append_array(_files_deep(dir + sub + "/", ext))
	return out

# --- 3. the docs ---------------------------------------------------------------------------

## README.md and CLAUDE.md both spell out the grove suite names for a reader deciding which
## slice to run. A name that no longer exists sends them at a suite that cannot run; a suite
## missing from the list is one they will not think to run. Order-insensitive by design.
func _check_docs() -> void:
	var expected := {}
	for t in _makefile_list("GROVE_TESTS"):
		if t.ends_with("_tests") and t.contains("/"):
			expected[t.get_file()] = true
	ok(expected.size() >= 5, "parsed the grove suite names from GROVE_TESTS (%d)" % expected.size())

	var re := RegEx.create_from_string("\\bgrove_[a-z0-9_]*_tests\\b")
	for doc in DOC_PATHS:
		var text := _read(doc)
		ok(text != "", "%s is readable" % doc)
		var named := {}
		for m in re.search_all(text):
			named[m.get_string(0)] = true
		var absent: Array = []
		for s in expected:
			if not named.has(s):
				absent.append(String(s))
		var ghosts: Array = []
		for s in named:
			if not expected.has(s):
				ghosts.append(String(s))
		if not absent.is_empty() or not ghosts.is_empty():
			print("  ----------------------------------------------------------------")
			print("  %s disagrees with GROVE_TESTS in the Makefile:" % doc)
			if not absent.is_empty():
				print("    never mentioned: ", ", ".join(absent))
			if not ghosts.is_empty():
				print("    mentioned but gone: ", ", ".join(ghosts))
			print("  edit the doc's list — order does not matter, membership does.")
			print("  ----------------------------------------------------------------")
		ok(absent.is_empty() and ghosts.is_empty(), \
			"%s names exactly the GROVE_TESTS set (%d missing, %d stale)" % [doc, absent.size(), ghosts.size()])

# --- Makefile parsing ----------------------------------------------------------------------

## The whitespace-separated values of one Makefile variable, following `\` line continuations
## (PY_TESTS spans three lines). `<NAME>_DISABLED` is a different variable and never matches,
## because the assignment operator has to follow the name.
func _makefile_list(var_name: String) -> Array:
	var out: Array = []
	var lines := _read("res://Makefile").split("\n")
	var i := 0
	while i < lines.size():
		var line := String(lines[i])
		var head := line.strip_edges()
		if not (head.begins_with(var_name) and RegEx.create_from_string("^%s\\s*[:+?]?=" % var_name).search(head)):
			i += 1
			continue
		var joined := head.split("=", true, 1)[1]
		while joined.strip_edges().ends_with("\\") and i + 1 < lines.size():
			joined = joined.strip_edges().trim_suffix("\\") + " " + String(lines[i + 1])
			i += 1
		for tok in joined.replace("\t", " ").split(" "):
			var t := tok.strip_edges()
			if t != "":
				out.append(t)
		break
	return out

func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t
