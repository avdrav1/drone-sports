class_name CharacterPortrait
extends Control
# A character's face. Uses the portrait texture when there is one; otherwise a
# face drawn in the cast's shape language: a round body, big eyes, two or three
# colors, and one silhouette feature per character. Readable at 64 px.
# Story 17.1: the drawn face has brows, lids, pupils and a mouth, one of
# EXPRESSIONS, blinks on a seeded timer, and moves its mouth while `talking`.
# Greyed out, eyes closed, when the character is dead.
# Story 18.1: a Saturday-morning-cartoon face: a thick dark outline, big low
# eyes with two shine dots, high short brows, a small mouth, cheek blush, and
# a soft smile at rest. Readable at 32 px.

const EXPRESSIONS: Array[StringName] = [&"neutral", &"happy", &"determined", &"worried", &"shocked", &"sad"]

## Face parameters per expression. brow_angle in radians, positive pulls the
## inner ends down (only determined does), negative lifts them (worry);
## brow_height, mouth width and pupil offsets are fractions of the face; lid 1
## is wide open, 0 shut; squint 1 pushes the lower lid up half the eye;
## eye_scale grows the eye; blush 0 to 1; mouth_curve positive smiles, negative
## frowns; mouth_open 0 is a line.
const POSES := {
	&"neutral": {"brow_angle": 0.0, "brow_height": 0.0, "lid": 1.0, "squint": 0.0, "eye_scale": 1.0, "pupil": Vector2.ZERO, "blush": 0.5, "mouth_width": 0.3, "mouth_curve": 0.35, "mouth_open": 0.0},
	&"happy": {"brow_angle": -0.12, "brow_height": 0.08, "lid": 1.0, "squint": 0.4, "eye_scale": 1.0, "pupil": Vector2.ZERO, "blush": 1.0, "mouth_width": 0.6, "mouth_curve": 0.45, "mouth_open": 0.45},
	&"determined": {"brow_angle": 0.22, "brow_height": -0.02, "lid": 0.85, "squint": 0.0, "eye_scale": 1.0, "pupil": Vector2(0.0, -0.15), "blush": 0.4, "mouth_width": 0.36, "mouth_curve": 0.45, "mouth_open": 0.12},
	&"worried": {"brow_angle": -0.3, "brow_height": 0.08, "lid": 1.0, "squint": 0.0, "eye_scale": 1.06, "pupil": Vector2(0.35, -0.15), "blush": 0.3, "mouth_width": 0.26, "mouth_curve": -0.3, "mouth_open": 0.1},
	&"shocked": {"brow_angle": -0.1, "brow_height": 0.12, "lid": 1.0, "squint": 0.0, "eye_scale": 1.2, "pupil": Vector2.ZERO, "blush": 0.0, "mouth_width": 0.3, "mouth_curve": 0.0, "mouth_open": 0.9},
	&"sad": {"brow_angle": -0.4, "brow_height": 0.02, "lid": 0.78, "squint": 0.0, "eye_scale": 1.0, "pupil": Vector2(0.0, 0.4), "blush": 0.3, "mouth_width": 0.3, "mouth_curve": -0.55, "mouth_open": 0.0},
}
## An eye's half width and half height at eye_scale 1, as fractions of the head's radius.
const EYE := Vector2(0.27, 0.33)
## Eyes sit this far below the head's centre, as a fraction of its radius.
const EYE_DROP := 0.08
## Gap from the top of an eye to its brow at brow_height 0, per head radius.
const BROW_GAP := 0.14
## Half the brow stroke's thickness per head radius, at its thickest (32 px).
const BROW_HALF := 0.09
## The lowest edge of each headwear's fill, per head radius from the head's
## centre (negative is up). Brows always stay below it.
const HEADWEAR_BOTTOM := {&"hardhat": -0.82, &"tall": -0.82, &"square": -0.82, &"visor": -0.82}
## Seconds between blinks, and how long the lids stay shut.
const BLINK_GAP := Vector2(2.0, 6.0)
const BLINK_LENGTH := Vector2(0.1, 0.2)
const INK := Color(0.1, 0.08, 0.12)

