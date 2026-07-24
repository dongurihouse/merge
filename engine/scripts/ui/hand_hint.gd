extends Control
## The FTUE hand hint — one reusable, INPUT-TRANSPARENT teach overlay.
## Spec: docs/superpowers/specs/2026-07-23-ftue-hand-hint-design.md
##
## Two gestures: "drag" (hand glides source → target, two bright cutouts) and "tap" (hand bobs on
## the target, one cutout). A soft dim covers everything EXCEPT the cutouts, built by rectangle
## SUBTRACTION — screen minus each cutout — as plain ColorRect bands. No shader.
##
## The overlay never blocks play: every node sets MOUSE_FILTER_IGNORE, so the player performs the
## real gesture straight through the veil. It also never self-dismisses — it loops until the owner
## calls dismiss() because the taught action actually happened. The owner (board.gd) decides WHEN;
## this file only decides HOW it looks.
##
## ui/ layer: imports core/ and ui/ only, never scenes/.

const Features = preload("res://engine/scripts/core/features.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")

const GESTURE_DRAG := "drag"
const GESTURE_TAP := "tap"

const DIM_ALPHA := 0.35          # the soft dim over everything but the cutouts
const CUTOUT_PAD := 6.0          # a little breathing room around the taught cell
const HAND_PX := 96.0            # the hand's on-screen size
const HAND_OFFSET := Vector2(29.0, 43.0)   # the fingertip sits up-left of the texture's centre
# (measured on the real ui/kit/hand.png: its 512px master's alpha-bbox center sits at
# roughly (255.5, 256) and the fingertip apex at ~(102, 29) — scaled to the 96px HAND_PX
# render, that's (-28.8, -42.6) up-left of centre, so HAND_OFFSET counters it here.)
const DRAG_GLIDE_S := 0.9        # source → target travel
const DRAG_PAUSE_S := 0.4        # the beat between loops
const TAP_CYCLE_S := 0.35        # one down/up bob
const PRESS_SCALE := 0.86        # the hand's scale while "pressing"
const TAP_BOB_PX := 14.0         # how far the hand dips on the tap's down beat

var gesture := GESTURE_DRAG
var dismissed := false           # set the instant dismiss() is called, before the fade-out finishes
var _src := Rect2()
var _dst := Rect2()
var _veil: Control
var _hand: Control
var _tween: Tween

## Build and start a hint over `host`. Returns null (and adds nothing) when the flag is off.
## Rects are in `host`'s coordinate space.
static func present(host: Control, gesture_id: String, source_rect: Rect2, target_rect: Rect2) -> Control:
	if not Features.on("ftue_hand_hint"):
		return null
	if host == null or not is_instance_valid(host):
		return null
	var o := new()
	o.gesture = gesture_id
	o._src = source_rect
	o._dst = target_rect
	host.add_child(o)
	o._build()
	return o

# Built explicitly by present() rather than left to the engine's own _ready() dispatch: a headless
# SceneTree test script runs its whole _initialize() before any frame is pumped, and NOTIFICATION_READY
# is not guaranteed to have fired by the time the test calls cutouts()/retarget() on the same line.
# Calling _build() synchronously right after add_child() makes the overlay usable immediately in
# every host, headless or not.
func _build() -> void:
	name = "HandHint"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 4000                       # above the board, below nothing that matters
	_veil = Control.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	_hand = _make_hand()
	add_child(_hand)
	_rebuild_veil()
	_start_loop()

## The bright rects this hint punches through the dim: [source, target] for a drag, [target] for a tap.
func cutouts() -> Array:
	if gesture == GESTURE_DRAG:
		return [_src.grow(CUTOUT_PAD), _dst.grow(CUTOUT_PAD)]
	return [_dst.grow(CUTOUT_PAD)]

## Move the hint to new rects WITHOUT restarting it — the board rebuilt under us.
## A no-op once dismiss() has been called: a mis-sequenced caller must not be able to restart
## a looping tween (or rebuild the veil) on a node that is already fading out to queue_free.
func retarget(source_rect: Rect2, target_rect: Rect2) -> void:
	if dismissed:
		return
	_src = source_rect
	_dst = target_rect
	_rebuild_veil()
	_start_loop()

func dismiss() -> void:
	if dismissed:
		return
	dismissed = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(queue_free)

# --- the veil ---------------------------------------------------------------
# Screen minus N cutouts, as axis-aligned bands. For one cutout that is the classic four-band
# frame (above / below / left / right). For two, the second is subtracted from each band the
# first produced — so the result is always a set of disjoint rects covering everything but the
# cutouts, however they are arranged.

func _rebuild_veil() -> void:
	for c in _veil.get_children():
		c.queue_free()
	var screen := Rect2(Vector2.ZERO, _screen_size())
	var bands: Array = [screen]
	for hole in cutouts():
		var next: Array = []
		for band in bands:
			next.append_array(_subtract(band, hole))
		bands = next
	for band in bands:
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.color = Color(0.0, 0.0, 0.0, DIM_ALPHA)
		r.position = (band as Rect2).position
		r.size = (band as Rect2).size
		_veil.add_child(r)

