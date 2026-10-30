class_name CharacterPortrait
extends Control
# A character's face. Uses the portrait texture when there is one; otherwise a
# face painted in code.
# Story 17.1: the drawn face has brows, lids, pupils and a mouth, one of
# EXPRESSIONS, blinks on a seeded timer, and moves its mouth while `talking`.
# Greyed out, eyes closed, when the character is dead.
# Story 18.2: pure motion(): an idle bob in the character's own rhythm, squash
# and stretch while talking, an eye pop when shocked, a droop when sad, a hop()
# on a pick, and pupils that look_at a point. The dead are still.
# Story 18.10: a DISTRESS face (a wince and a shake) for a drone in trouble, and
# `signal_lost` fills the portrait with TV static while its drone is down. The
# dead never show either.
# Story 18.9: pop_in() springs the face in when a radio line opens, from small
# to a little too big and back to rest within POP_IN_TIME.
# Story 20.4: the face is a person from the shoulders up, coloured from their
# CrewLook.
# Story 26.1: the face is painted, not a cartoon: a head and shoulders in real
# proportions, shaded with a key light from the upper left and a warm shadow
# side, a nose, small eyes with irises, lids and lashes, lips, ears, and hair or
# fur laid down in strands. Three kinds of head: human, vanara and bird, from
# the look. 18.2's motion is painted subtly: a breath, a small head tilt, and
# the jaw moving while talking. The still parts are built once per character
# and size and kept as meshes; only the eyes, brows and mouth are drawn anew.

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
	&"distress": {"brow_angle": -0.38, "brow_height": 0.1, "lid": 1.0, "squint": 0.5, "eye_scale": 0.95, "pupil": Vector2.ZERO, "blush": 0.0, "mouth_width": 0.46, "mouth_curve": -0.25, "mouth_open": 0.3},
}
## A wince for a crew drone in trouble (Story 18.10): squeezed eyes, brows up,
## a gritted grimace, and a shake in motion(). Set by CrewDistress from flight
## events, never by a line, so it is not one of EXPRESSIONS.
const DISTRESS := &"distress"
## Static cells across a signal-lost portrait, at most; and frames per second.
const STATIC_CELLS := 14
const STATIC_FPS := 20.0
## The kinds of head a look can have (Story 26.1).
const HEADS: Array[StringName] = [&"human", &"vanara", &"bird"]
## The head's radius per portrait size, and how far its centre sits from the
## portrait's middle per size (negative is up). Every other length on the face
## is per head radius from the head's centre.
const HEAD := 0.22
const HEAD_Y := -0.08
## The portrait's bottom edge and its sides, per head radius from the head's centre.
const BOTTOM := (0.5 - HEAD_Y) / HEAD
const SIDE := 0.5 / HEAD
## A human eye's half width and half height at eye_scale 1, and how far its
## centre sits out from the middle and down from the head's centre.
const EYE := Vector2(0.15, 0.075)
const EYE_X := 0.31
const EYE_DROP := 0.08
## Gap from the top of an eye to its brow at brow_height 0; a pose's
## brow_height moves the brow by BROW_LIFT of itself; the brow's half length,
## its arch, and half its stroke at the thickest.
const BROW_GAP := 0.08
const BROW_LIFT := 0.5
const BROW_REACH := 0.18
const BROW_ARCH := 0.035
const BROW_HALF := 0.035
## Front hair stops at HAIRLINE (above every brow) out to HAIR_EDGE, then runs
## down the temples to SIDEBURN at TEMPLE.
const HAIRLINE := -0.62
const HAIR_EDGE := 0.4
const TEMPLE := 0.8
const SIDEBURN := 0.25
## How far the jaw drops at mouth_open 1.
const JAW_DROP := 0.06
## A head tilt per expression in radians, eased in as the expression is set.
const TILT := {&"happy": -0.025, &"determined": -0.012, &"worried": 0.035, &"sad": 0.05}
## Seconds between blinks, and how long the lids stay shut.
const BLINK_GAP := Vector2(2.0, 6.0)
const BLINK_LENGTH := Vector2(0.1, 0.2)
const INK := Color(0.1, 0.08, 0.12)
## Idle bob height per face size; happy bobs higher, sad lower.
const BOB := {&"happy": 0.035, &"sad": 0.012}
const BOB_DEFAULT := 0.025
## Seconds a hop() takes, from crouch to landing.
const HOP_TIME := 0.45
## Seconds the shocked eye pop takes to settle.
const POP_TIME := 0.5
## Seconds a pop_in() takes to overshoot and settle at rest.
const POP_IN_TIME := 0.32
## The pop-in's starting size, per the face at rest.
const POP_IN_FROM := 0.3
## Longest combined pupil offset (pose plus look), in pose pupil units.
const PUPIL_REACH := 0.9
## A point this many face sizes away turns the pupils fully toward it.
const LOOK_REACH := 2.0
## How much of 18.2's cartoon motion the painted face keeps.
const SUBTLE := 0.3

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
## While true (and alive) the face is gone: TV static and SIGNAL LOST.
@export var signal_lost := false
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
var _pop_at := -INF

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(64, 64)

func _process(delta: float) -> void:
	time += delta
	if follow_mouse and is_visible_in_tree():
		look_at(get_global_mouse_position())
	if drawn() or shows_static():
		queue_redraw()

## True when the face is drawn in code; a `portrait` texture overrides it.
func drawn() -> bool:
	return character != null and character.portrait == null

## The portrait's colours: skin, hair, top (the shirt), accessory and detail,
## from the character's CrewLook; without a look, from `colors`.
static func palette(c: Character) -> Dictionary:
	if c.look:
		var l := c.look
		return {"skin": l.skin, "hair": l.hair, "top": l.top, "accessory": l.accessory_color, "detail": l.accessory_detail}
	var detail: Color = c.colors[2] if c.colors.size() > 2 else c.colors[1]
	return {"skin": c.colors[0], "hair": c.colors[1], "top": c.colors[1], "accessory": c.colors[1], "detail": detail}

## The character's hair style from their look's body; empty without a look.
static func hair_style(c: Character) -> StringName:
	return c.look.hair_style() if c.look else &""

## Where the front hair ends at `x` across the face, both per head radius from
## its centre (negative is up).
static func hairline(x: float) -> float:
	return lerpf(HAIRLINE, SIDEBURN, smoothstep(HAIR_EDGE, TEMPLE, absf(x)))

## The head kind of the character's look, one of HEADS; human without a look.
static func head_kind(c: Character) -> StringName:
	return c.look.head if c.look and c.look.head in HEADS else &"human"

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
## `hop_age` the seconds since hop(), `expr_age` since the expression was set,
## `pop_age` since pop_in(). Pure, so tests read motion, not pixels.
static func motion(expr: StringName, t: float, is_talking := false, bounce := Vector2(0.7, 0.0), hop_age := INF, expr_age := INF, pop_age := INF) -> Dictionary:
	var wave := sin(TAU * (t * bounce.x + bounce.y))
	var y := -float(BOB.get(expr, BOB_DEFAULT)) * wave
	# Stretch a little on the way up, squash on the way down.
	var sy := 1.0 + 0.015 * wave
	var pop := 1.0
	var x := 0.0
	if expr == DISTRESS:
		# A nervous shake: two quick wobbles beating, well inside the face.
		x = 0.022 * sin(t * 47.0) * (0.6 + 0.4 * sin(t * 6.3))
		sy *= 0.97
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
	var sc := Vector2(1.0 / sy, sy)
	if pop_age >= 0.0 and pop_age < POP_IN_TIME:
		# Springs up from small, overshoots, and lands exactly at rest; stretched
		# tall on the way up and squashed wide on the overshoot.
		var u := pop_age / POP_IN_TIME
		var k := pow(1.0 - u, 1.5) * cos(PI * 1.5 * u)
		var grow := 1.0 - (1.0 - POP_IN_FROM) * k
		var stretch := 1.0 + 0.25 * pow(1.0 - u, 2.0) * sin(PI * 3.0 * u)
		sc *= grow * Vector2(1.0 / stretch, stretch)
	return {"scale": sc, "offset": Vector2(x, y), "eye_pop": pop}

## The motion at rest: what a dead face always has.
static func still() -> Dictionary:
	return {"scale": Vector2.ONE, "offset": Vector2.ZERO, "eye_pop": 1.0}

## A hop, e.g. when the player picks this character. The dead stay still.
func hop() -> void:
	if not is_dead():
		_hop_at = time

## Springs the face in, e.g. as a radio line opens. The dead stay still.
func pop_in() -> void:
	if not is_dead():
		_pop_at = time

## Turns the pupils toward `point`, in global canvas coordinates.
func look_at(point: Vector2) -> void:
	var s := minf(size.x, size.y)
	var d := point - (global_position + size * 0.5 + Vector2(0, s * (HEAD_Y + HEAD * EYE_DROP)))
	look = d / maxf(d.length(), LOOK_REACH * maxf(s, 1.0))

## The face's motion now; still when dead.
func current_motion() -> Dictionary:
	if character == null or is_dead():
		return still()
	return motion(expression, time, talking, character.bounce, time - _hop_at, time - _expression_at, time - _pop_at)

