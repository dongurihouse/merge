extends SceneTree
## strings — the screen-text catalog (core/strings.gd + games/<active>/strings.json).
## The load-bearing check is the CODE SCAN: every Strings.t("literal path") used anywhere in the engine/
## grove scripts MUST resolve in the catalog (a missing/typo'd path returns itself → caught here). This is
## the safety net for the tr() → Strings.t() migration.

const Strings = preload("res://engine/scripts/core/strings.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

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

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)

# every Strings.t("path") literal across the scripts whose path does NOT resolve
func _scan_missing() -> Array:
	var miss: Array = []
	var re := RegEx.new()
	re.compile('Strings\\.t\\("([^"]+)"\\)')
	for f in _gd_files("res://engine/scripts") + _gd_files("res://games/grove"):
		if f.ends_with("strings.gd"):
			continue
		var txt := FileAccess.get_file_as_string(f)
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
	for f in _gd_files("res://engine/scripts"):
		if "/tools/" in f or f.ends_with("strings.gd"):   # strings.gd's docs mention tr("…") — not real calls
			continue
		var txt := FileAccess.get_file_as_string(f)
		for m in re.search_all(txt):
			left.append(f.get_file() + ": " + m.get_string(1))
	return left

func _gd_files(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var p := dir + "/" + name
		if d.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_gd_files(p))
		elif name.ends_with(".gd"):
			out.append(p)
		name = d.get_next()
	d.list_dir_end()
	return out
