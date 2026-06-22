extends SceneTree
## Standalone breaking-glass look-test (REAL renderer).
##   make fx                                                       → live looping window
##   make shot TOOL=engine/tools/fx_demo ARGS="/tmp/shatter.png"   → headless film-strip
##
## ANNEALED (dramatic) glass: the pane fractures from an IMPACT POINT into radial-spoke +
## concentric-ring shards (small sharp wedges near the impact, larger segments outward),
## tiling the pane exactly so the pre-break hold reads as a cracked pane. On release each
## shard flies outward (inner = faster, from impact energy), tumbles with a fake-3D edge
## flicker, glints (break-flash + specular spin), slides to rest (top-down drag, no
## gravity), and fades. A puff of fine glass dust sprays under the shards.
## Self-contained (no fx.gd / game-state deps) — tune here, then promote into FX.shatter.

const Save = preload("res://engine/scripts/core/save.gd")

const CELL := 300          # per-frame capture size (square)
const FRAMES := 9          # film-strip samples (frame 0 = cracked-but-intact pane)
const STEP := 0.07
const SPOKES_MIN := 8      # radial cracks from the impact point
const SPOKES_MAX := 11
const RING_FRACS := [0.0, 0.24, 0.54, 0.92, 1.28]   # concentric ring radii (×reach); dense near impact
const IMPACT_OFF := 0.16   # impact point offset from pane center (×side)
const FILL := Color(0.82, 0.90, 0.96, 0.50)         # pale translucent glass
const EDGE := Color(1, 1, 1, 0.85)                  # bright crack-line edges


func _initialize() -> void:
	Save.configure_for_test("/tmp/tu_fx_demo/")
	if FileAccess.file_exists("res://override.cfg"):
		_capture()
	else:
		_live()


func _live() -> void:
	DisplayServer.window_set_title("FX demo — breaking glass (close window to quit)")
	var view: Vector2 = root.get_visible_rect().size
	var bg := ColorRect.new()
	bg.color = Color("#2A2A1E")
	bg.size = view
	root.add_child(bg)
	var center := view * 0.5
	var side: float = minf(view.x, view.y) * 0.34
	var n := 0
	while true:
		var field := _spawn_pane_in(root, center, side, n)
		await create_timer(0.45).timeout      # cracked pane holds a beat...
		field.release()                        # ...then it shatters
		await create_timer(1.8).timeout
		field.queue_free()
		n += 1


func _capture() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var uargs := OS.get_cmdline_user_args()
	var out: String = String(uargs[0]) if uargs.size() >= 1 else "/tmp/fx_demo.png"

	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#2A2A1E")
	bg.size = Vector2(CELL, CELL)
	vp.add_child(bg)

	var center := Vector2(CELL, CELL) * 0.5
	var field := _spawn_pane_in(vp, center, 130.0, 0)
	await create_timer(0.2).timeout

	var strip := Image.create(CELL * FRAMES, CELL, false, Image.FORMAT_RGBA8)
	for i in FRAMES:
		RenderingServer.force_draw()
		await create_timer(STEP).timeout
		var frame := vp.get_texture().get_image()
		frame.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(CELL * i, 0))
		if i == 0:
			field.release()                    # frame 0 = cracked pane, then break
	var err := strip.save_png(out)
	print("FX strip saved=%s err=%d size=%dx%d (%d frames @ %.0fms)" % [out, err, strip.get_width(), strip.get_height(), FRAMES, STEP * 1000.0])
	quit()


func _spawn_pane_in(host: Node, center: Vector2, side: float, n: int) -> ShatterField:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337 + n * 17
	var pane := _square(center, side)
	var impact := center + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * side * IMPACT_OFF
	var reach := 0.0
	for v in pane:
		reach = maxf(reach, (v - impact).length())
	var cells := _radial_fracture(pane, impact, reach, rng)
	var field := ShatterField.new()
	host.add_child(field)
	field.build(cells, impact, reach, rng)
	return field


