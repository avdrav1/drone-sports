class_name CollisionGuard
extends Assist
# Sweeps the drone's shape ahead of its horizontal velocity. When the gap is
# shorter than the braking distance, takes over pitch and roll to brake.

## Deceleration the guard plans for, m/s². Below what a 45° tilt can deliver.
@export var brake_accel := 6.0
## Gap kept between the drone and the obstacle, m.
@export var margin := 0.4
## Time the drone takes to tilt into a brake, s.
@export var reaction_time := 0.3
## Velocity gain while braking, 1/s.
@export var velocity_gain := 4.0

## True on frames where the guard overrode the sticks.
var braking := false

func _init() -> void:
	assist_id = &"collision_guard"

func apply(intent: Intent, drone: Drone, _delta: float) -> void:
	braking = false
	var v := FlightControl.horizontal_velocity(drone)
	var speed := v.length()
	if speed < 0.05:
		return
	var dir := v / speed
	var reach := speed * speed / (2.0 * brake_accel) + speed * reaction_time + margin + 1.0
	var gap := free_distance(drone, dir, reach)
	if gap == INF:
		return
	var room := maxf(gap - margin - speed * reaction_time * 0.5, 0.0)
	var allowed := sqrt(2.0 * brake_accel * room)
	if speed <= allowed:
		return
	braking = true
	var decel := clampf(velocity_gain * (speed - allowed), 0.0, drone.gravity())
	var target := FlightControl.tilt_for_accel(drone, -dir * decel)
	var sticks := FlightControl.attitude_sticks(drone, target.x, target.y)
	intent.pitch = sticks.x
	intent.roll = sticks.y

## Distance the drone's collision shape can travel along dir before contact, or INF.
static func free_distance(drone: Drone, dir: Vector3, reach: float) -> float:
	var shape_node: CollisionShape3D = drone.get_node("Shape")
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape_node.shape
	params.transform = shape_node.global_transform
	params.motion = dir * reach
	params.exclude = [drone.get_rid()]
	var hit := drone.get_world_3d().direct_space_state.cast_motion(params)
	if hit.is_empty() or hit[0] >= 1.0:
		return INF
	return hit[0] * reach
