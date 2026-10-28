shader_type spatial;
// Box towers. Windows are laid out in world space so the grid stays square on
// any building. Walls take one of four library surfaces (Story 15.4) and roofs a
// fifth, all mapped in world space at each set's tile size so nothing stretches,
// then weathered: grime streaks under windows and the roof edge, dust and contact
// shadow at the base, stains on the roof. Windows (Story 15.5) are whole cells
// centred on each face; each pane reflects a sky gradient by Fresnel and shows a
// fake room behind it (interior mapping), with blinds and lamps per window. Per
// instance: COLOR tints the walls, INSTANCE_CUSTOM.x seeds the weathering, .y is
// how many windows are lit, .z is the wall surface (0 to 3) and .w seeds the
// windows. City mirrors the window choice in GDScript (window_at); keep the two
// in step. Only features GL Compatibility has.

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
uniform vec3 frame_color : source_color = vec3(0.1, 0.1, 0.11);
uniform float frame_width = 0.08;
uniform float lit_strength = 1.6;
// Lit windows glow brighter as rain darkens the day.
uniform float gloom_glow = 1.2;
// Unlit rooms: daylight that reaches the back of the room.
uniform float room_daylight = 0.18;
uniform float room_depth = 4.5;
// What the panes reflect: the golden-hour sky gradient and the street below.
uniform vec3 sky_zenith : source_color = vec3(0.24, 0.26, 0.45);
uniform vec3 sky_horizon : source_color = vec3(1.0, 0.6, 0.34);
uniform vec3 ground_reflect : source_color = vec3(0.16, 0.12, 0.1);
uniform float reflect_strength = 1.5;
uniform vec3 blind_color : source_color = vec3(0.78, 0.74, 0.66);
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
varying flat vec4 custom;
// Building height and footprint centre, from the instance transform.
varying flat float height;
varying flat vec2 centre;
varying flat vec2 half_size;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tint = COLOR.rgb;
	custom = INSTANCE_CUSTOM;
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

// Room atlas: four rooms, each a wall, floor, and furniture colour (linear).
const vec3 ROOM_WALL[4] = { vec3(0.62, 0.58, 0.5), vec3(0.42, 0.46, 0.5), vec3(0.66, 0.6, 0.52), vec3(0.5, 0.4, 0.32) };
const vec3 ROOM_FLOOR[4] = { vec3(0.3, 0.2, 0.12), vec3(0.22, 0.22, 0.24), vec3(0.36, 0.26, 0.16), vec3(0.18, 0.14, 0.12) };
const vec3 ROOM_STUFF[4] = { vec3(0.14, 0.12, 0.1), vec3(0.08, 0.09, 0.11), vec3(0.3, 0.16, 0.1), vec3(0.2, 0.2, 0.18) };
// Lamp tones: warm home, neutral, office white.
const vec3 LAMP[3] = { vec3(1.0, 0.7, 0.4), vec3(1.0, 0.82, 0.6), vec3(0.86, 0.92, 1.0) };
// How far each blind is drawn, from the top of the pane; most are open.
const float BLIND[8] = { 0.0, 0.0, 0.0, 0.0, 0.0, 0.15, 0.4, 0.85 };

// Integer hash (lowbias32), mirrored by City._hash32.
uint hash32(uint x) {
	x ^= x >> 16u;
	x *= 2146121005u;
	x ^= x >> 15u;
	x *= 2221713035u;
	x ^= x >> 16u;
	return x;
}

