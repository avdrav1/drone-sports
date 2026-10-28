shader_type spatial;
// The street level: road, pavements, and kerbs, picked by `layer`, each a
// library surface (Story 15.2) mapped in world space at its tile size. The road
// adds lane markings and its decals (Story 15.7). Road UV: x across the street
// from its centre line and y along it, in metres. UV2: x the street's width, y
// its kind (0 street, 1 avenue, 2 crossing, 3 pavement). Crossings are bare
// asphalt. Segment chunks carry, as written by Streets._markings:
//   CUSTOM0 the segment's along range, crosswalk ends (1 start, 2 end, 3 both),
//           and the across sign of the lane heading +along;
//   CUSTOM1 a manhole: along, across, radius, present;
//   CUSTOM2 a patch: along, across, half length, half width (0 for none);
//   CUSTOM3 an arrow's along and direction (0 for none), a drain's along and
//           kerb side (0 for none).
// Wet darkens and glosses, snow whitens, on every layer. Only features GL
// Compatibility has.

// 0 road, 1 pavement, 2 kerb.
uniform int layer = 0;
uniform sampler2D surface_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D surface_nr : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 tile = vec2(2.0, 2.0);
// Each layer's shade over its set's colour.
uniform vec3 asphalt_shade : source_color = vec3(0.68, 0.65, 0.62);
uniform vec3 paving_shade : source_color = vec3(0.95, 0.9, 0.84);
uniform vec3 kerb_shade : source_color = vec3(1.0, 0.97, 0.92);
// Patched asphalt is newer and darker than the road round it.
uniform float patch_shade = 0.82;
uniform vec3 paint : source_color = vec3(0.92, 0.9, 0.84);
uniform vec3 centre_paint : source_color = vec3(0.95, 0.75, 0.25);
uniform vec3 iron : source_color = vec3(0.32, 0.3, 0.27);
uniform float dash = 6.0;
// Seeds the cracks; Streets sets it from the layout's seed.
uniform float crack_seed = 0.0;
// 0 dry to 1 soaked, set by Rain (Story 13.2).
global uniform float wetness;
// 0 bare to 1 white, set by Snow (Story 13.3); streets are flat, so all of them.
global uniform float snow_cover;

// Crosswalk and stop line, from Streets.CROSSWALK_GAP and CROSSWALK_DEPTH.
const float CW_GAP = 0.5;
const float CW_DEPTH = 3.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying flat vec4 seg;
varying flat vec4 manhole;
varying flat vec4 patch;
varying flat vec4 marks;
// Kerbs: true when the instance runs along x.
varying flat float along_x;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	seg = CUSTOM0;
	manhole = CUSTOM1;
	patch = CUSTOM2;
	marks = CUSTOM3;
	along_x = length(MODEL_MATRIX[0].xyz) > length(MODEL_MATRIX[2].xyz) ? 1.0 : 0.0;
	// Tangent frame matching the world-space UVs in fragment(), as city.gdshader.
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

// Thin wandering lines where a noise field crosses its middle, kept to sparse
// clusters by a second, broader noise.
float cracks(vec2 p) {
	float n = value_noise(p * 0.9 + crack_seed) * 0.7 + value_noise(p * 2.7 - crack_seed) * 0.3;
	float line = 1.0 - smoothstep(0.0, 0.018, abs(n - 0.5));
	return line * smoothstep(0.62, 0.78, value_noise(p * 0.11 + crack_seed * 1.7));
}

