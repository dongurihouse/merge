extends "res://engine/tests/test_base.gd"
## Regression suite for the intake pixel tools: the keyer pipeline (chroma_key.gd →
## slice_islands.gd) AND the shared pixel-op module every intake tool keys through
## (games/tools/img_ops.gd — see the "img_ops" section at the bottom).
##
## Guards the "hole resurrection" bug: chroma_key zeroes an ENCLOSED #FF00FF pocket
## (e.g. the gap under a bag handle), but slice_islands' border-only flood-fill can't
## reach a walled-in pocket, so step 3 used to re-opaque it — resurrecting the magenta.
## The fix treats any already-cleared (alpha ~ 0) pixel as background regardless of
## whether the border flood reached it. These tests exercise the real static cores of
## both tools end-to-end on a synthetic asset that has an enclosed hole.

const ChromaKey = preload("res://games/tools/chroma_key.gd")
const SliceIslands = preload("res://games/tools/slice_islands.gd")
const ImgOps = preload("res://games/tools/img_ops.gd")

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

	_test_slice_keeps_a_soft_alpha_ramp()
	_test_despill_only_touches_a_tinted_edge()
	_test_hue_key_removes_shadow_on_key()
	_test_img_ops_values()
	_test_no_tool_redeclares_the_keying_constants()
	_test_is_bg_rule()
	_test_alpha_floor_forms_agree()
	_test_premultiply_round_trip()
	_test_flood_and_trim()

	finish()

## DESPILL IS AN EDGE OP, NOT A RECOLOUR. Clamping R,B toward G unconditionally is not a despill:
## Meadow Sky coral is #D87865 (R 216, G 120), so `R <= G + 15` drags every coral plane in the art
## to brown — which is exactly what a first cut of this did to the nav row's map pin, calendar bow,
## wax seal and play triangle. Both guards are asserted here: the pixel must be key-TINTED and it
## must sit within DESPILL_BAND px of transparency.
func _test_despill_only_touches_a_tinted_edge() -> void:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color8(216, 120, 101))                     # solid coral sheet, fully opaque
	for y in 24:
		img.set_pixel(0, y, Color(0, 0, 0, 0))          # one transparent column: the cut edge
		img.set_pixel(1, y, Color8(190, 74, 157))       # its key-tinted boundary pixel (excess 83)
	img.set_pixel(12, 12, Color8(190, 74, 157))         # the SAME tint, deep in the interior
	var touched := ImgOps.despill_magenta(img)
	ok(touched == 24, "despill touched only the 24 tinted edge px (got %d)" % touched)
	var edge := img.get_pixel(1, 5)
	ok(min(edge.r, edge.b) - edge.g <= float(ImgOps.DESPILL_D) / 255.0 + 0.001,
		"the tinted edge pixel is clamped to G + DESPILL_D")
	var coral := img.get_pixel(10, 10)
	ok(int(round(coral.r * 255.0)) == 216 and int(round(coral.b * 255.0)) == 101,
		"coral art is untouched — the excess guard, not a blanket clamp")
	var interior := img.get_pixel(12, 12)
	ok(int(round(interior.r * 255.0)) == 190,
		"a tinted pixel far from any transparency is untouched — the band guard")

## THE SOFT RAMP MUST SURVIVE THE SLICE. The guide's §8 edge treatment is a soft alpha ramp over
## key distance, not a hard threshold. This tool was written for checkerboard sheets whose every
## foreground pixel is opaque, and it used to write Color8(r, g, b, 255) — which on an ALREADY-KEYED
## sheet promotes each half-keyed boundary pixel to a fully opaque key-coloured one, i.e. exactly the
## magenta rim the ramp exists to prevent. Foreground alpha is now carried through unchanged.
func _test_slice_keeps_a_soft_alpha_ramp() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 1, 0))                                  # keyed-away field
	for y in range(16, 48):
		for x in range(16, 48):
			img.set_pixel(x, y, PIECE)                           # the opaque piece
	for y in range(16, 48):
		img.set_pixel(15, y, Color(0.6, 0.35, 0.55, 0.5))        # its half-covered boundary pixel
	var pieces := SliceIslands.slice_sheet(img, SliceIslands.VAL_MIN, SliceIslands.SAT_MAX, 200, 2)
	ok(pieces.size() == 1, "ramp sheet sliced to one piece")
	if pieces.size() == 1:
		var pc: Dictionary = pieces[0]
		var edge: Color = (pc.image as Image).get_pixel(15 - int(pc.x), 31 - int(pc.y))
		ok(absf(edge.a - 0.5) < 0.01, "the half-covered edge pixel keeps its 0.5 alpha, not 1.0")
		ok((pc.image as Image).get_pixel(20 - int(pc.x), 31 - int(pc.y)).a == 1.0,
			"…while the opaque interior is still opaque")

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
	_test_hue_key_reaches_an_opened_pocket()

