class_name CrewFace
extends MeshInstance3D
# Story 20.3: a crew figure wears its character's cartoon face, the portrait's
# eyes, brows, mouth and blush, drawn by crew_face.gdshader from the same
# CharacterPortrait.pose() values over the pack's own eyes and mouth. It
# blinks with the portrait's seed, and while the radio (a BarkBox) has one of
# this character's lines up, it makes the line's face and talks while the line
# types out, then goes back to REST. Look only: a mesh with no body. The dead
# never show a face.

const SHADER := preload("res://scenes/crew/crew_face.gdshader")
## The skin front of the pack's head box, in head-bone units: its size, where
## its centre sits, and how far forward, just in front of the pack's eyes and
## mouth (0.162) and glasses (0.167), behind fringes (0.17) and beards.
const SIZE := Vector2(0.24, 0.271)
const MOUNT := Vector3(0.0, 0.1355, 0.168)
## The face at rest, and after a line.
const REST := &"neutral"
## Pose fields, each set as the shader uniform of the same name.
const FIELDS := ["brow_angle", "brow_height", "lid", "squint", "eye_scale", "pupil", "blush", "mouth_width", "mouth_curve", "mouth_open"]

var character: Character
## The job's radio; this face follows its lines from `character`.
var radio: BarkBox
var expression: StringName = REST
var talking := false
## Seconds this face has run; drives blinks and talking.
var time := 0.0
var _until := -INF
var _expression_at := 0.0
var _material: ShaderMaterial

## Puts `c`'s face on `figure`'s head, or updates the one there. None for the dead.
static func wear(figure: CrewFigure, c: Character) -> CrewFace:
	var head := figure.skeleton.get_node_or_null("Head") if figure else null
	if head == null or c == null or not Roster.is_alive(c.id):
		return null
	var face := of(figure)
	if face == null:
		face = CrewFace.new()
		face.name = "Face"
		head.add_child(face)
	face.character = c
	face._apply_colors()
	return face

## The face `figure` wears, or null.
static func of(figure: CrewFigure) -> CrewFace:
	return figure.skeleton.get_node_or_null("Head/Face") as CrewFace if is_instance_valid(figure) else null

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = SIZE
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material_override = _material
	position = MOUNT
	_apply_colors()
	advance(0.0)

func _process(delta: float) -> void:
	advance(delta)

## Steps the face by `delta` seconds and pushes its pose to the shader.
func advance(delta: float) -> void:
	time += delta
	visible = shows()
	if not visible:
		return
	var line: Dictionary = radio.current if is_instance_valid(radio) and radio.showing() else {}
	if line.get("id", &"") == character.id:
		var face: StringName = line.get("face", REST)
		_set_expression(face if face in CharacterPortrait.EXPRESSIONS else REST)
		talking = radio.typing()
		_until = -INF
	else:
		talking = false
		if time >= _until and expression != REST:
			_set_expression(REST)
	var p := current_pose()
	for f in FIELDS:
		_material.set_shader_parameter(f, p[f])

## True while the character is alive: the dead never show a face.
func shows() -> bool:
	return character != null and Roster.is_alive(character.id)

## Shows `expr` for `seconds`, then returns to REST; a radio line outranks it.
func hold(expr: StringName, seconds: float) -> void:
	_set_expression(expr)
	_until = time + seconds

## The face now: CharacterPortrait.pose() for the expression and time, with the
## portrait's blink seed and the shocked eye pop.
func current_pose() -> Dictionary:
	var p := CharacterPortrait.pose(expression, time, talking, hash(character.id) if character else 0)
	if character:
		var m := CharacterPortrait.motion(expression, time, talking, character.bounce, INF, time - _expression_at)
		p.eye_scale = float(p.eye_scale) * float(m.eye_pop)
	return p

func _set_expression(e: StringName) -> void:
	if e != expression:
		_expression_at = time
	expression = e

func _apply_colors() -> void:
	if _material == null or character == null or character.look == null:
		return
	_material.set_shader_parameter(&"skin", character.look.skin)
	_material.set_shader_parameter(&"ink", CharacterPortrait.INK)
