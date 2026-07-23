extends SceneTree
## CHROMA KEYER (eng-owned; sibling to cutout_bg.gd, which keys only bright+achromatic).
## Clears every pixel within `tol` of a solid KEY colour to transparent — in place — for
## LLM sheets baked on a saturated chroma background (e.g. cyan) that the bright-only
## cutout_bg / slice_islands cannot separate. Pair with slice_islands (which is alpha-aware)
## to split the keyed sheet into one trimmed PNG per piece.
##
## Headless, pure-Image — run directly, then --import:
##   godot --headless --path . -s res://games/tools/chroma_key.gd -- <png> [png ...] key=#RRGGBB [tol=0.18]
##
## `tol` is a normalised RGB distance in [0,1]; a pixel is keyed when its distance to the
## key colour is <= tol. Alpha is set to 0 (RGB kept) so anti-aliased edges stay soft.

const DEFAULT_TOL := 0.18

## Zero the alpha (RGB kept) of every pixel within `tol` of `key`, in place. Returns the
## number of pixels cleared. Shared by the CLI entry point and the regression suite.
static func key_image(img: Image, key: Color, tol: float) -> int:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var kr := int(round(key.r * 255.0))
	var kg := int(round(key.g * 255.0))
	var kb := int(round(key.b * 255.0))
	# squared 0..255 distance threshold: (tol * 255)^2 * 3  (3 channels)
	var thr := (tol * 255.0) * (tol * 255.0) * 3.0
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()       # PackedByteArray, RGBA8, mutable copy
	var keyed := 0
	var n := w * h
	for i in n:
		var o := i * 4
		var dr := int(data[o]) - kr
		var dg := int(data[o + 1]) - kg
		var db := int(data[o + 2]) - kb
		if float(dr * dr + dg * dg + db * db) <= thr:
			data[o + 3] = 0
			keyed += 1
	# write the cleared alpha back into the caller's Image
	var out := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	img.blit_rect(out, Rect2i(0, 0, w, h), Vector2i(0, 0))
	return keyed

## HUE keying — for a sheet whose art casts a DROP SHADOW onto the key colour. A shadow over
## magenta is *darkened magenta* (e.g. #7C036E), which sits far from the key in RGB distance, so
## key_image leaves it opaque and the sprite ships with a hard black band welded to its bottom
## edge. Worse, distance cannot fix it: a mauve/purple SUBJECT is often CLOSER to #FF00FF than
## that dark shadow is, so any tolerance wide enough to catch the shadow eats the art.
##
## Hue does separate them. Excess = min(R,B) - G is huge for anything magenta-derived at ANY
## brightness (shadow 107, key 246) and small for cut-paper art (cream is negative; the deepest
## purple medallion measured 46). Two safeguards keep legitimate purple safe:
##   1. only pixels REACHED by a flood from the border are eligible — enclosed art can never key;
##   2. a soft ramp (`soft`..`hard`) feathers the boundary instead of a binary cut.
## RGB is preserved (like key_image) so a later despill pass can still see the edge tint.
## Returns the number of pixels whose alpha was reduced.
static func key_image_hue(img: Image, soft: float = 55.0, hard: float = 100.0) -> int:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var excess := PackedFloat32Array()
	excess.resize(w * h)
	for i in w * h:
		var o := i * 4
		excess[i] = float(mini(int(data[o]), int(data[o + 2])) - int(data[o + 1]))
	# flood from the border through anything even faintly key-tinted, so the shadow band (which
	# touches the border region around the art) is reachable while enclosed art is not.
	var reach := PackedByteArray()
	reach.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		for y in [0, h - 1]:
			var i0: int = y * w + x
			if excess[i0] > soft and reach[i0] == 0:
				reach[i0] = 1
				stack.append(i0)
	for y in h:
		for x in [0, w - 1]:
			var i1: int = y * w + x
			if excess[i1] > soft and reach[i1] == 0:
				reach[i1] = 1
				stack.append(i1)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var cx := i % w
		var cy := i / w
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ni: int = ny * w + nx
			if reach[ni] == 0 and excess[ni] > soft:
				reach[ni] = 1
				stack.append(ni)
	var span := maxf(1.0, hard - soft)
	var touched := 0
	for i in w * h:
		if reach[i] == 0:
			continue
		var a := clampf((excess[i] - soft) / span, 0.0, 1.0)   # 0 at the soft edge → 1 at full key
		var o := i * 4
		var new_a := int(round(float(data[o + 3]) * (1.0 - a)))
		if new_a < int(data[o + 3]):
			data[o + 3] = new_a
			touched += 1
		# DESPILL the survivors: an anti-aliased boundary pixel keeps a plum tint that would read as
		# a thin dark line along the cut. Clamp the key channels toward the subject (guide §8 step 2).
		if new_a > 16:
			var g := int(data[o + 1])
			data[o] = mini(int(data[o]), g + 15)
			data[o + 2] = mini(int(data[o + 2]), g + 15)
	var out := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	img.blit_rect(out, Rect2i(0, 0, w, h), Vector2i(0, 0))
	return touched

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var key := Color(0, 0, 0)
	var have_key := false
	var tol := DEFAULT_TOL
	var hue := false                 # hue=1 → magenta-excess mode (art with a baked drop shadow)
	var soft := 55.0
	var hard := 100.0
	var paths: Array = []
	for a in args:
		var s := String(a)
		if s.begins_with("key="):
			key = Color.html(s.substr(4))
			have_key = true
		elif s.begins_with("tol="):
			tol = float(s.substr(4))
		elif s.begins_with("hue="):
			hue = s.substr(4) != "0"
		elif s.begins_with("soft="):
			soft = float(s.substr(5))
		elif s.begins_with("hard="):
			hard = float(s.substr(5))
		else:
			paths.append(s)
	if paths.is_empty() or (not have_key and not hue):
		print("usage: chroma_key.gd -- <png> [png ...] key=#RRGGBB [tol=0.18]")
		print("       chroma_key.gd -- <png> [png ...] hue=1 [soft=55] [hard=100]   # shadow-on-key sheets")
		quit(2)
		return

	var rc := 0
	for p in paths:
		var img := Image.load_from_file(p)
		if img == null:
			print("FAIL load ", p)
			rc = 1
			continue
		var n := img.get_width() * img.get_height()
		if hue:
			var t := key_image_hue(img, soft, hard)
			img.save_png(p)
			print("chroma_key ", p, " — hue-keyed ", t, " of ", n, " px (soft=", soft, " hard=", hard, ")")
		else:
			var keyed := key_image(img, key, tol)
			img.save_png(p)
			print("chroma_key ", p, " — cleared ", keyed, " of ", n, " px (key=#",
				key.to_html(false), " tol=", tol, ")")
	quit(rc)
