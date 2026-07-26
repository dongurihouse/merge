extends RefCounted
## The SAVE/LOAD CONTRACT shared by every workbench-tuned FX registry (grab_fx, land_fx, launch_fx,
## move_fx, merge_fx, rush_fx). Each registry owns its own EFFECTS list, KNOBS defaults and config
## BLOCK NAME; the four functions that turn those into a resolved opts dict live HERE, once.
##
## The shape every registry produces:
##   {"enabled": true, <effect id>: bool, …, <knob id>: int, …}
## `enabled` is the master switch; each effect id is a toggle; each knob id is a number. The FX gallery
## (games/grove/tools/fx_gallery_view.gd) writes all six blocks from one Save button, so a divergence
## between two registries is invisible until playtest — that is why this is one module and not six
## copies. engine/tests/fx_config_tests.gd asserts the round-trip for all six.
##
## Wiring a registry up is four one-line forwarders:
##   static func knob(opts: Dictionary, id: String) -> int:  return FxConfig.knob(opts, id, KNOBS)
##   static func defaults() -> Dictionary:                    return FxConfig.defaults(EFFECTS, KNOBS)
##   static func from_config(cfg: Dictionary) -> Dictionary:  return FxConfig.from_config(cfg, "x_fx", EFFECTS, KNOBS)
##   static func on(opts: Dictionary, id: String) -> bool:    return FxConfig.on(opts, id)
##
## KNOWN LIMIT — knob values are forced through int(). A saved 2.9 resolves to 2, so a registry cannot
## currently declare a fractional knob (an alpha, a scale, a seconds value) without scaling it to an
## integer percent first, which is why the knob names read *_pct / *_ms. That is the CURRENT contract,
## deliberately unchanged here. Widening it to floats is a real behaviour change (every saved block and
## every workbench slider participates) and deserves its own decision — but it is now a change to ONE
## function instead of six.

## The unsaved baseline: master switch on, every effect on except the ids in `default_off`, every knob
## at its declared default. `effects` is a registry's EFFECTS (rows of {"id": …, "label": …, "tip": …}).
static func defaults(effects: Array, knobs: Dictionary, default_off: Array = []) -> Dictionary:
	var d := {"enabled": true}
	for e in effects:
		var id := String(e.id)
		d[id] = not (id in default_off)
	for k in knobs.keys():
		d[k] = knobs[k]
	return d

## Resolve the saved `block` of `cfg` over those defaults. Only keys the block actually carries
## override; anything missing (a new effect added after the block was last saved, a knob the workbench
## never wrote) keeps its default, so an old saved config never blanks a new cue.
static func from_config(cfg: Dictionary, block: String, effects: Array, knobs: Dictionary, default_off: Array = []) -> Dictionary:
	var r: Dictionary = cfg.get(block, {}) if cfg is Dictionary else {}
	var d := defaults(effects, knobs, default_off)
	for e in effects:
		var id := String(e.id)
		if r.has(id):
			d[id] = bool(r[id])
	if r.has("enabled"):
		d["enabled"] = bool(r["enabled"])
	for k in knobs.keys():
		d[k] = int(r.get(k, knobs[k]))   # see the int() note in the module docstring
	return d

## Read a numeric knob from a resolved opts dict, falling back to the registry's KNOBS default.
static func knob(opts: Dictionary, id: String, knobs: Dictionary) -> int:
	return int(opts.get(id, knobs.get(id, 0)))

## True when the master switch is on AND this effect is on.
static func on(opts: Dictionary, id: String) -> bool:
	return bool(opts.get("enabled", true)) and bool(opts.get(id, true))
