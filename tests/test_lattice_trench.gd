extends RefCounted
# Story 8.4: phase 2, the trench. The pilot flies in to the shutter while the
# entrance counts down; Sanjaya calls the turns; touching the shell strikes Sanjaya.

const Sim = preload("res://tests/sim.gd")
const SCENE := "res://scenes/boss/lattice_job.tscn"

func _job(tweak := {}) -> Node:
	var s: Node = load(SCENE).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	runner.confirm_risk = false
	var lattice: Lattice = s.get_node("Lattice")
	lattice.boss = lattice.boss.duplicate()
	for k in tweak:
		lattice.boss.set(k, tweak[k])
	Sim.add(s)
	var fight: LatticeFight = s.get_node("Fight")
	for d in fight.defenders:
		d.free()
	fight.defenders.clear()
	return s

## Live, with the entrance already open: straight into phase 2.
func _trench(s: Node) -> void:
	var runner: JobRunner = s.get_node("JobRunner")
	await Sim.process_frames(2)
	runner.launch(true)
	while runner.state != JobRunner.State.LIVE:
		await Sim.physics_frames(1)
	(s.get_node("Fight") as LatticeFight).open_entrance()
	await Sim.physics_frames(1)

## Flies the pilot's drone down the trench on an autopilot, as a scripted pilot.
func _fly_trench(s: Node) -> Autopilot:
	var fight: LatticeFight = s.get_node("Fight")
	var pilot: Drone = s.get_node("JobRunner").drone
	var auto := Autopilot.new()
	auto.corner_speed = 4.0
	pilot.add_child(auto)
	pilot.intent_source = auto
	var path := fight.lattice.trench_path()
	# Down to just through the shutter: the port itself is phase 3's.
	auto.go_to(path.slice(1, path.size() - 1))
	return auto

func _until(s: Node, seconds: float, done: Callable) -> void:
	for k in int(seconds * 60):
		await Sim.physics_frames(1)
		if done.call():
			return

func test_reaching_the_shutter_completes_the_phase() -> bool:
	var s := _job()
	var fight: LatticeFight = s.get_node("Fight")
	var done := []
	var calls := []
	fight.phase_complete.connect(func(p): done.append(p))
	fight.called.connect(func(i, t): calls.append(i))
	await _trench(s)
	var rig: CameraRig = s.get_node("CameraRig")
	var handed: bool = rig.target == s.get_node("Pilot") and rig.camera.current and not s.get_node("Pilot").freeze
	_fly_trench(s)
	await _until(s, 70.0, func(): return fight.phase != LatticeFight.Phase.TRENCH)
	var ok: bool = handed and done == [LatticeFight.Phase.RECLAIM, LatticeFight.Phase.TRENCH] \
		and fight.phase == LatticeFight.Phase.OVERRIDE and fight.contacts == 0 and calls.size() == fight.waypoints.size()
	if not ok:
		print("        handed %s done %s phase %s contacts %d calls %d/%d at %s" % [handed, done, fight.phase, fight.contacts,
			calls.size(), fight.waypoints.size(), s.get_node("Pilot").global_position])
	s.free()
	return ok

func test_entrance_closes_on_time_and_fails() -> bool:
	var s := _job({"trench_time": 3.0})
	var fight: LatticeFight = s.get_node("Fight")
	var runner: JobRunner = s.get_node("JobRunner")
	await _trench(s)
	await _until(s, 2.5, func(): return runner.state != JobRunner.State.LIVE)
	var early := runner.state == JobRunner.State.LIVE
	await _until(s, 1.5, func(): return runner.state != JobRunner.State.LIVE)
	var ok: bool = early and runner.state == JobRunner.State.FAILED and runner.fail_reason == "trench closed" \
		and not fight.lattice.entrance_open
	s.free()
	return ok

func test_shell_contact_strikes_sanjaya() -> bool:
	var s := _job()
	var fight: LatticeFight = s.get_node("Fight")
	var runner: JobRunner = s.get_node("JobRunner")
	await _trench(s)
	var pilot: Drone = runner.drone
	pilot.freeze = true
	var l := fight.lattice
	var mid := (l.tunnel_span().x + l.tunnel_span().y) * 0.5
	var a := deg_to_rad(30.0)
	# Close to the trench's top wall: the warning runs; then into it.
	var near := l.to_global(Lattice.toward(a) * (l.tunnel_span().y - 1.5))
	pilot.global_position = near
	await Sim.physics_frames(80)
	var warned := fight.zone_of(&"sanjaya").warning()
	pilot.global_position = l.to_global(Lattice.toward(a) * (l.tunnel_span().y + 0.5))
	await Sim.physics_frames(3)
	var ok: bool = warned and runner.strikes.get(&"sanjaya", 0) == 1 and runner.strikes.get(&"bhima", 0) == 0 and fight.contacts == 1
	if not ok:
		print("        warned %s strikes %s contacts %d (mid %.1f)" % [warned, runner.strikes, fight.contacts, mid])
	s.free()
	return ok

func test_sanjayas_death_ends_the_callouts() -> bool:
	var s := _job()
	var fight: LatticeFight = s.get_node("Fight")
	var calls := []
	var lines := []
	fight.called.connect(func(i, t): calls.append(i))
	(s.get_node("Bark") as Bark).spoke.connect(func(id, e, t): if id == &"sanjaya" and e == &"trench": lines.append(t))
	await _trench(s)
	_fly_trench(s)
	await _until(s, 30.0, func(): return calls.size() >= 2)
	var before := calls.size()
	Roster.kill(&"sanjaya")
	await _until(s, 70.0, func(): return fight.phase != LatticeFight.Phase.TRENCH)
	var ok: bool = before >= 2 and calls.size() == before and lines.size() == before and fight.caller() == &"bhima"
	if not ok:
		print("        before %d after %d lines %d" % [before, calls.size(), lines.size()])
	s.free()
	return ok
