extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): prove the code-drawn CutPaperPanel scales to any size
## with no stretch — render several very different rectangles side by side on the sky.
##   quiet_godot.sh --path . -s res://games/grove/tools/cutpaper_shot.gd -- /tmp/cutpaper.png

const CutPaper = preload("res://engine/scripts/ui/cut_paper.gd")
const TILE := "res://games/grove/assets/ui/dialogs/paper_tile_cream.png"

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via engine/tools/quiet_godot.sh"); quit(2); return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() >= 1 else "/tmp/cutpaper.png"
	await create_timer(0.2).timeout
	DisplayServer.window_set_size(Vector2i(1000, 900))
	await create_timer(0.2).timeout

	var root := get_root()
	var bg := ColorRect.new()
	bg.color = Color("#6FA9C0")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var tile := load(TILE) as Texture2D
	# a big portrait sheet, a wide bar, a small square, and a tiny cell — same code, no stretch
	var rects := [
		{"pos": Vector2(40, 40), "size": Vector2(360, 560)},
		{"pos": Vector2(440, 40), "size": Vector2(520, 150)},
		{"pos": Vector2(440, 230), "size": Vector2(230, 230)},
		{"pos": Vector2(710, 230), "size": Vector2(120, 120)},
		{"pos": Vector2(440, 500), "size": Vector2(520, 340)},
	]
	for r in rects:
		var p: Control = CutPaper.new()
		p.position = r["pos"]
		p.size = r["size"]
		p.custom_minimum_size = r["size"]
		p.paper_tex = tile
		root.add_child(p)

	await create_timer(0.5).timeout
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("wrote ", out, " ", img.get_size())
	quit(0)
