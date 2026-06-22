shader_type canvas_item;

// "Locked region" cover: a see-through enchanted veil over an un-restored region, alpha-blended
// over the art + the ominous vines beneath it. Gated by region_enabled (an owned region clears).
// Region membership is read from the region map's GREEN channel (region 0 encodes to red 0.0, so
// green tells a region-0 pixel apart from the background); the RED channel is the region index.
//
// The raw region map is a hard polygon fill sampled filter_nearest — a single tap gives a "die-cut"
// geometric edge that reads as fake. We make it read as MIST instead:
//   • domain-warp the boundary with fbm noise → an organic, torn edge (not the polygon outline)
//   • 3×3 feather of this-region coverage → soft, anti-aliased transition
//   • interior density noise → a cloudy veil, not a flat slab
//   • slow TIME drift → it breathes/flows like the vines under it
uniform sampler2D region_map_texture : repeat_disable, filter_nearest;
uniform float region_index = 0.0;
uniform float region_count = 8.0;
uniform float region_enabled = 1.0;
uniform vec4 tint_color : source_color = vec4(0.6863, 0.6627, 0.9255, 0.34);
uniform vec2 mask_offset_uv = vec2(0.0, 0.0);
uniform float feather = 2.5;        // soft-edge width, in region-map texels
uniform float warp_amt = 0.06;      // how far noise tears the edge (UV units); 0 = clean polygon
uniform float noise_scale = 9.0;    // noise frequency across the view
uniform float mist = 0.45;          // interior density variation (0 = flat fill)
uniform float drift = 0.03;         // slow flow speed

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

// 1.0 where the sampled pixel belongs to THIS region, else 0.0.
float region_cov(vec2 uv, float max_index) {
	vec4 rm = texture(region_map_texture, clamp(uv, vec2(0.0), vec2(1.0)));
	float member = step(0.5, rm.g);
	float sampled_index = floor(rm.r * max_index + 0.5);
	float matches = 1.0 - step(0.5, abs(sampled_index - region_index));
	return member * matches;
}

void fragment() {
	float max_index = max(region_count - 1.0, 1.0);
	float t = TIME * drift;

	// domain warp: push the sample position around with fbm so the boundary tears organically.
	vec2 warp = vec2(fbm(UV * noise_scale + t), fbm(UV * noise_scale + vec2(5.2, 1.3) - t)) - 0.5;
	vec2 wuv = (UV - mask_offset_uv) + warp * warp_amt;

	// 3×3 feathered coverage at the warped position → soft, anti-aliased edge.
	vec2 d = (1.0 / vec2(textureSize(region_map_texture, 0))) * feather;
	float cov = 0.0;
	cov += region_cov(wuv + vec2(-1.0, -1.0) * d, max_index);
	cov += region_cov(wuv + vec2( 0.0, -1.0) * d, max_index);
	cov += region_cov(wuv + vec2( 1.0, -1.0) * d, max_index);
	cov += region_cov(wuv + vec2(-1.0,  0.0) * d, max_index);
	cov += region_cov(wuv + vec2( 0.0,  0.0) * d, max_index);
	cov += region_cov(wuv + vec2( 1.0,  0.0) * d, max_index);
	cov += region_cov(wuv + vec2(-1.0,  1.0) * d, max_index);
	cov += region_cov(wuv + vec2( 0.0,  1.0) * d, max_index);
	cov += region_cov(wuv + vec2( 1.0,  1.0) * d, max_index);
	cov /= 9.0;

	// interior mist: vary the veil density so it looks cloudy, not a flat sticker.
	float m = fbm(UV * noise_scale * 1.7 + vec2(11.0) + t * 0.5);
	float density = 1.0 - mist * (1.0 - m);

	float a = tint_color.a * cov * region_enabled * density;
	COLOR = vec4(tint_color.rgb, a);
}
