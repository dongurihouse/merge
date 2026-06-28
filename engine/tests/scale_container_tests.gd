extends SceneTree
## Unit tests for ScaleContainer: it scales its single child uniformly and reports the
## child's SCALED footprint as its own minimum size, so a parent ScrollContainer scrolls
## the scaled content correctly.
##   godot --headless --path . -s res://engine/tests/scale_container_tests.gd

const ScaleContainer = preload("res://engine/scripts/ui/scale_container.gd")

var _pass := 0
var _fail := 0
func ok(c: bool, l: String) -> void:
	if c:
		_pass += 1
		print("  PASS  ", l)
	else:
		_fail += 1
		print("  FAIL  ", l)

# A VBox holder of a known width that the ScaleContainer fills (mirrors the real `rows` VBox).
# Width is forced via custom_minimum_size (the headless root window size does not reliably stick).
func _holder(w: float, h: float) -> VBoxContainer:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(w, h)
	holder.size = Vector2(w, h)
	get_root().add_child(holder)
	await process_frame
	await process_frame
	return holder

func _initialize() -> void:
	print("== ScaleContainer tests ==")

	var holder: VBoxContainer = await _holder(300.0, 600.0)

	var sc := ScaleContainer.new()
	sc.scale_factor = 2.0
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(sc)
	var child := Control.new()
	child.custom_minimum_size = Vector2(100, 50)   # authored size
	sc.add_child(child)
	for _i in 8:
		await process_frame

	ok(is_equal_approx(child.scale.x, 2.0) and is_equal_approx(child.scale.y, 2.0), "child rendered at scale_factor (uniform)")
	ok(is_equal_approx(child.size.x, sc.size.x / 2.0), "child laid out at container width / scale")
	ok(sc.get_combined_minimum_size().y >= 50.0 * 2.0 - 1.0, "min height = child height x scale (scaled footprint up)")

	# identity scale (1.0) is a transparent pass-through
	var sc1 := ScaleContainer.new()
	sc1.scale_factor = 1.0
	sc1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(sc1)
	var c1 := Control.new()
	c1.custom_minimum_size = Vector2(80, 40)
	sc1.add_child(c1)
	for _i in 8:
		await process_frame
	ok(is_equal_approx(c1.scale.x, 1.0), "identity scale leaves child unscaled")
	ok(sc1.get_combined_minimum_size().y >= 40.0 - 1.0, "identity min height = child height")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
