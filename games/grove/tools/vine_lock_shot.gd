extends SceneTree
## Dev tool (REAL renderer; run via engine/tools/quiet_godot.sh): render the home/farmhouse map so
## the purple "locked region" cover can be eyeballed for real. Captures two frames to <out_prefix>:
##   _locked.png  — fresh save: every region still locked, so the whole map wears the purple veil.
##   _r0open.png  — region 0's spot bought, so that one region is clear of vines + purple.
##   engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/vine_lock_shot.gd -- /tmp/vine_lock

const G = preload("res://engine/scripts/core/content.gd")

const W := 1080
const H := 1920

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via engine/tools/quiet_godot.sh (born-minimized, no-focus window).")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var uargs := OS.get_cmdline_user_args()
	var prefix: String = String(uargs[0]) if uargs.size() >= 1 else "/tmp/vine_lock"

	await create_timer(0.2).timeout
	DisplayServer.window_set_size(Vector2i(W, H))
	await create_timer(0.2).timeout

	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(hx)
	if hx.content == null:
		hx._ready()
	await create_timer(0.1).timeout
	hx._open_map(G.hub_map())
	await create_timer(0.25).timeout

	# a patch that sits inside a locked (bottom-right) region, and a control patch over the always-
	# owned house area. Measured below to PROVE the cover shifts the locked patch toward #AFA9EC.
	var locked_patch := Rect2i(480, 1150, 140, 140)
	var house_patch := Rect2i(360, 470, 120, 120)

	# (1) the real look: every still-locked region wears vines + the purple cover.
	await _shot(prefix + "_locked.png")

	# (2) isolate the cover: zero the four vine layers so ONLY the purple veil remains.
	_zero_vines(hx)
	await create_timer(0.1).timeout
	var cover := await _shot(prefix + "_coveronly.png")
	print("  cover-only  locked-patch mean = %s" % [_mean(cover, locked_patch)])
	print("  cover-only  house-patch  mean = %s" % [_mean(cover, house_patch)])

	# (3) buy EVERY region's spot → fully clean art, no vines, no cover. The baseline to diff against.
	for i in range(G.MAPS[G.hub_map()].spots.size()):
		hx.unlocks["%s_r%d" % [String(G.MAPS[G.hub_map()].id), i]] = true
	hx._build_map()
	await create_timer(0.25).timeout
	var clean := await _shot(prefix + "_allopen.png")
	print("  all-open    locked-patch mean = %s" % [_mean(clean, locked_patch)])
	print("  all-open    house-patch  mean = %s" % [_mean(clean, house_patch)])
	quit()

func _zero_vines(hx) -> void:
	var vv: Control = hx.content.find_child("VineMapView", true, false)
	if vv == null:
		return
	for entry in vv.region_overlays:
		for pair in [["glow", "opacity"], ["vines", "opacity"], ["shadow", "shadow_opacity"], ["embers", "ember_opacity"]]:
			var rect := entry.get(pair[0]) as TextureRect
			if rect != null:
				(rect.material as ShaderMaterial).set_shader_parameter(pair[1], 0.0)

func _mean(img: Image, r: Rect2i) -> Vector3:
	var acc := Vector3.ZERO
	var n := 0
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			var c := img.get_pixel(x, y)
			acc += Vector3(c.r, c.g, c.b)
			n += 1
	return acc / float(maxi(n, 1))

func _shot(path: String) -> Image:
	RenderingServer.force_draw()
	await create_timer(0.1).timeout
	RenderingServer.force_draw()
	await create_timer(0.05).timeout
	var img := root.get_texture().get_image()
	var err := img.save_png(path)
	print("VINE LOCK saved=%s err=%d size=%dx%d" % [path, err, img.get_width(), img.get_height()])
	return img
