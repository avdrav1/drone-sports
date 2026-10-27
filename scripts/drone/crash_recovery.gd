class_name CrashRecovery
extends Node
# Watches its parent Drone for a crash it cannot fly out of: tipped past
# `stuck_tilt` and all but still for `stuck_time`, e.g. pinned to a wall by its
# own thrust or turned over on the ground. Then the drone goes back, upright and
# at rest, to where it was last flying level, at least `rewind` seconds ago.
# Never applies forces: the drone's own recover() moves it, like a reset.

@export var stuck_tilt := deg_to_rad(60.0)
## Below this speed (m/s) and spin (rad/s) a tipped drone counts as stuck.
@export var stuck_speed := 0.5
@export var stuck_time := 1.5
## A level drone is remembered as safe below this tilt.
@export var safe_tilt := deg_to_rad(30.0)
## How far back the safe point is taken from, s.
@export var rewind := 1.0
## Height added to the safe point, m.
@export var lift := 0.5

const SNAPSHOT_EVERY := 0.25
const SNAPSHOTS := 16

## Seconds the drone has been stuck so far.
var stuck_for := 0.0
## Recoveries this run.
var count := 0
var _snapshots: Array = []  # [time, position, yaw], oldest first
var _time := 0.0
var _since_snapshot := 0.0

func drone() -> Drone:
	return get_parent() as Drone

func _physics_process(delta: float) -> void:
	var d := drone()
	if d == null or d.freeze:
		stuck_for = 0.0
		return
	_time += delta
	var tilt := FlightControl.tilt(d)
	_since_snapshot += delta
	if tilt < safe_tilt and _since_snapshot >= SNAPSHOT_EVERY:
		_since_snapshot = 0.0
		var fwd := -d.global_transform.basis.z
		_snapshots.append([_time, d.global_position, atan2(-fwd.x, -fwd.z)])
		if _snapshots.size() > SNAPSHOTS:
			_snapshots.pop_front()
	var still := d.linear_velocity.length() < stuck_speed and d.angular_velocity.length() < stuck_speed * 2.0
	stuck_for = stuck_for + delta if tilt > stuck_tilt and still else 0.0
	if stuck_for >= stuck_time:
		recover()

## Put the drone back at the last safe point now.
func recover() -> void:
	var d := drone()
	# With no safe point yet, lift straight up where it lies.
	var at := d.global_position + Vector3.UP * 1.5
	var fwd := -d.global_transform.basis.z
	var yaw := atan2(-fwd.x, -fwd.z) if Vector2(fwd.x, fwd.z).length() > 0.1 else 0.0
	for i in range(_snapshots.size() - 1, -1, -1):
		if _time - _snapshots[i][0] >= rewind:
			at = _snapshots[i][1] + Vector3.UP * lift
			yaw = _snapshots[i][2]
			break
	stuck_for = 0.0
	count += 1
	d.recover(Transform3D(Basis(Vector3.UP, yaw), at))

func reset() -> void:
	_snapshots.clear()
	stuck_for = 0.0
