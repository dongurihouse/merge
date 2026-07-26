extends "res://engine/tests/test_base.gd"
## Headless tests for the SHARED FX save/load contract (engine/scripts/ui/fx_config.gd) and its six
## registries: grab_fx, land_fx, launch_fx, move_fx, merge_fx, rush_fx.
##   godot --headless -s res://engine/tests/fx_config_tests.gd
##
## What is actually at risk here: the FX gallery writes all six config blocks from ONE Save button, and
## each registry resolves its own block back on load. A registry pointed at the wrong block name — or
## one whose defaults/knob merge drifts from its siblings — silently serves defaults, so the workbench
## slider you dragged does nothing in the game and nothing fails until playtest.
##
## The BLOCK NAMES BELOW ARE HARD-CODED ON PURPOSE. They are the test's independent statement of the
## contract; reading them back off the registry would make the wrong-block bug invisible. The
## round-trip fixture also loads ALL SIX blocks at once with DISTINCT values, so a registry reading a
## *sibling's* block (land/launch/merge all declare `puff_count`) fails too.

const GrabFx = preload("res://engine/scripts/ui/grab_fx.gd")
const LandFx = preload("res://engine/scripts/ui/land_fx.gd")
const LaunchFx = preload("res://engine/scripts/ui/launch_fx.gd")
const MoveFx = preload("res://engine/scripts/ui/move_fx.gd")
const MergeFx = preload("res://engine/scripts/ui/merge_fx.gd")
const RushFx = preload("res://engine/scripts/ui/rush_fx.gd")
const FxConfig = preload("res://engine/scripts/ui/fx_config.gd")

# One row per registry: the config block name (hard-coded, see above), the four entry points as
# Callables, its EFFECTS/KNOBS, and the effect ids expected to default OFF.
func _registries() -> Array:
	return [
		{"block": "grab_fx", "effects": GrabFx.EFFECTS, "knobs": GrabFx.KNOBS, "off": [],
			"defaults": GrabFx.defaults, "from_config": GrabFx.from_config, "knob": GrabFx.knob, "on": GrabFx.on},
		{"block": "land_fx", "effects": LandFx.EFFECTS, "knobs": LandFx.KNOBS, "off": [],
			"defaults": LandFx.defaults, "from_config": LandFx.from_config, "knob": LandFx.knob, "on": LandFx.on},
		{"block": "launch_fx", "effects": LaunchFx.EFFECTS, "knobs": LaunchFx.KNOBS, "off": [],
			"defaults": LaunchFx.defaults, "from_config": LaunchFx.from_config, "knob": LaunchFx.knob, "on": LaunchFx.on},
		{"block": "move_fx", "effects": MoveFx.EFFECTS, "knobs": MoveFx.KNOBS, "off": [],
			"defaults": MoveFx.defaults, "from_config": MoveFx.from_config, "knob": MoveFx.knob, "on": MoveFx.on},
		{"block": "merge_fx", "effects": MergeFx.EFFECTS, "knobs": MergeFx.KNOBS, "off": ["shake", "board_punch"],
			"defaults": MergeFx.defaults, "from_config": MergeFx.from_config, "knob": MergeFx.knob, "on": MergeFx.on},
		{"block": "rush_fx", "effects": RushFx.EFFECTS, "knobs": RushFx.KNOBS, "off": [],
			"defaults": RushFx.defaults, "from_config": RushFx.from_config, "knob": RushFx.knob, "on": RushFx.on},
	]

# The saved value this fixture writes for knob `k` of registry #`i`. Offsetting by the registry index
# keeps every value distinct ACROSS blocks, so reading a sibling's block is a failure, not a coincidence.
func _saved_knob(i: int, knobs: Dictionary, k: String) -> int:
	return int(knobs[k]) + 101 + i

# The whole settings file as the FX gallery's Save would leave it: all six blocks, every knob moved off
# its default, the first effect of each registry switched OFF and every default-off effect switched ON.
func _fixture(regs: Array) -> Dictionary:
	var cfg := {}
	for i in regs.size():
		var r: Dictionary = regs[i]
		var knobs: Dictionary = r["knobs"]
		var blk := {}
		for k in knobs.keys():
			blk[k] = _saved_knob(i, knobs, k)
		blk[String((r["effects"] as Array)[0].id)] = false
		for off_id in r["off"]:
			blk[String(off_id)] = true
		cfg[r["block"]] = blk
	return cfg

func _initialize() -> void:
	print("== FX config contract tests ==")
	var regs := _registries()
	ok(regs.size() == 6, "six FX registries under test")
	_test_defaults(regs)
	_test_round_trip(regs)
	_test_missing_keys_keep_defaults(regs)
	_test_master_switch(regs)
	_test_knob_fallback(regs)
	_test_int_contract()
	finish()

## Every registry's unsaved baseline: master on, effects on except its declared default-off set,
## and every knob present at its KNOBS value.
func _test_defaults(regs: Array) -> void:
	for r in regs:
		var blk: String = r["block"]
		var d: Dictionary = (r["defaults"] as Callable).call()
		ok(bool(d.get("enabled", false)), "%s: defaults() master switch is on" % blk)
		var toggles_right := true
		for e in r["effects"]:
			var id := String(e.id)
			if bool(d.get(id, false)) != not (id in r["off"]):
				toggles_right = false
		ok(toggles_right, "%s: defaults() effect toggles match the declared default-off set" % blk)
		var knobs: Dictionary = r["knobs"]
		var knobs_right := true
		for k in knobs.keys():
			if not d.has(k) or d[k] != knobs[k]:
				knobs_right = false
		ok(knobs_right, "%s: defaults() carries every knob at its KNOBS value" % blk)