@export var character: Character
## Drawn greyed, e.g. for a dead character on the roster.
@export var greyed := false
## One of EXPRESSIONS.
@export var expression: StringName = &"neutral"
## While true the mouth opens and closes.
@export var talking := false
## Seeds the blink timer; -1 uses the character's id, so a face always blinks alike.
@export var blink_seed := -1

## Seconds this face has been alive; drives blinks and talking.
var time := 0.0

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(64, 64)

func _process(delta: float) -> void:
	time += delta
	if drawn():
		queue_redraw()

## True when the face is drawn in code; a `portrait` texture overrides it.
func drawn() -> bool:
	return character != null and character.portrait == null

## The face for `expr` at `t` seconds: brow_angle, brow_height, lid, squint,
## eye_scale, pupil, blush, mouth_width, mouth_curve, mouth_open. Pure, so tests read the face, not pixels.
static func pose(expr: StringName, t: float, is_talking := false, rng_seed := 0) -> Dictionary:
	var p: Dictionary = POSES.get(expr, POSES[&"neutral"]).duplicate()
	if blinking(rng_seed, t):
		p.lid = 0.0
	if is_talking:
		# Two rhythms beating against each other, so it reads as speech, not a metronome.
		var wave := absf(sin(t * 11.0)) * (0.65 + 0.35 * sin(t * 3.7))
		p.mouth_open = clampf(p.mouth_open * 0.5 + 0.08 + 0.5 * wave, 0.0, 1.0)
	return p

## How much of the face's height the open part of one eye covers in pose `p`.
static func eye_height(p: Dictionary) -> float:
	return EYE.y * float(p.eye_scale) * maxf(float(p.lid) - float(p.squint) * 0.5, 0.0)

## The highest point a brow's stroke reaches in pose `p`, per head radius from
## the head's centre (negative is up).
static func brow_top(p: Dictionary) -> float:
	var es := float(p.eye_scale)
	var mid := EYE_DROP - EYE.y * es - BROW_GAP - float(p.brow_height)
	var lift := absf(sin(float(p.brow_angle))) * EYE.x * es * 0.6
	return mid - lift - BROW_HALF

## Each blink up to `until` seconds as Vector2(start, length), the same for the same seed.
static func blinks(rng_seed: int, until: float) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var out: Array[Vector2] = []
	var at := rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
	while at <= until:
		var length := rng.randf_range(BLINK_LENGTH.x, BLINK_LENGTH.y)
		out.append(Vector2(at, length))
		at += length + rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
	return out

static func blinking(rng_seed: int, t: float) -> bool:
	for b in blinks(rng_seed, t):
		if t < b.x + b.y:
			return true
	return false

func is_dead() -> bool:
	return greyed or (character != null and not Roster.is_alive(character.id))

## The face as drawn now: the dead never emote. Whatever the expression, their
## lids are shut, brows level, mouth a flat line, no blush, no talking.
func current_pose() -> Dictionary:
	var s := blink_seed
	if s < 0:
		s = hash(character.id) if character else 0
	if is_dead():
		var p := pose(&"neutral", 0.0, false, s)
		p.lid = 0.0
		p.blush = 0.0
		p.brow_angle = 0.0
		p.brow_height = 0.0
		p.mouth_curve = 0.0
		p.mouth_open = 0.0
		return p
	return pose(expression, time, talking, s)

## True when the eyes show their shine dots: open and alive.
func shows_shine() -> bool:
	return character != null and not is_dead() and float(current_pose().lid) > 0.0


func _draw() -> void:
	if character == null:
		return
	var s := minf(size.x, size.y)
	var c := size * 0.5
	if not drawn():
		draw_texture_rect(character.portrait, Rect2(c - Vector2.ONE * s * 0.5, Vector2.ONE * s), false, _tone(Color.WHITE))
		return
	var body := _tone(character.colors[0])
	var accent := _tone(character.colors[1])
	var detail := _tone(character.colors[2]) if character.colors.size() > 2 else accent
	var ink := _tone(INK)
	var r := s * 0.34
	var center := c + Vector2(0, s * 0.08)
	var line := maxf(r * 0.1, 1.2)
	_draw_feature(center, r, body, accent, detail, ink, line)
	draw_circle(center, r, body)
	draw_circle(center, r, ink, false, line, true)
	_draw_headwear(center, r, accent, detail, ink, line)
	var p := current_pose()
	var shine := shows_shine()
	for side in [-1.0, 1.0]:
		if p.blush > 0.0:
			draw_colored_polygon(_oval(center + Vector2(side * r * 0.6, r * 0.5), r * 0.17, r * 0.1), Color(1.0, 0.38, 0.5, 0.6 * float(p.blush)))
		var eye := center + Vector2(side * r * 0.4, r * EYE_DROP)
		_draw_eye(eye, r, p, shine, ink, line)
		_draw_brow(eye, r, side, p, ink, line)
	_draw_mouth(center + Vector2(0, r * 0.62), r, p, ink, line)

