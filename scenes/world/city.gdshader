shader_type spatial;
// Box towers. Windows are laid out in world space so the grid stays square on
// any building. Walls take one of four library surfaces (Story 15.4) and roofs a
// fifth, all mapped in world space at each set's tile size so nothing stretches,
// then weathered: grime streaks under windows and the roof edge, dust and contact
// shadow at the base, stains on the roof. Per instance: COLOR tints the walls,
// INSTANCE_CUSTOM.x seeds which windows are lit, .y is the fraction lit and .z is
// the wall surface (0 to 3). Only features GL Compatibility has.

// Wall surfaces, set by City from its `walls` list. tile is metres per repeat.
uniform sampler2D wall_albedo_0 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wall_albedo_1 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wall_albedo_2 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wall_albedo_3 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wall_nr_0 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D wall_nr_1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D wall_nr_2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D wall_nr_3 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 wall_tile[4];
uniform float wall_metallic[4];
// Facade metal is painted or anodised, not bare: scale the set's metallic so a
// clad tower does not go black away from the sun.
uniform float wall_metal_scale = 0.5;
uniform sampler2D roof_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D roof_nr : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 roof_tile = vec2(2.0, 1.0);
// Roofs are tar and gravel-dulled concrete, darker than the bare set.
uniform float roof_shade = 0.7;

uniform vec3 glass_color : source_color = vec3(0.14, 0.18, 0.24);
uniform vec3 lit_color : source_color = vec3(1.0, 0.78, 0.45);
uniform float lit_strength = 1.6;
uniform vec2 window_cell = vec2(3.0, 3.5);
uniform vec2 window_size = vec2(1.8, 2.1);
// No windows below this height: the ground floor reads as a solid base.
uniform float ground_floor = 4.0;
// How much the per-building COLOR tint shows through the texture.
uniform float tint_amount = 0.35;
uniform vec3 grime_color : source_color = vec3(0.24, 0.22, 0.2);
uniform vec3 dust_color : source_color = vec3(0.62, 0.52, 0.4);
// 0 dry to 1 soaked, set by Rain (Story 13.2): surfaces darken and turn glossy.
global uniform float wetness;
// 0 bare to 1 white, set by Snow (Story 13.3): roofs whiten.
global uniform float snow_cover;

varying vec3 world_pos;
varying vec3 world_normal;
// Flat: interpolation noise would flicker the lit-window hash.
varying flat vec3 tint;
varying flat vec3 custom;
// Building height and footprint centre, from the instance transform.
varying flat float height;
varying flat vec2 centre;
varying flat vec2 half_size;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tint = COLOR.rgb;
	custom = INSTANCE_CUSTOM.xyz;
	height = length(MODEL_MATRIX[1].xyz);
	centre = MODEL_MATRIX[3].xz;
	half_size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz)) * 0.5;
	// Tangent frame matching the world-space UVs in fragment(): walls run along
	// z or x with image-up as world up; roofs run along x with image-up as -z.
	// Towers are unrotated, so model axes are world axes.
	if (abs(NORMAL.y) > 0.5) {
		TANGENT = vec3(1.0, 0.0, 0.0);
		BINORMAL = vec3(0.0, 0.0, -1.0);
	} else if (abs(NORMAL.x) > 0.5) {
		TANGENT = vec3(0.0, 0.0, 1.0);
		BINORMAL = vec3(0.0, 1.0, 0.0);
	} else {
		TANGENT = vec3(1.0, 0.0, 0.0);
		BINORMAL = vec3(0.0, 1.0, 0.0);
	}
}

// A hash without sin, so it stays stable at large inputs.
float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// One of the four wall sets. The branch is per building (flat), and gradients
// come from outside it so mipmaps stay right.
void wall_sample(int set, vec2 p, vec2 dx, vec2 dy, out vec3 albedo, out vec3 nr) {
	if (set == 0) {
		albedo = textureGrad(wall_albedo_0, p, dx, dy).rgb;
		nr = textureGrad(wall_nr_0, p, dx, dy).rgb;
	} else if (set == 1) {
		albedo = textureGrad(wall_albedo_1, p, dx, dy).rgb;
		nr = textureGrad(wall_nr_1, p, dx, dy).rgb;
	} else if (set == 2) {
		albedo = textureGrad(wall_albedo_2, p, dx, dy).rgb;
		nr = textureGrad(wall_nr_2, p, dx, dy).rgb;
	} else {
		albedo = textureGrad(wall_albedo_3, p, dx, dy).rgb;
		nr = textureGrad(wall_nr_3, p, dx, dy).rgb;
	}
}

