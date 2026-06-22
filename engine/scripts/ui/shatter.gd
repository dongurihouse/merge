extends Node2D
## Breaking-glass shatter field. Add to a host, call arm(), and it fractures a polygon
## from an impact point into radial-spoke + concentric-ring shards (small/fast near impact,
## larger outward), which fly off, tumble in fake-3D, glint, and fade — then it frees itself.
##
## Two paint modes:
##   flat    — shards are a solid `color` (look-dev / generic punctuation)
##   texture — shards carry a slice of `texture` via per-vertex UV (so an irregular, masked
##             region like the map's purple lock veil shatters in its TRUE shape: pixels outside
##             the region are transparent and simply don't draw). The host's local origin must
##             line up with the texture's pixel origin (caller passes a full-view snapshot).
##
## Look-dev lives in engine/tools/fx_demo.gd (make fx / make shot), which drives this same code.

# --- tuning (promote to Tune.FX when locked) ----------------------------------------
const SPOKES_MIN := 8
const SPOKES_MAX := 11
const RING_FRACS := [0.0, 0.24, 0.54, 0.92, 1.28]   # concentric radii ×reach; dense near impact
const SPEED_INNER := 1050.0     # throw speed at the impact (shards here fly fastest)
const SPEED_OUTER := 430.0      # throw speed at the rim
const DRAG := 0.9               # low → shards coast off-screen (distance ≈ speed/drag)
const SPIN_DRAG := 2.4
const SHRINK := 0.74            # end-of-life depth shrink
const EDGE_W := 0.013           # crack-line width ×reach (flat mode only)

var _pieces: Array = []
var _released := false
var _auto := true               # false = wait for an explicit release() (look-dev capture)
var _hold := 0.0                # seconds to show the cracked-but-intact shape before bursting
var _impact := Vector2.ZERO
var _dust_color := Color(1, 1, 1, 0.8)
var _premult := false           # textured shards: snapshot is premultiplied-alpha → composite to match the veil


