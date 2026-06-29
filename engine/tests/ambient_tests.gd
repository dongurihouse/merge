extends SceneTree
## Headless tests for the ambient CPU governor (ambient_driver.gd) + its wiring in ambient.gd.
## The ambient layer must (1) reposition at a FIXED LOW RATE, not once per rendered frame, and
## (2) IDLE — stop repositioning AND freeze its CPUParticles2D — when the app is backgrounded /
## unfocused (finally wiring the long-dead `paused` meta). Both keep the SoC from heat-soaking on a
## near-static board.
##   godot --headless --path . -s res://engine/tests/ambient_tests.gd
## NOTE: headless logic check — it drives _process()/notification() directly, no window. (The headless
## root reports is_visible_in_tree()==false, so idling keys off app-focus, not visibility — by design.)

const AmbientDriver = preload("res://engine/scripts/ui/ambient_driver.gd")
const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const Features = preload("res://engine/scripts/core/features.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _has_driver(n: Node) -> bool:
	for c in n.get_children():
		if c.get_script() == AmbientDriver:
			return true
	return false

func _initialize() -> void:
	# 1. THROTTLE — the driver runs its tick at its own rate, not once per rendered frame.
	var layer := Control.new(); layer.size = Vector2(200, 200); get_root().add_child(layer)
	var d := AmbientDriver.new(); layer.add_child(d)
	var ticks := [0]
	d.setup(layer, func() -> void: ticks[0] += 1, 10.0)
	for _i in 20:
		d._process(0.05)                                   # 1.0s worth of 50ms frames
	ok(ticks[0] == 10, "driver throttles tick to its rate (10 over 1.0s @10Hz, not ~60)")

	# 2. IDLE WHEN UNSEEN — app-pause sets the paused meta AND freezes the particle sim; resume restores.
	var wl := Control.new(); wl.size = Vector2(200, 200); get_root().add_child(wl)
	var p := CPUParticles2D.new(); wl.add_child(p)
	var dw := AmbientDriver.new(); wl.add_child(dw)
	dw.setup(wl, Callable(), 10.0)
	ok(wl.get_meta("paused", true) == false, "active on setup → layer not paused")
	ok(p.process_mode == Node.PROCESS_MODE_INHERIT, "active on setup → particles simulate")
	dw.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	ok(wl.get_meta("paused", false) == true, "app backgrounded → paused meta set")
	ok(p.process_mode == Node.PROCESS_MODE_DISABLED, "app backgrounded → particles frozen (no CPU sim)")
	dw.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	ok(wl.get_meta("paused", true) == false, "app resumed → layer un-paused")
	ok(p.process_mode == Node.PROCESS_MODE_INHERIT, "app resumed → particles simulate again")

	# 3. NO WORK WHILE BACKGROUNDED — a paused driver does no reposition work.
	var l3 := Control.new(); l3.size = Vector2(100, 100); get_root().add_child(l3)
	var d3 := AmbientDriver.new(); l3.add_child(d3)
	var t3 := [0]
	d3.setup(l3, func() -> void: t3[0] += 1, 10.0)
	d3.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	for _i in 20:
		d3._process(0.05)
	ok(t3[0] == 0, "backgrounded driver does no reposition work")

	# 4. RESUME — repositioning restarts when the app returns to the foreground.
	d3.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	for _i in 4:
		d3._process(0.05)
	ok(t3[0] >= 1, "resumed driver repositions again")

	# 5. POPULATION LAYER is driven by a throttled driver (not the old per-frame loop tween).
	Features.FLAGS["ambient_characters"] = true
	var pop := Ambient.build_population_layer(Vector2(300, 300), [{"type": "x", "tier": 1}, {"type": "x", "tier": 1}])
	get_root().add_child(pop)
	ok(_has_driver(pop), "build_population_layer attaches an AmbientDriver")

	# 6. WEATHER LAYER attaches a driver so its sim freezes when backgrounded.
	Features.FLAGS["ambient_weather"] = true
	var wx := Ambient.build_weather(Vector2(300, 300), "rain")
	get_root().add_child(wx)
	ok(_has_driver(wx), "build_weather attaches an AmbientDriver")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
