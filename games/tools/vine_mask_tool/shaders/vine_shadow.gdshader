shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 shadow_color : source_color = vec4(0.045, 0.0, 0.075, 1.0);
uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.18;
uniform float shadow_radius : hint_range(0.0, 0.04) = 0.018;
uniform sampler2D mask_texture : repeat_disable, filter_linear;
uniform vec2 mask_pixel_size = vec2(0.001062699, 0.000598086);
uniform sampler2D region_map_texture : repeat_disable, filter_nearest;
uniform float region_index = 0.0;
uniform float region_count = 8.0;
uniform float region_enabled = 1.0;

float mask_at(vec2 uv) {
	return texture(mask_texture, clamp(uv, vec2(0.0), vec2(1.0))).r;
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
	vec2 texel = mask_pixel_size * max(shadow_radius * 900.0, 1.0);
	float spread = mask_at(uv);
	spread = max(spread, mask_at(uv + vec2(texel.x, 0.0)));
	spread = max(spread, mask_at(uv - vec2(texel.x, 0.0)));
	spread = max(spread, mask_at(uv + vec2(0.0, texel.y)));
	spread = max(spread, mask_at(uv - vec2(0.0, texel.y)));
	spread = max(spread, mask_at(uv + texel));
	spread = max(spread, mask_at(uv - texel));
	float breathe = 0.7 + 0.3 * sin(TIME * 0.8 + region_index);
	float alpha = clamp(spread * shadow_opacity * breathe * gate, 0.0, 0.85);
	COLOR = vec4(shadow_color.rgb, alpha);
}
