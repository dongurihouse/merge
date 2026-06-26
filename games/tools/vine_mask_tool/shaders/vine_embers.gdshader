shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 ember_color : source_color = vec4(0.82, 0.22, 1.0, 1.0);
uniform float ember_opacity : hint_range(0.0, 2.0) = 0.55;
uniform float ember_density : hint_range(10.0, 120.0) = 54.0;
uniform float ember_speed : hint_range(0.0, 3.0) = 0.45;
uniform sampler2D mask_texture : repeat_disable, filter_linear;
uniform sampler2D region_map_texture : repeat_disable, filter_nearest;
uniform float region_index = 0.0;
uniform float region_count = 8.0;
uniform float region_enabled = 1.0;

// highp is required: a phone GPU (mobile renderer) honors mediump and the large `* 19342.x` overflows
// fp16 mantissa, breaking the per-cell ember seed. Desktop already promotes to fp32, so this matches
// the two. No-op on desktop.
float hash(highp vec2 p) {
	highp float d = dot(p, vec2(41.13, 289.97));
	return fract(sin(d) * 19342.937);
}

float region_gate(vec2 uv) {
	float max_index = max(region_count - 1.0, 1.0);
	float encoded = texture(region_map_texture, clamp(uv, vec2(0.0), vec2(1.0))).r;
	float sampled_index = floor(encoded * max_index + 0.5);
	float matches = 1.0 - step(0.5, abs(sampled_index - region_index));
	return matches * region_enabled;
}

void fragment() {
	vec2 uv = UV;
	float gate = region_gate(uv);
	vec2 drift_uv = uv + vec2(0.0, TIME * ember_speed * 0.08);
	vec2 cell = floor(drift_uv * ember_density);
	vec2 local = fract(drift_uv * ember_density) - 0.5;
	float seed = hash(cell + vec2(region_index * 17.0, floor(TIME * 0.25)));
	float active = step(0.78, seed);
	vec2 ember_center = vec2(hash(cell + 3.7), hash(cell + 9.1)) - 0.5;
	float dist = length(local - ember_center * 0.62);
	float mote = smoothstep(0.09, 0.0, dist) * active;
	float source = texture(mask_texture, clamp(uv + vec2(0.0, 0.035), vec2(0.0), vec2(1.0))).r;
	float flicker = 0.55 + 0.45 * sin(TIME * 8.0 + seed * 9.0);
	float alpha = mote * source * gate * ember_opacity * flicker;
	COLOR = vec4(ember_color.rgb * alpha * 2.2, alpha);
}
