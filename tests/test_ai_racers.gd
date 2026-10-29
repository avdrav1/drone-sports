extends RefCounted
# Story 3.3: AI racers fly the course through the same drone and assists as the player.

const Sim = preload("res://tests/sim.gd")
const LANES := [-1.0, 1.0, 0.0]
const STARTS := [Vector3(-1.6, 3, -34), Vector3(1.6, 3, -34), Vector3(0, 3, -36.5)]

## Runs three AI racers on the test course. Returns {times, laps, out_of_bounds}.
func _race(seed: int) -> Dictionary:
	var root := Node3D.new()
	Sim.add(root)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	floor.add_child(shape)
	root.add_child(floor)
	var course := Course.new()
	course.data = load("res://data/courses/test_loop.tres")
	root.add_child(course)
	var drones: Array[Drone] = []
	for i in 3:
		var d: Drone = Sim.DRONE.instantiate()
		var ai := AiPilot.new()
		ai.course = course
		ai.seed = seed + i
		ai.lane = LANES[i]
		d.add_child(ai)
		d.intent_source = ai
		root.add_child(d)
		d.assists.apply_stack(load("res://data/assists/act1.tres"))
		d.global_position = STARTS[i]
		course.add_racer(d)
		drones.append(d)
	await Sim.physics_frames(1)
	course.start()
	var out := 0
	for f in 60 * 120:
		await Sim.physics_frames(1)
		for d in drones:
			if not course.data.bounds.has_point(d.global_position):
				out += 1
		if course.finish_order.size() == 3:
			break
	var times := []
	var laps := []
	for d in drones:
		var p = course.progress(d)
		times.append(p.finish_time if p.finished else INF)
		laps.append(p.lap_times.duplicate())
	root.free()
	return {"times": times, "laps": laps, "out_of_bounds": out}

func test_opponents_finish_close_and_in_bounds() -> bool:
	var r := await _race(100)
	var t: Array = r.times
	var spread: float = (t.max() - t.min()) / t.min()
	return t.max() < INF and spread <= 0.10 and r.out_of_bounds == 0

func test_lap_times_repeat_with_seed() -> bool:
	var a := await _race(200)
	var b := await _race(200)
	return a.laps == b.laps and a.laps[0].size() == 2

func test_race_scene_has_three_opponents() -> bool:
	var scene: Node = Sim.add(load("res://scenes/jobs/test_race.tscn").instantiate())
	await Sim.process_frames(3)
	var course: Course = scene.get_node("Course")
	var ok: bool = course.racers().size() == 4
	for i in 3:
		var d: Drone = scene.get_node("Opponent%d" % (i + 1))
		ok = ok and d.intent_source is AiPilot and d.freeze
	scene.free()
	return ok

## The racing line follows the arcs the gates sit on: no kink at a gate that
## turns tighter than the course's tightest bend (the hairpin, about 3 deg/m).
func test_racing_line_has_no_kinks() -> bool:
	var root: Node3D = Sim.add(Node3D.new())
	var course := Course.new()
	course.data = load("res://data/courses/test_loop.tres")
	root.add_child(course)
	var d: Drone = Sim.DRONE.instantiate()
	var ai := AiPilot.new()
	ai.course = course
	d.add_child(ai)
	d.intent_source = ai
	root.add_child(d)
	await Sim.physics_frames(2)
	var length := ai.curve.get_baked_length()
	var worst := 0.0
	var at := 1.0
	while at < length - 1.0:
		var a := ai.curve.sample_baked(at) - ai.curve.sample_baked(at - 1.0)
		var b := ai.curve.sample_baked(at + 1.0) - ai.curve.sample_baked(at)
		a.y = 0.0
		b.y = 0.0
		worst = maxf(worst, rad_to_deg(a.angle_to(b)))
		at += 0.5
	root.free()
	return worst > 0.0 and worst < 4.0
