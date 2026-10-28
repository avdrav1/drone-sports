shader_type spatial;
// Asphalt with lane markings. UV: x across the street from its centre line and
// y along it, in metres. UV2: x the street's width, y its kind (0 street,
// 1 avenue, 2 crossing). Crossings are bare asphalt.

uniform vec3 asphalt : source_color = vec3(0.25, 0.23, 0.23);
uniform vec3 paint : source_color = vec3(0.92, 0.9, 0.84);
uniform vec3 centre_paint : source_color = vec3(0.95, 0.75, 0.25);
uniform float dash = 6.0;
// 0 dry to 1 soaked, set by Rain (Story 13.2).
global uniform float wetness;

void fragment() {
	float across = abs(UV.x);
	float half_width = UV2.x * 0.5;
	vec3 c = asphalt;
	if (UV2.y < 1.5) {
		if (across > half_width - 0.5 && across < half_width - 0.35) {
			c = paint;
		}
		if (UV2.y < 0.5) {
			if (across < 0.08 && fract(UV.y / dash) < 0.5) {
				c = paint;
			}
		} else if (across > 0.1 && across < 0.25) {
			c = centre_paint;
		}
	}
	ALBEDO = c * (1.0 - 0.5 * wetness);
	ROUGHNESS = mix(0.95, 0.12, wetness);
	SPECULAR = mix(0.5, 0.8, wetness);
}
