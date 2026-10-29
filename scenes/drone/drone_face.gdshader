shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
// Story 18.7: a crew drone's LED face panel. Draws CharacterPortrait's face
// from the same pose values (DroneFace sets one uniform per pose field), in
// the pilot's colours, on a rounded screen. Units are the portrait's: one is
// the head's radius, y points down. Cheap enough for GL Compatibility.

uniform vec4 body : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform vec4 ink : source_color = vec4(0.1, 0.08, 0.12, 1.0);
uniform float brow_angle = 0.0;
uniform float brow_height = 0.0;
uniform float lid = 1.0;
uniform float squint = 0.0;
uniform float eye_scale = 1.0;
uniform vec2 pupil = vec2(0.0);
uniform float blush = 0.5;
uniform float mouth_width = 0.3;
uniform float mouth_curve = 0.35;
uniform float mouth_open = 0.0;
// CharacterPortrait.motion(): squash and stretch around the bottom of the head, and the bob.
uniform vec2 squash = vec2(1.0);
uniform vec2 bob = vec2(0.0);

// The panel's size in head radii, and where the head's centre sits on it.
const vec2 PANEL = vec2(2.9, 2.45);
const float LIFT = 0.08;
const vec2 EYE = vec2(0.27, 0.33);
const float EYE_DROP = 0.08;
const float BROW_GAP = 0.14;
const float LINE = 0.1;

