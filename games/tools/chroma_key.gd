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

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var key := Color(0, 0, 0)
	var have_key := false
	var tol := DEFAULT_TOL
	var paths: Array = []
	for a in args:
		var s := String(a)
		if s.begins_with("key="):
			key = Color.html(s.substr(4))
			have_key = true
		elif s.begins_with("tol="):
			tol = float(s.substr(4))
		else:
			paths.append(s)
	if paths.is_empty() or not have_key:
		print("usage: chroma_key.gd -- <png> [png ...] key=#RRGGBB [tol=0.18]")
		quit(2)
		return

	var kr := int(round(key.r * 255.0))
	var kg := int(round(key.g * 255.0))
	var kb := int(round(key.b * 255.0))
	# squared 0..255 distance threshold: (tol * 255)^2 * 3  (3 channels)
	var thr := (tol * 255.0) * (tol * 255.0) * 3.0
	var rc := 0
	for p in paths:
		var img := Image.load_from_file(p)
		if img == null:
			print("FAIL load ", p)
			rc = 1
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
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
		var out := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
		out.save_png(p)
		print("chroma_key ", p, " — cleared ", keyed, " of ", n, " px (key=#",
			key.to_html(false), " tol=", tol, ")")
	quit(rc)
