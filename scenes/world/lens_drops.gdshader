shader_type canvas_item;
// Raindrops on the FPV lens (Story 13.2). A grid of cells, each holding one
// drop that beads up, sits, and runs off on its own cycle; a drop bends the
// picture behind it like a small lens. `amount` 0..1 is the share of cells wet.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform float cell_size = 90.0;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(px / cell_size);
	float seed = hash(cell);
	float life = fract(TIME * (0.08 + 0.12 * seed) + seed * 7.0);
	vec2 centre = (cell + 0.2 + 0.6 * vec2(hash(cell + 3.1), hash(cell + 7.7))) * cell_size;
	// Late in its life a drop slides down the lens.
	centre.y += smoothstep(0.7, 1.0, life) * cell_size * 0.6;
	float radius = cell_size * (0.08 + 0.14 * hash(cell + 11.3)) * smoothstep(0.0, 0.15, life);
	vec2 d = (px - centre) / max(radius, 0.001);
	float r = length(d);
	float on = step(seed, amount) * (1.0 - smoothstep(0.85, 1.0, r)) * (1.0 - smoothstep(0.9, 1.0, life));
	vec2 bent = SCREEN_UV - d * radius * SCREEN_PIXEL_SIZE * 0.6;
	vec3 seen = textureLod(screen, bent, 1.5).rgb;
	// A darker rim and a bright fleck read as water.
	seen *= 1.0 - 0.35 * smoothstep(0.6, 1.0, r);
	seen += 0.25 * (1.0 - smoothstep(0.0, 0.25, length(d - vec2(-0.35, -0.35))));
	COLOR = vec4(seen, on * 0.9);
}
