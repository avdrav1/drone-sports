extends RefCounted
# Story 6.1: autopilot intent source. Waypoints in turn, then a hold.

const Sim = preload("res://tests/sim.gd")

func _fleet_drone(at: Vector3) -> Drone:
	var d: Drone = Sim.DRONE.instantiate()
	var pilot := Autopilot.new()
	pilot.name = "Autopilot"
	d.add_child(pilot)
	d.intent_source = pilot
	Sim.add(d)
	d.global_position = at
	return d

func test_reaches_five_waypoints_then_holds() -> bool:
	var d := _fleet_drone(Vector3(0, 20, 0))
	var pilot: Autopilot = d.get_node("Autopilot")
	var points := PackedVector3Array([Vector3(12, 22, 0), Vector3(12, 26, -14), Vector3(-6, 24, -20),
		Vector3(-14, 18, -4), Vector3(-2, 21, 8)])
	pilot.go_to(points)
	var closest: Array[float] = [INF, INF, INF, INF, INF]
	var reached: Array[int] = []
	pilot.arrived.connect(func(i): reached.append(i))
	var frames := 0
	while not pilot.done() and frames < 60 * 90:
		await Sim.physics_frames(1)
		frames += 1
		var i := mini(pilot.index, 4)
		closest[i] = minf(closest[i], d.global_position.distance_to(points[i]))
	# Holding: stays on the last point for three seconds.
	var drift := 0.0
	for k in 180:
		await Sim.physics_frames(1)
		drift = maxf(drift, d.global_position.distance_to(points[4]))
	var ok := pilot.done() and reached == [0, 1, 2, 3, 4] and closest.all(func(c): return c < 2.0) and drift < 2.0
	if not ok:
		print("        reached %s closest %s drift %.2f in %d frames" % [reached, closest, drift, frames])
	d.free()
	return ok

func test_flies_with_its_own_assists() -> bool:
	var d := _fleet_drone(Vector3(0, 20, 0))
	await Sim.physics_frames(2)
	var a := d.assists
	var ok := a.is_enabled(&"auto_level") and a.is_enabled(&"altitude_hold") and not a.is_enabled(&"brake")
	d.free()
	return ok

func test_queue_after_holding_flies_on() -> bool:
	var d := _fleet_drone(Vector3(0, 20, 0))
	var pilot: Autopilot = d.get_node("Autopilot")
	pilot.go_to(PackedVector3Array([Vector3(4, 20, 0)]))
	for k in 600:
		await Sim.physics_frames(1)
		if pilot.done():
			break
	var held := pilot.done()
	pilot.queue(Vector3(4, 20, -8))
	var flying := not pilot.done()
	for k in 600:
		await Sim.physics_frames(1)
		if pilot.done():
			break
	var ok := held and flying and d.global_position.distance_to(Vector3(4, 20, -8)) < 2.0
	d.free()
	return ok
