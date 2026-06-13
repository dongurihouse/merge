extends SceneTree
## Dev tool: turn the generated glyph atlas (assets/fonts/ui_glyph_atlas.png + .json)
## into a Godot-native BMFont (assets/fonts/ui.fnt). Measures each glyph's ink bbox
## from the alpha channel so the font is PROPORTIONAL (snug horizontal spacing) instead
## of a wide monospace. Run once whenever the atlas changes, then --import:
##   godot --path . -s res://tools/build_font.gd
##   godot --headless --path . --import
## ui_font.gd loads res://assets/fonts/ui.fnt automatically.

const DIR := "res://assets/fonts/"
const ALPHA_MIN := 0.20   # pixels above this count as ink (shaves the faint shadow fringe)
const SIDE := 6           # px of breathing room on each side of a glyph (tighter tracking)
const SPACE_FRAC := 0.34  # space width as a fraction of the cell

func _initialize() -> void:
	var json_str := FileAccess.get_file_as_string(DIR + "ui_glyph_atlas.json")
	if json_str == "":
		print("FAIL: cannot read ui_glyph_atlas.json"); quit(1); return
	var data: Dictionary = JSON.parse_string(json_str)
	var cell: Array = data["cell_size"]
	var cw := int(cell[0])
	var ch := int(cell[1])
	var cols := int(data["columns"])
	var order: Array = data["glyph_order"]

	var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + "ui_glyph_atlas.png"))
	if img == null:
		print("FAIL: cannot load ui_glyph_atlas.png"); quit(1); return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var W := img.get_width()
	var H := img.get_height()
	var baseline := int(round(ch * 0.80))
	var space_adv := int(round(cw * SPACE_FRAC))

	var lines: Array = []
	for i in order.size():
		var name: String = order[i]
		var cp := 32 if name == "SPACE" else name.unicode_at(0)
		var ox := (i % cols) * cw
		var oy := (i / cols) * ch
		# ink bounding box within this cell
		var minx := cw
		var miny := ch
		var maxx := -1
		var maxy := -1
		if name != "SPACE":
			for yy in ch:
				for xx in cw:
					if img.get_pixel(ox + xx, oy + yy).a > ALPHA_MIN:
						minx = min(minx, xx); maxx = max(maxx, xx)
						miny = min(miny, yy); maxy = max(maxy, yy)
		if maxx < 0:
			# blank cell (SPACE or empty) → zero-size glyph with a sensible advance
			lines.append("char id=%d x=0 y=0 width=0 height=0 xoffset=0 yoffset=%d xadvance=%d page=0 chnl=15" % [cp, baseline, space_adv])
			continue
		var iw := maxx - minx + 1
		var ih := maxy - miny + 1
		lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15" \
			% [cp, ox + minx, oy + miny, iw, ih, SIDE, miny, iw + SIDE * 2])

	var fnt := ""
	fnt += "info face=\"TidyUp\" size=%d bold=0 italic=0 charset=\"\" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=0,0 outline=0\n" % ch
	fnt += "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0\n" % [ch, baseline, W, H]
	fnt += "page id=0 file=\"ui_glyph_atlas.png\"\n"
	fnt += "chars count=%d\n" % lines.size()
	for l in lines:
		fnt += l + "\n"

	var f := FileAccess.open(DIR + "ui.fnt", FileAccess.WRITE)
	f.store_string(fnt)
	f.close()
	print("WROTE ui.fnt  glyphs=%d  cell=%dx%d  baseline=%d  atlas=%dx%d" % [lines.size(), cw, ch, baseline, W, H])
	quit()
