class_name AiPilot
extends IntentSource
# Flies a Course like a player would: through the same Intent and assists.
# Expects angle mode (auto-level) and altitude hold on, as in Act 1.
# Follows a spline through the gate centres, aiming a little ahead: closed for a
# loop, open with a run-out past the finish for a path.
# Seeded: the same seed flies the same race.

@export var course: Course
@export var seed := 1
## Cruise speed, m/s. Each racer flies a seeded fraction of it.
@export var cruise_speed := 10.0
## Slowest seeded pace as a fraction of cruise.
@export var min_pace := 0.97
## Slow wobble on speed, as a fraction.
@export var speed_noise := 0.03
## Chance per gate of lining up near the edge and clipping the frame.
@export var clip_chance := 0.05
@export var lookahead := 4.0
## Sideways offset from the racing line, m. Keeps racers out of each other's wake.
@export var lane := 0.0
## Racers closer than this ahead on our line are steered around, m.
@export var avoid_distance := 6.0
## Below this speed for stuck_time seconds, back off and climb before carrying on.
@export var stuck_speed := 1.0
@export var stuck_time := 1.0
## How long a recovery lasts, s.
@export var recover_time := 1.0
## On an open course, how far the line runs on past the finish gate, m.
@export var run_out := 15.0

## Matches AutoLevel.max_angle: stick 1 asks for this tilt.
const STICK_ANGLE := deg_to_rad(35.0)
## Matches AltitudeHold.climb_rate: stick 1 asks for this climb.
const STICK_CLIMB := 4.0

var drone: Drone
var curve := Curve3D.new()
var pace := 1.0
var rng := RandomNumberGenerator.new()
var _time := 0.0
var _phase := 0.0
## Lateral offset (m, along the gate's x) chosen for each gate on approach.
var _gate_offset := {}
var _aimed_gate := -1
var _slow_for := 0.0
var _recover_left := 0.0

func _ready() -> void:
	drone = get_parent() as Drone
	rng.seed = seed
	pace = rng.randf_range(min_pace, 1.0)
	_phase = rng.randf() * TAU
	if course:
		_build_curve.call_deferred()

func _build_curve() -> void:
	curve.clear_points()
	var gates := course.gates
	var n := gates.size()
	var closed := course.is_closed()
	for i in (n + 1 if closed else n):
		var g: Gate = gates[i % n]
		var fwd: Vector3 = -g.global_transform.basis.z
		# A third of each leg's length keeps the spline on the arc the gates sit on.
		var back := run_out / 3.0 if not closed and i == 0 \
			else g.global_position.distance_to(gates[(i - 1 + n) % n].global_position) / 3.0
		var ahead := run_out / 3.0 if not closed and i == n - 1 \
			else g.global_position.distance_to(gates[(i + 1) % n].global_position) / 3.0
		curve.add_point(g.global_position, -fwd * back, fwd * ahead)
	if not closed:
		# Fly on through the finish instead of braking in it.
		var last: Gate = gates[n - 1]
		var out: Vector3 = -last.global_transform.basis.z * run_out
		curve.add_point(last.global_position + out, -out / 3.0)

func reset() -> void:
	_gate_offset.clear()
	_aimed_gate = -1
	_slow_for = 0.0
	_recover_left = 0.0

func read_intent() -> Intent:
	if drone == null or curve.point_count < 2:
		return Intent.new()
	var dt := 1.0 / Engine.physics_ticks_per_second
	_time += dt
	var pos := drone.global_position
	var length := curve.get_baked_length()
	var at := curve.get_closest_offset(pos)
	var speed := cruise_speed * pace * (1.0 + speed_noise * sin(_time * 0.7 + _phase))
	var ahead := _along(at + lookahead + speed * 0.3, length)
	var target := curve.sample_baked(ahead)
	var tangent := curve.sample_baked(_along(ahead + 1.0, length)) - target
	var side := Vector3(-tangent.z, 0.0, tangent.x).normalized()
	target += side * lane * _lane_weight(pos) + _avoid(pos, target)
	target = _keep_in_gate(pos, target) + _clip_offset(pos)
	var p = course.progress(drone)
	if p and p.finished and not course.is_closed():
		# Past the finish of a path: settle at the end of the run-out.
		return steer(drone, curve.sample_baked(length), 0.0)
	_slow_for = _slow_for + dt if drone.linear_velocity.length() < stuck_speed else 0.0
	if _slow_for > stuck_time:
		_slow_for = 0.0
		_recover_left = recover_time
	if _recover_left > 0.0:
		# Stuck on something: back away from the line and climb.
		_recover_left -= dt
		var back := pos - (target - pos).normalized() * 3.0
		target = Vector3(back.x, pos.y + 2.0, back.z)
		speed = 3.0
	return steer(drone, target, speed)

