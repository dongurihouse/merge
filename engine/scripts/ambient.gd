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

const G = preload("res://engine/scripts/content.gd")
const Save = preload("res://engine/scripts/save.gd")
const FX = preload("res://engine/scripts/fx.gd")
const Features = preload("res://engine/scripts/features.gd")
const Game = preload("res://engine/scripts/game.gd")

const CHARACTER_TYPES = G.CHARACTER_TYPES   # the character roster lives in the game's data
const CHARACTER_ART = G.CHARACTER_ART       # type → clothes asset path (game-provided convention)

# Every value the look + feel hangs on is named here, so it can be retuned without
# hunting through the body below. Grouped by what it shapes.

# --- tuning: characters ------------------------------------------------------------
const CHAR_SIZE := Vector2(84, 84)            # a character's on-screen box
const SPARSE_CAP := 2                          # a "sparse" layer (the board's backdrop band) shows at most this many
const EDGE_MARGIN := 40.0                      # a character is kept this many px clear of every edge of bounds
const REPATH_SPAN := 3600.0                    # the per-frame position pump re-arms over this span (s); only needs to outlast a sitting

# --- tuning: the wander path (a slow Lissajous figure + a vertical bob) -------------
const CENTER_MIN := 0.16                        # each character's home point lands in [MIN, MIN+SPAN] of bounds, per axis
const CENTER_SPAN := 0.68
const SPEED_BASE := 0.010                       # base angular speed of the wander
const SPEED_STEP := 0.005                       # +this per speed-class, so characters drift out of phase
const SPEED_CLASSES := 3                        # i % this picks the speed-class
const AMP_X := 0.20                             # horizontal reach of the wander, as a fraction of bounds
const AMP_Y := 0.14                             # vertical reach (a flatter ellipse than X)
const FREQ_Y_RATIO := 0.83                      # Y oscillates at this fraction of X's rate → an open, non-repeating figure
const PHASE_Y_MULT := 1.7                       # extra Y phase, so X and Y never crest together
const BOB_AMP := 7.0                            # the small extra up/down bob, in px
const BOB_SPEED := 1.6                          # bob angular speed
const BOB_PHASE_STEP := 1.3                     # per-character bob phase, so they don't bob in lockstep

# --- tuning: placeholder character art (drawn only when the game ships no sprite) ---
const BODY_SIZE := Vector2(56, 56)              # the rounded body panel
const BODY_OFFSET := Vector2(14, 18)            # its inset within CHAR_SIZE
const BODY_COLOR := Color("#6B7B52", 0.92)      # soft moss green
const BODY_SHADOW := Color(0, 0, 0, 0.2)
const BODY_SHADOW_SIZE := 4
const EYE_COUNT := 2
const EYE_SIZE := Vector2(7, 9)
const EYE_COLOR := Color("#E8B23C")             # warm amber
const EYE_ORIGIN := Vector2(30, 38)             # the first eye's top-left within the character box
const EYE_SPACING := 16                          # px from one eye to the next

# --- tuning: the tap-hop (a quick squash & stretch) --------------------------------
const HOP_SQUASH := Vector2(1.15, 0.85)
const HOP_STRETCH := Vector2(0.92, 1.12)
const HOP_T_SQUASH := 0.08                       # seconds for the squash leg
const HOP_T_REST := 0.10                         # seconds for the stretch leg, and again for the settle leg

# --- tuning: weather selection (a deterministic roll, one bucket per real hour) -----
const SECS_PER_HOUR := 3600.0                    # weather rolls once per hour; also the win-back's hour→seconds factor
const ROLL_RANGE := 100                          # the hourly roll spans 0..ROLL_RANGE-1
const BREEZE_AT := 70                            # roll in [BREEZE_AT, RAIN_AT) → breeze  (≈20%)
const RAIN_AT := 90                              #         [RAIN_AT, SNOW_AT)   → rain    (≈8%)
const SNOW_AT := 98                              #         [SNOW_AT, ROLL_RANGE) → snow   (≈2%); below BREEZE_AT → clear (≈70%)
const WINBACK_RAIN_SECS := 60.0                  # on a >=48h return, it rains for this long

# --- tuning: weather particles (budget: ≤2 emitters, ≤80 particles per layer) -------
const BREEZE_PETAL := Color("#D98BA3")           # pink blossom drift
const BREEZE_LEAF := Color("#7FA65A")            # green leaf drift
const BREEZE_AMOUNT := 12
const BREEZE_PETAL_LIFE := 9.0
const BREEZE_LEAF_LIFE := 11.0
const BREEZE_PETAL_VEL := Vector2(34, 10)        # (gravity x, y) for the petal emitter
const BREEZE_LEAF_VEL := Vector2(28, 14)
const RAIN_AMOUNT := 70
const RAIN_LIFE := 1.3
const RAIN_VEL := Vector2(40, 980)               # fast, almost straight down
const RAIN_TOP_OFFSET := -40.0                   # the rain emitter sits this far above the view
const RAIN_SCALE_MIN := 0.8                      # the tiny streak tex needs ~full size
const RAIN_SCALE_MAX := 1.3
const RAIN_VEIL := Color(0.45, 0.58, 0.74, 0.10) # a faint blue wash over the scene
const SNOW_AMOUNT := 50
const SNOW_LIFE := 12.0
const SNOW_VEL := Vector2(14, 38)                # slow, drifting
const SNOW_SCALE_MIN := 1.1
const SNOW_SCALE_MAX := 1.8
const SNOW_FROST := Color(0.62, 0.72, 0.86, 0.10) # a cool cast so flakes read on a pale background

