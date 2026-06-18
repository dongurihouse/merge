extends SceneTree
## Loads a captured board PNG and proves the play field reads as a desaturated
## sage stage (not the old saturated olive). Image.load_from_file works headless
## (it is the live-viewport get_image() that returns null headless, not file loads).
## Coordinates are FRACTIONAL so they survive resolution changes; nudge fx/fy if
## the board region moves.
##   godot --headless --path . -s res://games/grove/tools/shot_sample.gd -- /tmp/board_sage.png

func _avg_patch(img: Image, fx: float, fy: float, rad: int) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var cx := int(fx * w)
	var cy := int(fy * h)
	var acc := Color(0, 0, 0)
	var n := 0
	for y in range(cy - rad, cy + rad):
		for x in range(cx - rad, cx + rad):
			if x >= 0 and y >= 0 and x < w and y < h:
				acc += img.get_pixel(x, y)
				n += 1
	n = max(n, 1)
	return Color(acc.r / n, acc.g / n, acc.b / n)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "/tmp/board_sage.png"
	var img := Image.load_from_file(path)
	if img == null:
		print("  FAIL  could not load ", path)
		quit(1)
		return
	# A patch low-centre, inside the play field rather than on the locked frontier.
	var field := _avg_patch(img, 0.5, 0.62, 8)
	print("  field avg = %s (s=%.3f v=%.3f)" % [field, field.s, field.v])
	var pass_cond := field.s < 0.22 and field.v > 0.66
	if pass_cond:
		print("  PASS  board field reads as a desaturated sage stage")
		print("== 1 passed, 0 failed ==")
		quit(0)
	else:
		print("  FAIL  board field still saturated/dark (olive regression?)")
		print("== 0 passed, 1 failed ==")
		quit(1)
