extends RefCounted
# Story 3.5: Act 1 framing. Bezel only on act1 jobs; the scout message fires once.

const Sim = preload("res://tests/sim.gd")
const FRAMING := preload("res://data/framing/act1.tres")

## A race rig with three stand-in opponents and a bezel. Returns [root, course, opponents, bezel].
func _setup(tags: Array[StringName]) -> Array:
	var job: Job = load("res://data/jobs/test_race.tres").duplicate()
	job.tags = tags
	var place := FinishPosition.new()
	var root := Sim.job_setup(job, [place])
	var course := Course.new()
	course.data = load("res://data/courses/test_loop.tres")
	root.add_child(course)
	place.course = course
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
	var bezel := ArcadeBezel.new()
	bezel.framing = FRAMING
	bezel.runner = root.get_node("Runner")
	bezel.course = course
	bezel.racer = d
	root.add_child(bezel)
	return [root, course, opponents, bezel]

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

## Runs a race where `ahead` opponents finish before the player. Returns the bezel's scout_shown.
func _run(ahead: int) -> bool:
	var s := _setup([&"act1"])
	var course: Course = s[1]
	await Sim.go_live(s[0])
	var runner: JobRunner = s[0].get_node("Runner")
	runner.drone.freeze = true
	course.start()
	for i in ahead:
		await _race(course, s[2][i])
	await _race(course, runner.drone)
	await Sim.physics_frames(2)
	var shown: bool = s[3].scout_shown
	s[0].free()
	return shown

func _clear_flags() -> void:
	SaveGame.write_section("flags", {})

func test_bezel_only_on_act1_jobs() -> bool:
	var tagged := _setup([&"act1"])
	var plain := _setup([])
	var ok: bool = tagged[3].visible and not plain[3].visible
	tagged[0].free()
	plain[0].free()
	return ok

func test_leaderboard_lists_player_handle() -> bool:
	var s := _setup([&"act1"])
	var handles: Array = s[3].leaderboard().map(func(r): return r.handle)
	var ok := handles.has(PlayerProfile.handle()) and handles.size() == FRAMING.leaderboard.size() + 1
	s[0].free()
	return ok

func test_scout_fires_once_on_first_top_three() -> bool:
	_clear_flags()
	var first := await _run(1)
	var flagged := StoryFlags.is_set(&"scouted")
	var second := await _run(0)
	_clear_flags()
	return first and flagged and not second

func test_no_scout_outside_top_three() -> bool:
	_clear_flags()
	var shown := await _run(3)
	var flagged := StoryFlags.is_set(&"scouted")
	_clear_flags()
	return not shown and not flagged