void fragment() {
	float seed = custom.x * 97.0;
	vec3 albedo;
	float rough;
	float metal = 0.0;
	if (world_normal.y > 0.5) {
		vec2 p = world_pos.xz / roof_tile;
		vec4 nr = texture(roof_nr, p);
		albedo = texture(roof_albedo, p).rgb * mix(vec3(1.0), tint, 0.3) * roof_shade;
		rough = nr.b;
		NORMAL_MAP = vec3(nr.rg, 1.0);
		// Stains: broad damp patches where water pooled, darker toward the
		// parapet where dirt collects.
		float blot = smoothstep(0.45, 0.8, value_noise(world_pos.xz * 0.12 + seed)
			* 0.7 + value_noise(world_pos.xz * 0.5 - seed) * 0.3);
		vec2 to_edge = half_size - abs(world_pos.xz - centre);
		float edge = 1.0 - smoothstep(0.0, 1.5, min(to_edge.x, to_edge.y));
		albedo *= 1.0 - 0.3 * blot - 0.25 * edge;
		rough = mix(rough, 0.7, blot * 0.5);
	} else {
		// Run along the wall: z on east and west faces, x on north and south.
		bool x_face = abs(world_normal.x) > 0.5;
		float along = x_face ? world_pos.z : world_pos.x;
		vec2 uv = vec2(along, world_pos.y - ground_floor);
		vec2 cell = floor(uv / window_cell);
		vec2 inside = abs(fract(uv / window_cell) * window_cell - window_cell * 0.5);
		bool window = uv.y > 0.0 && inside.x < window_size.x * 0.5 && inside.y < window_size.y * 0.5;
		int set = int(custom.z + 0.5);
		vec2 tile = wall_tile[set];
		vec2 p = vec2(along, -world_pos.y) / tile;
		vec3 tex;
		vec3 nr;
		wall_sample(set, p, dFdx(p), dFdy(p), tex, nr);
		if (window) {
			float face = x_face ? sign(world_normal.x) : 2.0 + sign(world_normal.z);
			bool lit = hash(cell + vec2(seed, face * 13.0)) < custom.y;
			albedo = lit ? lit_color : glass_color;
			EMISSION = lit ? lit_color * lit_strength : vec3(0.0);
			rough = 0.15;
			metal = 0.4;
		} else {
			// Broad blotches so a set's repeat does not read as a grid.
			float macro = value_noise(vec2(along, world_pos.y) * 0.18 + seed);
			albedo = tex * mix(vec3(1.0), tint, tint_amount) * mix(0.82, 1.08, macro);
			rough = nr.b;
			metal = wall_metallic[set] * wall_metal_scale;
			NORMAL_MAP = vec3(nr.rg, 1.0);
			// Grime: rain runs dirt down from each sill and from the roof edge
			// in thin streaks that fade as they fall.
			float streak = value_noise(vec2(along * 3.0 + seed, world_pos.y * 0.08));
			// Metres below the sill of the window above, in that window's column.
			float below = mod((window_cell.y - window_size.y) * 0.5 - (uv.y - cell.y * window_cell.y), window_cell.y);
			bool under_window = inside.x < window_size.x * 0.5 && uv.y + below > 0.0;
			float drip = under_window ? 1.0 - smoothstep(0.0, 2.5, below) : 0.0;
			float roof_run = 1.0 - smoothstep(0.0, 6.0 + 6.0 * streak, height - world_pos.y);
			float grime = clamp((drip * 0.6 + roof_run) * smoothstep(0.35, 0.75, streak), 0.0, 1.0);
			albedo = mix(albedo, albedo * grime_color * 2.0, grime * 0.55);
			// Dust splashed up from the street, and the contact shadow where
			// the wall meets the ground.
			float dust = (1.0 - smoothstep(0.0, 1.6 + streak, world_pos.y)) * 0.6;
			albedo = mix(albedo, dust_color * dot(albedo, vec3(0.33)) * 1.6, dust);
			rough = mix(rough, 0.95, dust);
			AO = mix(0.45, 1.0, smoothstep(0.0, 2.5, world_pos.y));
			AO_LIGHT_AFFECT = 0.5;
			albedo *= mix(0.65, 1.0, smoothstep(0.0, 1.2, world_pos.y));
		}
	}
	// Weather, the same on every surface: wet darkens and glosses, snow whitens
	// what faces up.
	albedo *= 1.0 - 0.4 * wetness * (1.0 - metal * 0.5);
	rough = mix(rough, 0.12, wetness * 0.85);
	float up = smoothstep(0.5, 0.9, world_normal.y);
	albedo = mix(albedo, vec3(0.92, 0.94, 0.97), snow_cover * up);
	rough = mix(rough, 0.8, snow_cover * up);
	metal *= 1.0 - snow_cover * up;
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
}
