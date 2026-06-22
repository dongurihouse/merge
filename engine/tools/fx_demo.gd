extends SceneTree
## Standalone breaking-glass look-test (REAL renderer).
##   make fx                                              → live looping window (watch it)
##   make shot TOOL=engine/tools/fx_demo ARGS="/tmp/shatter.png"   → headless film-strip
##
## The shatter is a real POLYGON FRACTURE, not particles: a square pane is split into
## Voronoi cells clipped to the pane (so every piece is literally a chunk of the original
## polygon, and the pieces tile it exactly), then each piece flies outward, spins, falls
## under gravity, and fades. Self-contained (no fx.gd / game-state deps) so the feel can
## be tuned here, then promoted into FX.shatter.

const Save = preload("res://engine/scripts/core/save.gd")

const CELL := 300          # per-frame capture size (square)
const FRAMES := 9          # samples across the animation (frame 0 = intact pane)
const STEP := 0.07         # seconds between samples
const COLS := 4            # seed grid → ~COLS*ROWS pieces (kept chunky, not dust)
const ROWS := 3
const FILL := Color(0.83, 0.91, 0.96, 0.52)   # pale translucent glass
const EDGE := Color(1, 1, 1, 0.85)            # bright crack-line edges


func _initialize() -> void:
	Save.configure_for_test("/tmp/tu_fx_demo/")
	if FileAccess.file_exists("res://override.cfg"):
		_capture()       # quiet, born-minimized → film-strip PNG
	else:
		_live()          # a real, focusable window that replays on a loop


# --- live: a real window, replaying the effect on a loop (close it to quit) ---------
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
		var field := _spawn_pane(center, side, n)
		await create_timer(0.35).timeout      # the intact pane sits a beat...
		field.release()                        # ...then it shatters
		await create_timer(1.7).timeout
		field.queue_free()
		n += 1


# --- capture: sample the effect into a film-strip PNG --------------------------------
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
			field.release()                    # frame 0 = intact pane, then break
	var err := strip.save_png(out)
	print("FX strip saved=%s err=%d size=%dx%d (%d frames @ %.0fms)" % [out, err, strip.get_width(), strip.get_height(), FRAMES, STEP * 1000.0])
	quit()


func _spawn_pane(center: Vector2, side: float, n: int) -> ShatterField:
	return _spawn_pane_in(root, center, side, n)

func _spawn_pane_in(host: Node, center: Vector2, side: float, n: int) -> ShatterField:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337 + n * 17                    # deterministic per run; varies the live loop
	var base := _square(center, side)
	var seeds := _jittered_seeds(center, side, rng)
	var field := ShatterField.new()
	host.add_child(field)
	field.build(base, seeds, center, side, rng)
	return field


# the original polygon (swap this for any convex shape — pieces follow it)
func _square(center: Vector2, side: float) -> Array:
	var h := side * 0.5
	return [center + Vector2(-h, -h), center + Vector2(h, -h),
			center + Vector2(h, h), center + Vector2(-h, h)]

# fracture seeds: a jittered grid inside the pane → organic, chunky cells
func _jittered_seeds(center: Vector2, side: float, rng: RandomNumberGenerator) -> Array:
	var tl := center - Vector2(side, side) * 0.5
	var cw := side / COLS
	var ch := side / ROWS
	var pts: Array = []
	for r in ROWS:
		for c in COLS:
			var jx := rng.randf_range(-0.42, 0.42) * cw
			var jy := rng.randf_range(-0.42, 0.42) * ch
			pts.append(tl + Vector2((c + 0.5) * cw + jx, (r + 0.5) * ch + jy))
	return pts


# =====================================================================================
# Voronoi fracture + flyaway physics
# =====================================================================================
class ShatterField extends Node2D:
	var _pieces: Array = []        # [{node, vel, ang, life, max_life, fade}]
	var _drag := 3.2               # top-down: shards slide out and decelerate to rest (no gravity)
	var _spin_drag := 2.6
	var _released := false

	func build(base: Array, seeds: Array, center: Vector2, side: float, rng: RandomNumberGenerator) -> void:
		var edge_w: float = maxf(1.5, side * 0.018)
		for i in seeds.size():
			var cell: Array = _voronoi_cell(base, seeds, i)
			if cell.size() < 3:
				continue
			var cen := _centroid(cell)
			var local := PackedVector2Array()
			for v in cell:
				local.append(v - cen)            # piece drawn around its own centroid

			var pg := Polygon2D.new()
			pg.polygon = local
			pg.color = FILL
			pg.position = cen

			var border := PackedVector2Array(local)
			border.append(local[0])              # close the outline
			var ln := Line2D.new()
			ln.points = border
			ln.width = edge_w
			ln.default_color = EDGE
			ln.joint_mode = Line2D.LINE_JOINT_ROUND
			pg.add_child(ln)
			add_child(pg)

			# Direction: roughly outward from the break, but each shard veers off on its own
			# heading so they scatter every which way instead of expanding as a tidy ring.
			var dir := (cen - center)
			dir = dir.normalized() if dir.length() > 8.0 else Vector2.from_angle(rng.randf_range(0.0, TAU))
			dir = dir.rotated(rng.randf_range(-1.1, 1.1))                       # ±~63° off radial
			dir = (dir + Vector2.from_angle(rng.randf_range(0.0, TAU)) * 0.5).normalized()  # blend a random heading
			var speed := rng.randf_range(120.0, 460.0)                         # wide spread: some far, some barely move
			var vel := dir * speed
			_pieces.append({
				"node": pg, "vel": vel,
				"ang": rng.randf_range(-7.0, 7.0),
				"life": rng.randf_range(0.8, 1.15),
				"max_life": 1.15, "fade": 0.45,
			})

	func release() -> void:
		_released = true

	func _process(delta: float) -> void:
		if not _released:
			return
		for p in _pieces:
			var node = p["node"]                 # untyped: a freed instance must not hit a typed assign
			if not is_instance_valid(node):
				continue
			p["vel"] *= exp(-_drag * delta)      # slide out, then friction brings it to rest
			node.position += p["vel"] * delta
			p["ang"] *= exp(-_spin_drag * delta)
			node.rotation += p["ang"] * delta
			p["life"] -= delta
			if p["life"] <= p["fade"]:
				node.modulate.a = clampf(p["life"] / p["fade"], 0.0, 1.0)
			if p["life"] <= 0.0:
				node.queue_free()
				p["node"] = null

	# Voronoi cell of seed i = base polygon clipped by the perpendicular bisector
	# against every other seed (keep the half-plane nearer to seed i).
	func _voronoi_cell(base: Array, seeds: Array, i: int) -> Array:
		var cell: Array = base.duplicate()
		var si: Vector2 = seeds[i]
		for j in seeds.size():
			if j == i:
				continue
			var sj: Vector2 = seeds[j]
			var mid := (si + sj) * 0.5
			var normal := si - sj                  # points toward seed i (the keep side)
			cell = _clip_halfplane(cell, mid, normal)
			if cell.size() < 3:
				break
		return cell

	# Sutherland–Hodgman clip: keep the part of poly where (pt - p)·n >= 0
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

	func _centroid(poly: Array) -> Vector2:
		var c := Vector2.ZERO
		for v in poly:
			c += v
		return c / poly.size()