# Fracture `poly` (host-local coords) from `impact`, painted per `paint`:
#   {"color": Color}                 → flat shards (+ bright crack edges)
#   {"texture": Texture2D}           → textured shards (uv = original vertex pixel)
# auto_release: seconds to hold the cracked shape, then burst. <0 = wait for release().
func arm(poly: Array, impact: Vector2, paint: Dictionary, auto_release := 0.0, rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = 20260621
	_impact = impact
	_dust_color = paint.get("dust", Color(1, 1, 1, 0.8))
	var reach := 0.0
	for v in poly:
		reach = maxf(reach, (v - impact).length())
	var cells := _radial_fracture(poly, impact, reach, rng)
	var tex: Texture2D = paint.get("texture", null)
	var col: Color = paint.get("color", Color.WHITE)
	_premult = tex != null and bool(paint.get("premultiplied", false))
	var tex_mat: CanvasItemMaterial = null
	if _premult:
		tex_mat = CanvasItemMaterial.new()   # the snapshot's RGB is already ×alpha; blend it as premultiplied
		tex_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA

	for cell in cells:
		var cen := _centroid(cell)
		var local := PackedVector2Array()
		var uv := PackedVector2Array()
		for v in cell:
			local.append(v - cen)
			uv.append(v)                       # original pixel into the snapshot

		var pg := Polygon2D.new()
		pg.polygon = local
		pg.position = cen
		if tex != null:
			pg.texture = tex
			pg.uv = uv
			pg.material = tex_mat
		else:
			pg.color = col
			var border := PackedVector2Array(local)
			border.append(local[0])
			var ln := Line2D.new()
			ln.points = border
			ln.width = maxf(1.4, reach * EDGE_W)
			ln.default_color = Color(1, 1, 1, 0.85)
			ln.joint_mode = Line2D.LINE_JOINT_ROUND
			pg.add_child(ln)
		add_child(pg)

		var dir := cen - impact
		dir = dir.normalized() if dir.length() > 4.0 else Vector2.from_angle(rng.randf_range(0.0, TAU))
		dir = dir.rotated(rng.randf_range(-0.5, 0.5))
		dir = (dir + Vector2.from_angle(rng.randf_range(0.0, TAU)) * 0.28).normalized()
		var distf := clampf((cen - impact).length() / maxf(reach, 1.0), 0.0, 1.0)
		var speed := lerpf(SPEED_INNER, SPEED_OUTER, distf) * rng.randf_range(0.85, 1.25)
		_pieces.append({
			"node": pg, "vel": dir * speed,
			"ang": rng.randf_range(-8.0, 8.0),
			"life": rng.randf_range(0.85, 1.25), "max_life": 1.25,
			"fade": 0.5, "age": 0.0, "phase": rng.randf() * TAU,
			"tumble_x": rng.randf_range(4.0, 9.0) * (1.0 if rng.randf() < 0.5 else -1.0),
			"tumble_y": rng.randf_range(4.0, 9.0) * (1.0 if rng.randf() < 0.5 else -1.0),
			"phase2": rng.randf() * TAU,
		})

	if auto_release < 0.0:
		_auto = false                # wait for an explicit release()
	else:
		_auto = true
		_hold = auto_release
	set_process(true)


func release() -> void:
	_do_release()

func _do_release() -> void:
	if _released:
		return
	_released = true
	_emit_dust()


func _process(delta: float) -> void:
	if not _released:
		if not _auto:
			return                   # manual mode: wait for release()
		if _hold > 0.0:
			_hold -= delta
			return
		_do_release()                # hold elapsed (or was 0) → burst
	var alive := 0
	for p in _pieces:
		var node = p["node"]
		if not is_instance_valid(node):
			continue
		alive += 1
		p["age"] += delta
		p["vel"] *= exp(-DRAG * delta)
		node.position += p["vel"] * delta
		p["ang"] *= exp(-SPIN_DRAG * delta)
		node.rotation += p["ang"] * delta

		# fake-3D tumble: foreshorten on two axes, carried around by the spin
		var t := clampf(p["age"] / p["max_life"], 0.0, 1.0)
		var shrink := lerpf(1.0, SHRINK, t)
		var sx := absf(cos(p["age"] * p["tumble_x"] + p["phase"]))
		var sy := absf(cos(p["age"] * p["tumble_y"] + p["phase2"]))
		node.scale = Vector2(maxf(0.1, sx), maxf(0.1, sy)) * shrink

		# glint via modulate brightness: break-flash + spin specular + edge-flip pop
		var flash := maxf(0.0, 1.0 - p["age"] / 0.14) * 0.9
		var spec := pow(maxf(0.0, sin(node.rotation * 1.7 + p["phase"])), 14) * 0.6
		var flip := clampf((pow(1.0 - sx, 8) + pow(1.0 - sy, 8)) * 0.5, 0.0, 0.7)
		var glint := clampf(maxf(maxf(flash, spec), flip), 0.0, 1.0)
		var b := 1.0 + glint * 0.7
		var a := 1.0
		p["life"] -= delta
		if p["life"] <= p["fade"]:
			a = clampf(p["life"] / p["fade"], 0.0, 1.0)
		# premultiplied shards: scale RGB by the fade too, else they go additive instead of fading out
		node.modulate = Color(b * a, b * a, b * a, a) if _premult else Color(b, b, b, a)
		if p["life"] <= 0.0:
			node.queue_free()
			p["node"] = null
	if _released and alive == 0:
		queue_free()


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
	mat.gravity = Vector3.ZERO
	mat.damping_min = 120.0
	mat.damping_max = 220.0
	mat.initial_velocity_min = 90.0
	mat.initial_velocity_max = 320.0
	mat.scale_min = 0.15
	mat.scale_max = 0.5
	mat.color = _dust_color
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


# =====================================================================================
# Voronoi-free radial fracture: spokes + rings from impact, vertices shared so cells tile.
# =====================================================================================
func _radial_fracture(poly: Array, impact: Vector2, reach: float, rng: RandomNumberGenerator) -> Array:
	var spokes: int = rng.randi_range(SPOKES_MIN, SPOKES_MAX)
	var a0 := rng.randf_range(0.0, TAU)
	var angs: Array = []
	for i in spokes:
		angs.append(a0 + TAU * i / spokes + rng.randf_range(-0.14, 0.14))

	var rings: int = RING_FRACS.size()
	var vgrid: Array = []
	for j in rings:
		var row: Array = []
		for i in spokes:
			var rr: float = reach * float(RING_FRACS[j])
			if j > 0:
				rr *= rng.randf_range(0.88, 1.12)
			row.append(impact + Vector2.from_angle(angs[i]) * rr)
		vgrid.append(row)

	var cells: Array = []
	for j in rings - 1:
		for i in spokes:
			var i2 := (i + 1) % spokes
			var quad := [vgrid[j][i], vgrid[j][i2], vgrid[j + 1][i2], vgrid[j + 1][i]]
			var cell := _clip_to_convex(_dedupe(quad), poly)
			if cell.size() >= 3:
				cells.append(cell)
	return cells


func _clip_to_convex(subject: Array, clip: Array) -> Array:
	var c := _centroid(clip)
	var out: Array = subject
	for k in clip.size():
		var a: Vector2 = clip[k]
		var b: Vector2 = clip[(k + 1) % clip.size()]
		var edge := b - a
		var nrm := Vector2(-edge.y, edge.x)
		if nrm.dot(c - a) < 0.0:
			nrm = -nrm
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
			var tt := da / (da - db)
			out.append(a + (b - a) * tt)
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
