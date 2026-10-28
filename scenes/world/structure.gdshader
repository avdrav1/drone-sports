shader_type spatial;
// Gates and job props (Story 15.10): a 15.2 surface set mapped triplanar in the
// piece's own space at its tile size, so loose debris carries its texture as it
// falls. `paint` moves the photo to a flat paint colour that keeps the photo's
// light and dark (wear shows through). Rain streaks hang under the top edge
// (vertex COLOR.r is metres below the top / 40), dust settles near the ground,
// COLOR.b shades whole pieces, and wetness and snow cover apply as elsewhere.
// Only features GL Compatibility has.

uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
// R, G: normal X, Y (OpenGL); B: roughness.
uniform sampler2D nr_map : repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec2 tile_size = vec2(1.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform float paint = 0.0;
uniform float metallic = 0.0;
uniform float grime = 0.5;
// 1 paints the tint in diagonal hazard bands with black.
uniform float stripes = 0.0;
uniform float normal_strength = 0.8;
uniform vec3 dust_color : source_color = vec3(0.72, 0.55, 0.4);
// 0 dry to 1 soaked, set by Rain (Story 13.2).
global uniform float wetness;
// 0 bare to 1 white, set by Snow (Story 13.3): settles on what faces up.
global uniform float snow_cover;

varying vec3 obj_pos;
varying vec3 obj_normal;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float luma(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

void fragment() {
	vec3 w = pow(abs(obj_normal), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec2 ux = obj_pos.zy / tile_size;
	vec2 uy = obj_pos.xz / tile_size;
	vec2 uz = obj_pos.xy / tile_size;
	vec3 tex = texture(albedo_map, ux).rgb * w.x + texture(albedo_map, uy).rgb * w.y + texture(albedo_map, uz).rgb * w.z;
	vec3 nx = texture(nr_map, ux).rgb;
	vec3 ny = texture(nr_map, uy).rgb;
	vec3 nz = texture(nr_map, uz).rgb;
	vec3 mean = textureLod(albedo_map, vec2(0.5), 12.0).rgb;

	vec3 color = tint;
	if (stripes > 0.5) {
		float band = step(0.5, fract((obj_pos.x + obj_pos.z + obj_pos.y) * 2.0));
		color = mix(vec3(0.03), tint, band);
	}
	vec3 painted = color * clamp(mix(1.0, luma(tex) / max(luma(mean), 0.01), 0.35), 0.75, 1.2);
	vec3 albedo = mix(tex * color, painted, paint);
	// Whole-piece shade (blocks), and broad patches so the repeat does not show.
	albedo *= 0.8 + 0.4 * COLOR.b;
	float patch = hash(floor(obj_pos.x * 0.7) + floor(obj_pos.y * 0.5) * 7.0 + floor(obj_pos.z * 0.7) * 13.0);
	albedo *= 1.0 - grime * 0.12 * patch;

	// Rain streaks: vertical runs of uneven length under the top edge.
	float below = COLOR.r * 40.0;
	float across = (obj_pos.x + obj_pos.z) * 2.5;
	float column = floor(across);
	float edge = smoothstep(0.0, 0.3, fract(across)) * smoothstep(1.0, 0.7, fract(across));
	float run = 0.4 + 2.5 * hash(column);
	float streak = (1.0 - smoothstep(0.0, run, below)) * hash(column + 3.1) * edge;
	albedo *= 1.0 - grime * 0.3 * streak * (1.0 - abs(world_normal.y));
	// Dust kicked up onto the bottom metre and a half.
	float dust = grime * (1.0 - smoothstep(0.0, 1.5, world_pos.y)) * 0.6;
	albedo = mix(albedo, dust_color * (0.8 + 0.4 * luma(tex)), dust);

	float rough = nx.b * w.x + ny.b * w.y + nz.b * w.z;
	rough = clamp(rough + grime * 0.1 * streak, 0.05, 1.0);
	vec2 bx = nx.rg * 2.0 - 1.0;
	vec2 by = ny.rg * 2.0 - 1.0;
	vec2 bz = nz.rg * 2.0 - 1.0;
	// Map u, v onto the plane's axes: zy, xz, xy (image-up is +v).
	vec3 offset = vec3(0.0, bx.y, bx.x) * w.x + vec3(by.x, 0.0, by.y) * w.y + vec3(bz.x, bz.y, 0.0) * w.z;
	offset -= obj_normal * dot(offset, obj_normal);
	vec3 bent = normalize(obj_normal + offset * normal_strength);

	float up = world_normal.y;
	float wet = wetness * mix(0.6, 1.0, smoothstep(0.6, 0.9, up));
	albedo *= 1.0 - 0.35 * wet * (1.0 - metallic);
	rough = mix(rough, 0.2, wet * 0.8);
	float snow = snow_cover * smoothstep(0.55, 0.85, up);
	albedo = mix(albedo, vec3(0.92, 0.94, 0.97), snow);
	rough = mix(rough, 0.8, snow);

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metallic * (1.0 - snow) * (1.0 - dust);
	vec3 n = mix(bent, obj_normal, snow);
	NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(n, 0.0))).xyz);
}
