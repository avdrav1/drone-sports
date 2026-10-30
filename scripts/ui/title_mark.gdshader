shader_type canvas_item;
// Story 24.6: the title's fill, saffron at the bar to gold-orange at the feet.
// TitleMark draws its fill in white and sets the rows the gradient spans.

uniform float top = 0.0;
uniform float bottom = 1.0;
uniform vec4 top_color : source_color = vec4(1.0, 0.86, 0.35, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.98, 0.45, 0.08, 1.0);

varying float row;

void vertex() {
	row = VERTEX.y;
}

void fragment() {
	float t = clamp((row - top) / max(bottom - top, 1.0), 0.0, 1.0);
	COLOR.rgb *= mix(top_color.rgb, bottom_color.rgb, t);
}
