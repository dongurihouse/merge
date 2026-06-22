extends SceneTree
## Headless guard for the HOME/map canvas geometry (map.gd `map_rect_for`).
##   godot --headless --path . -s res://engine/tests/map_canvas_tests.gd
## The home map background must FILL the device width at the design aspect (like the board
## background's cover-fill) — never side-letterbox on an off-design device. On a window WIDER
## than design it crops the top/bottom; on the exact design aspect it fills the viewport exactly.

const MapScene = preload("res://engine/scripts/scenes/map.gd")

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
	var design := Vector2(1080.0, 1920.0)
	var design_aspect := design.x / design.y

	# at the exact design aspect the rect is the whole viewport (unchanged from the placer basis)
	ok(MapScene.map_rect_for(design, design_aspect) == Rect2(0, 0, 1080, 1920), \
		"at the design aspect the map rect is the whole viewport")

	# a window WIDER than 9:16 (stretch aspect=expand grows the viewport width): the map must span the
	# FULL width (no side sky bars) and keep the design aspect, cropping the top/bottom instead.
	var wide := Vector2(1600.0, 1920.0)
	var wr: Rect2 = MapScene.map_rect_for(wide, design_aspect)
	ok(absf(wr.size.x - wide.x) < 1.0, "a wide window: the map spans the FULL width (no side letterbox)")
	ok(absf(wr.position.x) < 1.0, "a wide window: the map is flush to the left edge (x≈0)")
	ok(wr.position.y < 0.0, "a wide window: the map overflows top/bottom (cropped, vertically centered)")
	ok(absf(wr.size.y / wr.size.x - design.y / design.x) < 0.01, \
		"a wide window: the map keeps the design aspect (crop, never squash)")

	# a TALLER window (the common phone case): width still fills exactly; the sky shows above/below.
	var tall := Vector2(1080.0, 2340.0)
	var tr: Rect2 = MapScene.map_rect_for(tall, design_aspect)
	ok(absf(tr.size.x - tall.x) < 1.0, "a tall window: the map still fills the full width")
	ok(tr.position.y > 0.0 and tr.size.y < tall.y, "a tall window: the map is shorter than the screen (sky above/below)")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
