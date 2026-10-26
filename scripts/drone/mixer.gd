class_name Mixer
extends RefCounted
# Pure function from Intent to four motor thrusts. Motor order matches Drone:
# 0 front-left, 1 front-right, 2 back-left, 3 back-right.

## Each stick at full deflection moves a motor by this fraction of max thrust.
const STICK_AUTHORITY := 0.30

static func mix(intent: Intent, max_thrust: float) -> PackedFloat32Array:
	var collective := (clampf(intent.throttle, -1.0, 1.0) + 1.0) * 0.5 * max_thrust
	var d := STICK_AUTHORITY * max_thrust
	var p := clampf(intent.pitch, -1.0, 1.0) * d
	var r := clampf(intent.roll, -1.0, 1.0) * d
	var y := clampf(intent.yaw, -1.0, 1.0) * d
	var out := PackedFloat32Array([
		collective - p + r - y,
		collective - p - r + y,
		collective + p + r + y,
		collective + p - r - y,
	])
	for i in out.size():
		out[i] = clampf(out[i], 0.0, max_thrust)
	return out

## Throttle value whose collective equals hover thrust for a level drone.
static func hover_throttle(hover_thrust: float, max_thrust: float) -> float:
	return 2.0 * hover_thrust / max_thrust - 1.0
