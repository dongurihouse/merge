extends "res://engine/tests/test_base.gd"
## Guard: the RESIDENTS hand card arbitrates SCROLL vs PICK-UP off the PHYSICAL event.
##   godot --headless --path . -s res://engine/tests/resident_drag_tests.gd
##
## residents.gd's DragCard owns both gestures a hand card can start: a vertical swipe scrolls the
## ON HAND list, a press-and-drag picks the resident up to merge/place. It tells them apart with
## `_touch_down` — "was this gesture started by a finger?" — and a quick vertical FINGER swipe is
## given to the scroller (TOUCH_DRAG_HOLD_MS of dwell claims the resident instead).
##
## Every physical press arrives TWICE: the platform's real event plus the engine's emulated twin
## (input_devices/pointing/emulate_touch_from_mouse). Measured in-engine at _gui_input, Godot
## 4.6.2, this project's settings, the ORDER inverts by platform:
##   desktop (real mouse): touch_down(device=-1), mouse_down(device=0)
##   device  (real touch): mouse_down(device=-1), touch_down(device=0)
## So the FIRST event's class is not the gesture's kind — taking it inverted `_touch_down` on both
## platforms: desktop scrolled when the player meant to drag, and a device could never scroll the
## hand at all. The engine stamps InputEvent.DEVICE_ID_EMULATION (-1) on the twin ONLY, so the
## device id is the discriminator; DisplayServer.is_touchscreen_available() is NOT (it reports true
## on macOS here, because the emulation is on).
##
## This drives a real DragCard with the exact measured pairs — the twin and the physical event,
## device ids set, in each platform's order — against a real overflowing ScrollContainer, and pins:
##   1. desktop ordering + quick vertical gesture  -> DRAG   (the reproduction)
##   2. device  ordering + quick vertical gesture  -> SCROLL (the reproduction)
##   3. device  ordering + dwell past the hold     -> DRAG   (hand→Habitat placement survives)
##   4. a plain tap fires on_tap EXACTLY once under BOTH orderings (the change moves which half of
##      the pair drives the machine, so neither half may double-fire or drop the tap).

const Residents = preload("res://engine/scripts/ui/residents.gd")

const DESKTOP := "desktop"   # real mouse in: the emulated TOUCH arrives first
const DEVICE := "device"     # real finger in: the emulated MOUSE arrives first

const EM := -1               # InputEvent.DEVICE_ID_EMULATION — the twin
const PHYS := 0              # a real device id