## A WALLED-IN key pocket the distance pass already opened. Its core is transparent but its
## anti-aliased RIM is a partly-keyed pixel too far from the key for `tol` and unreachable from the
## canvas border, so a border-only flood ships a magenta ring around every punched hole (the real
## case: the nav calendar glyph's two ring holes). The flood is therefore seeded from already-cleared
## pixels as well — which must NOT make an enclosed OPAQUE magenta detail keyable (asserted above).
func _test_hue_key_reaches_an_opened_pocket() -> void:
	var w := 40
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0.6, 0.2))                                # opaque green sheet, no border key
	for y in range(16, 24):                                     # the pocket: pure key, already cut
		for x in range(16, 24):
			img.set_pixel(x, y, Color(1, 0, 1, 0))
	for x in range(15, 25):                                     # its rim: half-keyed, still OPAQUE
		img.set_pixel(x, 15, Color8(190, 74, 157))              # excess 83
		img.set_pixel(x, 24, Color8(190, 74, 157))
	ChromaKey.key_image_hue(img, 30.0, 110.0)
	var rim := img.get_pixel(20, 15)
	ok(rim.a < 1.0, "the opened pocket's key-tinted rim is reached and ramped down")
	ok(min(rim.r, rim.b) - rim.g <= 15.0 / 255.0 + 0.001,
		"…and what survives is despilled (R,B clamped to G+15)")
	ok(img.get_pixel(5, 5).a == 1.0, "the green sheet around it is untouched")

## ==========================================================================================
## img_ops — the SHARED keying constants + pixel ops (games/tools/img_ops.gd)
##
## Every intake tool used to carry its own copy of the background rule, held in sync by
## "keep in lockstep" comments. Retuning one copy silently changed how a source PNG keyed
## depending on which tool the plan invoked — a fringe in the shipped game, never an error.
## These tests pin the shared values AND assert no tool has re-declared them locally, so a
## future divergence fails here instead of shipping.
## ==========================================================================================

## Every tool that keys pixels, and the exact `is_bg` call its own `_is_bg` must resolve to.
## proc_line deliberately passes its OWN checker thresholds (a baked transparency
## checkerboard is a different plate from the cream field), so it names CHK_VAL / CHK_SAT.
const IS_BG_CALLS := {
	"process_icon":  "ImgOps.is_bg(c, ImgOps.BG_MAX_VAL, ImgOps.BG_MAX_SAT, ImgOps.ALPHA_CLEAR)",
	"process_group": "ImgOps.is_bg(c, ImgOps.BG_MAX_VAL, ImgOps.BG_MAX_SAT, ImgOps.ALPHA_CLEAR)",
	"process_decor": "ImgOps.is_bg(c, ImgOps.BG_MAX_VAL, ImgOps.BG_MAX_SAT, ImgOps.ALPHA_CLEAR)",
	"slice_grid":    "ImgOps.is_bg(c, ImgOps.BG_MAX_VAL, ImgOps.BG_MAX_SAT, ImgOps.ALPHA_CLEAR)",
	"cutout_bg":     "ImgOps.is_bg(c, ImgOps.BG_MAX_VAL, ImgOps.BG_MAX_SAT, ImgOps.ALPHA_MIN_F)",
	"cutout_holes":  "ImgOps.is_bg(c, ImgOps.BG_MAX_VAL, ImgOps.BG_MAX_SAT, ImgOps.ALPHA_MIN_F)",
	"proc_line":     "ImgOps.is_bg(c, CHK_VAL, CHK_SAT, ImgOps.ALPHA_MIN_F)",
}

## Tools that carry the constants but do their own byte-level test (slice_islands) or use a
## deliberately different floor (slice_badges) — checked separately below.
const OTHER_TOOLS := ["slice_badges", "slice_islands"]

## The source of an intake tool, by tool NAME (these checks read the code, not the pixels).
func _src(tool_name: String) -> String:
	return read_text("res://games/tools/%s.gd" % tool_name)

