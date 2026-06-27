extends SceneTree
## Headless tests for engine/scripts/ui/rush_fx.gd — the rush screen-juice registry: knob
## defaults/overrides, the knob() reader, and each effect honouring its tuning param.
##   godot --headless --path . -s res://engine/tests/rush_fx_tests.gd

const RushFx = preload("res://engine/scripts/ui/rush_fx.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Save = preload("res://engine/scripts/core/save.gd")

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
	# effects honour their params. Enable the gating flags + non-calm so the effect bodies run.
	Save.set_setting("calm", false)
	Features.FLAGS["celebrate_bursts"] = true
	# merge_burst: count + (tier-3)*4 → at count 20, tier 3 == 20 (today's value)
	var mh := Control.new(); get_root().add_child(mh)
	RushFx.merge_burst(mh, Vector2(10, 10), 3, 20)
	var pcount := 0
	for ch in mh.get_children():
		if ch is GPUParticles2D: pcount = int((ch as GPUParticles2D).amount)
	ok(pcount == FX.amount_for(20), "merge_burst: particle amount tracks the count knob (tier 3, count 20)")
	mh.queue_free()
	# cell_pop strength flows to squash_pop (pct 50 → half deviation)
	var cp := Control.new(); cp.size = Vector2(80, 80); get_root().add_child(cp)
	RushFx.cell_pop(cp, 50)
	# calm is false (set above), so squash_pop sets node.scale synchronously before tweening
	ok(not cp.scale.is_equal_approx(Vector2.ONE), "cell_pop: applies a scaled squash (pct 50)")
	cp.queue_free()
	# treefall_crack accepts debris/shake/hitstop without error and bursts on the host
	var th := Control.new(); get_root().add_child(th)
	var tb := Control.new(); tb.size = Vector2(100, 100); get_root().add_child(tb)
	RushFx.treefall_crack(th, tb, Vector2(20, 20), true, 9, 24.0, 40)
	var has_burst := false
	for ch in th.get_children():
		if ch is GPUParticles2D: has_burst = true
	ok(has_burst, "treefall_crack: debris bursts with custom params (silent)")
	th.queue_free(); tb.queue_free()
	# timer_low: threshold drives the warm lerp + colour override (synchronous, silent)
	var tlbl := Label.new(); get_root().add_child(tlbl)
	RushFx.timer_low(tlbl, 10, true, 20)   # secs_left 10 of threshold 20 → warm 0.5
	ok(tlbl.get_theme_color("font_color").is_equal_approx(RushFx.INK.lerp(RushFx.HOT, 0.5)), "timer_low: warm lerp at half the threshold")
	RushFx.timer_low(tlbl, 30, true, 20)   # above threshold → resting ink restored
	ok(tlbl.get_theme_color("font_color").is_equal_approx(RushFx.INK), "timer_low: above threshold restores resting ink")
	tlbl.queue_free()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
