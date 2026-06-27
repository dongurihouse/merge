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
## Every look/feel dial lives in Tune (engine/scripts/core/tuning.gd → class Ambient).

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").Ambient   # the engine's ambient look/feel dials
const FXTune = preload("res://engine/scripts/core/tuning.gd").FX      # the merge-puff dials live with the other feel-verb tunables

const WEATHER_DEBUG_STATES := ["", "clear", "breeze", "rain", "snow"]

static var forced_weather := ""        # shot tools force a state ("rain"…)

# --- residents (the population sub-game) --------------------------------------------
# Tier reads from the ART itself — each tier ships its own sprite (items/resident_<id>/), so the
# layer applies NO per-tier scale or tint (that doubled up on the art and ballooned/tinted high
# tiers). Merge still gets a celebratory poof. Dials kept LOCAL (Tune.Ambient owns generic-wander).
const RES_POOF_PER_EVENT := 12         # burst particles per merge event
const RES_POOF_COLOR := Color("#F3D9A6")  # the warm celebratory poof colour

# --- residents population layer ----------------------------------------------------

## The POPULATION layer (the residents sub-game): the map's ROSTER, one sprite per member dict
## `{type, tier}` from G.resident_members.
## The roster is the source of truth — the layer is stateless + freely rebuildable (positions
## stay a pure function of child index + time via _update_layer), so a welcome/merge just
## rebuilds it. NO cap on member count. Every node IGNOREs the mouse. Each member renders its
## own tier art (G.resident_art(type, tier)), falling back to the shared placeholder body when
## the sprite is absent.
static func build_population_layer(bounds: Vector2, members: Array) -> Control:
	var layer := Control.new()
	layer.name = "AmbientLayer"          # same node name → _map_tap's spirit-hop find still works
	layer.size = bounds
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Features.on("ambient_characters"):
		return layer                       # the empty layer keeps the node contract
	for i in members.size():
		var m: Dictionary = members[i]
		layer.add_child(_make_resident(i, String(m.get("type", "")), int(m.get("tier", 1))))
	_update_layer(layer)                  # correct positions on the very first frame
	var tw := layer.create_tween().set_loops()
	tw.tween_method(func(_t: float) -> void: _update_layer(layer), 0.0, 1.0, Tune.REPATH_SPAN)
	return layer

# One resident sprite: the type+tier's own art (G.resident_art(type, tier)) when present, else the
# shared placeholder body. Mouse-IGNORE like every wandering sprite.
static func _make_resident(_i: int, type_id: String, tier: int) -> Control:
	var ch := Control.new()
	ch.size = Tune.CHAR_SIZE
	ch.pivot_offset = Tune.CHAR_SIZE / 2.0
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.set_meta("resident", type_id)
	ch.set_meta("tier", tier)
	var path := G.resident_art(type_id, tier)
	if path != "" and ResourceLoader.exists(path):
		var tex := TextureRect.new()
		tex.texture = load(path)
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ch.add_child(tex)
	else:
		# placeholder resident: the same soft rounded body the generic wanderers use
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
	# Tier needs no scale/tint here — each tier's own art carries the "elder" read.
	return ch

## A one-shot celebratory burst for `count` two-of-a-kind merge events — the merge FLOURISH. Safe
## to call AFTER a layer rebuild (idempotent; relies on no specific surviving sprite): it plays a
## warm poof over the layer's center for each event. The roster is already committed by the API, so
## this is pure juice. A 0-or-fewer count is a no-op.
static func merge_poof(layer: Control, count: int) -> void:
	if layer == null or not is_instance_valid(layer) or count <= 0:
		return
	var center := layer.size / 2.0
	for _e in count:
		FX.burst(layer, center, RES_POOF_COLOR, RES_POOF_PER_EVENT)

## The WORLD REACTION to a merge: a quick outward PUFF of ambient motes from `center`. Rather than
## nudge the existing drift particles (a CPUParticles2D exposes no per-particle velocity), it spawns
## a tiny one-shot radial burst of the SAME breeze petal/leaf motes flying OUTWARD from the hit, so
## the ambient layer reads as recoiling from the merge. Cheap: MOTE_PUFF_COUNT motes, ~MOTE_PUFF_LIFE
## then self-free. `impulse` sets how hard they scatter (outward velocity). The motes are a CPUParticles2D
## (a Node2D — it never eats input). No-op when ambient_weather is off OR the layer is gone — the caller
## guards the no-ambient case (Rush) too.
## The mote COUNT is calm-trimmed (FX.amount_for); the puff is light, so it still fires under calm.
static func puff(layer: Control, center: Vector2, impulse := FXTune.MOTE_PUFF_IMPULSE) -> void:
	if layer == null or not is_instance_valid(layer) or not Features.on("ambient_weather"):
		return
	var n := _puff_count()
	if n <= 0:
		return
	var p := CPUParticles2D.new()
	p.texture = FX._pick_tex(Tune.BREEZE_PETAL)
	p.position = center
	p.amount = n
	p.lifetime = FXTune.MOTE_PUFF_LIFE
	p.one_shot = true
	p.explosiveness = 1.0                # all at once — a single outward gust
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	p.direction = Vector2(0, -1)
	p.spread = 180.0                     # a full radial fan — motes scatter every which way outward
	p.gravity = Vector2.ZERO             # the puff is a free outward scatter, no fall
	p.initial_velocity_min = impulse * 0.5
	p.initial_velocity_max = impulse
	p.angular_velocity_min = -Tune.DRIFT_SPIN
	p.angular_velocity_max = Tune.DRIFT_SPIN
	p.scale_amount_min = FXTune.MOTE_PUFF_SCALE_MIN
	p.scale_amount_max = FXTune.MOTE_PUFF_SCALE_MAX
	layer.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

# How many motes a puff flings — MOTE_PUFF_COUNT, calm-trimmed (FX.amount_for). Pure-ish (reads the
# calm setting through FX); unit-tested for "> 0 normally, never above the base count".
static func _puff_count() -> int:
	return FX.amount_for(FXTune.MOTE_PUFF_COUNT)

static func _update_layer(layer: Control) -> void:
	if layer == null or not is_instance_valid(layer) or layer.get_meta("paused", false):
		return
	var t := Time.get_unix_time_from_system()
	var day := int(t / Tune.SECS_PER_DAY)
	for i in layer.get_child_count():
		var ch := layer.get_child(i) as Control
		if ch == null:                      # merge_poof's transient FX.burst particles ride this layer too — skip non-Controls
			continue
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

static func weather_debug_label() -> String:
	return "Weather: %s" % ("auto" if forced_weather == "" else forced_weather)

static func debug_cycle_weather() -> String:
	var i := WEATHER_DEBUG_STATES.find(forced_weather)
	if i < 0:
		i = 0
	forced_weather = WEATHER_DEBUG_STATES[(i + 1) % WEATHER_DEBUG_STATES.size()]
	return forced_weather

static func reset_weather_debug_for_test() -> void:
	forced_weather = ""

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
