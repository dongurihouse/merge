extends "res://games/grove/tests/grove_test_base.gd"
## grove · placement TOOL (tools/ui_placement.gd) — proves the game-side hooks the drag-to-place
## tool drives: the board reads + applies saved fence/board vertical nudges (default 0 = unchanged),
## the home unlock badges carry the spot-id meta at their farm_home.json positions, and the
## farm_home.json writer round-trips (other fields + key order preserved).

const FARM_HOME := "res://games/grove/assets/map/farm/farm_home.json"
const Overlay = preload("res://games/grove/tools/placement_overlay.gd")

func _initialize() -> void:
	begin("grove · placement tool")
	await _test_board_offsets()
	await _test_home_badges()
	await _test_overlay_drag()
	_test_farm_home_roundtrip()
	finish()

# REGRESSION: the overlay must fill its parent so it sits in the input stack — a zero-size overlay
# gets NO presses (they fall through to content/board_area) and the drag silently does nothing.
# Then a simulated press→motion→release through _gui_input must actually move the target.
func _test_overlay_drag() -> void:
	# board: drag the quest fence down → a positive saved nudge + the band shifts.
	fresh("place_drag_board")
	var ss = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(ss)
	if ss.board == null:
		ss._ready()
	await create_timer(0.05).timeout
	var ovb: Control = Overlay.new()
	ovb.scene = ss; ovb.mode = "board"
	ss.add_child(ovb)
	ovb.setup()
	await create_timer(0.05).timeout
	ok(ovb.size.x > 0.0 and ovb.size.y > 0.0, "the overlay fills its parent (non-zero → it receives presses)")
	var fence_y0: float = ss.giver_bar.position.y
	var fc: Vector2 = ss.giver_bar.get_global_rect().get_center()
	_drag(ovb, fc, fc + Vector2(0, 100))
	await create_timer(0.05).timeout
	ok(ss._place_fence_dy > 0.0, "dragging the fence down records a positive saved nudge")
	ok(ss.giver_bar.position.y > fence_y0 + 1.0, "the quest fence actually shifts down on drag")
	ss.queue_free()

	# home: drag a badge sideways → the button moves with the cursor.
	fresh("place_drag_home")
	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	if hx.content == null:
		hx._ready()
	await create_timer(0.05).timeout
	hx._open_map(G.hub_map())
	await create_timer(0.1).timeout
	var ovh: Control = Overlay.new()
	ovh.scene = hx; ovh.mode = "home"
	hx.add_child(ovh)
	ovh.setup()
	await create_timer(0.05).timeout
	ok(ovh._targets.size() >= 1, "the overlay collected the home unlock badges")
	var badge: Control = ovh._targets[0].node
	var c0: Vector2 = badge.get_global_rect().get_center()
	_drag(ovh, c0, c0 + Vector2(120, 0))
	await create_timer(0.05).timeout
	var c1: Vector2 = badge.get_global_rect().get_center()
	ok(absf(c1.x - (c0.x + 120.0)) < 6.0, "dragging a badge moves it with the cursor (~+120px)")
	hx.queue_free()

func _drag(ov: Control, from: Vector2, to: Vector2) -> void:
	ov._gui_input(_press(from, true))
	ov._gui_input(_motion(to))
	ov._gui_input(_press(to, false))

