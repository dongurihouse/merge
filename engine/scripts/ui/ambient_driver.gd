extends Node
## The ambient CPU governor — one per ambient layer. Two jobs, both to keep a near-static board from
## heat-soaking the SoC:
##   1. THROTTLE — runs its `on_tick` (the layer's reposition pass) at a FIXED LOW RATE, not once per
##      rendered frame. The wander is slow + purely time-derived, so a low rate is visually identical.
##   2. IDLE — when the app is backgrounded / unfocused / the layer is hidden, it stops ticking AND
##      freezes every CPUParticles2D under the layer (process_mode DISABLED → the per-frame CPU
##      simulation halts), and sets the layer's `paused` meta (the hook `_update_layer` already reads).
## Cheap to rebuild: the host frees + rebuilds ambient layers freely; a fresh driver re-derives its
## state on the next frame. The weather layer attaches one with an empty `on_tick` (gating only).

var _layer: Control = null
var _tick := Callable()
var _interval := 1.0 / 15.0
var _accum := 0.0
var _focused := true                 # cleared on app-pause / window focus-out
var _active := true                  # current applied state (ticking + particles live)

## Wire the driver to its layer. `on_tick` is the per-rate callback (empty for weather — gating only),
## `hz` the tick rate.
func setup(layer: Control, on_tick: Callable, hz: float) -> void:
	_layer = layer
	_tick = on_tick
	_interval = 1.0 / maxf(1.0, hz)
	_apply(true)                     # assume active; _process reconciles once the layer is in the tree

func _process(delta: float) -> void:
	_reconcile()
	if not _active or not _tick.is_valid():
		return
	_accum += delta
	if _accum >= _interval:
		_accum = 0.0
		_tick.call()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_focused = false
		_reconcile()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_focused = true
		_reconcile()

# Active iff the app is in the foreground. Visibility-in-tree is deliberately NOT a gate: an occluding
# dialog still leaves the layer visible_in_tree, and the wander should keep going while you watch — we
# only idle when the app itself is unseen (backgrounded / window focus lost).
func _desired() -> bool:
	return _focused

func _reconcile() -> void:
	var want := _desired()
	if want != _active:
		_apply(want)

func _apply(active: bool) -> void:
	_active = active
	if _layer == null or not is_instance_valid(_layer):
		return
	_layer.set_meta("paused", not active)          # the hook _update_layer reads before repositioning
	_freeze_particles(_layer, not active)

# Halt / resume the per-frame CPU particle simulation under the layer (weather drift, motes).
func _freeze_particles(node: Node, frozen: bool) -> void:
	if node is CPUParticles2D:
		node.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT
	for c in node.get_children():
		_freeze_particles(c, frozen)
