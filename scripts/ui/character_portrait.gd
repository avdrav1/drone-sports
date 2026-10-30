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
# Story 26.2: each face is its namesake from the epics: the look's headwear,
# hair, beard, held object and marks, painted in the look's colours.

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
						_paint_brow(pt, kind, side, q, palette(character), _look_of(character).build)
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
	## Applied to every point before it is placed, e.g. to fit a tall crown.
	var warp := Transform2D.IDENTITY

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
		points.append(origin + warp * p * unit)
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
			points.append(origin + warp * (p + nrm * w) * unit)
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
				pts.append(Vector2(0.74 * sx * (1.0 - 0.35 * maxf(y, 0.0) * maxf(y, 0.0)), -0.1 + (0.82 if y < 0.0 else 0.95) * y))
			_:
				if y < 0.0:
					pts.append(Vector2(0.78 * signf(x) * pow(absf(x), 0.9), 0.98 * y))
				else:
					pts.append(Vector2(0.78 * signf(x) * pow(absf(x), 0.75) * (1.0 - 0.25 * pow(y, 3.0)), 1.12 * y))
	return pts

## The hair a face wears: long, curls (to the jaw), jata (a knot on top), short or bald; and a
## beard (empty, moustache or beard). The look's own hair_cut and beard win;
## without them, read from the look's body.
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
	var beard := &"beard" if style == &"bald_beard" else &""
	if c.look and (c.look.hair_cut != &"" or c.look.beard != &""):
		cut = c.look.hair_cut if c.look.hair_cut != &"" else cut
		beard = c.look.beard
	return {"cut": cut, "beard": beard}

## The character's look, or a plain one when they have none.
static func _look_of(c: Character) -> CrewLook:
	return c.look if c.look else CrewLook.new()

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
	var look := _look_of(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c.id)
	match kind:
		&"bird":
			_paint_bird(layers, pal, rng)
		&"vanara":
			_paint_body(layers.body, pal, pal.hair, look)
			_paint_vanara(layers, pal, look, rng)
		_:
			_paint_body(layers.body, pal, pal.skin, look)
			_paint_human(layers, pal, hair_of(c), look, rng)
	_paint_iconography(layers, pal, look, kind, rng)
	var out := {"parts": PackedStringArray()}
	for k in layers:
		out[k] = layers[k].mesh()
		out.parts.append_array(layers[k].parts)
	return out

## Neck, shoulders and chest in `skin` (fur for a vanara), under a draped
## cloth in the look's top colour with a border in its accessory colour.
static func _paint_body(p: Paint, pal: Dictionary, skin: Color, look: CrewLook) -> void:
	# The neck, a lit column with its right side in shadow.
	var nw := look.build
	var neck := PackedVector2Array([Vector2(-0.36 * nw, 0.5), Vector2(0.36 * nw, 0.5), Vector2(0.46 * nw, 1.9), Vector2(-0.46 * nw, 1.9)])
	p.dome(Vector2(-0.12, 1.2), neck, skin, 0.9, 0.0, 3)
	p.soft(Vector2(0.06, 1.12), 0.5, 0.26, Color(_shade(skin), 0.75))
	# Chest and shoulders.
	var torso := _shoulders(1.0)
	p.dome(Vector2(-0.5, 2.5), torso, skin, 0.55, 0.05, 3)
	for side: float in [-1.0, 1.0]:
		# Collarbones catch the light.
		p.soft(Vector2(side * 0.55, 1.86), 0.3, 0.05, Color(skin.lightened(0.25), 0.3), side * -0.15)
		p.soft(Vector2(side * 0.55, 1.94), 0.3, 0.04, Color(_shade(skin), 0.3), side * -0.15)
	if &"armour" in look.marks:
		_paint_armour(p, pal)
		return
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

static func _paint_human(layers: Dictionary, pal: Dictionary, hair: Dictionary, look: CrewLook, rng: RandomNumberGenerator) -> void:
	var skin: Color = pal.skin
	var hc: Color = pal.hair
	var p: Paint = layers.head
	var cut: StringName = hair.cut
	if cut == &"long":
		_paint_long_hair(layers.back, hc, rng)
	elif cut == &"curls":
		_paint_curls(layers.back, hc, rng)
	# Ears, half behind the skull's edge.
	for side: float in [-1.0, 1.0]:
		var e := Vector2(side * 0.77, 0.24)
		p.dome(e, _oval(e, 0.13, 0.27, 20), skin, 0.7)
		p.soft(e + Vector2(side * 0.02, 0.0), 0.06, 0.16, Color(_shade(skin), 0.7))
	var skull := _skull(&"human")
	for i in skull.size():
		# A broad build widens the jaw more than the crown.
		skull[i].x *= lerpf(1.0, look.build, clampf(skull[i].y + 0.3, 0.0, 1.0))
	p.dome(Vector2(-0.1, -0.05), skull, skin, 0.75, 0.04, 6)
	p.parts.append("ears")
	_paint_human_face(p, skin)
	if look.age > 0.0:
		_paint_age(p, skin, look.age)
	if cut != &"bald":
		_paint_hair_cap(p, hc, cut, rng)
	if cut == &"jata":
		_paint_knot(layers.front, hc, rng)
	if hair.beard != &"":
		_paint_beard(layers.jaw, layers.front, hc, 0.3 + look.age * 0.7, hair.beard == &"beard", rng)

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

## Curls to the jaw, showing beside the face and the neck.
static func _paint_curls(p: Paint, hc: Color, rng: RandomNumberGenerator) -> void:
	var mass := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI * 0.97, PI * 2.03, i / 16.0)
		mass.append(Vector2(0.95 * cos(a), -0.08 + 1.08 * sin(a)))
	for i in 13:
		var t := i / 12.0
		var y := lerpf(0.2, 1.0, t)
		mass.append(Vector2(1.0 + 0.08 * sin(t * 12.0), y))
	for i in 13:
		var t := 1.0 - i / 12.0
		var y := lerpf(0.2, 1.0, t)
		mass.append(Vector2(-1.0 - 0.08 * sin(t * 12.0), y))
	p.shaded(mass, hc, Vector2(-0.2, -0.2), Vector2(1.1, 1.2), 0.2)
	for i in 34:
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector2(side * rng.randf_range(0.82, 1.02), rng.randf_range(0.0, 0.95))
		var curl := PackedVector2Array()
		for k in 9:
			var a := k * 0.8
			curl.append(at + Vector2(cos(a) * side, sin(a)) * 0.07 * (1.0 - k / 12.0))
		var col := hc.lightened(0.3) if i % 3 == 0 else _shade(hc, 0.5)
		p.stroke(curl, 0.025, 0.015, Color(col, 0.8), Color(col, 0.3))
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
static func _paint_beard(jaw: Paint, front: Paint, hc: Color, length: float, full: bool, rng: RandomNumberGenerator) -> void:
	if full:
		_paint_full_beard(jaw, hc, length, rng)
	_paint_moustache(front, hc, rng)

static func _paint_full_beard(jaw: Paint, hc: Color, length: float, rng: RandomNumberGenerator) -> void:
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

