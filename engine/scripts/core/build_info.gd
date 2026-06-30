extends RefCounted
## Runtime app version/build info for player-facing support surfaces.
##
## Dev/editor runs use the checked-in export preset defaults. iOS exports stamp
## engine/generated/build_info.gd before Godot packages resources, so TestFlight
## builds can show the exact marketing version + build number.

const GENERATED_PATH := "res://engine/generated/build_info.gd"
const MARKETING_VERSION := "1.0"
const BUILD_NUMBER := "1"

static func version_text() -> String:
	var info := _info()
	var version := String(info.get("marketing_version", MARKETING_VERSION))
	var build := String(info.get("build_number", BUILD_NUMBER))
	return _format_text(version, build)

static func _info() -> Dictionary:
	var out := {"marketing_version": MARKETING_VERSION, "build_number": BUILD_NUMBER}
	if not OS.has_feature("ios"):
		return out
	var generated := _generated_info()
	if generated.has("marketing_version"):
		out["marketing_version"] = String(generated.marketing_version)
	if generated.has("build_number"):
		out["build_number"] = String(generated.build_number)
	return out

static func _generated_info() -> Dictionary:
	if not ResourceLoader.exists(GENERATED_PATH):
		return {}
	var Generated: GDScript = load(GENERATED_PATH)
	if Generated == null or not Generated.has_method("info"):
		return {}
	var info: Variant = Generated.info()
	return info if info is Dictionary else {}

static func _format_text(version: String, build: String) -> String:
	version = version.strip_edges()
	build = build.strip_edges()
	if version == "":
		version = MARKETING_VERSION
	if build == "":
		build = BUILD_NUMBER
	return "%s (build %s)" % [version, build]
