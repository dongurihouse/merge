extends RefCounted
## Ghibli Grove — ambient LIFE + WEATHER (order L). One module, both scenes.
##
## Spirits are STATELESS: every frame their position derives from wall-clock
## time + a per-day seed + their index — so the layer can be freed and
## re-inserted at any moment (the vista clears ALL children on rebuilds) and
## every spirit resumes mid-path. No tween state to teleport.
##
## Weather picks deterministically per HOUR (clear/breeze/rain/snow ≈ 70/20/8/2).
## The >=48h win-back persists `winback_until = now + 60` and both scenes'
## pickers read it → it rains for that first minute home. CALM MODE WINS:
## calm players get breeze, never rain/snow. Caps: ≤2 emitters, ≤80 particles.

const G = preload("res://scripts/grove_content.gd")
const Save = preload("res://scripts/save.gd")
const FX = preload("res://scripts/fx.gd")
const Features = preload("res://scripts/features.gd")

const SPIRIT_TYPES := ["moss", "acorn", "lantern"]   # §I art rows (puff removed, owner 2026-06-13)
const SPIRIT_CAP := 5

static var forced_weather := ""        # shot tools force a state ("rain"…)

# --- spirits -----------------------------------------------------------------------

## How many spirits wander: 1 + completed zones, capped (home delegates here).
static func spirit_count(unlocks: Dictionary) -> int:
	return mini(1 + G.completed_zones(unlocks), SPIRIT_CAP)

## The wandering layer. `bounds` = the area they roam (map: MAP_SIZE; board: a
## backdrop band). Everything IGNOREs the mouse; taps are the HOST's business.
static func build_layer(bounds: Vector2, unlocks: Dictionary, sparse := false) -> Control:
	var layer := Control.new()
	layer.name = "AmbientLayer"
	layer.size = bounds
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Features.on("ambient_spirits"):
		return layer                       # the empty layer keeps the node contract
	var n := spirit_count(unlocks)
	if sparse:
		n = mini(n, 2)
	for i in n:
		var sp := _make_spirit(i)
		layer.add_child(sp)
	_update_layer(layer)                  # correct positions on the very first frame
	var tw := layer.create_tween().set_loops()
	tw.tween_method(func(_t: float) -> void: _update_layer(layer), 0.0, 1.0, 3600.0)
	return layer

static func _update_layer(layer: Control) -> void:
	if layer == null or not is_instance_valid(layer) or layer.get_meta("paused", false):
		return
	var t := Time.get_unix_time_from_system()
	var day := int(t / 86400.0)
	for i in layer.get_child_count():
		var sp: Control = layer.get_child(i)
		sp.position = _spirit_pos(i, t, day, layer.size) - sp.size / 2.0

## Pure path function: a slow figure-wander + the spec's ambient_bob.
static func _spirit_pos(i: int, t: float, day_seed: int, bounds: Vector2) -> Vector2:
	var h := hash(day_seed * 31 + i * 7)
	var cx := 0.16 + 0.68 * float(h % 997) / 997.0
	var cy := 0.16 + 0.68 * float((h / 997) % 991) / 991.0
	var spd := 0.010 + 0.005 * float(i % 3)
	var ph := float(h % 6283) / 1000.0
	var x := bounds.x * (cx + 0.20 * sin(t * spd + ph))
	var y := bounds.y * (cy + 0.14 * cos(t * spd * 0.83 + ph * 1.7))
	y += 7.0 * sin(t * 1.6 + float(i) * 1.3)        # ambient_bob
	return Vector2(clampf(x, 40.0, bounds.x - 40.0), clampf(y, 40.0, bounds.y - 40.0))

static func _make_spirit(i: int) -> Control:
	var kind: String = SPIRIT_TYPES[i % SPIRIT_TYPES.size()]
	var sp := Control.new()
	sp.size = Vector2(84, 84)
	sp.pivot_offset = Vector2(42, 42)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.set_meta("spirit", kind)
	var path := "res://assets/map/spirit_%s.png" % kind
	if ResourceLoader.exists(path):
		var tex := TextureRect.new()
		tex.texture = load(path)
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sp.add_child(tex)
	else:
		# placeholder spirit: a soft downy puff with two warm eyes
		var body := Panel.new()
		body.size = Vector2(56, 56)
		body.position = Vector2(14, 18)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color("#6B7B52", 0.92)
		bs.set_corner_radius_all(28)
		bs.shadow_color = Color(0, 0, 0, 0.2)
		bs.shadow_size = 4
		body.add_theme_stylebox_override("panel", bs)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sp.add_child(body)
		for e in 2:
			var eye := ColorRect.new()
			eye.color = Color("#E8B23C")
			eye.size = Vector2(7, 9)
			eye.position = Vector2(30 + e * 16, 38)
			eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sp.add_child(eye)
	return sp

