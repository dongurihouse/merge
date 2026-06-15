extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): the REAL wayside buy flow. Forces the
## design-size window (deterministic), restores zone 0, pans way_0_1 on-screen, and
## drives a REAL press+release at TWO points — the sprite center and the PRICE-PIN
## center — asserting each buys. Exists because handler-level tests pass while real
## input is dead (input-swallow bug class). Mirrors click_spot.gd.
##   engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/click_wayside.gd

const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	DisplayServer.window_set_size(Vector2i(1080, 1920))   # deterministic = design size

	var rc := 0
	rc += await _try("sprite-center", false)
	rc += await _try("price-pin",     true)
	print("OVERALL %s" % ("PASS" if rc == 0 else "FAIL"))
	quit(rc)

# tap_pin=false → click the holder/sprite center; true → click the price-pin center.
func _try(label: String, tap_pin: bool) -> int:
	var dir := "/tmp/tu_clickway_%s/" % label
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)
	Save.add_coins(999)
	var g := Save.grove()
	var ul := {}
	for s in G.ZONES[0].spots:
		ul[String(s.id)] = true
	g["unlocks"] = ul
	Save.grove_write()

	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.4).timeout

	var node: Control = null
	for hit in scn.wayside_hits:
		if String(hit.w.id) == "way_0_1":
			node = hit.node
			break
	if node == null:
		print("[%s] FAIL: way_0_1 not found" % label)
		scn.queue_free()
		return 1

	# pan the holder to viewport center
	var view: Vector2 = scn.get_viewport().get_visible_rect().size
	scn.vista.position = view * 0.5 - (Vector2(node.position) + node.size * 0.5)
	await create_timer(0.2).timeout

	# pick the click point: sprite center, or the price-pin center
	var pin: Control = null
	for ch in node.get_children():
		if ch is PanelContainer:
			pin = ch
	var at: Vector2 = node.get_global_rect().get_center()
	var pin_info := "(no pin)"
	if tap_pin and pin != null:
		at = pin.get_global_rect().get_center()
		pin_info = "pin_rect=%s" % str(pin.get_global_rect())

	# capture the report BEFORE the click — a successful buy rebuilds the vista and
	# frees `node`/`pin`, so we must not dereference them afterwards
	var report: String = "view=%s holder_rect=%s %s  click@%s" % \
		[str(view), str(node.get_global_rect()), pin_info, str(at)]
	var owned_before: bool = scn.wayside_owned("way_0_1")
	_click(at)
	await create_timer(0.35).timeout
	var ok: bool = scn.wayside_owned("way_0_1") and not owned_before
	print("[%s] %s  %s  bought=%s" % [label, ("PASS" if ok else "FAIL"), report, ok])
	scn.queue_free()
	await process_frame
	return 0 if ok else 1

func _click(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	Input.parse_input_event(down)
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