// Where window `i` of `n` falls in a shuffle of 0..n-1 keyed by `key`: a bijection
// on the next power of two, walked until it lands below n. The first `lit`
// ranks are lit, so exactly that many windows are. Mirrored by City._rank.
uint window_rank(uint i, uint n, uint key) {
	uint m = 1u;
	while ((1u << m) < n) {
		m++;
	}
	uint mask = (1u << m) - 1u;
	uint s = max(m / 2u, 1u);
	uint k = hash32(key);
	uint x = i;
	for (int t = 0; t < 64; t++) {
		x = (x ^ k) & mask;
		x = (x * 739982445u) & mask;
		x ^= x >> s;
		x = (x * 695872825u + (k >> 16u)) & mask;
		x ^= x >> s;
		if (x < n) {
			break;
		}
	}
	return x;
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
		// Whole window cells centred on the face, from the ground floor up to
		// the last full storey, so no window is cut at a corner or the roof.
		// City.window_grid counts them the same way.
		int cols_x = int(floor(2.0 * half_size.y / window_cell.x + 0.001));
		int cols_z = int(floor(2.0 * half_size.x / window_cell.x + 0.001));
		int rows = max(int(floor((height - ground_floor) / window_cell.y + 0.001)), 0);
		int cols = x_face ? cols_x : cols_z;
		float face_mid = x_face ? centre.y : centre.x;
		vec2 uv = vec2(along - face_mid + float(cols) * window_cell.x * 0.5, world_pos.y - ground_floor);
		vec2 cell = floor(uv / window_cell);
		vec2 in_cell = uv - cell * window_cell;
		vec2 inside = abs(in_cell - window_cell * 0.5);
		bool in_col = cell.x >= 0.0 && cell.x < float(cols);
		bool window = in_col && cell.y >= 0.0 && cell.y < float(rows)
			&& inside.x < window_size.x * 0.5 && inside.y < window_size.y * 0.5;
		int set = int(custom.z + 0.5);
		vec2 tile = wall_tile[set];
		vec2 p = vec2(along, -world_pos.y) / tile;
		vec3 tex;
		vec3 nr;
		wall_sample(set, p, dFdx(p), dFdy(p), tex, nr);
		if (window) {
			// Window index: faces +x, -x, +z, -z in turn, row by row.
			int face = x_face ? (world_normal.x > 0.0 ? 0 : 1) : (world_normal.z > 0.0 ? 2 : 3);
			int first = face == 0 ? 0 : face == 1 ? rows * cols_x : face == 2 ? 2 * rows * cols_x : 2 * rows * cols_x + rows * cols_z;
			uint index = uint(first + int(cell.y) * cols + int(cell.x));
			uint key = uint(custom.w + 0.5);
			bool lit = window_rank(index, uint(2 * rows * (cols_x + cols_z)), key) < uint(custom.y + 0.5);
			uint pick = hash32(index ^ (key << 16u));
			float blind = BLIND[pick & 7u];
			int room = int((pick >> 3u) & 3u);
			vec3 lamp = LAMP[(pick >> 5u) % 3u] * lit_strength * (1.0 + gloom_glow * wetness)
				* (0.75 + 0.25 * float((pick >> 8u) & 3u) / 3.0);
			vec2 half_win = window_size * 0.5;
			vec2 win = in_cell - (window_cell - window_size) * 0.5;
			if (inside.x > half_win.x - frame_width || inside.y > half_win.y - frame_width) {
				// Frame: dark powder-coated aluminium.
				albedo = frame_color;
				rough = 0.45;
				metal = 0.5;
			} else if (win.y > window_size.y * (1.0 - blind)) {
				// Blind, just behind the glass: daylit slats, backlit when the
				// room is.
				float slat = 0.9 + 0.1 * step(0.5, fract(win.y * 12.0));
				albedo = blind_color * slat * 0.7;
				EMISSION = lit ? blind_color * lamp * 0.35 * slat : vec3(0.0);
				rough = 0.6;
			} else {
				// Interior mapping: walk the view ray from the pane into a room
				// the size of the cell and room_depth deep, and shade the plane
				// it reaches. Axes: along the wall, up, into the building.
				vec3 inward = x_face ? vec3(-sign(world_normal.x), 0.0, 0.0) : vec3(0.0, 0.0, -sign(world_normal.z));
				vec3 right = x_face ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
				vec3 d = normalize(world_pos - CAMERA_POSITION_WORLD);
				vec3 ld = vec3(dot(d, right), d.y, dot(d, inward));
				ld = sign(ld + 1e-6) * max(abs(ld), vec3(1e-4));
				vec3 box = vec3(window_cell, room_depth);
				vec3 o = vec3(in_cell, 0.0);
				vec3 tv = (step(0.0, ld) * box - o) / ld;
				float t = min(min(tv.x, tv.y), tv.z);
				vec3 hit = o + ld * t;
				vec3 room_col;
				float light = 1.0;
				if (t == tv.y && ld.y > 0.0) {
					// Ceiling, with the lamp's panel in the middle.
					vec2 c = abs(vec2(hit.x - window_cell.x * 0.5, hit.z - room_depth * 0.45));
					room_col = vec3(0.8);
					light = lit && c.x < 0.4 && c.y < 0.6 ? 3.0 : 0.7;
				} else if (t == tv.y) {
					room_col = ROOM_FLOOR[room];
				} else if (t == tv.x) {
					room_col = ROOM_WALL[room] * 0.8;
				} else {
					room_col = ROOM_WALL[room];
					// Furniture against the back wall: a low unit and a shelf
					// or picture, placed per room.
					float fx = float((pick >> 10u) & 3u) * 0.5 + 0.2;
					bool low = hit.y < 0.9 && hit.x > fx && hit.x < fx + 1.4;
					bool high = hit.y > 1.5 && hit.y < 2.1 && abs(hit.x - window_cell.x + fx + 0.3) < 0.4;
					room_col = low || high ? ROOM_STUFF[room] : room_col;
				}
				// Darker toward the back, away from the window or the lamp.
				light *= mix(1.0, 0.5, hit.z / room_depth);
				vec3 interior = room_col * light * (lit ? lamp : vec3(room_daylight));
				// Reflection: the sky gradient (or the street below) by
				// Schlick's Fresnel, each pane tilted a hair so they differ.
				vec3 n = normalize(-inward + right * (float((pick >> 12u) & 15u) / 15.0 - 0.5) * 0.04);
				vec3 r = reflect(d, n);
				vec3 sky = r.y > 0.0 ? mix(sky_horizon, sky_zenith, pow(r.y, 0.5)) : ground_reflect;
				// Rain greys the sky it reflects.
				sky = mix(sky, vec3(dot(sky, vec3(0.3, 0.5, 0.2))) * 0.7, wetness * 0.7);
				float f = 0.1 + 0.9 * pow(1.0 - clamp(dot(-d, n), 0.0, 1.0), 5.0);
				albedo = glass_color * 0.1;
				EMISSION = interior * (1.0 - f) + sky * f * reflect_strength;
				rough = 0.08;
				SPECULAR = 0.0;
			}
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
			bool under_window = in_col && inside.x < window_size.x * 0.5 && uv.y + below > 0.0
				&& uv.y + below < float(rows) * window_cell.y;
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
