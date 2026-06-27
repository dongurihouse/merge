extends RefCounted
## The four shared FEEL VERBS — merge / land / launch / move — plus the screen-juice
## helpers (haptic, ripple, board_punch). Each composes the fx.gd primitives and takes an
## `intensity` (0..1) so a surface shares the vocabulary while dialing the strength.
## fx.gd stays the primitive library; scenes call these instead of hand-assembling primitives.

const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").FX

const LEAF := Color("#7FB069")
const STRAW := Color("#E3B23C")
const HOT := Color("#E0592B")

static func merge(host: Node, node: Control, center: Vector2, tier: int, combo: int, intensity := 1.0, hitstop_gate := 0) -> void:
	pass
static func land(host: Node, node: Control, center: Vector2, intensity := 1.0) -> void:
	pass
static func launch(emitter: Control, projectile: Control, intensity := 1.0) -> void:
	pass
static func move(node: Control, from: Vector2, to: Vector2, kind := "slide", dur := -1.0) -> Tween:
	return null
static func haptic(weight := "soft") -> void:
	pass
static func ripple(neighbors: Array, impact_center: Vector2, intensity := 1.0) -> void:
	pass
static func board_punch(board: Control, intensity := 1.0) -> void:
	pass
