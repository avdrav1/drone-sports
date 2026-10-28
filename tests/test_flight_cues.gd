extends RefCounted
# Story 14.3: flight events. Crash recovery, low battery, the guard or brake
# cutting in, and a camera view change each play their sound once, and only on
# their event.

const Sim = preload("res://tests/sim.gd")
const GuardTest = preload("res://tests/test_collision_guard.gd")
const CUES: Array[StringName] = [&"flight_recovered", &"flight_low_battery", &"flight_guard", &"flight_brake", &"camera_view"]

## A camera rig following `d`, added to the tree.
func _rig(d: Drone) -> CameraRig:
	var rig: CameraRig = load("res://scenes/camera/camera_rig.tscn").instantiate()
	rig.target = d
	Sim.add(rig)
	return rig

## True when `id` played `times` and no other flight cue played at all.
func _only(id: StringName, times: int) -> bool:
	for c in CUES:
		var want := times if c == id else 0
		if Sfx.count(c) != want:
			print("        %s played %d, wanted %d" % [c, Sfx.count(c), want])
			return false
	return true

## A drone with no intent source, so assists do not run and their flags stay as set.
func _still_drone() -> Drone:
	var d: Drone = Sim.DRONE.instantiate()
	Sim.add(d)
	d.global_position = Vector3(0, 50, 0)
	d.freeze = true
	return d

func test_quiet_flight_plays_nothing() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 30, 0))
	var rig := _rig(d)
	Sfx.clear_log()
	await Sim.physics_frames(60)
	var ok := _only(&"", 0)
	rig.free()
	d.free()
	return ok

func test_recovery_plays_once() -> bool:
	var d := _still_drone()
	var rig := _rig(d)
	await Sim.physics_frames(2)
	Sfx.clear_log()
	d.recover(Transform3D(Basis.IDENTITY, Vector3(0, 40, 0)))
	await Sim.physics_frames(30)
	var ok := _only(&"flight_recovered", 1)
	d.recover(Transform3D(Basis.IDENTITY, Vector3(0, 40, 0)))
	ok = ok and _only(&"flight_recovered", 2)
	rig.free()
	d.free()
	return ok

func test_low_battery_plays_once_when_it_turns_low() -> bool:
	var d := _still_drone()
	d.battery = 0.5
	var rig := _rig(d)
	await Sim.physics_frames(2)
	Sfx.clear_log()
	d.battery = 0.3
	await Sim.physics_frames(10)
	var ok := _only(&"", 0)
	d.battery = 0.19
	await Sim.physics_frames(10)
	d.battery = 0.05
	await Sim.physics_frames(10)
	ok = ok and _only(&"flight_low_battery", 1)
	# A fresh battery rearms it.
	d.battery = 1.0
	await Sim.physics_frames(2)
	d.battery = 0.1
	await Sim.physics_frames(2)
	ok = ok and _only(&"flight_low_battery", 2)
	rig.free()
	d.free()
	return ok

func test_switching_to_a_low_drone_is_not_an_event() -> bool:
	var a := _still_drone()
	var b := _still_drone()
	b.battery = 0.1
	var rig := _rig(a)
	await Sim.physics_frames(2)
	Sfx.clear_log()
	rig.target = b
	await Sim.physics_frames(5)
	var ok := _only(&"", 0)
	rig.free()
	a.free()
	b.free()
	return ok

func test_guard_cut_in_plays_once_per_event() -> bool:
	var d := _still_drone()
	var guard: CollisionGuard = d.assists.get_node("CollisionGuard")
	guard.enabled = true
	var rig := _rig(d)
	await Sim.physics_frames(2)
	Sfx.clear_log()
	guard.braking = true
	await Sim.physics_frames(10)
	# A flicker off and back on is the same event.
	guard.braking = false
	await Sim.physics_frames(5)
	guard.braking = true
	await Sim.physics_frames(10)
	var ok := _only(&"flight_guard", 1)
	guard.braking = false
	await Sim.physics_frames(60)
	guard.braking = true
	await Sim.physics_frames(2)
	ok = ok and _only(&"flight_guard", 2)
	# Switched off, a stale flag is not the guard cutting in.
	guard.braking = false
	await Sim.physics_frames(60)
	guard.enabled = false
	guard.braking = true
	await Sim.physics_frames(5)
	ok = ok and _only(&"flight_guard", 2)
	rig.free()
	d.free()
	return ok

func test_guard_at_a_wall_plays_once() -> bool:
	var gt := GuardTest.new()
	var wall := gt._wall()
	var d := gt._launch(gt._guard_stack())
	var rig := _rig(d)
	Sfx.clear_log()
	var braked := false
	for i in 240:
		await Sim.physics_frames(1)
		braked = braked or (d.assists.get_node("CollisionGuard") as CollisionGuard).braking
	var ok: bool = braked and _only(&"flight_guard", 1)
	rig.free()
	d.free()
	wall.free()
	return ok

func test_brake_plays_once_when_released_sticks_stop_the_drift() -> bool:
	var s := Sim.all_off()
	s.auto_level = true
	s.altitude_hold = true
	s.brake = true
	var d := Sim.drone(Sim.intent(0.0, 1.0), Vector3(0, 30, 0), s)
	var rig := _rig(d)
	Sfx.clear_log()
	# Held stick: flying, not braking.
	await Sim.physics_frames(120)
	var ok := _only(&"", 0)
	# Released: the brake pulls the drone to a stop, once.
	d.intent_source.value = Sim.intent()
	await Sim.physics_frames(180)
	var brake: Brake = d.assists.get_node("Brake")
	ok = ok and _only(&"flight_brake", 1) and not brake.stopping
	rig.free()
	d.free()
	return ok

func test_view_change_plays_once_per_change() -> bool:
	var d := _still_drone()
	var rig := _rig(d)
	await Sim.physics_frames(2)
	Sfx.clear_log()
	rig.use_default_view() # already the view: no change
	var ok := _only(&"", 0)
	rig.set_view(CameraRig.View.FPV)
	rig.set_view(CameraRig.View.FPV)
	ok = ok and _only(&"camera_view", 1)
	rig.cycle()
	ok = ok and _only(&"camera_view", 2) and Sfx.log.back().bus == &"UI"
	rig.free()
	d.free()
	return ok
