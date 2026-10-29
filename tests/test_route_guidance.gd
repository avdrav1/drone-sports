extends RefCounted
# Story 10.4: GPS route guidance. The race route runs through the remaining
# gates and updates on each pass; the delivery route ends at the drop point;
# a job with no guidance draws no route anywhere.

const Sim = preload("res://tests/sim.gd")

func _gate_positions(c: Course, order: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in order:
		out.append(c.gates[i].global_position)
	return out

func _cross(c: Course, r: Node3D, gate: int) -> void:
	var g: Gate = c.gates[gate]
	r.global_position = g.global_transform * Vector3(0, 20, 1.5)
	await Sim.physics_frames(1)
	r.global_position = g.global_transform * Vector3(0, 0, 1.5)
	await Sim.physics_frames(2)
	r.global_position = g.global_transform * Vector3(0, 0, -1.5)
	await Sim.physics_frames(2)

func test_race_route_follows_remaining_gates() -> bool:
	var root: Node3D = Sim.add(Node3D.new())
	var course := Course.new()
	course.data = load("res://data/courses/test_loop.tres")
	root.add_child(course)
	var r := Node3D.new()
	root.add_child(r)
	r.global_position = course.gates[0].global_transform * Vector3(0, 0, 4)
	course.add_racer(r)
	var route := CourseRoute.new()
	route.course = course
	route.drone = r
	root.add_child(route)
	var before := route.points()
	course.start()
	await _cross(course, r, 0)
	var started := route.points()
	await _cross(course, r, 1)
	var after_one := route.points()
	var guided := route.guided()
	var ok := before == _gate_positions(course, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0]) \
		and started == _gate_positions(course, [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]) \
		and after_one == _gate_positions(course, [2, 3, 4, 5, 6, 7, 8, 9, 0]) \
		and guided.size() == after_one.size() + 1 and guided[0] == r.global_position
	root.free()
	return ok

func test_race_scene_draws_route() -> bool:
	var scene: Node = Sim.add(load("res://scenes/jobs/test_race.tscn").instantiate())
	await Sim.process_frames(3)
	var route: RouteSource = scene.get_node("Route")
	var ribbon: RouteRibbon = scene.get_node("RouteRibbon")
	var radar: Radar = scene.get_node("HUD/Radar")
	var ok: bool = route.guided().size() == 17 and ribbon.dashes > 0 and not radar.route_dots().is_empty()
	scene.free()
	return ok

func test_delivery_route_ends_at_drop_point() -> bool:
	var scene: Node = Sim.add(load("res://scenes/jobs/sample_delivery.tscn").instantiate())
	await Sim.process_frames(3)
	var route: RouteSource = scene.get_node("Route")
	var map: MapScreen = scene.get_node("MapLayer/Map")
	var target: Vector3 = scene.get_node("DropPad/Target").global_position
	var line := route.guided()
	var chart := map.route_chart()
	var ok: bool = line.size() == 2 and line[line.size() - 1] == target \
		and chart[chart.size() - 1].is_equal_approx(map.to_chart(target)) \
		and scene.get_node("RouteRibbon").dashes > 0
	scene.free()
	return ok

func _with_guidance(path: String, g: Job.Guidance) -> Node:
	var scene: Node = load(path).instantiate()
	var runner: JobRunner = scene.get_node("JobRunner")
	runner.job = runner.job.duplicate()
	runner.job.guidance = g
	return Sim.add(scene)

## Marlo is benched in these two: fit, Marlo raises guidance a step (Story 19.6).
func test_no_guidance_draws_no_route() -> bool:
	Roster.injure(&"marlo")
	var ok := true
	for path in ["res://scenes/jobs/sample_delivery.tscn", "res://scenes/jobs/test_race.tscn"]:
		var scene := _with_guidance(path, Job.Guidance.NONE)
		await Sim.process_frames(3)
		var route: RouteSource = scene.get_node("Route")
		var radar: Radar = scene.get_node("HUD/Radar")
		var map: MapScreen = scene.get_node("MapLayer/Map")
		var ribbon: RouteRibbon = scene.get_node("RouteRibbon")
		ok = ok and not route.points().is_empty() and route.guided().is_empty() and radar.route_dots().is_empty() \
			and map.route_chart().is_empty() and ribbon.dashes == 0
		scene.free()
	return ok

func test_next_leg_guidance_shows_one_leg() -> bool:
	Roster.injure(&"marlo")
	var scene := _with_guidance("res://scenes/jobs/test_race.tscn", Job.Guidance.NEXT_LEG)
	await Sim.process_frames(3)
	var route: RouteSource = scene.get_node("Route")
	var line := route.guided()
	var gate0: Vector3 = scene.get_node("Course").gates[0].global_position
	scene.free()
	return line.size() == 2 and line[1] == gate0