# the original polygon (swap for any convex shape — the fracture follows it)
func _square(center: Vector2, side: float) -> Array:
	var h := side * 0.5
	return [center + Vector2(-h, -h), center + Vector2(h, -h),
			center + Vector2(h, h), center + Vector2(-h, h)]


# Radial spokes + concentric rings from the impact point. Shared vertices on a polar
# grid → cells tile the pane exactly. Outer cells are clipped to the pane outline.
func _radial_fracture(pane: Array, impact: Vector2, reach: float, rng: RandomNumberGenerator) -> Array:
	var spokes: int = rng.randi_range(SPOKES_MIN, SPOKES_MAX)
	var a0 := rng.randf_range(0.0, TAU)
	var angs: Array = []
	for i in spokes:
		angs.append(a0 + TAU * i / spokes + rng.randf_range(-0.14, 0.14))   # straight, jittered spokes

	var rings: int = RING_FRACS.size()
	# polar vertex grid: vgrid[j][i]. Ring 0 collapses to the impact point.
	var vgrid: Array = []
	for j in rings:
		var row: Array = []
		for i in spokes:
			var rr: float = reach * float(RING_FRACS[j])
			if j > 0:
				rr *= rng.randf_range(0.88, 1.12)          # wavy concentric cracks
			row.append(impact + Vector2.from_angle(angs[i]) * rr)
		vgrid.append(row)

	var cells: Array = []
	for j in rings - 1:
		for i in spokes:
			var i2 := (i + 1) % spokes
			var quad := [vgrid[j][i], vgrid[j][i2], vgrid[j + 1][i2], vgrid[j + 1][i]]
			var cell := _clip_to_convex(_dedupe(quad), pane)
			if cell.size() >= 3:
				cells.append(cell)
	return cells


# Sutherland–Hodgman clip of `subject` to convex `clip` polygon (keep interior side).
func _clip_to_convex(subject: Array, clip: Array) -> Array:
	var c := _centroid(clip)
	var out: Array = subject
	for k in clip.size():
		var a: Vector2 = clip[k]
		var b: Vector2 = clip[(k + 1) % clip.size()]
		var edge := b - a
		var nrm := Vector2(-edge.y, edge.x)
		if nrm.dot(c - a) < 0.0:
			nrm = -nrm                                  # point inward
		out = _clip_halfplane(out, a, nrm)
		if out.size() < 3:
			break
	return out

func _clip_halfplane(poly: Array, p: Vector2, n: Vector2) -> Array:
	var out: Array = []
	var cnt := poly.size()
	for k in cnt:
		var a: Vector2 = poly[k]
		var b: Vector2 = poly[(k + 1) % cnt]
		var da := (a - p).dot(n)
		var db := (b - p).dot(n)
		if da >= 0.0:
			out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			var t := da / (da - db)
			out.append(a + (b - a) * t)
	return out

func _dedupe(poly: Array) -> Array:
	var out: Array = []
	for v in poly:
		if out.is_empty() or out[out.size() - 1].distance_to(v) > 0.5:
			out.append(v)
	return out

func _centroid(poly: Array) -> Vector2:
	var c := Vector2.ZERO
	for v in poly:
		c += v
	return c / poly.size()