# The rect the veil must cover. `_build()` runs synchronously right after add_child(), before the
# engine has had a layout pass, so `size` (anchored to PRESET_FULL_RECT) may still read zero even
# though the host already has a real size — fall back to the host's own size, then to the viewport
# (guarded: an unparented node mid-test has neither, and get_viewport_rect() errors off-tree).
func _screen_size() -> Vector2:
	if size != Vector2.ZERO:
		return size
	var host := get_parent()
	if host is Control and (host as Control).size != Vector2.ZERO:
		return (host as Control).size
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2.ZERO

# `band` minus `hole` as up to four axis-aligned rects. No intersection → the band, unchanged.
func _subtract(band: Rect2, hole: Rect2) -> Array:
	var cut := band.intersection(hole)
	if cut.size.x <= 0.0 or cut.size.y <= 0.0:
		return [band]
	var out: Array = []
	if cut.position.y > band.position.y:                                   # above
		out.append(Rect2(band.position, Vector2(band.size.x, cut.position.y - band.position.y)))
	if cut.end.y < band.end.y:                                             # below
		out.append(Rect2(Vector2(band.position.x, cut.end.y), Vector2(band.size.x, band.end.y - cut.end.y)))
	if cut.position.x > band.position.x:                                   # left, between the two
		out.append(Rect2(Vector2(band.position.x, cut.position.y), Vector2(cut.position.x - band.position.x, cut.size.y)))
	if cut.end.x < band.end.x:                                             # right, between the two
		out.append(Rect2(Vector2(cut.end.x, cut.position.y), Vector2(band.end.x - cut.end.x, cut.size.y)))
	return out

# --- the hand ---------------------------------------------------------------
# Ships twice (Look kit rule): the generated cursor when ui/kit/hand.png exists, a small
# code-drawn hand otherwise, at the SAME metrics so the motion is identical either way.

func _make_hand() -> Control:
	var tex: Texture2D = null
	var p := Look.kit("kit/hand.png")
	if ResourceLoader.exists(p):
		tex = load(p) as Texture2D
	if tex != null:
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE      # BEFORE size — a later set silently clamps up
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		tr.texture = tex
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.size = Vector2(HAND_PX, HAND_PX)
		tr.pivot_offset = Vector2(HAND_PX, HAND_PX) * 0.5
		return tr
	var fb := _HandDraw.new()
	fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fb.size = Vector2(HAND_PX, HAND_PX)
	fb.pivot_offset = Vector2(HAND_PX, HAND_PX) * 0.5
	return fb

# The code-drawn fallback: a pale rounded finger with a cuff. Same box as the texture.
class _HandDraw extends Control:
	func _draw() -> void:
		var w := size.x
		var cream := Color(0.98, 0.94, 0.86, 0.98)
		var edge := Color(0.36, 0.28, 0.22, 0.85)
		var palm := Rect2(w * 0.28, w * 0.42, w * 0.44, w * 0.44)
		draw_circle(Vector2(w * 0.5, w * 0.30), w * 0.13, cream)          # fingertip
		draw_rect(palm, cream, true)
		draw_circle(Vector2(w * 0.5, w * 0.30), w * 0.13, edge, false, 2.0)
		draw_rect(palm, edge, false, 2.0)

func _hand_pos_for(r: Rect2) -> Vector2:
	return r.get_center() - _hand.size * 0.5 + HAND_OFFSET

func _start_loop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if gesture == GESTURE_DRAG:
		_loop_drag()
	else:
		_loop_tap()

func _loop_drag() -> void:
	_hand.position = _hand_pos_for(_src)
	_hand.scale = Vector2.ONE
	_tween = create_tween().set_loops()
	_tween.tween_property(_hand, "scale", Vector2(PRESS_SCALE, PRESS_SCALE), 0.14)   # press
	_tween.tween_property(_hand, "position", _hand_pos_for(_dst), DRAG_GLIDE_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)                     # glide
	_tween.tween_property(_hand, "scale", Vector2.ONE, 0.14)                         # release
	_tween.tween_interval(DRAG_PAUSE_S)
	_tween.tween_property(_hand, "modulate:a", 0.0, 0.18)
	_tween.tween_callback(func() -> void: _hand.position = _hand_pos_for(_src))
	_tween.tween_property(_hand, "modulate:a", 1.0, 0.18)

func _loop_tap() -> void:
	var up := _hand_pos_for(_dst)
	_hand.position = up
	_hand.scale = Vector2.ONE
	_tween = create_tween().set_loops()
	_tween.set_parallel(false)
	_tween.tween_property(_hand, "position", up + Vector2(0.0, TAP_BOB_PX), TAP_CYCLE_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_hand, "scale", Vector2(PRESS_SCALE, PRESS_SCALE), TAP_CYCLE_S * 0.5)
	_tween.tween_property(_hand, "position", up, TAP_CYCLE_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_hand, "scale", Vector2.ONE, TAP_CYCLE_S * 0.5)
	_tween.tween_interval(DRAG_PAUSE_S)

# --- eligibility (pure seam) ------------------------------------------------
# WHICH hint should be live right now, given the ledger and what the board can offer. Kept here,
# free of scene state, so the teach ORDER is asserted headlessly. "" = show nothing.
# Order is merge → gen_tap: a hint never skips ahead of an earlier unseen one, so a player who
# happens to lack a mergeable pair simply waits rather than being taught out of order.
static func next_hint_id(merge_seen: bool, gen_tap_seen: bool, has_pair: bool, has_gen: bool) -> String:
	if not merge_seen:
		return "merge" if has_pair else ""
	if not gen_tap_seen:
		return "gen_tap" if has_gen else ""
	return ""
