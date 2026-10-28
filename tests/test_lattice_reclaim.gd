extends RefCounted
# Story 8.3: phase 1, reclaim. Tagging the gap units opens the trench; defenders
# take fleet drones and the shell takes units back; no fleet fails the job.

const Sim = preload("res://tests/sim.gd")
const SCENE := "res://scenes/boss/lattice_job.tscn"

func _job(seed := 1) -> Node:
	var s: Node = load(SCENE).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	runner.confirm_risk = false
	(s.get_node("Fight") as LatticeFight).seed = seed
	Sim.add(s)
	return s

func _live(s: Node) -> void:
	var runner: JobRunner = s.get_node("JobRunner")
	await Sim.process_frames(2)
	runner.launch(true)
	while runner.state != JobRunner.State.LIVE:
		await Sim.physics_frames(1)

func _no_defenders(s: Node) -> void:
	var fight: LatticeFight = s.get_node("Fight")
	for d in fight.defenders:
		d.free()
	fight.defenders.clear()

func test_reclaiming_the_gap_opens_the_entrance() -> bool:
	var s := _job()
	_no_defenders(s)
	var fight: LatticeFight = s.get_node("Fight")
	var view: CommandView = s.get_node("CommandView")
	var done := []
	fight.phase_complete.connect(func(p): done.append(p))
	await _live(s)
	var start := view.drones.size()
	var gap := fight.gap()
	for i in gap.size():
		fight.tag(view.drones[i % start], gap[i])
	for k in 60 * 60:
		await Sim.physics_frames(1)
		if not done.is_empty():
			break
	var ok: bool = gap.size() == fight.boss().gap_units and done == [LatticeFight.Phase.RECLAIM] \
		and fight.lattice.entrance_open and fight.phase == LatticeFight.Phase.TRENCH \
		and gap.all(func(u): return u in fight.reclaimed and fight.lattice.is_hidden(u)) \
		and view.drones.size() == start + fight.reclaimed.size()
	if not ok:
		print("        reclaimed %s of %s, fleet %d" % [fight.reclaimed, gap, view.drones.size()])
	s.free()
	return ok

func test_losing_the_fleet_fails_and_units_go_back() -> bool:
	var s := _job()
	var fight: LatticeFight = s.get_node("Fight")
	var view: CommandView = s.get_node("CommandView")
	var runner: JobRunner = s.get_node("JobRunner")
	await _live(s)
	var unit: int = fight.gap()[0]
	fight.reclaim(unit)
	var back := false
	var def: Drone = fight.defenders[0]
	while not view.drones.is_empty() and runner.state == JobRunner.State.LIVE:
		var prey: Drone = view.drones[0]
		def.global_position = prey.global_position + Vector3(0.6, 0, 0)
		await Sim.physics_frames(2)
		if fight.reclaimed.is_empty() and not fight.lattice.is_hidden(unit):
			back = true
	var ok: bool = back and runner.state == JobRunner.State.FAILED and runner.fail_reason == "fleet lost" and fight.lost >= 5
	s.free()
	return ok

## Defender positions and fight state after `seconds` of a set opening.
func _run(seed: int, seconds: float) -> Array:
	var s := _job(seed)
	var fight: LatticeFight = s.get_node("Fight")
	var view: CommandView = s.get_node("CommandView")
	await _live(s)
	var gap := fight.gap()
	for i in gap.size():
		fight.tag(view.drones[i % view.drones.size()], gap[i])
	await Sim.physics_frames(int(seconds * 60))
	var out := [fight.reclaimed.duplicate(), fight.lost]
	for d in fight.defenders:
		out.append(d.global_position.snapped(Vector3.ONE * 0.001))
	s.free()
	return out

func test_reproducible_with_a_seed() -> bool:
	var a := await _run(3, 12.0)
	var b := await _run(3, 12.0)
	var c := await _run(4, 12.0)
	var ok := a == b and a.slice(2) != c.slice(2)
	if not ok:
		print("        %s / %s / %s" % [a, b, c])
	return ok
