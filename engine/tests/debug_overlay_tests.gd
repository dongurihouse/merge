extends SceneTree
## Headless tests for the owner debug overlay drag handle.
##   godot --headless --path . -s res://engine/tests/debug_overlay_tests.gd

const Debug = preload("res://engine/scripts/ui/debug.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").Hud

var _pass := 0
var _fail := 0


func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)


func _mouse_button(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	return ev


func _mouse_motion(pos: Vector2, rel: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.position = pos
	ev.relative = rel
	return ev


func _initialize() -> void:
	print("== Debug overlay drag tests ==")
	Debug.reset_drag_for_test()

	var host := Control.new()
	host.size = Vector2(720, 960)
	root.add_child(host)
	await process_frame

	var expected_default := Vector2(12, Tune.EDGE_MARGIN + Look.safe_top(host) + Debug.LV_BADGE_BOX + 8.0)
	ok(Debug._default_panel_position(host).is_equal_approx(expected_default),
		"debug overlay default position stays below the level badge")

	var clamped := Debug._clamp_panel_position(Vector2(999, 999), Vector2(184, 44), Vector2(500, 400))
	ok(clamped.is_equal_approx(Vector2(316, 356)), "debug overlay drag clamps inside the viewport")

	var panel := VBoxContainer.new()
	panel.position = Vector2(40, 80)
	panel.size = Vector2(184, 44)
	var menu := VBoxContainer.new()
	menu.visible = false
	panel.add_child(menu)
	host.add_child(panel)
	await process_frame

	Debug._on_toggle_gui_input(_mouse_button(Vector2(8, 8), true), host, panel)
	Debug._on_toggle_gui_input(_mouse_motion(Vector2(48, 34), Vector2(40, 26)), host, panel)
	Debug._on_toggle_gui_input(_mouse_button(Vector2(48, 34), false), host, panel)
	ok(panel.position.distance_to(Vector2(80, 106)) < 1.0, "dragging the DEBUG toggle moves the overlay column")
	ok(Debug.drag_position_for_test().distance_to(panel.position) < 1.0, "debug overlay stores dragged position for reloads")
	Debug._on_toggle_pressed(menu)
	ok(not menu.visible, "drag release suppresses the click toggle")

	Debug._on_toggle_gui_input(_mouse_button(Vector2(8, 8), true), host, panel)
	Debug._on_toggle_gui_input(_mouse_button(Vector2(8, 8), false), host, panel)
	Debug._on_toggle_pressed(menu)
	ok(menu.visible, "normal click still toggles the debug menu")

	panel.queue_free()
	host.queue_free()
	await process_frame

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
