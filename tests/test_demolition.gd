extends RefCounted
# Story 4.2: demolition run. Completable with Act 3 assists along a clear line
# through the windows; a knocked cornice block landing on Bhima is a strike; the
# roof coming down before the exit fails the job; grade A needs zero contact.

const Sim = preload("res://tests/sim.gd")
const SCENE := "res://scenes/jobs/demolition.tscn"
# Through the top window, down the shaft, out the north window.
const PATH := [Vector3(0, 1, 0), Vector3(0, 10.9, -30), Vector3(0, 10.9, -41), Vector3(2, 10.9, -45),
	Vector3(2, 6.6, -45), Vector3(0, 6.3, -47), Vector3(0, 6.3, -54)]

func _live(scene: Node) -> void:
	var runner: JobRunner = scene.get_node("JobRunner")
	runner.launch()
	runner.state_time = runner.job.countdown
	await Sim.physics_frames(2)

## Anything solid overlapping the drone's shape at its current place.
func _blocked(d: Drone) -> bool:
	var shape: CollisionShape3D = d.get_node("Shape")
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape.shape
	q.transform = shape.global_transform
	q.exclude = [d.get_rid()]
	q.collide_with_areas = false
	return not d.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

## Pins the drone along a polyline at `speed`, one tick at a time. Returns ticks blocked.
## Kinematic while pinned, so areas (the cornice sensors) still see it.
func _fly(d: Drone, path: Array, speed: float, log := {}) -> int:
	var blocked := 0
	d.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	for i in path.size() - 1:
		var steps := maxi(ceili(path[i].distance_to(path[i + 1]) / speed * 60.0), 1)
		for k in steps:
			d.freeze = true
			d.global_position = path[i].lerp(path[i + 1], float(k + 1) / steps)
			await Sim.physics_frames(1)
			log["frame"] = log.get("frame", 0) + 1
			if _blocked(d):
				blocked += 1
	return blocked

func test_completable_with_act3_grade_a() -> bool:
	var scene: Node = Sim.add(load(SCENE).instantiate())
	await Sim.process_frames(2)
	var runner: JobRunner = scene.get_node("JobRunner")
	var d: Drone = scene.get_node("Drone")
	var act3 := not d.assists.is_enabled(&"collision_guard") and not d.assists.is_enabled(&"altitude_hold")
	await _live(scene)
	var blocked := await _fly(d, PATH, 8.0)
	await Sim.physics_frames(2)
	var ok: bool = act3 and blocked == 0 and runner.state == JobRunner.State.COMPLETE \
		and runner.result.letter == "A" and runner.result.strikes.is_empty()
	# One contact on an otherwise perfect run is no longer an A.
	var avoid: AvoidContact = runner.get_node("NoContact")
	avoid.contacts = 1
	ok = ok and Grader.grade(runner.objectives()) != "A"
	scene.free()
	return ok

func test_knocked_cornice_strikes_bhima_after_warning() -> bool:
	var scene: Node = Sim.add(load(SCENE).instantiate())
	await Sim.process_frames(2)
	var runner: JobRunner = scene.get_node("JobRunner")
	var d: Drone = scene.get_node("Drone")
	var zone: HazardZone = scene.get_node("BhimaZone")
	var log := {"frame": 0, "warned": -1, "struck": -1}
	zone.warning_started.connect(func(_c): if log.warned < 0: log.warned = log.frame)
	zone.struck.connect(func(_c, _cause): log.struck = log.frame)
	await _live(scene)
	# A low entry clips the middle cornice block.
	await _fly(d, [Vector3(0, 9.9, -34), Vector3(0, 9.9, -38.4)], 6.0, log)
	await _fly(d, [Vector3(0, 9.9, -38.4), Vector3(0, 12, -34)], 6.0, log)
	for i in 120:
		await Sim.physics_frames(1)
		log.frame += 1
	var ok: bool = runner.strikes.get(&"bhima", 0) == 1 and log.warned >= 0 and log.struck - log.warned >= 60
	scene.free()
	return ok

func test_late_exit_fails_when_roof_falls() -> bool:
	var scene: Node = Sim.add(load(SCENE).instantiate())
	await Sim.process_frames(2)
	var runner: JobRunner = scene.get_node("JobRunner")
	runner.results_scene = null
	var d: Drone = scene.get_node("Drone")
	await _live(scene)
	await _fly(d, PATH.slice(0, 5), 8.0)
	var hz: HazardScene = scene.get_node("Hazards")
	hz.timeline.seek(37.5, true)
	for i in 60:
		d.freeze = true
		await Sim.physics_frames(1)
	var ok: bool = hz.fired.has(&"roof") and runner.state == JobRunner.State.FAILED \
		and runner.fail_reason == "the roof came down"
	scene.free()
	return ok
