class_name DroneTurntable
extends SubViewportContainer
# Story 27.5: the hangar's drone on a turntable, in its own little world. It
# shows a livery and parts before they are applied: `show_drone` dresses a
# display drone (frozen, never flown, nothing in it runs) the way Garage.apply
# would, its arms at the parts' arm length and its hull in the frame's shape.
# The camera goes round it: the right stick, a mouse drag, or the arrow keys
# while it has focus turn it; left alone, it turns slowly by itself.

## Radians a second the turntable turns on its own, and at full stick or key.
const IDLE_SPIN := 0.35
const TURN_SPEED := 2.6
## Radians per pixel of mouse drag.
const DRAG_TURN := 0.012
## Seconds after the player turns it before it spins on its own again.
const IDLE_AFTER := 3.0
## The camera's height angle and its distance off the drone, m.
const PITCH := 0.5
const DISTANCE := 1.25
const STICK_DEADZONE := 0.2

## Where the camera looks from, round the drone, in radians.
var yaw := 0.6
## The display drone; replaced when the parts change.
var drone: Drone
var accent := Color(1.0, 0.76, 0.25)

var _view: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _parts := {}
var _since_turned := INF

func _ready() -> void:
	stretch = true
	focus_mode = FOCUS_ALL
	mouse_filter = MOUSE_FILTER_STOP
	_view = SubViewport.new()
	_view.name = "View"
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	add_child(_view)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.045, 0.05, 0.065)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = env
	_view.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.9, 0.7, 0.0)
	key.light_energy = 1.3
	_view.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.35, PI + 0.4, 0.0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.7, 0.8, 1.0)
	_view.add_child(rim)
	_build_stand()
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.position.y = 0.09
	_view.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 34.0
	_camera.current = true
	_view.add_child(_camera)
	_place_camera()

## The stand: a dark disc with a ring lit in the accent.
func _build_stand() -> void:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.3
	mesh.bottom_radius = 0.315
	mesh.height = 0.03
	mesh.radial_segments = 48
	disc.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.11, 0.12, 0.14)
	m.metallic = 0.4
	m.roughness = 0.5
	disc.material_override = m
	_view.add_child(disc)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.296
	torus.outer_radius = 0.306
	torus.rings = 48
	ring.mesh = torus
	ring.position.y = 0.016
	var lit := StandardMaterial3D.new()
	lit.albedo_color = accent
	lit.emission_enabled = true
	lit.emission = accent
	lit.emission_energy_multiplier = 1.5
	ring.material_override = lit
	_view.add_child(ring)

## Dresses the display drone in `l` with `parts` (kind -> part id) fitted.
## The parts only rebuild it when they change; a livery alone re-dresses it.
func show_drone(l: Livery, parts: Dictionary) -> void:
	if drone == null or parts != _parts:
		_parts = parts.duplicate()
		if drone:
			drone.free()
		drone = Drone.new()
		drone.name = "Drone"
		drone.freeze = true
		# On show only: it never runs (rule 1: nothing but a flight moves a drone).
		drone.process_mode = PROCESS_MODE_DISABLED
		for kind in parts:
			var p := Hangar.part(parts[kind])
			if p:
				p.apply_stats(drone)
		var look := DroneLook.new()
		look.name = "Look"
		drone.add_child(look)
		_pivot.add_child(drone)
	var frame := Hangar.part(parts.get(&"frame", &""))
	look().wear(l, frame.hull if frame else Vector3.ONE)

func look() -> DroneLook:
	return drone.get_node("Look") as DroneLook if drone else null

## Turns the view by `angle` radians, as the player does.
func turn(angle: float) -> void:
	yaw = wrapf(yaw + angle, -PI, PI)
	_since_turned = 0.0
	_place_camera()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var push := _stick()
	if has_focus():
		push += Input.get_axis(&"ui_left", &"ui_right")
	if absf(push) > 0.0:
		turn(push * TURN_SPEED * delta)
	else:
		_since_turned += delta
		if _since_turned > IDLE_AFTER:
			yaw = wrapf(yaw + IDLE_SPIN * delta, -PI, PI)
			_place_camera()

## The right stick's left and right, past its deadzone, on any pad.
static func _stick() -> float:
	var x := 0.0
	for id in Input.get_connected_joypads():
		var v := Input.get_joy_axis(id, JOY_AXIS_RIGHT_X)
		if absf(v) > absf(x):
			x = v
	return x if absf(x) > STICK_DEADZONE else 0.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		turn(event.relative.x * DRAG_TURN)
		accept_event()
	# Left and right turn it while it has focus (in _process); they do not
	# move focus off it. Up and down do.
	if event.is_action(&"ui_left") or event.is_action(&"ui_right"):
		accept_event()

func _place_camera() -> void:
	if _camera == null:
		return
	# The fov spans the view's narrower side, so a tall view still fits the drone.
	_camera.keep_aspect = Camera3D.KEEP_WIDTH if size.x < size.y else Camera3D.KEEP_HEIGHT
	var at := Vector3(sin(yaw) * cos(PITCH), sin(PITCH), cos(yaw) * cos(PITCH)) * DISTANCE
	_camera.position = at + Vector3(0, 0.05, 0)
	_camera.look_at(Vector3(0, 0.07, 0), Vector3.UP)