float sd_ellipse(vec2 p, vec2 ab) {
	float k0 = length(p / ab);
	float k1 = length(p / (ab * ab));
	return k1 > 0.0 ? k0 * (k0 - 1.0) / k1 : -min(ab.x, ab.y);
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

float sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 at = (UV - 0.5) * PANEL;
	float aa = max(fwidth(at.x), 0.0001);
	float line = max(LINE, aa * 1.2);
	// The bezel: ink, the pilot's accent, ink, then the screen.
	float edge = sd_round_box(at, PANEL * 0.5, 0.5);
	if (edge > 0.0) {
		discard;
	}
	vec3 col = ink.rgb;
	col = mix(col, accent.rgb, smoothstep(aa, -aa, edge + 0.1));
	col = mix(col, ink.rgb, smoothstep(aa, -aa, edge + 0.22));
	float screen = edge + 0.28;
	vec3 face = body.rgb;
	// The face moves inside the screen like the portrait does.
	vec2 pivot = vec2(0.0, 0.42 / 0.34);
	vec2 q = at + vec2(0.0, LIFT);
	q = pivot + (q - pivot - bob / 0.34) / squash;
	// Blush.
	for (int i = 0; i < 2; i++) {
		float side = float(i) * 2.0 - 1.0;
		float b = sd_ellipse(q - vec2(side * 0.6, 0.5), vec2(0.17, 0.1));
		face = mix(face, vec3(1.0, 0.38, 0.5), 0.6 * blush * smoothstep(aa, -aa, b));
	}
	vec2 half_eye = EYE * eye_scale;
	vec2 look = length(pupil) > 0.9 ? normalize(pupil) * 0.9 : pupil;
	for (int i = 0; i < 2; i++) {
		float side = float(i) * 2.0 - 1.0;
		vec2 e = vec2(side * 0.4, EYE_DROP);
		if (lid <= 0.0) {
			// Shut: a soft downward curve.
			float u = clamp((q.x - e.x) / half_eye.x, -1.0, 1.0);
			vec2 c = vec2(e.x + u * half_eye.x, e.y + half_eye.y * (0.15 + 0.3 * (1.0 - u * u)));
			face = mix(face, ink.rgb, smoothstep(aa, -aa, length(q - c) - line * 0.5));
		} else {
			float top = e.y - half_eye.y + (1.0 - lid) * 2.0 * half_eye.y;
			float bottom = e.y + half_eye.y - squint * half_eye.y;
			float open = max(sd_ellipse(q - e, half_eye), max(top - q.y, q.y - bottom));
			face = mix(face, ink.rgb, smoothstep(aa, -aa, open - line * 0.5));
			float white = open + line * 0.5;
			face = mix(face, vec3(1.0), smoothstep(aa, -aa, white));
			vec2 pc = e + vec2(0.0, half_eye.y * 0.12) + look * half_eye.x * 0.35;
			float pr = half_eye.x * 0.68;
			face = mix(face, ink.rgb, smoothstep(aa, -aa, max(sd_ellipse(q - pc, vec2(pr, pr * 1.15)), white)));
			// Two shine dots, a big one up and left and a small one down and right.
			float dot_a = length(q - pc - vec2(-0.3, -0.42) * pr) - max(pr * 0.36, aa);
			float dot_b = length(q - pc - vec2(0.36, 0.34) * pr) - max(pr * 0.18, aa * 0.7);
			face = mix(face, vec3(1.0), smoothstep(aa, -aa, max(min(dot_a, dot_b), white)));
		}
		// Brow: the inner end drops when brow_angle is positive.
		vec2 mid = e + vec2(side * half_eye.x * 0.1, -half_eye.y - BROW_GAP - brow_height);
		float a = -side * brow_angle;
		vec2 along = vec2(cos(a), sin(a)) * half_eye.x * 0.6;
		face = mix(face, ink.rgb, smoothstep(aa, -aa, sd_segment(q, mid - along, mid + along) - line * 0.75));
	}
	// Mouth: the portrait's curve, a line when shut, a filled D when open.
	vec2 m = vec2(0.0, 0.62);
	float mh = max(mouth_width * 0.5, 0.001);
	float curve = mouth_curve * 0.35;
	float gape = mouth_open * 0.34;
	float u = clamp((q.x - m.x) / mh, -1.0, 1.0);
	float bulge = 1.0 - u * u;
	float lip = 1.0 - min(gape / (line * 2.0), 1.0) * 0.6;
	float y_top = m.y + curve * bulge * lip - gape * 0.35 * bulge;
	// Distance to the upper lip, as the portrait's eight-segment polyline.
	float d_top = 1e3;
	vec2 prev = vec2(m.x - mh, m.y);
	for (int i = 1; i <= 8; i++) {
		float s = mix(-1.0, 1.0, float(i) / 8.0);
		float b = 1.0 - s * s;
		vec2 next = vec2(m.x + s * mh, m.y + curve * b * lip - gape * 0.35 * b);
		d_top = min(d_top, sd_segment(q, prev, next));
		prev = next;
	}
	if (gape < line) {
		face = mix(face, ink.rgb, smoothstep(aa, -aa, d_top - line * 0.5));
	} else {
		float y_bottom = m.y + curve * bulge + gape * 0.65 * sqrt(bulge);
		float inside = max(max(y_top - q.y, q.y - y_bottom), abs(q.x - m.x) - mh);
		face = mix(face, ink.rgb, smoothstep(aa, -aa, min(inside, d_top) - line * 0.5));
		if (gape > line * 1.2) {
			float tongue = min(mh * 0.45, gape * 0.4);
			float t = length(q - vec2(m.x, m.y + curve + gape * 0.65 - tongue - line * 0.5)) - tongue;
			face = mix(face, vec3(0.95, 0.42, 0.5), smoothstep(aa, -aa, max(t, inside + line * 0.5)));
		}
	}
	// LED dots: a faint grid, faded out when it would be finer than the pixels.
	vec2 cell = abs(fract(UV * vec2(36.0, 30.0)) - 0.5);
	float grid = smoothstep(0.32, 0.5, max(cell.x, cell.y)) * (1.0 - smoothstep(0.08, 0.2, fwidth(UV.x * 36.0)));
	face *= 1.0 - 0.18 * grid;
	col = mix(col, face, smoothstep(aa, -aa, screen));
	ALBEDO = col;
}
