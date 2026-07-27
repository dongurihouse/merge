extends "res://engine/tests/test_base.gd"
## strings — the screen-text catalog (core/strings.gd + games/<active>/strings.json).
## The load-bearing check is the CODE SCAN: every Strings.t("literal path") used anywhere in the engine/
## grove scripts MUST resolve in the catalog (a missing/typo'd path returns itself → caught here). This is
## the safety net for the tr() → Strings.t() migration.

const Strings = preload("res://engine/scripts/core/strings.gd")

func _initialize() -> void:
	print("== strings ==")
	Strings._reset()
	# missing path → the path itself (visible on screen, never a crash)
	ok(Strings.t("definitely.not.a.real.key") == "definitely.not.a.real.key", "a missing path returns itself (visible, no crash)")
	# the catalog file exists and parses to a non-empty object
	ok(not Strings._data_for_test().is_empty(), "the strings.json catalog loads as a non-empty object")

	# CODE SCAN — every Strings.t("…") literal in the codebase resolves in the catalog.
	var miss := _scan_missing()
	ok(miss.is_empty(), "every Strings.t(\"…\") path in the code resolves%s" % ("" if miss.is_empty() else " — MISSING (%d): %s" % [miss.size(), str(miss.slice(0, 20))]))
	# and there are no leftover LITERAL tr("…") in migrated UI files (the catalog is complete).
	var left := _scan_leftover_tr()
	ok(left.is_empty(), "no literal tr(\"…\")/translate(\"…\") remain in migrated files%s" % ("" if left.is_empty() else " — %d left: %s" % [left.size(), str(left.slice(0, 12))]))

	finish()

# every Strings.t("path") literal across the scripts whose path does NOT resolve
func _scan_missing() -> Array:
	var miss: Array = []
	var re := RegEx.new()
	re.compile('Strings\\.t\\("([^"]+)"\\)')
	for f in gd_files("res://engine/scripts") + gd_files("res://games/grove"):
		if f.ends_with("strings.gd"):
			continue
		var txt := read_text(f)
		for m in re.search_all(txt):
			var path := m.get_string(1)
			if Strings.t(path) == path:
				miss.append(path)
	return miss

# any literal tr("…") / TranslationServer.translate("…") still in the migrated UI files (excludes the
# scenes/tools that are intentionally left, and the dynamic tr(var) calls which take a non-literal arg).
func _scan_leftover_tr() -> Array:
	var left: Array = []
	var re := RegEx.new()
	re.compile('(?:\\btr|TranslationServer\\.translate)\\("([^"]+)"')
	for f in gd_files("res://engine/scripts"):
		if "/tools/" in f or f.ends_with("strings.gd"):   # strings.gd's docs mention tr("…") — not real calls
			continue
		var txt := read_text(f)
		for m in re.search_all(txt):
			left.append(f.get_file() + ": " + m.get_string(1))
	return left

# The walk and the slurp are test_base.gd's gd_files(dir, deep) / read_text(path) — one
# coverage function for every guard. This suite's older list_dir_begin walk carried an explicit
# dotted-directory skip; the shared one keeps it (and states why). Measured before the swap: the
# two yield the IDENTICAL 136 paths over these two roots, so the scan lost nothing.
