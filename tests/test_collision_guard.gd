extends RefCounted
# Story 1.4: collision guard.

const Sim = preload("res://tests/sim.gd")
const WALL_FACE_Z := -30.0
const DRONE_HALF := 0.2

# A pilot who holds 10 m/s straight at the wall (-Z) and level height, whatever happens.
class WallPilot extends IntentSource:
	var drone: Drone
	var speed := 10.0
	func read_intent() -> Intent:
		var i := Intent.new()
		var closing := -drone.linear_velocity.z
		var accel := drone.drag * speed / drone.mass + 4.0 * (speed - closing)
		var t := FlightControl.tilt_for_accel(drone, Vector3(0, 0, -accel))
		var sticks := FlightControl.attitude_sticks(drone, t.x, t.y)
		i.pitch = sticks.x
		i.roll = sticks.y
		var lift := drone.mass * (drone.gravity() - 2.0 * drone.linear_velocity.y) / maxf(cos(FlightControl.tilt(drone)), 0.5)
		i.throttle = Mixer.hover_throttle(lift / 4.0, drone.max_thrust)
		return i

class ContactCounter extends RefCounted:
	var hits := 0
	func on_hit(_body: Node) -> void:
		hits += 1

func _wall() -> StaticBody3D:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(40, 40, 2)
	wall.add_child(shape)
	Sim.add(wall)
	wall.global_position = Vector3(0, 10, WALL_FACE_Z - 1.0)
	return wall

func _guard_stack() -> AssistStack:
	var s := Sim.all_off()
	s.collision_guard = true
	return s

func _hover() -> float:
	return Mixer.hover_throttle(9.8 / 4.0, 4.5)

func _launch(stack: AssistStack) -> Drone:
	var d := Sim.drone(Sim.intent(_hover()), Vector3(0, 10, 0), stack)
	var pilot := WallPilot.new()
	pilot.drone = d
	d.add_child(pilot)
	d.intent_source = pilot
	d.contact_monitor = true
	d.max_contacts_reported = 4
	d.linear_velocity = Vector3(0, 0, -10)
	return d

func _gap(d: Drone) -> float:
	return d.global_position.z - DRONE_HALF - WALL_FACE_Z

# Runs until the drone stops closing on the wall (or 4 s). Returns [gap at stop, hits].
func _fly_at_wall(stack: AssistStack, disable_after_frames := -1) -> Array:
	var wall := _wall()
	var d := _launch(stack)
	var counter := ContactCounter.new()
	d.body_entered.connect(counter.on_hit)
	var stop_gap := INF
	for i in 240:
		await Sim.physics_frames(1)
		if i == disable_after_frames:
			d.assists.get_node("CollisionGuard").enabled = false
		if stop_gap == INF and d.linear_velocity.z >= 0.0:
			stop_gap = _gap(d)
	d.free()
	wall.free()
	return [stop_gap, counter.hits]

func test_stops_within_1m_without_contact() -> bool:
	var r: Array = await _fly_at_wall(_guard_stack())
	print("        stop gap %.2f m, contacts %d" % r)
	return r[0] <= 1.0 and r[0] > 0.0 and r[1] == 0

func test_without_guard_drone_hits_wall() -> bool:
	var r: Array = await _fly_at_wall(Sim.all_off())
	return r[1] > 0

func test_disable_live() -> bool:
	# Guard brakes at first; switched off mid-run the drone is free to drift back into the wall.
	var wall := _wall()
	var d := _launch(_guard_stack())
	var guard: CollisionGuard = d.assists.get_node("CollisionGuard")
	var braked := false
	for i in 120:
		await Sim.physics_frames(1)
		braked = braked or guard.braking
	guard.enabled = false
	var hit := false
	for i in 180:
		await Sim.physics_frames(1)
		hit = hit or _gap(d) < 0.05
	d.free()
	wall.free()
	return braked and hit

func test_no_change_when_clear() -> bool:
	var wanted := Sim.intent(_hover(), 0.3, -0.2, 0.1)
	var d := Sim.drone(wanted, Vector3(0, 10, 0), _guard_stack())
	d.linear_velocity = Vector3(0, 0, -10)
	var ok := true
	for i in 30:
		await Sim.physics_frames(1)
		var got := d.intent
		ok = ok and got.throttle == wanted.throttle and got.pitch == wanted.pitch \
			and got.roll == wanted.roll and got.yaw == wanted.yaw
	d.free()
	return ok
