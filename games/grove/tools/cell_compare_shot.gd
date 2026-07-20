extends SceneTree
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Game = preload("res://engine/scripts/core/game.gd")
func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED"); quit(2); return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var out: String = OS.get_cmdline_user_args()[0]
	const PX := 240.0
	var bg := ColorRect.new(); bg.color = Color("#7FA6B8"); bg.size = Vector2(1000, 400); root.add_child(bg)
	# 1: a board item (mushroom t1) via make_piece — the board's exact call
	var item := PieceView.make_piece(101, PX)   # line 1 (flower) t1... use a real code
	item.position = Vector2(40, 60); bg.add_child(item)
	# 2: a resident via the residents path
	var art := G.resident_art("coin", 1)   # sprout t1
	var tex := load(art) as Texture2D
	var img := tex.get_image(); var ur := img.get_used_rect()
	var at := AtlasTexture.new(); at.atlas = tex; at.region = Rect2(ur)
	var res := PieceView.make_piece_from_texture(at, PX, PieceView.ITEM_INSET)
	res.position = Vector2(360, 60); bg.add_child(res)
	# 3: a board mushroom (squarish) for reference
	var mush := PieceView.make_piece(501, PX)   # line 5 mushroom t1
	mush.position = Vector2(680, 60); bg.add_child(mush)
	await create_timer(0.5).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().get_region(Rect2i(0,0,960,360)).save_png(out)
	print("saved=%s px=%d" % [out, PX]); quit()
