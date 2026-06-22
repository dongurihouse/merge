extends SceneTree
## Standalone FX look-test (REAL renderer; run via engine/tools/quiet_godot.sh):
## plays a one-shot "breaking glass" effect on a single subject and samples it across
## its lifetime into a horizontal film-strip PNG — so an animation is judged from
## many frames, not one screenshot. SELF-CONTAINED: the shatter look lives here
## inline (no fx.gd / game-state deps) and renders into a fixed-size SubViewport
## (independent of the project's window stretch), so you can tune the FEEL here
## first, then promote the verified version into FX.shatter.
##   make shot TOOL=engine/tools/fx_demo ARGS="/tmp/shatter.png"

const Save = preload("res://engine/scripts/core/save.gd")

const CELL := 280          # per-frame capture size (square)
const FRAMES := 8          # samples across the animation
const STEP := 0.06         # seconds between samples
const SHARDS := 18

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via engine/tools/quiet_godot.sh  (make shot TOOL=engine/tools/fx_demo ARGS=\"/tmp/shatter.png\")")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	Save.configure_for_test("/tmp/tu_fx_demo/")

	var uargs := OS.get_cmdline_user_args()
	var out: String = String(uargs[0]) if uargs.size() >= 1 else "/tmp/fx_demo.png"

	# Render the scene into a fixed CELL×CELL viewport — what we capture is exactly
	# this size regardless of the host window / project content-scale.
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var bg := ColorRect.new()
	bg.color = Color("#2A2A1E")
	bg.size = Vector2(CELL, CELL)
	vp.add_child(bg)

	# the subject the effect acts on, centered
	var subject := ColorRect.new()
	subject.color = Color("#CFE3EE")            # pale glass
	subject.size = Vector2(120, 120)
	subject.position = (Vector2(CELL, CELL) - subject.size) * 0.5
	vp.add_child(subject)

	await create_timer(0.2).timeout
	_shatter(vp, subject)

	# capture FRAMES samples left-to-right into one strip
	var strip := Image.create(CELL * FRAMES, CELL, false, Image.FORMAT_RGBA8)
	for i in FRAMES:
		RenderingServer.force_draw()
		await create_timer(STEP).timeout
		var frame := vp.get_texture().get_image()
		frame.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(CELL * i, 0))
	var err := strip.save_png(out)
	print("FX strip saved=%s err=%d size=%dx%d (%d frames @ %.0fms)" % [out, err, strip.get_width(), strip.get_height(), FRAMES, STEP * 1000.0])
	quit()


# --- the effect under test (inline; promote to FX.shatter once the feel is right) ---
func _shatter(host: Node, node: Control) -> void:
	var center := node.position + node.size * 0.5

	# 1. the pane cracks: a quick shake, then fade + shrink away
	node.pivot_offset = node.size * 0.5
	var t := node.create_tween()
	t.tween_property(node, "rotation", 0.10, 0.05)
	t.tween_property(node, "rotation", -0.08, 0.05)
	t.tween_property(node, "rotation", 0.0, 0.04)
	t.set_parallel(true)
	t.tween_property(node, "modulate:a", 0.0, 0.22).set_ease(Tween.EASE_IN)
	t.tween_property(node, "scale", Vector2(0.82, 0.82), 0.22)

	# 2. shard spray — GPUParticles2D burst, same machinery as FX.burst()
	var p := GPUParticles2D.new()
	p.texture = _shard_texture()
	p.position = center
	p.amount = SHARDS
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.z_index = 100
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 6.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, 520.0, 0)            # shards fall
	mat.initial_velocity_min = 160.0
	mat.initial_velocity_max = 360.0
	mat.angular_velocity_min = -540.0             # spin = glittery tumble
	mat.angular_velocity_max = 540.0
	mat.scale_min = 0.35
	mat.scale_max = 0.95
	mat.color = Color("#E8F4FB")
	p.process_material = mat
	host.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


# a small bright sliver (elongated diamond) that reads as a glass shard
func _shard_texture() -> Texture2D:
	var n := 24
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var nx: float = (x - c) / c
			var ny: float = (y - c) / c
			# thin diamond: narrow in x, long in y → a sliver
			var d: float = absf(nx) * 2.6 + absf(ny) * 1.0
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a * 2.0, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