## A pupil's centre for an eye at `eye` with half size `half`, given the pose's
## pupil offset: clamped to PUPIL_REACH so it never leaves the eye.
static func pupil_center(eye: Vector2, half: Vector2, pupil: Vector2) -> Vector2:
	return eye + Vector2(0, half.y * 0.12) + pupil.limit_length(PUPIL_REACH) * half * 0.35

## How much of the head's radius the open part of one eye covers in pose `p`.
static func eye_height(p: Dictionary) -> float:
	return EYE.y * float(p.eye_scale) * maxf(float(p.lid) - float(p.squint) * 0.5, 0.0)

## The highest point a brow's stroke reaches in pose `p`, per head radius from
## the head's centre (negative is up).
static func brow_top(p: Dictionary) -> float:
	var mid := EYE_DROP - EYE.y * float(p.eye_scale) - BROW_GAP - float(p.brow_height) * BROW_LIFT
	var lift := absf(sin(float(p.brow_angle))) * BROW_REACH
	return mid - lift - BROW_ARCH - BROW_HALF

## How far out from the middle a brow reaches, per head radius.
static func brow_reach() -> float:
	return EYE_X + BROW_REACH + BROW_HALF

## How far the jaw drops in pose `p`, per head radius: talking moves it.
static func jaw(p: Dictionary) -> float:
	return float(p.mouth_open) * JAW_DROP

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

## True while the portrait shows static instead of the face: its drone is down
## and the character alive (a downed drone is not a death).
func shows_static() -> bool:
	return signal_lost and character != null and not is_dead()

## Brightness 0 to 1 of static cell (i, j) on frame `frame`; frames change
## STATIC_FPS times a second. Pure, so tests read the noise, not pixels.
static func static_noise(i: int, j: int, frame: int) -> float:
	var h := hash(Vector3i(i, j, frame))
	return float(h & 1023) / 1023.0

## True when the eyes show their catchlight (one small glint each): open and alive.
func shows_shine() -> bool:
	return character != null and not is_dead() and float(current_pose().lid) > 0.0


## The face's motion as painted: 18.2's motion() kept to SUBTLE of itself, a
## slow sway and a tilt for the expression, and a breath for the shoulders.
## Still when dead.
func painted_motion() -> Dictionary:
	if character == null or is_dead():
		return {"scale": Vector2.ONE, "offset": Vector2.ZERO, "tilt": 0.0, "breath": 0.0}
	var m := current_motion()
	var b := character.bounce
	var ease := smoothstep(0.0, 0.5, time - _expression_at)
	var off: Vector2 = (m.offset as Vector2) * SUBTLE
	var tilt := 0.018 * sin(TAU * (time * b.x * 0.4 + b.y)) + float(TILT.get(expression, 0.0)) * ease + off.x * 1.5
	return {"scale": Vector2.ONE + ((m.scale as Vector2) - Vector2.ONE) * SUBTLE, "offset": off, "tilt": tilt,
		"breath": sin(TAU * (time * 0.23 + b.y))}

## The parts painted for `c` at `s` px, e.g. nose, iris, lids, hair: so tests
## read what is drawn, not pixels.
static func paint_parts(c: Character, s: float) -> PackedStringArray:
	var parts := PackedStringArray(paint(c, s, false).parts)
	var p := Paint.new(Vector2.ZERO, s * HEAD)
	paint_face(p, c, pose(&"neutral", 0.0), true)
	parts.append_array(p.parts)
	return parts

## The still parts of a face, built once per character, size and death.
static var _painted := {}

func _layers(s: float) -> Dictionary:
	var key := "%d|%d|%d" % [character.get_instance_id(), roundi(s * 4.0), int(is_dead())]
	if not _painted.has(key):
		if _painted.size() > 80:
			_painted.clear()
		_painted[key] = paint(character, s, is_dead())
	return _painted[key]

func _draw() -> void:
	if character == null:
		return
	var s := minf(size.x, size.y)
	var c := size * 0.5
	if shows_static():
		_draw_static(c, s)
		return
	var m := painted_motion()
	var sc: Vector2 = m.scale
	if not drawn():
		var pivot := c + Vector2(0, s * 0.42)
		draw_set_transform(pivot + (m.offset as Vector2) * s - pivot * sc, float(m.tilt), sc)
		draw_texture_rect(character.portrait, Rect2(c - Vector2.ONE * s * 0.5, Vector2.ONE * s), false, _tone(Color.WHITE))
		draw_set_transform(Vector2.ZERO)
		return
	var corner := (size - Vector2(s, s)) * 0.5
	var r := s * HEAD
	var neck := corner + Vector2(s * 0.5, s * (0.5 + HEAD_Y) + r * 1.3)
	# The head turns about the neck; the shoulders only breathe.
	var head_xf := Transform2D(float(m.tilt), sc, 0.0, neck + (m.offset as Vector2) * s) * Transform2D(0.0, -neck)
	var foot := corner + Vector2(s * 0.5, s)
	var breath := Vector2(1.0, 1.0 + 0.008 * float(m.breath))
	var body_xf := Transform2D(0.0, breath, 0.0, foot) * Transform2D(0.0, -foot) * Transform2D(0.0, corner)
	head_xf = head_xf * Transform2D(0.0, corner)
	var layers := _layers(s)
	var p := current_pose()
	_mesh(layers.back, head_xf)
	_mesh(layers.body, body_xf)
	_mesh(layers.head, head_xf)
	draw_set_transform_matrix(head_xf)
	for part in _moving_parts(s, p):
		if not part.indices.is_empty():
			RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), part.indices, part.points, part.colors)
	_mesh(layers.jaw, head_xf * Transform2D(0.0, Vector2(0, jaw(p) * r)))
	_mesh(layers.front, head_xf)
	_mesh(layers.held, body_xf)
	draw_set_transform(Vector2.ZERO)

## The moving parts of the face drawn before, by pose rounded finely enough
## not to show: a face that holds still or repeats a pose builds nothing new.
static var _moving := {}

## The eyes, brows and mouth for pose `p`, from _moving or painted and kept.
func _moving_parts(s: float, p: Dictionary) -> Array[Paint]:
	var kind := head_kind(character)
	var shine := shows_shine()
	var q := p.duplicate()
	for f in ["lid", "squint", "brow_height", "mouth_width", "mouth_curve", "mouth_open"]:
		q[f] = snappedf(float(p[f]), 0.02)
	q.eye_scale = snappedf(float(p.eye_scale), 0.02)
	q.brow_angle = snappedf(float(p.brow_angle), 0.01)
	q.pupil = (p.pupil as Vector2).snapped(Vector2(0.05, 0.05))
	var base := "%d|%d|%d|%d|" % [character.get_instance_id(), roundi(s * 4.0), int(is_dead()), int(shine)]
	var keys := [
		"eyes|%s|%s|%s|%s|%s" % [q.lid, q.squint, q.eye_scale, q.pupil, shine],
		"brows|%s|%s|%s" % [q.brow_angle, q.brow_height, q.eye_scale],
		"mouth|%s|%s|%s" % [q.mouth_width, q.mouth_curve, q.mouth_open],
	]
	var out: Array[Paint] = []
	if _moving.size() > 3000:
		_moving.clear()
	for k in 3:
		var key: String = base + keys[k]
		if not _moving.has(key):
			var pt := Paint.new(Vector2(s * 0.5, s * (0.5 + HEAD_Y)), s * HEAD, is_dead())
			match k:
				0:
					for side: float in [-1.0, 1.0]:
						_paint_eye(pt, kind, side, q, shine)
				1:
					for side: float in [-1.0, 1.0]:
						_paint_brow(pt, kind, side, q, palette(character))
				2:
					_paint_mouth_of(pt, character, q)
			_moving[key] = pt
		out.append(_moving[key])
	return out

func _mesh(mesh: ArrayMesh, xf: Transform2D) -> void:
	if mesh.get_surface_count() > 0:
		draw_set_transform_matrix(xf)
		draw_mesh(mesh, null)

## The portrait's square full of rolling TV static, with SIGNAL LOST across it.
func _draw_static(c: Vector2, s: float) -> void:
	var box := Rect2(c - Vector2.ONE * s * 0.46, Vector2.ONE * s * 0.92)
	var n := clampi(int(s / 4.0), 6, STATIC_CELLS)
	var cell := box.size / n
	var frame := int(time * STATIC_FPS)
	# A brighter band rolls down the screen, like a lost channel.
	var roll := fmod(time * 0.8, 1.3) - 0.15
	for j in n:
		var band := 0.3 * maxf(0.0, 1.0 - absf(float(j) / n - roll) * 6.0)
		for i in n:
			var v := 0.2 + 0.7 * static_noise(i, j, frame) + band
			draw_rect(Rect2(box.position + cell * Vector2(i, j), cell + Vector2(0.5, 0.5)), Color(v * 0.9, v * 0.95, minf(v * 1.08, 1.0)))
	var line := ink_width(s * 0.34)
	var font := get_theme_default_font()
	var fs := maxi(int(s * 0.19), 7)
	var label := Rect2(box.position.x, c.y - fs * 1.15, box.size.x, fs * 2.3)
	draw_rect(label, Color(INK, 0.85))
	for k in 2:
		var word := "SIGNAL" if k == 0 else "LOST"
		draw_string(font, Vector2(label.position.x, c.y - fs * 0.15 + fs * k * 1.05), word, HORIZONTAL_ALIGNMENT_CENTER, label.size.x, fs, Color(1.0, 0.95, 0.6))
	draw_rect(box, INK, false, line)


