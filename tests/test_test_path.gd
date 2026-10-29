extends RefCounted
# Story 22.1: the test race is a point-to-point path that teaches in three parts:
# heights on a straight, then growing turns at one height, then both together.

const Sim = preload("res://tests/sim.gd")
const PATH := "res://data/courses/test_path.tres"
const LANES := [-1.0, 1.0, 0.0]

## Heading of a gate's pass direction (-Z), radians.
static func _yaw(t: Transform3D) -> float:
	var f := -t.basis.z
	return atan2(-f.x, -f.z)

## Turn at gate i from gate i-1, degrees, signed.
static func _turn(gates: Array[Transform3D], i: int) -> float:
	return rad_to_deg(angle_difference(_yaw(gates[i - 1]), _yaw(gates[i])))

## The path's three parts as gate indices: the straight from the start while the
## heading holds, then gates at the first turn's height, then the rest.
static func _parts(data: CourseData) -> Array:
	var g := data.gates
	var straight: Array[int] = [0]
	var i := 1
	while i < g.size() and absf(_turn(g, i)) < 0.5 and absf(rad_to_deg(angle_difference(_yaw(g[0]), _yaw(g[i])))) < 0.5:
		straight.append(i)
		i += 1
	var turns: Array[int] = []
	var height := g[i].origin.y if i < g.size() else 0.0
	while i < g.size() and is_equal_approx(g[i].origin.y, height):
		turns.append(i)
		i += 1
	var both: Array[int] = []
	while i < g.size():
		both.append(i)
		i += 1
	return [straight, turns, both]

## A plain node standing in for a racer, behind the start gate.
static func _racer(c: Course) -> Node3D:
	var r := Node3D.new()
	c.add_child(r)
	r.global_position = c.gates[0].global_transform * Vector3(0, 0, 4)
	c.add_racer(r)
	return r

## Moves the racer forward through gate g, arriving from above.
static func _through(r: Node3D, g: Gate) -> void:
	r.global_position = g.global_transform * Vector3(0, 20, 1.5)
	await Sim.physics_frames(1)
	r.global_position = g.global_transform * Vector3(0, 0, 1.5)
	await Sim.physics_frames(1)
	r.global_position = g.global_transform * Vector3(0, 0, -1.5)
	await Sim.physics_frames(1)

func test_race_scene_flies_the_open_path() -> bool:
	var scene: Node = Sim.add(load("res://scenes/jobs/test_race.tscn").instantiate())
	await Sim.process_frames(2)
	var course: Course = scene.get_node("Course")
	var hud: RaceHud = scene.get_node("HUD/Race")
	var ok: bool = course.data.resource_path == PATH and not course.is_closed() and course.laps() == 1 \
		and course.finish_gate() == course.gates.size() - 1 and hud.lap_label() == "RUN" \
		and scene.get_node("Gps").map.resource_path == "res://data/maps/test_path.tres"
	# The objectives read "run", not "lap".
	for o in scene.get_node("JobRunner").get_children():
		ok = ok and not (o as Objective).label.to_lower().contains("lap")
	ok = ok and scene.get_node("JobRunner/CleanLap").label.to_lower().contains("run") \
		and scene.get_node("JobRunner/BestSplit").label.to_lower().contains("run")
	# Every racer starts behind the start gate, facing through it.
	for d in course.racers():
		var local: Vector3 = course.gates[0].global_transform.affine_inverse() * d.global_position
		ok = ok and local.z > 0.0 and local.z < 10.0 and absf(local.x) < 2.0
	scene.free()
	return ok

func test_first_part_is_straight_with_three_heights() -> bool:
	var data: CourseData = load(PATH)
	var straight: Array[int] = _parts(data)[0]
	var g := data.gates
	var fwd := -g[0].basis.z
	var heights := {}
	var ok := straight.size() >= 4
	for i in straight:
		heights[snappedf(g[i].origin.y, 0.01)] = true
		# On the start gate's line, ahead of it.
		var rel := g[i].origin - g[0].origin
		rel.y = 0.0
		ok = ok and rel.cross(fwd).length() < 0.01 and rel.dot(fwd) >= 0.0
	return ok and heights.size() >= 3

func test_second_part_turns_grow_at_one_height() -> bool:
	var data: CourseData = load(PATH)
	var turns: Array[int] = _parts(data)[1]
	var ok := turns.size() >= 3
	var last := 0.0
	for i in turns:
		var a := absf(_turn(data.gates, i))
		ok = ok and a > 1.0 and a >= last - 0.01 and is_equal_approx(data.gates[i].origin.y, data.gates[turns[0]].origin.y)
		last = a
	# The turns build to a real bend.
	return ok and last >= 45.0

