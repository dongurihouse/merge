extends Control
## The FTUE feature-spotlight OVERLAY (Core §14 / T28) — presentation only.
## When a staged feature FIRST appears, the scene builds one of these over `target`:
##   · a semi-transparent VEIL dims the whole screen EXCEPT a cutout over the target
##     (drawn as four bands around the target rect — the target reads bright/highlighted),
##   · a pulsing RING traces the target (the "spotlight + pulse"),
##   · a mimed HAND-GESTURE plays — a code-drawn finger doing a TAP (a scale-pulse at the
##     target) or a DRAG (a glide along a short path toward the board) — so the player sees
##     exactly how to use it (§14),
##   · an optional wordless caption sits under the hand.
## Dismisses on ANY tap (or when the player interacts), then frees itself + calls `on_done`.
##
## Per §13 "everything ships twice": this is the CODE-DRAWN fallback — no art exists yet, a
## drawn finger/ring is fine; an art hand swaps in later behind the same API. Reuses the §12
## FX vocabulary (breathe/pop_in). ui/ layer: imports core + ui only, never scenes/.

const FX = preload("res://engine/scripts/ui/fx.gd")
const Spotlight = preload("res://engine/scripts/core/spotlight.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE

const VEIL_ALPHA := 0.62           # how much the screen dims outside the cutout
const VEIL_COLOR := Color("#17121E")
const RING_COLOR := Color("#FBF3EA")   # CREAM — the bright spotlight ring
const RING_PAD := 14.0             # the ring sits this far outside the target rect
const RING_WIDTH := 5.0
const HAND_COLOR := Color("#FBF3EA")
const HAND_LEN := 64.0             # drawn finger length
const DRAG_GLIDE := 96.0           # how far a drag-gesture finger travels
const HAND_TAP_DEST_DY := 70.0     # the hand sits this far below the target center

var _target_rect := Rect2()        # the highlighted region (global → local, the root is full-rect)
var _gesture := "tap"
var _hand: Control
var _ring: Control
var _on_done := Callable()
var _dismissed := false

## Build + present the overlay over `target`, miming `gesture` ("tap"/"drag"), captioned
## `label`. `host` is the full-rect scene root the overlay parents under. Returns the overlay
## (already added + animating). `on_done` fires after dismissal. A null/invalid target → a
## centered fallback (still teaches the gesture). Honours the §11 flag (no-op when off).
static func present(host: Control, target: Control, gesture: String, label: String, on_done := Callable()) -> Control:
	if not Features.on("ftue_feature_spotlight"):
		if on_done.is_valid():
			on_done.call()
		return null
	var ov := new()
	ov._gesture = "drag" if gesture == "drag" else "tap"
	ov._on_done = on_done
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP   # eat input behind it until dismissed
	ov.z_index = 4096
	host.add_child(ov)
	# resolve the target rect into the overlay's own (full-rect) space.
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		var gr := target.get_global_rect()
		ov._target_rect = Rect2(gr.position - ov.global_position, gr.size)
	else:
		var c := ov.size * 0.5
		ov._target_rect = Rect2(c - Vector2(90, 90), Vector2(180, 180))
	ov._build(label)
	return ov

func _build(label: String) -> void:
	# 1. the veil with a cutout over the target — four dim bands framing the bright target.
	_build_veil()
	# 2. the pulsing spotlight ring tracing the target (§14 "spotlight + pulse").
	_ring = _RingDraw.new()
	(_ring as _RingDraw).rect = _target_rect.grow(RING_PAD)
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	FX.breathe(_ring, 1.05, 0.7)        # the pulse (vocabulary §12)
	# 3. the mimed hand-gesture — a code-drawn finger doing a tap or a drag.
	_build_hand()
	# 4. an optional wordless caption under the hand.
	if label != "":
		_build_caption(label)
	# enter softly (vocabulary §12), then loop the gesture.
	FX.pop_in(self)
	_play_gesture()

func _build_veil() -> void:
	# Four ColorRects around the target rect leave the target itself un-dimmed (a cutout),
	# so the highlighted feature reads BRIGHT against the dimmed screen.
	var r := _target_rect.grow(RING_PAD)
	var full := get_viewport_rect().size
	var bands := [
		Rect2(0, 0, full.x, maxf(0.0, r.position.y)),                                  # top
		Rect2(0, r.end.y, full.x, maxf(0.0, full.y - r.end.y)),                        # bottom
		Rect2(0, r.position.y, maxf(0.0, r.position.x), r.size.y),                     # left
		Rect2(r.end.x, r.position.y, maxf(0.0, full.x - r.end.x), r.size.y),           # right
	]
	for b in bands:
		var rect := b as Rect2
		var cr := ColorRect.new()
		cr.color = Color(VEIL_COLOR, VEIL_ALPHA)
		cr.position = rect.position
		cr.size = rect.size
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cr)

