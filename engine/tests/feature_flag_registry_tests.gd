extends "res://engine/tests/test_base.gd"
## Guard: the feature-flag registry (core/features.gd) and its call sites name the SAME ids.
##   godot --headless --path . -s res://engine/tests/feature_flag_registry_tests.gd
##
## Features.on() fails OPEN: an unknown id gets a push_warning and returns TRUE. That default is
## deliberate — a typo can never silently kill a feature — and it is exactly why a rename needs a
## mechanism. Rename or delete a flag and every stale call site keeps returning true for the life
## of the product; the owner then flips the bool OFF and the feature stays ON. There is no crash,
## and push_warning is invisible in a release build, so nothing surfaces the drift.
##
## This is the same code scan strings_tests.gd:27-39 already runs for the OTHER string-key
## registry (every Strings.t("literal") must resolve in the catalog), pointed at flag ids.
##
##  1. THE ALIAS SET. The scan matches by NAME (`Features.on(…)` / `Feat.on(…)`), so a file that
##     preloads features.gd under some third name would be invisible to it — the scan would go
##     quiet on that file and read as clean. Checked against every preload in the tree.
##  2. FORWARD — every flag id named in code resolves in FLAGS. This is the fail-open hole.
##  3. REVERSE — every flag in FLAGS is named by at least one call site. A flag nothing reads is
##     dead weight that still reads as a live switch; features.gd:51-52 already carries commented
##     tombstones for exactly this, so it is a recurring maintenance cost, not a hypothetical.

const FEATURES_PATH := "res://engine/scripts/core/features.gd"
const Features = preload(FEATURES_PATH)

const SCAN_ROOTS := ["res://engine/", "res://games/"]

## Every name features.gd is bound to at a preload site. Section 1 fails if a file binds another.
const ALIASES := ["Features", "Feat"]

## Ids named in CODE that deliberately do not resolve in FLAGS. Keyed "res://path.gd@flag_id"
## (NOT by line: a line-keyed exemption goes stale whenever anything above it shifts, and a guard
## that cries wolf gets switched off). One line of reason each — an entry here is a decision.
const UNKNOWN_ALLOWLIST := {
	"res://engine/tests/feature_flag_registry_tests.gd@not_a_real_feature_flag":
		"this suite's own known-positive fixture — an id that MUST NOT resolve, so the tree scan is proved able to tell an invented flag from a real one end to end (and the allowlist path stays exercised rather than being dead machinery)",
}

## Flags in FLAGS that no call site names by literal. Keyed "flag_id", one line of reason each.
## Empty: every flag is read somewhere today. An entry here means "parked but kept on purpose".
const UNREFERENCED_ALLOWLIST := {}

func _initialize() -> void:
	print("== Feature-flag registry guard ==")
	var flags: Array = Features.FLAGS.keys()
	# Anti-Potemkin: an empty registry would make every comparison below pass vacuously.
	ok(flags.size() >= 20, "the FLAGS registry parses to a real set (%d flags)" % flags.size())

	var files := _gd_files()
	ok(files.size() >= 100, "the scan reaches the tree (%d .gd files under %s)" % [files.size(), ", ".join(SCAN_ROOTS)])

	_check_alias_set(files)
	var refs := _scan_refs(files)
	_check_known_positive(refs)
	_check_forward(refs, flags)
	_check_reverse(refs, flags)
	finish()

# --- 1. the alias set ----------------------------------------------------------------------

## Every `X = preload(".../features.gd")` must bind a name the scan knows. A file binding a new
## alias contributes zero references, which looks identical to a file with no flag calls at all.
func _check_alias_set(files: PackedStringArray) -> void:
	var re := RegEx.create_from_string("([A-Za-z_][A-Za-z0-9_]*)\\s*:?=\\s*(?:pre)?load\\(\"%s\"\\)" % FEATURES_PATH)
	var bound := {}
	var rogue := PackedStringArray()
	for p in files:
		for m in re.search_all(_read(p)):
			var name := m.get_string(1)
			bound[name] = true
			if not ALIASES.has(name):
				rogue.append("%s@%s" % [p, name])
	# KNOWN-POSITIVE: the preload matcher must find the aliases that exist, or the check is moot.
	ok(bound.size() >= 2, "known-positive: the preload matcher binds %d alias name(s) (expected >= 2)" % bound.size())
	if not rogue.is_empty():
		print("  features.gd preloaded under a name the scan does not know: ", ", ".join(rogue))
		print("  add the name to ALIASES here, or rename the binding to one of: ", ", ".join(ALIASES))
	ok(rogue.is_empty(), "every features.gd preload binds a name the scan matches (%d rogue)" % rogue.size())

# --- 2 / 3. the two directions -------------------------------------------------------------

## END-TO-END KNOWN-POSITIVE. A scan that reports nothing is a bug until it has been shown
## finding something, so this file itself carries one real id and one invented id, and the raw
## tree scan must come back with BOTH — proving the scan reaches files, extracts ids, and would
## classify a stale call site as unknown. The invented call also pins the fail-open default that
## is this suite's whole reason to exist.
func _check_known_positive(refs: Array) -> void:
	ok(Features.on("idle_hint"), "known-positive: a real flag reads back through Features.on()")
	ok(Features.on("not_a_real_feature_flag"), "Features.on() still fails OPEN on an unknown id — the drift this suite catches is silent")

	var self_path := "res://engine/tests/feature_flag_registry_tests.gd"
	var mine := {}
	for r in refs:
		if r.path == self_path:
			mine[r.flag] = true
	ok(mine.has("idle_hint"), "known-positive: the tree scan sees this file's REAL flag call (idle_hint)")
	ok(mine.has("not_a_real_feature_flag"), "known-positive: the tree scan sees this file's INVENTED flag call, so an unknown id is detectable")
	ok(not Features.FLAGS.has("not_a_real_feature_flag"), "known-positive: the invented id genuinely does not resolve in FLAGS")
	ok(refs.size() >= 25, "the scan finds flag references across the tree (%d)" % refs.size())

