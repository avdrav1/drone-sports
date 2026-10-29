shader_type canvas_item;
// Lays the crawl's text on a plane tipped away from the viewer: full width at
// the bottom edge, narrowing to top_width at the top, faded into the distance.

uniform sampler2D text_tex : filter_linear, repeat_disable;
uniform vec2 text_size = vec2(900.0, 2000.0);
uniform vec2 rect_size = vec2(1280.0, 300.0);
// Text pixel at the bottom edge.
uniform float scroll = 0.0;
uniform float top_width = 0.25;
uniform float fade = 0.35;
// Lines rise out of nothing over this bottom fraction.
uniform float rise = 0.12;

void fragment() {
	float w = mix(top_width, 1.0, UV.y);
	float x = 0.5 + (UV.x - 0.5) / w;
	// Text pixels per screen pixel at the bottom edge, the same both ways.
	float s = text_size.x / rect_size.x;
	float k = s * rect_size.y / (1.0 - top_width);
	float v = scroll - k * (1.0 / w - 1.0);
	vec2 at = vec2(x, v / text_size.y);
	vec4 c = texture(text_tex, at);
	if (at.x < 0.0 || at.x > 1.0 || at.y < 0.0 || at.y > 1.0) {
		c = vec4(0.0);
	}
	c.a *= smoothstep(0.0, fade, UV.y) * smoothstep(1.0, 1.0 - rise, UV.y);
	COLOR = c;
}
