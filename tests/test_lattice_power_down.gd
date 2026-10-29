extends RefCounted
# Story 8.6: power-down and epilogue. The shell lets go, the living crew's lost
# drones come home, the dead are named and nothing of theirs returns, and the
# save records the Lattice disabled.

const Sim = preload("res://tests/sim.gd")
const SCENE := "res://scenes/boss/lattice_job.tscn"

## Runs the job from the override (pilot parked at the port) to the end, with
## `dead` already gone. Returns [scene, result].
func _finish(dead: Array) -> Array:
	for id in dead:
		Roster.kill(id)
	var s: Node = load(SCENE).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.results_scene = null
	runner.back_scene = ""
	runner.confirm_risk = false
	Sim.add(s)
	var fight: LatticeFight = s.get_node("Fight")
	for d in fight.defenders:
		d.free()
	fight.defenders.clear()
	var results := []
	runner.finished.connect(func(r): results.append(r))
	await Sim.process_frames(2)
	runner.launch(true)
	while runner.state != JobRunner.State.LIVE:
		await Sim.physics_frames(1)
	fight.open_entrance()
	runner.drone.freeze = true
	runner.drone.global_position = fight.override.center.global_position
	fight.start_override()
	for k in 60 * 40:
		await Sim.physics_frames(1)
		if not results.is_empty():
			break
	return [s, results[0] if not results.is_empty() else null]

func test_living_crews_drones_come_home_the_dead_stay_gone() -> bool:
	var out := await _finish([&"dot"])
	var s: Node = out[0]
	var r: JobResult = out[1]
	var fight: LatticeFight = s.get_node("Fight")
	var view: CommandView = s.get_node("CommandView")
	var ok := r != null and r.completed and fight.phase == LatticeFight.Phase.DONE and fight.lattice.remaining() == 0
	for id in FleetCrew.tagged():
		if Roster.is_alive(id):
			var d: Drone = fight.returned.get(id)
			ok = ok and d != null and d in view.drones and view.pilots.get(d) == Roster.character(id)
		else:
			ok = ok and not fight.returned.has(id)
	ok = ok and fight.returned.size() == FleetCrew.flyers().size() and not fight.returned.has(&"dot")
	if not ok:
		print("        returned %s, remaining %d, phase %s" % [fight.returned.keys(), fight.lattice.remaining(), fight.phase])
	s.free()
	return ok

func test_results_account_for_living_and_dead() -> bool:
	var out := await _finish([&"dot"])
	var s: Node = out[0]
	var r: JobResult = out[1]
	var ok := r != null and r.epilogue.size() == Roster.ids().size()
	if ok:
		for e in r.epilogue:
			ok = ok and e.alive == Roster.is_alive(e.id) and e.text != ""
			if e.id == &"dot":
				ok = ok and not e.alive and e.text == Bark.memorial(&"dot")
		var screen: Control = load("res://scenes/ui/results.tscn").instantiate()
		Sim.add(screen)
		screen.show_result(r)
		var rows: Array = screen.rows.get_children().filter(func(n): return n.name.begins_with("Epilogue"))
		var texts: Array = rows.map(func(n): return (n.get_child(1) as Label).text)
		ok = ok and rows.size() == r.epilogue.size() and texts.any(func(t): return t.begins_with("Nala is not coming home.")) \
			and texts.any(func(t): return t.begins_with("Sanjaya: "))
		if not ok:
			print("        %s / %s" % [r.epilogue, texts])
		screen.free()
	s.free()
	return ok

func test_save_records_lattice_disabled() -> bool:
	var out := await _finish([])
	var s: Node = out[0]
	var flags = SaveGame.read_section("flags", {})
	var ok: bool = out[1] != null and StoryFlags.is_set(&"lattice_disabled") and flags is Dictionary and flags.get("lattice_disabled") == true
	s.free()
	return ok