# =====================================================================================
class ShatterField extends Node2D:
	var _pieces: Array = []
	var _drag := 3.0               # top-down: slide out, friction to rest (no gravity)
	var _spin_drag := 2.4
	var _released := false
	var _impact := Vector2.ZERO

	func build(cells: Array, impact: Vector2, reach: float, rng: RandomNumberGenerator) -> void:
		_impact = impact
		for cell in cells:
			var cen := _centroid(cell)
			var local := PackedVector2Array()
			for v in cell:
				local.append(v - cen)

			var pg := Polygon2D.new()
			pg.polygon = local
			pg.color = FILL
			pg.position = cen
			var border := PackedVector2Array(local)
			border.append(local[0])
			var ln := Line2D.new()
			ln.points = border
			ln.width = maxf(1.4, reach * 0.013)
			ln.default_color = EDGE
			ln.joint_mode = Line2D.LINE_JOINT_ROUND
			pg.add_child(ln)
			add_child(pg)

			# direction: radially outward from the impact (slight scatter)
			var dir := cen - impact
			dir = dir.normalized() if dir.length() > 4.0 else Vector2.from_angle(rng.randf_range(0.0, TAU))
			dir = dir.rotated(rng.randf_range(-0.5, 0.5))
			dir = (dir + Vector2.from_angle(rng.randf_range(0.0, TAU)) * 0.28).normalized()
			# impact energy: shards nearer the impact fly faster
			var distf := clampf((cen - impact).length() / maxf(reach, 1.0), 0.0, 1.0)
			var speed := lerpf(440.0, 150.0, distf) * rng.randf_range(0.8, 1.2)
			_pieces.append({
				"node": pg, "vel": dir * speed,
				"ang": rng.randf_range(-8.0, 8.0),
				"life": rng.randf_range(0.85, 1.25), "max_life": 1.25,
				"fade": 0.5, "age": 0.0, "phase": rng.randf() * TAU,
			})

	func release() -> void:
		_released = true
		_emit_dust()

	func _process(delta: float) -> void:
		if not _released:
			return
		for p in _pieces:
			var node = p["node"]
			if not is_instance_valid(node):
				continue
			p["age"] += delta
			p["vel"] *= exp(-_drag * delta)
			node.position += p["vel"] * delta
			p["ang"] *= exp(-_spin_drag * delta)
			node.rotation += p["ang"] * delta

			# tumble: shrink for depth + squash X to fake passing edge-on
			var t := clampf(p["age"] / p["max_life"], 0.0, 1.0)
			var shrink := lerpf(1.0, 0.74, t)
			var flick := 1.0 - 0.5 * absf(sin(node.rotation * 1.3 + p["phase"]))
			node.scale = Vector2(shrink * flick, shrink)

			# glint: a bright flash at the break, then occasional specular as it spins
			var flash := maxf(0.0, 1.0 - p["age"] / 0.14) * 0.9
			var spec := pow(maxf(0.0, sin(node.rotation * 1.7 + p["phase"])), 14) * 0.6
			node.color = FILL.lerp(Color(1, 1, 1, 0.94), clampf(maxf(flash, spec), 0.0, 1.0))

			p["life"] -= delta
			if p["life"] <= p["fade"]:
				node.modulate.a = clampf(p["life"] / p["fade"], 0.0, 1.0)
			if p["life"] <= 0.0:
				node.queue_free()
				p["node"] = null

	# fine glass dust sprayed from the impact, under the shards
	func _emit_dust() -> void:
		var p := GPUParticles2D.new()
		p.texture = _speck_texture()
		p.position = _impact
		p.z_index = -1
		p.amount = 30
		p.lifetime = 0.55
		p.one_shot = true
		p.explosiveness = 1.0
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 4.0
		mat.direction = Vector3(0, -1, 0)
		mat.spread = 180.0
		mat.gravity = Vector3.ZERO                    # top-down
		mat.damping_min = 120.0                       # friction to rest
		mat.damping_max = 220.0
		mat.initial_velocity_min = 90.0
		mat.initial_velocity_max = 320.0
		mat.scale_min = 0.15
		mat.scale_max = 0.5
		mat.color = Color(1, 1, 1, 0.8)
		p.process_material = mat
		add_child(p)
		p.emitting = true
		p.finished.connect(p.queue_free)

	func _speck_texture() -> Texture2D:
		var n := 16
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := (n - 1) / 2.0
		for y in n:
			for x in n:
				var d := Vector2(x - c, y - c).length() / c
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
		return ImageTexture.create_from_image(img)

	func _centroid(poly: Array) -> Vector2:
		var c := Vector2.ZERO
		for v in poly:
			c += v
		return c / poly.size()
