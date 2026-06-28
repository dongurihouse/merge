extends RefCounted
## Move screen-juice — a TOGGLEABLE + tunable registry for the TILE-TRAVEL feel (a tile that slides /
## arcs / falls from one cell to another, built to sell the trip + the arrival): cast shadow + motion
## trail + motion-lean. Mirrors land_fx.gd: the Move workbench flips the toggles + drags the knobs,
## replays to FEEL it, and saves to config; the game resolves the saved config once and drives a tunable
## version of feel.move via MoveFx.apply(...).
##
## Add a new move enhancement = one row in EFFECTS (+ a knob in KNOBS) + a branch in apply().

const FX = preload("res://engine/scripts/ui/fx.gd")

# id · label (shown in the workbench) · tip (one-line feel). DEFAULT is on; the config can turn any off.
const EFFECTS := [
	{"id": "shadow", "label": "Cast shadow", "tip": "a soft dark blob follows under the tile as it travels"},
	{"id": "trail",  "label": "Motion trail", "tip": "a few faded afterimage ghosts smear behind a fast move"},
	{"id": "lean",   "label": "Motion lean", "tip": "the tile tilts into the travel direction, righting on arrival (not on arc)"},
]

# id → default numeric knob. Sliders edit these; apply() reads them via knob().
const KNOBS := {
	"duration_ms": 220,      # primary travel duration (ms) — bigger = a slower, weightier trip
	"trail_count": 3,        # afterimage ghosts dropped along the chord
	"shadow_alpha_pct": 22,  # cast-shadow opacity (% — 0 invisible, 60 heavy)
	"lean_deg": 6,           # how far the tile tilts into the horizontal travel direction
}

const SHADOW_DARK := Color(0.05, 0.05, 0.05)
const SHADOW_SCALE := Vector2(0.8, 0.34)         # the blob is wide + short relative to the tile
const SHADOW_OFFSET := Vector2(0, 10)            # nudged down so it reads as ground contact
const TRAIL_T := 0.12                            # each ghost fades out over ~0.12s

static func knob(opts: Dictionary, id: String) -> int:
	return int(opts.get(id, KNOBS.get(id, 0)))

static func defaults() -> Dictionary:
	var d := {"enabled": true}
	for e in EFFECTS:
		d[String(e.id)] = true
	for k in KNOBS.keys():
		d[k] = KNOBS[k]
	return d

## Resolve the saved toggles + knobs over the defaults (the "move_fx" config block).
static func from_config(cfg: Dictionary) -> Dictionary:
	var r: Dictionary = cfg.get("move_fx", {}) if cfg is Dictionary else {}
	var d := defaults()
	for e in EFFECTS:
		var id := String(e.id)
		if r.has(id):
			d[id] = bool(r[id])
	if r.has("enabled"):
		d["enabled"] = bool(r["enabled"])
	for k in KNOBS.keys():
		d[k] = int(r.get(k, KNOBS[k]))
	return d

## True when the master switch is on AND this effect is on.
static func on(opts: Dictionary, id: String) -> bool:
	return bool(opts.get("enabled", true)) and bool(opts.get(id, true))

## Are the felt enhancements (shadow / trail / lean) allowed at all? Hard-off under calm (motion
## accessibility) AND under headless (no renderer, no felt effect) — exactly feel.move's gate.
static func _enhance_enabled() -> bool:
	return not FX.calm() and DisplayServer.get_name() != "headless"

