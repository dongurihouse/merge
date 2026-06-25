extends SceneTree
## Headless tests for the code-drawn water fill FX component.
##   godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd

const WaterFillEffect = preload("res://engine/scripts/ui/water_fill_effect.gd")
const SCENE_PATH := "res://engine/tools/WaterFillDemo.tscn"

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _initialize() -> void:
	var fx: Control = WaterFillEffect.new()
	fx.size = Vector2(640, 520)
	root.add_child(fx)
	await process_frame

	ok(is_equal_approx(fx.energy_for_test(), WaterFillEffect.IDLE_ENERGY),
		"starts at idle wave energy")

	fx.trigger_impact_for_test()
	ok(fx.energy_for_test() > WaterFillEffect.IDLE_ENERGY * 3.0,
		"impact injects substantially more wave energy")

	var center_wave: float = fx.wave_height_for_test(0.5)
	var edge_wave: float = fx.wave_height_for_test(0.1)
	ok(absf(center_wave - edge_wave) > 3.0,
		"impact wave is localized around the droplet hit point")

	for i in 180:
		fx.advance_for_test(1.0 / 60.0)
	ok(fx.energy_for_test() < WaterFillEffect.IDLE_ENERGY + 0.8,
		"wave energy damps back near idle")

	fx.set_time_for_test(0.9)
	var growing: Dictionary = fx.drop_state_for_test()
	ok(bool(growing.visible) and float(growing.radius) > 7.0,
		"droplet grows before falling")

	fx.set_time_for_test(1.8)
	var falling: Dictionary = fx.drop_state_for_test()
	ok(bool(falling.visible) and float(falling.y) > float(growing.y),
		"droplet falls downward after growing")

	fx.set_time_for_test(2.25)
	var after_hit: Dictionary = fx.drop_state_for_test()
	ok(not bool(after_hit.visible),
		"droplet disappears into the water after impact")

	fx.queue_free()

	ok(ResourceLoader.exists(SCENE_PATH), "editor-openable water demo scene exists")
	var packed := load(SCENE_PATH) as PackedScene
	ok(packed != null, "water demo scene loads as a PackedScene")
	if packed != null:
		var scene := packed.instantiate() as Control
		ok(scene != null and scene.name == "WaterFillDemo", "water demo scene instantiates as WaterFillDemo")
		if scene != null:
			root.add_child(scene)
			await process_frame
			ok(scene.find_child("WaterFillEffect", true, false) is Control,
				"water demo scene contains the animated water effect")
			scene.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
