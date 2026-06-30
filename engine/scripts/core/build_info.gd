extends RefCounted
## Runtime app version/build info for player-facing support surfaces.
##
## Use the stamped generated file whenever it exists, including editor/headless
## probes. Fall back to checked-in defaults only when no stamp is available.

const GENERATED_PATH := "res://engine/generated/build_info.gd"
const MARKETING_VERSION := "1.1.8"
const BUILD_NUMBER := "1.1.8"

static func version_text() -> String:
	var info := _info()
	var version := String(info.get("marketing_version", MARKETING_VERSION))
	return _format_text(version)

static func _info() -> Dictionary:
	var out := {"marketing_version": MARKETING_VERSION, "build_number": BUILD_NUMBER}
	var generated := _generated_info()
	if generated.has("marketing_version"):
		out["marketing_version"] = String(generated.marketing_version)
	if generated.has("build_number"):
		out["build_number"] = String(generated.build_number)
	return out

static func _generated_info() -> Dictionary:
	if not FileAccess.file_exists(GENERATED_PATH):
		return {}
	var Generated: GDScript = ResourceLoader.load(GENERATED_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if Generated == null or not Generated.has_method("info"):
		return {}
	var info: Variant = Generated.info()
	return info if info is Dictionary else {}

static func _format_text(version: String) -> String:
	version = version.strip_edges()
	if version == "":
		version = MARKETING_VERSION
	return version
