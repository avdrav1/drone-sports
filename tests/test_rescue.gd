extends RefCounted
# Story 4.3: search and rescue. Beacon strength follows distance; holding over
# Sushena completes; the timer strikes (after a warning) and fails; seeded spot.

const Sim = preload("res://tests/sim.gd")
const SCENE := "res://scenes/jobs/rescue.tscn"

func _scene(seed := 7, seconds := 90.0) -> Node:
	var scene: Node = load(SCENE).instantiate()
	scene.get_node("Sushena").seed = seed
	scene.get_node("RescueTimer").seconds = seconds
	return Sim.add(scene)

func _live(scene: Node) -> void:
	var runner: JobRunner = scene.get_node("JobRunner")
	runner.results_scene = null
	runner.launch()
	runner.state_time = runner.job.countdown
	await Sim.physics_frames(2)

func test_beacon_strength_follows_distance() -> bool:
	var b := Beacon.new()
	b.range = 150.0
	var ok := b.strength_at(0.0) == 1.0 and b.strength_at(150.0) == 0.0 and b.strength_at(400.0) == 0.0
	var last := 2.0
	for d in [0.0, 10.0, 40.0, 80.0, 120.0, 149.0]:
		var s := b.strength_at(d)
		ok = ok and s < last
		last = s
	var listener: Node3D = Sim.add(Node3D.new())
	b.listener = listener
	Sim.add(b)
	listener.global_position = Vector3(30, 0, 0)
	var near_interval := b.interval()
	listener.global_position = Vector3(140, 0, 0)
	ok = ok and is_equal_approx(b.strength(), b.strength_at(140.0)) and near_interval < b.interval()
	b.free()
	listener.free()
	return ok

func test_holding_over_sushena_completes() -> bool:
	var scene := _scene()
	await Sim.process_frames(2)
	var runner: JobRunner = scene.get_node("JobRunner")
	var d: Drone = scene.get_node("Drone")
	var over: Vector3 = scene.get_node("Sushena/HoldPoint").global_position
	await _live(scene)
	for i in 185:
		d.freeze = true
		d.global_position = over
		await Sim.physics_frames(1)
	var ok: bool = runner.state == JobRunner.State.COMPLETE and runner.result.strikes.is_empty()
	scene.free()
	return ok

func test_timer_expiry_strikes_and_fails() -> bool:
	var scene := _scene(7, 3.0)
	await Sim.process_frames(2)
	var runner: JobRunner = scene.get_node("JobRunner")
	var zone: HazardZone = scene.get_node("Sushena/Zone")
	var log := {"frame": 0, "warned": -1, "struck": -1}
	zone.warning_started.connect(func(_c): if log.warned < 0: log.warned = log.frame)
	zone.struck.connect(func(_c, cause): log.struck = log.frame)
	await _live(scene)
	for i in 240:
		scene.get_node("Drone").freeze = true
		await Sim.physics_frames(1)
		log.frame += 1
	var ok: bool = runner.state == JobRunner.State.FAILED and runner.fail_reason == "time ran out" \
		and runner.result.strikes == {&"sushena": 1} and log.struck - log.warned >= 60
	scene.free()
	return ok

func test_spot_reproducible_with_seed() -> bool:
	var spots := []
	for seed in [7, 7, 8]:
		var scene := _scene(seed)
		await Sim.process_frames(1)
		spots.append(scene.get_node("Sushena").global_position)
		scene.free()
	return spots[0] == spots[1] and spots[0] != spots[2] and spots[0].distance_to(Vector3.ZERO) >= 50.0

func test_sushena_is_not_on_the_map() -> bool:
	var scene := _scene()
	await Sim.process_frames(2)
	var kinds := MapMarker.collect(scene).map(func(m): return m.kind)
	var runner: JobRunner = scene.get_node("JobRunner")
	var ok: bool = not &"crew" in kinds and runner.job.guidance == Job.Guidance.NONE \
		and scene.find_children("*", "RouteSource").is_empty()
	scene.free()
	return ok