## THE CONTRACT AT RISK: a saved block written by the FX gallery must come back out of from_config.
## All six blocks are present in the one config dict, exactly as the settings file holds them.
func _test_round_trip(regs: Array) -> void:
	var cfg := _fixture(regs)
	for i in regs.size():
		var r: Dictionary = regs[i]
		var blk: String = r["block"]
		var knobs: Dictionary = r["knobs"]
		var opts: Dictionary = (r["from_config"] as Callable).call(cfg)
		var knob: Callable = r["knob"]

		var bad := []
		for k in knobs.keys():
			if knob.call(opts, k) != _saved_knob(i, knobs, k):
				bad.append("%s(got %d want %d)" % [k, knob.call(opts, k), _saved_knob(i, knobs, k)])
		ok(bad.is_empty(), "%s: every saved knob reads back (%d knobs)%s" % [blk, knobs.size(), "" if bad.is_empty() else " — wrong: " + ", ".join(bad)])

		# the saved OFF toggle survives…
		var first := String((r["effects"] as Array)[0].id)
		ok(not bool(opts.get(first, true)), "%s: saved OFF toggle '%s' reads back off" % [blk, first])
		ok(not (r["on"] as Callable).call(opts, first), "%s: on() honours the saved OFF toggle" % blk)

		# …and so does an explicit ON for an effect that DEFAULTS off (merge_fx shake / board_punch).
		for off_id in r["off"]:
			ok((r["on"] as Callable).call(opts, String(off_id)), "%s: default-off '%s' reads back ON when saved on" % [blk, off_id])

		# the untouched effects stayed at their defaults.
		var rest_ok := true
		for e in r["effects"]:
			var id := String(e.id)
			if id == first or id in r["off"]:
				continue
			if not bool(opts.get(id, false)):
				rest_ok = false
		ok(rest_ok, "%s: effects the block did not mention keep their defaults" % blk)

## An EMPTY config (and a config whose block is present but bare) must resolve exactly to defaults —
## this is what a fresh install and a pre-existing save with a newly added cue both look like.
func _test_missing_keys_keep_defaults(regs: Array) -> void:
	for r in regs:
		var blk: String = r["block"]
		var d: Dictionary = (r["defaults"] as Callable).call()
		var from_empty: Dictionary = (r["from_config"] as Callable).call({})
		ok(from_empty == d, "%s: an empty config resolves to defaults()" % blk)
		var from_bare: Dictionary = (r["from_config"] as Callable).call({blk: {}})
		ok(from_bare == d, "%s: an empty saved block resolves to defaults()" % blk)
		# a block belonging to somebody else must not leak in.
		var other := "merge_fx" if blk != "merge_fx" else "land_fx"
		var from_other: Dictionary = (r["from_config"] as Callable).call({other: {"enabled": false}})
		ok(bool(from_other.get("enabled", false)), "%s: another registry's block does not reach it" % blk)

## The master switch gates every effect regardless of its own toggle.
func _test_master_switch(regs: Array) -> void:
	for r in regs:
		var blk: String = r["block"]
		var opts: Dictionary = (r["from_config"] as Callable).call({blk: {"enabled": false}})
		var all_off := true
		for e in r["effects"]:
			if (r["on"] as Callable).call(opts, String(e.id)):
				all_off = false
		ok(all_off, "%s: master switch off silences every effect" % blk)
		# …and the knobs still resolve (the appliers read them even while gated).
		var knobs: Dictionary = r["knobs"]
		var kept := true
		for k in knobs.keys():
			if (r["knob"] as Callable).call(opts, k) != int(knobs[k]):
				kept = false
		ok(kept, "%s: knobs still resolve while the master switch is off" % blk)

## knob() falls back to the registry's KNOBS default for a key the opts dict never got, and to 0 for a
## key no registry declares.
func _test_knob_fallback(regs: Array) -> void:
	for r in regs:
		var blk: String = r["block"]
		var knobs: Dictionary = r["knobs"]
		var knob: Callable = r["knob"]
		var fell_back := true
		for k in knobs.keys():
			if knob.call({}, k) != int(knobs[k]):
				fell_back = false
		ok(fell_back, "%s: knob() falls back to the KNOBS default on a bare opts dict" % blk)
		ok(knob.call({}, "no_such_knob_at_all") == 0, "%s: knob() returns 0 for an undeclared id" % blk)

## The int() coercion is the CURRENT contract: a fractional saved value truncates. Asserted so that
## widening fx_config.from_config to floats is a deliberate, visible decision rather than a silent one
## — if you change it, this is the test that tells you what you changed.
func _test_int_contract() -> void:
	var effects := [{"id": "thing", "label": "Thing", "tip": "t"}]
	var knobs := {"amount_pct": 50}
	var got := FxConfig.from_config({"probe_fx": {"amount_pct": 2.9}}, "probe_fx", effects, knobs)
	ok(int(got["amount_pct"]) == 2, "from_config truncates a fractional knob to int (2.9 -> 2)")
	ok(typeof(got["amount_pct"]) == TYPE_INT, "resolved knobs are ints")
	# a default_off id is honoured for any registry that declares one.
	var off := FxConfig.defaults(effects, knobs, ["thing"])
	ok(not bool(off["thing"]), "defaults() honours default_off")
	ok(bool(FxConfig.defaults(effects, knobs)["thing"]), "defaults() leaves effects on when default_off is empty")
