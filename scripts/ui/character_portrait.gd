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
# Story 18.2: the face moves like a cartoon: an idle bob in the character's own
# rhythm, squash and stretch while talking, eyes that pop when shocked, a droop
# when sad, a hop() on a pick, and pupils that look_at a point. The dead are still.

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
const ANTENNA_FILL := 0.16
## Idle bob height per face size; happy bobs higher, sad lower.
const BOB := {&"happy": 0.035, &"sad": 0.012}
const BOB_DEFAULT := 0.025
## Seconds a hop() takes, from crouch to landing.
const HOP_TIME := 0.45
## Seconds the shocked eye pop takes to settle.
const POP_TIME := 0.5
## Longest combined pupil offset (pose plus look), in pose pupil units.
const PUPIL_REACH := 0.9
## A point this many face sizes away turns the pupils fully toward it.
const LOOK_REACH := 2.0

@export var character: Character
## Drawn greyed, e.g. for a dead character on the roster.
@export var greyed := false
## One of EXPRESSIONS.
@export var expression: StringName = &"neutral":
	set(v):
		if v != expression:
			_expression_at = time
		expression = v
## While true the mouth opens and closes.
@export var talking := false
## Seeds the blink timer; -1 uses the character's id, so a face always blinks alike.
@export var blink_seed := -1
## While true the pupils follow the mouse, e.g. on the board.
@export var follow_mouse := false

## Seconds this face has been alive; drives blinks and talking.
var time := 0.0
## Where the pupils look, set by look_at(): length 0 to 1.
var look := Vector2.ZERO
var _expression_at := 0.0
var _hop_at := -INF

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(64, 64)

func _process(delta: float) -> void:
	time += delta
	if follow_mouse and is_visible_in_tree():
		look_at(get_global_mouse_position())
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

## The whole face's motion for `expr` at `t` seconds: `scale` (around the
## bottom of the head), `offset` (per face size, negative is up) and `eye_pop`
## (multiplies eye_scale). `bounce` is the character's Character.bounce,
## `hop_age` the seconds since hop(), `expr_age` since the expression was set.
## Pure, so tests read motion, not pixels.
static func motion(expr: StringName, t: float, is_talking := false, bounce := Vector2(0.7, 0.0), hop_age := INF, expr_age := INF) -> Dictionary:
	var wave := sin(TAU * (t * bounce.x + bounce.y))
	var y := -float(BOB.get(expr, BOB_DEFAULT)) * wave
	# Stretch a little on the way up, squash on the way down.
	var sy := 1.0 + 0.015 * wave
	var pop := 1.0
	if expr == &"sad":
		y += 0.03
		sy *= 0.96
	elif expr == &"shocked" and expr_age < POP_TIME:
		var k := 1.0 - expr_age / POP_TIME
		pop += 0.18 * k * k * cos(expr_age * 20.0)
		y -= 0.03 * k * k
		sy *= 1.0 + 0.04 * k * k
	if is_talking:
		# Two beats against each other, like the mouth, so it reads as speech.
		sy *= 1.0 + 0.06 * sin(t * 9.0) * (0.7 + 0.3 * sin(t * 2.3))
	if hop_age >= 0.0 and hop_age < HOP_TIME:
		var crouch := 0.08
		var land := 0.36
		if hop_age < crouch:
			sy *= 1.0 - 0.15 * sin(PI * hop_age / crouch)
		elif hop_age < land:
			var u := (hop_age - crouch) / (land - crouch)
			y -= 0.1 * 4.0 * u * (1.0 - u)
			sy *= 1.0 + 0.12 * (1.0 - u)
		else:
			sy *= 1.0 - 0.12 * sin(PI * (hop_age - land) / (HOP_TIME - land))
	# Width answers height, so the face keeps its area.
	return {"scale": Vector2(1.0 / sy, sy), "offset": Vector2(0.0, y), "eye_pop": pop}

## The motion at rest: what a dead face always has.
static func still() -> Dictionary:
	return {"scale": Vector2.ONE, "offset": Vector2.ZERO, "eye_pop": 1.0}

## A cartoon hop, e.g. when the player picks this character. The dead stay still.
func hop() -> void:
	if not is_dead():
		_hop_at = time

## Turns the pupils toward `point`, in global canvas coordinates.
func look_at(point: Vector2) -> void:
	var s := minf(size.x, size.y)
	var d := point - (global_position + size * 0.5 + Vector2(0, s * 0.08))
	look = d / maxf(d.length(), LOOK_REACH * maxf(s, 1.0))

## The face's motion now; still when dead.
func current_motion() -> Dictionary:
	if character == null or is_dead():
		return still()
	return motion(expression, time, talking, character.bounce, time - _hop_at, time - _expression_at)

## A pupil's centre for an eye at `eye` with half size `half`, given the pose's
## pupil offset: clamped to PUPIL_REACH so it never leaves the eye.
static func pupil_center(eye: Vector2, half: Vector2, pupil: Vector2) -> Vector2:
	return eye + Vector2(0, half.y * 0.12) + pupil.limit_length(PUPIL_REACH) * half.x * 0.35

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
	var p := pose(expression, time, talking, s)
	p.pupil = ((p.pupil as Vector2) + look).limit_length(PUPIL_REACH)
	p.eye_scale = float(p.eye_scale) * float(current_motion().eye_pop)
	return p

## True when the eyes show their shine dots: open and alive.
func shows_shine() -> bool:
	return character != null and not is_dead() and float(current_pose().lid) > 0.0


func _draw() -> void:
	if character == null:
		return
	var s := minf(size.x, size.y)
	var c := size * 0.5
	# Squash and stretch the whole drawing around the bottom of the head.
	var m := current_motion()
	var pivot := c + Vector2(0, s * 0.42)
	var sc: Vector2 = m.scale
	draw_set_transform(pivot + (m.offset as Vector2) * s - pivot * sc, 0.0, sc)
	if not drawn():
		draw_texture_rect(character.portrait, Rect2(c - Vector2.ONE * s * 0.5, Vector2.ONE * s), false, _tone(Color.WHITE))
		draw_set_transform(Vector2.ZERO)
		return
	var body := _tone(character.colors[0])
	var accent := _tone(character.colors[1])
	var detail := _tone(character.colors[2]) if character.colors.size() > 2 else accent
	var ink := _tone(INK)
	var r := s * 0.34
	var center := c + Vector2(0, s * 0.08)
	var line := ink_width(r)
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
	draw_set_transform(Vector2.ZERO)

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
	var pc := pupil_center(eye, half, p.pupil)
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
			var stalk := antenna_widths(r)
			_stroke(center - Vector2(0, r * 0.8), tip, ink, stalk.x)
			_stroke(center - Vector2(0, r * 0.8), tip, detail, stalk.y)
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

## Outline width for a face of radius r, in pixels.
static func ink_width(r: float) -> float:
	return maxf(r * 0.1, 1.2)

## The antenna stalk's (ink stroke, colour fill) widths: the fill keeps
## ANTENNA_FILL of r and the ink rims it on both sides, so the stalk reads
## as a solid coloured part joining ball and head at every size.
static func antenna_widths(r: float) -> Vector2:
	var fill := r * ANTENNA_FILL
	return Vector2(fill + ink_width(r) * 2.0, fill)

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
