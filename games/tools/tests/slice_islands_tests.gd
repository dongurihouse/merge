extends "res://engine/tests/test_base.gd"
## Regression suite for the intake keyer pipeline (chroma_key.gd → slice_islands.gd).
##
## Guards the "hole resurrection" bug: chroma_key zeroes an ENCLOSED #FF00FF pocket
## (e.g. the gap under a bag handle), but slice_islands' border-only flood-fill can't
## reach a walled-in pocket, so step 3 used to re-opaque it — resurrecting the magenta.
## The fix treats any already-cleared (alpha ~ 0) pixel as background regardless of
## whether the border flood reached it. These tests exercise the real static cores of
## both tools end-to-end on a synthetic asset that has an enclosed hole.

const ChromaKey = preload("res://games/tools/chroma_key.gd")
const SliceIslands = preload("res://games/tools/slice_islands.gd")

const KEY := Color(1, 0, 1)          # #FF00FF magenta chroma background
const PIECE := Color(0, 1, 0)        # opaque green foreground piece

## A magenta sheet with a solid green square that ENCLOSES a magenta pocket — the
## "bag handle loop" case. Returns the 64x64 RGBA8 image (alpha 255 everywhere).
func _make_sheet() -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(KEY)
	for y in range(16, 48):
		for x in range(16, 48):
			img.set_pixel(x, y, PIECE)          # solid green piece
	for y in range(26, 38):
		for x in range(26, 38):
			img.set_pixel(x, y, KEY)            # enclosed magenta pocket inside the piece
	return img

func _initialize() -> void:
	print("== slice_islands intake-keyer guard ==")

	var img := _make_sheet()

	# Step 1: chroma_key clears the magenta — outer field AND the enclosed pocket.
	var cleared := ChromaKey.key_image(img, KEY, 0.18)
	ok(cleared > 0, "chroma_key cleared magenta pixels")
	ok(img.get_pixel(31, 31).a == 0.0, "chroma_key zeroed the enclosed pocket alpha")
	ok(img.get_pixel(20, 20).a == 1.0, "chroma_key left the green piece opaque")

	# Step 2: slice into pieces.
	var pieces := SliceIslands.slice_sheet(img, SliceIslands.VAL_MIN, SliceIslands.SAT_MAX, 200, 2)
	ok(pieces.size() == 1, "slice produced exactly one piece (green frame)")

	if pieces.size() == 1:
		var pc: Dictionary = pieces[0]
		var cell: Image = pc.image
		# Global (31,31) is the pocket centre; map into the cropped cell.
		var hx := 31 - int(pc.x)
		var hy := 31 - int(pc.y)
		# REGRESSION: the enclosed pocket must stay transparent, not resurrect as magenta.
		ok(cell.get_pixel(hx, hy).a == 0.0, "enclosed pocket stays transparent in the sliced piece")
		# The surrounding green frame must survive as opaque foreground.
		var gx := 18 - int(pc.x)
		var gy := 31 - int(pc.y)
		var gp := cell.get_pixel(gx, gy)
		ok(gp.a == 1.0, "green frame pixel stays opaque")
		ok(gp.g > 0.5 and gp.r < 0.5 and gp.b < 0.5, "green frame keeps its colour")

	_test_hue_key_removes_shadow_on_key()

	finish()

## HUE KEY — the "black line welded to the sprite" guard. Generated art often casts a soft drop
## shadow onto the key colour; that shadow is DARKENED magenta, which a distance key leaves opaque
## and a later despill turns into a hard black band. The case is unfixable by tolerance because a
## mauve SUBJECT can sit closer to #FF00FF than the dark shadow does — measured on the real board
## cell sheet: subject max magenta-excess 46, shadow band 107.
func _test_hue_key_removes_shadow_on_key() -> void:
	var w := 40
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 1))                                    # pure key field
	for y in range(24, 30):                                     # the drop shadow: DARKENED key
		for x in range(8, 32):
			img.set_pixel(x, y, Color8(124, 3, 110))
	for y in range(8, 24):                                      # the subject: a mauve tile
		for x in range(8, 32):
			img.set_pixel(x, y, Color8(133, 86, 132))           # excess 46 — the worst real case
	# a distance key wide enough to catch the shadow would also eat this subject
	var probe := img.duplicate() as Image
	ChromaKey.key_image(probe, KEY, 0.45)
	ok(probe.get_pixel(20, 15).a == 0.0,
		"a tolerance wide enough for the shadow destroys the mauve subject (why hue mode exists)")
	var touched := ChromaKey.key_image_hue(img, 55.0, 100.0)
	ok(touched > 0, "hue key touched the key-derived pixels")
	ok(img.get_pixel(20, 26).a == 0.0, "the darkened-key drop shadow is keyed fully away")
	ok(img.get_pixel(1, 1).a == 0.0, "the pure key field is keyed away")
	ok(img.get_pixel(20, 15).a == 1.0, "the mauve subject stays fully opaque")
	# enclosed key-coloured art can never be eaten: only border-reachable pixels are eligible
	var enc := Image.create(w, w, false, Image.FORMAT_RGBA8)
	enc.fill(Color(0, 0.6, 0.2))                                # solid green sheet, no border key
	enc.set_pixel(20, 20, Color(1, 0, 1))                       # a legitimately magenta detail
	ChromaKey.key_image_hue(enc, 55.0, 100.0)
	ok(enc.get_pixel(20, 20).a == 1.0, "an enclosed magenta detail is never keyed (flood is border-seeded)")
