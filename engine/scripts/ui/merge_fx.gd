extends RefCounted
## Merge screen-juice — a TOGGLEABLE + tunable registry for the MERGE IMPACT (two tiles fuse: squash
## & stretch + soft flash + the "thunk" hitstop + a leaf/gold/hot burst + shake + merge sound + the
## neighbour ripple + the board punch). Mirrors land_fx.gd: the Merge workbench flips the toggles +
## drags the knobs, replays to FEEL it, and saves to config; the game resolves the saved config once
## and calls MergeFx.apply(...) at each merge.
##
## Add a new merge effect = one row in EFFECTS (+ a knob in KNOBS) + a branch in apply().

const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Feel = preload("res://engine/scripts/ui/feel.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").FX

const LEAF := Color("#7FB069")
const STRAW := Color("#E3B23C")
const HOT := Color("#E0592B")

# id · label (shown in the workbench) · tip (one-line feel). DEFAULT is on; the config can turn any off.
const EFFECTS := [
	{"id": "squash",      "label": "Squash & pop",  "tip": "the produced tile compresses then springs back"},
	{"id": "flash",       "label": "Flash",         "tip": "a soft white pop at the fuse point"},
	{"id": "hitstop",     "label": "Hitstop",       "tip": "a tiny freeze on impact — the \"thunk\""},
	{"id": "burst",       "label": "Burst",         "tip": "leaves/gold/hot particles, escalating by tier"},
	{"id": "shake",       "label": "Shake",         "tip": "a quick screen jolt"},
	{"id": "sound",       "label": "Sound",         "tip": "the merge tone — soft below tier 4, success above"},
	{"id": "ripple",      "label": "Ripple",        "tip": "the orthogonal neighbours jiggle outward"},
	{"id": "board_punch", "label": "Board punch",   "tip": "the whole board pulses up then settles"},
]

# id → default numeric knob. Sliders edit these; apply() reads them via knob().
const KNOBS := {
	"flash_pct": 80,        # flash peak as % of FLASH_PEAK
	"hitstop_ms": 50,       # freeze duration (ms)
	"burst_count": 22,      # base burst particles
	"shake_amp": 7,         # screen jolt amplitude
	"ripple_pct": 60,       # neighbour ripple strength (% of full intensity)
	"punch_pct": 100,       # board punch strength (% of full intensity)
	"pitch_base_pct": 100,  # scales the merge pitch (80–160%)
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

## Resolve the saved toggles + knobs over the defaults (the "merge_fx" config block).
static func from_config(cfg: Dictionary) -> Dictionary:
	var r: Dictionary = cfg.get("merge_fx", {}) if cfg is Dictionary else {}
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

## The merge burst colour ramp, copied from feel._merge_color: tier<4 LEAF green, 4..7 STRAW gold,
## >= 8 HOT.
static func _color(tier: int) -> Color:
	if tier >= 8:
		return HOT
	return STRAW if tier >= 4 else LEAF

## Fire the merge impact per the resolved opts. `node` is the produced tile; `host`/`center` locate
## the flash + burst; `tier`/`combo` drive the escalation; `neighbors`/`board` feed the ripple +
## punch. Every cue is individually toggled + tuned. Null-safe on node/neighbors/board.
static func apply(host: Node, node: Control, center: Vector2, tier: int, combo: int, neighbors: Array, board: Control, opts: Dictionary) -> void:
	if on(opts, "squash"):
		FX.squash_pop(node)
	if on(opts, "flash"):
		var size := node.size.x if node != null and is_instance_valid(node) else 96.0
		FX.flash(host, center, size, Tune.FLASH_PEAK * float(knob(opts, "flash_pct")) / 100.0)
	if on(opts, "hitstop"):
		FX.hitstop(float(knob(opts, "hitstop_ms")) / 1000.0)
	if on(opts, "burst"):
		FX.burst(host, center, _color(tier), knob(opts, "burst_count"))
	if on(opts, "shake"):
		FX.shake(host, float(knob(opts, "shake_amp")))
	if on(opts, "sound"):
		var base_pitch := clampf(0.95 + 0.03 * tier, 0.9, 1.3) * float(knob(opts, "pitch_base_pct")) / 100.0
		Audio.play("merge_success" if tier >= 4 else "merge_soft", -1.0, base_pitch)
	if on(opts, "ripple"):
		Feel.ripple(neighbors, center, float(knob(opts, "ripple_pct")) / 100.0)
	if on(opts, "board_punch"):
		Feel.board_punch(board, float(knob(opts, "punch_pct")) / 100.0)