func _build_hand() -> void:
	_hand = _HandDraw.new()
	_hand.custom_minimum_size = Vector2(HAND_LEN, HAND_LEN)
	_hand.size = Vector2(HAND_LEN, HAND_LEN)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand)
	_hand.position = _hand_home()

# True when the target sits low on the screen — then the tap hand + caption go ABOVE it so
# the finger never clips off the bottom edge (e.g. a bottom-bar shop button).
func _target_low() -> bool:
	return _target_rect.get_center().y > get_viewport_rect().size.y * 0.72

# Where the hand starts: beside the target center for a drag (it glides outward); below the
# target for a tap (or ABOVE it when the target is low on-screen).
func _hand_home() -> Vector2:
	var c := _target_rect.get_center()
	if _gesture == "drag":
		return c - Vector2(HAND_LEN * 0.5, HAND_LEN * 0.2)
	var dy := -HAND_TAP_DEST_DY - HAND_LEN if _target_low() else HAND_TAP_DEST_DY
	return c + Vector2(-HAND_LEN * 0.5, dy)

func _play_gesture() -> void:
	if not is_instance_valid(_hand):
		return
	var home := _hand_home()
	_hand.position = home
	_hand.pivot_offset = _hand.size * 0.5
	var t := _hand.create_tween().set_loops()
	if _gesture == "drag":
		# a finger pressing, then gliding along a short path (mimes the sell/stow drag).
		var dest := home + Vector2(DRAG_GLIDE, DRAG_GLIDE * 0.35)
		t.tween_property(_hand, "scale", Vector2(0.86, 0.86), 0.14).set_trans(Tween.TRANS_SINE)
		t.tween_property(_hand, "position", dest, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(_hand, "scale", Vector2.ONE, 0.12)
		t.tween_property(_hand, "position", home, 0.0)
		t.tween_interval(0.45)
	else:
		# a finger tapping in place (a press-down scale-pulse on the target).
		t.tween_property(_hand, "scale", Vector2(0.78, 0.78), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_property(_hand, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.5)

func _build_caption(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Pal.CREAM)
	lbl.add_theme_color_override("font_outline_color", Pal.BG_DEEP)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(360, 0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# under the hand (or above the target when it sits low), clamped on-screen.
	var full := get_viewport_rect().size
	var y: float = _hand_home().y - 56.0 if _target_low() else _hand_home().y + HAND_LEN + 18.0
	y = clampf(y, 40.0, full.y - 90.0)
	lbl.position = Vector2(clampf(_target_rect.get_center().x - 180.0, 12.0, full.x - 372.0), y)
	add_child(lbl)

# Dismiss on ANY tap/press — the player tries the feature and the guide gets out of the way.
func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		dismiss()

func dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true
	var done := _on_done
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.tween_callback(func() -> void:
		queue_free()
		if done.is_valid():
			done.call())

# --- code-drawn primitives (the §13 art-less fallback) ----------------------------

# A bright rounded ring tracing the target rect (the spotlight outline + pulse host).
class _RingDraw extends Control:
	var rect := Rect2()
	func _draw() -> void:
		draw_rect(rect, Color("#FBF3EA", 0.10), true)            # a faint warm fill in the cutout
		draw_rect(rect, Color("#FBF3EA"), false, 5.0)            # the bright ring
		draw_rect(rect.grow(4.0), Color("#E3B23C", 0.5), false, 2.0)   # a soft straw halo

# A simple code-drawn finger/hand pointer (a rounded fingertip + a short shaft).
class _HandDraw extends Control:
	func _draw() -> void:
		var tip := Vector2(size.x * 0.5, size.y * 0.28)
		var base := Vector2(size.x * 0.5, size.y * 0.95)
		draw_line(tip, base, Color("#17121E", 0.45), 16.0)       # a soft shadow shaft behind
		draw_line(tip, base, Color("#FBF3EA"), 11.0)             # the finger
		draw_circle(tip, 13.0, Color("#17121E", 0.45))           # fingertip shadow
		draw_circle(tip, 10.0, Color("#FBF3EA"))                 # the fingertip
		draw_circle(tip, 5.0, Color("#E3B23C"))                  # a warm tap dot
