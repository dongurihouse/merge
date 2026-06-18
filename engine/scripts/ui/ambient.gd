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
const Game = preload("res://engine/scripts/core/game.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").Ambient   # the engine's ambient look/feel dials

const CHARACTER_TYPES = G.CHARACTER_TYPES   # the character roster lives in the game's data
const CHARACTER_ART = G.CHARACTER_ART       # type → clothes asset path (game-provided convention)

static var forced_weather := ""        # shot tools force a state ("rain"…)

# --- residents (the population sub-game) --------------------------------------------
# Tier reads as "elder": each step up scales the sprite a touch larger and warms its
# tint, so a merged-up resident looks more settled/venerable without a new asset. These
# are small, tasteful steps (the cozy look) — kept LOCAL since Tune.Ambient owns the
# generic-wander dials, and the resident layer is a distinct, no-cap concern.
const RES_TIER_SCALE_STEP := 0.14      # +this per tier above t1 (t1=1.0, t2=1.14, t3=1.28…)
const RES_TIER_TINT := Color("#F3D9A6")  # the warm "elder" wash a higher tier leans toward
const RES_TIER_TINT_STEP := 0.18       # how far toward RES_TIER_TINT each tier above t1 leans
const RES_POOF_PER_EVENT := 12         # burst particles per merge event
const RES_POOF_COLOR := Color("#F3D9A6")  # the warm celebratory poof colour

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

## The POPULATION layer (the residents sub-game). Like build_layer, but the wandering set
## is the map's ROSTER: one sprite per member dict `{type, tier}` from G.resident_members.
## The roster is the source of truth — the layer is stateless + freely rebuildable (positions
## stay a pure function of child index + time via _update_layer), so a welcome/merge just
## rebuilds it. NO cap on member count. Every node IGNOREs the mouse. Higher TIERS read as
## "elder" via a gentle scale + warm recolour. Art per member = load(G.resident_art(type)),
## falling back to the shared placeholder body when the sprite is absent.
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

# One resident sprite: the type's art (G.resident_art) when present, else the shared placeholder
# body. The TIER is applied visually — a gentle scale step + a warm recolour wash — so a merged-up
# resident reads as more settled/venerable. Mouse-IGNORE like every wandering sprite.
static func _make_resident(_i: int, type_id: String, tier: int) -> Control:
	var ch := Control.new()
	ch.size = Tune.CHAR_SIZE
	ch.pivot_offset = Tune.CHAR_SIZE / 2.0
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.set_meta("resident", type_id)
	ch.set_meta("tier", tier)
	var path := G.resident_art(type_id)
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
	# TIER as "elder": grow a step + warm the wash, per tier above t1 (t1 is untouched).
	var steps := float(maxi(tier - 1, 0))
	if steps > 0.0:
		ch.scale = Vector2.ONE * (1.0 + RES_TIER_SCALE_STEP * steps)
		ch.modulate = Color.WHITE.lerp(RES_TIER_TINT, clampf(RES_TIER_TINT_STEP * steps, 0.0, 0.7))
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

# --- clouds (the sky band) ----------------------------------------------------------
## A few soft clouds drift slowly across the top "sky" band (behind the fence + HUD),
## giving the scene depth + gentle life so the backdrop never reads as a flat field.
## Stateless like the wandering layer: each cloud's x derives from wall-clock time, so
## the layer can be freed/re-inserted at any moment. Mouse-ignored; ≤3 sprites.
static func build_clouds(view: Vector2) -> Control:
	var layer := Control.new()
	layer.name = "CloudLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = view
	if not Features.on("ambient_clouds"):
		return layer
	var tex := _cloud_tex()
	if tex == null:
		return layer                          # no art → no clouds (the layer keeps the node contract)
	var aspect := float(tex.get_height()) / float(tex.get_width())
	# y-frac (kept in the top sky band, clear of the grid), on-screen WIDTH px, alpha, px/sec, flip
	var specs := [
		[0.035, 250.0, 0.55, 7.0, false],
		[0.100, 165.0, 0.42, 11.0, true],
		[0.155, 300.0, 0.30, 4.5, false],
	]
	var clouds: Array = []
	for s in specs:
		var c := TextureRect.new()
		c.texture = tex
		var w := float(s[1])
		var h := w * aspect
		c.custom_minimum_size = Vector2(w, h)
		c.size = Vector2(w, h)
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_SCALE
		c.flip_h = bool(s[4])
		c.modulate = Color(1, 1, 1, float(s[2]))
		c.position.y = view.y * float(s[0])
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(c)
		clouds.append({"node": c, "w": w, "speed": float(s[3])})
	layer.set_meta("clouds", clouds)
	_update_clouds(layer, view)
	var tw := layer.create_tween().set_loops()
	tw.tween_method(func(_t: float) -> void: _update_clouds(layer, view), 0.0, 1.0, 1.0)
	return layer

static func _update_clouds(layer: Control, view: Vector2) -> void:
	if layer == null or not is_instance_valid(layer) or layer.get_meta("paused", false):
		return
	var t := Time.get_unix_time_from_system()
	for cd in layer.get_meta("clouds", []):
		var c: Control = cd["node"]
		if not is_instance_valid(c):
			continue
		var span: float = view.x + float(cd["w"])
		c.position.x = fmod(t * float(cd["speed"]), span) - float(cd["w"])   # off-left → off-right, wrapping

# cloud.png is a 1086×1448 cluster (several puffs + lots of empty space); crop a single
# clean puff so each drifting sprite reads as one cloud, not a sparse far-flung group.
static var _cloud: Texture2D
static func _cloud_tex() -> Texture2D:
	if _cloud == null:
		var path := Game.art("ui/cloud.png")
		if not ResourceLoader.exists(path):
			return null
		var base: Texture2D = load(path)
		var at := AtlasTexture.new()
		at.atlas = base
		at.region = Rect2(24, 28, 644, 410)   # the top-left puff
		_cloud = at
	return _cloud

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
