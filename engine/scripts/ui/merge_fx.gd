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
const Strings = preload("res://engine/scripts/core/strings.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").FX

const LEAF := Color("#7FB069")
const STRAW := Color("#E3B23C")
const HOT := Color("#E0592B")
const PETAL := Color("#D98BA3")        # the pink petal puff — resolves to p_petal via FX._pick_tex

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
	{"id": "world_puff",  "label": "World puff",    "tip": "a little puff of petals scatters from the fuse"},
	{"id": "combo_words", "label": "Combo words",   "tip": "Nice / Lovely / Wonderful at a streak milestone"},
	{"id": "combo_bloom", "label": "Combo bloom",   "tip": "a warm screen glow swells with the streak"},
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
	"puff_count": 8,        # petals flung outward by the world puff
	"puff_size_pct": 120,   # world-puff petal sprite size (% of the grove burst scale)
	"words_size": 30,       # milestone word font size
	"bloom_pct": 100,       # combo-bloom rise strength (% — scaled at the call site)
	"merge_slide_ms": 130,  # pre-impact loser-tile snap duration (board + Workbench preview)
}

static func knob(opts: Dictionary, id: String) -> int:
	return int(opts.get(id, KNOBS.get(id, 0)))

# shake + board_punch fire on EVERY merge when on; the cozy design reserves them for big moments,
# so they default OFF (opt-in via the workbench). The rest of the cues default on.
const DEFAULT_OFF := ["shake", "board_punch"]

static func defaults() -> Dictionary:
	var d := {"enabled": true}
	for e in EFFECTS:
		d[String(e.id)] = not (String(e.id) in DEFAULT_OFF)
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

## The tier the escalation (colour / chime / haptic) reads off. An INTENSIFIED merge — a §6.G recipe-line
## merge (T63) — should feel like a pinnacle merge at ANY tier, so we lift the read-off tier to the
## big-moment band (ESCALATE_TIER == the HOT/PREMIUM pinnacle, 8) while NEVER dropping a real high-tier
## merge below itself. An ordinary merge reads off its own tier unchanged. (feel_tests asserts the lift
## composes to HOT colour + heavy weight + the success-chime threshold, so this stays correct if the
## constant ever moves.)
static func escalation_tier(tier: int, intensified: bool) -> int:
	return maxi(tier, Tune.ESCALATE_TIER) if intensified else tier

## Whether the RESERVED big-moment cues (shake + board punch) fire for this merge. They default OFF (the
## cozy design reserves them), but an INTENSIFIED merge forces them on — still respecting the merge master
## switch, so a fully-disabled merge-FX stays silent (T63).
static func big_cue_forced(opts: Dictionary, intensified: bool) -> bool:
	return intensified and bool(opts.get("enabled", true))

## Fire the merge impact per the resolved opts. `node` is the produced tile; `host`/`center` locate
## the flash + burst; `tier`/`combo` drive the escalation; `neighbors`/`board` feed the ripple +
## punch. `intensity` (0..1) scales the flash peak, burst count, shake amp, ripple, and board punch
## (a spirit-merge passes a low intensity); `hitstop_gate` suppresses the freeze when `combo` sits
## below the gate (a low-combo merge stays snappy), else the freeze fires scaled by intensity. The
## sound always plays when toggled on. Every cue is individually toggled + tuned. Null-safe on
## node/neighbors/board. Also fires the merge HAPTIC (preserving feel.merge's tactile cue) — gated
## on the sound toggle so a fully-muted merge has no buzz either.
static func apply(host: Node, node: Control, center: Vector2, tier: int, combo: int, neighbors: Array, board: Control, opts: Dictionary, intensity := 1.0, hitstop_gate := 0, intensified := false) -> void:
	# T63: an INTENSIFIED merge (a §6.G recipe-line merge) feels like a pinnacle merge at any tier — the
	# colour/chime/haptic read off the lifted `eff` tier, and the reserved shake + board punch are forced on.
	var eff := escalation_tier(tier, intensified)
	var force_big := big_cue_forced(opts, intensified)
	if on(opts, "squash"):
		FX.squash_pop(node)
	if on(opts, "flash"):
		var size := node.size.x if node != null and is_instance_valid(node) else 96.0
		FX.flash(host, center, size, Tune.FLASH_PEAK * float(knob(opts, "flash_pct")) / 100.0 * intensity)
	if on(opts, "hitstop"):
		# the "thunk" — ZERO below the combo gate (keeps low-combo merges snappy), else scaled by intensity.
		var hs := 0.0 if combo < hitstop_gate else float(knob(opts, "hitstop_ms")) / 1000.0 * intensity
		if hs > 0.0:
			FX.hitstop(hs)
	if on(opts, "burst"):
		FX.burst(host, center, _color(eff), int(round(knob(opts, "burst_count") * intensity)))
	if on(opts, "shake") or force_big:
		FX.shake(host, float(knob(opts, "shake_amp")) * intensity)
	if on(opts, "sound"):
		var base_pitch := clampf(0.95 + 0.03 * eff, 0.9, 1.3) * float(knob(opts, "pitch_base_pct")) / 100.0
		Audio.play("merge_success" if eff >= 4 else "merge_soft", -1.0, base_pitch)
		Feel.haptic(_weight(eff))   # the tactile spine feel.merge fired — weight ladders by tier
	if on(opts, "ripple"):
		Feel.ripple(neighbors, center, float(knob(opts, "ripple_pct")) / 100.0 * intensity)
	if on(opts, "board_punch") or force_big:
		Feel.board_punch(board, float(knob(opts, "punch_pct")) / 100.0 * intensity)
	# the WORLD REACTION puff: the ambient layer recoils from the fuse as a small grove-scale petal
	# burst (NOT the old 64–115px Ambient.puff motes — this is a normal FX.burst sized by puff_size_pct).
	if on(opts, "world_puff"):
		FX.burst(host, center, PETAL, int(round(knob(opts, "puff_count") * intensity)), knob(opts, "puff_size_pct"))
	# the milestone shout — only at an EXACT streak milestone (3/5/8), the cozy word, never a "COMBO xN".
	if on(opts, "combo_words"):
		var idx: int = Tune.COMBO_MILESTONES.find(combo)
		if idx >= 0:
			var key: String = ["combo_nice", "combo_lovely", "combo_wonderful"][mini(idx, 2)]
			FX.floating_text(host, center - Vector2(20, 50), Strings.t("board.feedback." + key), STRAW, knob(opts, "words_size"))
	# combo_bloom is a PERSISTENT overlay (ComboBloom), not a one-shot — the CALL SITE gates + scales it
	# (board.gd gates _combo_bloom.bump on this toggle, scaled by bloom_pct). Nothing fires here.

## Haptic weight ladder copied from feel._merge_weight: heavy at the big-moment tier, firm at 4..7,
## soft below.
static func _weight(tier: int) -> String:
	if tier >= Tune.ESCALATE_TIER:
		return "heavy"
	return "firm" if tier >= 4 else "soft"
