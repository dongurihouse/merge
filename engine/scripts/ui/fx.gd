extends RefCounted
## Shared juice helpers (static, like Audio/Save). All scenes use these.
##   const FX = preload("res://engine/scripts/ui/fx.gd")
## Every animation value lives in Tune (engine/scripts/core/tuning.gd → class FX).

const Save = preload("res://engine/scripts/core/save.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")   # §13: every glyph is a sprite via Look.icon — no emoji in floaters
const Pal = Game.PALETTE
const Tune = preload("res://engine/scripts/core/tuning.gd").FX   # the engine's juice dials
const ShatterScript = preload("res://engine/scripts/ui/shatter.gd")

static var _dot_tex: Texture2D

## Calm mode (accessibility): fewer particles, gentler motion. Checked at fire time
## so toggling applies immediately.
static func calm() -> bool:
	return Save.get_setting("calm", false)

## Particle count adjusted for calm mode — shared by fx.burst and main's local burst.
static func amount_for(amount: int) -> int:
	return maxi(Tune.CALM_AMOUNT_FLOOR, int(amount * Tune.CALM_AMOUNT_SCALE)) if calm() else amount

## Shatter a captured veil texture from `impact` (host-local). `bbox` (host-local) is the
## region's opaque bounds — the fracture area. Each shard carries its slice of `texture`, so
## an irregular masked region breaks in its true shape (pixels outside are transparent).
## Used by the home-map unlock to break the purple lock veil. `host` should be a Control/Node2D
## whose local origin matches the texture's pixel origin (a full-view snapshot).
static func shatter_veil(host: Node, texture: Texture2D, bbox: Rect2, impact: Vector2, hold := 0.12) -> void:
	if not (host and is_instance_valid(host)) or texture == null or bbox.size.x < 2.0 or bbox.size.y < 2.0:
		return
	var f := ShatterScript.new()
	host.add_child(f)
	var rect_poly := [bbox.position, bbox.position + Vector2(bbox.size.x, 0.0),
			bbox.position + bbox.size, bbox.position + Vector2(0.0, bbox.size.y)]
	var dust := Color(0.6863, 0.6627, 0.9255, 0.8)   # #AFA9EC, the veil's tint
	# A transparent-viewport snapshot is premultiplied-alpha — tell the field so shards composite
	# to match the veil instead of darkening.
	f.arm(rect_poly, impact, {"texture": texture, "dust": dust, "premultiplied": true}, hold)

