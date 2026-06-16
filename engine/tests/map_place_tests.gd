extends SceneTree
## Headless tests for the authoring placement editor in engine/scripts/scenes/map.gd.
##   godot --headless --path . -s res://engine/tests/map_place_tests.gd

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Layout = preload("res://engine/scripts/core/layout.gd")
const Debug = preload("res://engine/scripts/ui/debug.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _fresh_save() -> void:
	var dir := "user://tu_map_place_tests/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)
	var g := Save.grove()
	var ul := {}
	for sp in G.MAPS[0].spots:
		ul[String(sp.id)] = true
	g["unlocks"] = ul
	g["stars_earned"] = 40
	Save.grove_write()

func _wheel(button: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = Vector2(200, 400)
	return ev

func _initialize() -> void:
	OS.set_environment("GAME", "grove")
	print("== Map placement editor tests ==")
	_fresh_save()
	Layout.reset_all()
	Debug.force = true

	var h = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(h)
	await process_frame
	h._open_map(0)
	await process_frame

	var first_before = h.spot_hits[0]
	var first_z := int(first_before.z)
	var first_k := int(first_before.k)
	var first_center_before: Vector2 = (first_before.node as Control).get_global_rect().get_center()
	h._place_select({"kind": "map", "z": 0})
	var scale0 := Layout.map_scale(0)
	ok(h._place_input(_wheel(MOUSE_BUTTON_WHEEL_UP)), "wheel up is consumed for selected background")
	ok(Layout.map_scale(0) > scale0, "wheel up increases selected background scale")
	ok(h.content.modulate.a >= 0.99, "background resize redraw stays opaque (no pop-in flash)")
	var first_after = h.spot_hits[0]
	var first_center_after: Vector2 = (first_after.node as Control).get_global_rect().get_center()
	ok(first_center_after.distance_to(first_center_before) <= 0.5, "background resize keeps spot screen positions stable")
	var scale1 := Layout.map_scale(0)
	ok(h._place_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN)), "wheel down is consumed for selected background")
	ok(Layout.map_scale(0) < scale1, "wheel down decreases selected background scale")

	var first = h.spot_hits[0]
	h._place_select({"kind": "spot", "z": first_z, "k": first_k, "node": first.node})
	var size0 := Layout.spot_fsize(first_z, first_k)
	ok(h._place_input(_wheel(MOUSE_BUTTON_WHEEL_UP)), "wheel up is consumed for selected spot")
	ok(Layout.spot_fsize(first_z, first_k) > size0, "wheel up increases selected spot size")
	var size1 := Layout.spot_fsize(first_z, first_k)
	ok(h._place_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN)), "wheel down is consumed for selected spot")
	ok(Layout.spot_fsize(first_z, first_k) < size1, "wheel down decreases selected spot size")

	h.queue_free()
	await process_frame
	Debug.force = false
	Layout.reset_all()

	print("== Map placement editor: %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
