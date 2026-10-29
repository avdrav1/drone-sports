class_name DroneFace
extends MeshInstance3D
# Story 18.7: a crew drone wears its pilot's face. A small LED panel on the
# front of the drone, a child of its DroneLook, drawn by an unshaded shader from
# the same CharacterPortrait.pose() values as the portrait, in the pilot's
# colours. It blinks with the portrait's seed, bobs with their rhythm, looks
# the way the drone is heading, and reacts to the drone's own flight events
# (17.8) through its FlightWatcher. Visual only: a mesh with no body, so the
# drone's mass, shapes and flight values never change (rules 1 and 2). Only
# drones a living crew member flies wear one; the dead never appear on a drone.

const SHADER := preload("res://scenes/drone/drone_face.gdshader")
## The panel, metres: on the front of the canopy, tipped back a little.
const SIZE := Vector2(0.084, 0.071)
const MOUNT := Vector3(0.0, 0.05, -0.088)
const TILT := -0.3
## The face at rest, and between reactions.
const REST := &"neutral"
## Flight event -> [expression, seconds held, dizzy]. Dizzy pupils circle.
## Keys match the emote table's (18.3) where both react to the same thing.
const REACTIONS := {
	&"gate": [&"happy", 0.9, false],
	&"takeoff": [&"happy", 0.8, false],
	&"low_pass": [&"happy", 1.2, false],
	&"top_speed": [&"determined", 1.5, false],
	&"near_miss": [&"shocked", 1.2, false],
	&"crash": [&"worried", 2.5, true],
	&"battery_low": [&"worried", 2.0, false],
}
## Lateral speed, m/s, at which the pupils look fully toward the heading.
const LOOK_SPEED := 6.0
## Pose fields, each set as the shader uniform of the same name.
const FIELDS := ["brow_angle", "brow_height", "lid", "squint", "eye_scale", "pupil", "blush", "mouth_width", "mouth_curve", "mouth_open"]

var character: Character
var drone: Drone
## Raises this drone's flight events.
var watcher: FlightWatcher
var expression: StringName = REST
var dizzy := false
## Seconds this face has run; drives blinks, bob and reactions.
var time := 0.0
## Where the pupils look, length 0 to 1.
var look := Vector2.ZERO
var _until := -INF
var _expression_at := 0.0
var _material: ShaderMaterial

## Puts `c`'s face on `d`, or updates the one there. None for the dead.
static func wear(d: Drone, c: Character) -> DroneFace:
	var look_node := d.get_node_or_null("Look") if d else null
	if look_node == null or c == null or not Roster.is_alive(c.id):
		return null
	var face := of(d)
	if face == null:
		face = DroneFace.new()
		face.name = "Face"
		look_node.add_child(face)
	face.character = c
	face._apply_colors()
	return face

## The face `d` wears, or null.
static func of(d: Node) -> DroneFace:
	return d.get_node_or_null("Look/Face") as DroneFace if is_instance_valid(d) else null

func _ready() -> void:
	drone = get_parent().get_parent() as Drone
	var quad := QuadMesh.new()
	quad.size = SIZE
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material_override = _material
	position = MOUNT
	rotation = Vector3(TILT, PI, 0.0)
	# A dark back plate so the panel reads as a screen from behind too.
	var back := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SIZE.x + 0.004, SIZE.y + 0.004, 0.006)
	back.mesh = box
	var plate := StandardMaterial3D.new()
	plate.albedo_color = DroneLook.CARBON
	back.material_override = plate
	back.position = Vector3(0, 0, -0.0035)
	add_child(back)
	watcher = FlightWatcher.new()
	watcher.name = "Watcher"
	watcher.drone = drone
	add_child(watcher)
	watcher.flight_event.connect(react)
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
	if time >= _until and expression != REST:
		_set_expression(REST)
	if drone:
		var v := drone.global_basis.inverse() * drone.linear_velocity
		# The drone's right is the viewer's left; up is up the panel.
		var aim := Vector2(-v.x, -v.y) / maxf(Vector2(v.x, v.y).length(), LOOK_SPEED)
		look = look.lerp(aim, clampf(delta * 6.0, 0.0, 1.0))
	var p := current_pose()
	for f in FIELDS:
		_material.set_shader_parameter(f, p[f])
	var m := current_motion()
	_material.set_shader_parameter(&"squash", m.scale)
	_material.set_shader_parameter(&"bob", m.offset)

## True while the pilot is alive: the dead never appear on a drone.
func shows() -> bool:
	return character != null and Roster.is_alive(character.id)

## Shows the reaction to a flight event; false for an unmapped one.
func react(event: StringName) -> bool:
	if not REACTIONS.has(event) or not shows():
		return false
	var r: Array = REACTIONS[event]
	hold(r[0], r[1])
	dizzy = r[2]
	return true

## Shows `expr` for `seconds`, then returns to REST.
func hold(expr: StringName, seconds: float) -> void:
	_set_expression(expr)
	dizzy = false
	_until = time + seconds

## The panel's face now: CharacterPortrait.pose() for the expression and time,
## with the portrait's blink seed, the heading look and the shocked eye pop.
func current_pose() -> Dictionary:
	var p := CharacterPortrait.pose(expression, time, false, hash(character.id) if character else 0)
	var aim := Vector2(cos(time * 12.0), sin(time * 12.0)) * 0.8 if dizzy else (p.pupil as Vector2) + look
	p.pupil = aim.limit_length(CharacterPortrait.PUPIL_REACH)
	p.eye_scale = float(p.eye_scale) * float(current_motion().eye_pop)
	return p

func current_motion() -> Dictionary:
	if not shows():
		return CharacterPortrait.still()
	return CharacterPortrait.motion(expression, time, false, character.bounce, INF, time - _expression_at)

func _set_expression(e: StringName) -> void:
	if e != expression:
		_expression_at = time
	expression = e
	if e == REST:
		dizzy = false

func _apply_colors() -> void:
	if _material == null or character == null or character.colors.size() < 2:
		return
	_material.set_shader_parameter(&"body", character.colors[0])
	_material.set_shader_parameter(&"accent", character.colors[1])
	_material.set_shader_parameter(&"ink", CharacterPortrait.INK)