static func pop(node: Control) -> void:
	if not (node and is_instance_valid(node)):
		return
	node.pivot_offset = _center_pivot(node)
	var t := node.create_tween()
	t.tween_property(node, "scale", Tune.POP_SCALE, Tune.POP_T_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, Tune.POP_T_SETTLE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The merge result's IMPACT: squash & stretch (the chosen "C" feel). Calm falls back to a
## gentle uniform overshoot. `pop()` stays for taps/confirms — this is for produced tiles.
static func squash_pop(node: Control) -> void:
	if not (node and is_instance_valid(node)):
		return
	node.pivot_offset = _center_pivot(node)
	if calm():
		var c := node.create_tween()
		c.tween_property(node, "scale", Tune.SQUASH_CALM, Tune.POP_T_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		c.tween_property(node, "scale", Vector2.ONE, Tune.POP_T_SETTLE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	node.scale = Tune.SQUASH_K[0]
	var t := node.create_tween()
	for i in range(1, Tune.SQUASH_K.size()):
		t.tween_property(node, "scale", Tune.SQUASH_K[i], Tune.SQUASH_T[i - 1]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## A brief white impact pop over a merged tile (modelled on login_mystery's reel flash).
## `gpos`/`size` are host-local — a `size`×`size` square centred on `gpos`. Gated on
## merge_impact, off under calm. Frees itself.
static func flash(host: Node, gpos: Vector2, size: float, peak := Tune.FLASH_PEAK) -> void:
	if not Features.on("merge_impact") or calm():
		return
	if not (host and is_instance_valid(host)):
		return
	var fl := ColorRect.new()
	fl.color = Color(1, 1, 1, peak)
	fl.size = Vector2(size, size)
	fl.position = gpos - Vector2(size, size) * 0.5
	fl.z_index = Tune.BURST_Z + 1
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(fl)
	var t := fl.create_tween()
	t.tween_property(fl, "modulate:a", 0.0, Tune.FLASH_T).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(fl.queue_free)

## A short decaying positional shake (the "thunk"). Promoted from login_mystery's private
## copy so the board's big-moment escalation and the slot jackpot share one verb. `amp` px;
## settles back to the rest position. No-op under calm (motion accessibility). Callers gate
## on their own flag (e.g. big_moment_shake).
static func shake(node: Control, amp := Tune.SHAKE_AMP) -> void:
	if not (node and is_instance_valid(node)) or not node.is_inside_tree():
		return
	if calm():
		return
	var rest := node.position
	var t := node.create_tween()
	var offs := [Vector2(amp, -amp * 0.5), Vector2(-amp * 0.8, amp * 0.4), Vector2(amp * 0.5, amp * 0.3), Vector2(-amp * 0.3, -amp * 0.2)]
	for o in offs:
		t.tween_property(node, "position", rest + o, Tune.SHAKE_LEG_T).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "position", rest, Tune.SHAKE_SETTLE_T).set_trans(Tween.TRANS_SINE)

# --- hitstop: a global micro-freeze at the moment of impact -------------------------
static var _hitstop_active := false

# "do we want a freeze" — flag ON and not calm. Testable off-headless.
static func hitstop_wanted() -> bool:
	return Features.on("merge_hitstop") and not calm()

# the full gate: wanted AND not headless. A global time_scale change would starve the
# deterministic headless test clock (the grove base pins time_scale=1.0), and a freeze
# is a purely-felt effect with no logic consequence — so it is hard-off in headless.
static func hitstop_enabled() -> bool:
	return hitstop_wanted() and DisplayServer.get_name() != "headless"

## Freeze the whole game for `secs` real-time, then restore. Tweens obey time_scale, so a
## squash_pop started at impact holds its compressed pose during the freeze and plays on
## release; audio ignores time_scale, so the merge sound punches through. The restore timer
## ignores time_scale, so it always fires. Re-entrancy-guarded so rapid merges don't stack.
static func hitstop(secs: float) -> void:
	if not hitstop_enabled() or _hitstop_active or secs <= 0.0:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_hitstop_active = true
	Engine.time_scale = Tune.HITSTOP_SCALE
	var timer := tree.create_timer(secs, true, false, true)   # process_always, ignore_time_scale
	timer.timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		_hitstop_active = false)

## Generator pop anticipation: a quick crouch -> spring -> settle squash as the generator
## spits a tile. Flag-off / calm fall back to the existing `pop()` so a tap still feels
## responsive.
static func gen_charge(node: Control) -> void:
	if not (node and is_instance_valid(node)):
		return
	if not Features.on("gen_anticipation") or calm():
		pop(node)
		return
	node.pivot_offset = _center_pivot(node)
	node.scale = Tune.GEN_CHARGE_K[0]
	var t := node.create_tween()
	for i in range(1, Tune.GEN_CHARGE_K.size()):
		t.tween_property(node, "scale", Tune.GEN_CHARGE_K[i], Tune.GEN_CHARGE_T[i - 1]).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func wobble(node: Control) -> void:
	if not (node and is_instance_valid(node)):
		return
	node.pivot_offset = _center_pivot(node)
	var t := node.create_tween()   # bound to node so it dies with it
	if calm():                     # one gentle tilt instead of a shake
		t.tween_property(node, "rotation", Tune.WOBBLE_CALM_TILT, Tune.WOBBLE_CALM_T_OUT).set_trans(Tween.TRANS_SINE)
		t.tween_property(node, "rotation", 0.0, Tune.WOBBLE_CALM_T_BACK).set_trans(Tween.TRANS_SINE)
		return
	t.tween_property(node, "rotation", Tune.WOBBLE_SHAKE[0], Tune.WOBBLE_SHAKE_T[0])
	t.tween_property(node, "rotation", Tune.WOBBLE_SHAKE[1], Tune.WOBBLE_SHAKE_T[1])
	t.tween_property(node, "rotation", Tune.WOBBLE_SHAKE[2], Tune.WOBBLE_SHAKE_T[2])
	t.tween_property(node, "rotation", 0.0, Tune.WOBBLE_SHAKE_T[3]).set_trans(Tween.TRANS_BACK)

# W1: a gentle, slow ROCK (not a fast shake) — the idle merge hint. Sways ±deg a
# few times so a sleepy player notices the next move without the board feeling jittery.
static func rock(node: Control, deg := Tune.ROCK_DEG, cycle := Tune.ROCK_CYCLE, cycles := Tune.ROCK_CYCLES) -> void:
	if not (node and is_instance_valid(node)):
		return
	node.pivot_offset = _center_pivot(node)
	var rad := deg_to_rad(deg)
	var half := cycle * 0.5
	var t := node.create_tween()   # bound to node so it dies with it
	for i in cycles:
		t.tween_property(node, "rotation", rad, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(node, "rotation", -rad, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "rotation", 0.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# The ONE suggested action pulses ONLY when the feature is on AND calm mode is off.
# Calm mode (§12) disables breathe — the screen quiets without losing function.
static func breathe_active() -> bool:
	return Features.on("breathe_cta") and not calm()

# gentle looping attention pulse (bound to the node — dies with it).
# A no-op under calm: the node rests at its natural scale rather than pulsing.
static func breathe(node: Control, amount := Tune.BREATHE_AMOUNT, period := Tune.BREATHE_PERIOD) -> void:
	if not (node and is_instance_valid(node)):
		return
	if not breathe_active():
		node.scale = Vector2.ONE   # quiet: rest at natural scale, never stuck mid-pulse
		return
	node.pivot_offset = _center_pivot(node)   # scale from the CENTER (size may be 0 pre-layout)
	var t := node.create_tween()
	t.set_loops()
	t.tween_property(node, "scale", Vector2(amount, amount), period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "scale", Vector2.ONE, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	node.set_meta("_fx_breathe_tween", t)   # handle so breathe_stop() can end the loop (it otherwise runs forever)

# Stop a looping breathe (started by breathe / breathe_once): kill its tween, settle back to the
# natural scale, and clear the guard meta so the node can breathe again later. Safe on a node that
# was never breathing (no-op). The COMPLEMENT to breathe_once — a drag-time pulse must end on drop.
static func breathe_stop(node: Control) -> void:
	if not (node and is_instance_valid(node)):
		return
	if node.has_meta("_fx_breathe_tween"):
		var t = node.get_meta("_fx_breathe_tween")
		if t is Tween and t.is_valid():
			t.kill()
		node.remove_meta("_fx_breathe_tween")
	if node.has_meta("_fx_breathing"):
		node.remove_meta("_fx_breathing")
	node.scale = Vector2.ONE

static func floating_text(host: Control, gpos: Vector2, text: String, color: Color, size: int = Tune.FLOAT_SIZE) -> void:
	if not Features.on("floaters"):
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Pal.BG_DEEP)
	lbl.add_theme_constant_override("outline_size", Tune.FLOAT_OUTLINE)
	lbl.position = gpos
	lbl.z_index = Tune.FLOAT_Z
	lbl.pivot_offset = Vector2(size, size) * 0.5
	lbl.scale = Vector2(Tune.FLOAT_SCALE_START, Tune.FLOAT_SCALE_START)
	lbl.rotation = Tune.FLOAT_ROT_START
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(lbl)
	var t := lbl.create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "scale", Tune.FLOAT_SCALE_POP, Tune.FLOAT_T_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "rotation", Tune.FLOAT_ROT_POP, Tune.FLOAT_T_POP).set_trans(Tween.TRANS_BACK)
	t.tween_property(lbl, "position:y", gpos.y - Tune.FLOAT_RISE, Tune.FLOAT_T_RISE).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(Tune.FLOAT_HOLD)
	t.chain().tween_property(lbl, "modulate:a", 0.0, Tune.FLOAT_T_FADE)
	t.chain().tween_callback(lbl.queue_free)

# shout + sparkle at a GLOBAL position (host must be a full-rect root control)
static func celebrate_at(host: Control, gpos: Vector2, text: String, color: Color) -> void:
	if not Features.on("celebrate_bursts"):
		return
	floating_text(host, gpos - Vector2(text.length() * Tune.CELEB_TEXT_DX, Tune.CELEB_TEXT_DY), text, color)
	burst(host, gpos, color, Tune.CELEB_BURST)

## §13 "emoji purge": a drifting reward floater built as an icon SPRITE (Look.icon —
## kit art when generated, the code-drawn glyph until then) NEXT TO a number-only Label.
## The Label text is ALWAYS `prefix + number` (pure ASCII) — never an emoji glyph baked
## into a string. Same drift/pop/fade motion as floating_text. Use this for every
## currency floater (stars/coins/water/gems) so the number "always sits beside an icon"
## and the glyph art-swaps the day the kit lands, instead of staying frozen as an emoji.
## Returns the HBox (the icon + label live under it) for tests / callers; null when gated off.
static func floating_reward(host: Control, gpos: Vector2, icon_id: String, amount: int, color: Color, size: int = Tune.FLOAT_SIZE, prefix: String = "+") -> Control:
	if not Features.on("floaters"):
		return null
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Look.icon(icon_id, float(size))
	row.add_child(ic)
	var lbl := Label.new()
	lbl.text = prefix + str(amount)          # ASCII only — the number sits beside the icon, never an emoji
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Pal.BG_DEEP)
	lbl.add_theme_constant_override("outline_size", Tune.FLOAT_OUTLINE)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	row.position = gpos
	row.z_index = Tune.FLOAT_Z
	row.pivot_offset = Vector2(size, size) * 0.5
	row.scale = Vector2(Tune.FLOAT_SCALE_START, Tune.FLOAT_SCALE_START)
	row.rotation = Tune.FLOAT_ROT_START
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(row)
	var t := row.create_tween()
	t.set_parallel(true)
	t.tween_property(row, "scale", Tune.FLOAT_SCALE_POP, Tune.FLOAT_T_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(row, "rotation", Tune.FLOAT_ROT_POP, Tune.FLOAT_T_POP).set_trans(Tween.TRANS_BACK)
	t.tween_property(row, "position:y", gpos.y - Tune.FLOAT_RISE, Tune.FLOAT_T_RISE).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(Tune.FLOAT_HOLD)
	t.chain().tween_property(row, "modulate:a", 0.0, Tune.FLOAT_T_FADE)
	t.chain().tween_callback(row.queue_free)
	return row

## celebrate_at's icon+number twin: a reward shout (icon sprite + number) + a burst,
## at a GLOBAL position. Routes the currency feedback through floating_reward so no
## emoji is ever baked into the celebrate text. (gated on celebrate_bursts, like celebrate_at.)
static func celebrate_reward(host: Control, gpos: Vector2, icon_id: String, amount: int, color: Color, prefix: String = "+") -> void:
	if not Features.on("celebrate_bursts"):
		return
	floating_reward(host, gpos - Vector2(Tune.CELEB_TEXT_DX * 2.0, Tune.CELEB_TEXT_DY), icon_id, amount, color, Tune.FLOAT_SIZE, prefix)
	burst(host, gpos, color, Tune.CELEB_BURST)

# loop-tween guard: breathing twice on one node compounds the oscillation
static func breathe_once(node: Control) -> void:
	if not (node and is_instance_valid(node)):
		return
	if not breathe_active():
		node.scale = Vector2.ONE   # calm/off: rest at natural scale (don't latch the meta flag)
		return
	if node.has_meta("_fx_breathing"):
		return
	node.set_meta("_fx_breathing", true)
	breathe(node)

# grove particle sprites (petals/leaves/pollen) auto-wire when generated; until
# --- the juice vocabulary — same verbs on every screen ----------------------------

## The CENTER of a node for scale animations. node.size is (0,0) until the node has been
## laid out (e.g. an un-parented card mid-build), which would pivot a scale at the top-left
## corner — so fall back to custom_minimum_size, the intended size set before layout.
static func _center_pivot(node: Control) -> Vector2:
	var sz := node.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		sz = node.custom_minimum_size
	return sz / 2.0

## Overlay cards and confirms enter with this — never a hard cut.
static func pop_in(node: Control) -> void:
	node.pivot_offset = _center_pivot(node)
	node.scale = Vector2(Tune.POPIN_SCALE_START, Tune.POPIN_SCALE_START)
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, Tune.POPIN_T).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, Tune.POPIN_T)

## Staggered arrival for groups (chest items, shop sections/cards).
static func scatter_in(nodes: Array, base_delay := 0.0) -> void:
	if not Features.on("scatter_in"):
		return
	for i in nodes.size():
		var n: Control = nodes[i]
		if n == null or not is_instance_valid(n):
			continue
		n.pivot_offset = _center_pivot(n)
		n.scale = Vector2(Tune.SCATTER_SCALE_START, Tune.SCATTER_SCALE_START)
		var tw := n.create_tween()
		tw.tween_interval(base_delay + Tune.SCATTER_STAGGER * i)
		tw.tween_property(n, "scale", Vector2.ONE, Tune.SCATTER_T).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A wallet number counts toward its target and its chip pulses once.
static func tick(label: Label, to_value: int) -> void:
	if not Features.on("wallet_tick"):
		label.text = str(to_value)
		return
	var from := int(label.text) if label.text.is_valid_int() else 0
	var tw := label.create_tween()
	tw.tween_method(func(v: float) -> void: label.text = str(int(v)), float(from), float(to_value), Tune.TICK_T_COUNT)
	var chip: Node = label.get_parent()
	while chip != null and not chip is PanelContainer:
		chip = chip.get_parent()
	if chip is Control:
		var c := chip as Control
		c.pivot_offset = c.size / 2.0
		var pw := c.create_tween()
		pw.tween_property(c, "scale", Tune.TICK_CHIP_SCALE, Tune.TICK_CHIP_T_OUT).set_trans(Tween.TRANS_QUAD)
		pw.tween_property(c, "scale", Vector2.ONE, Tune.TICK_CHIP_T_BACK)

## A grant arcs its icon to the wallet chip, then runs `then` (usually tick).
static func fly_to_wallet(host: Control, from_gpos: Vector2, fly_icon: Control, to_chip: Control, then: Callable = Callable()) -> void:
	if not Features.on("fly_to_wallet"):
		if fly_icon != null:
			fly_icon.queue_free()
		if then.is_valid():
			then.call()
		return
	if fly_icon == null:
		if then.is_valid():
			then.call()
		return
	host.add_child(fly_icon)
	fly_icon.global_position = from_gpos - Tune.FLY_ICON_OFFSET
	fly_icon.z_index = Tune.FLY_Z
	var dest: Vector2 = to_chip.get_global_rect().get_center() - Tune.FLY_ICON_OFFSET \
		if to_chip != null and is_instance_valid(to_chip) else from_gpos + Tune.FLY_FALLBACK
	var mid: Vector2 = (from_gpos + dest) / 2.0 + Tune.FLY_ARC
	var tw := fly_icon.create_tween()
	tw.tween_property(fly_icon, "global_position", mid, Tune.FLY_T_UP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fly_icon, "global_position", dest, Tune.FLY_T_DOWN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(fly_icon, "scale", Tune.FLY_SCALE, Tune.FLY_T_DOWN)
	tw.tween_callback(func() -> void:
		fly_icon.queue_free()
		if then.is_valid():
			then.call())

# then bursts use the soft dot. Choice follows the color's mood (gold → pollen,
# green → leaf, else petal) — the hand-painted FX style.
static var _grove_tex := {}

static func _pick_tex(color: Color) -> Texture2D:
	var id := "p_pollen" if color.r > Tune.POLLEN_R and color.g > Tune.POLLEN_G and color.b < Tune.POLLEN_B \
		else ("p_leaf" if color.g > color.r else "p_petal")
	if _grove_tex.has(id):
		return _grove_tex[id]
	var path := Game.art("ui/fx/%s.png" % id)
	if ResourceLoader.exists(path):
		_grove_tex[id] = load(path)
		return _grove_tex[id]
	if _dot_tex == null:
		_dot_tex = _make_dot_texture()
	return _dot_tex

static func burst(host: Node, center: Vector2, color: Color, amount: int = Tune.BURST_AMOUNT) -> void:
	if not Features.on("celebrate_bursts"):
		return
	var tex := _pick_tex(color)
	var grove := tex != _dot_tex
	var p := GPUParticles2D.new()
	p.texture = tex
	p.position = center
	p.amount = amount_for(amount)
	p.lifetime = Tune.BURST_GROVE_LIFE if grove else Tune.BURST_DOT_LIFE      # grove juice is floaty, breezy, settling
	p.one_shot = true
	p.explosiveness = 1.0
	p.z_index = Tune.BURST_Z
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = Tune.BURST_EMIT_RADIUS
	mat.direction = Vector3(0, -1, 0)
	mat.spread = Tune.BURST_SPREAD
	mat.gravity = Vector3(0, Tune.BURST_GROVE_GRAVITY, 0) if grove else Vector3(0, Tune.BURST_DOT_GRAVITY, 0)
	mat.initial_velocity_min = Tune.BURST_GROVE_VEL_MIN if grove else Tune.BURST_DOT_VEL_MIN
	mat.initial_velocity_max = Tune.BURST_GROVE_VEL_MAX if grove else Tune.BURST_DOT_VEL_MAX
	mat.angular_velocity_min = -Tune.BURST_GROVE_SPIN if grove else 0.0
	mat.angular_velocity_max = Tune.BURST_GROVE_SPIN if grove else 0.0
	mat.scale_min = Tune.BURST_GROVE_SCALE_MIN if grove else Tune.BURST_DOT_SCALE_MIN   # particle sprites are 128px; dots are 24px
	mat.scale_max = Tune.BURST_GROVE_SCALE_MAX if grove else Tune.BURST_DOT_SCALE_MAX
	mat.color = color if not grove else Tune.BURST_GROVE_TINT   # sprites carry their own paint
	p.process_material = mat
	host.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

static func _make_dot_texture() -> Texture2D:
	var n := Tune.DOT_TEX_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := n / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x - c + 0.5, y - c + 0.5).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
