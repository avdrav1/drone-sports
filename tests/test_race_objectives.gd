extends RefCounted
# Story 3.2: race objectives and the race job.

const Sim = preload("res://tests/sim.gd")

## A job rig with a test course, three stand-in opponents, and the race objectives.
## Returns [root, course, opponents].
func _setup() -> Array:
	var job: Job = load("res://data/jobs/test_race.tres").duplicate()
	var place := FinishPosition.new()
	place.name = "FinishPosition"
	var clean := CleanLap.new()
	clean.name = "CleanLap"
	var split := BestSplit.new()
	split.name = "BestSplit"
	var root := Sim.job_setup(job, [place, clean, split])
	var course := Course.new()
	course.data = load("res://data/courses/test_loop.tres")
	root.add_child(course)
	for o in [place, clean, split]:
		o.course = course
	var d: Drone = root.get_node("Drone")
	d.global_position = course.gates[0].global_transform * Vector3(0, 0, 4)
	course.add_racer(d)
	var opponents := []
	for i in 3:
		var r := Node3D.new()
		root.add_child(r)
		r.global_position = d.global_position
		course.add_racer(r)
		opponents.append(r)
	return [root, course, opponents]

func _through(r: Node3D, g: Gate) -> void:
	r.global_position = g.global_transform * Vector3(0, 20, 1.5)
	await Sim.physics_frames(1)
	r.global_position = g.global_transform * Vector3(0, 0, 1.5)
	await Sim.physics_frames(1)
	r.global_position = g.global_transform * Vector3(0, 0, -1.5)
	await Sim.physics_frames(1)

func _race(c: Course, r: Node3D) -> void:
	await _through(r, c.gates[0])
	for lap in c.laps():
		for i in range(1, c.gates.size()):
			await _through(r, c.gates[i])
		await _through(r, c.gates[0])

func _go(root: Node, course: Course) -> JobRunner:
	await Sim.go_live(root)
	var runner: JobRunner = root.get_node("Runner")
	runner.drone.freeze = true # moved by hand below
	course.start()
	return runner

func test_weights_come_from_job() -> bool:
	var s := _setup()
	var runner: JobRunner = s[0].get_node("Runner")
	runner.begin()
	var ok: bool = runner.get_node("FinishPosition").weight == 3.0 and runner.get_node("CleanLap").weight == 1.0
	s[0].free()
	return ok

func test_first_place_clean_run_grades_a() -> bool:
	var s := _setup()
	var course: Course = s[1]
	var runner: JobRunner = await _go(s[0], course)
	await _race(course, runner.drone)
	await Sim.physics_frames(2)
	var ok: bool = runner.state == JobRunner.State.COMPLETE and runner.result.letter == "A"
	s[0].free()
	return ok

func test_last_place_with_contact_grades_at_most_d() -> bool:
	var s := _setup()
	var course: Course = s[1]
	var runner: JobRunner = await _go(s[0], course)
	for r in s[2]:
		await _race(course, r)
	runner.drone.body_entered.emit(course.gates[3])
	await _race(course, runner.drone)
	await Sim.physics_frames(2)
	var ok: bool = runner.state == JobRunner.State.COMPLETE and runner.result.letter in ["D", "F"] \
		and course.place_of(runner.drone) == 4
	s[0].free()
	return ok

func test_race_scene_loads() -> bool:
	var scene: Node = Sim.add(load("res://scenes/jobs/test_race.tscn").instantiate())
	await Sim.process_frames(3)
	var course: Course = scene.get_node("Course")
	var ok: bool = course.gates.size() == 8 and course.racers().has(scene.get_node("Drone")) \
		and scene.get_node("JobRunner").state == JobRunner.State.BRIEFING
	scene.free()
	return ok
