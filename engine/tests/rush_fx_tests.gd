extends SceneTree
## Headless tests for engine/scripts/ui/rush_fx.gd — the rush screen-juice registry: knob
## defaults/overrides, the knob() reader, and each effect honouring its tuning param.
##   godot --headless --path . -s res://engine/tests/rush_fx_tests.gd

const RushFx = preload("res://engine/scripts/ui/rush_fx.gd")

var _pass := 0
var _fail := 0
func ok(cond: bool, label: String) -> void:
	if cond: _pass += 1; print("  PASS  ", label)
	else: _fail += 1; print("  FAIL  ", label)

func _initialize() -> void:
	# defaults: from_config with no rush_fx block returns every knob at its KNOBS default
	var d := RushFx.from_config({})
	ok(int(d.get("merge_burst_count", -1)) == RushFx.KNOBS["merge_burst_count"], "from_config: merge_burst_count defaults")
	ok(int(d.get("treefall_shake", -1)) == RushFx.KNOBS["treefall_shake"], "from_config: treefall_shake defaults")
	ok(bool(d.get("enabled", false)), "from_config: master enabled still defaults on")
	# overrides: a saved value wins
	var o := RushFx.from_config({"rush_fx": {"merge_burst_count": 7, "treefall_hitstop_ms": 120}})
	ok(int(o["merge_burst_count"]) == 7, "from_config: saved knob overrides the default")
	ok(int(o["treefall_hitstop_ms"]) == 120, "from_config: saved treefall_hitstop_ms overrides")
	ok(int(o["combo_heat_size"]) == RushFx.KNOBS["combo_heat_size"], "from_config: unmentioned knob keeps its default")
	# knob() reader
	ok(RushFx.knob(o, "merge_burst_count") == 7, "knob(): reads a present value")
	ok(RushFx.knob({}, "timer_low_secs") == RushFx.KNOBS["timer_low_secs"], "knob(): falls back to KNOBS default")
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
