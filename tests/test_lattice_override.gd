extends RefCounted
# Story 8.5: phase 3, override. Hold inside the port's sphere for the hold time;
# out for more than half a second resets; done, the Lattice is disabled.

const Sim = preload("res://tests/sim.gd")
const SCENE := "res://scenes/boss/lattice_job.tscn"

func _job() -> Node:
	var s: Node = load(SCENE).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	runner.confirm_risk = false
	Sim.add(s)
	var fight: LatticeFight = s.get_node("Fight")
	for d in fight.defenders:
		d.free()
	fight.defenders.clear()
	return s

## Live and straight to phase 3, the pilot held still at the port.
func _override(s: Node) -> Drone:
	var runner: JobRunner = s.get_node("JobRunner")
	var fight: LatticeFight = s.get_node("Fight")
	await Sim.process_frames(2)
	runner.launch(true)
	while runner.state != JobRunner.State.LIVE:
		await Sim.physics_frames(1)
	fight.open_entrance()
	var pilot := runner.drone
	pilot.freeze = true
	pilot.global_position = fight.override.center.global_position
	fight.start_override()
	return pilot

func test_perfect_hold_completes_in_exactly_the_hold_time() -> bool:
	var s := _job()
	var fight: LatticeFight = s.get_node("Fight")
	var events := []
	fight.hold_complete.connect(func(): events.append(&"hold_complete"))
	fight.boss_disabled.connect(func(): events.append(&"boss_disabled"))
	var pilot := await _override(s)
	var gusty := pilot.wind == fight.gusts
	var frames := 0
	while events.is_empty() and frames < 60 * 20:
		await Sim.physics_frames(1)
		frames += 1
	var want := roundi(fight.boss().hold_time * 60.0)
	var ok: bool = gusty and absi(frames - want) <= 1 and events == [&"hold_complete", &"boss_disabled"] \
		and fight.phase == LatticeFight.Phase.POWER_DOWN and fight.override.radius == fight.boss().hold_radius \
		and fight.override.score() == 1.0
	if not ok:
		print("        %d frames (want %d) events %s gusty %s" % [frames, want, events, gusty])
	s.free()
	return ok

func test_out_over_half_a_second_resets() -> bool:
	var s := _job()
	var fight: LatticeFight = s.get_node("Fight")
	var pilot := await _override(s)
	var port: Vector3 = fight.override.center.global_position
	var out := port + Vector3(0, 1.5, 0)
	await Sim.physics_frames(180)
	var held_before := fight.override.held
	# A short slip keeps the time held.
	pilot.global_position = out
	await Sim.physics_frames(24)
	pilot.global_position = port
	await Sim.physics_frames(1)
	var kept := fight.override.held >= held_before
	# A longer one loses it.
	pilot.global_position = out
	await Sim.physics_frames(36)
	pilot.global_position = port
	await Sim.physics_frames(1)
	var reset := fight.override.held < 0.1
	var ok := held_before >= 2.9 and kept and reset and fight.phase == LatticeFight.Phase.OVERRIDE
	if not ok:
		print("        before %.2f kept %s reset %s (now %.2f)" % [held_before, kept, reset, fight.override.held])
	s.free()
	return ok

func test_hold_only_counts_in_phase_3() -> bool:
	var s := _job()
	var runner: JobRunner = s.get_node("JobRunner")
	var fight: LatticeFight = s.get_node("Fight")
	await Sim.process_frames(2)
	runner.launch(true)
	while runner.state != JobRunner.State.LIVE:
		await Sim.physics_frames(1)
	runner.drone.freeze = true
	runner.drone.global_position = fight.override.center.global_position
	await Sim.physics_frames(60)
	var ok := fight.override.held == 0.0 and fight.phase == LatticeFight.Phase.RECLAIM
	s.free()
	return ok
