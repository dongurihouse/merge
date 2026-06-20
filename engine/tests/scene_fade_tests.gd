extends SceneTree
## Headless tests for SceneFade — the cross-scene transition cover.
##   godot --headless -s res://engine/tests/scene_fade_tests.gd
## Covers the structural contract (a cover layer is added on top, blocks input, and the fade-in cover
## removes itself after the tween). The actual scene SWAP under cover is exercised by the smoke test.

const SceneFade = preload("res://engine/scripts/ui/scene_fade.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")

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
	print("== SceneFade tests ==")

	# A stand-in "scene" root in the tree.
	var scene := Control.new()
	scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)
	await process_frame

	# 1. fade_in adds exactly one cover (a CanvasLayer) on top, starting opaque.
	var before := scene.get_child_count()
	var cover := SceneFade.fade_in(scene, 0.08)
	ok(scene.get_child_count() == before + 1, "fade_in adds a cover layer")
	ok(cover is CanvasLayer, "cover is a CanvasLayer (above scene content)")
	var rect := cover.get_child(0) as ColorRect
	ok(rect != null and rect.color.a >= 0.99, "cover starts opaque (hides the build)")

	# 2. after the tween (plus buffer) the fade-in cover removes itself.
	await create_timer(0.25).timeout
	ok(not is_instance_valid(cover) or cover.get_parent() == null, "fade_in cover frees itself when done")

	# 3. cover(scene) blocks input while a transition is in flight.
	var c2 := SceneFade.cover(scene, 1.0, true)
	var r2 := c2.get_child(0) as Control
	ok(r2 != null and r2.mouse_filter == Control.MOUSE_FILTER_STOP, "transition cover blocks input")
	c2.queue_free()

	# 4. integration: SceneFade.to() actually completes the swap under cover (fade -> change_scene).
	SceneWarm._clear()
	var pa := "user://tu_fade_a.tscn"
	var pb := "user://tu_fade_b.tscn"
	_make_named_scene(pa, "FadeA")
	_make_named_scene(pb, "FadeB")
	change_scene_to_packed(load(pa))
	await process_frame
	await process_frame
	ok(current_scene != null and current_scene.name == "FadeA", "starting scene is FadeA")
	SceneFade.to(current_scene, self, pb, 0.06)
	await create_timer(0.3).timeout
	ok(current_scene != null and current_scene.name == "FadeB", "SceneFade.to() swapped to FadeB under cover")
	for p in [pa, pb]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)

func _make_named_scene(path: String, root_name: String) -> void:
	var n := Node.new()
	n.name = root_name
	var ps := PackedScene.new()
	ps.pack(n)
	ResourceSaver.save(ps, path)
	n.free()
