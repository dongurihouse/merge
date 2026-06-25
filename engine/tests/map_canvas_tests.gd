extends SceneTree
## Headless guard for the HOME/map canvas geometry (map.gd `map_rect_for`).
##   godot --headless --path . -s res://engine/tests/map_canvas_tests.gd
## The home map background must COVER-FILL the viewport at the design aspect (like the board
## background) — never letterbox on an off-design device. On a window WIDER than design it crops the
## top/bottom; on a TALLER window (the common phone case) it crops left/right; on the exact design
## aspect it fills the viewport exactly.

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

	# a TALLER window (the common phone case: 19.5:9 vs the 9:16 canvas): the map must COVER the full
	# HEIGHT (no top/bottom sky bands) and overflow left/right instead, keeping the design aspect.
	var tall := Vector2(1080.0, 2340.0)
	var tr: Rect2 = MapScene.map_rect_for(tall, design_aspect)
	ok(absf(tr.size.y - tall.y) < 1.0, "a tall window: the map fills the FULL height (no top/bottom sky bands)")
	ok(absf(tr.position.y) < 1.0, "a tall window: the map is flush to the top edge (y≈0)")
	ok(tr.position.x < 0.0 and tr.size.x > tall.x, "a tall window: the map overflows left/right (cropped, horizontally centered)")
	ok(absf(tr.size.y / tr.size.x - design.y / design.x) < 0.01, \
		"a tall window: the map keeps the design aspect (crop, never squash)")

	var design_src := FileAccess.get_file_as_string("res://engine/scripts/core/design.gd")
	ok(design_src.find("GROVE_DEVICE_POINTS") != -1,
		"desktop window fit accepts GROVE_DEVICE_POINTS so `make g DEVICE=393x852` can mimic phone shape")
	var makefile_src := FileAccess.get_file_as_string("res://Makefile")
	ok(makefile_src.find("GROVE_DEVICE_POINTS") != -1 and makefile_src.find("DEVICE=393x852") != -1,
		"Makefile exposes the phone simulator through `make g DEVICE=393x852`")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
