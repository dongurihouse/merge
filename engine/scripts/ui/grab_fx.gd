extends RefCounted
## Grab screen-juice — a TOGGLEABLE + tunable registry for the PICK-UP moment (an item or generator is
## grabbed and lifts off the board): a GLOW tint + a white silhouette OUTLINE on the held tile + a light
## HAPTIC tap. Mirrors land_fx.gd / merge_fx.gd: the Grab workbench flips the toggles + drags the knobs,
## ▶ to feel it, saves to config; the game resolves the saved config once and calls GrabFx.grab(...) on
## pickup + GrabFx.release(...) on drop.
##
## Unlike the one-shot merge/land verbs, the highlight is a SUSTAINED state — grab() turns it on,
## release() takes it off (the board calls release in _clear_drag_feel, the shared drag-end chokepoint
## every drop path runs through). Both are null-safe + idempotent.
##
## Add a new grab effect = one row in EFFECTS (+ a knob in KNOBS) + a branch in grab()/release().

const Feel = preload("res://engine/scripts/ui/feel.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")

# The brighten the glow tint reaches at glow_pct = 100 — the SAME warm value the merge telegraph uses
# (board.gd TELEGRAPH_GLOW), so a held tile reads consistently with a telegraphed merge target.
const GRAB_GLOW := Color(1.15, 1.15, 1.05, 1.0)
const OUTLINE_COLOR := Color(1, 1, 1, 1)   # a white rim

# id · label (shown in the workbench) · tip (one-line feel). DEFAULT is on; the config can turn any off.
const EFFECTS := [
	{"id": "glow",    "label": "Glow",    "tip": "the held tile brightens while you hold it"},
	{"id": "outline", "label": "Outline", "tip": "a white rim traces the held tile's silhouette"},
	{"id": "haptic",  "label": "Haptic",  "tip": "a light tap on the device on pickup (no effect on desktop)"},
]

# id → default numeric knob. Sliders edit these; grab() reads them via knob().
const KNOBS := {
	"glow_pct":    100,   # glow strength: 100 = the telegraph glow; 0 = none, 200 = double the brighten
	"outline_w":   4,     # white rim thickness (% of cell)
	"outline_a":   90,    # white rim opacity (%)
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

## Resolve the saved toggles + knobs over the defaults (the "grab_fx" config block).
static func from_config(cfg: Dictionary) -> Dictionary:
	var r: Dictionary = cfg.get("grab_fx", {}) if cfg is Dictionary else {}
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

## Turn the grab highlight ON + fire the pickup haptic. `node` is the held holder (a PieceView piece or
## generator). Null-safe. SUSTAINED: call release(node) on drop to clear it. Each cue is toggled + tuned.
static func grab(node: Control, opts: Dictionary) -> void:
	if node == null or not is_instance_valid(node):
		return
	if on(opts, "glow"):
		# brighten the held tile toward GRAB_GLOW, scaled by glow_pct (>100 extrapolates brighter).
		node.modulate = Color.WHITE.lerp(GRAB_GLOW, float(knob(opts, "glow_pct")) / 100.0)
	if on(opts, "outline"):
		PieceView.add_grab_outline(node, OUTLINE_COLOR, float(knob(opts, "outline_w")) / 100.0, float(knob(opts, "outline_a")) / 100.0)
	if on(opts, "haptic"):
		Feel.haptic("tick")   # the lightest weight — a brief pickup tap (no-op on desktop/headless)

## Take the grab highlight OFF (restore the modulate, drop the rim). Null-safe + idempotent (safe even
## if grab() never ran). The board calls this from _clear_drag_feel — the shared drag-end chokepoint.
static func release(node: Control) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.modulate = Color.WHITE
	PieceView.clear_grab_outline(node)
