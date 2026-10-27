shader_type sky;
// Sunset gradient, sun disk with glare, and a noise cloud layer lit from the sun side.
// Plain math and one texture so it runs on GL Compatibility too.

uniform vec3 zenith_color : source_color = vec3(0.16, 0.14, 0.3);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.55, 0.28);
uniform vec3 ground_color : source_color = vec3(0.35, 0.2, 0.12);
uniform float horizon_sharpness = 3.0;
uniform float sun_disk_size = 0.9995;
uniform float sun_glare = 6.0;
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;
uniform float cloud_scale = 0.18;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.55;
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.62, 0.38);
uniform vec3 cloud_shadow : source_color = vec3(0.3, 0.2, 0.32);
uniform float cloud_drift = 0.004;

void sky() {
	vec3 dir = EYEDIR;
	float up = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, zenith_color, pow(up, 1.0 / horizon_sharpness));
	if (dir.y < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-dir.y * 6.0, 0.0, 1.0));
	}
	vec3 sun_dir = LIGHT0_DIRECTION;
	float sun_dot = max(dot(dir, sun_dir), 0.0);
	vec3 sun_col = LIGHT0_COLOR * LIGHT0_ENERGY;
	// Warm glow around the sun, widest near the horizon.
	col += sun_col * (pow(sun_dot, 12.0) * 0.18 + pow(sun_dot, 180.0) * 0.45);
	if (dir.y > 0.02) {
		vec2 uv = dir.xz / (dir.y + 0.08) * cloud_scale + vec2(TIME * cloud_drift, 0.0);
		float n = texture(cloud_noise, uv).r * 0.65 + texture(cloud_noise, uv * 2.7 + 0.3).r * 0.35;
		float density = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.25, n);
		// Fade clouds out toward the horizon so they melt into the haze.
		density *= smoothstep(0.02, 0.18, dir.y);
		// Thick cores stay in shadow; thin edges and the sun side catch the light.
		float facing = pow(sun_dot, 3.0);
		float lit = clamp(facing * 0.9 + (1.0 - density) * 0.6, 0.0, 1.0);
		vec3 cloud = mix(cloud_shadow, cloud_lit * (0.7 + sun_col * 0.3), lit * lit);
		col = mix(col, cloud, density * 0.92);
	}
	if (AT_CUBEMAP_PASS == false) {
		col += sun_col * smoothstep(sun_disk_size, sun_disk_size + 0.0003, sun_dot) * sun_glare;
	}
	COLOR = col;
}
