extends RefCounted
## Ambient LIFE + WEATHER (order L). One module, both scenes.
##
## Characters are STATELESS: every frame their position derives from wall-clock
## time + a per-day seed + their index — so the layer can be freed and
## re-inserted at any moment (the host clears ALL children on rebuilds) and
## every character resumes mid-path. No tween state to teleport.
##
## Weather picks deterministically per HOUR (clear/breeze/rain/snow ≈ 70/20/8/2).
## The >=48h win-back persists `winback_until = now + 60` and both scenes'
## pickers read it → it rains for that first minute back. CALM MODE WINS:
## calm players get breeze, never rain/snow. Caps: ≤2 emitters, ≤80 particles.
##
## Every look/feel dial lives in Tune (engine/scripts/tuning.gd → class Ambient).

const G = preload("res://engine/scripts/content.gd")
const Save = preload("res://engine/scripts/save.gd")
const FX = preload("res://engine/scripts/fx.gd")
const Features = preload("res://engine/scripts/features.gd")
const Game = preload("res://engine/scripts/game.gd")
const Tune = preload("res://engine/scripts/tuning.gd").Ambient   # the engine's ambient look/feel dials

const CHARACTER_TYPES = G.CHARACTER_TYPES   # the character roster lives in the game's data
const CHARACTER_ART = G.CHARACTER_ART       # type → clothes asset path (game-provided convention)

static var forced_weather := ""        # shot tools force a state ("rain"…)

# --- characters --------------------------------------------------------------------

## The wandering layer. `bounds` = the area they roam; `count` = how many wander
## (the host decides, e.g. from progression). Everything IGNOREs the mouse; taps
## are the host's business.
static func build_layer(bounds: Vector2, count: int, sparse := false) -> Control:
	var layer := Control.new()
	layer.name = "AmbientLayer"
	layer.size = bounds
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Features.on("ambient_characters"):
		return layer                       # the empty layer keeps the node contract
	var n := count
	if sparse:
		n = mini(n, Tune.SPARSE_CAP)
	for i in n:
		var ch := _make_character(i)
		layer.add_child(ch)
	_update_layer(layer)                  # correct positions on the very first frame
	var tw := layer.create_tween().set_loops()
	tw.tween_method(func(_t: float) -> void: _update_layer(layer), 0.0, 1.0, Tune.REPATH_SPAN)
	return layer

static func _update_layer(layer: Control) -> void:
	if layer == null or not is_instance_valid(layer) or layer.get_meta("paused", false):
		return
	var t := Time.get_unix_time_from_system()
	var day := int(t / Tune.SECS_PER_DAY)
	for i in layer.get_child_count():
		var ch: Control = layer.get_child(i)
		ch.position = _character_pos(i, t, day, layer.size) - ch.size / 2.0

## Pure path function: a slow figure-wander + a gentle vertical bob.
static func _character_pos(i: int, t: float, day_seed: int, bounds: Vector2) -> Vector2:
	var h := hash(day_seed * Tune.SEED_DAY_MULT + i * Tune.SEED_I_MULT)
	var cx := Tune.CENTER_MIN + Tune.CENTER_SPAN * float(h % Tune.SPREAD_X) / float(Tune.SPREAD_X)
	var cy := Tune.CENTER_MIN + Tune.CENTER_SPAN * float((h / Tune.SPREAD_X) % Tune.SPREAD_Y) / float(Tune.SPREAD_Y)
	var spd := Tune.SPEED_BASE + Tune.SPEED_STEP * float(i % Tune.SPEED_CLASSES)
	var ph := float(h % Tune.PHASE_MOD) / Tune.PHASE_DIV
	var x := bounds.x * (cx + Tune.AMP_X * sin(t * spd + ph))
	var y := bounds.y * (cy + Tune.AMP_Y * cos(t * spd * Tune.FREQ_Y_RATIO + ph * Tune.PHASE_Y_MULT))
	y += Tune.BOB_AMP * sin(t * Tune.BOB_SPEED + float(i) * Tune.BOB_PHASE_STEP)        # the gentle vertical bob
	return Vector2(clampf(x, Tune.EDGE_MARGIN, bounds.x - Tune.EDGE_MARGIN), clampf(y, Tune.EDGE_MARGIN, bounds.y - Tune.EDGE_MARGIN))

static func _make_character(i: int) -> Control:
	var kind: String = CHARACTER_TYPES[i % CHARACTER_TYPES.size()]
	var ch := Control.new()
	ch.size = Tune.CHAR_SIZE
	ch.pivot_offset = Tune.CHAR_SIZE / 2.0
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.set_meta("character", kind)
	var path := Game.art(CHARACTER_ART % kind)
	if ResourceLoader.exists(path):
		var tex := TextureRect.new()
		tex.texture = load(path)
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ch.add_child(tex)
	else:
		# placeholder character: a soft rounded body with two eyes
		var body := Panel.new()
		body.size = Tune.BODY_SIZE
		body.position = Tune.BODY_OFFSET
		var bs := StyleBoxFlat.new()
		bs.bg_color = Tune.BODY_COLOR
		bs.set_corner_radius_all(int(Tune.BODY_SIZE.x / 2.0))
		bs.shadow_color = Tune.BODY_SHADOW
		bs.shadow_size = Tune.BODY_SHADOW_SIZE
		body.add_theme_stylebox_override("panel", bs)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ch.add_child(body)
		for e in Tune.EYE_COUNT:
			var eye := ColorRect.new()
			eye.color = Tune.EYE_COLOR
			eye.size = Tune.EYE_SIZE
			eye.position = Tune.EYE_ORIGIN + Vector2(e * Tune.EYE_SPACING, 0)
			eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ch.add_child(eye)
	return ch