# --- tuning: the shared drift emitter + the two code-drawn textures ----------------
const EMIT_WIDTH_FRAC := 0.75                    # the emission band spans this fraction of the view width
const EMIT_BAND_H := 8.0                         # ...and is this thin (px)
const EMIT_TOP_OFFSET := -30.0                   # particles spawn this far above the top edge
const DRIFT_DIR := Vector2(0.2, 1.0)             # mostly down, with a slight sideways lean
const DRIFT_SPREAD := 12.0                       # ± degrees of spread around DRIFT_DIR
const DRIFT_VEL_MIN := 18.0                      # initial speed range
const DRIFT_VEL_MAX := 42.0
const DRIFT_SPIN := 40.0                         # ± angular velocity (deg/s)
const DRIFT_SCALE_MIN := 0.05                    # default particle scale (rain & snow override these)
const DRIFT_SCALE_MAX := 0.16
const STREAK_SIZE := Vector2i(4, 26)             # the rain-streak bitmap, in px
const STREAK_COLOR := Color(0.75, 0.85, 1.0, 0.55)
const FLAKE_SIZE := 10                           # the snowflake bitmap is FLAKE_SIZE × FLAKE_SIZE px
const FLAKE_RADIUS := 4.5                        # soft-disc radius, and the bitmap's center
const FLAKE_ALPHA := 0.9                         # alpha at the flake's center, fading to 0 at the rim

# --- internal: seed mixing (arbitrary co-primes; they only decorrelate the inputs) --
const SECS_PER_DAY := 86400.0                    # the wander reseeds once per real day
const SEED_DAY_MULT := 31                        # hash(day*SEED_DAY_MULT + i*SEED_I_MULT)
const SEED_I_MULT := 7
const SPREAD_X := 997                            # large primes that fan the hash across the 0..1 ranges
const SPREAD_Y := 991
const PHASE_MOD := 6283                          # phase ∈ [0, PHASE_MOD/PHASE_DIV) ≈ [0, 2π)
const PHASE_DIV := 1000.0

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
		n = mini(n, SPARSE_CAP)
	for i in n:
		var ch := _make_character(i)
		layer.add_child(ch)
	_update_layer(layer)                  # correct positions on the very first frame
	var tw := layer.create_tween().set_loops()
	tw.tween_method(func(_t: float) -> void: _update_layer(layer), 0.0, 1.0, REPATH_SPAN)
	return layer

static func _update_layer(layer: Control) -> void:
	if layer == null or not is_instance_valid(layer) or layer.get_meta("paused", false):
		return
	var t := Time.get_unix_time_from_system()
	var day := int(t / SECS_PER_DAY)
	for i in layer.get_child_count():
		var ch: Control = layer.get_child(i)
		ch.position = _character_pos(i, t, day, layer.size) - ch.size / 2.0

## Pure path function: a slow figure-wander + a gentle vertical bob.
static func _character_pos(i: int, t: float, day_seed: int, bounds: Vector2) -> Vector2:
	var h := hash(day_seed * SEED_DAY_MULT + i * SEED_I_MULT)
	var cx := CENTER_MIN + CENTER_SPAN * float(h % SPREAD_X) / float(SPREAD_X)
	var cy := CENTER_MIN + CENTER_SPAN * float((h / SPREAD_X) % SPREAD_Y) / float(SPREAD_Y)
	var spd := SPEED_BASE + SPEED_STEP * float(i % SPEED_CLASSES)
	var ph := float(h % PHASE_MOD) / PHASE_DIV
	var x := bounds.x * (cx + AMP_X * sin(t * spd + ph))
	var y := bounds.y * (cy + AMP_Y * cos(t * spd * FREQ_Y_RATIO + ph * PHASE_Y_MULT))
	y += BOB_AMP * sin(t * BOB_SPEED + float(i) * BOB_PHASE_STEP)        # the gentle vertical bob
	return Vector2(clampf(x, EDGE_MARGIN, bounds.x - EDGE_MARGIN), clampf(y, EDGE_MARGIN, bounds.y - EDGE_MARGIN))

