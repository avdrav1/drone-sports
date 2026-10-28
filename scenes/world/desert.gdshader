shader_type spatial;
// Textured sand that turns to rock on steep, high ground (Story 15.8): the 15.2
// sand and rock sets in world space at their tile sizes, each also sampled at a
// larger scale so the repeat does not show from drone height, tinted by slow noise
// into the golden-hour palette. Wind ripples on the sand fade with distance.

uniform vec3 sand_color : source_color = vec3(0.9, 0.62, 0.38);
uniform vec3 sand_dark : source_color = vec3(0.78, 0.5, 0.3);
uniform vec3 rock_color : source_color = vec3(0.45, 0.24, 0.15);
uniform vec3 rock_dark : source_color = vec3(0.25, 0.13, 0.09);
uniform sampler2D detail_noise : repeat_enable, filter_linear_mipmap;
// The SurfaceSets' maps; normal_rough packs normal X, Y (OpenGL) in R, G and roughness in B.
uniform sampler2D sand_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_nr : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_nr : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float sand_tile = 3.0;
uniform float rock_tile = 4.0;
// How far the palette tint moves the photo's hue: 0 is the photo, 1 the palette.
uniform float palette_amount = 0.55;
uniform float normal_strength = 0.8;
// Texture normals and ripples fade out by this distance, m.
uniform float detail_fade = 120.0;
uniform float ripple_frequency = 1.4;
uniform float ripple_strength = 0.25;
uniform float ripple_fade = 60.0;
// 0 dry to 1 soaked, set by Rain (Story 13.2): wet sand darkens, flat ground glistens.
global uniform float wetness;
// 0 bare to 1 white, set by Snow (Story 13.3): settles on flat ground, not cliffs.
global uniform float snow_cover;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// A texel moved toward the palette: `mean` is its map's mean colour (the last mip).
vec3 detail(vec3 tex, vec3 mean, vec3 tint) {
	return tex * mix(vec3(1.0), tint / max(mean, vec3(0.01)), palette_amount);
}

void fragment() {
	float broad = texture(detail_noise, world_pos.xz * 0.0005).r;
	float mid = texture(detail_noise, world_pos.xz * 0.006).r;
	float slope = 1.0 - world_normal.y;
	float rockiness = smoothstep(0.12, 0.3, slope + (mid - 0.5) * 0.2) * smoothstep(6.0, 20.0, world_pos.y);
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float near = 1.0 - smoothstep(detail_fade * 0.4, detail_fade, dist);

	// Sand: two scales of the same set, the larger one breaking up the repeat.
	vec2 suv = world_pos.xz / sand_tile;
	vec2 suv_big = world_pos.xz / (sand_tile * 6.3) + vec2(0.37, 0.71);
	vec3 sand_tex = mix(texture(sand_albedo, suv).rgb, texture(sand_albedo, suv_big).rgb, 0.45);
	vec3 snr = texture(sand_nr, suv).rgb;
	vec3 sand_tint = mix(sand_dark, sand_color, smoothstep(0.3, 0.7, broad * 0.85 + mid * 0.15));
	vec3 sand = detail(sand_tex, textureLod(sand_albedo, vec2(0.5), 12.0).rgb, sand_tint);
	vec2 bump = (snr.rg * 2.0 - 1.0) * (1.0 - rockiness);
	// UV u is +X, image-up (OpenGL +Y) is -Z.
	vec3 offset = vec3(bump.x, 0.0, -bump.y);
	float rough = mix(0.95, snr.b, 0.6);

	if (rockiness > 0.001) {
		// Rock: triplanar, so cliffs never stretch.
		vec3 w = pow(abs(world_normal), vec3(4.0));
		w /= w.x + w.y + w.z;
		vec3 p = world_pos / rock_tile;
		vec3 p_big = world_pos / (rock_tile * 7.1);
		vec3 rx = texture(rock_albedo, p.zy).rgb * 0.6 + texture(rock_albedo, p_big.zy).rgb * 0.4;
		vec3 ry = texture(rock_albedo, p.xz).rgb * 0.6 + texture(rock_albedo, p_big.xz).rgb * 0.4;
		vec3 rz = texture(rock_albedo, p.xy).rgb * 0.6 + texture(rock_albedo, p_big.xy).rgb * 0.4;
		vec3 rock_tex = rx * w.x + ry * w.y + rz * w.z;
		vec3 nx = texture(rock_nr, p.zy).rgb;
		vec3 ny = texture(rock_nr, p.xz).rgb;
		vec3 nz = texture(rock_nr, p.xy).rgb;
		vec3 rock = detail(rock_tex, textureLod(rock_albedo, vec2(0.5), 12.0).rgb, mix(rock_dark, rock_color, mid));
		sand = mix(sand, rock, rockiness);
		vec2 bx = nx.rg * 2.0 - 1.0;
		vec2 by = ny.rg * 2.0 - 1.0;
		vec2 bz = nz.rg * 2.0 - 1.0;
		vec3 rock_offset = vec3(0.0, -bx.y, bx.x) * w.x + vec3(by.x, 0.0, -by.y) * w.y + vec3(bz.x, -bz.y, 0.0) * w.z;
		offset += rock_offset * rockiness;
		float rock_rough = nx.b * w.x + ny.b * w.y + nz.b * w.z;
		rough = mix(rough, rock_rough, rockiness);
	}
	ALBEDO = sand;
	float flat_wet = wetness * smoothstep(0.6, 0.9, world_normal.y);
	ALBEDO *= 1.0 - 0.4 * wetness;
	ROUGHNESS = mix(rough, 0.25, flat_wet);
	float flat_snow = snow_cover * smoothstep(0.6, 0.9, world_normal.y);
	ALBEDO = mix(ALBEDO, vec3(0.92, 0.94, 0.97), flat_snow);
	ROUGHNESS = mix(ROUGHNESS, 0.8, flat_snow);
	// Wind ripples on sand: a bent sine across the ground, gone by ripple_fade metres away.
	float phase = dot(world_pos.xz, vec2(0.8, 0.6)) * ripple_frequency + mid * 9.0;
	float amount = ripple_strength * (1.0 - smoothstep(ripple_fade * 0.5, ripple_fade, dist)) * (1.0 - rockiness);
	vec3 bent = world_normal + vec3(0.8, 0.0, 0.6) * cos(phase) * amount;
	bent += offset * normal_strength * near * (1.0 - flat_snow);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(bent), 0.0)).xyz);
}