func _draw_eye(eye: Vector2, r: float, p: Dictionary, shine: bool, ink: Color, line: float) -> void:
	var half := EYE * r * float(p.eye_scale)
	var lid: float = p.lid
	if lid <= 0.0:
		# Shut: a soft downward curve.
		var shut := PackedVector2Array()
		for i in 7:
			var u := lerpf(-1.0, 1.0, i / 6.0)
			shut.append(eye + Vector2(u * half.x, half.y * (0.15 + 0.3 * (1.0 - u * u))))
		draw_polyline(shut, ink, line, true)
		return
	# The open part: the eye between the upper lid and the squinting lower lid.
	var top := eye.y - half.y + (1.0 - lid) * 2.0 * half.y
	var bottom := eye.y + half.y - float(p.squint) * half.y
	var band := PackedVector2Array([Vector2(eye.x - r, top), Vector2(eye.x + r, top), Vector2(eye.x + r, bottom), Vector2(eye.x - r, bottom)])
	var open := Geometry2D.intersect_polygons(_oval(eye, half.x, half.y), band)
	if open.is_empty():
		return
	var white: PackedVector2Array = open[0]
	draw_colored_polygon(white, _tone(Color.WHITE))
	var pr := half.x * 0.68
	var pc := eye + Vector2(0, half.y * 0.12) + (p.pupil as Vector2) * half.x * 0.35
	for part in Geometry2D.intersect_polygons(_oval(pc, pr, pr * 1.15), white):
		draw_colored_polygon(part, ink)
	if shine:
		# Two shine dots: a big one up and left, a small one down and right.
		for dot in [Vector3(-0.3, -0.42, 0.36), Vector3(0.36, 0.34, 0.18)]:
			var at := pc + Vector2(dot.x, dot.y) * pr
			if Geometry2D.is_point_in_polygon(at, white):
				draw_circle(at, maxf(pr * dot.z, 0.5), Color.WHITE)
	white.append(white[0])
	draw_polyline(white, ink, line, true)

func _draw_brow(eye: Vector2, r: float, side: float, p: Dictionary, ink: Color, line: float) -> void:
	var half := EYE * r * float(p.eye_scale)
	var mid := eye + Vector2(side * half.x * 0.1, -half.y - r * BROW_GAP - float(p.brow_height) * r)
	# Rotate so the inner end (toward the nose) drops when brow_angle is positive.
	var along := Vector2.RIGHT.rotated(-side * float(p.brow_angle)) * half.x * 0.6
	_stroke(mid - along, mid + along, ink, line * 1.5)

func _draw_mouth(m: Vector2, r: float, p: Dictionary, ink: Color, line: float) -> void:
	var half: float = p.mouth_width * r * 0.5
	var curve: float = p.mouth_curve * r * 0.35
	var open: float = p.mouth_open * r * 0.34
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in 9:
		var u := lerpf(-1.0, 1.0, i / 8.0)
		var bulge := 1.0 - u * u
		var y := curve * bulge
		# Open, the upper lip flattens so a smile makes a wide D, not a V.
		var lip := 1.0 - minf(open / maxf(line * 2.0, 0.001), 1.0) * 0.6
		top.append(m + Vector2(u * half, y * lip - open * 0.35 * bulge))
		if i > 0 and i < 8:
			# The lower lip shares the corners with the upper one.
			bottom.append(m + Vector2(u * half, y + open * 0.65 * sqrt(bulge)))
	if open < line:
		draw_polyline(top, ink, line, true)
		return
	bottom.reverse()
	var shape := top.duplicate()
	shape.append_array(bottom)
	draw_colored_polygon(shape, ink)
	if open > line * 1.2:
		var tongue := minf(half * 0.45, open * 0.4)
		draw_circle(m + Vector2(0, curve + open * 0.65 - tongue - line * 0.5), tongue, _tone(Color(0.95, 0.42, 0.5)))
	shape.append(shape[0])
	draw_polyline(shape, ink, line, true)

