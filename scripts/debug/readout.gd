extends Label
# Debug readout: position, velocity, and active assists of `subject`, refreshed every frame.

@export var subject: Node3D
## First line, set by whoever owns the readout (e.g. the active preset).
var header := ""

var frames_updated := 0
var _last_position := Vector3.ZERO

func _process(delta: float) -> void:
	frames_updated += 1
	if subject == null:
		text = "no subject"
		return
	var pos := subject.global_position
	var vel: Vector3 = subject.linear_velocity if subject is RigidBody3D else (pos - _last_position) / maxf(delta, 0.0001)
	_last_position = pos
	text = (header + "\n" if header else "") + "pos  %6.2f %6.2f %6.2f\nvel  %6.2f %6.2f %6.2f  (%.1f m/s)\nassists: %s" % [
		pos.x, pos.y, pos.z, vel.x, vel.y, vel.z, vel.length(), _assists()]
	if subject is Drone:
		text += "\nbattery %3d%%  wind %.1f m/s  throttle %+.2f" % [roundi(subject.battery * 100.0),
			subject.wind_velocity().length(), subject.intent.throttle]

func _assists() -> String:
	if subject.has_method("assist_summary"):
		return subject.assist_summary()
	return "(none)"
