extends RefCounted
## Design resolution + desktop window helpers (game-agnostic). The whole UI is authored against the
## project's PORTRAIT viewport (display/window/size in project.godot); this is the ONE place that
## reads it, so nothing else hardcodes 1080/1920.

static var _size := Vector2.ZERO

## The design viewport size (portrait), from project.godot.
static func size() -> Vector2:
	if _size == Vector2.ZERO:
		_size = Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1080)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 1920)))
	return _size

## width / height of the design viewport.
static func aspect() -> float:
	var d := size()
	return d.x / d.y

## DESKTOP boot: size the window to the design aspect, as tall as the monitor's usable height, centered.
## With the project's stretch aspect="expand", a non-portrait window would widen the viewport and the
## cover-fit map art would zoom/crop — so the window is matched to the art instead. No-op on mobile (the
## device IS the window), during quiet capture (TU_QUIET — engine/tools/quiet_godot.sh sets its own
## size), and when there is no real display (headless).
static func fit_desktop_window() -> void:
	if OS.has_feature("mobile") or OS.get_environment("TU_QUIET") == "1":
		return
	var scr := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	if scr.size.y <= 0:
		return
	var deco_y: int = maxi(0, DisplayServer.window_get_size_with_decorations().y - DisplayServer.window_get_size().y)
	var h: float = float(scr.size.y - deco_y)
	var w: float = h * aspect()
	DisplayServer.window_set_size(Vector2i(roundi(w), roundi(h)))
	DisplayServer.window_set_position(Vector2i(int(scr.position.x + (float(scr.size.x) - w) / 2.0), scr.position.y))