## The tap reaction (map only, v1: pure charm — no mechanics).
static func hop(sp: Control) -> void:
	var tw := sp.create_tween()
	tw.tween_property(sp, "scale", Vector2(1.15, 0.85), 0.08)
	tw.tween_property(sp, "scale", Vector2(0.92, 1.12), 0.1)
	tw.tween_property(sp, "scale", Vector2.ONE, 0.1)

# --- the win-back (shared; both scenes) --------------------------------------------

## Detects the >=48h return, stamps the rainy minute. Caller persists the blob.
static func check_winback(g: Dictionary, now: float) -> bool:
	if not Features.on("winback_rain_beat"):
		return false
	var last := float(g.get("last_seen", now))
	if now - last >= G.WINBACK_HOURS * 3600.0:
		g["winback_until"] = now + 60.0
		return true
	return false

static func winback_active() -> bool:
	if not Features.on("winback_rain_beat"):
		return false
	return Time.get_unix_time_from_system() < float(Save.grove().get("winback_until", 0.0))

# --- weather -----------------------------------------------------------------------

static func weather_now(calm: bool) -> String:
	if forced_weather != "":
		return forced_weather
	if winback_active():
		return "breeze" if calm else "rain"      # "it rained while you were away"
	var roll := absi(hash(int(Time.get_unix_time_from_system() / 3600.0))) % 100
	var w := "clear"
	if roll >= 70 and roll < 90:
		w = "breeze"
	elif roll >= 90 and roll < 98:
		w = "rain"
	elif roll >= 98:
		w = "snow"
	if calm and (w == "rain" or w == "snow"):
		return "breeze"                          # calm mode WINS
	return w

## A screen-wide weather layer (≤2 emitters, ≤80 particles). "clear" = empty.
static func build_weather(view: Vector2, kind: String) -> Control:
	var layer := Control.new()
	layer.name = "WeatherLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = view
	if not Features.on("ambient_weather"):
		return layer
	match kind:
		"breeze":
			layer.add_child(_drift_emitter(view, FX._pick_tex(Color("#D98BA3")), 12, 9.0, Vector2(34, 10)))
			layer.add_child(_drift_emitter(view, FX._pick_tex(Color("#7FA65A")), 12, 11.0, Vector2(28, 14)))
		"rain":
			var rain := _drift_emitter(view, _streak_tex(), 70, 1.3, Vector2(40, 980))
			rain.position = Vector2(view.x / 2.0, -40)
			rain.scale_amount_min = 0.8        # the tiny streak tex needs ~full size
			rain.scale_amount_max = 1.3
			layer.add_child(rain)
			var veil := ColorRect.new()
			veil.color = Color(0.45, 0.58, 0.74, 0.10)
			veil.set_anchors_preset(Control.PRESET_FULL_RECT)
			veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(veil)
		"snow":
			var snow := _drift_emitter(view, _flake_tex(), 50, 12.0, Vector2(14, 38))
			snow.scale_amount_min = 1.1
			snow.scale_amount_max = 1.8
			layer.add_child(snow)
			var frost := ColorRect.new()       # a cool cast so flakes read on pale grass
			frost.color = Color(0.62, 0.72, 0.86, 0.10)
			frost.set_anchors_preset(Control.PRESET_FULL_RECT)
			frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(frost)
	return layer

static func _drift_emitter(view: Vector2, tex: Texture2D, amount: int, life: float, vel: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = FX.amount_for(amount)
	p.lifetime = life
	p.preprocess = life                  # the sky is already mid-weather on arrival
	p.texture = tex
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(view.x * 0.75, 8.0)
	p.position = Vector2(view.x / 2.0, -30.0)
	p.direction = Vector2(0.2, 1.0)
	p.spread = 12.0
	p.gravity = Vector2(vel.x, vel.y)
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 42.0
	p.angular_velocity_min = -40.0
	p.angular_velocity_max = 40.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.16
	return p

static var _streak: Texture2D
static func _streak_tex() -> Texture2D:
	if _streak == null:
		var img := Image.create(4, 26, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.75, 0.85, 1.0, 0.55))
		_streak = ImageTexture.create_from_image(img)
	return _streak

static var _flake: Texture2D
static func _flake_tex() -> Texture2D:
	if _flake == null:
		var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for x in 10:
			for y in 10:
				var d := Vector2(x - 4.5, y - 4.5).length()
				if d < 4.5:
					img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d / 4.5, 0.0, 1.0) * 0.9))
		_flake = ImageTexture.create_from_image(img)
	return _flake