## Silhouette features behind the head.
func _draw_feature(center: Vector2, r: float, body: Color, accent: Color, detail: Color, ink: Color, line: float) -> void:
	match character.shape:
		&"antenna":
			var tip := center + Vector2(r * 0.18, -r * 1.42)
			_stroke(center - Vector2(0, r * 0.8), tip, ink, r * 0.16)
			_stroke(center - Vector2(0, r * 0.8), tip, detail, r * 0.16 - line * 1.4)
			_ball(tip, r * 0.24, accent, ink, line)
		&"ears":
			for side in [-1.0, 1.0]:
				var ear := center + Vector2(side * r * 0.76, -r * 0.74)
				_ball(ear, r * 0.4, body, ink, line)
				_ball(ear, r * 0.2, accent, ink, line * 0.6)
		&"tuft":
			for x in [-0.32, 0.32, 0.0]:
				_ball(center + Vector2(r * x, -r * (1.02 - absf(x) * 0.35)), r * 0.3, detail, ink, line)
		&"fin":
			_blob(PackedVector2Array([center + Vector2(-r * 0.5, -r * 0.6), center + Vector2(-r * 0.05, -r * 1.25), center + Vector2(r * 0.25, -r * 1.58), center + Vector2(r * 0.55, -r * 0.6)]), detail, ink, line)

## Silhouette features worn on top of the head, in front of it. Each sits with
## its lowest edge at HEADWEAR_BOTTOM so the brows never cross it.
func _draw_headwear(center: Vector2, r: float, accent: Color, detail: Color, ink: Color, line: float) -> void:
	var bottom: float = HEADWEAR_BOTTOM.get(character.shape, 0.0)
	match character.shape:
		&"hardhat":
			var brim := bottom - 0.12
			var dome := PackedVector2Array()
			for i in 13:
				var a := lerpf(PI, TAU, i / 12.0)
				dome.append(center + Vector2(cos(a) * r * 0.8, r * (brim - 0.04) + sin(a) * r * 0.58))
			_blob(dome, detail, ink, line)
			_blob(_rect(center + Vector2(0, r * brim), Vector2(r * 1.1, r * 0.12)), detail, ink, line)
		&"tall":
			_blob(PackedVector2Array([center + Vector2(-r * 0.5, -r * 1.62), center + Vector2(r * 0.5, -r * 1.62), center + Vector2(r * 0.62, r * bottom), center + Vector2(-r * 0.62, r * bottom)]), detail, ink, line)
			_blob(_rect(center + Vector2(0, r * (bottom - 0.14)), Vector2(r * 0.6, r * 0.1)), accent, ink, line * 0.7)
		&"square":
			# Goggles pushed up on top of the head, strap round it.
			var lens := bottom - 0.19
			_blob(_rect(center + Vector2(0, r * lens), Vector2(r * 0.98, r * 0.1)), detail, ink, line)
			for side in [-1.0, 1.0]:
				_ball(center + Vector2(side * r * 0.3, r * lens), r * 0.19, accent, ink, line)
		&"visor":
			# Racing visor pushed up on top of the head.
			_blob(_rect(center + Vector2(0, r * (bottom - 0.13)), Vector2(r * 0.9, r * 0.13)), detail, ink, line)

func _ball(at: Vector2, radius: float, fill: Color, ink: Color, line: float) -> void:
	draw_circle(at, radius, fill)
	draw_circle(at, radius, ink, false, line, true)

func _blob(pts: PackedVector2Array, fill: Color, ink: Color, line: float) -> void:
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, ink, line, true)

## A line with round ends.
func _stroke(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	draw_line(a, b, col, width, true)
	draw_circle(a, width * 0.5, col)
	draw_circle(b, width * 0.5, col)

static func _rect(mid: Vector2, half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([mid - half, mid + Vector2(half.x, -half.y), mid + half, mid + Vector2(-half.x, half.y)])

static func _oval(at: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _tone(col: Color) -> Color:
	if not is_dead():
		return col
	var v := col.get_luminance() * 0.7 + 0.15
	return Color(v, v, v, col.a)
