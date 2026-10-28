class_name CharacterPortrait
extends Control
# A character's face. Uses the portrait texture when there is one; otherwise a
# face drawn in the cast's shape language: a round body, big eyes, two or three
# colors, and one silhouette feature per character. Readable at 64 px.
# Story 17.1: the drawn face has brows, lids, pupils and a mouth, one of
# EXPRESSIONS, blinks on a seeded timer, and moves its mouth while `talking`.
# Greyed out, eyes closed, when the character is dead.

const EXPRESSIONS: Array[StringName] = [&"neutral", &"happy", &"determined", &"worried", &"shocked", &"sad"]

## Face parameters per expression. brow_angle in radians, positive pulls the
## inner ends down (a frown), negative lifts them (worry); brow_height, mouth
## width and pupil offsets are fractions of the face; lid 1 is wide open, 0
## shut; mouth_curve positive smiles, negative frowns; mouth_open 0 is a line.
const POSES := {
	&"neutral": {"brow_angle": 0.0, "brow_height": 0.0, "lid": 1.0, "pupil": Vector2.ZERO, "mouth_width": 0.42, "mouth_curve": 0.08, "mouth_open": 0.0},
	&"happy": {"brow_angle": -0.08, "brow_height": 0.06, "lid": 0.7, "pupil": Vector2.ZERO, "mouth_width": 0.6, "mouth_curve": 0.6, "mouth_open": 0.4},
	&"determined": {"brow_angle": 0.38, "brow_height": -0.06, "lid": 0.6, "pupil": Vector2.ZERO, "mouth_width": 0.4, "mouth_curve": -0.1, "mouth_open": 0.0},
	&"worried": {"brow_angle": -0.36, "brow_height": 0.07, "lid": 1.0, "pupil": Vector2(0.35, -0.15), "mouth_width": 0.34, "mouth_curve": -0.22, "mouth_open": 0.06},
	&"shocked": {"brow_angle": -0.12, "brow_height": 0.18, "lid": 1.0, "pupil": Vector2.ZERO, "mouth_width": 0.34, "mouth_curve": 0.0, "mouth_open": 0.9},
	&"sad": {"brow_angle": -0.42, "brow_height": -0.02, "lid": 0.55, "pupil": Vector2(0.0, 0.4), "mouth_width": 0.4, "mouth_curve": -0.5, "mouth_open": 0.0},
}
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

## The face for `expr` at `t` seconds: brow_angle, brow_height, lid, pupil,
## mouth_width, mouth_curve, mouth_open. Pure, so tests read the face, not pixels.
static func pose(expr: StringName, t: float, is_talking := false, rng_seed := 0) -> Dictionary:
	var p: Dictionary = POSES.get(expr, POSES[&"neutral"]).duplicate()
	if blinking(rng_seed, t):
		p.lid = 0.0
	if is_talking:
		# Two rhythms beating against each other, so it reads as speech, not a metronome.
		var wave := absf(sin(t * 11.0)) * (0.65 + 0.35 * sin(t * 3.7))
		p.mouth_open = clampf(p.mouth_open * 0.5 + 0.08 + 0.5 * wave, 0.0, 1.0)
	return p

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

## The face as drawn now: the dead keep their lids shut and stop talking.
func current_pose() -> Dictionary:
	var s := blink_seed
	if s < 0:
		s = hash(character.id) if character else 0
	if is_dead():
		var p := pose(expression, 0.0, false, s)
		p.lid = 0.0
		return p
	return pose(expression, time, talking, s)

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
	var r := s * 0.36
	var center := c + Vector2(0, s * 0.06)
	_draw_feature(center, r, body, accent, detail)
	draw_circle(center, r, body)
	draw_circle(center + Vector2(0, r * 0.45), r * 0.5, accent)
	if character.shape == &"square":
		# Goggles strap across the eyes.
		draw_rect(Rect2(center - Vector2(r * 1.08, r * 0.38), Vector2(r * 2.16, r * 0.46)), detail)
	elif character.shape == &"visor":
		# Racing visor pushed up on the forehead.
		draw_rect(Rect2(center - Vector2(r * 0.95, r * 0.82), Vector2(r * 1.9, r * 0.32)), detail)
	var p := current_pose()
	var ink := _tone(INK)
	var line := maxf(r * 0.08, 1.0)
	for side in [-1.0, 1.0]:
		var eye := center + Vector2(side * r * 0.4, -r * 0.15)
		_draw_eye(eye, r * 0.26, p, body, ink, line)
		_draw_brow(eye, r * 0.26, r, side, p, ink, line)
	_draw_mouth(center + Vector2(0, r * 0.47), r, p, ink, line)

