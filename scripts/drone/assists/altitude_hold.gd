class_name AltitudeHold
extends Assist
# Throttle stick asks for a climb rate. Centered, the drone brakes its climb or
# sink, then holds the height where it stopped. Compensates for tilt.

## Climb rate at full throttle stick, m/s.
@export var climb_rate := 4.0
## Throttle within this of center counts as centered.
@export var deadzone := 0.05
## Below this climb rate a centered stick locks the height, m/s.
@export var lock_rate := 0.2
## Height error to climb rate, 1/s.
@export var height_gain := 2.0
## Climb rate error to acceleration, 1/s.
@export var rate_gain := 4.0

var target_height := 0.0
var _holding := false
var _last_frame := -1

func _init() -> void:
	assist_id = &"altitude_hold"

func apply(intent: Intent, drone: Drone, _delta: float) -> void:
	var frame := Engine.get_physics_frames()
	if frame - _last_frame > 1:
		_holding = false # just switched on: hold where we are now
	_last_frame = frame
	var y := drone.global_position.y
	var wanted_rate: float
	if absf(intent.throttle) > deadzone:
		_holding = false
		wanted_rate = intent.throttle * climb_rate
	elif not _holding and absf(drone.linear_velocity.y) > lock_rate:
		wanted_rate = 0.0
	else:
		if not _holding:
			_holding = true
			target_height = y
		wanted_rate = clampf(height_gain * (target_height - y), -climb_rate, climb_rate)
	var accel := rate_gain * (wanted_rate - drone.linear_velocity.y)
	var lift := drone.mass * (drone.gravity() + accel) / maxf(cos(FlightControl.tilt(drone)), 0.5)
	intent.throttle = clampf(Mixer.hover_throttle(lift / Drone.MOTOR_COUNT, drone.max_thrust), -1.0, 1.0)