# --- the fixture: a hand card inside a genuinely overflowing scroller -------------------------
#
# Nothing here is mocked: a real ScrollContainer whose content is twice its height (so
# _can_scroll() is true for the real reason), the card inside it, and a drop target outside it.
# The scroller is tall enough that the whole gesture stays clear of the _auto_scroll_drag edge
# bands, so any movement of scroll_vertical came from the arbitration under test.
func _fixture() -> Dictionary:
	var host := Control.new()
	host.size = Vector2(400, 500)
	root.add_child(host)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 100)
	scroll.size = Vector2(200, 300)
	scroll.custom_minimum_size = Vector2(200, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	host.add_child(scroll)

	var content := Control.new()
	content.custom_minimum_size = Vector2(200, 600)   # 2× the viewport: a real overflow
	scroll.add_child(content)

	var counts := {"tap": 0, "take": 0}

	var layer := Control.new()          # the ghost rides this, as the dialog's overlay does
	layer.size = Vector2(400, 500)
	host.add_child(layer)

	var card = Residents.DragCard.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.position = Vector2(0, 100)     # global y 200..290, mid-viewport
	card.size = Vector2(90, 90)
	card.data = {"src": "hand", "idx": 0, "line": "coin", "tier": 1}
	card.scroll_owner = scroll
	card.drag_layer = layer
	card.make_preview = func() -> Control:
		var ghost := Control.new()
		ghost.size = Vector2(90, 90)
		return ghost
	card.on_tap = func() -> void:
		counts["tap"] = int(counts["tap"]) + 1
	content.add_child(card)

	var target = Residents.DragCard.new()   # a free habitat cell, OUTSIDE the scroller
	target.mouse_filter = Control.MOUSE_FILTER_STOP
	target.position = Vector2(240, 150)
	target.size = Vector2(90, 90)
	target.data = {"src": "free"}
	target.can_take = func(from: Dictionary, _me: Dictionary) -> bool:
		return String(from.get("src", "")) == "hand"
	target.on_take = func(_from: Dictionary, _me: Dictionary) -> void:
		counts["take"] = int(counts["take"]) + 1
	host.add_child(target)

	var registry := func() -> Array: return [card, target]
	card.targets = registry
	target.targets = registry
	return {"host": host, "scroll": scroll, "card": card, "target": target, "counts": counts}

# --- the measured event pairs -----------------------------------------------------------------

func _mouse_btn(pressed: bool, at: Vector2, dev: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	e.global_position = at
	e.device = dev
	return e

func _touch(pressed: bool, at: Vector2, dev: int) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = at
	e.device = dev
	return e

func _mouse_move(at: Vector2, rel: Vector2, dev: int) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.device = dev
	return e

func _drag(at: Vector2, rel: Vector2, dev: int) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = at
	e.relative = rel
	e.device = dev
	return e

# _gui_input takes LOCAL positions; the emulated half carries device -1, the physical half a real id.
func _send_press(card, at: Vector2, order: String) -> void:
	if order == DESKTOP:
		card._gui_input(_touch(true, at, EM))
		card._gui_input(_mouse_btn(true, at, PHYS))
	else:
		card._gui_input(_mouse_btn(true, at, EM))
		card._gui_input(_touch(true, at, PHYS))

func _send_move(card, at: Vector2, rel: Vector2, order: String) -> void:
	if order == DESKTOP:
		card._gui_input(_drag(at, rel, EM))
		card._gui_input(_mouse_move(at, rel, PHYS))
	else:
		card._gui_input(_mouse_move(at, rel, EM))
		card._gui_input(_drag(at, rel, PHYS))

func _send_release(card, at: Vector2, order: String) -> void:
	if order == DESKTOP:
		card._gui_input(_touch(false, at, EM))
		card._gui_input(_mouse_btn(false, at, PHYS))
	else:
		card._gui_input(_mouse_btn(false, at, EM))
		card._gui_input(_touch(false, at, PHYS))

func _ghost_of(card) -> Control:
	return card._ghost as Control

# --- the cases ---------------------------------------------------------------------------------

func _initialize() -> void:
	# 1. DESKTOP ordering — a quick vertical mouse drag PICKS THE RESIDENT UP.
	var f := _fixture()
	await process_frame
	await process_frame
	var card = f.card
	var scroll: ScrollContainer = f.scroll
	ok(card._can_scroll(), "fixture: the hand scroller really overflows (arbitration is live)")
	_send_press(card, Vector2(45, 50), DESKTOP)
	ok(not card._touch_down, "desktop: the PHYSICAL mouse press sets the gesture kind, not its emulated touch twin")
	_send_move(card, Vector2(45, 15), Vector2(0, -35), DESKTOP)
	ok(card._dragging, "desktop: a quick vertical drag on a hand card starts a DRAG")
	ok(not card._scrolling, "desktop: a quick vertical drag does NOT hand the gesture to the scroller")
	ok(_ghost_of(card) != null, "desktop: the drag ghost is created")
	ok(scroll.scroll_vertical == 0, "desktop: scroll_vertical is untouched by a drag")
	# ride to the free cell and drop
	_send_move(card, Vector2(285, -5), Vector2(240, -20), DESKTOP)
	_send_release(card, Vector2(285, -5), DESKTOP)
	ok(int(f.counts["take"]) == 1, "desktop: releasing over a free cell fires the drop target's on_take")
	ok(int(f.counts["tap"]) == 0, "desktop: a drag is not also a tap")
	ok(scroll.scroll_vertical == 0, "desktop: the whole drag left scroll_vertical at 0")
	await drop(f.host)

	# 2. DEVICE ordering — the same quick vertical gesture SCROLLS the hand.
	f = _fixture()
	await process_frame
	await process_frame
	card = f.card
	scroll = f.scroll
	_send_press(card, Vector2(45, 50), DEVICE)
	ok(card._touch_down, "device: the PHYSICAL touch press sets the gesture kind, not its emulated mouse twin")
	_send_move(card, Vector2(45, 15), Vector2(0, -35), DEVICE)
	ok(card._scrolling, "device: a quick vertical finger swipe SCROLLS the hand list")
	ok(not card._dragging, "device: a quick vertical finger swipe does not pick the resident up")
	ok(_ghost_of(card) == null, "device: no drag ghost is created for a scroll")
	ok(scroll.scroll_vertical > 0, "device: scroll_vertical actually moved")
	_send_release(card, Vector2(45, 15), DEVICE)
	ok(int(f.counts["take"]) == 0, "device: a scroll never resolves a drop target")
	ok(int(f.counts["tap"]) == 0, "device: a scroll is not a tap")
	await drop(f.host)

	# 3. DEVICE ordering + a dwell past TOUCH_DRAG_HOLD_MS — the hand→Habitat placement path.
	f = _fixture()
	await process_frame
	await process_frame
	card = f.card
	scroll = f.scroll
	_send_press(card, Vector2(45, 50), DEVICE)
	var hold := int(Residents.DragCard.TOUCH_DRAG_HOLD_MS) + 20
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < hold:
		await process_frame
	_send_move(card, Vector2(45, 15), Vector2(0, -35), DEVICE)
	ok(card._dragging, "device: dwelling past TOUCH_DRAG_HOLD_MS claims the resident (a DRAG)")
	ok(not card._scrolling, "device: the dwell gesture does not scroll")
	ok(_ghost_of(card) != null, "device: the held resident gets its ghost")
	ok(scroll.scroll_vertical == 0, "device: the dwell drag leaves scroll_vertical alone")
	_send_move(card, Vector2(285, -5), Vector2(240, -20), DEVICE)
	_send_release(card, Vector2(285, -5), DEVICE)
	ok(int(f.counts["take"]) == 1, "device: the dwell drag places into the free habitat cell")
	await drop(f.host)

	# 4. A plain tap fires on_tap EXACTLY once — under BOTH orderings.
	for order in [DESKTOP, DEVICE]:
		f = _fixture()
		await process_frame
		await process_frame
		card = f.card
		_send_press(card, Vector2(45, 50), order)
		_send_release(card, Vector2(45, 50), order)
		ok(int(f.counts["tap"]) == 1, "%s: a plain tap fires on_tap exactly once" % order)
		ok(int(f.counts["take"]) == 0, "%s: a plain tap resolves no drop target" % order)
		ok(f.scroll.scroll_vertical == 0, "%s: a plain tap does not scroll" % order)
		await drop(f.host)

	finish()
