class_name PropWash
extends CPUParticles3D
# Sand kicked up under the drone when it flies low with thrust on. Visual only:
# reads the parent Drone and casts a ray down; never touches physics.

## Dust starts within this height above the ground, m.
@export var max_height := 3.0
## Total thrust fraction below which there is no dust.
@export var min_thrust := 0.1

var drone: Drone
## How hard the wash blows this tick, 0 when there is none: closeness to the
## ground times thrust. DroneSound reads it.
var strength := 0.0

func _ready() -> void:
	drone = get_parent() as Drone
	top_level = true
	emitting = false

func _physics_process(_delta: float) -> void:
	if drone == null:
		return
	var from := drone.global_position
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * max_height)
	ray.exclude = [drone.get_rid()]
	var hit := drone.get_world_3d().direct_space_state.intersect_ray(ray)
	var thrust := 0.0
	for t in drone.motor_thrusts:
		thrust += clampf(t, 0.0, drone.max_thrust)
	thrust = thrust / (drone.max_thrust * Drone.MOTOR_COUNT) * drone.power()
	emitting = not hit.is_empty() and thrust >= min_thrust
	strength = 0.0
	if emitting:
		global_position = hit.position + Vector3.UP * 0.05
		# Thicker the closer and harder the drone pushes.
		var closeness := 1.0 - from.distance_to(hit.position) / max_height
		strength = closeness * thrust
		speed_scale = 0.6 + strength
