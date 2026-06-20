extends SceneTree
## Headless tests for Kit.load_config caching — the parsed config is read+JSON-parsed ONCE per path,
## not re-parsed for every widget a scene build creates. Cleared on demand (the workbench's Save hook).
##   godot --headless -s res://engine/tests/kit_config_cache_tests.gd

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _write(path: String, body: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(body)
	f.close()

func _initialize() -> void:
	print("== Kit config-cache tests ==")
	var path := "user://tu_kit_cfg_test.json"
	Kit.clear_config_cache()

	# 1. first load parses the file.
	_write(path, '{"button": {"font": 22}}')
	var a := Kit.load_config(path)
	ok(a is Dictionary and int((a.get("button", {}) as Dictionary).get("font", 0)) == 22, "first load parses the file")

	# 2. the file changes on disk, but a cached load returns the ORIGINAL (proves it isn't re-parsing).
	_write(path, '{"button": {"font": 40}}')
	var b := Kit.load_config(path)
	ok(int((b.get("button", {}) as Dictionary).get("font", 0)) == 22, "second load is cached (no re-parse)")

	# 3. clearing the cache re-reads the new contents.
	Kit.clear_config_cache(path)
	var c := Kit.load_config(path)
	ok(int((c.get("button", {}) as Dictionary).get("font", 0)) == 40, "clear_config_cache() forces a re-read")

	# 4. a missing path returns {} and is harmless to cache/clear.
	Kit.clear_config_cache()
	ok(Kit.load_config("res://nope/missing.json") == {}, "missing path returns empty dict")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
