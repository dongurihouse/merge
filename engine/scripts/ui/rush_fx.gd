extends RefCounted
## Rush screen-juice — a registry of TOGGLEABLE effects for the Expedition Rush. Both the GAME
## (explore_rush.gd) and the WORKBENCH preview (ui_workbench_view "rush_fx") call these. The workbench
## flips the toggles, replays to feel them, and saves to config; the game resolves the saved toggles once
## and gates each call:  var fx = RushFx.from_config(Kit.load_config(Kit.CONFIG_PATH));  if RushFx.on(fx, "merge_burst"): ...
##
## Add a new effect = one row in EFFECTS + a gated call in the game + (optionally) a line in the preview.

const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")

const INK := Color("#43352B")
const GOLD := Color("#FFD166")
const STRAW := Color("#E3B23C")
const LEAF := Color("#7FB069")
const HOT := Color("#E0592B")

# id · label (shown in the workbench) · tip (one-line feel). DEFAULT is on; the config can turn any off.
const EFFECTS := [
	{"id": "merge_burst",    "label": "Merge burst",     "tip": "leaves puff out where two tiles fuse (preview only — live burst comes from Feel.merge)"},
	{"id": "score_tick",     "label": "Score ticks up",  "tip": "the number rolls up instead of snapping"},
	{"id": "score_pulse",    "label": "Score cell pulse","tip": "the score cell pops on a gain"},
	{"id": "mult_pop",       "label": "Mult pop",        "tip": "the medallion pops when the multiplier climbs"},
	{"id": "combo_heat",     "label": "Combo heat",      "tip": "the COMBO callout grows + warms with the streak"},
	{"id": "timer_low",      "label": "Timer urgency",   "tip": "the clock reddens + pulses under 10s"},
	{"id": "treefall_crack", "label": "Treefall crack",  "tip": "the timber lands with debris + a heavier jolt"},
]

# id → default value for the per-effect intensity / feel knobs. The workbench edits these and
# saves them into the same rush_fx config block; the game reads them via from_config + knob().
# Defaults match today's values; the parameterized effect fns (next task) reproduce today's feel at
# these defaults — merge_burst matches the old curve for tiers 1–5 and runs slightly larger at 6–7.
const KNOBS := {
	"merge_burst_count": 20,
	"score_tick_ms": 400,
	"score_pulse_pct": 100,
	"mult_pop_pct": 100,
	"combo_heat_size": 24,
	"timer_low_secs": 10,
	"treefall_debris": 18,
	"treefall_shake": 16,
	"treefall_hitstop_ms": 60,
}

## Read a numeric knob from a resolved opts dict, falling back to its KNOBS default.
static func knob(opts: Dictionary, id: String) -> int:
	return int(opts.get(id, KNOBS.get(id, 0)))

static func defaults() -> Dictionary:
	var d := {"enabled": true}
	for e in EFFECTS:
		d[String(e.id)] = true
	return d

## Resolve the saved toggles over the defaults (the "rush_fx" config block).
static func from_config(cfg: Dictionary) -> Dictionary:
	var r: Dictionary = cfg.get("rush_fx", {}) if cfg is Dictionary else {}
	var d := defaults()
	for k in d.keys():
		if r.has(k):
			d[k] = bool(r[k])
	for k in KNOBS.keys():
		d[k] = int(r.get(k, KNOBS[k]))
	return d

## True when the master switch is on AND this effect is on.
static func on(opts: Dictionary, id: String) -> bool:
	return bool(opts.get("enabled", true)) and bool(opts.get(id, true))

# --- the effects ------------------------------------------------------------------------------------

## WORKBENCH-PREVIEW ONLY. A puff of leaves where two tiles fused; `count` is the base, the result
## tier nudges it. The LIVE Rush merge no longer calls this — its burst (and the tier>=4 flash +
## combo-gated thunk + real merge sound) now come from Feel.merge in explore_rush._merge, gated on
## the global feature flags + calm rather than this RushFx toggle. The `merge_burst` toggle therefore
## only drives the workbench rush_fx preview (ui_workbench_view._rush_fx_play), which still calls this.
static func merge_burst(host: Node, gpos: Vector2, tier: int, count := 20) -> void:
	FX.burst(host, gpos, LEAF, clampi(count + (tier - 3) * 4, 4, 40))

## Roll the score label up to `to_value` over `ms` milliseconds (vs a hard snap).
static func score_tick(label: Label, to_value: int, ms := 400) -> void:
	if label != null and is_instance_valid(label):
		FX.tick(label, to_value, maxf(0.01, ms / 1000.0))

## Pop a cell at `pct` strength (100 = the default squash). Used by score_pulse + mult_pop.
static func cell_pop(cell: Control, pct := 100) -> void:
	if cell != null and is_instance_valid(cell):
		FX.squash_pop(cell, maxf(0.0, pct / 100.0))

## The COMBO callout; `base_size` is the floor, the streak grows it (gold → straw → hot-orange).
static func combo_heat(host: Control, gpos: Vector2, combo: int, base_size := 24) -> void:
	var col := GOLD if combo < 5 else (STRAW if combo < 8 else HOT)
	var sz := clampi(base_size + combo * 3, base_size, base_size + 30)
	FX.floating_text(host, gpos, "COMBO ×%d" % combo, col, sz)

## The clock under `threshold` seconds: redden toward hot + a heartbeat pop. Call once per whole
## second; pass the seconds left. Above the threshold it restores the resting ink colour.
static func timer_low(label: Label, secs_left: int, silent: bool = false, threshold := 10) -> void:
	if label == null or not is_instance_valid(label):
		return
	if secs_left > threshold:
		label.add_theme_color_override("font_color", INK)
		return
	var warm := clampf(float(threshold - secs_left) / float(maxi(1, threshold)), 0.0, 1.0)
	label.add_theme_color_override("font_color", INK.lerp(HOT, warm))
	FX.squash_pop(label)
	if not silent:
		Audio.play("button_tap", -8.0, 1.4 + warm * 0.4)  # a soft rising tick

## The timber LANDS with a crack — debris burst + jolt + a brief freeze, all tunable.
static func treefall_crack(host: Node, board: Control, gpos: Vector2, silent: bool = false, debris := 18, shake_amp := 16.0, hitstop_ms := 60) -> void:
	FX.burst(host, gpos, STRAW, debris)
	FX.shake(board, shake_amp)
	FX.hitstop(maxf(0.0, hitstop_ms / 1000.0))
	if not silent:
		Audio.play("tidy_poof", -1.0, 0.65)                 # low poof = a woody crack
