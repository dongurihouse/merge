extends SceneTree
## Headless tests for SceneWarm — the threaded scene pre-warm + packed-swap helper.
##   godot --headless -s res://engine/tests/scene_warm_tests.gd
## Uses a throwaway PackedScene saved to user:// so it never depends on (or recompiles)
## the real game scenes. The actual change_scene swap is covered by the headless smoke.

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

# Pack a trivial scene (a named root + one child) to a user:// path for warming.
func _make_scene(path: String) -> void:
	var root := Node.new()
	root.name = "WarmRoot"
	var child := Node.new()
	child.name = "WarmChild"
	root.add_child(child)
	child.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, path)
	root.free()

func _initialize() -> void:
	print("== SceneWarm tests ==")
	SceneWarm._clear()

	var path := "user://tu_scene_warm_test.tscn"
	_make_scene(path)

	# 1. take() on a real (un-prewarmed) path cold-loads a usable PackedScene.
	var ps := SceneWarm.take(path)
	ok(ps is PackedScene, "take() returns a PackedScene (cold fallback)")
	if ps != null:
		var inst := ps.instantiate()
		ok(inst != null and inst.name == "WarmRoot" and inst.get_child_count() == 1, "packed scene instantiates with its tree")
		if inst != null:
			inst.free()

	# 2. take() is cached — the same object comes back (no re-load).
	ok(SceneWarm.take(path) == ps, "take() caches: identical PackedScene on 2nd call")

	# 3. prewarm() then take() works and is idempotent (safe to call repeatedly).
	SceneWarm._clear()
	SceneWarm.prewarm(path)
	SceneWarm.prewarm(path)   # 2nd call must not error or double-request
	var ps2 := SceneWarm.take(path)
	ok(ps2 is PackedScene, "prewarm() + take() yields a PackedScene")

	# 4. is_warm reflects cache state.
	ok(SceneWarm.is_warm(path), "is_warm() true after take()")
	SceneWarm._clear()
	ok(not SceneWarm.is_warm(path), "is_warm() false after _clear()")

	# 5. missing paths are safe no-ops (never crash a transition).
	SceneWarm.prewarm("res://does/not/exist.tscn")
	ok(SceneWarm.take("res://does/not/exist.tscn") == null, "take() on missing path returns null")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
