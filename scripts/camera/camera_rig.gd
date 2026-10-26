class_name CameraRig
extends Node3D
# A tool for flying, never a mechanic. Four views cycled with `cycle_camera`:
# chase, FPV, orbit, top-down. Chase and orbit pull in on a sphere cast so
# the camera never ends a frame inside geometry.

enum View { CHASE, FPV, ORBIT, TOP_DOWN }
const ORDER: Array[View] = [View.CHASE, View.FPV, View.ORBIT, View.TOP_DOWN]

signal view_changed(view: View)

@export var target: Node3D
## The view a job asks for. A JobRunner calls use_default_view() on Briefing.
@export var default_view := View.CHASE

@export_group("Chase")
@export var chase_distance := 3.0
@export var chase_height := 1.0
## Higher is snappier. Exponential smoothing rate, 1/s.
@export var chase_smoothing := 8.0
@export_group("FPV")
@export var fpv_offset := Vector3(0.0, 0.03, -0.18)
@export_group("Orbit")
@export var orbit_distance := 4.0
@export var orbit_sensitivity := 0.006
@export_group("Top-down")
@export var top_down_height := 25.0
@export_group("Clipping")
@export var clip_radius := 0.2

var view := View.CHASE
var orbit_yaw := 0.0
var orbit_pitch := -0.35
var _chase_position := Vector3.ZERO
var _clip_shape := SphereShape3D.new()

@onready var camera: Camera3D = $Camera

func _ready() -> void:
	camera.top_level = true
	view = default_view
	if target:
		_chase_position = _chase_goal()

func cycle() -> void:
	set_view(ORDER[(ORDER.find(view) + 1) % ORDER.size()])

func use_default_view() -> void:
	set_view(default_view)

func set_view(v: View) -> void:
	if v == View.CHASE and target:
		_chase_position = _chase_goal()
	view = v
	view_changed.emit(view)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_camera"):
		cycle()
	elif view == View.ORBIT and event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		orbit_yaw -= event.relative.x * orbit_sensitivity
		orbit_pitch = clampf(orbit_pitch - event.relative.y * orbit_sensitivity, -1.45, 1.45)

func _process(delta: float) -> void:
	update_camera(delta)

func update_camera(delta: float) -> void:
	if target == null:
		return
	var pivot := target.global_position
	match view:
		View.FPV:
			camera.global_transform = target.global_transform * Transform3D(Basis.IDENTITY, fpv_offset)
		View.CHASE:
			_chase_position = _chase_position.lerp(_chase_goal(), 1.0 - exp(-chase_smoothing * delta))
			_place(_clip(pivot, _chase_position), pivot)
		View.ORBIT:
			var offset := Basis.from_euler(Vector3(orbit_pitch, orbit_yaw, 0.0)) * Vector3(0.0, 0.0, orbit_distance)
			_place(_clip(pivot, pivot + offset), pivot)
		View.TOP_DOWN:
			camera.global_position = pivot + Vector3(0.0, top_down_height, 0.0)
			camera.look_at(pivot, Vector3.FORWARD)

## Behind the target along its heading (yaw only), and above.
func _chase_goal() -> Vector3:
	var b := target.global_transform.basis
	var back := Vector3(b.z.x, 0.0, b.z.z)
	back = back.normalized() if back.length_squared() > 0.0001 else Vector3.BACK
	return target.global_position + back * chase_distance + Vector3.UP * chase_height

func _place(pos: Vector3, look: Vector3) -> void:
	camera.global_position = pos
	if pos.distance_squared_to(look) > 0.0001:
		camera.look_at(look, Vector3.UP)

## Sweeps a sphere from pivot toward wanted and stops short of the first hit.
## A ray backs it up for when the sphere already touches something at the pivot.
func _clip(pivot: Vector3, wanted: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if target is CollisionObject3D:
		exclude.append(target.get_rid())
	var params := PhysicsShapeQueryParameters3D.new()
	_clip_shape.radius = clip_radius
	params.shape = _clip_shape
	params.transform = Transform3D(Basis.IDENTITY, pivot)
	params.motion = wanted - pivot
	params.exclude = exclude
	var hit := space.cast_motion(params)
	var fraction: float = hit[0] if not hit.is_empty() else 1.0
	var ray := PhysicsRayQueryParameters3D.create(pivot, wanted)
	ray.exclude = exclude
	var ray_hit := space.intersect_ray(ray)
	if not ray_hit.is_empty():
		var length := pivot.distance_to(wanted)
		var ray_fraction := maxf(pivot.distance_to(ray_hit.position) - clip_radius, 0.0) / length
		fraction = minf(fraction, ray_fraction)
	return pivot + (wanted - pivot) * fraction
