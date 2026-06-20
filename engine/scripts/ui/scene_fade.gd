extends RefCounted
## Cross-scene transition cover.
##
## Even after SceneWarm removes the load+compile cost, the swap still pays a synchronous instantiate +
## _ready + first-frame GPU upload — a brief hitch. Godot builds the tree on the main thread (instantiate
## can't be threaded), so we HIDE that hitch instead of spreading it: the outgoing scene fades to a solid
## cover, the swap runs WHILE the screen is covered (the freeze lands on a solid frame, not a live one),
## and the incoming scene fades in from its own cover. The user sees a smooth ~1/3 s dip, never a frozen
## live frame.
##
## Tunables — eyeball + adjust to taste (feel, not correctness): COVER_COLOR / FADE_OUT / FADE_IN.

const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")

const COVER_COLOR := Color(0.05, 0.05, 0.06)   # near-black; softer than pure black on the cozy palette
const FADE_OUT := 0.15                          # current scene -> covered (seconds)
const FADE_IN := 0.18                           # new scene reveals from the cover (seconds)

## A full-screen cover on a CanvasLayer above everything in `scene`, at the given alpha. block_input
## STOPs taps (used during a transition); otherwise the cover is click-through. Returns the layer.
static func cover(scene: Node, alpha: float, block_input: bool) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 128                            # above the game's own HUD/overlay layers
	var rect := ColorRect.new()
	rect.color = Color(COVER_COLOR.r, COVER_COLOR.g, COVER_COLOR.b, alpha)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP if block_input else Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	scene.add_child(layer)
	return layer

## Reveal `scene` from a cover: drop an opaque cover, then tween it transparent and free it. Click-through
## so the player can interact immediately. Call from a scene's _ready. Returns the cover layer.
static func fade_in(scene: Node, dur := FADE_IN) -> CanvasLayer:
	var layer := cover(scene, 1.0, false)
	var rect := layer.get_child(0) as ColorRect
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, dur)
	tw.tween_callback(layer.queue_free)
	return layer

## Transition `scene` -> `path`: fade the current scene to the cover, then run the (prewarmed) swap under
## cover so its build hitch is invisible. Input is blocked during the fade so a double-tap can't double-swap.
static func to(scene: Node, tree: SceneTree, path: String, dur := FADE_OUT) -> void:
	var layer := cover(scene, 0.0, true)
	var rect := layer.get_child(0) as ColorRect
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 1.0, dur)
	tw.tween_callback(func() -> void: SceneWarm.go(tree, path))
