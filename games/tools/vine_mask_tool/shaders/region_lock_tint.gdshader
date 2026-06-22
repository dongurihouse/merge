shader_type canvas_item;

// Flat "locked region" cover: fills a region's polygon with a uniform see-through tint, normal
// (alpha) blended so it veils the art + the additive vines beneath it. Gated by the same
// region_enabled toggle the vines use, so an owned region clears instantly. Region membership is
// read from the region map's GREEN channel (region 0 encodes to red 0.0, identical to the
// background fill — green is what tells a region-0 pixel apart from a non-region pixel).
uniform sampler2D region_map_texture : repeat_disable, filter_nearest;
uniform float region_index = 0.0;
uniform float region_count = 8.0;
uniform float region_enabled = 1.0;
uniform vec4 tint_color : source_color = vec4(0.6863, 0.6627, 0.9255, 0.34);
// This cover layer is full-view (NOT translated by the mask offset like the vines). Subtracting the
// offset (in UV) makes it sample the SAME region the vines do at each pixel; clamp-to-edge then
// bleeds the edge region's tint outward, so a shifted mask never exposes background on the edges.
uniform vec2 mask_offset_uv = vec2(0.0, 0.0);

void fragment() {
	vec4 rm = texture(region_map_texture, clamp(UV - mask_offset_uv, vec2(0.0), vec2(1.0)));
	float member = step(0.5, rm.g);
	float max_index = max(region_count - 1.0, 1.0);
	float sampled_index = floor(rm.r * max_index + 0.5);
	float matches = 1.0 - step(0.5, abs(sampled_index - region_index));
	float a = tint_color.a * member * matches * region_enabled;
	COLOR = vec4(tint_color.rgb, a);
}
