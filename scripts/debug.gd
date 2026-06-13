extends RefCounted
## PRODUCTION vs DEBUG mode (owner 2026-06-12).
##
## PRODUCTION is the default and is always CLEAN — no authoring chrome, no debug
## affordances, nothing a player could stumble into. DEBUG unlocks the owner's
## authoring tools; today that means the drag-to-place editor (Layout) on the map
## and inside rooms — adjust placements, then SAVE them. New debug adjustments
## hang off Debug.on() the same way.
##
## Enter debug with NO source edit:
##     godot --path . -- debug          (everything after -- is a user arg)
##   or set an environment variable:
##     TU_DEBUG=1 godot --path .
##
## Debug is NEVER on in headless logic suites or quiet capture runs (those would
## pollute tests/screenshots). Capture tools that WANT the debug chrome set
## Debug.force = true explicitly (e.g. tools/home_shot.gd `place=1`).

static var force := false

static func on() -> bool:
	if force:
		return true
	if DisplayServer.get_name() == "headless":
		return false                     # logic suites
	if OS.get_environment("TU_QUIET") == "1":
		return false                     # quiet capture runs
	if OS.get_environment("TU_DEBUG") == "1":
		return true
	return "debug" in OS.get_cmdline_user_args()
