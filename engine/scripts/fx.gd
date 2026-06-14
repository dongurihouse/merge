extends RefCounted
## Tidy Up — shared juice helpers (static, like Audio/Save). All grove screens use these.
##   const FX = preload("res://engine/scripts/fx.gd")

const Palette = preload("res://engine/scripts/palette.gd")
const Save = preload("res://engine/scripts/save.gd")
const Features = preload("res://engine/scripts/features.gd")

static var _dot_tex: Texture2D

## Calm mode (accessibility): fewer particles, gentler motion. Checked at fire time
## so toggling applies immediately.
static func calm() -> bool:
	return Save.get_setting("calm", false)

## Particle count adjusted for calm mode — shared by fx.burst and main's local burst.
static func amount_for(amount: int) -> int:
	return maxi(4, int(amount * 0.4)) if calm() else amount

static func pop(node: Control) -> void:
	if not (node and is_instance_valid(node)):
		return
	node.pivot_offset = node.size / 2.0
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func wobble(node: Control) -> void:
	if not (node and is_instance_valid(node)):
		return
	node.pivot_offset = node.size / 2.0
	var t := node.create_tween()   # bound to node so it dies with it
	if calm():                     # one gentle tilt instead of a shake
		t.tween_property(node, "rotation", 0.07, 0.12).set_trans(Tween.TRANS_SINE)
		t.tween_property(node, "rotation", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
		return
	t.tween_property(node, "rotation", 0.22, 0.05)
	t.tween_property(node, "rotation", -0.17, 0.06)
	t.tween_property(node, "rotation", 0.09, 0.05)
	t.tween_property(node, "rotation", 0.0, 0.05).set_trans(Tween.TRANS_BACK)

# W1: a gentle, slow ROCK (not a fast shake) — the idle merge hint. Sways ±deg a
# few times so a sleepy player notices the next move without the board feeling jittery.
static func rock(node: Control, deg := 6.0, cycle := 1.2, cycles := 3) -> void:
	if not (node and is_instance_valid(node)):
		return
	node.pivot_offset = node.size / 2.0
	var rad := deg_to_rad(deg)
	var half := cycle * 0.5
	var t := node.create_tween()   # bound to node so it dies with it
	for i in cycles:
		t.tween_property(node, "rotation", rad, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(node, "rotation", -rad, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "rotation", 0.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# gentle looping attention pulse (bound to the node — dies with it)
static func breathe(node: Control, amount := 1.05, period := 0.9) -> void:
	node.pivot_offset = node.size / 2.0
	var t := node.create_tween()
	t.set_loops()
	t.tween_property(node, "scale", Vector2(amount, amount), period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "scale", Vector2.ONE, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

static func floating_text(host: Control, gpos: Vector2, text: String, color: Color, size: int = 44) -> void:
	if not Features.on("floaters"):
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	lbl.add_theme_constant_override("outline_size", 10)
	lbl.position = gpos
	lbl.z_index = 60
	lbl.pivot_offset = Vector2(size, size) * 0.5
	lbl.scale = Vector2(0.4, 0.4)
	lbl.rotation = -0.12
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(lbl)
	var t := lbl.create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "rotation", 0.06, 0.16).set_trans(Tween.TRANS_BACK)
	t.tween_property(lbl, "position:y", gpos.y - 75.0, 0.75).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(0.18)
	t.chain().tween_property(lbl, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(lbl.queue_free)

# shout + sparkle at a GLOBAL position (host must be a full-rect root control)
static func celebrate_at(host: Control, gpos: Vector2, text: String, color: Color) -> void:
	if not Features.on("celebrate_bursts"):
		return
	floating_text(host, gpos - Vector2(text.length() * 11.0, 64.0), text, color)
	burst(host, gpos, color, 20)

# loop-tween guard: breathing twice on one node compounds the oscillation
static func breathe_once(node: Control) -> void:
	if not Features.on("breathe_cta"):
		return
	if node.has_meta("_fx_breathing"):
		return
	node.set_meta("_fx_breathing", true)
	breathe(node)

# grove particle sprites (petals/leaves/pollen) auto-wire when generated; until
# --- the §6 juice vocabulary (GROVE_UI_SPEC) — same verbs on every screen ---------

## Overlay cards and confirms enter with this — never a hard cut.
static func pop_in(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2(0.92, 0.92)
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.12)

## Staggered arrival for groups (chest items, shop sections/cards).
static func scatter_in(nodes: Array, base_delay := 0.0) -> void:
	if not Features.on("scatter_in"):
		return
	for i in nodes.size():
		var n: Control = nodes[i]
		if n == null or not is_instance_valid(n):
			continue
		n.pivot_offset = n.size / 2.0
		n.scale = Vector2(0.3, 0.3)
		var tw := n.create_tween()
		tw.tween_interval(base_delay + 0.04 * i)
		tw.tween_property(n, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A wallet number counts toward its target and its chip pulses once.
static func tick(label: Label, to_value: int) -> void:
	if not Features.on("wallet_tick"):
		label.text = str(to_value)
		return
	var from := int(label.text) if label.text.is_valid_int() else 0
	var tw := label.create_tween()
	tw.tween_method(func(v: float) -> void: label.text = str(int(v)), float(from), float(to_value), 0.4)
	var chip: Node = label.get_parent()
	while chip != null and not chip is PanelContainer:
		chip = chip.get_parent()
	if chip is Control:
		var c := chip as Control
		c.pivot_offset = c.size / 2.0
		var pw := c.create_tween()
		pw.tween_property(c, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_QUAD)
		pw.tween_property(c, "scale", Vector2.ONE, 0.14)

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
	fly_icon.global_position = from_gpos - Vector2(16, 16)
	fly_icon.z_index = 60
	var dest: Vector2 = to_chip.get_global_rect().get_center() - Vector2(16, 16) \
		if to_chip != null and is_instance_valid(to_chip) else from_gpos + Vector2(0, -200)
	var mid: Vector2 = (from_gpos + dest) / 2.0 + Vector2(0, -110)
	var tw := fly_icon.create_tween()
	tw.tween_property(fly_icon, "global_position", mid, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fly_icon, "global_position", dest, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(fly_icon, "scale", Vector2(0.55, 0.55), 0.22)
	tw.tween_callback(func() -> void:
		fly_icon.queue_free()
		if then.is_valid():
			then.call())

# then bursts use the soft dot. Choice follows the color's mood (gold → pollen,
# green → leaf, else petal), per GROVE_STYLE §5.
static var _grove_tex := {}

static func _pick_tex(color: Color) -> Texture2D:
	var id := "p_pollen" if color.r > 0.7 and color.g > 0.55 and color.b < 0.5 \
		else ("p_leaf" if color.g > color.r else "p_petal")
	if _grove_tex.has(id):
		return _grove_tex[id]
	var path := "res://assets/fx/%s.png" % id
	if ResourceLoader.exists(path):
		_grove_tex[id] = load(path)
		return _grove_tex[id]
	if _dot_tex == null:
		_dot_tex = _make_dot_texture()
	return _dot_tex

static func burst(host: Node, center: Vector2, color: Color, amount: int = 14) -> void:
	if not Features.on("celebrate_bursts"):
		return
	var tex := _pick_tex(color)
	var grove := tex != _dot_tex
	var p := GPUParticles2D.new()
	p.texture = tex
	p.position = center
	p.amount = amount_for(amount)
	p.lifetime = 1.1 if grove else 0.55      # grove juice is floaty, breezy, settling
	p.one_shot = true
	p.explosiveness = 1.0
	p.z_index = 30
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 6.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, 130, 0) if grove else Vector3(0, 320, 0)
	mat.initial_velocity_min = 60.0 if grove else 110.0
	mat.initial_velocity_max = 170.0 if grove else 280.0
	mat.angular_velocity_min = -160.0 if grove else 0.0
	mat.angular_velocity_max = 160.0 if grove else 0.0
	mat.scale_min = 0.05 if grove else 0.4   # particle sprites are 128px; dots are 24px
	mat.scale_max = 0.14 if grove else 1.0
	mat.color = color if not grove else Color(1, 1, 1, 0.95)   # sprites carry their own paint
	p.process_material = mat
	host.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

static func _make_dot_texture() -> Texture2D:
	var n := 24
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := n / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x - c + 0.5, y - c + 0.5).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