func _press(pos: Vector2, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = pos
	return e

func _motion(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	return e

# The board exposes the two bands + applies a saved vertical nudge AFTER layout, independently,
# leaving the responsive sizing alone. A fresh board (no board_layout.json) → zero offset.
func _test_board_offsets() -> void:
	fresh("place_board")
	var ss = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(ss)
	if ss.board == null:
		ss._ready()
	await create_timer(0.05).timeout
	ok(ss._place_fence_dy == 0.0 and ss._place_board_dy == 0.0, "a fresh board has no nudge (no file → today's layout)")
	ok(ss.giver_bar != null and ss._board_center != null, "the board exposes the quest fence + board bands to the tool")

	var h: float = ss.get_viewport_rect().size.y
	var fence0: float = ss.giver_bar.position.y
	var board0: float = ss._board_center.position.y

	# nudge the FENCE only → the fence shifts by frac·h, the board stays put.
	ss._place_fence_dy = 0.1
	ss.placement_refresh()
	await create_timer(0.05).timeout
	ok(absf(ss.giver_bar.position.y - (fence0 + 0.1 * h)) < 1.0, "a fence nudge shifts the quest bar by frac·viewport_h")
	ok(absf(ss._board_center.position.y - board0) < 1.0, "the fence nudge leaves the board where it was (independent)")

	# nudge the BOARD only → the board shifts, the fence returns to its natural spot.
	ss._place_fence_dy = 0.0
	ss._place_board_dy = -0.05
	ss.placement_refresh()
	await create_timer(0.05).timeout
	ok(absf(ss._board_center.position.y - (board0 - 0.05 * h)) < 1.0, "a board nudge shifts the board by frac·viewport_h")
	ok(absf(ss.giver_bar.position.y - fence0) < 1.0, "clearing the fence nudge restores the quest bar exactly")

	# back to zero → byte-for-byte the default layout (the production guarantee).
	ss._place_board_dy = 0.0
	ss.placement_refresh()
	await create_timer(0.05).timeout
	ok(absf(ss.giver_bar.position.y - fence0) < 1.0 and absf(ss._board_center.position.y - board0) < 1.0, "zero offsets reproduce the default layout")
	ss.queue_free()

# Every farmhouse-hub unlock badge carries its spot-id meta, seated at its farm_home.json pos —
# so the tool can map a dragged badge back to the right buildings[].spot.
func _test_home_badges() -> void:
	fresh("place_home")
	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	if hx.content == null:
		hx._ready()
	await create_timer(0.05).timeout                # let the scene settle in-tree before re-opening
	hx._open_map(G.hub_map())                       # the §16 home that ships farm_home.json badges
	await create_timer(0.1).timeout

	var by_spot := _farm_home_pos()
	var badges := _find_meta(hx.content, "place_spot", [])
	ok(badges.size() >= 1, "the farmhouse hub seats unlock badges tagged with their spot id")
	var rect: Rect2 = hx._map_rect
	var matched := 0
	for b in badges:
		var sid := String(b.get_meta("place_spot"))
		if not by_spot.has(sid):
			continue
		var ctr: Vector2 = (b as Control).get_global_rect().get_center()
		var nrm := (ctr - rect.position) / rect.size
		var want: Vector2 = by_spot[sid]
		if (nrm - want).length() < 0.01:
			matched += 1
	ok(matched >= 1, "a tagged badge sits at its farm_home.json pos (the tool's px↔normalized basis holds)")
	hx.queue_free()

# The writer mutates one spot's pos in place and re-serialises with the file's format; reparsing
# shows the change applied and every other field/spot preserved.
func _test_farm_home_roundtrip() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(FARM_HOME))
	ok(typeof(data) == TYPE_DICTIONARY and data.has("buildings"), "farm_home.json parses to a buildings list")
	var first = data.buildings[0]
	var sid := String(first.spot)
	var mask := String(first.get("mask", ""))
	var cost := int(first.get("cost", -1))
	first["pos"] = [0.123, 0.456]
	var text := JSON.stringify(data, "\t", true)
	var back = JSON.parse_string(text)
	var b0 = back.buildings[0]
	ok(String(b0.spot) == sid and String(b0.get("mask", "")) == mask and int(b0.get("cost", -1)) == cost, "the writer preserves a spot's other fields (spot/mask/cost)")
	ok(float(b0.pos[0]) == 0.123 and float(b0.pos[1]) == 0.456, "the writer applies the new pos")
	ok(back.buildings.size() == data.buildings.size(), "the writer keeps every other building")

# --- helpers ----------------------------------------------------------------

func _farm_home_pos() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(FARM_HOME))
	var out := {}
	if typeof(data) == TYPE_DICTIONARY:
		for b in data.get("buildings", []):
			var p = b.get("pos", null)
			if p != null:
				out[String(b.get("spot", ""))] = Vector2(float(p[0]), float(p[1]))
	return out

func _find_meta(n: Node, key: String, acc: Array) -> Array:
	if n is Control and n.has_meta(key):
		acc.append(n)
	for c in n.get_children():
		_find_meta(c, key, acc)
	return acc
