shader_type spatial;
// Box towers. Windows are laid out in world space so the grid stays square on
// any building; roofs are plain concrete. Per instance: COLOR tints the walls,
// INSTANCE_CUSTOM.x seeds which windows are lit and .y is the fraction lit.
// Only features GL Compatibility has.

uniform vec3 wall_color : source_color = vec3(0.86, 0.74, 0.6);
uniform vec3 roof_color : source_color = vec3(0.52, 0.49, 0.46);
uniform vec3 glass_color : source_color = vec3(0.14, 0.18, 0.24);
uniform vec3 lit_color : source_color = vec3(1.0, 0.78, 0.45);
uniform float lit_strength = 1.6;
uniform vec2 window_cell = vec2(3.0, 3.5);
uniform vec2 window_size = vec2(1.8, 2.1);
// No windows below this height: the ground floor reads as a solid base.
uniform float ground_floor = 4.0;

varying vec3 world_pos;
varying vec3 world_normal;
// Flat: interpolation noise would flicker the lit-window hash.
varying flat vec3 tint;
varying flat vec2 custom;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tint = COLOR.rgb;
	custom = INSTANCE_CUSTOM.xy;
}

// A hash without sin, so it stays stable at large inputs.
float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	if (world_normal.y > 0.5) {
		ALBEDO = roof_color * mix(vec3(1.0), tint, 0.3);
		ROUGHNESS = 0.92;
	} else {
		// Run along the wall: z on east and west faces, x on north and south.
		bool x_face = abs(world_normal.x) > 0.5;
		vec2 uv = vec2(x_face ? world_pos.z : world_pos.x, world_pos.y - ground_floor);
		vec2 cell = floor(uv / window_cell);
		vec2 inside = abs(fract(uv / window_cell) * window_cell - window_cell * 0.5);
		bool window = uv.y > 0.0 && inside.x < window_size.x * 0.5 && inside.y < window_size.y * 0.5;
		vec3 wall = wall_color * tint;
		if (window) {
			float face = x_face ? sign(world_normal.x) : 2.0 + sign(world_normal.z);
			bool lit = hash(cell + vec2(custom.x * 97.0, face * 13.0)) < custom.y;
			ALBEDO = lit ? lit_color : glass_color;
			EMISSION = lit ? lit_color * lit_strength : vec3(0.0);
			ROUGHNESS = 0.15;
			METALLIC = 0.4;
		} else {
			ALBEDO = wall;
			ROUGHNESS = 0.85;
		}
	}
}
