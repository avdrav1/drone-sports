shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap, specular_disabled;
// Story 20.3: a crew figure's face. Draws CharacterPortrait's face from the
// same pose values (CrewFace sets one uniform per pose field) on the front of
// the head, over the pack's own eyes and mouth. The background is the head's
// skin, shaded and lit as crew_body.gdshader shades it, so the panel does not
// show. Face units are the portrait's: one is the head's radius, y points down.

uniform vec4 skin : source_color = vec4(0.96, 0.78, 0.62, 1.0);
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
// crew_body.gdshader's lift on the shadow side.
uniform float fill = 0.22;

// The panel in head-bone units: the skin front of the pack's head box, its
// width and height (CrewFace.SIZE). Its bottom corners are cut like the chin.
const vec2 PANEL = vec2(0.24, 0.271);
// Head-bone units per face unit, and the face centre's height on the panel,
// so the brows stay under the lowest fringe (0.171) and the mouth above the
// chin. The mouth sits a little higher than the portrait's (0.62) to fit.
const float UNIT = 0.12;
const float CENTRE = 0.09;
const float MOUTH = 0.52;
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

void fragment() {
	// Head-bone units: x right, y up from the bottom of the face.
	vec2 h = vec2((UV.x - 0.5) * PANEL.x, (1.0 - UV.y) * PANEL.y);
	float half_w = h.y < 0.015 ? mix(0.049, 0.099, h.y / 0.015) : mix(0.099, 0.12, clamp((h.y - 0.015) / 0.035, 0.0, 1.0));
	if (abs(h.x) > half_w) {
		discard;
	}
	// The pack's skin cells shade from light at the top to darker at the
	// bottom; the head's front maps its height onto that ramp.
	vec3 face = skin.rgb * (1.0 - 0.56 * (0.025 + 0.63 * h.y));
	vec2 q = vec2(h.x, CENTRE - h.y) / UNIT;
	float aa = max(fwidth(q.x), 0.0001);
	float line = max(LINE, aa * 1.2);
	// White that should stay bright in a low sun: the eyes and their shine.
	float bright = 0.0;
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
			float in_white = smoothstep(aa, -aa, white);
			face = mix(face, vec3(1.0), in_white);
			bright = max(bright, in_white);
			vec2 pc = e + vec2(0.0, half_eye.y * 0.12) + look * half_eye.x * 0.35;
			float pr = half_eye.x * 0.68;
			float in_pupil = smoothstep(aa, -aa, max(sd_ellipse(q - pc, vec2(pr, pr * 1.15)), white));
			face = mix(face, ink.rgb, in_pupil);
			bright *= 1.0 - in_pupil;
			// Two shine dots, a big one up and left and a small one down and right.
			float dot_a = length(q - pc - vec2(-0.3, -0.42) * pr) - max(pr * 0.36, aa);
			float dot_b = length(q - pc - vec2(0.36, 0.34) * pr) - max(pr * 0.18, aa * 0.7);
			float shine = smoothstep(aa, -aa, max(min(dot_a, dot_b), white));
			face = mix(face, vec3(1.0), shine);
			bright = max(bright, shine);
		}
		// Brow: the inner end drops when brow_angle is positive.
		vec2 mid = e + vec2(side * half_eye.x * 0.1, -half_eye.y - BROW_GAP - brow_height);
		float a = -side * brow_angle;
		vec2 along = vec2(cos(a), sin(a)) * half_eye.x * 0.6;
		face = mix(face, ink.rgb, smoothstep(aa, -aa, sd_segment(q, mid - along, mid + along) - line * 0.75));
	}
	// Mouth: the portrait's curve, a line when shut, a filled D when open.
	vec2 m = vec2(0.0, MOUTH);
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
	ALBEDO = face;
	ROUGHNESS = 0.9;
	EMISSION = face * mix(fill, 0.55, bright);
}
