extends RefCounted
# Story 14.4: jobs. Every runner state change and every hazard warning and strike
# plays its sound; gate sounds match the gates the flown drone passes; holds tick
# and chime; the results screen plays the payout count.

const Sim = preload("res://tests/sim.gd")
const TEST_COURSE := "res://data/courses/test_loop.tres"
const RESULTS := preload("res://scenes/ui/results.tscn")

## A job rig that neither pays out nor shows results.
func _setup(job: Job, objectives: Array = []) -> Array:
	var root := Sim.job_setup(job, objectives)
	var runner: JobRunner = root.get_node("Runner")
	runner.pays_out = false
	runner.results_scene = null
	return [root, runner]

## Ids from the log that are job or hazard cues, in order.
func _cues() -> Array:
	return Sfx.log.map(func(l): return l.id).filter(func(id): return String(id).begins_with("job_") or String(id).begins_with("hazard_"))

func test_every_state_change_plays_its_sound() -> bool:
	var job := Job.new()
	job.countdown = 3.0
	var s := _setup(job)
	var runner: JobRunner = s[1]
	var states := []
	runner.state_changed.connect(func(st, _p): states.append(st))
	Sfx.clear_log()
	await Sim.go_live(s[0])
	runner.complete()
	var won := _cues()
	var ok: bool = states == [JobRunner.State.BRIEFING, JobRunner.State.COUNTDOWN, JobRunner.State.LIVE, JobRunner.State.COMPLETE] \
		and won == [&"job_briefing", &"job_countdown", &"job_countdown", &"job_countdown", &"job_go", &"job_complete"]
	if not ok:
		print("        complete run: ", won)
	s[0].free()
	# A failed run ends on the fail stinger instead.
	s = _setup(Job.new())
	runner = s[1]
	Sfx.clear_log()
	await Sim.go_live(s[0])
	runner.fail("test")
	var lost := _cues()
	ok = ok and lost.front() == &"job_briefing" and lost.slice(-2) == [&"job_go", &"job_fail"] \
		and lost.count(&"job_complete") == 0 and lost.count(&"job_fail") == 1
	if lost.count(&"job_fail") != 1:
		print("        failed run: ", lost)
	s[0].free()
	return ok

func test_failing_in_briefing_plays_only_briefing_and_fail() -> bool:
	var s := _setup(Job.new())
	var runner: JobRunner = s[1]
	Sfx.clear_log()
	runner.begin()
	runner.fail("test")
	await Sim.physics_frames(5)
	var ok: bool = _cues() == [&"job_briefing", &"job_fail"]
	s[0].free()
	return ok

func test_gate_sounds_match_gates_passed() -> bool:
	var s := _setup(Job.new())
	var root: Node = s[0]
	var runner: JobRunner = s[1]
	var course := Course.new()
	course.data = load(TEST_COURSE)
	root.add_child(course)
	var d: Drone = runner.drone
	var ai := Node3D.new()
	root.add_child(ai)
	await Sim.go_live(root)
	d.freeze = true
	course.add_racer(d)
	course.add_racer(ai)
	course.start()
	var passed := [0]
	course.gate_passed.connect(func(who, _g): if who == d: passed[0] += 1)
	Sfx.clear_log()
	# A lap and a half for the drone, skipping gate 3 on the way; the AI flies too.
	var order := [0, 1, 2, 4, 5, 6, 7, 0, 1, 2, 3]
	for i in order:
		await _through(d, course.gates[i])
		await _through(ai, course.gates[i])
	var ok: bool = passed[0] >= 10 and Sfx.count(&"job_gate") == passed[0]
	if not ok:
		print("        passed %d, gate sounds %d" % [passed[0], Sfx.count(&"job_gate")])
	root.free()
	return ok

## Moves a racer forward through a gate, one physics frame per step.
func _through(r: Node3D, g: Gate) -> void:
	r.global_position = g.global_transform * Vector3(0, 20, 1.5)
	await Sim.physics_frames(1)
	r.global_position = g.global_transform * Vector3(0, 0, 1.5)
	await Sim.physics_frames(1)
	r.global_position = g.global_transform * Vector3(0, 0, -1.5)
	await Sim.physics_frames(1)

func test_hold_ticks_and_chimes() -> bool:
	var center := Node3D.new()
	var h := HoldStation.new()
	h.center = center
	h.radius = 2.0
	h.hold_time = 2.0
	h.ends_job = true
	var s := _setup(Job.new(), [h])
	var root: Node = s[0]
	root.add_child(center)
	center.global_position = Vector3(10, 5, 0)
	var d: Drone = s[1].drone
	await Sim.go_live(root)
	Sfx.clear_log()
	var frames := 0
	while not h.is_done() and frames < 300:
		d.freeze = true
		d.global_position = center.global_position
		await Sim.physics_frames(1)
		frames += 1
	await Sim.physics_frames(2)
	var ok: bool = h.is_done() and Sfx.count(&"job_hold_tick") == 3 and Sfx.count(&"job_hold_done") == 1
	if not ok:
		print("        ticks %d, done %d" % [Sfx.count(&"job_hold_tick"), Sfx.count(&"job_hold_done")])
	root.free()
	return ok

func test_every_hazard_warning_and_strike_plays() -> bool:
	var job := Job.new()
	job.crew_in_field = [&"sanjaya"]
	var s := _setup(job)
	var root: Node = s[0]
	var zone := HazardZone.new()
	zone.character = &"sanjaya"
	root.add_child(zone)
	zone.global_position = Vector3(0, 5, -60)
	var warned := [0]
	var struck := [0]
	zone.warning_started.connect(func(_c): warned[0] += 1)
	zone.struck.connect(func(_c, _cause): struck[0] += 1)
	await Sim.go_live(root)
	s[1].drone.freeze = true
	await Sim.physics_frames(60)
	Sfx.clear_log()
	warned[0] = 0
	# Two warnings, each held past min_warning and ended with a strike, apart.
	for k in 2:
		for i in 70:
			zone.threaten()
			await Sim.physics_frames(1)
		zone.threaten()
		zone.strike(&"test")
		await Sim.physics_frames(60)
	var ok: bool = warned[0] == 2 and struck[0] == 2 \
		and Sfx.count(&"hazard_warning") == 2 and Sfx.count(&"hazard_strike") == 2
	if not ok:
		print("        warned %d/%d, struck %d/%d" % [warned[0], Sfx.count(&"hazard_warning"), struck[0], Sfx.count(&"hazard_strike")])
	root.free()
	return ok

func test_results_play_the_payout_count() -> bool:
	var job := Job.new()
	job.title = "Test"
	var paid := JobResult.new()
	paid.job = job
	paid.completed = true
	paid.pay = 500
	var screen: Control = RESULTS.instantiate()
	Sim.add(screen)
	Sfx.clear_log()
	screen.show_result(paid)
	var ok := Sfx.count(&"job_payout") == 1
	var unpaid := JobResult.new()
	unpaid.job = job
	screen.show_result(unpaid)
	ok = ok and Sfx.count(&"job_payout") == 1
	screen.free()
	return ok

func test_job_cue_buses_match_the_note() -> bool:
	var ids := [&"job_briefing", &"job_countdown", &"job_go", &"job_gate", &"job_hold_tick",
		&"job_hold_done", &"job_complete", &"job_fail", &"job_payout", &"hazard_warning"]
	var ok: bool = Sfx.bank.find(&"hazard_strike").bus == &"World"
	for id in ids:
		if Sfx.bank.find(id).bus != &"UI":
			print("        %s is on %s" % [id, Sfx.bank.find(id).bus])
			ok = false
	return ok