func _draw_eye(eye: Vector2, er: float, p: Dictionary, lid_color: Color, ink: Color, line: float) -> void:
	draw_circle(eye, er, _tone(Color.WHITE))
	var pupil: Vector2 = p.pupil
	draw_circle(eye + Vector2(0, er * 0.2) + pupil * er * 0.4, er * 0.5, ink)
	var lid: float = p.lid
	if lid >= 1.0:
		return
	# The lid: the part of the eye above a cut that falls as the eye closes.
	var cut := er * (1.0 - 2.0 * lid)
	var reach := er + 0.75
	var half := acos(clampf(-cut / reach, -1.0, 1.0))
	var pts := PackedVector2Array()
	for i in 13:
		var a := lerpf(-half, half, i / 12.0)
		pts.append(eye + Vector2(sin(a), -cos(a)) * reach)
	draw_colored_polygon(pts, lid_color)
	var edge := sqrt(maxf(er * er - cut * cut, 0.0))
	if lid <= 0.0:
		# Shut: a soft downward curve.
		draw_polyline(PackedVector2Array([eye + Vector2(-er, er * 0.1), eye + Vector2(0, er * 0.45), eye + Vector2(er, er * 0.1)]), ink, line, true)
	else:
		draw_line(eye + Vector2(-edge, cut), eye + Vector2(edge, cut), ink, line, true)

func _draw_brow(eye: Vector2, er: float, r: float, side: float, p: Dictionary, ink: Color, line: float) -> void:
	var mid := eye + Vector2(side * er * 0.1, -er * 1.45 - float(p.brow_height) * r)
	# Rotate so the inner end (toward the nose) drops when brow_angle is positive.
	var along := Vector2.RIGHT.rotated(-side * float(p.brow_angle)) * er * 0.85
	draw_line(mid - along, mid + along, ink, line * 1.3, true)

func _draw_mouth(m: Vector2, r: float, p: Dictionary, ink: Color, line: float) -> void:
	var half: float = p.mouth_width * r * 0.5
	var curve: float = p.mouth_curve * r * 0.2
	var open: float = p.mouth_open * r * 0.32
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in 9:
		var u := lerpf(-1.0, 1.0, i / 8.0)
		var bulge := 1.0 - u * u
		var y := curve * bulge
		top.append(m + Vector2(u * half, y - open * 0.35 * bulge))
		if i > 0 and i < 8:
			# The lower lip shares the corners with the upper one.
			bottom.append(m + Vector2(u * half, y + open * 0.65 * bulge))
	if open < line:
		draw_polyline(top, ink, line, true)
		return
	bottom.reverse()
	var shape := top.duplicate()
	shape.append_array(bottom)
	draw_colored_polygon(shape, ink)

func _draw_feature(center: Vector2, r: float, body: Color, accent: Color, detail: Color) -> void:
	match character.shape:
		&"antenna":
			draw_line(center - Vector2(0, r * 0.9), center - Vector2(0, r * 1.45), detail, maxf(r * 0.08, 1.5))
			draw_circle(center - Vector2(0, r * 1.5), r * 0.16, accent)
		&"hardhat":
			draw_rect(Rect2(center - Vector2(r * 1.1, r * 0.75), Vector2(r * 2.2, r * 0.2)), detail)
			draw_circle(center - Vector2(0, r * 0.7), r * 0.75, detail)
		&"ears":
			for side in [-1.0, 1.0]:
				draw_circle(center + Vector2(side * r * 0.75, -r * 0.8), r * 0.38, body)
				draw_circle(center + Vector2(side * r * 0.75, -r * 0.8), r * 0.2, accent)
		&"tall":
			draw_rect(Rect2(center - Vector2(r * 0.55, r * 1.55), Vector2(r * 1.1, r * 0.7)), detail)
		&"tuft":
			for x in [-0.3, 0.0, 0.3]:
				draw_circle(center + Vector2(r * x, -r * (1.0 - absf(x) * 0.4)), r * 0.24, detail)
		&"fin":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.45, -r * 0.7), center + Vector2(r * 0.1, -r * 1.5), center + Vector2(r * 0.5, -r * 0.7)]), detail)

func _tone(col: Color) -> Color:
	if not is_dead():
		return col
	var v := col.get_luminance() * 0.7 + 0.15
	return Color(v, v, v, col.a)
