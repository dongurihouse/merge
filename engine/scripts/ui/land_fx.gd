extends RefCounted
## Land screen-juice — a TOGGLEABLE + tunable registry for the TILE-LANDING impact (a tile that
## travelled then touches down: squash + dust puff + soft flash + touch sound + haptic + a neighbour
## ripple). The board now routes the player's plain drop-into-empty-cell through this too. Mirrors
## rush_fx.gd: the Land workbench flips the toggles + drags the knobs, replays to FEEL it, and saves
## to config; the game resolves the saved config once and calls LandFx.apply(...) at each landing.
##
## Add a new land effect = one row in EFFECTS (+ a knob in KNOBS) + a branch in apply().

const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Feel = preload("res://engine/scripts/ui/feel.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").FX

const LEAF := Color("#7FB069")

# id · label (shown in the workbench) · tip (one-line feel). DEFAULT is on; the config can turn any off.
const EFFECTS := [
	{"id": "squash", "label": "Squash",      "tip": "the tile compresses then springs back on touchdown"},
	{"id": "puff",   "label": "Dust puff",   "tip": "a little burst of dust where it lands"},
	{"id": "flash",  "label": "Flash",       "tip": "a soft white pop at the contact point"},
	{"id": "sound",  "label": "Touch sound", "tip": "a soft woody tap"},
	{"id": "haptic", "label": "Haptic",      "tip": "a light tap on the device (no effect on desktop)"},
	{"id": "ripple", "label": "Ripple",      "tip": "the orthogonal neighbours bump outward from the landing"},
]

# id → default numeric knob. Sliders edit these; apply() reads them via knob().
const KNOBS := {
	"squash_pct": 100,   # squash strength: 100 = a 1.20/0.80 impact pose; 0 = none, 200 = double
	"squash_ms": 240,    # squash total duration (ms) — bigger = a slower, weightier settle
	"puff_count": 7,     # dust particles
	"flash_pct": 45,     # flash peak as % of FLASH_PEAK
	"sound_db": -4,      # touch sound level (dB; less negative = louder)
	"ripple_pct": 60,    # neighbour bump strength (% of full intensity)
}

static func knob(opts: Dictionary, id: String) -> int:
	return int(opts.get(id, KNOBS.get(id, 0)))

static func defaults() -> Dictionary:
	var d := {"enabled": true}
	for e in EFFECTS:
		d[String(e.id)] = true
	for k in KNOBS.keys():
		d[k] = KNOBS[k]
	return d

## Resolve the saved toggles + knobs over the defaults (the "land_fx" config block).
static func from_config(cfg: Dictionary) -> Dictionary:
	var r: Dictionary = cfg.get("land_fx", {}) if cfg is Dictionary else {}
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

## Fire the landing impact per the resolved opts. `node` is the arriving tile; `host`/`center`
## locate the puff + flash. Mirrors feel.land but every cue is individually toggled + tuned.
## `intensity` (0..1) scales the squash deviation; `quiet` (a bulk/gravity settle) suppresses the
## per-tile SOUND, flash, haptic, and neighbour ripple — but the SQUASH still fires and the dust puff
## still fires whenever intensity > 0 (the cheap visual touchdown), so a settling column still visibly
## thumps without machine-gunning N sounds/flashes/pulses/ripples. Mirrors feel.land's quiet behaviour.
## `neighbors` is the orthogonal tiles to bump on a discrete landing (empty = no ripple — e.g. a spawn or
## a bulk settle that passes none); the scene gathers them (board.gd → _orthogonal_neighbour_nodes).
static func apply(host: Node, node: Control, center: Vector2, opts: Dictionary, intensity := 1.0, quiet := false, neighbors := []) -> void:
	if on(opts, "squash"):
		_squash(node, int(round(knob(opts, "squash_pct") * intensity)), knob(opts, "squash_ms"))
	# the dust puff reads the touchdown — fires even on a quiet bulk settle (it's the SOUND/flash we dedupe)
	if on(opts, "puff") and intensity > 0.0:
		FX.burst(host, center, LEAF, knob(opts, "puff_count"))
	if quiet:
		return
	# discrete (loud) landing only: the soft flash + touch sound + haptic + the neighbour ripple
	if on(opts, "flash"):
		var size := node.size.x if node != null and is_instance_valid(node) else 96.0
		FX.flash(host, center, size, Tune.FLASH_PEAK * float(knob(opts, "flash_pct")) / 100.0)
	if on(opts, "sound"):
		Audio.play("tidy_poof", float(knob(opts, "sound_db")), 1.0)
	if on(opts, "haptic"):
		Feel.haptic("soft")
	# the orthogonal neighbours BUMP outward from the touchdown — the same impact-propagation verb the
	# merge uses, driven by the neighbour list the caller passes (empty = no bump).
	if on(opts, "ripple") and not neighbors.is_empty():
		Feel.ripple(neighbors, center, float(knob(opts, "ripple_pct")) / 100.0 * intensity)

## The tunable impact squash: compress to (1+a, 1-a), counter-stretch to (1-b, 1+b), settle to rest.
## `pct` scales the deviation `a`; `ms` is the total duration split across the two legs.
static func _squash(node: Control, pct: int, ms: int) -> void:
	if not (node and is_instance_valid(node)):
		return
	node.pivot_offset = (node.size / 2.0) if node.size.x > 0.0 else (node.custom_minimum_size / 2.0)
	var a := 0.20 * float(pct) / 100.0       # impact deviation (wide+short)
	var b := a * 0.45                          # counter-stretch (tall+narrow)
	var t1 := maxf(0.02, float(ms) / 1000.0 * 0.4)
	var t2 := maxf(0.02, float(ms) / 1000.0 * 0.6)
	node.scale = Vector2(1.0 + a, 1.0 - a)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.0 - b, 1.0 + b), t1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, t2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
