extends RefCounted
# Story 7.4: hazard zones and strikes. Entering at 10 m/s strikes and 1 m/s does
# not; every strike follows at least 1 s of warning; no crew_in_field, no strikes;
# the results list strikes per character.

const Sim = preload("res://tests/sim.gd")
const RESULTS := preload("res://scripts/ui/results.gd")
const ZONE_AT := Vector3(0, 5, -30)

## A live job rig with a Marlo zone at ZONE_AT (radius 3) and a crew warning HUD.
func _setup(crew: Array[StringName]) -> Array:
	var job := Job.new()
	job.crew_in_field = crew
	var root := Sim.job_setup(job)
	var zone := HazardZone.new()
	zone.character = &"marlo"
	root.add_child(zone)
	zone.global_position = ZONE_AT
	var runner: JobRunner = root.get_node("Runner")
	var hud := CrewWarning.new()
	hud.runner = runner
	root.add_child(hud)
	var log := {"warned": -1, "struck": [], "hud": false, "frame": 0}
	zone.warning_started.connect(func(_c): if log.warned < 0: log.warned = log.frame)
	zone.struck.connect(func(_c, cause): log.struck.append([log.frame, cause]))
	await Sim.go_live(root)
	return [root, runner, zone, hud, log]

## Flies the frozen drone in a straight line at `speed` m/s, one tick at a time.
func _fly(s: Array, from: Vector3, to: Vector3, speed: float) -> void:
	var d: Drone = s[1].drone
	var log: Dictionary = s[4]
	var steps := ceili(from.distance_to(to) / speed * 60.0)
	# Settle at the start so the jump there (read as speed) has warned and cleared.
	for i in 45:
		d.freeze = true
		d.global_position = from
		await Sim.physics_frames(1)
	log.warned = -1
	log.hud = false
	for i in steps + 1:
		d.freeze = true
		d.global_position = from.lerp(to, float(i) / steps)
		await Sim.physics_frames(1)
		log.frame += 1
		if s[3].warned().has(&"marlo"):
			log.hud = true

func test_fast_entry_strikes_after_a_warning() -> bool:
	var s := await _setup([&"marlo"])
	await _fly(s, Vector3(0, 5, 0), ZONE_AT, 10.0)
	var log: Dictionary = s[4]
	s[0].free()
	return log.struck.size() == 1 and log.struck[0][1] == &"contact" and log.warned >= 0 \
		and log.struck[0][0] - log.warned >= 60 and log.hud

func test_slow_entry_does_not_strike() -> bool:
	var s := await _setup([&"marlo"])
	await _fly(s, Vector3(0, 5, -22), ZONE_AT, 1.0)
	var log: Dictionary = s[4]
	s[0].free()
	return log.struck.is_empty() and log.warned < 0

func test_no_crew_in_field_never_strikes() -> bool:
	var s := await _setup([])
	await _fly(s, Vector3(0, 5, 0), ZONE_AT, 10.0)
	var zone: HazardZone = s[2]
	zone.threaten()
	await Sim.physics_frames(90)
	var forced := zone.strike(&"timer")
	var log: Dictionary = s[4]
	s[0].free()
	return log.struck.is_empty() and log.warned < 0 and not forced

func _drop(s: Array, height: float) -> void:
	var debris := Debris.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = 0.3
	debris.add_child(shape)
	s[0].add_child(debris)
	debris.global_position = ZONE_AT + Vector3(0, height, 0)
	var log: Dictionary = s[4]
	for i in 120:
		await Sim.physics_frames(1)
		log.frame += 1

func test_debris_strikes_only_after_a_full_warning() -> bool:
	# From 12 m up it takes about 1.36 s to reach the zone: warned in time, strikes.
	var high := await _setup([&"marlo"])
	await _drop(high, 12.0)
	var hl: Dictionary = high[4]
	high[0].free()
	# From 4.5 m up it arrives in about 0.55 s: too soon to warn a full second, no strike.
	var low := await _setup([&"marlo"])
	await _drop(low, 4.5)
	var ll: Dictionary = low[4]
	low[0].free()
	return hl.struck.size() == 1 and hl.struck[0][1] == &"debris" and hl.struck[0][0] - hl.warned >= 60 \
		and ll.struck.is_empty()

func test_scripted_strike_needs_a_warning() -> bool:
	var s := await _setup([&"marlo"])
	var zone: HazardZone = s[2]
	var early := zone.strike(&"timer")
	for i in 66:
		zone.threaten()
		await Sim.physics_frames(1)
	var late := zone.strike(&"timer")
	s[0].free()
	return not early and late

func test_results_list_strikes_per_character() -> bool:
	var s := await _setup([&"marlo"])
	await _fly(s, Vector3(0, 5, 0), ZONE_AT, 10.0)
	var runner: JobRunner = s[1]
	runner.results_scene = null
	runner.pays_out = false
	runner.fail("test")
	var lines: Array[String] = RESULTS.strike_lines(runner.result)
	var ok: bool = runner.result.strikes == {&"marlo": 1} and lines == ["Marlo struck 1x"]
	s[0].free()
	return ok