## The tap reaction (pure charm — no mechanics).
static func hop(ch: Control) -> void:
	var tw := ch.create_tween()
	tw.tween_property(ch, "scale", Tune.HOP_SQUASH, Tune.HOP_T_SQUASH)
	tw.tween_property(ch, "scale", Tune.HOP_STRETCH, Tune.HOP_T_REST)
	tw.tween_property(ch, "scale", Vector2.ONE, Tune.HOP_T_REST)

# --- the win-back (shared; both scenes) --------------------------------------------

## Detects the >=48h return, stamps the rainy minute. Caller persists the blob.
static func check_winback(g: Dictionary, now: float) -> bool:
	if not Features.on("winback_rain_beat"):
		return false
	var last := float(g.get("last_seen", now))
	if now - last >= G.WINBACK_HOURS * Tune.SECS_PER_HOUR:
		g["winback_until"] = now + Tune.WINBACK_RAIN_SECS
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
	var roll := absi(hash(int(Time.get_unix_time_from_system() / Tune.SECS_PER_HOUR))) % Tune.ROLL_RANGE
	var w := "clear"
	if roll >= Tune.BREEZE_AT and roll < Tune.RAIN_AT:
		w = "breeze"
	elif roll >= Tune.RAIN_AT and roll < Tune.SNOW_AT:
		w = "rain"
	elif roll >= Tune.SNOW_AT:
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
			layer.add_child(_drift_emitter(view, FX._pick_tex(Tune.BREEZE_PETAL), Tune.BREEZE_AMOUNT, Tune.BREEZE_PETAL_LIFE, Tune.BREEZE_PETAL_VEL))
			layer.add_child(_drift_emitter(view, FX._pick_tex(Tune.BREEZE_LEAF), Tune.BREEZE_AMOUNT, Tune.BREEZE_LEAF_LIFE, Tune.BREEZE_LEAF_VEL))
		"rain":
			var rain := _drift_emitter(view, _streak_tex(), Tune.RAIN_AMOUNT, Tune.RAIN_LIFE, Tune.RAIN_VEL)
			rain.position = Vector2(view.x / 2.0, Tune.RAIN_TOP_OFFSET)
			rain.scale_amount_min = Tune.RAIN_SCALE_MIN        # the tiny streak tex needs ~full size
			rain.scale_amount_max = Tune.RAIN_SCALE_MAX
			layer.add_child(rain)
			var veil := ColorRect.new()
			veil.color = Tune.RAIN_VEIL
			veil.set_anchors_preset(Control.PRESET_FULL_RECT)
			veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(veil)
		"snow":
			var snow := _drift_emitter(view, _flake_tex(), Tune.SNOW_AMOUNT, Tune.SNOW_LIFE, Tune.SNOW_VEL)
			snow.scale_amount_min = Tune.SNOW_SCALE_MIN
			snow.scale_amount_max = Tune.SNOW_SCALE_MAX
			layer.add_child(snow)
			var frost := ColorRect.new()       # a cool cast so flakes read on a pale background
			frost.color = Tune.SNOW_FROST
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
	p.emission_rect_extents = Vector2(view.x * Tune.EMIT_WIDTH_FRAC, Tune.EMIT_BAND_H)
	p.position = Vector2(view.x / 2.0, Tune.EMIT_TOP_OFFSET)
	p.direction = Tune.DRIFT_DIR
	p.spread = Tune.DRIFT_SPREAD
	p.gravity = Vector2(vel.x, vel.y)
	p.initial_velocity_min = Tune.DRIFT_VEL_MIN
	p.initial_velocity_max = Tune.DRIFT_VEL_MAX
	p.angular_velocity_min = -Tune.DRIFT_SPIN
	p.angular_velocity_max = Tune.DRIFT_SPIN
	p.scale_amount_min = Tune.DRIFT_SCALE_MIN
	p.scale_amount_max = Tune.DRIFT_SCALE_MAX
	return p

static var _streak: Texture2D
static func _streak_tex() -> Texture2D:
	if _streak == null:
		var img := Image.create(Tune.STREAK_SIZE.x, Tune.STREAK_SIZE.y, false, Image.FORMAT_RGBA8)
		img.fill(Tune.STREAK_COLOR)
		_streak = ImageTexture.create_from_image(img)
	return _streak

static var _flake: Texture2D
static func _flake_tex() -> Texture2D:
	if _flake == null:
		var img := Image.create(Tune.FLAKE_SIZE, Tune.FLAKE_SIZE, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for x in Tune.FLAKE_SIZE:
			for y in Tune.FLAKE_SIZE:
				var d := Vector2(x - Tune.FLAKE_RADIUS, y - Tune.FLAKE_RADIUS).length()
				if d < Tune.FLAKE_RADIUS:
					img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d / Tune.FLAKE_RADIUS, 0.0, 1.0) * Tune.FLAKE_ALPHA))
		_flake = ImageTexture.create_from_image(img)
	return _flake
