extends SceneTree
## Quick headless montage of item sprites into a labeled grid PNG (for Dev review).
## Pure-Image, no renderer:
##   godot --headless --path . -s res://games/tools/montage.gd -- <out.png> <cell> <bg_hex> <row:base,base,...> ...
## Each row arg = "<rowlabel>:flower" expands to flower_1..flower_8 across columns.

const ITEMS := "res://games/grove/assets/items/%s_%d.png"

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 4:
		print("usage: montage.gd -- <out.png> <cell> <bg_hex> <base> [base ...]"); quit(2); return
	var out := String(a[0])
	var cell := int(a[1])
	var bg := Color(String(a[2]))
	var bases: Array = a.slice(3)
	var cols := 8
	var rows := bases.size()
	var gap := 8
	var W := cols * cell + (cols + 1) * gap
	var H := rows * cell + (rows + 1) * gap
	var canvas := Image.create(W, H, false, Image.FORMAT_RGBA8)
	canvas.fill(bg)
	for r in rows:
		var base := String(bases[r])
		for c in cols:
			var p: String = ITEMS % [base, c + 1]
			var gp := ProjectSettings.globalize_path(p)
			if not FileAccess.file_exists(gp):
				continue
			var im := Image.load_from_file(gp)
			if im == null:
				continue
			im.convert(Image.FORMAT_RGBA8)
			im.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
			var x := gap + c * (cell + gap)
			var y := gap + r * (cell + gap)
			canvas.blend_rect(im, Rect2i(0, 0, cell, cell), Vector2i(x, y))
	var oabs := ProjectSettings.globalize_path(out) if out.begins_with("res://") else out
	canvas.save_png(oabs)
	print("WROTE %s  %dx%d  rows=%s" % [oabs, W, H, str(bases)])
	quit()
