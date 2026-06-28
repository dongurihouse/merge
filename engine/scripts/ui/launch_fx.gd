extends RefCounted
## Launch screen-juice — a TOGGLEABLE + tunable registry for the EMIT/LAUNCH (an emitter spits a
## projectile: a generator pops a tile, the Rush board flings one — emitter recoil + muzzle puff +
## toss sound). Mirrors land_fx.gd: the Launch workbench flips the toggles + drags the knobs, replays
## to FEEL it, and saves to config; the game resolves the saved config once and calls
## LaunchFx.apply(...) at each emit.
##
## Add a new launch effect = one row in EFFECTS (+ a knob in KNOBS) + a branch in apply().

const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Feel = preload("res://engine/scripts/ui/feel.gd")

const LEAF := Color("#7FB069")

# id · label (shown in the workbench) · tip (one-line feel). DEFAULT is on; the config can turn any off.
const EFFECTS := [
	{"id": "recoil", "label": "Recoil",     "tip": "the emitter crouches then springs back as it spits the tile"},
	{"id": "puff",   "label": "Muzzle puff", "tip": "a little burst of leaves at the launched tile"},
	{"id": "sound",  "label": "Toss sound", "tip": "a soft drop tick as it leaves the emitter"},
]

# id → default numeric knob. Sliders edit these; apply() reads them via knob().
const KNOBS := {
	"recoil_pct": 100,   # recoil strength gate: >0 = the emitter recoils; 0 = no recoil
	"puff_count": 4,     # muzzle-puff particles
	"sound_db": -5,      # toss sound level (dB; less negative = louder)
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

## Resolve the saved toggles + knobs over the defaults (the "launch_fx" config block).
static func from_config(cfg: Dictionary) -> Dictionary:
	var r: Dictionary = cfg.get("launch_fx", {}) if cfg is Dictionary else {}
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

## Fire the emit per the resolved opts. `emitter` is the node that spat the tile (recoils); `projectile`
## is the launched tile; `center` locates the muzzle puff. `intensity` (0..1) scales the muzzle-puff
## count (0 emits no puff). Mirrors feel.launch but every cue is individually toggled + tuned. Null-safe
## on both nodes. Also fires the launch HAPTIC ("tick") — the tactile cue feel.launch threw.
static func apply(emitter: Control, projectile: Control, center: Vector2, opts: Dictionary, intensity := 1.0) -> void:
	if on(opts, "recoil") and knob(opts, "recoil_pct") > 0 and emitter != null and is_instance_valid(emitter):
		FX.gen_charge(emitter)
	if on(opts, "puff") and intensity > 0.0 and projectile != null and is_instance_valid(projectile):
		var host := projectile.get_parent()
		if host is Node:
			FX.burst(host, center, LEAF, int(round(knob(opts, "puff_count") * intensity)))
	if on(opts, "sound"):
		Audio.play("item_drop", float(knob(opts, "sound_db")), 1.1)
	Feel.haptic("tick")
