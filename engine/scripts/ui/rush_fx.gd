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
	{"id": "merge_burst",    "label": "Merge burst",     "tip": "leaves puff out where two tiles fuse"},
	{"id": "score_tick",     "label": "Score ticks up",  "tip": "the number rolls up instead of snapping"},
	{"id": "score_pulse",    "label": "Score cell pulse","tip": "the score cell pops on a gain"},
	{"id": "mult_pop",       "label": "Mult pop",        "tip": "the medallion pops when the multiplier climbs"},
	{"id": "combo_heat",     "label": "Combo heat",      "tip": "the COMBO callout grows + warms with the streak"},
	{"id": "timer_low",      "label": "Timer urgency",   "tip": "the clock reddens + pulses under 10s"},
	{"id": "treefall_crack", "label": "Treefall crack",  "tip": "the timber lands with debris + a heavier jolt"},
]

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
	return d

## True when the master switch is on AND this effect is on.
static func on(opts: Dictionary, id: String) -> bool:
	return bool(opts.get("enabled", true)) and bool(opts.get(id, true))

# --- the effects ------------------------------------------------------------------------------------

## A puff of leaves where two tiles fused; bigger for a higher result tier.
static func merge_burst(host: Node, gpos: Vector2, tier: int) -> void:
	FX.burst(host, gpos, LEAF, clampi(8 + tier * 4, 8, 28))

## Roll the score label up to `to_value` (vs a hard snap).
static func score_tick(label: Label, to_value: int) -> void:
	if label != null and is_instance_valid(label):
		FX.tick(label, to_value)

## Pop a cell (used for the score cell on a gain, and the mult medallion when it climbs).
static func cell_pop(cell: Control) -> void:
	if cell != null and is_instance_valid(cell):
		FX.squash_pop(cell)

## The COMBO callout, growing + warming with the streak (gold → straw → hot-orange).
static func combo_heat(host: Control, gpos: Vector2, combo: int) -> void:
	var col := GOLD if combo < 5 else (STRAW if combo < 8 else HOT)
	var sz := clampi(24 + combo * 3, 24, 54)
	FX.floating_text(host, gpos, "COMBO ×%d" % combo, col, sz)

## The clock under ~10s: redden toward hot + a heartbeat pop. Call once per WHOLE second; pass the
## seconds left. At >10s it restores the resting ink colour, so it can be called unconditionally.
static func timer_low(label: Label, secs_left: int, silent: bool = false) -> void:
	if label == null or not is_instance_valid(label):
		return
	if secs_left > 10:
		label.add_theme_color_override("font_color", INK)
		return
	var warm := clampf(float(10 - secs_left) / 10.0, 0.0, 1.0)
	label.add_theme_color_override("font_color", INK.lerp(HOT, warm))
	FX.squash_pop(label)
	if not silent:
		Audio.play("button_tap", -8.0, 1.4 + warm * 0.4)    # a soft rising tick

## The timber LANDS with a crack — debris burst + a heavier jolt + a brief freeze.
static func treefall_crack(host: Node, board: Control, gpos: Vector2, silent: bool = false) -> void:
	FX.burst(host, gpos, STRAW, 18)
	FX.shake(board, 16.0)
	FX.hitstop(0.06)
	if not silent:
		Audio.play("tidy_poof", -1.0, 0.65)                 # low poof = a woody crack