void fragment() {
	vec2 p;
	if (world_normal.y > 0.5) {
		p = world_pos.xz;
	} else if (abs(world_normal.x) > 0.5) {
		p = vec2(world_pos.z, -world_pos.y);
	} else {
		p = vec2(world_pos.x, -world_pos.y);
	}
	p /= tile;
	vec3 albedo = texture(surface_albedo, p).rgb;
	vec4 nr = texture(surface_nr, p);
	float rough = nr.b;
	float metal = 0.0;
	NORMAL_MAP = vec3(nr.rg, 1.0);
	// Broad blotches so a repeat does not read as a grid.
	float macro = value_noise(world_pos.xz * 0.15 + crack_seed);
	// Low spots that hold water when it rains.
	float hollow = smoothstep(0.55, 0.75, value_noise(world_pos.xz * 0.35 - crack_seed));
	if (layer == 1) {
		albedo *= paving_shade * mix(0.85, 1.05, macro);
		hollow *= 0.5;
	} else if (layer == 2) {
		albedo *= kerb_shade;
		// A joint between kerb stones every metre, and the top's worn arris.
		float along = along_x > 0.5 ? world_pos.x : world_pos.z;
		albedo *= mix(0.55, 1.0, smoothstep(0.0, 0.015, abs(fract(along) - 0.5) - 0.48));
		hollow = 0.0;
	} else {
		float across = abs(UV.x);
		float half_width = UV2.x * 0.5;
		float along = UV.y;
		albedo *= asphalt_shade * mix(0.82, 1.1, macro);
		if (UV2.y < 1.5) {
			// The gutter: grime washed to the kerb.
			float gutter = smoothstep(half_width - 0.6, half_width - 0.1, across);
			albedo *= 1.0 - 0.35 * gutter;
			hollow = max(hollow, gutter * 0.8);
			// A patch: newer, darker asphalt with a sealed seam round it.
			vec2 lp = abs(vec2(along - patch.x, UV.x - patch.y)) - patch.zw;
			if (patch.z > 0.0 && max(lp.x, lp.y) < 0.0) {
				float seam = smoothstep(-0.1, -0.04, max(lp.x, lp.y));
				albedo *= mix(patch_shade, 0.5, seam);
				hollow *= 0.3;
			}
		}
		albedo *= 1.0 - 0.6 * cracks(world_pos.xz);
		if (UV2.y < 1.5) {
			float lines = 0.0;
			vec3 line_color = paint;
			if (across > half_width - 0.5 && across < half_width - 0.35) {
				lines = 1.0;
			}
			if (UV2.y < 0.5) {
				if (across < 0.08 && fract(along / dash) < 0.5) {
					lines = 1.0;
				}
			} else if (across > 0.1 && across < 0.25) {
				lines = 1.0;
				line_color = centre_paint;
			}
			// Crosswalks at each end that meets a crossing, and a stop line
			// across the lane approaching it.
			float flags = seg.z;
			for (int e = 0; e < 2; e++) {
				bool on = e == 0 ? mod(flags, 2.0) > 0.5 : flags > 1.5;
				if (!on) {
					continue;
				}
				float d = e == 0 ? along - seg.x : seg.y - along;
				float depth = min(CW_DEPTH, (seg.y - seg.x) * 0.5 - CW_GAP);
				// The lane approaching this end is on the side heading toward it.
				float approach = UV.x * seg.w * (e == 0 ? -1.0 : 1.0);
				// Lane lines stop short of the crosswalk.
				if (d < CW_GAP + depth + 0.3) {
					lines = 0.0;
				}
				if (d > CW_GAP && d < CW_GAP + depth && across < half_width - 0.5
						&& fract((UV.x + half_width) / 1.0) < 0.5) {
					lines = 1.0;
					line_color = paint;
				}
				if (d > CW_GAP + depth + 0.5 && d < CW_GAP + depth + 0.8 && approach > 0.1 && across < half_width - 0.5) {
					lines = 1.0;
					line_color = paint;
				}
			}
			// A straight-on arrow in the lane, pointing at the crossing.
			if (marks.g != 0.0) {
				float f = (along - marks.x) * marks.g;
				float s = abs(UV.x - seg.w * marks.g * UV2.x * 0.25);
				if ((s < 0.12 && f > -2.0 && f < 0.6) || (f >= 0.6 && f < 2.0 && s < (2.0 - f) * 0.4)) {
					lines = 1.0;
					line_color = paint;
				}
			}
			// Paint wears in patches and where tyres run.
			lines *= mix(0.55, 1.0, smoothstep(0.3, 0.6, value_noise(world_pos.xz * 1.3 + 7.0)));
			albedo = mix(albedo, line_color * mix(0.85, 1.0, macro), lines);
			rough = mix(rough, 0.6, lines);
			// A manhole: a cast-iron disc with a raised grid, in a dark ring.
			if (manhole.w > 0.5) {
				float r = length(vec2(along - manhole.x, UV.x - manhole.y));
				if (r < manhole.z + 0.06) {
					vec2 g = vec2(along, UV.x) * 12.0;
					float grid = step(0.5, fract(g.x)) * step(0.5, fract(g.y));
					albedo = r > manhole.z ? albedo * 0.45 : iron * mix(0.75, 1.25, grid);
					rough = 0.45;
					metal = r > manhole.z ? 0.0 : 0.2;
					hollow = 0.0;
				}
			}
			// A drain: a grate of slots against the kerb.
			if (marks.a != 0.0) {
				vec2 q = abs(vec2(along - marks.z, UV.x - marks.a * (half_width - 0.275)));
				if (q.x < 0.45 && q.y < 0.225) {
					bool slot = q.x < 0.39 && q.y < 0.17 && fract(along * 9.0) < 0.5;
					albedo = slot ? vec3(0.02) : iron;
					rough = 0.5;
					metal = slot ? 0.0 : 0.2;
				}
			}
		}
	}
	// Weather, the same on every layer: wet darkens and glosses, more in the
	// hollows where puddles stand; snow whitens.
	float pool = wetness * hollow;
	albedo *= 1.0 - 0.5 * wetness - 0.2 * pool;
	rough = mix(rough, 0.12, wetness * 0.85);
	rough = mix(rough, 0.03, pool);
	NORMAL_MAP = mix(NORMAL_MAP, vec3(0.5, 0.5, 1.0), pool);
	SPECULAR = mix(0.5, 0.8, wetness);
	float up = smoothstep(0.5, 0.9, world_normal.y);
	albedo = mix(albedo, vec3(0.92, 0.94, 0.97), snow_cover * up);
	rough = mix(rough, 0.8, snow_cover * up);
	metal *= 1.0 - snow_cover * up;
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
}
