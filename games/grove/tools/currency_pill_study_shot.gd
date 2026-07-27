extends SceneTree
## Real-renderer capture for CurrencyPillStudy.tscn at the mock's native 941x160 crop.
##
## Run quietly so the review tool never steals focus:
##   engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/currency_pill_study_shot.gd -- /tmp/currency_pills.png

const Base = preload("res://engine/tools/shot_base.gd")

const SCENE_PATH := "res://games/grove/tools/CurrencyPillStudy.tscn"
const CAPTURE_SIZE := Vector2i(941, 160)


func _initialize() -> void:
	# The study is a 941x160 REFERENCE crop, not the design canvas, so the project's canvas_items
	# stretch is switched off BEFORE begin() forces the window size — otherwise root reports the
	# design viewport instead of the window and _apply_size retries a size that can never match.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	# The study reads no save state, so it takes no temp save dir (save: false).
	var ctx := await Base.begin(self, {"tool": "currency_pill_study", "size": CAPTURE_SIZE,
		"default_out": "/tmp/currency_pill_study.png", "save": false})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var out: String = ctx["out"]

	var study := load(SCENE_PATH).instantiate() as Control
	study.position = Vector2.ZERO
	study.size = Vector2(CAPTURE_SIZE)
	root.add_child(study)
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	study.position = Vector2.ZERO     # re-assert: the scene's own layout may have moved itself
	study.size = Vector2(CAPTURE_SIZE)

	var error := Base.capture(self, out, ctx["args"], Rect2i(Vector2i.ZERO, CAPTURE_SIZE))
	print("CURRENCY_PILL_STUDY saved=%s size=%s error=%d" % [out, str(CAPTURE_SIZE), error])
	quit(0 if error == OK else 1)
