shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 vine_color : source_color = vec4(0.62, 0.10, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.95, 0.72, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 2.0) = 0.95;
uniform float glow_radius : hint_range(0.0, 0.03) = 0.006;
uniform float glow_strength : hint_range(0.0, 4.0) = 1.2;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.2;
uniform float flow_speed : hint_range(0.0, 8.0) = 1.2;
uniform float edge_power : hint_range(0.5, 8.0) = 2.4;
uniform float breath_strength : hint_range(0.0, 2.0) = 0.35;
uniform float heartbeat_strength : hint_range(0.0, 2.0) = 0.45;
uniform float lightning_strength : hint_range(0.0, 3.0) = 0.65;
uniform float shimmer_strength : hint_range(0.0, 0.02) = 0.004;
uniform float energy_crawl_strength : hint_range(0.0, 2.0) = 0.75;
uniform sampler2D mask_texture : repeat_disable, filter_linear;
uniform vec2 mask_pixel_size = vec2(0.001062699, 0.000598086);
uniform sampler2D region_map_texture : repeat_disable, filter_nearest;
uniform float region_index = 0.0;
uniform float region_count = 8.0;
uniform float region_enabled = 1.0;

// highp is required: a phone GPU (mobile renderer) honors mediump and the large `* 43758.x` overflows
// fp16 mantissa, turning the noise into harsh bands. Desktop already promotes to fp32, so this matches
// the two. No-op on desktop.
float hash(highp vec2 p) {
	highp float d = dot(p, vec2(127.1, 311.7));
	return fract(sin(d) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float mask_at(vec2 uv) {
	return texture(mask_texture, clamp(uv, vec2(0.0), vec2(1.0))).r;
}

float region_gate(vec2 uv) {
	// The boundary's organic shape is baked into the region map (_rebuild_region_map warps the
	// rasterization with noise), so every overlay inherits the same torn edge — here it's a plain
	// membership test.
	float max_index = max(region_count - 1.0, 1.0);
	float encoded = texture(region_map_texture, clamp(uv, vec2(0.0), vec2(1.0))).r;
	float sampled_index = floor(encoded * max_index + 0.5);
	float matches = 1.0 - step(0.5, abs(sampled_index - region_index));
	return matches * region_enabled;
}

void fragment() {
	vec2 uv = UV;
	float shimmer_noise = noise(uv * 48.0 + vec2(TIME * flow_speed * 0.9, -TIME * flow_speed * 0.55));
	vec2 shimmer_uv = uv + vec2(
		sin((uv.y * 52.0) + TIME * flow_speed * 2.3 + shimmer_noise * 3.0),
		cos((uv.x * 47.0) - TIME * flow_speed * 1.8 + shimmer_noise * 2.4)
	) * shimmer_strength;

	float gate = region_gate(uv);
	float mask = mask_at(shimmer_uv) * gate;

	vec2 texel = mask_pixel_size * max(glow_radius * 900.0, 1.0);
	float halo = mask;
	halo = max(halo, mask_at(uv + vec2(texel.x, 0.0)));
	halo = max(halo, mask_at(uv - vec2(texel.x, 0.0)));
	halo = max(halo, mask_at(uv + vec2(0.0, texel.y)));
	halo = max(halo, mask_at(uv - vec2(0.0, texel.y)));
	halo = max(halo, mask_at(uv + texel));
	halo = max(halo, mask_at(uv - texel));
	halo = max(halo, mask_at(uv + vec2(texel.x, -texel.y)));
	halo = max(halo, mask_at(uv + vec2(-texel.x, texel.y)));

	float t = TIME * flow_speed;
	float crawl = noise(shimmer_uv * 35.0 + vec2(t * 0.45, -t * 0.28));
	float fine = noise(shimmer_uv * 95.0 + vec2(-t * 0.75, t * 0.38));
	float energy_wave = 0.5 + 0.5 * sin((shimmer_uv.y * 58.0 + shimmer_uv.x * 23.0) - TIME * flow_speed * 4.2);
	float crawl_band = smoothstep(0.48, 0.78, energy_wave + crawl * 0.28) * energy_crawl_strength;
	float wave = 0.5 + 0.5 * sin((shimmer_uv.y * 34.0 + shimmer_uv.x * 17.0) - TIME * pulse_speed);
	float breath = 1.0 + breath_strength * (0.5 + 0.5 * sin(TIME * max(pulse_speed * 0.45, 0.1)));
	float heartbeat_phase = fract(TIME * 0.72);
	float heartbeat = exp(-pow(heartbeat_phase - 0.08, 2.0) * 220.0) + exp(-pow(heartbeat_phase - 0.18, 2.0) * 180.0) * 0.55;
	float lightning_seed = noise(vec2(floor(TIME * 1.7), region_index * 13.37));
	float lightning_window = step(0.72, lightning_seed) * exp(-fract(TIME * 1.7) * 10.0);
	float lightning_path = smoothstep(0.68, 0.94, noise(shimmer_uv * 125.0 + vec2(TIME * 8.0, region_index * 4.0)));
	float lightning = lightning_window * lightning_path * lightning_strength;
	float pulse = (0.62 + 0.38 * sin(TIME * pulse_speed + crawl * 5.5)) * breath + heartbeat * heartbeat_strength + lightning;

	float living = clamp(0.45 + crawl * 0.35 + fine * 0.20 + wave * 0.25 + crawl_band * 0.55 + lightning * 0.9, 0.0, 2.4);
	float core = pow(mask, edge_power) * living * pulse;
	float aura = max(halo - mask * 0.35, 0.0) * glow_strength * (0.55 + wave * 0.45) * gate;

	vec3 color = mix(vine_color.rgb, core_color.rgb, clamp(core + lightning, 0.0, 1.0));
	float alpha = clamp((core + aura) * opacity, 0.0, 1.0);

	COLOR = vec4(color * (core * 1.6 + aura * 0.85 + lightning * 1.8), alpha);
}
