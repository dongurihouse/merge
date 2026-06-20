extends SceneTree
## Headless tests for Kit.polish_async — the worker-thread image polish behind the workbench's polish
## sliders. Uses a synthetic Image so it doesn't depend on imported art.
##   godot --headless -s res://engine/tests/kit_polish_async_tests.gd

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# A small RGBA image with a soft alpha edge (something for defringe/feather to chew on).
func _synthetic(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var a := 1.0 if (x > 2 and x < w - 3 and y > 2 and y < h - 3) else 0.3
			img.set_pixel(x, y, Color(0.8, 0.4, 0.2, a))
	return img

func _await_polish(key: String, img: Image, opts: Dictionary, aspect: bool) -> Texture2D:
	var tex: Texture2D = Kit.polish_async(key, img, opts, aspect)
	var tries := 0
	while tex == null and tries < 120:
		Kit.pump_polish()
		await process_frame
		tex = Kit.polish_async(key, img, opts, aspect)
		tries += 1
	return tex

func _initialize() -> void:
	print("== Kit async-polish tests ==")
	Kit.clear_async_cache()

	var img := _synthetic(40, 40)

	# 1. first call dispatches to a worker and isn't ready yet (work is OFF the main thread).
	var first: Texture2D = Kit.polish_async("icon|t", img, {"feather": 1.0, "supersample": 1, "size": 160}, false)
	ok(first == null, "first call returns null (polish runs on a worker, not inline)")
	ok(Kit.polish_pending() == 1, "one task queued")

	# 2. it completes and yields a polished texture at the requested size.
	var tex := await _await_polish("icon|t", img, {"feather": 1.0, "supersample": 1, "size": 160}, false)
	ok(tex is Texture2D, "worker polish completes -> a texture")
	ok(tex != null and tex.get_width() == 160 and tex.get_height() == 160, "polished to the requested size (160)")
	ok(Kit.polish_pending() == 0, "no tasks left pending")

	# 3. a repeat request for the same key is served from cache instantly (same object).
	var again: Texture2D = Kit.polish_async("icon|t", img, {"feather": 1.0, "supersample": 1, "size": 160}, false)
	ok(again == tex, "repeat key returns the cached texture immediately")

	# 4. aspect mode keeps a non-square source's proportions.
	var wide := _synthetic(80, 40)
	var atex := await _await_polish("badge|t", wide, {"feather": 1.0}, true)
	ok(atex is Texture2D and atex.get_width() > atex.get_height(), "aspect polish keeps non-square proportions")

	# 5. a null source is a safe no-op.
	ok(Kit.polish_async("none", null, {}, false) == null, "null source returns null (no crash)")

	Kit.clear_async_cache()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