## A distance along the line: wrapped round a loop, held at the end of a path.
func _along(d: float, length: float) -> float:
	return fmod(d, length) if course.is_closed() else minf(d, length)

## Sticks that carry `d` toward `target` at `speed` m/s: tilt for the horizontal
## velocity, an altitude-hold climb for height, and yaw to face the way it goes.
## Needs auto-level and altitude hold on. Shared with Autopilot (Story 6.1).
static func steer(d: Drone, target: Vector3, speed: float) -> Intent:
	var intent := Intent.new()
	var pos := d.global_position
	# Horizontal: accelerate toward the speed we want along the line.
	var to := target - pos
	var dir := Vector3(to.x, 0.0, to.z).normalized()
	var accel := (dir * speed - FlightControl.horizontal_velocity(d)) * 2.0
	var tilt := FlightControl.tilt_for_accel(d, accel)
	intent.pitch = clampf(tilt.x / STICK_ANGLE, -1.0, 1.0)
	intent.roll = clampf(tilt.y / STICK_ANGLE, -1.0, 1.0)
	# Vertical: ask altitude hold for a climb rate toward the line.
	intent.throttle = clampf(to.y * 1.5 / STICK_CLIMB, -1.0, 1.0)
	# Yaw: face where we are going; holding on the spot, just stop turning.
	var b := d.global_transform.basis
	var fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	var err := fwd.signed_angle_to(dir, Vector3.UP) if Vector2(to.x, to.z).length() > 1.0 else 0.0
	intent.yaw = clampf(-err * 2.0 + FlightControl.body_rate(d).y * 0.3, -1.0, 1.0)
	return intent

## Steer to the side and up around racers just ahead on our line.
func _avoid(pos: Vector3, target: Vector3) -> Vector3:
	var dir := target - pos
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		return Vector3.ZERO
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0.0, dir.x)
	var out := Vector3.ZERO
	for other in course.racers():
		if other == drone:
			continue
		var rel: Vector3 = other.global_position - pos
		var along := rel.dot(dir)
		var across := rel.dot(side)
		if along > 0.0 and along < avoid_distance and absf(across) < 1.5 and absf(rel.y) < 1.5:
			var push := (1.5 - absf(across)) * (1.0 - along / avoid_distance)
			out += side * (-signf(across) if across != 0.0 else 1.0) * push * 2.0 + Vector3.UP * push
	return out

## Close to the next gate, keep the aim inside its opening whatever lanes and avoidance asked.
func _keep_in_gate(pos: Vector3, target: Vector3) -> Vector3:
	var p = course.progress(drone)
	if p == null:
		return target
	var gate: Gate = course.gates[p.next]
	if pos.distance_to(gate.global_position) > 10.0:
		return target
	var local := gate.global_transform.affine_inverse() * target
	var margin := 0.5
	local.x = clampf(local.x, -gate.size.x * 0.5 + margin, gate.size.x * 0.5 - margin)
	local.y = clampf(local.y, -gate.size.y * 0.5 + margin, gate.size.y * 0.5 - margin)
	return gate.global_transform * local

## Lanes narrow to the centre line near a gate so every lane fits the opening.
func _lane_weight(pos: Vector3) -> float:
	var p = course.progress(drone)
	if p == null:
		return 1.0
	var d := pos.distance_to(course.gates[p.next].global_position)
	return clampf((d - 3.0) / 10.0, 0.4, 1.0)

## Near the next gate, shift the aim sideways if this gate was rolled as a clip.
func _clip_offset(pos: Vector3) -> Vector3:
	var p = course.progress(drone)
	if p == null:
		return Vector3.ZERO
	var gate: Gate = course.gates[p.next]
	if gate.index != _aimed_gate:
		_aimed_gate = gate.index
		if not _gate_offset.has(gate.index):
			var clip := rng.randf() < clip_chance
			# Body half-width is 0.2 m: this grazes the frame by a few centimetres.
			_gate_offset[gate.index] = (gate.size.x * 0.5 - 0.17) * (1.0 if rng.randf() < 0.5 else -1.0) if clip else 0.0
	var offset: float = _gate_offset[gate.index]
	if offset == 0.0 or pos.distance_to(gate.global_position) > 6.0:
		return Vector3.ZERO
	return gate.global_transform.basis.x * offset
