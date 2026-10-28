extends RefCounted
# Story 8.7: chorus lines. Plural and flat, never "I", "me", or "my"; said on
# phase starts, a crew unit reclaimed, a strike, and once at shutdown; the dot
# portrait thins with the shell.

const Sim = preload("res://tests/sim.gd")
const SCENE := "res://scenes/boss/lattice_job.tscn"
const LINES := "res://data/dialogue/lattice.json"
const EVENTS := ["phase_reclaim", "phase_trench", "phase_override", "crew_unit", "strike", "shutdown"]

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

func test_no_line_speaks_in_the_first_person_singular() -> bool:
	var data := Chorus.load_lines(LINES)
	var singular := RegEx.create_from_string("(?i)\\b(i|me|my)\\b")
	var ok := (load("res://data/boss/lattice.tres") as Boss).chorus == LINES
	for e in EVENTS:
		var pool: Array = data.get(e, [])
		ok = ok and pool.size() >= 3
		for line in pool:
			if singular.search(line) != null:
				print("        first person: %s" % line)
				ok = false
	# The check itself catches what it should.
	return ok and singular.search("I see you.") != null and singular.search("Take my drone") != null \
		and singular.search("We are more now.") == null

func test_speaks_on_its_events_then_stops() -> bool:
	var s := _job()
	var fight: LatticeFight = s.get_node("Fight")
	var chorus: Chorus = s.get_node("Chorus")
	var runner: JobRunner = s.get_node("JobRunner")
	var heard := []
	chorus.spoke.connect(func(e, t): heard.append([e, t]))
	await Sim.process_frames(2)
	runner.launch(true)
	while runner.state != JobRunner.State.LIVE:
		await Sim.physics_frames(1)
	# A crew member's drone, freed from the shell.
	var unit: int = fight.lattice.crew_units.keys()[0]
	var who: Character = Roster.character(fight.lattice.crew_units[unit])
	fight.reclaim(unit)
	fight.open_entrance()
	# A strike on the calling crew member.
	runner.crew_struck.emit(&"marlo", Roster.Status.ACTIVE)
	runner.drone.freeze = true
	runner.drone.global_position = fight.override.center.global_position
	fight.start_override()
	for k in 60 * 15:
		await Sim.physics_frames(1)
		if fight.phase == LatticeFight.Phase.POWER_DOWN:
			break
	var said_before_end := heard.size()
	chorus.say(&"phase_reclaim")
	var events: Array = heard.map(func(h): return String(h[0]))
	var crew_line: String = heard[events.find("crew_unit")][1] if "crew_unit" in events else ""
	var ok: bool = events == ["phase_reclaim", "crew_unit", "phase_trench", "strike", "phase_override", "shutdown"] \
		and heard.size() == said_before_end and chorus.silent \
		and (crew_line.contains(who.name) or crew_line.contains(who.role.to_lower()) or crew_line == "Take it back. We have more.") \
		and not crew_line.contains("{")
	if not ok:
		print("        %s" % [heard])
	s.free()
	return ok

func test_portrait_thins_with_the_shell() -> bool:
	var s := _job()
	var fight: LatticeFight = s.get_node("Fight")
	var box: ChorusBox = s.get_node("HUD/ChorusBox")
	await Sim.process_frames(2)
	var l := fight.lattice
	var full := box.dots()
	for i in l.units.size() / 2:
		l.hide_unit(i)
	var half := box.dots()
	for i in l.units.size():
		l.hide_unit(i)
	var none := box.dots()
	var ok := full == box.grid * box.grid and absi(half - full / 2) <= 1 and none == 0
	if not ok:
		print("        dots %d / %d / %d" % [full, half, none])
	s.free()
	return ok
