class_name SpeedGovernor
extends Assist
# Caps horizontal speed. Near the cap it blends the sticks toward an attitude
# that holds exactly the cap, so the pilot's push fades out instead of hitting a wall.

## Horizontal speed cap, m/s.
@export var max_speed := 12.0
## Blending starts at this fraction below the cap.
@export var soft_band := 0.15
## Speed error to acceleration, 1/s.
@export var speed_gain := 2.0

func _init() -> void:
	assist_id = &"speed_governor"

func apply(intent: Intent, drone: Drone, _delta: float) -> void:
	var v := FlightControl.horizontal_velocity(drone)
	var speed := v.length()
	var soft_start := max_speed * (1.0 - soft_band)
	if speed <= soft_start:
		return
	var weight := clampf((speed - soft_start) / (max_speed - soft_start), 0.0, 1.0)
	# Acceleration that cancels drag at the cap and pulls speed back toward it.
	var along := drone.drag * max_speed / drone.mass + speed_gain * (max_speed - speed)
	var target := FlightControl.tilt_for_accel(drone, v / speed * along)
	var sticks := FlightControl.attitude_sticks(drone, target.x, target.y)
	intent.pitch = lerpf(intent.pitch, sticks.x, weight)
	intent.roll = lerpf(intent.roll, sticks.y, weight)
