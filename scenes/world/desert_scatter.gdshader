shader_type spatial;
render_mode cull_disabled;
// Desert scatter (Story 15.8): a colour per material, varied in patches between
// base_color and alt_color and per instance by INSTANCE_CUSTOM.r, darker low down,
// with the 15.2 rock set mapped triplanar in world space where texture_amount > 0.
// Where leafy > 0, edges seen side-on break into holes so scrub reads as foliage,
// not stone. Wets and snows like the ground. A mesh with vertex colours marks
// its wood in black: that part is trunk_color, and is never cut into leaves.

uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D nr_map : repeat_enable, filter_linear_mipmap;
uniform vec3 base_color : source_color = vec3(0.6, 0.45, 0.35);
uniform vec3 alt_color : source_color = vec3(0.6, 0.45, 0.35);
// Size of the patches that pick between base_color and alt_color, m.
uniform float patch_size = 0.6;
// How much darker the mesh is at its foot than 0.6 m up (self-shading).
uniform float foot_dark = 0.0;
uniform float tile = 4.0;
// 0 is flat vertex colour; 1 the texture's light and dark over it.
uniform float texture_amount = 0.0;
uniform float roughness = 0.85;
// How far the per-instance tint moves brightness either way.
uniform float tint_range = 0.25;
// Fraction of a silhouette's cells cut away, 0 for solid.
uniform float leafy = 0.0;
uniform float leaf_size = 0.09;
uniform vec3 trunk_color : source_color = vec3(0.3, 0.22, 0.16);
global uniform float wetness;
global uniform float snow_cover;

varying vec3 world_pos;
varying vec3 world_normal;
varying float tint;
varying float local_y;
varying float leaf;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tint = INSTANCE_CUSTOM.r;
	local_y = VERTEX.y;
	leaf = COLOR.r;
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	if (leafy > 0.0 && leaf > 0.5) {
		float edge = 1.0 - abs(dot(NORMAL, VIEW));
		if (hash(floor(world_pos / leaf_size)) < leafy * (0.25 + edge)) {
			discard;
		}
	}
	vec3 base = mix(base_color, alt_color, hash(floor(world_pos / patch_size) + 0.5));
	base = mix(trunk_color, base, step(0.5, leaf));
	base *= (1.0 + (tint - 0.5) * 2.0 * tint_range) * (1.0 - foot_dark * (1.0 - smoothstep(0.0, 0.6, local_y)));
	float rough = roughness;
	vec3 n = FRONT_FACING ? world_normal : -world_normal;
	if (texture_amount > 0.0) {
		vec3 w = pow(abs(world_normal), vec3(4.0));
		w /= w.x + w.y + w.z;
		vec3 p = world_pos / tile;
		vec3 mean = textureLod(albedo_map, vec2(0.5), 12.0).rgb;
		vec3 tex = texture(albedo_map, p.zy).rgb * w.x + texture(albedo_map, p.xz).rgb * w.y + texture(albedo_map, p.xy).rgb * w.z;
		base = mix(base, base * tex / mean, texture_amount);
		vec3 nx = texture(nr_map, p.zy).rgb;
		vec3 ny = texture(nr_map, p.xz).rgb;
		vec3 nz = texture(nr_map, p.xy).rgb;
		vec2 bx = nx.rg * 2.0 - 1.0;
		vec2 by = ny.rg * 2.0 - 1.0;
		vec2 bz = nz.rg * 2.0 - 1.0;
		n += (vec3(0.0, -bx.y, bx.x) * w.x + vec3(by.x, 0.0, -by.y) * w.y + vec3(bz.x, -bz.y, 0.0) * w.z) * texture_amount;
		rough = mix(rough, nx.b * w.x + ny.b * w.y + nz.b * w.z, texture_amount);
	}
	ALBEDO = base * (1.0 - 0.4 * wetness);
	ROUGHNESS = mix(rough, 0.3, wetness * 0.7);
	float top_snow = snow_cover * smoothstep(0.5, 0.9, world_normal.y);
	ALBEDO = mix(ALBEDO, vec3(0.92, 0.94, 0.97), top_snow);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(n), 0.0)).xyz);
}
