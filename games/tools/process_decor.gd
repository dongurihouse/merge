extends SceneTree
## Dev tool: process a raw LLM-generated BEDROOM DECOR image into a clean 1024x1280 layer.
## Unlike process_icon.gd, this DOES NOT trim or center — each decor piece's position on the
## canvas is the whole point (layered consistency depends on it).
##
##   godot --headless --path . -s res://games/tools/process_decor.gd -- <input.png> <output_res_path> [W H] [--opaque]
##
## Examples:
##   godot --headless --path . -s res://games/tools/process_decor.gd -- /tmp/raw.png res://games/grove/assets/rooms/decor_bed.png
##   godot --headless --path . -s res://games/tools/process_decor.gd -- /tmp/raw.png res://games/grove/assets/rooms/bedroom_base.png 1024 1280 --opaque

const ImgOps := preload("res://games/tools/img_ops.gd")

const W := 1024
const H := 1280

# Background rule is shared — see games/tools/img_ops.gd.
func _is_bg(c: Color) -> bool:
	return ImgOps.is_bg(c, ImgOps.BG_MAX_VAL, ImgOps.BG_MAX_SAT, ImgOps.ALPHA_CLEAR)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: process_decor <input.png> <output_res_or_abs> [W H] [--opaque]")
		quit(1); return
	var src: String = args[0]
	var out: String = args[1]
	var tw: int = W
	var th: int = H
	var opaque := false
	var ai := 2
	if args.size() >= ai + 2 and args[ai].is_valid_int() and args[ai + 1].is_valid_int():
		tw = int(args[ai]); th = int(args[ai + 1]); ai += 2
	var cover := false
	while ai < args.size():
		if args[ai] == "--opaque":
			opaque = true
		elif args[ai] == "--cover":
			cover = true       # scale to FILL the target and center-crop (no letterbox bars)
		ai += 1

	var out_abs: String = ProjectSettings.globalize_path(out) if out.begins_with("res://") else out

	var img := Image.load_from_file(src)
	if img == null:
		print("FAIL: cannot load ", src); quit(1); return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var iw := img.get_width()
	var ih := img.get_height()
	var removed := 0
	if not opaque:
		# flood-fill the background from every border pixel — keeps the subject IN PLACE
		removed = ImgOps.flood_clear_from_border(img, _is_bg)

	# resize to the target canvas. Default = letterbox (CONTAIN, preserves whole image);
	# --cover = scale to fill + center-crop (full-bleed surfaces like maps — no pad bars).
	var src_ar := float(iw) / float(ih)
	var dst_ar := float(tw) / float(th)
	var canvas := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0) if not opaque else Color(0.95, 0.93, 0.88, 1.0))   # cream pad for opaque base
	if cover:
		var fill_w := tw
		var fill_h := th
		if src_ar > dst_ar:
			fill_w = int(round(float(th) * src_ar))
		else:
			fill_h = int(round(float(tw) / src_ar))
		img.resize(fill_w, fill_h, Image.INTERPOLATE_LANCZOS)
		canvas.blit_rect(img, Rect2i((fill_w - tw) / 2, (fill_h - th) / 2, tw, th), Vector2i.ZERO)
	else:
		var fit_w := tw
		var fit_h := th
		if src_ar > dst_ar:
			fit_h = int(round(float(tw) / src_ar))
		else:
			fit_w = int(round(float(th) * src_ar))
		img.resize(fit_w, fit_h, Image.INTERPOLATE_LANCZOS)
		canvas.blit_rect(img, Rect2i(0, 0, fit_w, fit_h), Vector2i((tw - fit_w) / 2, (th - fit_h) / 2))

	DirAccess.make_dir_recursive_absolute(out_abs.get_base_dir())
	canvas.save_png(out_abs)
	print("WROTE %s  removed_bg_px=%d  src=%dx%d  out=%dx%d  opaque=%s" % [out_abs, removed, iw, ih, tw, th, str(opaque)])
	quit()
