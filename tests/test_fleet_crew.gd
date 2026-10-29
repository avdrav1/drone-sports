extends RefCounted
# Story 7.7: crew in the fleet. One drone per living crew member who flies, each
# with their portrait in the command view, answering orders.

const Sim = preload("res://tests/sim.gd")
const SCENES := ["res://scenes/jobs/fleet_inspection.tscn", "res://scenes/jobs/fleet_race.tscn"]

func _job(path: String) -> Node:
	var s: Node = load(path).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	runner.auto_begin = false
	Sim.add(s)
	return s

## Living cast tagged can_fly, counted straight from the data.
func _flyers() -> int:
	var n := 0
	for c in (load("res://data/characters/cast.tres") as Cast).characters:
		if &"can_fly" in c.tags and Roster.is_alive(c.id):
			n += 1
	return n

func test_fleet_size_is_living_flying_crew() -> bool:
	var ok := _flyers() >= 3
	var sizes := []
	for path in SCENES:
		var s := _job(path)
		sizes.append((s.get_node("CommandView") as CommandView).drones.size())
		s.free()
	var full := _flyers()
	ok = ok and sizes == [full, full]
	# A dead crew member is one fewer drone, everywhere.
	Roster.kill(&"nala")
	for path in SCENES:
		var s := _job(path)
		var view: CommandView = s.get_node("CommandView")
		ok = ok and view.drones.size() == full - 1 and view.drones.size() == _flyers() \
			and not view.pilots.values().any(func(c): return c.id == &"nala")
		if path.ends_with("fleet_race.tscn"):
			ok = ok and (s.get_node("Relay") as Relay).drones == view.drones
		ok = ok and (s.get_node("JobRunner") as JobRunner).drone == view.drones[0]
		s.free()
	if not ok:
		print("        sizes %s, flyers now %d" % [sizes, _flyers()])
	return ok

func test_each_drone_shows_its_pilots_portrait() -> bool:
	var s := _job(SCENES[0])
	var view: CommandView = s.get_node("CommandView")
	var crew: FleetCrew = s.get_node("FleetCrew")
	await Sim.process_frames(3)
	var ok := not view.drones.is_empty()
	for d in view.drones:
		var face := view.portrait(d)
		var who: Character = Roster.character(crew.pilot_of(d))
		ok = ok and face != null and face.visible and face.character == who and d.name == who.name
	s.free()
	return ok

func test_pilots_answer_orders() -> bool:
	var s := _job(SCENES[0])
	var view: CommandView = s.get_node("CommandView")
	var crew: FleetCrew = s.get_node("FleetCrew")
	var said := []
	(s.get_node("Bark") as Bark).spoke.connect(func(id, e, text): said.append([id, e, text]))
	await Sim.process_frames(2)
	var d := view.drones[1]
	view.select(d)
	view.waypoint_queued.emit(d, Vector3(0, 10, -20))
	var ok: bool = said.size() == 1 and said[0][0] == crew.pilot_of(d) and said[0][1] == &"order" and said[0][2] != ""
	s.free()
	return ok
