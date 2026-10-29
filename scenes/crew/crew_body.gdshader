shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap, specular_disabled;
// Story 20.1: a crew body in its CrewLook's colours. tools/models/crew_bodies.py
// moved the recolourable faces into the colormap's empty top row, one cell per
// CrewLook.ROLES entry; everything else (eyes, glasses, belts) samples the
// pack's colormap as made. Flat bright colours with a soft top-to-bottom shade.

uniform sampler2D colormap : source_color, filter_nearest;
uniform vec4 skin : source_color = vec4(0.96, 0.78, 0.62, 1.0);
uniform vec4 hair : source_color = vec4(0.25, 0.18, 0.14, 1.0);
uniform vec4 top : source_color = vec4(0.4, 0.6, 0.9, 1.0);
uniform vec4 bottom : source_color = vec4(0.25, 0.28, 0.4, 1.0);
uniform vec4 shoes : source_color = vec4(0.2, 0.2, 0.24, 1.0);
// Lifts the shadow side so a figure never goes black against a low sun.
uniform float fill = 0.22;

const float COLS = 16.0;
const float ROWS = 4.0;

void fragment() {
	vec3 col;
	if (UV.y < 1.0 / ROWS) {
		int role = int(UV.x * COLS);
		col = role == 0 ? skin.rgb : role == 1 ? hair.rgb : role == 2 ? top.rgb : role == 3 ? bottom.rgb : shoes.rgb;
		// The pack's cells shade from light at the top to darker at the bottom.
		col *= 1.0 - 0.14 * UV.y * ROWS;
	} else {
		col = texture(colormap, UV).rgb;
	}
	ALBEDO = col;
	ROUGHNESS = 0.9;
	EMISSION = col * fill;
}
