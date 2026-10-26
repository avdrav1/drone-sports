class_name FlightControl
extends RefCounted
# Read-only attitude math shared by assists. Turns a wanted attitude into
# pitch/roll stick values; never touches physics.

## PD gains from attitude error (rad) and body rate (rad/s) to stick.
## Scaled by stick authority so the closed loop is the same whatever torque a stick gives.
const KP := 0.54 / Mixer.STICK_AUTHORITY
const KD := 0.05625 / Mixer.STICK_AUTHORITY
const MAX_TILT := deg_to_rad(45.0)

## Nose-down angle in radians (positive is nose down).
static func pitch_angle(drone: Drone) -> float:
	return asin(clampf(drone.global_transform.basis.z.y, -1.0, 1.0))

## Right-side-down angle in radians.
static func roll_angle(drone: Drone) -> float:
	return asin(clampf(-drone.global_transform.basis.x.y, -1.0, 1.0))

static func tilt(drone: Drone) -> float:
	return acos(clampf(drone.global_transform.basis.y.y, -1.0, 1.0))

static func body_rate(drone: Drone) -> Vector3:
	return drone.global_transform.basis.inverse() * drone.angular_velocity

## Stick pitch and roll that drive the drone toward the target angles.
static func attitude_sticks(drone: Drone, target_pitch: float, target_roll: float) -> Vector2:
	var rate := body_rate(drone)
	# Nose-down rate is -x, roll-right rate is -z in body axes.
	var p := KP * (target_pitch - pitch_angle(drone)) - KD * -rate.x
	var r := KP * (target_roll - roll_angle(drone)) - KD * -rate.z
	return Vector2(clampf(p, -1.0, 1.0), clampf(r, -1.0, 1.0))

## Target pitch and roll that produce a horizontal acceleration (world, m/s²).
static func tilt_for_accel(drone: Drone, accel: Vector3) -> Vector2:
	var b := drone.global_transform.basis
	var fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	var g := drone.gravity()
	return Vector2(
		clampf(atan(accel.dot(fwd) / g), -MAX_TILT, MAX_TILT),
		clampf(atan(accel.dot(right) / g), -MAX_TILT, MAX_TILT))

static func horizontal_velocity(drone: Drone) -> Vector3:
	var v := drone.linear_velocity
	return Vector3(v.x, 0.0, v.z)