func _tone(col: Color) -> Color:
	return Paint.tone(col, is_dead())

## Outline width for a face of radius r, in pixels (the signal-lost frame).
static func ink_width(r: float) -> float:
	return maxf(r * 0.1, 1.2)


# --- Painting -----------------------------------------------------------------

## Builds triangles with a colour per vertex, from shapes given in head units
## (head radius 1, its centre at 0, y down), into pixels. Every shape's edge
## fades out over a pixel, so edges are soft at any size.
class Paint:
	## The key light: from the upper left, in front.
	const LIGHT := Vector3(-0.5, -0.55, 0.67)
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	## What was painted, for tests: nose, iris, lids, hair...
	var parts := PackedStringArray()
	var origin := Vector2.ZERO
	var unit := 1.0
	var grey := false

	func _init(at := Vector2.ZERO, r := 1.0, is_grey := false) -> void:
		origin = at
		unit = maxf(r, 0.001)
		grey = is_grey

	## The dead's grey: the colour's lightness, a little lifted.
	static func tone(c: Color, is_grey: bool) -> Color:
		if not is_grey:
			return c
		var v := c.get_luminance() * 0.7 + 0.15
		return Color(v, v, v, c.a)

	## One pixel, in head units.
	func px() -> float:
		return 1.0 / unit

	func vert(p: Vector2, c: Color) -> int:
		points.append(origin + p * unit)
		colors.append(tone(c, grey))
		return points.size() - 1

	## `base` lit by the key light on a surface facing `n`: a warm shadow side,
	## the colour itself in the half light, lighter toward the light, and a
	## highlight of `gloss`.
	static func lit(base: Color, n: Vector3, gloss := 0.0) -> Color:
		var l := LIGHT.normalized()
		var t := clampf(n.dot(l) * 0.5 + 0.5, 0.0, 1.0)
		var dark := Color(base.r * 0.46, base.g * 0.36, base.b * 0.4, base.a)
		var c := dark.lerp(base, smoothstep(0.08, 0.7, t)) if t < 0.7 else base.lerp(base.lightened(0.2), smoothstep(0.7, 1.0, t))
		if gloss > 0.0:
			var h := (l + Vector3(0, 0, 1)).normalized()
			c = c.lerp(Color(1.0, 0.97, 0.9, base.a), gloss * pow(maxf(n.dot(h), 0.0), 24.0))
		return c

	## A flat fill.
	func fill(poly: PackedVector2Array, col: Color, feather := 1.0) -> void:
		var cols := PackedColorArray()
		cols.resize(poly.size())
		cols.fill(col)
		fill_colors(poly, cols, feather)

	## A fill with a colour per corner.
	func fill_colors(poly: PackedVector2Array, cols: PackedColorArray, feather := 1.0) -> void:
		if poly.size() < 3:
			return
		var tri := Geometry2D.triangulate_polygon(poly)
		if tri.is_empty():
			return
		var base := points.size()
		for i in poly.size():
			vert(poly[i], cols[i])
		for i in tri:
			indices.append(base + i)
		if feather > 0.0:
			_rim(poly, base, feather)

	## A rounded form inside `ring`, facing the viewer at `at` and turning away
	## toward its edge (`bulge` 1 is a ball, less is flatter), lit by the key light.
	func dome(at: Vector2, ring: PackedVector2Array, base: Color, bulge := 0.8, gloss := 0.0, rings := 4) -> void:
		var n := ring.size()
		var start := vert(at, lit(base, Vector3(0, 0, 1), gloss))
		for k in range(1, rings + 1):
			var rho := sin(PI * 0.5 * float(k) / rings)
			for i in n:
				var d := ring[i] - at
				var dir := d.normalized()
				var nz := sqrt(maxf(1.0 - rho * rho, 0.0)) + 0.15
				vert(at + d * float(k) / rings, lit(base, Vector3(dir.x * rho * bulge, dir.y * rho * bulge, nz).normalized(), gloss))
		for i in n:
			indices.append_array([start, start + 1 + i, start + 1 + (i + 1) % n])
		for k in range(1, rings):
			var a := start + 1 + (k - 1) * n
			var b := a + n
			for i in n:
				var j := (i + 1) % n
				indices.append_array([a + i, b + i, b + j, a + i, b + j, a + j])
		_rim(ring, start + 1 + (rings - 1) * n, 1.0)

	## Any shape, each corner lit as if on a ball of `radius` round `at`: for
	## shapes a dome cannot fill from one point, like a crescent of hair.
	func shaded(poly: PackedVector2Array, base: Color, at: Vector2, radius: Vector2, gloss := 0.0) -> void:
		var cols := PackedColorArray()
		for q in poly:
			var d := (q - at) / radius
			var l := minf(d.length(), 1.0)
			var dir := d.normalized()
			cols.append(lit(base, Vector3(dir.x * l, dir.y * l, sqrt(1.0 - l * l) + 0.15).normalized(), gloss))
		fill_colors(poly, cols)

	## A soft-edged glaze, full at the middle and gone at the edge: shadows,
	## highlights and warmth laid over the forms.
	func soft(at: Vector2, rx: float, ry: float, col: Color, angle := 0.0) -> void:
		var steps := [Vector2(0.4, 0.85), Vector2(0.72, 0.42), Vector2(1.0, 0.0)]
		var n := 20
		var start := vert(at, col)
		for st: Vector2 in steps:
			for i in n:
				var a := TAU * i / n
				vert(at + Vector2(cos(a) * rx * st.x, sin(a) * ry * st.x).rotated(angle), Color(col, col.a * st.y))
		for i in n:
			indices.append_array([start, start + 1 + i, start + 1 + (i + 1) % n])
		for k in 2:
			var a := start + 1 + k * n
			var b := a + n
			for i in n:
				var j := (i + 1) % n
				indices.append_array([a + i, b + i, b + j, a + i, b + j, a + j])

	## A line along `curve` from width w0 and colour c0 to w1 and c1; `swell`
	## makes it thickest in the middle and fine at both ends, like a lock of
	## hair. Lines finer than a pixel fade instead of thinning.
	func stroke(curve: PackedVector2Array, w0: float, w1: float, c0: Color, c1: Color, swell := false) -> void:
		var n := curve.size()
		if n < 2:
			return
		var start := points.size()
		var f := px()
		for i in n:
			var t := float(i) / (n - 1)
			var tan := (curve[mini(i + 1, n - 1)] - curve[maxi(i - 1, 0)]).normalized()
			var nrm := Vector2(-tan.y, tan.x)
			var w := lerpf(w0, w1, t) * 0.5
			if swell:
				w *= 0.2 + 0.8 * sin(PI * minf(t * 1.15, 1.0))
			var c := c0.lerp(c1, t)
			if w * 2.0 < f:
				c.a *= w * 2.0 / f
				w = f * 0.5
			var p := curve[i]
			vert(p + nrm * (w + f * 0.7), Color(c, 0.0))
			vert(p + nrm * w * 0.5, c)
			vert(p - nrm * w * 0.5, c)
			vert(p - nrm * (w + f * 0.7), Color(c, 0.0))
		for i in n - 1:
			var a := start + i * 4
			var b := a + 4
			for k in 3:
				indices.append_array([a + k, b + k, b + k + 1, a + k, b + k + 1, a + k + 1])

	## A pixel-wide fade out from the edge of `poly`, whose corners are the
	## vertices from `base` on.
	func _rim(poly: PackedVector2Array, base: int, feather: float) -> void:
		var n := poly.size()
		var area := 0.0
		for i in n:
			var a := poly[i]
			var b := poly[(i + 1) % n]
			area += a.x * b.y - b.x * a.y
		var sgn := 1.0 if area > 0.0 else -1.0
		var w := feather * px()
		var outer := points.size()
		for i in n:
			var p := poly[i]
			var e1 := (p - poly[(i - 1 + n) % n]).normalized()
			var e2 := (poly[(i + 1) % n] - p).normalized()
			var nrm := (Vector2(e1.y, -e1.x) + Vector2(e2.y, -e2.x)).normalized() * sgn
			points.append(origin + (p + nrm * w) * unit)
			colors.append(Color(colors[base + i], 0.0))
		for i in n:
			var j := (i + 1) % n
			indices.append_array([base + i, base + j, outer + j, base + i, outer + j, outer + i])

	func mesh() -> ArrayMesh:
		var m := ArrayMesh.new()
		if indices.is_empty():
			return m
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = points
		arr[Mesh.ARRAY_COLOR] = colors
		arr[Mesh.ARRAY_INDEX] = indices
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		return m

