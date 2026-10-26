class_name AutoLevel
extends Assist
# Angle mode: pitch and roll sticks ask for a tilt angle instead of a spin.
# Released sticks ask for zero tilt, so the drone levels itself.

## Tilt at full stick deflection.
@export var max_angle := deg_to_rad(35.0)

func _init() -> void:
	assist_id = &"auto_level"

func apply(intent: Intent, drone: Drone, _delta: float) -> void:
	var sticks := FlightControl.attitude_sticks(drone, intent.pitch * max_angle, intent.roll * max_angle)
	intent.pitch = sticks.x
	intent.roll = sticks.y
