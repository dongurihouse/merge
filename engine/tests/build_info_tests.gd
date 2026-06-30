extends SceneTree

const BuildInfo = preload("res://engine/scripts/core/build_info.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""

func _write_generated_build_info(version: String, build: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://engine/generated"))
	var f := FileAccess.open(BuildInfo.GENERATED_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("""extends RefCounted

const MARKETING_VERSION := "%s"
const BUILD_NUMBER := "%s"

static func info() -> Dictionary:
	return {"marketing_version": MARKETING_VERSION, "build_number": BUILD_NUMBER}
""" % [version, build])

func _restore_generated_build_info(had_generated: bool, previous_text: String) -> void:
	if had_generated:
		var f := FileAccess.open(BuildInfo.GENERATED_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(previous_text)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BuildInfo.GENERATED_PATH))

func _initialize() -> void:
	print("== BuildInfo guard ==")

	var build_info := BuildInfo.new()
	var has_policy := build_info.has_method("_should_try_generated")
	ok(has_policy and bool(build_info.call("_should_try_generated", false, true, true)),
		"exported builds load ResourceLoader-only generated build info remaps")
	ok(has_policy and not bool(build_info.call("_should_try_generated", false, true, false)),
		"editor/headless runs ignore stale ResourceLoader-only generated paths")

	var had_generated := FileAccess.file_exists(BuildInfo.GENERATED_PATH)
	var previous_generated := _read_text(BuildInfo.GENERATED_PATH) if had_generated else ""
	_write_generated_build_info("9.8.7", "456")
	var stamped_text := BuildInfo.version_text()
	_restore_generated_build_info(had_generated, previous_generated)
	ok(stamped_text == "9.8.7", "BuildInfo shows the stamped marketing version")
	ok(not stamped_text.contains("(build"), "BuildInfo omits the build suffix from player-facing text")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
