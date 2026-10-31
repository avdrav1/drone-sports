shader_type spatial;
// Story 26.10: chain-link fence panels. A diamond wire mesh drawn by discarding
// the space between the wires, laid out in world space along the panel (its
// local x) and up, so a panel cut round a hole keeps the pattern in step with
// its neighbours. Far off, where a wire is thinner than a pixel, the mesh fades
// to its average cover through a screen-space dither. Plain GLSL ES 3.0
// features only (discard, fwidth, FRAGCOORD), so it runs under GL Compatibility.
render_mode cull_disabled;

uniform vec4 wire_color : source_color = vec4(0.6, 0.62, 0.63, 1.0);
// Diamond size and wire thickness, metres.
uniform float cell = 0.07;
uniform float wire = 0.006;
uniform float wire_metallic : hint_range(0.0, 1.0) = 0.7;
uniform float wire_roughness : hint_range(0.0, 1.0) = 0.45;

varying vec2 link;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 along = normalize(MODEL_MATRIX[0].xyz);
	link = vec2(dot(wp.xz, along.xz), wp.y);
}

void fragment() {
	// Diagonal coordinates, one unit a diamond.
	vec2 q = vec2(link.x + link.y, link.x - link.y) / cell;
	vec2 f = abs(fract(q) - 0.5);
	float dist = (0.5 - max(f.x, f.y)) * cell;
	float aa = max(fwidth(q.x), fwidth(q.y)) * cell;
	float cover = 1.0 - smoothstep(wire * 0.5, wire * 0.5 + aa, dist);
	// Average cover of the wire mesh, for where it is finer than a pixel.
	float t = wire / cell;
	float density = 1.0 - (1.0 - t) * (1.0 - t);
	cover = mix(cover, density, clamp(aa / cell * 2.0 - 0.5, 0.0, 1.0));
	float noise = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (cover < noise) {
		discard;
	}
	ALBEDO = wire_color.rgb;
	METALLIC = wire_metallic;
	ROUGHNESS = wire_roughness;
}
