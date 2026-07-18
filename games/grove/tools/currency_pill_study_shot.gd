extends SceneTree
## Real-renderer capture for CurrencyPillStudy.tscn at the mock's native 941x160 crop.
##
## Run quietly so the review tool never steals focus:
##   engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/currency_pill_study_shot.gd -- /tmp/currency_pills.png

const SCENE_PATH := "res://games/grove/tools/CurrencyPillStudy.tscn"
const CAPTURE_SIZE := Vector2i(941, 160)


func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run currency_pill_study_shot.gd through engine/tools/quiet_godot.sh")
		quit(2)
		return

	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_size(CAPTURE_SIZE)

	var args := OS.get_cmdline_user_args()
	var output := String(args[0]) if not args.is_empty() else "/tmp/currency_pill_study.png"
	var study := load(SCENE_PATH).instantiate() as Control
	study.position = Vector2.ZERO
	study.size = Vector2(CAPTURE_SIZE)
	root.add_child(study)
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	study.position = Vector2.ZERO
	study.size = Vector2(CAPTURE_SIZE)
	RenderingServer.force_draw()

	var frame := root.get_texture().get_image()
	var crop := frame.get_region(Rect2i(Vector2i.ZERO, CAPTURE_SIZE))
	var error := crop.save_png(output)
	print("CURRENCY_PILL_STUDY saved=%s size=%s error=%d" % [output, str(crop.get_size()), error])
	quit(0 if error == OK else 1)