## FORWARD: an id in code that FLAGS does not have is a fail-open call site.
func _check_forward(refs: Array, flags: Array) -> void:
	var offenders := PackedStringArray()
	var allowed := 0
	for r in refs:
		if flags.has(r.flag):
			continue
		var key := "%s@%s" % [r.path, r.flag]
		if UNKNOWN_ALLOWLIST.has(key):
			allowed += 1
			continue
		offenders.append("%s:%d  %s" % [r.path, r.line, String(r.text).strip_edges()])
	if not offenders.is_empty():
		print("  ----------------------------------------------------------------")
		print("  call sites naming a flag that FLAGS does not have: %d" % offenders.size())
		for o in offenders:
			print("    ", o)
		print("  each of these returns TRUE at runtime and warns into a log nobody reads.")
		print("  fix the id, or add \"res://path.gd@flag_id\" to UNKNOWN_ALLOWLIST here with the reason.")
		print("  ----------------------------------------------------------------")
	ok(offenders.is_empty(), "every flag id named in code resolves in FLAGS (%d offender(s), %d allowlisted)" % [offenders.size(), allowed])

	# A stale exemption is a hole that silently re-opens.
	var stale := PackedStringArray()
	for key in UNKNOWN_ALLOWLIST:
		var live := false
		for r in refs:
			if "%s@%s" % [r.path, r.flag] == key:
				live = true
				break
		if not live:
			stale.append(key)
	ok(stale.is_empty(), "every UNKNOWN_ALLOWLIST entry still points at a real call site%s" % \
		("" if stale.is_empty() else " — stale: " + ", ".join(stale)))

## REVERSE: a flag nothing names is dead — it still reads as a live switch an owner can flip.
func _check_reverse(refs: Array, flags: Array) -> void:
	var named := {}
	for r in refs:
		named[r.flag] = true
	var dead := PackedStringArray()
	var allowed := 0
	for f in flags:
		if named.has(f):
			continue
		if UNREFERENCED_ALLOWLIST.has(f):
			allowed += 1
			continue
		dead.append(String(f))
	if not dead.is_empty():
		print("  ----------------------------------------------------------------")
		print("  flags in FLAGS that no call site names: ", ", ".join(dead))
		print("  delete the entry (features.gd:51-52 shows the tombstone-comment form), or add the")
		print("  id to UNREFERENCED_ALLOWLIST here with the reason it is kept unread.")
		print("  ----------------------------------------------------------------")
	ok(dead.is_empty(), "every flag in FLAGS is read by at least one call site (%d dead, %d allowlisted)" % [dead.size(), allowed])

	var stale := PackedStringArray()
	for f in UNREFERENCED_ALLOWLIST:
		if named.has(f) or not flags.has(f):
			stale.append(String(f))
	ok(stale.is_empty(), "every UNREFERENCED_ALLOWLIST entry is still an unread flag%s" % \
		("" if stale.is_empty() else " — stale: " + ", ".join(stale)))

# --- scanning ------------------------------------------------------------------------------

## Every flag-id literal named through a known alias, as {path, line, flag, text}. The three
## reference forms are `on("id")` (the read), `FLAGS["id"]` and `FLAGS.has("id")` (the test-side
## flips) — all three go stale the same way. features.gd itself is skipped: it is the registry,
## and its push_warning template spells the call form in a string.
func _scan_refs(files: PackedStringArray) -> Array:
	var alias := "|".join(ALIASES)
	var re := RegEx.create_from_string(
		"(?<![A-Za-z0-9_.])(?:%s)\\.(?:on\\(\"([a-z0-9_]+)\"\\)|FLAGS\\.has\\(\"([a-z0-9_]+)\"\\)|FLAGS\\[\"([a-z0-9_]+)\"\\])" % alias)
	var out: Array = []
	for p in files:
		if p == FEATURES_PATH:
			continue
		var line_no := 0
		for raw in _read(p).split("\n"):
			line_no += 1
			# Comments only DOCUMENT calls; cutting at the first # keeps a doc line that spells a
			# retired id out of the offender list. A `#` inside a string ahead of a real call on
			# the same line would hide it — the reference-count floor above bounds that.
			var code := raw
			var hash_at := raw.find("#")
			if hash_at >= 0:
				code = raw.substr(0, hash_at)
			for m in re.search_all(code):
				for g in [1, 2, 3]:
					var id := m.get_string(g)
					if id != "":
						out.append({"path": p, "line": line_no, "flag": id, "text": raw})
						break
	return out

func _gd_files() -> PackedStringArray:
	var out := PackedStringArray()
	for root in SCAN_ROOTS:
		out.append_array(_gd_files_deep(root))
	return out

func _gd_files_deep(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + f)
	for sub in d.get_directories():
		if not sub.begins_with("."):
			out.append_array(_gd_files_deep(dir + sub + "/"))
	return out

func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t
