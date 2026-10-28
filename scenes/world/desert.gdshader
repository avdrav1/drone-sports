shader_type spatial;
// Sand that turns to rock on steep, high ground, with wind ripples that fade with distance.

uniform vec3 sand_color : source_color = vec3(0.9, 0.62, 0.38);
uniform vec3 sand_dark : source_color = vec3(0.78, 0.5, 0.3);
uniform vec3 rock_color : source_color = vec3(0.45, 0.24, 0.15);
uniform vec3 rock_dark : source_color = vec3(0.25, 0.13, 0.09);
uniform sampler2D detail_noise : repeat_enable, filter_linear_mipmap;
uniform float ripple_frequency = 1.4;
uniform float ripple_strength = 0.25;
uniform float ripple_fade = 60.0;
// 0 dry to 1 soaked, set by Rain (Story 13.2): wet sand darkens, flat ground glistens.
global uniform float wetness;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float broad = texture(detail_noise, world_pos.xz * 0.0005).r;
	float mid = texture(detail_noise, world_pos.xz * 0.006).r;
	float slope = 1.0 - world_normal.y;
	float rockiness = smoothstep(0.12, 0.3, slope + (mid - 0.5) * 0.2) * smoothstep(6.0, 20.0, world_pos.y);
	vec3 sand = mix(sand_dark, sand_color, smoothstep(0.3, 0.7, broad * 0.85 + mid * 0.15));
	vec3 rock = mix(rock_dark, rock_color, mid);
	ALBEDO = mix(sand, rock, rockiness);
	float flat_wet = wetness * smoothstep(0.6, 0.9, world_normal.y);
	ALBEDO *= 1.0 - 0.4 * wetness;
	ROUGHNESS = mix(mix(0.92, 0.8, rockiness), 0.25, flat_wet);
	// Wind ripples on sand: a bent sine across the ground, gone by ripple_fade metres away.
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float phase = dot(world_pos.xz, vec2(0.8, 0.6)) * ripple_frequency + mid * 9.0;
	float amount = ripple_strength * (1.0 - smoothstep(ripple_fade * 0.5, ripple_fade, dist)) * (1.0 - rockiness);
	vec3 bent = normalize(world_normal + vec3(0.8, 0.0, 0.6) * cos(phase) * amount);
	NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
}
