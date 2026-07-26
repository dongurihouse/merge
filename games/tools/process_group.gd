extends SceneTree
## Dev tool: group-normalize a SET of tiles into clean, bottom-anchored, square PNGs that share ONE
## scale — the largest tile fills the box, the smaller tiles keep their RELATIVE size (they do NOT each
## blow up to fill). Use for a level-badge part's stages so a small wreath stays small (its individual
## leaves don't balloon). Bottom edge is a shared baseline; a small constant canvas margin is kept.
##
##   godot --headless -s res://games/tools/process_group.gd -- <size> <out1> <in1> [<out2> <in2> ...]
##
## Each <in> is a sliced tile (its background may be transparent OR a bright/checker fill); each <out>
## accepts res:// or an absolute path.

const ImgOps := preload("res://games/tools/img_ops.gd")

const MARGIN := 8              # constant transparent margin in CANVAS px (NOT scaled — preserves proportions)

# Background rule + pixel ops are shared — see games/tools/img_ops.gd.
func _is_bg(c: Color) -> bool:
	return ImgOps.is_bg(c, ImgOps.BG_MAX_VAL, ImgOps.BG_MAX_SAT, ImgOps.ALPHA_CLEAR)

## Flood-fill the background from every border, then crop tight to the opaque subject. Returns the
## cropped image (no padding — the caller adds a constant canvas margin), or null if nothing remained.
func _clean_and_trim(src: String) -> Image:
	var img := Image.load_from_file(src)
	if img == null:
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	ImgOps.flood_clear_from_border(img, _is_bg)
	var bounds := ImgOps.trim(img)
	if bounds.size.x == 0:
		return null
	var crop := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	crop.blit_rect(img, bounds, Vector2i.ZERO)
	return crop

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3 or args.size() % 2 == 0:
		print("usage: process_group <size> <out1> <in1> [<out2> <in2> ...]")
		quit(1); return
	var size := int(args[0])
	var outs: Array = []
	var crops: Array = []
	var max_long := 1
	var i := 1
	while i + 1 < args.size():
		var out_path: String = args[i]
		var in_path: String = args[i + 1]
		i += 2
		var crop := _clean_and_trim(in_path)
		if crop == null:
			print("FAIL: nothing opaque in ", in_path); quit(1); return
		outs.append(out_path)
		crops.append(crop)
		max_long = maxi(max_long, maxi(crop.get_width(), crop.get_height()))
	# ONE scale for the whole group: the largest tile fills (size − 2·margin); the rest keep relative size.
	var scale: float = float(size - 2 * MARGIN) / float(max_long)
	for k in crops.size():
		var crop: Image = crops[k]
		var nw: int = maxi(1, int(round(crop.get_width() * scale)))
		var nh: int = maxi(1, int(round(crop.get_height() * scale)))
		ImgOps.premultiply(crop)
		crop.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
		ImgOps.unpremultiply(crop)
		var canvas := Image.create(size, size, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0, 0, 0, 0))
		canvas.blit_rect(crop, Rect2i(0, 0, nw, nh), Vector2i((size - nw) / 2, size - nh - MARGIN))  # bottom-anchored
		var out_abs: String = ProjectSettings.globalize_path(outs[k]) if String(outs[k]).begins_with("res://") else String(outs[k])
		DirAccess.make_dir_recursive_absolute(out_abs.get_base_dir())
		canvas.save_png(out_abs)
		print("WROTE %s  out=%dx%d  content=%dx%d" % [out_abs, size, size, nw, nh])
	print("group scale=%.4f  (largest source long-side=%d -> %d px)" % [scale, max_long, size - 2 * MARGIN])
	quit()