## Drive the TRAVEL per the resolved opts. `node` slides/arcs/falls `from`->`to`; `kind` is
## "slide" / "arc" / "fall". Returns the primary `position` Tween (always built, so the move reaches
## `to` even with every enhancement off). Mirrors feel.move but every cue is individually toggled + tuned.
static func apply(node: Control, from: Vector2, to: Vector2, kind: String, opts: Dictionary) -> Tween:
	if not (node and is_instance_valid(node)):
		return null
	node.position = from
	var dur := maxf(0.02, float(knob(opts, "duration_ms")) / 1000.0)
	var t := node.create_tween()
	if kind == "arc":
		_build_arc(t, node, from, to, dur)
	else:
		# slide / fall: accelerate INTO the impact — slow to leave, fastest at the target.
		t.tween_property(node, "position", to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# the enhancements ride alongside the primary tween — never block it, never run headless/calm.
	if _enhance_enabled():
		if on(opts, "shadow"):
			_shadow(node, from, to, dur, float(knob(opts, "shadow_alpha_pct")) / 100.0)
		if on(opts, "trail"):
			_trail(node, from, to, dur, knob(opts, "trail_count"))
		if on(opts, "lean") and kind != "arc":
			_lean(node, from, to, dur, float(knob(opts, "lean_deg")))
	return t

# The arc's two legs: up-and-over (EASE_OUT, leaves slowly) to a peak above the higher endpoint, then
# down-into-target (EASE_IN, accelerates into the hit). Total = dur, split evenly across the two legs.
static func _build_arc(t: Tween, node: Control, from: Vector2, to: Vector2, dur: float) -> void:
	var span := absf(to.x - from.x)
	var lift := maxf(60.0, span * 0.4)
	var peak := Vector2((from.x + to.x) * 0.5, minf(from.y, to.y) - lift)
	t.tween_property(node, "position", peak, dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", to, dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# --- enhancements (scene-tree; only run off-headless, off-calm) ------------------------

## A soft dark blob that follows under the node along the ground for the duration of the move. A single
## ColorRect — cheap; frees itself when the travel ends. For an "arc" it shrinks + fades as the tile
## rises then snaps back on land. Modelled on feel._move_shadow (simpler — no contact-shadow dedupe).
static func _shadow(node: Control, from: Vector2, to: Vector2, dur: float, alpha: float) -> void:
	if not (node and is_instance_valid(node)) or not node.is_inside_tree():
		return
	var parent := node.get_parent()
	if not (parent is CanvasItem):
		return
	var sz := node.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		sz = node.custom_minimum_size
	var sh := ColorRect.new()
	sh.color = Color(SHADOW_DARK.r, SHADOW_DARK.g, SHADOW_DARK.b, alpha)
	sh.size = sz * SHADOW_SCALE
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.z_index = -1   # under the tile
	(parent as Node).add_child(sh)
	(parent as Node).move_child(sh, 0)   # behind the moving node
	sh.pivot_offset = sh.size * 0.5
	var base_off := SHADOW_OFFSET + (sz - sh.size) * 0.5
	sh.position = from + base_off
	var t := sh.create_tween()
	t.tween_property(sh, "position", to + base_off, dur)   # follow the node along the ground
	t.chain().tween_callback(sh.queue_free)

## A cheap motion TRAIL — `count` faded node.duplicate() ghosts dropped along the from->to chord, each
## appearing as the node passes its point then fading out over TRAIL_T and self-freeing. Modelled on
## feel._move_trail (placed on the straight chord, no spin — a faint smear behind a fast move).
static func _trail(node: Control, from: Vector2, to: Vector2, dur: float, count: int) -> void:
	if not (node and is_instance_valid(node)) or not node.is_inside_tree():
		return
	var parent := node.get_parent()
	if not (parent is Node):
		return
	if count <= 0:
		return
	for i in count:
		var f := float(i + 1) / float(count + 1)   # spaced strictly between the endpoints
		var ghost := node.duplicate()
		if not (ghost is CanvasItem):
			ghost.free()
			continue
		var g := ghost as Control
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.modulate = Color(1, 1, 1, 0.5 * (1.0 - f * 0.5))
		g.z_index = node.z_index - 1
		(parent as Node).add_child(g)
		g.position = from.lerp(to, f)
		var t := g.create_tween()
		t.tween_interval(dur * f)            # appear as the node passes this point
		t.tween_property(g, "modulate:a", 0.0, TRAIL_T)
		t.tween_callback(g.queue_free)

## A small `deg` tilt INTO the horizontal travel direction, righting on arrival — a body-language cue
## that the tile is moving with intent. The sign follows horizontal travel; a pure vertical move has no
## lean. Modelled on feel._move_lean. (apply() already skips this for "arc".)
static func _lean(node: Control, from: Vector2, to: Vector2, dur: float, deg: float) -> void:
	if not (node and is_instance_valid(node)):
		return
	node.pivot_offset = node.size * 0.5 if node.size.x > 0.0 else node.custom_minimum_size * 0.5
	var dir := signf(to.x - from.x)
	if dir == 0.0:
		return   # a pure vertical move has no lean direction
	var lean := deg_to_rad(deg) * dir
	var t := node.create_tween()
	t.tween_property(node, "rotation", lean, dur * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "rotation", 0.0, dur * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