static func _make_character(i: int) -> Control:
	var kind: String = CHARACTER_TYPES[i % CHARACTER_TYPES.size()]
	var ch := Control.new()
	ch.size = CHAR_SIZE
	ch.pivot_offset = CHAR_SIZE / 2.0
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
		body.size = BODY_SIZE
		body.position = BODY_OFFSET
		var bs := StyleBoxFlat.new()
		bs.bg_color = BODY_COLOR
		bs.set_corner_radius_all(int(BODY_SIZE.x / 2.0))
		bs.shadow_color = BODY_SHADOW
		bs.shadow_size = BODY_SHADOW_SIZE
		body.add_theme_stylebox_override("panel", bs)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ch.add_child(body)
		for e in EYE_COUNT:
			var eye := ColorRect.new()
			eye.color = EYE_COLOR
			eye.size = EYE_SIZE
			eye.position = EYE_ORIGIN + Vector2(e * EYE_SPACING, 0)
			eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ch.add_child(eye)
	return ch

## The tap reaction (pure charm — no mechanics).
static func hop(ch: Control) -> void:
	var tw := ch.create_tween()
	tw.tween_property(ch, "scale", HOP_SQUASH, HOP_T_SQUASH)
	tw.tween_property(ch, "scale", HOP_STRETCH, HOP_T_REST)
	tw.tween_property(ch, "scale", Vector2.ONE, HOP_T_REST)

# --- the win-back (shared; both scenes) --------------------------------------------

## Detects the >=48h return, stamps the rainy minute. Caller persists the blob.
static func check_winback(g: Dictionary, now: float) -> bool:
	if not Features.on("winback_rain_beat"):
		return false
	var last := float(g.get("last_seen", now))
	if now - last >= G.WINBACK_HOURS * SECS_PER_HOUR:
		g["winback_until"] = now + WINBACK_RAIN_SECS
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
	var roll := absi(hash(int(Time.get_unix_time_from_system() / SECS_PER_HOUR))) % ROLL_RANGE
	var w := "clear"
	if roll >= BREEZE_AT and roll < RAIN_AT:
		w = "breeze"
	elif roll >= RAIN_AT and roll < SNOW_AT:
		w = "rain"
	elif roll >= SNOW_AT:
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
			layer.add_child(_drift_emitter(view, FX._pick_tex(BREEZE_PETAL), BREEZE_AMOUNT, BREEZE_PETAL_LIFE, BREEZE_PETAL_VEL))
			layer.add_child(_drift_emitter(view, FX._pick_tex(BREEZE_LEAF), BREEZE_AMOUNT, BREEZE_LEAF_LIFE, BREEZE_LEAF_VEL))
		"rain":
			var rain := _drift_emitter(view, _streak_tex(), RAIN_AMOUNT, RAIN_LIFE, RAIN_VEL)
			rain.position = Vector2(view.x / 2.0, RAIN_TOP_OFFSET)
			rain.scale_amount_min = RAIN_SCALE_MIN        # the tiny streak tex needs ~full size
			rain.scale_amount_max = RAIN_SCALE_MAX
			layer.add_child(rain)
			var veil := ColorRect.new()
			veil.color = RAIN_VEIL
			veil.set_anchors_preset(Control.PRESET_FULL_RECT)
			veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(veil)
		"snow":
			var snow := _drift_emitter(view, _flake_tex(), SNOW_AMOUNT, SNOW_LIFE, SNOW_VEL)
			snow.scale_amount_min = SNOW_SCALE_MIN
			snow.scale_amount_max = SNOW_SCALE_MAX
			layer.add_child(snow)
			var frost := ColorRect.new()       # a cool cast so flakes read on a pale background
			frost.color = SNOW_FROST
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
	p.emission_rect_extents = Vector2(view.x * EMIT_WIDTH_FRAC, EMIT_BAND_H)
	p.position = Vector2(view.x / 2.0, EMIT_TOP_OFFSET)
	p.direction = DRIFT_DIR
	p.spread = DRIFT_SPREAD
	p.gravity = Vector2(vel.x, vel.y)
	p.initial_velocity_min = DRIFT_VEL_MIN
	p.initial_velocity_max = DRIFT_VEL_MAX
	p.angular_velocity_min = -DRIFT_SPIN
	p.angular_velocity_max = DRIFT_SPIN
	p.scale_amount_min = DRIFT_SCALE_MIN
	p.scale_amount_max = DRIFT_SCALE_MAX
	return p

static var _streak: Texture2D
static func _streak_tex() -> Texture2D:
	if _streak == null:
		var img := Image.create(STREAK_SIZE.x, STREAK_SIZE.y, false, Image.FORMAT_RGBA8)
		img.fill(STREAK_COLOR)
		_streak = ImageTexture.create_from_image(img)
	return _streak

static var _flake: Texture2D
static func _flake_tex() -> Texture2D:
	if _flake == null:
		var img := Image.create(FLAKE_SIZE, FLAKE_SIZE, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for x in FLAKE_SIZE:
			for y in FLAKE_SIZE:
				var d := Vector2(x - FLAKE_RADIUS, y - FLAKE_RADIUS).length()
				if d < FLAKE_RADIUS:
					img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d / FLAKE_RADIUS, 0.0, 1.0) * FLAKE_ALPHA))
		_flake = ImageTexture.create_from_image(img)
	return _flake
