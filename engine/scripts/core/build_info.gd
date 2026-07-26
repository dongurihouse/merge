extends RefCounted
## Runtime app version/build info for player-facing support surfaces.
##
## Use the stamped generated file whenever it exists, including editor/headless
## probes. When no stamp is available, READ export_presets.cfg — the same file
## tools/stamp_build_info.sh reads and the one that actually ships the version to the
## App Store. The version used to be re-typed here as a const, which went stale the first
## time the preset was bumped and rendered a WRONG version in the
## player-facing Settings dialog on every unstamped build (editor, headless, any export
## where the stamp script did not run). One owner, no restatement.
##
## `dev` is the honest last resort: the presets file is an editor artifact, so an exported
## build that somehow reached the fallback path has nothing truthful to report.

const GENERATED_PATH := "res://engine/generated/build_info.gd"
const PRESETS_PATH := "res://export_presets.cfg"
const MARKETING_KEY := "application/short_version"
const BUILD_KEY := "application/version"
const UNSTAMPED := "dev"

## Parsed presets, cached — version_text() is called per Settings build and by the update check.
static var _presets: Dictionary = {}

static func version_text() -> String:
	var info := _info()
	var version := String(info.get("marketing_version", UNSTAMPED))
	return _format_text(version)

static func _info() -> Dictionary:
	var out := {"marketing_version": preset_value(MARKETING_KEY), "build_number": preset_value(BUILD_KEY)}
	var generated := _generated_info()
	if generated.has("marketing_version"):
		out["marketing_version"] = String(generated.marketing_version)
	if generated.has("build_number"):
		out["build_number"] = String(generated.build_number)
	return out

static func _generated_info() -> Dictionary:
	var file_exists := FileAccess.file_exists(GENERATED_PATH)
	var resource_exists := ResourceLoader.exists(GENERATED_PATH)
	if not _should_try_generated(file_exists, resource_exists, OS.has_feature("template")):
		return {}
	var Generated: GDScript = ResourceLoader.load(GENERATED_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if Generated == null or not Generated.has_method("info"):
		return {}
	var info: Variant = Generated.info()
	return info if info is Dictionary else {}

static func _should_try_generated(file_exists: bool, resource_exists: bool, export_template: bool) -> bool:
	return file_exists or (resource_exists and export_template)

## A quoted string value from export_presets.cfg (`key="value"`), or "" when the file or the
## key is absent. Mirrors tools/stamp_build_info.sh's preset_value(): first match wins.
static func preset_value(key: String) -> String:
	if _presets.is_empty():
		_presets = _parse_presets()
	return String(_presets.get(key, ""))

static func _parse_presets() -> Dictionary:
	var out := {"_read": true}                 # non-empty even on failure, so the parse runs once
	var f := FileAccess.open(PRESETS_PATH, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		var eq := line.find("=")
		if eq <= 0:
			continue
		var key := line.substr(0, eq)
		if out.has(key):
			continue                           # first match wins (the presets file repeats keys per preset)
		out[key] = line.substr(eq + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
	f.close()
	return out

static func _format_text(version: String) -> String:
	version = version.strip_edges()
	if version == "":
		version = UNSTAMPED
	return version
