class_name Brake
extends Assist
# Velocity mode for new pilots. Pitch and roll sticks ask for a ground speed
# along the drone's heading; released, the drone leans against its drift and
# stops. Yaw asks for a turn rate; released, the turn stops.
# Runs first in the pipeline and hands auto-level the tilt to hold, so it only
# makes sense with auto-level on (both come off in Act 3).

## Ground speed at full stick, m/s.
@export var max_speed := 8.0
## Most tilt the brake will ask auto-level for.
@export var max_tilt := deg_to_rad(25.0)
## Speed error to acceleration, 1/s.
@export var speed_gain := 1.5
## Turn rate at full yaw stick, rad/s.
@export var max_yaw_rate := deg_to_rad(90.0)
## Yaw stick per rad/s of turn rate error.
@export var yaw_gain := 3.0

## Ground speed (m/s) above which released sticks count as the brake stopping the drone.
@export var stop_speed := 1.5

## True on frames where the sticks are released and the brake is stopping the drone.
var stopping := false

## Tilt auto-level gives at full stick when there is none to ask.
const FALLBACK_ANGLE := deg_to_rad(35.0)

func _init() -> void:
	assist_id = &"brake"

func apply(intent: Intent, drone: Drone, _delta: float) -> void:
	var b := drone.global_transform.basis
	var fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	var stick := Vector2(intent.pitch, intent.roll).limit_length(1.0)
	var want := (fwd * stick.x + right * stick.y) * max_speed
	var v := FlightControl.horizontal_velocity(drone)
	stopping = stick.length() < 0.1 and v.length() > stop_speed
	# Pull toward the wanted velocity and cancel drag on the way.
	var accel := speed_gain * (want - v) + v * drone.drag / drone.mass
	var tilt := FlightControl.tilt_for_accel(drone, accel)
	var level_angle := _level_angle()
	intent.pitch = clampf(tilt.x, -max_tilt, max_tilt) / level_angle
	intent.roll = clampf(tilt.y, -max_tilt, max_tilt) / level_angle
	# Yaw right is clockwise seen from above: negative about world up.
	var rate := -drone.angular_velocity.y
	intent.yaw = clampf(yaw_gain * (intent.yaw * max_yaw_rate - rate), -1.0, 1.0)

func _level_angle() -> float:
	for a in (get_parent() as AssistPipeline).assists() if get_parent() is AssistPipeline else []:
		if a is AutoLevel:
			return a.max_angle
	return FALLBACK_ANGLE