## Code lines only — a threshold quoted in a comment is documentation, not a second source of truth.
func _code_lines(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line in text.split("\n"):
		var stripped := String(line).strip_edges()
		if stripped != "" and not stripped.begins_with("#"):
			out.append(stripped)
	return out

func _test_img_ops_values() -> void:
	# Pin the shared numbers: a retune has to change THIS line, in the open.
	ok(ImgOps.BG_MAX_VAL == 0.93, "shared BG_MAX_VAL is 0.93")
	ok(ImgOps.BG_MAX_SAT == 0.10, "shared BG_MAX_SAT is 0.10")
	ok(ImgOps.ALPHA_MIN == 8, "shared ALPHA_MIN is 8 (8-bit domain)")
	ok(is_equal_approx(ImgOps.ALPHA_MIN_F, 8.0 / 255.0), "ALPHA_MIN_F is ALPHA_MIN / 255")
	ok(ImgOps.ALPHA_CLEAR == 0.05, "ALPHA_CLEAR (the older, looser float floor) is 0.05")
	ok(ImgOps.TRIM_ALPHA == 0.05, "TRIM_ALPHA is 0.05")
	# slice_islands keys raw bytes, so it takes the 8-bit constant straight from the module.
	ok(SliceIslands.ALPHA_MIN == ImgOps.ALPHA_MIN, "slice_islands' ALPHA_MIN IS the shared constant")

func _test_no_tool_redeclares_the_keying_constants() -> void:
	for tool_name in IS_BG_CALLS.keys():
		var text := _src(tool_name)
		ok(text.contains('preload("res://games/tools/img_ops.gd")'),
			"%s preloads img_ops" % tool_name)
		ok(text.contains(IS_BG_CALLS[tool_name]),
			"%s's _is_bg resolves to the shared rule" % tool_name)
	# No tool may re-declare the background rule locally — that is exactly the drift this
	# module exists to prevent.
	for tool_name in (IS_BG_CALLS.keys() + OTHER_TOOLS):
		var redeclared := false
		for line in _code_lines(_src(tool_name)):
			if line.begins_with("const BG_MAX_VAL") or line.begins_with("const BG_MAX_SAT"):
				redeclared = true
		ok(not redeclared, "%s does not re-declare BG_MAX_VAL / BG_MAX_SAT" % tool_name)
	# ALPHA_MIN may only be re-declared where it means something ELSE. slice_badges' 0.08 is a
	# FOREGROUND-membership floor, not the "already transparent" floor — measured to change its
	# output, so it is kept on purpose and documented in place.
	for tool_name in (IS_BG_CALLS.keys() + OTHER_TOOLS):
		for line in _code_lines(_src(tool_name)):
			if not line.begins_with("const ALPHA_MIN"):
				continue
			if tool_name == "slice_badges":
				ok(line.contains("0.08"),
					"slice_badges keeps its own 0.08 medal-membership floor (deliberate)")
			else:
				ok(line.contains("ImgOps."),
					"%s's ALPHA_MIN comes from img_ops" % tool_name)

func _test_is_bg_rule() -> void:
	var V := ImgOps.BG_MAX_VAL
	var S := ImgOps.BG_MAX_SAT
	var A := ImgOps.ALPHA_CLEAR
	ok(ImgOps.is_bg(Color(1, 1, 1, 1), V, S, A), "pure white is background")
	# Straddle the value threshold. NOT tested exactly AT V: Color stores float32, so
	# Color(0.93,...).r reads back as 0.93000001 and lands on the far side of the comparison.
	ok(not ImgOps.is_bg(Color(0.92, 0.92, 0.92, 1), V, S, A), "a grey just BELOW BG_MAX_VAL is NOT background")
	ok(ImgOps.is_bg(Color(0.94, 0.94, 0.94, 1), V, S, A), "a grey just ABOVE BG_MAX_VAL is background")
	ok(not ImgOps.is_bg(Color(1.0, 0.5, 0.5, 1), V, S, A), "a saturated bright pink is NOT background")
	ok(not ImgOps.is_bg(Color(0.2, 0.2, 0.2, 1), V, S, A), "a dark grey is NOT background")
	ok(ImgOps.is_bg(Color(1, 0.5, 0.5, 0.0), V, S, A), "a fully transparent pixel is background")
	ok(not ImgOps.is_bg(Color(0, 0, 0, 1), V, S, A), "opaque black is NOT background (sat guard on mx == 0)")
	# proc_line's looser checker plate keys where the cream rule would not.
	ok(ImgOps.is_bg(Color(0.8, 0.8, 0.8, 1), 0.74, 0.14, ImgOps.ALPHA_MIN_F),
		"proc_line's CHK thresholds key a mid-grey checker the cream rule keeps")
	ok(not ImgOps.is_bg(Color(0.8, 0.8, 0.8, 1), V, S, A),
		"... and the cream rule really does keep it (the two plates differ on purpose)")

## The de-duplication rewrote `c.a * 255.0 < ALPHA_MIN` as `c.a < ALPHA_MIN_F`. Prove the two
## forms agree on EVERY 8-bit alpha a real PNG can carry (Color.a is float32-backed, so this is
## a rounding claim, not an algebra one), and that ALPHA_CLEAR is a genuinely different floor.
func _test_alpha_floor_forms_agree() -> void:
	var probe := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for k in 256:
		probe.set_pixel(k, 0, Color8(255, 0, 0, k))   # saturated red: only the alpha test can fire
	var f_mismatch := 0
	var c_mismatch := 0
	var divergent := 0
	for k in 256:
		var c := probe.get_pixel(k, 0)
		if ImgOps.is_bg(c, ImgOps.BG_MAX_VAL, ImgOps.BG_MAX_SAT, ImgOps.ALPHA_MIN_F) \
				!= (c.a * 255.0 < float(ImgOps.ALPHA_MIN)):
			f_mismatch += 1
		if ImgOps.is_bg(c, ImgOps.BG_MAX_VAL, ImgOps.BG_MAX_SAT, ImgOps.ALPHA_CLEAR) != (c.a < 0.05):
			c_mismatch += 1
		if ImgOps.is_bg(c, ImgOps.BG_MAX_VAL, ImgOps.BG_MAX_SAT, ImgOps.ALPHA_MIN_F) \
				!= ImgOps.is_bg(c, ImgOps.BG_MAX_VAL, ImgOps.BG_MAX_SAT, ImgOps.ALPHA_CLEAR):
			divergent += 1
	ok(f_mismatch == 0, "ALPHA_MIN_F matches the old `c.a * 255.0 < 8` form on all 256 alphas")
	ok(c_mismatch == 0, "ALPHA_CLEAR matches the old `c.a < 0.05` form on all 256 alphas")
	# 8..12 inclusive: ALPHA_CLEAR calls them background, ALPHA_MIN does not. Kept, not unified.
	ok(divergent == 5, "the two alpha floors disagree on exactly 5 alpha levels (8..12), as documented")

func _test_premultiply_round_trip() -> void:
	var im := Image.create(4, 1, false, Image.FORMAT_RGBA8)
	im.set_pixel(0, 0, Color8(200, 100, 50, 255))
	im.set_pixel(1, 0, Color8(200, 100, 50, 128))
	im.set_pixel(2, 0, Color8(200, 100, 50, 0))     # cleared: colour must not resurrect
	im.set_pixel(3, 0, Color8(0, 0, 0, 255))
	ImgOps.premultiply(im)
	ok(im.get_pixel(2, 0) == Color(0, 0, 0, 0), "premultiply zeroes a cleared pixel's RGB")
	ok(is_equal_approx(im.get_pixel(0, 0).r, 200.0 / 255.0), "premultiply leaves an opaque pixel alone")
	ImgOps.unpremultiply(im)
	var half := im.get_pixel(1, 0)
	ok(absf(half.r - 200.0 / 255.0) < 0.01 and absf(half.g - 100.0 / 255.0) < 0.01,
		"a half-alpha pixel round-trips back to its straight colour")
	ok(im.get_pixel(2, 0) == Color(0, 0, 0, 0), "the cleared pixel stays fully clear")

## The synthetic case every processing tool relies on: a bright field, an opaque subject, and a
## bright pocket WALLED IN by the subject. The border flood must clear the field and leave the
## pocket (that is why cutout_holes exists); trim must return the subject's tight bounds.
func _test_flood_and_trim() -> void:
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))                                   # bright achromatic field
	for y in range(10, 30):
		for x in range(10, 30):
			img.set_pixel(x, y, Color(0.2, 0.6, 0.3, 1))          # opaque green subject
	for y in range(16, 24):
		for x in range(16, 24):
			img.set_pixel(x, y, Color(1, 1, 1, 1))                # enclosed white pocket
	var is_bg_fn := func(c: Color) -> bool:
		return ImgOps.is_bg(c, ImgOps.BG_MAX_VAL, ImgOps.BG_MAX_SAT, ImgOps.ALPHA_CLEAR)

	var outer := ImgOps.mark_outer_field(img, is_bg_fn)
	ok(outer[0] == 1, "mark_outer_field marks the border field")
	ok(outer[20 * 40 + 20] == 0, "mark_outer_field does NOT reach the walled-in pocket")
	ok(outer[20 * 40 + 12] == 0, "mark_outer_field does not mark the subject")

	var probe := img.duplicate() as Image
	var removed := ImgOps.flood_clear_from_border(probe, is_bg_fn)
	ok(removed == 40 * 40 - 20 * 20, "flood cleared exactly the outer field (%d px)" % removed)
	ok(probe.get_pixel(0, 0).a == 0.0, "the outer field is transparent")
	ok(probe.get_pixel(20, 20).a == 1.0, "the enclosed pocket survives the border flood")
	ok(probe.get_pixel(12, 12).a == 1.0, "the subject survives the border flood")

	ok(ImgOps.trim(probe) == Rect2i(10, 10, 20, 20), "trim returns the subject's tight bounds")
	var blank := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	blank.fill(Color(0, 0, 0, 0))
	ok(ImgOps.trim(blank).size.x == 0, "trim reports a zero-size rect when nothing is opaque")