## A full moustache over the upper lip, drooping past the corners of the mouth.
static func _paint_moustache(front: Paint, hc: Color, rng: RandomNumberGenerator) -> void:
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
static func _paint_vanara(layers: Dictionary, pal: Dictionary, look: CrewLook, rng: RandomNumberGenerator) -> void:
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

## A great bird: dark wings folded over the shoulders in rows of feathers, a
## pale ruff, a broad pale head with fine feathers, and a heavy hooked beak.
static func _paint_bird(layers: Dictionary, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	var body: Paint = layers.body
	var wing: Color = pal.top
	var plume: Color = pal.hair
	var head: Color = pal.skin
	var ruff := head.lightened(0.35)
	body.dome(Vector2(-0.6, 2.3), _shoulders(1.0), wing, 0.55, 0.05, 3)
	# Feathers from the top row down, each row overlapping the one above.
	for row in range(7, -1, -1):
		var n := 13
		for i in n:
			var u := lerpf(-1.0, 1.0, (i + 0.5 * (row % 2)) / (n - 1))
			var at := Vector2(u * 2.05, 1.6 + 0.16 * row + 0.32 * pow(absf(u), 1.5))
			var down := Vector2(u * 0.3, 1.0).normalized()
			var size := rng.randf_range(0.3, 0.38)
			if absf(at.x) > SIDE - 0.15 or at.y + size > BOTTOM:
				continue
			var tip := at + down * size
			var side := Vector2(-down.y, down.x) * size * 0.45
			var f := PackedVector2Array(_bez(at - side, at - side * 1.05 + down * size * 0.7, tip - side * 0.7, tip, 6))
			f.append_array(_bez(tip, tip + side * 0.7, at + side * 1.05 + down * size * 0.7, at + side, 6))
			var col := Paint.lit(wing, Vector3(u * 0.5, -0.2 + 0.05 * row, 0.8).normalized()).lightened(rng.randf() * 0.12)
			body.shaded(f, col, at + down * size * 0.3 + Vector2(-0.08, -0.08), Vector2(size * 0.6, size * 0.8), 0.1)
			body.stroke(PackedVector2Array([at + down * 0.04, tip - down * 0.06]), 0.018, 0.008, Color(col.lightened(0.35), 0.5), Color(col.lightened(0.35), 0.1))
			body.stroke(f.slice(6, 13), 0.03, 0.02, Color(col.lightened(0.3), 0.0), Color(col.lightened(0.3), 0.45))
	# The neck in feathers, the ruff at its foot.
	var neck := PackedVector2Array([Vector2(-0.5, 0.3), Vector2(0.5, 0.3), Vector2(0.62, 1.4), Vector2(-0.62, 1.4)])
	body.dome(Vector2(-0.15, 0.9), neck, plume, 0.85, 0.05, 3)
	_locks(body, 50, func(t: float, g: RandomNumberGenerator) -> Array:
		var x := lerpf(-0.5, 0.5, t)
		var y := g.randf_range(0.5, 1.3)
		return [Vector2(x, y), Vector2(x, y + 0.06), Vector2(x * 1.05, y + 0.14), Vector2(x * 1.1, y + 0.24)], plume, 0.06, rng)
	body.soft(Vector2(0.05, 0.72), 0.55, 0.25, Color(_shade(plume), 0.7))
	var collar := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		var k := 1.0 + 0.05 * sin(a * 11.0)
		collar.append(Vector2(cos(a) * 1.15 * k, 1.42 + sin(a) * 0.3 * k))
	body.dome(Vector2(-0.3, 1.32), collar, ruff, 0.7, 0.1)
	_locks(body, 110, func(t: float, g: RandomNumberGenerator) -> Array:
		var a := TAU * t
		var root := Vector2(cos(a) * 0.5, 1.37 + sin(a) * 0.1)
		var tip := Vector2(cos(a) * 1.25, 1.44 + sin(a) * 0.36) * Vector2(g.randf_range(0.88, 1.05), 1.0)
		return [root, root.lerp(tip, 0.4) + Vector2(0, -0.06), root.lerp(tip, 0.8) + Vector2(0, 0.02), tip], ruff, 0.08, rng)
	body.parts.append_array(["shoulders", "feathers"])
	# The head: broad and pale, fine feathers laid back from the beak.
	var p: Paint = layers.head
	p.dome(Vector2(-0.18, -0.3), _skull(&"bird"), head, 0.8, 0.08, 5)
	_locks(p, 110, func(t: float, g: RandomNumberGenerator) -> Array:
		var side := -1.0 if t < 0.5 else 1.0
		var k := absf(t - 0.5) * 2.0
		var a := lerpf(-PI * 0.5, PI * 0.35, k) + g.randf_range(-0.05, 0.05)
		var root := Vector2(side * cos(a) * 0.3, sin(a) * 0.5 - 0.1)
		var tip := Vector2(side * cos(a) * 0.74, sin(a) * 0.8 - 0.1) * g.randf_range(0.92, 1.0)
		return [root, root.lerp(tip, 0.3), root.lerp(tip, 0.7), tip], head.darkened(0.12), 0.035, rng)
	var sh := _shade(head)
	p.soft(Vector2(0.42, 0.15), 0.28, 0.55, Color(sh, 0.45))
	for side: float in [-1.0, 1.0]:
		p.soft(Vector2(side * 0.36, -0.03), 0.2, 0.15, Color(sh, 0.55))
		# A dark stripe from the eye back along the head, as raptors have.
		p.stroke(_bez(Vector2(side * 0.46, -0.0), Vector2(side * 0.56, 0.05), Vector2(side * 0.62, 0.12), Vector2(side * 0.68, 0.22)), 0.07, 0.02, Color(plume, 0.6), Color(plume, 0.0))
	p.parts.append("shading")
	# The beak: a waxy cere with its nostrils, then the horn of the upper
	# mandible, broad at the base, hooking down to a dark tip, lit along its ridge.
	var f: Paint = layers.front
	var horn := Color(0.88, 0.8, 0.56)
	var beak := PackedVector2Array()
	beak.append_array(_bez(Vector2(-0.27, 0.16), Vector2(-0.3, 0.45), Vector2(-0.18, 0.78), Vector2(0.0, 1.02), 12))
	beak.append_array(_bez(Vector2(0.0, 1.02), Vector2(0.18, 0.78), Vector2(0.3, 0.45), Vector2(0.27, 0.16), 12))
	f.dome(Vector2(-0.08, 0.38), beak, horn, 0.9, 0.55)
	f.soft(Vector2(0.0, 0.9), 0.11, 0.14, Color(0.2, 0.17, 0.15, 0.95))
	f.soft(Vector2(0.0, 0.97), 0.05, 0.05, Color(0.12, 0.1, 0.09, 1.0))
	f.soft(Vector2(0.14, 0.55), 0.09, 0.3, Color(_shade(horn), 0.55))
	f.stroke(_bez(Vector2(-0.06, 0.22), Vector2(-0.07, 0.5), Vector2(-0.05, 0.72), Vector2(-0.01, 0.9)), 0.04, 0.02, Color(1, 1, 0.95, 0.65), Color(1, 1, 0.95, 0.0))
	var cere := Color(0.92, 0.7, 0.28)
	var c := PackedVector2Array(_bez(Vector2(-0.3, 0.2), Vector2(-0.25, 0.04), Vector2(0.25, 0.04), Vector2(0.3, 0.2), 10))
	c.append_array(_bez(Vector2(0.3, 0.2), Vector2(0.2, 0.26), Vector2(-0.2, 0.26), Vector2(-0.3, 0.2), 10))
	f.shaded(c, cere, Vector2(-0.08, 0.1), Vector2(0.35, 0.2), 0.4)
	for side: float in [-1.0, 1.0]:
		f.fill(_oval(Vector2(side * 0.1, 0.17), 0.045, 0.016, 10, side * 0.3), Color(0.15, 0.1, 0.06))
	f.parts.append_array(["beak", "nose"])

## The parts of the face that move: eyes (whites, irises, lids and lashes),
## brows and the mouth, in pose `p`. `shine` puts one small catchlight in each eye.
static func paint_face(p: Paint, c: Character, pz: Dictionary, shine: bool) -> void:
	var kind := head_kind(c)
	var pal := palette(c)
	for side: float in [-1.0, 1.0]:
		_paint_eye(p, kind, side, pz, shine)
		_paint_brow(p, kind, side, pz, pal, _look_of(c).build)
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
		var up := base - half.y * arc * (0.6 if bird else 1.0 - 0.12 * u)
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

static func _paint_brow(p: Paint, kind: StringName, side: float, pz: Dictionary, pal: Dictionary, build := 1.0) -> void:
	var e: Dictionary = EYES[kind]
	var at: Vector2 = e.at * Vector2(side, 1.0)
	var half: Vector2 = e.half
	var mid := at + Vector2(side * 0.02, -half.y * float(pz.eye_scale) - BROW_GAP - float(pz.brow_height) * BROW_LIFT)
	var col: Color = _shade(pal.hair, 0.3)
	var thick := 0.065 * build * build
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


# --- Iconography (Story 26.2) -------------------------------------------------

## Where each headwear's lowest edge sits over the brow, per head radius (the
## brows always stay below it).
const HEADWEAR_BOTTOM := {&"crown": -0.48, &"helmet": -0.46, &"turban": -0.5, &"band": -0.52, &"crest": -0.7}
## Wood for a bow, and the colours of the healer's herb.
const BOW_WOOD := Color(0.32, 0.17, 0.09)
const LEAF := Color(0.28, 0.55, 0.22)
const BLOOM := Color(1.0, 0.85, 0.35)
const STONE := Color(0.62, 0.58, 0.52)
const VERMILION := Color(0.86, 0.2, 0.1)

## The look's headwear, held object and marks, each painted in its layer.
static func _paint_iconography(layers: Dictionary, pal: Dictionary, look: CrewLook, kind: StringName, rng: RandomNumberGenerator) -> void:
	var gold: Color = pal.accessory
	var gem: Color = pal.detail
	var front: Paint = layers.front
	if kind == &"vanara" and look.beard == &"beard":
		_paint_goatee(layers.jaw, pal.hair, rng)
	for m in look.marks:
		match m:
			&"tilak":
				_paint_tilak(front, kind)
			&"tripundra":
				_paint_tripundra(front)
			&"earrings":
				_paint_earrings(front, kind, gold, gem)
			&"necklace":
				_paint_necklace(layers.body, gold, gem)
			&"beads":
				_paint_beads(layers.body)
			&"sacred_thread":
				_paint_thread(layers.body)
			&"sash":
				_paint_sash(layers.body, gem)
			&"neck_ring":
				_paint_neck_ring(layers.body, gold, gem)
	match look.headwear:
		&"crown":
			_paint_crown(front, gold, gem)
		&"helmet":
			_paint_helmet(front, gold, gem)
		&"turban":
			_paint_turban(front, gold, gem, rng)
		&"band":
			_paint_band(front, gold, gem)
		&"crest":
			_paint_crest(layers.back, pal.hair, rng)
	var side := signf(look.held_side) if look.held_side != 0.0 else -1.0
	match look.held:
		&"bow":
			_paint_bow(layers.back, layers.held, side, gold)
		&"gada":
			_paint_gada(layers.held, side, gold, gem)
		&"chakra":
			_paint_chakra(layers.held, gold, gem)
		&"stone":
			_paint_stone(layers.held, side, rng)
		&"herb":
			_paint_herb(layers.held, side, rng)
	# Glow last, over everything on the face.
	if &"glow" in look.marks:
		_paint_glow(front)

## Lines of a life: across the forehead, at the corners of the eyes, under
## them, and deeper by the mouth.
static func _paint_age(p: Paint, skin: Color, age: float) -> void:
	var sh := Color(_shade(skin), 0.3 * age)
	var hi := Color(skin.lightened(0.3), 0.25 * age)
	for k in 3:
		var y := -0.3 - 0.1 * k
		p.stroke(_bez(Vector2(-0.42, y + 0.03), Vector2(-0.15, y - 0.02), Vector2(0.15, y - 0.02), Vector2(0.42, y + 0.03)), 0.018, 0.018, Color(sh, 0.0), sh, true)
		p.stroke(_bez(Vector2(-0.42, y + 0.05), Vector2(-0.15, y), Vector2(0.15, y), Vector2(0.42, y + 0.05)), 0.014, 0.014, Color(hi, 0.0), hi, true)
	for side: float in [-1.0, 1.0]:
		for k in 3:
			var a := Vector2(side * (EYE_X + EYE.x + 0.02), EYE_DROP - 0.03 + 0.04 * k)
			p.stroke(PackedVector2Array([a, a + Vector2(side * 0.07, (k - 1) * 0.03)]), 0.012, 0.004, sh, Color(sh, 0.0))
		p.stroke(_bez(Vector2(side * 0.2, 0.17), Vector2(side * 0.27, 0.22), Vector2(side * 0.37, 0.22), Vector2(side * 0.45, 0.16)), 0.02, 0.02, Color(sh, 0.0), Color(_shade(skin), 0.45 * age), true)
		p.stroke(_bez(Vector2(side * 0.18, 0.5), Vector2(side * 0.28, 0.6), Vector2(side * 0.32, 0.72), Vector2(side * 0.33, 0.86)), 0.03, 0.012, Color(_shade(skin), 0.4 * age), Color(_shade(skin), 0.0))
	p.parts.append("age")

## A breastplate over the chest and plates over the shoulders, in the look's
## top colour as burnished metal, trimmed in its accessory colour.
static func _paint_armour(p: Paint, pal: Dictionary) -> void:
	var steel: Color = pal.top
	var trim: Color = pal.accessory
	for side: float in [-1.0, 1.0]:
		for k in 3:
			var plate := PackedVector2Array()
			var y := 1.75 + k * 0.22
			plate.append_array(_bez(Vector2(side * (0.8 + 0.1 * k), y), Vector2(side * 1.5, y - 0.2), Vector2(side * 2.1, y + 0.05), Vector2(side * (2.25 - 0.02 * k), y + 0.5), 8))
			plate.append_array(_bez(Vector2(side * (2.25 - 0.02 * k), y + 0.5), Vector2(side * 2.0, y + 0.3), Vector2(side * 1.5, y + 0.12), Vector2(side * (0.85 + 0.1 * k), y + 0.2), 8))
			p.shaded(plate, steel.darkened(0.06 * k), Vector2(side * 1.4 - 0.3, y - 0.2), Vector2(1.1, 0.6), 0.9)
			p.stroke(plate.slice(0, 9), 0.035, 0.035, Paint.lit(trim, Vector3(-0.3, -0.6, 0.8).normalized(), 0.8), Paint.lit(trim, Vector3(side * 0.6, 0.0, 0.8).normalized(), 0.8))
	var chest := PackedVector2Array()
	chest.append_array(_bez(Vector2(-1.25, BOTTOM), Vector2(-1.3, 2.3), Vector2(-0.9, 1.85), Vector2(-0.45, 1.74), 8))
	chest.append_array(_bez(Vector2(-0.45, 1.74), Vector2(-0.2, 1.9), Vector2(0.2, 1.9), Vector2(0.45, 1.74), 6))
	chest.append_array(_bez(Vector2(0.45, 1.74), Vector2(0.9, 1.85), Vector2(1.3, 2.3), Vector2(1.25, BOTTOM), 8))
	p.shaded(chest, steel, Vector2(-0.4, 2.0), Vector2(1.5, 1.0), 0.9)
	p.stroke(chest.slice(8, 15), 0.06, 0.06, Paint.lit(trim, Vector3(0, -0.5, 0.9).normalized(), 0.9), Paint.lit(trim, Vector3(0.3, -0.5, 0.9).normalized(), 0.9))
	# The ridge down the middle, lit on its left.
	p.stroke(PackedVector2Array([Vector2(-0.02, 1.9), Vector2(-0.02, BOTTOM)]), 0.05, 0.05, Color(steel.lightened(0.4), 0.5), Color(steel.lightened(0.4), 0.2))
	p.parts.append_array(["shoulders", "armour"])

## The kirita-mukut: a tall gold crown in tiers over a band at the brow, set
## with gems, with fans over the ears.
static func _paint_crown(p: Paint, gold: Color, gem: Color) -> void:
	var b: float = HEADWEAR_BOTTOM[&"crown"]
	# Drawn tall, then fitted under the portrait's top edge.
	p.warp = Transform2D(0.0, Vector2(1.0, 0.86), 0.0, Vector2(0.0, b * 0.14))
	var body := PackedVector2Array([Vector2(-0.84, b - 0.06), Vector2(-0.8, -0.92), Vector2(-0.66, -0.98), Vector2(-0.62, -1.24), Vector2(-0.46, -1.3), Vector2(-0.4, -1.52),
		Vector2(-0.12, -1.74), Vector2(0.0, -1.84), Vector2(0.12, -1.74), Vector2(0.4, -1.52), Vector2(0.46, -1.3), Vector2(0.62, -1.24), Vector2(0.66, -0.98), Vector2(0.8, -0.92), Vector2(0.84, b - 0.06)])
	for i in 9:
		var x := lerpf(0.84, -0.84, i / 8.0)
		body.append(Vector2(x, b + 0.14 * x * x - 0.06))
	for side: float in [-1.0, 1.0]:
		var fan := PackedVector2Array()
		for i in 9:
			var a := lerpf(-PI * 0.75, PI * 0.25, i / 8.0)
			fan.append(Vector2(side * 0.86, -0.62) + Vector2(side * cos(a), sin(a)) * 0.24)
		fan.append(Vector2(side * 0.78, -0.5))
		p.shaded(fan, gold.darkened(0.08), Vector2(side * 0.8 - 0.1, -0.75), Vector2(0.3, 0.3), 0.8)
		for i in 4:
			var a := lerpf(-PI * 0.7, PI * 0.15, i / 3.0)
			p.stroke(PackedVector2Array([Vector2(side * 0.84, -0.6), Vector2(side * 0.84, -0.6) + Vector2(side * cos(a), sin(a)) * 0.2]), 0.02, 0.01, Color(_shade(gold), 0.7), Color(_shade(gold), 0.2))
	p.shaded(body, gold, Vector2(-0.3, -1.1), Vector2(1.0, 0.9), 0.9)
	# Rims at each tier, beaded.
	for t in [[b - 0.04, 0.84], [-0.95, 0.72], [-1.27, 0.54], [-1.5, 0.38]]:
		var y: float = t[0]
		var w: float = t[1]
		var rim := _bez(Vector2(-w, y + 0.08 * w), Vector2(-w * 0.4, y - 0.03), Vector2(w * 0.4, y - 0.03), Vector2(w, y + 0.08 * w), 10)
		p.stroke(rim, 0.05, 0.05, Color(_shade(gold, 0.8), 0.8), Color(_shade(gold, 0.8), 0.8))
		for i in range(1, 10):
			p.soft(rim[i] + Vector2(0, -0.02), 0.018, 0.018, Color(1.0, 0.95, 0.75, 0.8))
	# Lotus-petal work between the rims.
	for t in [[-1.12, 0.6, 5], [-1.4, 0.42, 3]]:
		for i in t[2]:
			var x := lerpf(-t[1], t[1], (i + 0.5) / t[2]) * 0.85
			p.stroke(_bez(Vector2(x - 0.06, t[0] + 0.1), Vector2(x - 0.06, t[0] - 0.02), Vector2(x + 0.06, t[0] - 0.02), Vector2(x + 0.06, t[0] + 0.1), 6), 0.025, 0.025, Color(_shade(gold, 0.7), 0.7), Color(_shade(gold, 0.7), 0.7))
	_gem(p, Vector2(0.0, b - 0.12), 0.1, gem)
	_gem(p, Vector2(0.0, -1.12), 0.07, gem)
	for side: float in [-1.0, 1.0]:
		_gem(p, Vector2(side * 0.45, b - 0.1 + 0.03), 0.05, gem)
	p.dome(Vector2(-0.02, -1.9), _oval(Vector2(0.0, -1.88), 0.07, 0.08, 14), gold, 0.9, 0.9)
	p.warp = Transform2D.IDENTITY
	p.parts.append("crown")

## A cut gem: a dark rim, its colour, and a glint.
static func _gem(p: Paint, at: Vector2, r: float, col: Color) -> void:
	p.fill(_oval(at, r * 1.25, r * 1.25, 16), _shade(Color(0.85, 0.65, 0.3), 0.6))
	p.dome(at + Vector2(r * 0.2, r * 0.25), _oval(at, r, r, 16), col, 0.9, 0.0)
	p.soft(at + Vector2(-r * 0.35, -r * 0.35), r * 0.35, r * 0.35, Color(1, 1, 1, 0.85))

## A warrior's helmet: a steel dome with a gold rim and ridge, a finial and a
## red plume, and mail over the ears.
static func _paint_helmet(p: Paint, steel: Color, trim: Color) -> void:
	var b: float = HEADWEAR_BOTTOM[&"helmet"]
	for side: float in [-1.0, 1.0]:
		var guard := PackedVector2Array([Vector2(side * 0.72, b - 0.05), Vector2(side * 0.95, b - 0.05), Vector2(side * 1.0, 0.42), Vector2(side * 0.8, 0.5), Vector2(side * 0.72, 0.1)])
		p.shaded(guard, steel.darkened(0.12), Vector2(side * 0.85, -0.2), Vector2(0.4, 0.8), 0.5)
		for k in 6:
			var y := b + 0.12 + k * 0.15
			p.stroke(PackedVector2Array([Vector2(side * 0.74, y), Vector2(side * 0.97, y + 0.02)]), 0.025, 0.025, Color(_shade(steel), 0.7), Color(_shade(steel), 0.7))
	var dome := PackedVector2Array()
	for i in 21:
		var a := lerpf(PI, TAU, i / 20.0)
		dome.append(Vector2(cos(a) * 0.9, b - 0.05 + sin(a) * 0.82))
	for i in 9:
		var x := lerpf(0.9, -0.9, i / 8.0)
		dome.append(Vector2(x, b + 0.12 * x * x))
	p.shaded(dome, steel, Vector2(-0.3, -1.0), Vector2(0.95, 0.85), 0.95)
	var rim := PackedVector2Array()
	for i in 13:
		var x := lerpf(-0.92, 0.92, i / 12.0)
		rim.append(Vector2(x, b - 0.03 + 0.12 * x * x))
	p.stroke(rim, 0.1, 0.1, Paint.lit(trim, Vector3(-0.4, -0.4, 0.8).normalized(), 0.8), Paint.lit(trim, Vector3(0.6, -0.2, 0.7).normalized(), 0.8))
	p.stroke(_bez(Vector2(0.0, b - 0.06), Vector2(0.0, -1.0), Vector2(0.0, -1.3), Vector2(0.0, -1.42)), 0.07, 0.04, Paint.lit(trim, Vector3(-0.3, 0.0, 1.0).normalized(), 0.8), Paint.lit(trim, Vector3(-0.3, -0.6, 0.7).normalized(), 0.8))
	# The finial and its plume, sweeping back.
	p.dome(Vector2(-0.02, -1.45), _oval(Vector2(0.0, -1.44), 0.08, 0.07, 14), trim, 0.9, 0.9)
	p.stroke(PackedVector2Array([Vector2(0.0, -1.48), Vector2(0.0, -1.68)]), 0.05, 0.01, trim, trim)
	var plume := Color(0.72, 0.1, 0.1)
	for i in 9:
		var t := i / 8.0
		p.stroke(_bez(Vector2(0.0, -1.62), Vector2(0.25, -1.85 + t * 0.1), Vector2(0.55, -1.7 + t * 0.15), Vector2(0.72 + 0.1 * t, -1.35 + t * 0.2), 10), 0.07, 0.02, Color(plume.lightened(0.25 * t), 0.9), Color(plume.darkened(0.2), 0.5), true)
	p.parts.append("helmet")

## A turban wound round the head in folds, with a jewelled clasp and a plume.
static func _paint_turban(p: Paint, cloth: Color, gem: Color, rng: RandomNumberGenerator) -> void:
	var b: float = HEADWEAR_BOTTOM[&"turban"]
	var mass := PackedVector2Array()
	mass.append_array(_bez(Vector2(-0.86, b), Vector2(-1.08, -0.8), Vector2(-0.95, -1.32), Vector2(-0.35, -1.42), 10))
	mass.append_array(_bez(Vector2(-0.35, -1.42), Vector2(0.1, -1.5), Vector2(0.75, -1.45), Vector2(0.95, -1.15), 8))
	mass.append_array(_bez(Vector2(0.95, -1.15), Vector2(1.1, -0.9), Vector2(1.02, -0.6), Vector2(0.86, b), 8))
	for i in 9:
		var x := lerpf(0.86, -0.86, i / 8.0)
		mass.append(Vector2(x, b + 0.1 * x * x - 0.04 * (1.0 - x * x)))
	p.shaded(mass, cloth, Vector2(-0.3, -1.0), Vector2(1.1, 0.8), 0.15)
	# Folds wound across from lower left to upper right.
	for k in 7:
		var y0 := b - 0.02 - 0.12 * k
		var y1 := b - 0.3 - 0.13 * k
		var pts := _bez(Vector2(-0.9 + 0.03 * k, y0), Vector2(-0.3, y0 - 0.02), Vector2(0.4, y1 + 0.08), Vector2(0.98 - 0.05 * k, y1), 12)
		p.stroke(pts, 0.05, 0.08, Color(_shade(cloth), 0.5), Color(_shade(cloth), 0.25), true)
		var hi := pts.duplicate()
		for i in hi.size():
			hi[i] += Vector2(0, -0.045)
		p.stroke(hi, 0.03, 0.05, Color(cloth.lightened(0.35), 0.45), Color(cloth.lightened(0.35), 0.2), true)
	# The sarpech: a jewel at the front with a white plume rising from it.
	for i in 7:
		var t := i / 6.0
		p.stroke(_bez(Vector2(0.05, -0.92), Vector2(0.1, -1.25), Vector2(0.28 + 0.06 * t, -1.5), Vector2(0.45 + 0.1 * t, -1.66 + 0.06 * t), 10), 0.04, 0.01, Color(0.97, 0.95, 0.9, 0.9), Color(0.97, 0.95, 0.9, 0.4), true)
	p.dome(Vector2(0.0, -0.82), _oval(Vector2(0.03, -0.8), 0.13, 0.17, 18), Color(0.95, 0.75, 0.32), 0.9, 0.8)
	_gem(p, Vector2(0.03, -0.8), 0.08, gem)
	for i in 3:
		p.soft(Vector2(0.03, -0.6 + 0.0 * i) + Vector2(0, 0.05 * i), 0.025, 0.025, Color(1, 0.97, 0.9, 0.95))
	p.parts.append("turban")

## A gold band across the brow over the hair, with an ornament at the front.
static func _paint_band(p: Paint, gold: Color, gem: Color) -> void:
	var b: float = HEADWEAR_BOTTOM[&"band"]
	var band := PackedVector2Array()
	for i in 17:
		var x := lerpf(-0.86, 0.86, i / 16.0)
		band.append(Vector2(x, b - 0.1 + 0.16 * x * x))
	for i in 17:
		var x := lerpf(0.86, -0.86, i / 16.0)
		band.append(Vector2(x, b + 0.16 * x * x))
	p.shaded(band, gold, Vector2(-0.3, b - 0.3), Vector2(1.0, 0.5), 0.9)
	var leaf := PackedVector2Array(_bez(Vector2(-0.16, b - 0.04), Vector2(-0.2, b - 0.3), Vector2(-0.03, b - 0.38), Vector2(0.0, b - 0.46), 8))
	leaf.append_array(_bez(Vector2(0.0, b - 0.46), Vector2(0.03, b - 0.38), Vector2(0.2, b - 0.3), Vector2(0.16, b - 0.04), 8))
	p.shaded(leaf, gold, Vector2(-0.05, b - 0.3), Vector2(0.25, 0.3), 0.9)
	_gem(p, Vector2(0.0, b - 0.16), 0.06, gem)
	p.parts.append("band")

## A crest of long feathers sweeping up and back from a bird's crown, dark
## with pale tips.
static func _paint_crest(p: Paint, plume: Color, rng: RandomNumberGenerator) -> void:
	for i in 7:
		var t := i / 6.0
		var a := lerpf(-PI * 0.8, -PI * 0.2, t) + (t - 0.5) * 0.4
		var root := Vector2(cos(a) * 0.3, -0.7)
		var len := lerpf(0.75, 1.0, 1.0 - absf(t - 0.5) * 2.0) * rng.randf_range(0.92, 1.05)
		var dir := Vector2(cos(a), sin(a))
		var tip := root + dir * len + Vector2(signf(t - 0.5) * 0.12, 0.0)
		var nrm := Vector2(-dir.y, dir.x) * 0.14
		var f := PackedVector2Array(_bez(root - nrm * 0.5, root.lerp(tip, 0.4) - nrm, root.lerp(tip, 0.8) - nrm * 0.6, tip, 8))
		f.append_array(_bez(tip, root.lerp(tip, 0.8) + nrm * 0.6, root.lerp(tip, 0.4) + nrm, root + nrm * 0.5, 8))
		var cols := PackedColorArray()
		for q in f:
			var k := clampf((q - root).length() / len, 0.0, 1.0)
			cols.append(Paint.lit(plume.darkened(0.15), Vector3(dir.x * -0.2, -0.4, 0.8).normalized()).lerp(Color(0.9, 0.86, 0.78), smoothstep(0.82, 1.0, k)))
		p.fill_colors(f, cols)
		p.stroke(_bez(root, root.lerp(tip, 0.35), root.lerp(tip, 0.7), tip, 8), 0.015, 0.005, Color(plume.lightened(0.4), 0.6), Color(plume.lightened(0.4), 0.2))
	p.parts.append("crest")

## A vaishnava tilak: a white U from the bridge of the nose with a red line in it.
static func _paint_tilak(p: Paint, kind: StringName) -> void:
	var y0 := -0.12 if kind == &"human" else -0.2
	var top := y0 - 0.48
	for side: float in [-1.0, 1.0]:
		p.stroke(_bez(Vector2(side * 0.025, y0), Vector2(side * 0.07, y0 - 0.05), Vector2(side * 0.08, y0 - 0.2), Vector2(side * 0.085, top)), 0.03, 0.035, Color(0.97, 0.95, 0.9, 0.95), Color(0.97, 0.95, 0.9, 0.95))
	p.stroke(PackedVector2Array([Vector2(0.0, y0 - 0.06), Vector2(0.0, top + 0.02)]), 0.035, 0.035, VERMILION, VERMILION)
	p.parts.append("tilak")

## The tripundra: three lines of ash across the brow, a red dot at the middle.
static func _paint_tripundra(p: Paint) -> void:
	for k in 3:
		var y := -0.32 - 0.075 * k
		p.stroke(_bez(Vector2(-0.4, y + 0.03), Vector2(-0.15, y - 0.01), Vector2(0.15, y - 0.01), Vector2(0.4, y + 0.03), 10), 0.035, 0.035, Color(0.92, 0.92, 0.9, 0.85), Color(0.92, 0.92, 0.9, 0.85), true)
	p.soft(Vector2(0.0, -0.4), 0.045, 0.045, Color(VERMILION, 1.0))
	p.fill(_oval(Vector2(0.0, -0.4), 0.028, 0.028, 12), VERMILION)
	p.parts.append("tilak")

## Divine sight: a soft light at the brow, with faint rays.
static func _paint_glow(p: Paint) -> void:
	var at := Vector2(0.0, -0.33)
	var light := Color(1.0, 0.9, 0.55)
	p.soft(at, 0.5, 0.42, Color(light, 0.35))
	for i in 16:
		var a := TAU * i / 16.0
		var dir := Vector2(cos(a), sin(a) * 0.85)
		p.stroke(PackedVector2Array([at + dir * 0.08, at + dir * 0.5]), 0.03, 0.005, Color(light, 0.5), Color(light, 0.0))
	p.soft(at, 0.12, 0.12, Color(1.0, 0.97, 0.85, 0.9))
	p.soft(at, 0.04, 0.05, Color(1, 1, 1, 1))
	p.parts.append("glow")

## Kundala: a gold ring hanging from each ear, a gem below.
static func _paint_earrings(p: Paint, kind: StringName, gold: Color, gem: Color) -> void:
	var lobe := Vector2(0.8, 0.46) if kind == &"human" else Vector2(0.9, 0.28)
	for side: float in [-1.0, 1.0]:
		var at := lobe * Vector2(side, 1.0) + Vector2(0, 0.1)
		var ring := _oval(at, 0.085, 0.095, 18)
		ring.append(ring[0])
		p.stroke(ring, 0.04, 0.04, Paint.lit(gold, Vector3(-0.5, -0.5, 0.7).normalized(), 0.8), Paint.lit(gold, Vector3(0.5, 0.3, 0.7).normalized(), 0.8))
		_gem(p, at + Vector2(0, 0.12), 0.035, gem)
	p.parts.append("earrings")

## A gold necklace close round the neck, with a pendant.
static func _paint_necklace(p: Paint, gold: Color, gem: Color) -> void:
	for k in 2:
		var pts := _bez(Vector2(-0.6, 1.72), Vector2(-0.5, 2.1 + 0.15 * k), Vector2(0.5, 2.1 + 0.15 * k), Vector2(0.6, 1.72), 16)
		p.stroke(pts, 0.05, 0.05, Paint.lit(gold, Vector3(-0.4, -0.4, 0.8).normalized(), 0.7), Paint.lit(gold, Vector3(0.4, -0.4, 0.8).normalized(), 0.7))
		for i in range(1, 16, 2):
			p.soft(pts[i] + Vector2(-0.01, -0.01), 0.02, 0.02, Color(1.0, 0.95, 0.75, 0.8))
	p.dome(Vector2(0.0, 2.1), _oval(Vector2(0.0, 2.12), 0.1, 0.13, 16), gold, 0.9, 0.8)
	_gem(p, Vector2(0.0, 2.12), 0.06, gem)
	p.parts.append("necklace")

## A rudraksha mala: a loop of dark beads hanging on the chest.
static func _paint_beads(p: Paint) -> void:
	var pts := _bez(Vector2(-0.55, 1.68), Vector2(-0.6, 2.55), Vector2(0.6, 2.55), Vector2(0.55, 1.68), 24)
	var bead := Color(0.42, 0.22, 0.14)
	for i in pts.size():
		p.dome(pts[i] + Vector2(-0.01, -0.01), _oval(pts[i], 0.045, 0.045, 12), bead, 0.9, 0.3)
	p.parts.append("beads")

## The sacred thread, over the left shoulder and across the chest.
static func _paint_thread(p: Paint) -> void:
	for k in 3:
		var o := Vector2(0.025 * k, 0.0)
		p.stroke(_bez(Vector2(-1.15, 1.74) + o, Vector2(-0.6, 2.0) + o, Vector2(0.0, 2.3) + o, Vector2(0.75, BOTTOM) + o, 16), 0.018, 0.018, Color(0.97, 0.95, 0.88, 0.95), Color(0.97, 0.95, 0.88, 0.95))
	p.parts.append("sacred_thread")

## A builder's sash, knotted, from the right shoulder across the chest.
static func _paint_sash(p: Paint, col: Color) -> void:
	var sash := PackedVector2Array()
	sash.append_array(_bez(Vector2(0.75, 1.7), Vector2(0.3, 2.0), Vector2(-0.4, 2.3), Vector2(-1.05, BOTTOM), 10))
	sash.append(Vector2(-0.55, BOTTOM))
	sash.append_array(_bez(Vector2(-0.4, 2.55), Vector2(0.1, 2.2), Vector2(0.7, 2.0), Vector2(1.05, 1.82), 10))
	p.shaded(sash, col, Vector2(0.0, 2.0), Vector2(1.2, 0.8), 0.1)
	for k in 3:
		var t := 0.25 + 0.25 * k
		var a := Vector2(0.75, 1.7).lerp(Vector2(-1.05, BOTTOM), t)
		p.stroke(PackedVector2Array([a, a + Vector2(0.2, 0.18)]), 0.03, 0.03, Color(_shade(col), 0.5), Color(_shade(col), 0.2))
	p.dome(Vector2(0.75, 1.82), _oval(Vector2(0.8, 1.84), 0.14, 0.12, 14), col.darkened(0.08), 0.8, 0.1)
	p.parts.append("sash")

## A gold ring round a bird's neck, above the ruff.
static func _paint_neck_ring(p: Paint, gold: Color, gem: Color) -> void:
	var front := PackedVector2Array()
	for i in 13:
		var x := lerpf(-0.5, 0.5, i / 12.0)
		front.append(Vector2(x, 0.88 + 0.12 * (1.0 - x * x / 0.25)))
	for i in 13:
		var x := lerpf(0.5, -0.5, i / 12.0)
		front.append(Vector2(x, 1.02 + 0.12 * (1.0 - x * x / 0.25)))
	p.shaded(front, gold, Vector2(-0.15, 0.9), Vector2(0.6, 0.3), 0.9)
	_gem(p, Vector2(0.0, 1.07), 0.06, gem)
	p.parts.append("neck_ring")

## A vanara elder's beard: a tuft of fur below the muzzle.
static func _paint_goatee(p: Paint, fur: Color, rng: RandomNumberGenerator) -> void:
	_locks(p, 40, func(t: float, g: RandomNumberGenerator) -> Array:
		var x := lerpf(-0.36, 0.36, t)
		var root := Vector2(x, 0.88 + 0.08 * (1.0 - absf(x) / 0.36))
		var tip := Vector2(x * 0.4 + g.randf_range(-0.04, 0.04), 1.32 + 0.14 * (1.0 - absf(x) / 0.36))
		return [root, root + Vector2(0, 0.15), tip + Vector2(x * 0.3, -0.12), tip], fur, 0.07, rng)
	p.parts.append("beard")

## A bow over one shoulder: its upper limb rising behind the head, lacquered
## wood bound in gold, with a recurved tip, and the string behind the shoulder.
static func _paint_bow(back: Paint, front: Paint, side: float, gold: Color) -> void:
	var tip := Vector2(side * 1.15, -1.6)
	var limb := _bez(tip, Vector2(side * 2.0, -0.9), Vector2(side * 2.1, 0.8), Vector2(side * 1.65, BOTTOM), 20)
	back.stroke(PackedVector2Array([Vector2(side * 1.22, BOTTOM), tip + Vector2(side * 0.02, 0.04)]), 0.025, 0.025, Color(0.9, 0.86, 0.75, 0.9), Color(0.9, 0.86, 0.75, 0.9))
	back.stroke(limb, 0.07, 0.16, Paint.lit(BOW_WOOD, Vector3(-side * 0.2, -0.5, 0.8).normalized(), 0.5), Paint.lit(BOW_WOOD, Vector3(side * 0.5, 0.2, 0.8).normalized(), 0.5))
	back.stroke(limb, 0.02, 0.04, Color(BOW_WOOD.lightened(0.4), 0.5), Color(BOW_WOOD.lightened(0.4), 0.3))
	for k in 6:
		var i := 2 + k * 3
		var dir := (limb[i + 1] - limb[i - 1]).normalized()
		var n := Vector2(-dir.y, dir.x) * (0.05 + 0.004 * i)
		back.stroke(PackedVector2Array([limb[i] - n, limb[i] + n]), 0.05, 0.05, Paint.lit(gold, Vector3(-0.4, -0.4, 0.8).normalized(), 0.8), Paint.lit(gold, Vector3(0.4, 0.2, 0.8).normalized(), 0.8))
	back.stroke(_bez(tip, tip + Vector2(-side * 0.1, -0.05), tip + Vector2(-side * 0.18, 0.02), tip + Vector2(-side * 0.16, 0.12), 6), 0.07, 0.03, Paint.lit(gold, Vector3(-0.4, -0.5, 0.8).normalized(), 0.8), gold)
	back.parts.append("bow")

## The gada: a fluted gold mace head with a finial, resting on a shoulder on
## its banded haft.
static func _paint_gada(p: Paint, side: float, gold: Color, gem: Color) -> void:
	var head := Vector2(side * 1.6, 0.15)
	var haft := PackedVector2Array([Vector2(side * 0.9, BOTTOM), head])
	p.stroke(haft, 0.16, 0.13, Paint.lit(gold, Vector3(-0.5, 0.0, 0.8).normalized(), 0.7).darkened(0.15), Paint.lit(gold, Vector3(-0.5, -0.3, 0.8).normalized(), 0.7))
	for k in 4:
		var a := haft[0].lerp(haft[1], 0.45 + 0.13 * k)
		p.stroke(PackedVector2Array([a + Vector2(-0.1, 0.04 * side), a + Vector2(0.1, -0.04 * side)]), 0.06, 0.06, Paint.lit(gold, Vector3(-0.5, -0.5, 0.7).normalized(), 0.9), Paint.lit(gold, Vector3(0.5, 0.2, 0.7).normalized(), 0.9))
	p.dome(head + Vector2(-0.16, -0.16), _oval(head, 0.52, 0.56, 32), gold, 0.95, 0.9)
	# Flutes down the head, each lit on its left and shaded on its right.
	for k in 7:
		var x := lerpf(-0.36, 0.36, k / 6.0)
		var w := sqrt(maxf(1.0 - pow(x / 0.52, 2.0), 0.0)) * 0.54
		var pts := _bez(head + Vector2(x * 0.6, -w), head + Vector2(x * 1.25, -w * 0.4), head + Vector2(x * 1.25, w * 0.4), head + Vector2(x * 0.6, w), 10)
		p.stroke(pts, 0.035, 0.035, Color(_shade(gold, 0.8), 0.0), Color(_shade(gold, 0.8), 0.55), true)
		for i in pts.size():
			pts[i] += Vector2(-0.035, 0.0)
		p.stroke(pts, 0.025, 0.025, Color(1.0, 0.95, 0.75, 0.0), Color(1.0, 0.95, 0.75, 0.4), true)
	for y in [-0.56, 0.54]:
		p.stroke(_bez(head + Vector2(-0.2, y), head + Vector2(-0.1, y + 0.03), head + Vector2(0.1, y + 0.03), head + Vector2(0.2, y), 6), 0.08, 0.08, Paint.lit(gold, Vector3(-0.3, -0.6, 0.7).normalized(), 0.9), Paint.lit(gold, Vector3(0.4, -0.2, 0.8).normalized(), 0.9))
	p.dome(head + Vector2(-0.03, -0.68), _oval(head + Vector2(0.0, -0.66), 0.1, 0.11, 14), gold, 0.9, 0.9)
	p.stroke(PackedVector2Array([head + Vector2(0.0, -0.72), head + Vector2(0.0, -0.94)]), 0.07, 0.01, gold, gold.lightened(0.3))
	_gem(p, head + Vector2(-0.05, 0.02), 0.07, gem)
	p.parts.append("gada")

## A chakra worked on the breastplate: a gold wheel with its spokes and hub.
static func _paint_chakra(p: Paint, gold: Color, gem: Color) -> void:
	var at := Vector2(0.0, 2.2)
	p.soft(at, 0.42, 0.42, Color(gold.lightened(0.3), 0.25))
	var ring := _oval(at, 0.3, 0.3, 32)
	ring.append(ring[0])
	p.stroke(ring, 0.07, 0.07, Paint.lit(gold, Vector3(-0.5, -0.5, 0.7).normalized(), 0.9), Paint.lit(gold, Vector3(0.5, 0.5, 0.7).normalized(), 0.9))
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		var dir := Vector2(cos(a), sin(a))
		p.stroke(PackedVector2Array([at + dir * 0.07, at + dir * 0.27]), 0.04, 0.025, Paint.lit(gold, Vector3(dir.x * 0.3, dir.y * 0.3, 0.9).normalized(), 0.8), gold)
		p.soft(at + dir * 0.36, 0.035, 0.035, Color(gold.lightened(0.2), 0.9))
	p.dome(at + Vector2(-0.02, -0.02), _oval(at, 0.08, 0.08, 16), gold, 0.9, 0.9)
	_gem(p, at, 0.04, gem)
	p.parts.append("chakra")

## A stone for the bridge to Lanka, carried on the shoulder, with "राम"
## (Rama) written on it in vermilion.
static func _paint_stone(p: Paint, side: float, rng: RandomNumberGenerator) -> void:
	var at := Vector2(side * 1.5, 1.38)
	var ring := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var k := 1.0 + 0.06 * sin(a * 3.0 + 1.0) + 0.04 * sin(a * 5.0)
		ring.append(at + Vector2(cos(a) * 0.62, sin(a) * 0.46) * k)
	p.dome(at + Vector2(-0.2, -0.18), ring, STONE, 0.75, 0.05, 5)
	for i in 24:
		var q := at + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.35, 0.35))
		p.soft(q, 0.04, 0.03, Color(STONE.darkened(0.3) if i % 2 == 0 else STONE.lightened(0.25), 0.4))
	p.soft(at + Vector2(0.0, 0.42), 0.6, 0.12, Color(0.1, 0.07, 0.05, 0.35))
	# राम: the headline, then र, the ा bar and म.
	var ink := VERMILION
	var w := 0.035
	var top := at.y - 0.12
	var base := at.y + 0.14
	var x := at.x - 0.3
	p.stroke(PackedVector2Array([Vector2(x - 0.02, top), Vector2(x + 0.62, top)]), w, w, ink, ink)
	p.stroke(_bez(Vector2(x + 0.06, top), Vector2(x + 0.17, top + 0.08), Vector2(x + 0.02, top + 0.12), Vector2(x + 0.04, top + 0.16), 8), w, w, ink, ink)
	p.stroke(_bez(Vector2(x + 0.04, top + 0.16), Vector2(x + 0.06, top + 0.2), Vector2(x + 0.12, top + 0.22), Vector2(x + 0.16, base), 8), w, w, ink, ink)
	p.stroke(PackedVector2Array([Vector2(x + 0.24, top), Vector2(x + 0.24, base)]), w, w, ink, ink)
	# म: a stem down from the headline into a small loop at its foot, joined
	# across to a full upright on the right.
	p.stroke(PackedVector2Array([Vector2(x + 0.56, top), Vector2(x + 0.56, base)]), w, w, ink, ink)
	p.stroke(PackedVector2Array([Vector2(x + 0.35, top), Vector2(x + 0.35, top + 0.09)]), w, w, ink, ink)
	var loop := _oval(Vector2(x + 0.38, top + 0.13), 0.045, 0.04, 12)
	loop.append(loop[0])
	p.stroke(loop, w * 0.9, w * 0.9, ink, ink)
	p.stroke(_bez(Vector2(x + 0.42, top + 0.14), Vector2(x + 0.47, top + 0.15), Vector2(x + 0.52, top + 0.14), Vector2(x + 0.56, top + 0.12), 6), w, w, ink, ink)
	p.parts.append("stone")