## A cubic curve from a to d through handles b and c, as n + 1 points.
static func _bez(a: Vector2, b: Vector2, c: Vector2, d: Vector2, n := 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var u := 1.0 - t
		out.append(a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t)
	return out

static func _oval(at: Vector2, rx: float, ry: float, n := 24, angle := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	return pts

## A warm shadow tone of a colour, for glazes.
static func _shade(c: Color, k := 1.0) -> Color:
	return c.lerp(Color(c.r * 0.45, c.g * 0.32, c.b * 0.34), k)

## The head's outline for each kind: a skull and jaw in human proportions, a
## rounder vanara head, or a bird's narrow crown.
static func _skull(kind: StringName) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 48
	for i in n:
		var a := TAU * i / n
		var x := cos(a)
		var y := sin(a)
		var sx := signf(x) * pow(absf(x), 0.85)
		match kind:
			&"vanara":
				if y < 0.0:
					pts.append(Vector2(0.8 * sx, 0.92 * y))
				else:
					pts.append(Vector2(0.8 * sx * (1.0 - 0.18 * pow(y, 3.0)), 1.04 * y))
			&"bird":
				pts.append(Vector2(0.62 * sx * (1.0 - 0.25 * maxf(y, 0.0)), -0.1 + (0.78 if y < 0.0 else 0.66) * y))
			_:
				if y < 0.0:
					pts.append(Vector2(0.78 * signf(x) * pow(absf(x), 0.9), 0.98 * y))
				else:
					pts.append(Vector2(0.78 * signf(x) * pow(absf(x), 0.75) * (1.0 - 0.25 * pow(y, 3.0)), 1.12 * y))
	return pts

## The hair a face wears: long, jata (a knot on top), short or bald; and a
## beard. Read from the look's body until the look names its own (Story 26.2).
static func hair_of(c: Character) -> Dictionary:
	var style := hair_style(c)
	var cut := &"short"
	match style:
		&"long", &"side_part":
			cut = &"long"
		&"bun", &"twin_buns", &"topknot":
			cut = &"jata"
		&"bald_beard":
			cut = &"bald"
	return {"cut": cut, "beard": style == &"bald_beard"}

## The still layers of `c`'s face at `s` px: back (hair behind), body (neck,
## shoulders, clothes), head (skull, face, hair), jaw (beard; it drops as the
## mouth opens), front (moustache, locks, headwear) and held (things on the
## shoulder), each an ArrayMesh in pixels, plus `parts`, what was painted.
static func paint(c: Character, s: float, dead: bool) -> Dictionary:
	var at := Vector2(s * 0.5, s * (0.5 + HEAD_Y))
	var r := s * HEAD
	var layers := {}
	for k in [&"back", &"body", &"head", &"jaw", &"front", &"held"]:
		layers[k] = Paint.new(at, r, dead)
	var pal := palette(c)
	var kind := head_kind(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c.id)
	match kind:
		&"bird":
			_paint_bird(layers, pal, rng)
		&"vanara":
			_paint_body(layers.body, pal, pal.hair)
			_paint_vanara(layers, pal, rng)
		_:
			_paint_body(layers.body, pal, pal.skin)
			_paint_human(layers, pal, hair_of(c), rng)
	var out := {"parts": PackedStringArray()}
	for k in layers:
		out[k] = layers[k].mesh()
		out.parts.append_array(layers[k].parts)
	return out

## Neck, shoulders and chest in `skin` (fur for a vanara), under a draped
## cloth in the look's top colour with a border in its accessory colour.
static func _paint_body(p: Paint, pal: Dictionary, skin: Color) -> void:
	# The neck, a lit column with its right side in shadow.
	var neck := PackedVector2Array([Vector2(-0.36, 0.5), Vector2(0.36, 0.5), Vector2(0.44, 1.9), Vector2(-0.44, 1.9)])
	p.dome(Vector2(-0.12, 1.2), neck, skin, 0.9, 0.0, 3)
	p.soft(Vector2(0.06, 1.12), 0.5, 0.26, Color(_shade(skin), 0.75))
	# Chest and shoulders.
	var torso := _shoulders(1.0)
	p.dome(Vector2(-0.5, 2.5), torso, skin, 0.55, 0.05, 3)
	for side: float in [-1.0, 1.0]:
		# Collarbones catch the light.
		p.soft(Vector2(side * 0.55, 1.86), 0.3, 0.05, Color(skin.lightened(0.25), 0.3), side * -0.15)
		p.soft(Vector2(side * 0.55, 1.94), 0.3, 0.04, Color(_shade(skin), 0.3), side * -0.15)
	# The cloth over both shoulders, open in a V at the chest.
	var cloth: Color = pal.top
	var border: Color = pal.accessory
	for side: float in [-1.0, 1.0]:
		var drape := PackedVector2Array()
		drape.append_array(_bez(Vector2(side * 0.5, 1.68), Vector2(side * 1.1, 1.72), Vector2(side * 1.8, 1.86), Vector2(side * 2.1, 2.16), 6))
		drape.append(Vector2(side * SIDE, BOTTOM))
		drape.append(Vector2(side * 0.2, BOTTOM))
		drape.append_array(_bez(Vector2(side * 0.2, BOTTOM), Vector2(side * 0.5, 2.5), Vector2(side * 0.75, 2.1), Vector2(side * 0.62, 1.74), 6))
		if side > 0.0:
			drape.reverse()
		p.shaded(drape, cloth, Vector2(side * 1.2 - 0.3, 2.3), Vector2(1.3, 0.9), 0.08)
		# Folds running down from the shoulder.
		for k in 4:
			var x0 := side * (0.9 + 0.3 * k)
			p.stroke(_bez(Vector2(x0, 1.72 + 0.05 * k), Vector2(x0 - side * 0.15, 2.2), Vector2(x0 - side * 0.35, 2.5), Vector2(x0 - side * 0.5, BOTTOM), 6), 0.07, 0.12, Color(_shade(cloth), 0.0), Color(_shade(cloth), 0.45), true)
			p.stroke(_bez(Vector2(x0 + side * 0.08, 1.72 + 0.05 * k), Vector2(x0 - side * 0.07, 2.2), Vector2(x0 - side * 0.27, 2.5), Vector2(x0 - side * 0.42, BOTTOM), 6), 0.04, 0.06, Color(cloth.lightened(0.3), 0.0), Color(cloth.lightened(0.3), 0.35), true)
		# A woven border along the open edge.
		p.stroke(_bez(Vector2(side * 0.2, BOTTOM), Vector2(side * 0.5, 2.5), Vector2(side * 0.75, 2.1), Vector2(side * 0.6, 1.68), 8), 0.13, 0.11, Paint.lit(border, Vector3(-side * 0.3, 0.0, 1.0).normalized(), 0.6), Paint.lit(border, Vector3(-0.3, -0.5, 1.0).normalized(), 0.6))
	p.parts.append("shoulders")

## The outline of the shoulders and chest down to the portrait's bottom edge,
## `wide` times as broad: sloping from the neck, rounding over each shoulder.
static func _shoulders(wide: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(Vector2(-SIDE * wide, BOTTOM))
	out.append_array(_bez(Vector2(-SIDE * wide, BOTTOM), Vector2(-2.2 * wide, 2.15), Vector2(-1.9 * wide, 1.85), Vector2(-1.2 * wide, 1.76), 8))
	out.append_array(_bez(Vector2(-1.1 * wide, 1.74), Vector2(-0.6, 1.66), Vector2(-0.4, 1.56), Vector2(0.0, 1.58), 6))
	out.append_array(_bez(Vector2(0.0, 1.58), Vector2(0.4, 1.56), Vector2(0.6, 1.66), Vector2(1.1 * wide, 1.74), 6))
	out.append_array(_bez(Vector2(1.2 * wide, 1.76), Vector2(1.9 * wide, 1.85), Vector2(2.2 * wide, 2.15), Vector2(SIDE * wide, BOTTOM), 8))
	return out

## Locks of hair: `count` strokes from roots to tips picked by `at(t)`, each
## a little lighter or darker than `base`, brighter toward the light.
static func _locks(p: Paint, count: int, at: Callable, base: Color, width: float, rng: RandomNumberGenerator) -> void:
	for i in count:
		var t := (i + rng.randf()) / count
		var pts: Array = at.call(t, rng)
		var tip: Vector2 = pts[3]
		var light := clampf(0.5 - tip.x * 0.25 - tip.y * 0.15 + rng.randf_range(-0.3, 0.3), 0.0, 1.0)
		var col := _shade(base, 0.55).lerp(base.lightened(0.35), light)
		p.stroke(_bez(pts[0], pts[1], pts[2], pts[3], 10), width * rng.randf_range(0.6, 1.3), width * 0.3, Color(col, 0.0), Color(col, 0.85), true)

static func _paint_human(layers: Dictionary, pal: Dictionary, hair: Dictionary, rng: RandomNumberGenerator) -> void:
	var skin: Color = pal.skin
	var hc: Color = pal.hair
	var p: Paint = layers.head
	var cut: StringName = hair.cut
	if cut == &"long":
		_paint_long_hair(layers.back, hc, rng)
	# Ears, half behind the skull's edge.
	for side: float in [-1.0, 1.0]:
		var e := Vector2(side * 0.77, 0.24)
		p.dome(e, _oval(e, 0.13, 0.27, 20), skin, 0.7)
		p.soft(e + Vector2(side * 0.02, 0.0), 0.06, 0.16, Color(_shade(skin), 0.7))
	p.dome(Vector2(-0.1, -0.05), _skull(&"human"), skin, 0.75, 0.04, 6)
	p.parts.append("ears")
	_paint_human_face(p, skin)
	if cut != &"bald":
		_paint_hair_cap(p, hc, cut, rng)
	if cut == &"jata":
		_paint_knot(layers.front, hc, rng)
	if hair.beard:
		_paint_beard(layers.jaw, layers.front, hc, 0.5, rng)

## The modelling of a human face: forehead and cheekbones in the light, the
## right side and the eye sockets in shadow, a nose, the folds by the mouth,
## the chin.
static func _paint_human_face(p: Paint, skin: Color) -> void:
	var sh := _shade(skin)
	var hi := skin.lightened(0.3)
	p.soft(Vector2(0.6, 0.35), 0.32, 0.75, Color(sh, 0.4), 0.1)
	p.soft(Vector2(-0.25, -0.5), 0.38, 0.24, Color(hi, 0.35))
	p.soft(Vector2(-0.42, 0.34), 0.2, 0.13, Color(hi, 0.35))
	p.soft(Vector2(0.44, 0.34), 0.18, 0.11, Color(hi, 0.12))
	for side: float in [-1.0, 1.0]:
		p.soft(Vector2(side * 0.42, 0.45), 0.22, 0.15, Color(0.85, 0.32, 0.28, 0.12))
		p.soft(Vector2(side * EYE_X, EYE_DROP - 0.01), 0.24, 0.15, Color(sh, 0.45 if side > 0.0 else 0.3))
		p.soft(Vector2(side * 0.15, 0.06), 0.08, 0.1, Color(sh, 0.4))
		p.soft(Vector2(side * 0.3, -0.12), 0.2, 0.06, Color(hi, 0.3 if side < 0.0 else 0.1))
		p.stroke(_bez(Vector2(side * 0.17, 0.53), Vector2(side * 0.25, 0.6), Vector2(side * 0.29, 0.7), Vector2(side * 0.3, 0.82)), 0.035, 0.015, Color(sh, 0.3), Color(sh, 0.0))
	# The nose: a lit bridge, the shadow side, wings, a rounded tip, nostrils.
	p.stroke(_bez(Vector2(-0.035, 0.02), Vector2(-0.04, 0.16), Vector2(-0.045, 0.3), Vector2(-0.035, 0.43)), 0.04, 0.07, Color(hi, 0.0), Color(hi, 0.5))
	p.soft(Vector2(0.09, 0.3), 0.07, 0.22, Color(sh, 0.55), 0.12)
	for side: float in [-1.0, 1.0]:
		p.dome(Vector2(side * 0.11, 0.5), _oval(Vector2(side * 0.11, 0.5), 0.075, 0.06, 16), skin.darkened(0.04 if side < 0.0 else 0.14), 0.6)
	p.dome(Vector2(-0.02, 0.46), _oval(Vector2(0.0, 0.47), 0.095, 0.085, 18), skin, 0.8, 0.35)
	for side: float in [-1.0, 1.0]:
		p.fill(_oval(Vector2(side * 0.06, 0.545), 0.035, 0.015, 12, -side * 0.35), _shade(skin, 1.0).darkened(0.35))
	p.soft(Vector2(0.02, 0.57), 0.14, 0.04, Color(sh, 0.45))
	p.parts.append("nose")
	# The philtrum, the chin and the shadow under the lower lip.
	p.soft(Vector2(0.0, 0.64), 0.04, 0.06, Color(sh, 0.18))
	p.soft(Vector2(0.0, 0.92), 0.15, 0.05, Color(sh, 0.4))
	p.soft(Vector2(-0.05, 1.03), 0.17, 0.08, Color(hi, 0.3))
	p.parts.append("shading")

## Hair over the top of the head down to the hairline, parted in the middle
## and laid down in locks to the temples; a jata is drawn up to the crown.
static func _paint_hair_cap(p: Paint, hc: Color, cut: StringName, rng: RandomNumberGenerator) -> void:
	var cap := PackedVector2Array()
	for i in 21:
		var x := lerpf(-0.86, 0.86, i / 20.0)
		cap.append(Vector2(x, hairline(x) if absf(x) < 0.84 else 0.32))
	for i in 21:
		var a := lerpf(0.0, PI, i / 20.0)
		cap.append(Vector2(0.86 * cos(a), 0.32 - 1.36 * sin(a)))
	p.shaded(cap, hc, Vector2(0.0, -0.3), Vector2(0.95, 1.1), 0.25)
	p.soft(Vector2(-0.35, -0.82), 0.3, 0.12, Color(hc.lightened(0.4), 0.3), -0.5)
	var up := cut == &"jata"
	_locks(p, 70, func(t: float, g: RandomNumberGenerator) -> Array:
		var side := -1.0 if t < 0.5 else 1.0
		var k := absf(t - 0.5) * 2.0
		var x := side * lerpf(0.02, 0.84, k)
		var tip := Vector2(x, hairline(x) if absf(x) < 0.84 else 0.32) + Vector2(g.randf_range(-0.03, 0.03), -0.02)
		var root := Vector2(side * 0.02, -1.0) if not up else Vector2(side * 0.05, -1.08)
		var bend := Vector2(side * (0.55 + 0.25 * k), -0.95 + 0.25 * k)
		return [root, root.lerp(bend, 0.6), bend.lerp(tip, 0.4), tip], hc, 0.035, rng)
	p.parts.append("hair")

## Long hair down behind the shoulders, in locks.
static func _paint_long_hair(p: Paint, hc: Color, rng: RandomNumberGenerator) -> void:
	var mass := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI * 0.97, PI * 2.03, i / 16.0)
		mass.append(Vector2(0.95 * cos(a), -0.08 + 1.08 * sin(a)))
	mass.append_array(PackedVector2Array([Vector2(1.05, 0.6), Vector2(1.18, 1.4), Vector2(1.12, 2.05), Vector2(0.75, 2.2), Vector2(-0.75, 2.2), Vector2(-1.12, 2.05), Vector2(-1.18, 1.4), Vector2(-1.05, 0.6)]))
	p.dome(Vector2(-0.3, 0.2), mass, hc, 0.5, 0.15)
	_locks(p, 80, func(t: float, g: RandomNumberGenerator) -> Array:
		var side := -1.0 if t < 0.5 else 1.0
		var k := absf(t - 0.5) * 2.0
		var root := Vector2(side * 0.75 * k, -1.05 + 0.4 * k * k)
		var tip := Vector2(side * g.randf_range(0.75, 1.15), g.randf_range(1.7, 2.18))
		return [root, root + Vector2(side * 0.35, 0.4), tip + Vector2(side * 0.1, -0.8), tip], hc, 0.05, rng)
	p.parts.append("hair")

## The jata: hair gathered and coiled up on the crown.
static func _paint_knot(p: Paint, hc: Color, rng: RandomNumberGenerator) -> void:
	var at := Vector2(0.0, -1.12)
	p.dome(at + Vector2(-0.08, -0.06), _oval(at, 0.3, 0.26, 24), hc, 0.9, 0.3)
	for i in 9:
		var y := lerpf(-0.18, 0.18, i / 8.0)
		var w := sqrt(maxf(1.0 - pow(y / 0.26, 2.0), 0.0)) * 0.29
		var col := hc.lightened(0.25) if i % 2 == 0 else _shade(hc, 0.6)
		p.stroke(_bez(at + Vector2(-w, y + 0.03), at + Vector2(-w * 0.3, y - 0.05), at + Vector2(w * 0.3, y - 0.05), at + Vector2(w, y + 0.03), 8), 0.03, 0.03, Color(col, 0.0), Color(col, 0.7), true)
	p.parts.append("hair")

## A full beard round the jaw (in the jaw layer, so it drops as the mouth
## opens) and a moustache over the upper lip (in front). `length` past the chin.
static func _paint_beard(jaw: Paint, front: Paint, hc: Color, length: float, rng: RandomNumberGenerator) -> void:
	var beard := PackedVector2Array()
	beard.append_array(_bez(Vector2(-0.8, 0.15), Vector2(-0.85, 0.8), Vector2(-0.5, 1.2 + length), Vector2(0.0, 1.25 + length), 10))
	beard.append_array(_bez(Vector2(0.0, 1.25 + length), Vector2(0.5, 1.2 + length), Vector2(0.85, 0.8), Vector2(0.8, 0.15), 10))
	beard.append_array(PackedVector2Array([Vector2(0.74, 0.4), Vector2(0.6, 0.6), Vector2(0.4, 0.72), Vector2(0.3, 0.86), Vector2(0.18, 0.95), Vector2(0.0, 0.97), Vector2(-0.18, 0.95), Vector2(-0.3, 0.86), Vector2(-0.4, 0.72), Vector2(-0.6, 0.6), Vector2(-0.74, 0.4)]))
	jaw.shaded(beard, hc, Vector2(-0.1, 0.8), Vector2(1.0, 0.9), 0.1)
	_locks(jaw, 60, func(t: float, g: RandomNumberGenerator) -> Array:
		var x := lerpf(-0.75, 0.75, t)
		var root := Vector2(x, 0.35 + 0.55 * (1.0 - absf(x) / 0.75))
		var tip := Vector2(x * 0.55 + g.randf_range(-0.05, 0.05), 1.0 + length * (1.0 - absf(x)) + 0.2 * (1.0 - absf(x)))
		return [root, root + Vector2(0.0, 0.3), tip + Vector2(x * 0.2, -0.2), tip], hc, 0.05, rng)
	jaw.parts.append("beard")
	var lip := PackedVector2Array()
	lip.append_array(_bez(Vector2(-0.4, 0.92), Vector2(-0.34, 0.7), Vector2(-0.2, 0.58), Vector2(0.0, 0.6), 8))
	lip.append_array(_bez(Vector2(0.0, 0.6), Vector2(0.2, 0.58), Vector2(0.34, 0.7), Vector2(0.4, 0.92), 8))
	lip.append_array(_bez(Vector2(0.4, 0.92), Vector2(0.3, 0.76), Vector2(0.15, 0.7), Vector2(0.0, 0.71), 8))
	lip.append_array(_bez(Vector2(0.0, 0.71), Vector2(-0.15, 0.7), Vector2(-0.3, 0.76), Vector2(-0.4, 0.92), 8))
	front.shaded(lip, hc, Vector2(-0.1, 0.62), Vector2(0.45, 0.3), 0.2)
	for side: float in [-1.0, 1.0]:
		_locks(front, 12, func(t: float, g: RandomNumberGenerator) -> Array:
			var root := Vector2(side * lerpf(0.03, 0.2, t), 0.62)
			return [root, root + Vector2(side * 0.12, -0.01), Vector2(side * (0.28 + 0.06 * t), 0.7), Vector2(side * (0.34 + 0.05 * t), 0.88)], hc, 0.03, rng)
	front.parts.append("moustache")

## A vanara: a ruff of fur round a bare face, a heavy brow, a pale muzzle with
## a broad nose, and fur over the shoulders.
static func _paint_vanara(layers: Dictionary, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	var p: Paint = layers.head
	var fur: Color = pal.hair
	var face: Color = pal.skin
	var muzzle := face.lerp(Color(0.96, 0.86, 0.72), 0.45)
	# The ruff, lock by lock round the skull.
	var ruff := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var k := 1.0 if i % 2 == 0 else 1.1
		ruff.append(Vector2(cos(a) * 1.02 * k, -0.02 + sin(a) * 1.12 * k))
	p.dome(Vector2(-0.15, -0.1), ruff, fur, 0.6, 0.12)
	_locks(p, 130, func(t: float, g: RandomNumberGenerator) -> Array:
		var a := TAU * t
		var dir := Vector2(cos(a), sin(a))
		var root := dir * Vector2(0.62, 0.75)
		var tip := dir * Vector2(1.08, 1.2) * g.randf_range(0.95, 1.08)
		var swirl := dir.orthogonal() * 0.12
		return [root, root.lerp(tip, 0.35) + swirl, root.lerp(tip, 0.7) + swirl, tip], fur, 0.07, rng)
	for side: float in [-1.0, 1.0]:
		var e := Vector2(side * 0.84, 0.1)
		p.dome(e, _oval(e, 0.17, 0.22, 20), face.darkened(0.08), 0.7)
		p.soft(e + Vector2(side * 0.02, 0.01), 0.08, 0.12, Color(_shade(face), 0.75))
	# The bare face: a heart shape from the brow down round the muzzle.
	var mask := PackedVector2Array()
	mask.append_array(_bez(Vector2(0.0, -0.34), Vector2(0.25, -0.5), Vector2(0.62, -0.42), Vector2(0.66, -0.05), 8))
	mask.append_array(_bez(Vector2(0.66, -0.05), Vector2(0.7, 0.35), Vector2(0.52, 0.55), Vector2(0.48, 0.75), 6))
	mask.append_array(_bez(Vector2(0.48, 0.75), Vector2(0.45, 1.05), Vector2(-0.45, 1.05), Vector2(-0.48, 0.75), 10))
	mask.append_array(_bez(Vector2(-0.48, 0.75), Vector2(-0.52, 0.55), Vector2(-0.7, 0.35), Vector2(-0.66, -0.05), 6))
	mask.append_array(_bez(Vector2(-0.66, -0.05), Vector2(-0.62, -0.42), Vector2(-0.25, -0.5), Vector2(0.0, -0.34), 8))
	p.dome(Vector2(-0.12, 0.15), mask, face, 0.7, 0.05, 5)
	var sh := _shade(face)
	for side: float in [-1.0, 1.0]:
		p.soft(Vector2(side * 0.27, 0.07), 0.24, 0.15, Color(sh, 0.55 if side > 0.0 else 0.4))
		p.soft(Vector2(side * 0.48, 0.38), 0.16, 0.14, Color(0.8, 0.3, 0.25, 0.12))
	# The brow ridge, lit on top, throwing the eyes into shade.
	var ridge := PackedVector2Array()
	ridge.append_array(_bez(Vector2(-0.62, 0.0), Vector2(-0.5, -0.24), Vector2(-0.15, -0.22), Vector2(0.0, -0.14), 8))
	ridge.append_array(_bez(Vector2(0.0, -0.14), Vector2(0.15, -0.22), Vector2(0.5, -0.24), Vector2(0.62, 0.0), 8))
	ridge.append_array(_bez(Vector2(0.62, 0.0), Vector2(0.45, -0.1), Vector2(0.1, -0.08), Vector2(0.0, -0.05), 6))
	ridge.append_array(_bez(Vector2(0.0, -0.05), Vector2(-0.1, -0.08), Vector2(-0.45, -0.1), Vector2(-0.62, 0.0), 6))
	p.dome(Vector2(-0.2, -0.17), ridge, face, 0.9, 0.2, 3)
	p.soft(Vector2(0.0, -0.04), 0.55, 0.05, Color(sh, 0.3))
	# The muzzle and the broad nose at its top.
	p.dome(Vector2(-0.08, 0.6), _oval(Vector2(0.0, 0.66), 0.45, 0.36, 32), muzzle, 0.85, 0.15)
	p.soft(Vector2(0.28, 0.72), 0.2, 0.28, Color(_shade(muzzle), 0.35))
	p.dome(Vector2(-0.02, 0.4), _oval(Vector2(0.0, 0.42), 0.16, 0.09, 20), face.darkened(0.1), 0.8, 0.35)
	for side: float in [-1.0, 1.0]:
		p.fill(_oval(Vector2(side * 0.07, 0.46), 0.04, 0.018, 12, side * 0.5), sh.darkened(0.5))
		p.stroke(_bez(Vector2(side * 0.14, 0.52), Vector2(side * 0.24, 0.58), Vector2(side * 0.3, 0.68), Vector2(side * 0.32, 0.78)), 0.03, 0.012, Color(_shade(muzzle), 0.4), Color(_shade(muzzle), 0.0))
	p.soft(Vector2(0.0, 0.6), 0.035, 0.08, Color(_shade(muzzle), 0.3))
	p.soft(Vector2(-0.12, 0.98), 0.18, 0.06, Color(muzzle.lightened(0.3), 0.3))
	p.parts.append_array(["ears", "nose", "muzzle", "shading"])
	# Fur over the forehead and cheeks, over the mask's edge.
	_locks(p, 60, func(t: float, g: RandomNumberGenerator) -> Array:
		var side := -1.0 if t < 0.5 else 1.0
		var k := absf(t - 0.5) * 2.0
		var a := lerpf(-PI * 0.5, PI * 0.45, k)
		var root := Vector2(side * cos(a) * 0.9, sin(a) * 1.0 - 0.05)
		var tip := Vector2(side * cos(a) * 0.62, sin(a) * 0.72 - 0.08) + Vector2(g.randf_range(-0.03, 0.03), 0.04)
		return [root, root.lerp(tip, 0.3), root.lerp(tip, 0.7) + Vector2(0, 0.04), tip], fur, 0.05, rng)
	p.parts.append("fur")

## A great bird: dark wings over the shoulders, a pale ruff, a feathered
## neck, a bare head with fine down, and a hooked beak (in front).
static func _paint_bird(layers: Dictionary, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	var body: Paint = layers.body
	var wing: Color = pal.top
	var plume: Color = pal.hair
	var head: Color = pal.skin
	# Folded wings over the shoulders, in rows of feathers.
	var torso := PackedVector2Array()
	for i in 15:
		var u := lerpf(-1.0, 1.0, i / 14.0)
		torso.append(Vector2(u * SIDE, 1.5 + 0.5 * pow(absf(u), 1.4)))
	torso.append(Vector2(SIDE, BOTTOM))
	torso.append(Vector2(-SIDE, BOTTOM))
	body.dome(Vector2(-0.6, 2.4), torso, wing, 0.55, 0.05, 3)
	for row in 5:
		for i in 13:
			var u := lerpf(-1.0, 1.0, (i + 0.5 * (row % 2)) / 12.0)
			var at := Vector2(u * SIDE, 1.62 + 0.5 * pow(absf(u), 1.4) + row * 0.24)
			if at.y > BOTTOM - 0.05:
				continue
			var f := PackedVector2Array(_bez(at + Vector2(-0.2, -0.12), at + Vector2(-0.2, 0.15), at + Vector2(0.2, 0.15), at + Vector2(0.2, -0.12), 8))
			body.fill(f, Color(Paint.lit(wing, Vector3(-u * 0.5, 0.0, 1.0).normalized()).lightened(0.1 * rng.randf()), 0.9))
			body.stroke(f, 0.03, 0.03, Color(wing.lightened(0.35), 0.0), Color(wing.lightened(0.35), 0.5))
	# The neck in feathers, the ruff at its foot.
	var neck := PackedVector2Array([Vector2(-0.4, 0.2), Vector2(0.4, 0.2), Vector2(0.55, 1.6), Vector2(-0.55, 1.6)])
	body.dome(Vector2(-0.15, 0.9), neck, plume, 0.85, 0.05, 3)
	_locks(body, 40, func(t: float, g: RandomNumberGenerator) -> Array:
		var x := lerpf(-0.42, 0.42, t)
		var y := g.randf_range(0.4, 1.3)
		return [Vector2(x, y), Vector2(x, y + 0.06), Vector2(x * 1.05, y + 0.14), Vector2(x * 1.1, y + 0.22)], plume, 0.05, rng)
	body.soft(Vector2(0.05, 0.62), 0.45, 0.2, Color(_shade(plume), 0.7))
	var ruff: Color = (pal.detail as Color).lerp(Color(0.95, 0.92, 0.84), 0.6)
	var collar := PackedVector2Array()
	for i in 36:
		var a := TAU * i / 36.0
		var k := 1.0 if i % 2 == 0 else 1.14
		collar.append(Vector2(cos(a) * 1.05 * k, 1.62 + sin(a) * 0.32 * k))
	body.dome(Vector2(-0.3, 1.5), collar, ruff, 0.7, 0.1)
	_locks(body, 70, func(t: float, g: RandomNumberGenerator) -> Array:
		var a := TAU * t
		var root := Vector2(cos(a) * 0.55, 1.62 + sin(a) * 0.12)
		var tip := Vector2(cos(a) * 1.15, 1.62 + sin(a) * 0.38) * Vector2(g.randf_range(0.9, 1.05), 1.0)
		return [root, root.lerp(tip, 0.4) + Vector2(0, -0.05), root.lerp(tip, 0.8), tip], ruff, 0.07, rng)
	body.parts.append_array(["shoulders", "feathers"])
	# The head: a bare crown with fine down, darker toward the back.
	var p: Paint = layers.head
	p.dome(Vector2(-0.15, -0.25), _skull(&"bird"), head, 0.8, 0.08, 5)
	_locks(p, 60, func(t: float, g: RandomNumberGenerator) -> Array:
		var a := lerpf(PI * 0.95, PI * 2.05, t)
		var root := Vector2(cos(a) * 0.55, -0.1 + sin(a) * 0.7)
		var tip := root * g.randf_range(0.75, 0.9) + Vector2(0, -0.02)
		return [root, root.lerp(tip, 0.3), root.lerp(tip, 0.7), tip], plume.lerp(head, 0.4), 0.025, rng)
	var sh := _shade(head)
	p.soft(Vector2(0.4, 0.2), 0.25, 0.5, Color(sh, 0.4))
	for side: float in [-1.0, 1.0]:
		p.soft(Vector2(side * 0.34, -0.02), 0.2, 0.16, Color(sh, 0.5))
	p.parts.append("shading")
	# The beak: a waxy cere with its nostrils, then the horn of the upper
	# mandible hooking down to a dark tip, lit along its ridge.
	var f: Paint = layers.front
	var horn := Color(0.86, 0.78, 0.55)
	var beak := PackedVector2Array()
	beak.append_array(_bez(Vector2(-0.2, 0.2), Vector2(-0.22, 0.5), Vector2(-0.14, 0.75), Vector2(0.0, 0.95), 10))
	beak.append_array(_bez(Vector2(0.0, 0.95), Vector2(0.14, 0.75), Vector2(0.22, 0.5), Vector2(0.2, 0.2), 10))
	f.dome(Vector2(-0.06, 0.4), beak, horn, 0.9, 0.5)
	f.soft(Vector2(0.0, 0.86), 0.09, 0.1, Color(0.18, 0.15, 0.13, 0.9))
	f.soft(Vector2(0.11, 0.55), 0.07, 0.25, Color(_shade(horn), 0.5))
	f.stroke(_bez(Vector2(-0.04, 0.25), Vector2(-0.05, 0.5), Vector2(-0.04, 0.7), Vector2(-0.01, 0.85)), 0.03, 0.02, Color(1, 1, 0.95, 0.6), Color(1, 1, 0.95, 0.0))
	var cere := Color(0.9, 0.68, 0.3)
	f.dome(Vector2(-0.04, 0.15), _oval(Vector2(0.0, 0.18), 0.23, 0.08, 20), cere, 0.8, 0.3)
	for side: float in [-1.0, 1.0]:
		f.fill(_oval(Vector2(side * 0.08, 0.19), 0.035, 0.012, 10, side * 0.3), Color(0.15, 0.1, 0.06))
	f.parts.append_array(["beak", "nose"])

## The parts of the face that move: eyes (whites, irises, lids and lashes),
## brows and the mouth, in pose `p`. `shine` puts one small catchlight in each eye.
static func paint_face(p: Paint, c: Character, pz: Dictionary, shine: bool) -> void:
	var kind := head_kind(c)
	var pal := palette(c)
	for side: float in [-1.0, 1.0]:
		_paint_eye(p, kind, side, pz, shine)
		_paint_brow(p, kind, side, pz, pal)
	_paint_mouth_of(p, c, pz)

## The mouth for each kind of head: lips, a vanara's on the muzzle, a bird's gape.
static func _paint_mouth_of(p: Paint, c: Character, pz: Dictionary) -> void:
	var pal := palette(c)
	match head_kind(c):
		&"bird":
			_paint_beak_gape(p, pz)
		&"vanara":
			_paint_mouth(p, pz, pal.skin.lerp(Color(0.96, 0.86, 0.72), 0.45), Vector2(0.0, 0.8), 1.15, 0.5)
		_:
			_paint_mouth(p, pz, pal.skin, Vector2(0.0, 0.76), 1.0, 1.0)

## Where each kind's eye sits and its half size; the iris's radius per half width; and its colour.
const EYES := {
	&"human": {"at": Vector2(EYE_X, EYE_DROP), "half": EYE, "iris": 0.44, "color": Color(0.3, 0.18, 0.1)},
	&"vanara": {"at": Vector2(0.27, 0.07), "half": Vector2(0.125, 0.075), "iris": 0.56, "color": Color(0.62, 0.38, 0.12)},
	&"bird": {"at": Vector2(0.33, -0.02), "half": Vector2(0.115, 0.1), "iris": 0.8, "color": Color(0.88, 0.55, 0.12)},
}

static func _paint_eye(p: Paint, kind: StringName, side: float, pz: Dictionary, shine: bool) -> void:
	var e: Dictionary = EYES[kind]
	var es := float(pz.eye_scale)
	var at: Vector2 = e.at * Vector2(side, 1.0)
	var half: Vector2 = (e.half as Vector2) * Vector2(1.0 + (es - 1.0) * 0.3, es)
	var lid := float(pz.lid)
	var squint := float(pz.squint)
	var bird := kind == &"bird"
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var crease := PackedVector2Array()
	var shut := PackedVector2Array()
	for i in 15:
		var u := lerpf(-1.0, 1.0, i / 14.0)
		var x := at.x + side * u * half.x
		var arc := sqrt(1.0 - u * u) if bird else pow(1.0 - u * u, 0.75)
		var base := at.y + (0.0 if bird else -u * half.y * 0.12)
		var up := base - half.y * arc * (1.0 if bird else 1.0 - 0.12 * u)
		var lo := base + half.y * arc * (1.0 if bird else 0.75 * (1.0 + 0.1 * u))
		var meet := base + half.y * 0.45 * arc
		lo = lerpf(lo, meet - half.y * 0.15 * arc, squint * 0.7)
		upper.append(Vector2(x, minf(lerpf(meet, up, lid), lo)))
		lower.append(Vector2(x, lo))
		crease.append(Vector2(x, up - half.y * (0.45 + 0.1 * lid) * arc))
		shut.append(Vector2(x, meet))
	var lash := Color(0.08, 0.05, 0.04)
	if lid <= 0.02:
		p.stroke(shut, 0.022, 0.03, Color(lash, 0.8), Color(lash, 0.9))
		p.stroke(crease, 0.015, 0.015, Color(0.3, 0.15, 0.1, 0.0), Color(0.3, 0.15, 0.1, 0.25), true)
		p.parts.append("lids")
		return
	var open := upper.duplicate()
	var back := lower.duplicate()
	back.reverse()
	open.append_array(back)
	var white := Color(0.9, 0.86, 0.8) if not bird else Color(0.2, 0.12, 0.06)
	var cols := PackedColorArray()
	for i in open.size():
		var u := absf((open[i].x - at.x) / half.x)
		cols.append(white.darkened(0.3 * u * u + (0.12 if i < 15 else 0.0)))
	p.fill_colors(open, cols, 0.6)
	# The iris and pupil, clipped by the lids, darker at the rim and lit low on
	# the side away from the light.
	var ir := half.x * float(e.iris)
	var ic := pupil_center(at, half, pz.pupil)
	var iris: Color = e.color
	for layer: Array in [[ir, iris.darkened(0.5), Vector2.ZERO], [ir * 0.84, iris, Vector2.ZERO], [ir * 0.55, iris.lightened(0.35), Vector2(0.18, 0.28) * ir], [ir * 0.38 if not bird else ir * 0.45, Color(0.04, 0.03, 0.03), Vector2.ZERO]]:
		for part in Geometry2D.intersect_polygons(_oval(ic + (layer[2] as Vector2), layer[0], layer[0], 20), open):
			p.fill(part, layer[1], 0.6)
	p.parts.append("iris")
	# The lid's shadow on the eyeball, the lash line, and the lashes.
	p.stroke(upper, half.y * 0.5, half.y * 0.5, Color(0.15, 0.06, 0.04, 0.3), Color(0.15, 0.06, 0.04, 0.3))
	if shine:
		var glint := ic + Vector2(-0.35, -0.4) * ir
		if Geometry2D.is_point_in_polygon(glint, open):
			p.soft(glint, ir * 0.22, ir * 0.22, Color(1, 1, 1, 0.9))
			p.parts.append("catchlight")
	var inner := upper.slice(0, 1)
	p.stroke(upper, 0.016, 0.03, Color(lash, 0.75), Color(lash, 0.95))
	if not bird:
		for i in range(7, 15, 2):
			var a := upper[i]
			var out := Vector2(side * (0.015 + 0.01 * (i - 7)), -0.035)
			p.stroke(PackedVector2Array([a, a + out * 0.6 + Vector2(0, -0.005), a + out]), 0.012, 0.002, Color(lash, 0.8), Color(lash, 0.2))
		p.soft(inner[0] + Vector2(side * 0.012, 0.004), 0.018, 0.012, Color(0.85, 0.45, 0.42, 0.7))
	p.stroke(lower, 0.012, 0.012, Color(0.35, 0.18, 0.12, 0.35), Color(0.35, 0.18, 0.12, 0.5))
	p.stroke(crease, 0.016, 0.016, Color(0.3, 0.15, 0.1, 0.0), Color(0.3, 0.15, 0.1, 0.3), true)
	p.parts.append("lids")

static func _paint_brow(p: Paint, kind: StringName, side: float, pz: Dictionary, pal: Dictionary) -> void:
	var e: Dictionary = EYES[kind]
	var at: Vector2 = e.at * Vector2(side, 1.0)
	var half: Vector2 = e.half
	var mid := at + Vector2(side * 0.02, -half.y * float(pz.eye_scale) - BROW_GAP - float(pz.brow_height) * BROW_LIFT)
	var col: Color = _shade(pal.hair, 0.3)
	var thick := 0.065
	if kind == &"vanara":
		col = _shade(pal.hair, 0.5)
		thick = 0.08
		mid.y -= 0.06
	elif kind == &"bird":
		col = _shade(pal.hair, 0.7)
		thick = 0.11
		mid.y -= 0.03
	var pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		var q := Vector2(side * lerpf(-BROW_REACH, BROW_REACH, t), -BROW_ARCH * sin(PI * pow(t, 0.8)))
		pts.append(mid + q.rotated(-side * float(pz.brow_angle)))
	p.stroke(pts, thick, thick * 0.35, Color(col, 0.85), Color(col, 0.6))
	for i in 10:
		var t := (i + 0.5) / 10.0
		var a := pts[int(t * 8.0)]
		var dir := (pts[mini(int(t * 8.0) + 1, 8)] - pts[maxi(int(t * 8.0) - 1, 0)]).normalized()
		var lift := Vector2(dir.y, -dir.x) * side * -0.02
		p.stroke(PackedVector2Array([a + Vector2(0, thick * 0.3), a + dir * 0.03 + lift, a + dir * 0.06 + lift * 1.5]), 0.012, 0.004, Color(col.lightened(0.15), 0.8), Color(col, 0.3))
	p.parts.append("brows")

## Lips at `m`: the upper lip in shade, the lower one catching the light; open,
## the mouth shows its dark inside and the upper teeth. `wide` scales the width
## and `full` the lips' thickness.
static func _paint_mouth(p: Paint, pz: Dictionary, skin: Color, m: Vector2, wide: float, full: float) -> void:
	var hw := (0.15 + 0.16 * float(pz.mouth_width)) * wide
	var curve := float(pz.mouth_curve) * 0.07
	var gap := float(pz.mouth_open) * 0.16
	var lip := skin.lerp(Color(0.62, 0.26, 0.26), 0.4)
	var line := PackedVector2Array()
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var upper_edge := PackedVector2Array()
	var lower_edge := PackedVector2Array()
	for i in 13:
		var u := lerpf(-1.0, 1.0, i / 12.0)
		var bulge := 1.0 - u * u
		var y := m.y - curve * (u * u) + curve * 0.3
		line.append(Vector2(u * hw, y))
		top.append(Vector2(u * hw, y - gap * 0.3 * bulge))
		bottom.append(Vector2(u * hw, y + gap * 0.7 * sqrt(bulge)))
		var bow := 0.012 * (1.0 - absf(sin(u * PI * 1.6))) if absf(u) < 0.35 else 0.0
		upper_edge.append(Vector2(u * hw * 1.02, y - gap * 0.3 * bulge - (0.05 * full * pow(bulge, 0.6) - bow)))
		lower_edge.append(Vector2(u * hw * 0.98, y + gap * 0.7 * sqrt(bulge) + 0.065 * full * pow(bulge, 0.7)))
	if gap > 0.006:
		var inside := top.duplicate()
		var b := bottom.duplicate()
		b.reverse()
		inside.append_array(b)
		p.fill(inside, Color(0.22, 0.07, 0.07), 0.6)
		var teeth := PackedVector2Array()
		for i in range(2, 11):
			teeth.append(top[i])
		for i in range(10, 1, -1):
			teeth.append(top[i] + Vector2(0, minf(gap * 0.35, 0.035) * (1.0 - pow(lerpf(-1.0, 1.0, i / 12.0), 2.0))))
		for part in Geometry2D.intersect_polygons(teeth, inside):
			p.fill(part, Color(0.9, 0.86, 0.78), 0.5)
		p.soft(Vector2(m.x + hw * 0.1, bottom[6].y - gap * 0.15), hw * 0.45, gap * 0.25, Color(0.65, 0.25, 0.28, 0.8))
	var up := upper_edge.duplicate()
	var t2 := top.duplicate()
	t2.reverse()
	up.append_array(t2)
	var cols := PackedColorArray()
	for q in up:
		cols.append(_shade(lip, 0.25 + 0.3 * clampf(q.x / hw * 0.5 + 0.5, 0.0, 1.0)))
	p.fill_colors(up, cols)
	var lo := bottom.duplicate()
	var l2 := lower_edge.duplicate()
	l2.reverse()
	lo.append_array(l2)
	cols = PackedColorArray()
	for q in lo:
		cols.append(_shade(lip, 0.25 * clampf(q.x / hw * 0.5 + 0.5, 0.0, 1.0)))
	p.fill_colors(lo, cols)
	p.soft(Vector2(-hw * 0.25, lower_edge[6].y - 0.03 * full), hw * 0.3, 0.015 * full + 0.004, Color(1.0, 0.92, 0.85, 0.35))
	p.stroke(line if gap <= 0.006 else top, 0.016, 0.016, Color(_shade(lip, 1.0).darkened(0.4), 0.7), Color(_shade(lip, 1.0).darkened(0.4), 0.7))
	for side: float in [-1.0, 1.0]:
		p.soft(line[0 if side < 0.0 else 12] + Vector2(side * 0.015, 0.0), 0.03, 0.025, Color(_shade(skin), 0.45))
	p.parts.append("lips")

## A bird's gape: the lower mandible under the beak, dropping as it opens, the
## corners of the gape lifting for a smile and falling for a frown.
static func _paint_beak_gape(p: Paint, pz: Dictionary) -> void:
	var gap := float(pz.mouth_open) * 0.2
	var curve := float(pz.mouth_curve) * 0.08
	var horn := Color(0.8, 0.72, 0.5)
	if gap > 0.01:
		var inside := PackedVector2Array([Vector2(-0.2, 0.32 - curve), Vector2(0.2, 0.32 - curve), Vector2(0.12, 0.7 + gap), Vector2(-0.12, 0.7 + gap)])
		p.fill(inside, Color(0.35, 0.12, 0.12))
	var jaw := PackedVector2Array()
	jaw.append_array(_bez(Vector2(-0.21, 0.3 - curve), Vector2(-0.2, 0.55 + gap), Vector2(-0.1, 0.72 + gap), Vector2(0.0, 0.78 + gap), 8))
	jaw.append_array(_bez(Vector2(0.0, 0.78 + gap), Vector2(0.1, 0.72 + gap), Vector2(0.2, 0.55 + gap), Vector2(0.21, 0.3 - curve), 8))
	p.dome(Vector2(-0.05, 0.55 + gap), jaw, horn, 0.8, 0.3, 3)
	for side: float in [-1.0, 1.0]:
		p.soft(Vector2(side * 0.21, 0.3 - curve), 0.05, 0.04, Color(0.3, 0.15, 0.08, 0.6))
	p.parts.append("lips")
