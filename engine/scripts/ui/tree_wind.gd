extends RefCounted
## Tree foliage WIND — shared by the grove map (engine/scripts/scenes/map.gd) and the dev map placer
## (games/grove/tools/map_placer.gd) so both sway identically.
##
## A canvas_item shader shears the sprite horizontally by an amount that grows toward the CANOPY (zero at
## the trunk base → the trunk stays planted while leaves/outer branches move). The phase varies across the
## width (UV.x) so the canopy RIPPLES rather than sliding as one rigid slab, and two sine frequencies mix
## so it reads organic. A `gust` envelope (0→1→0, tweened from GDScript) controls WHEN it sways, so trees
## rest then gust in bursts rather than rocking nonstop.
##
## This is the cheap first pass. The fuller realism roadmap (noise turbulence, per-cluster sprites, a
## vertex-grid mesh, a shared wind field) is specced in docs/design/tree-foliage-motion.md.

const SHADER := "shader_type canvas_item;
uniform float phase = 0.0;
uniform float freq = 1.7;
uniform float amp = 0.05;        // peak horizontal shear, as a fraction of sprite width
uniform float trunk = 0.6;       // UV.y at/below this (toward the base) does NOT move
uniform float gust = 0.0;        // 0 = still, 1 = full gust (an envelope, tweened from code)
void fragment() {
	float w = smoothstep(trunk, 0.0, UV.y);                 // canopy weight: 0 at the trunk line → 1 at the top
	float t = TIME * freq + phase + UV.x * 2.4;             // phase shifts across width → a ripple, not a slab
	float sway = sin(t) * 0.7 + sin(t * 2.3 + 1.1) * 0.3;   // a primary sway + a faster, smaller flutter
	float dx = sway * gust * amp * w;
	float dy = sin(t * 1.6) * gust * amp * w * 0.35;        // a little vertical lift/settle on the canopy
	vec2 uv = UV + vec2(dx, dy);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) { COLOR = vec4(0.0); }
	else { COLOR = texture(TEXTURE, uv); }
}"

static var _shader: Shader

static func _res() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader

## Give a tree sprite a fresh, randomized wind material; returns it so the caller can gust it.
static func apply(tree: CanvasItem) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _res()
	m.set_shader_parameter("phase", randf() * TAU)
	m.set_shader_parameter("freq", 1.3 + randf() * 1.1)        # ~1.3–2.4 rad/s
	m.set_shader_parameter("amp", 0.04 + randf() * 0.03)       # peak canopy shear
	m.set_shader_parameter("trunk", 0.56 + randf() * 0.1)      # where the trunk ends / canopy begins
	m.set_shader_parameter("gust", 0.0)
	tree.material = m
	return m

## Recurring random gusts: rest, ramp in, hold, damp out, then reschedule. Tweens bind to `tree`.
static func auto_gust(tree: Node, m: ShaderMaterial) -> void:
	if not is_instance_valid(tree):
		return
	var tw := tree.create_tween()
	tw.tween_interval(4.0 + randf() * 9.0)                                             # rest between gusts
	tw.tween_property(m, "shader_parameter/gust", 1.0, 0.5 + randf() * 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5 + randf() * 0.8)
	tw.tween_property(m, "shader_parameter/gust", 0.0, 1.3 + randf() * 1.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: auto_gust(tree, m))

## Fire ONE gust right now (the placer's manual preview trigger).
static func gust_once(tree: Node, m: ShaderMaterial) -> void:
	if not is_instance_valid(tree):
		return
	var tw := tree.create_tween()
	tw.tween_property(m, "shader_parameter/gust", 1.0, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(m, "shader_parameter/gust", 0.0, 1.6).set_ease(Tween.EASE_IN)