## A sprig of the sanjivani herb rising past the shoulder: leaves on a stem
## and small golden flowers that glow.
static func _paint_herb(p: Paint, side: float, rng: RandomNumberGenerator) -> void:
	var stem := _bez(Vector2(side * 1.25, BOTTOM), Vector2(side * 1.35, 1.6), Vector2(side * 1.75, 0.6), Vector2(side * 1.55, -0.35), 16)
	p.soft(stem[15], 0.5, 0.5, Color(BLOOM, 0.25))
	p.stroke(stem, 0.06, 0.03, LEAF.darkened(0.3), LEAF)
	for i in range(3, 16, 2):
		var dir := (stem[mini(i + 1, 16)] - stem[i - 1]).normalized()
		var out := Vector2(-dir.y, dir.x) * (1.0 if i % 4 == 1 else -1.0)
		var tip := stem[i] + (out * 0.32 + dir * 0.12) * lerpf(1.0, 0.6, i / 16.0)
		var leaf := PackedVector2Array(_bez(stem[i], stem[i].lerp(tip, 0.3) + dir * 0.09, stem[i].lerp(tip, 0.7) + dir * 0.07, tip, 8))
		leaf.append_array(_bez(tip, stem[i].lerp(tip, 0.7) - dir * 0.05, stem[i].lerp(tip, 0.3) - dir * 0.06, stem[i], 8))
		var col := LEAF.lerp(Color(0.5, 0.75, 0.3), rng.randf() * 0.5)
		p.shaded(leaf, col, stem[i].lerp(tip, 0.4) + Vector2(-0.05, -0.05), Vector2(0.3, 0.3), 0.3)
		p.stroke(PackedVector2Array([stem[i], tip]), 0.012, 0.004, Color(col.lightened(0.3), 0.6), Color(col.lightened(0.3), 0.1))
	for i in 7:
		var q := stem[16] + Vector2(rng.randf_range(-0.22, 0.22), rng.randf_range(-0.15, 0.25))
		p.soft(q, 0.13, 0.13, Color(BLOOM, 0.45))
		p.dome(q + Vector2(-0.01, -0.01), _oval(q, 0.05, 0.05, 12), BLOOM, 0.8, 0.6)
	p.parts.append("herb")