func test_last_part_changes_heading_and_height() -> bool:
	var data: CourseData = load(PATH)
	var both: Array[int] = _parts(data)[2]
	var ok := both.size() >= 3 and both[-1] == data.gates.size() - 1
	for i in both:
		ok = ok and absf(_turn(data.gates, i)) > 10.0 \
			and absf(data.gates[i].origin.y - data.gates[i - 1].origin.y) >= 0.5
	return ok

## Flyable for Act 1: heights in the gate band the loop used, legs long enough to climb.
func test_path_is_flyable() -> bool:
	var data: CourseData = load(PATH)
	var ok := not data.closed
	for i in data.gates.size():
		var p := data.gates[i].origin
		ok = ok and p.y >= 3.0 and p.y <= 5.0 and data.bounds.has_point(p) \
			and Vector2(p.x, p.z).length() < 140.0
		if i > 0:
			var prev := data.gates[i - 1].origin
			ok = ok and absf(p.y - prev.y) <= 1.0 and p.distance_to(prev) >= 18.0
	return ok

func test_race_ends_at_last_gate_once() -> bool:
	var c := Course.new()
	c.data = load(PATH)
	Sim.add(c)
	var r := _racer(c)
	var finished := []
	var laps := []
	c.racer_finished.connect(func(who, place, _t): finished.append([who, place]))
	c.lap_completed.connect(func(_t, _who, n, valid): laps.append([n, valid]))
	c.start()
	var n := c.gates.size()
	for i in n - 1:
		await _through(r, c.gates[i])
	var before: bool = finished.is_empty() and c.progress(r).next == n - 1
	# Route guidance ends at the finish gate.
	var route := CourseRoute.new()
	route.course = c
	route.drone = r
	c.add_child(route)
	var route_end: bool = route.points() == PackedVector3Array([c.gates[n - 1].global_position])
	await _through(r, c.gates[n - 1])
	var once: bool = finished == [[r, 1]] and laps == [[1, true]] and c.progress(r).finished
	# Flying the start and the finish again changes nothing.
	await _through(r, c.gates[0])
	await _through(r, c.gates[n - 1])
	once = once and finished.size() == 1 and laps.size() == 1 and route.points().is_empty()
	c.free()
	return before and route_end and once

func test_ai_racers_finish_the_path() -> bool:
	var scene: PackedScene = load("res://scenes/jobs/test_race.tscn")
	var starts := []
	var template: Node = scene.instantiate()
	for i in 3:
		starts.append((template.get_node("Opponent%d" % (i + 1)) as Node3D).transform.origin)
	template.free()
	var root := Node3D.new()
	Sim.add(root)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	floor.add_child(shape)
	root.add_child(floor)
	var course := Course.new()
	course.data = load(PATH)
	root.add_child(course)
	var drones: Array[Drone] = []
	for i in 3:
		var d: Drone = Sim.DRONE.instantiate()
		var ai := AiPilot.new()
		ai.course = course
		ai.seed = 11 + i
		ai.lane = LANES[i]
		d.add_child(ai)
		d.intent_source = ai
		root.add_child(d)
		d.assists.apply_stack(load("res://data/assists/act1.tres"))
		d.global_position = starts[i]
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
	var ok: bool = course.finish_order.size() == 3 and out == 0
	for d in drones:
		ok = ok and course.progress(d).laps == 1
	print("        AI finish times: %s" % [drones.map(func(d): return snappedf(course.progress(d).finish_time, 0.01))])
	root.free()
	return ok

## The fleet race moved to the path in Story 22.2; the loop still runs laps.
func test_the_loop_still_runs_laps() -> bool:
	# Round the loop: the first lap ends at the start gate and the race goes on.
	var c := Course.new()
	c.data = load("res://data/courses/test_loop.tres").duplicate()
	c.data.laps = 2
	Sim.add(c)
	var r := _racer(c)
	var hud := RaceHud.new()
	hud.course = c
	hud.racer = r
	c.start()
	await _through(r, c.gates[0])
	for i in range(1, c.gates.size()):
		await _through(r, c.gates[i])
	await _through(r, c.gates[0])
	var p := c.progress(r)
	var ok: bool = p.laps == 1 and not p.finished and hud.lap_label() == "LAP" and hud.lap_text() == "2/2"
	hud.free()
	c.free()
	return ok
