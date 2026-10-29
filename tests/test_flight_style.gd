extends RefCounted
# Story 18.11: flying with personality. Each flying crew member has a
# FlightStyle the autopilot reads: the bold one pulls ahead, the clumsy one
# wanders off the line, the steady one keeps their gap and radios advice. Only
# the intent changes; every drone keeps the one flight model.

const Sim = preload("res://tests/sim.gd")
const STYLES := ["bold", "steady", "clumsy", "gentle"]
## A relay-like lap: corners both ways, flown through at corner speed.
const ROUTE := [Vector3(0, 20, -20), Vector3(18, 21, -32), Vector3(30, 20, -14), Vector3(18, 22, 4),
	Vector3(-2, 20, -6), Vector3(-14, 21, -24)]
const START := Vector3(0, 20, 0)

func _style(id: String) -> FlightStyle:
	return load("res://data/crew/styles/%s.tres" % id)

## Distance from `p` to the route's polyline, start included.
func _off_line(p: Vector3) -> float:
	var pts := [START] + ROUTE
	var best := INF
	for i in pts.size() - 1:
		best = minf(best, p.distance_to(Geometry3D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
	return best

## Flies ROUTE in `style` alone in open air: [seconds to finish, mean metres off the line].
func _fly(style: FlightStyle) -> Array:
	var d: Drone = Sim.DRONE.instantiate()
	var auto := Autopilot.new()
	auto.name = "Autopilot"
	auto.corner_speed = 5.0
	auto.style = style
	auto.wobble_phase = 1.0
	d.add_child(auto)
	d.intent_source = auto
	Sim.add(d)
	d.global_position = START
	await Sim.physics_frames(2)
	auto.go_to(PackedVector3Array(ROUTE))
	var frames := 0
	var off := 0.0
	while not auto.done() and frames < 60 * 60:
		await Sim.physics_frames(1)
		frames += 1
		off += _off_line(d.global_position)
	var out := [frames / 60.0 if auto.done() else INF, off / maxf(frames, 1)]
	d.free()
	return out

func test_bold_finishes_ahead_and_clumsy_strays_most() -> bool:
	var runs := {}
	for id in STYLES:
		runs[id] = await _fly(_style(id))
	var ok: bool = runs.bold[0] < runs.steady[0] and runs.values().all(func(r): return r[0] < INF)
	for id in STYLES:
		if id != "clumsy":
			ok = ok and runs.clumsy[1] > runs[id][1]
	if not ok:
		print("        [seconds, mean off line] %s" % runs)
	return ok

func test_crew_fly_true_to_character() -> bool:
	var want := {&"nala": "bold", &"sanjaya": "steady", &"arjuna": "clumsy", &"sushena": "gentle"}
	var ok := true
	for id in FleetCrew.tagged():
		var c: Character = Roster.character(id)
		ok = ok and c.flight_style != null and want.get(id, "") == String(c.flight_style.id)
	var bold := _style("bold")
	var steady := _style("steady")
	var clumsy := _style("clumsy")
	# Bold pushes and cuts corners; steady keeps the widest gap and advises; clumsy wobbles and reacts late.
	ok = ok and bold.push > steady.push and bold.corner_speed > steady.corner_speed and bold.cut > 0.0 \
		and steady.spacing > bold.spacing and steady.spacing > clumsy.spacing and steady.advice \
		and not bold.advice and not clumsy.advice \
		and clumsy.wobble > steady.wobble and clumsy.wobble > bold.wobble and clumsy.delay > steady.delay
	return ok

## Runs `method` of an existing fleet test with every flying crew member in `style`.
func _with_style(style: FlightStyle, suite: String, method: String) -> bool:
	var saved := {}
	for id in FleetCrew.tagged():
		var c: Character = Roster.character(id)
		saved[id] = c.flight_style
		c.flight_style = style
	var t = load("res://tests/%s.gd" % suite).new()
	var ok: bool = await t.call(method)
	for id in saved:
		Roster.character(id).flight_style = saved[id]
	if not ok:
		print("        %s::%s failed with every pilot %s" % [suite, method, style.id])
	return ok

func test_each_fleet_job_completes_in_every_style() -> bool:
	var ok := true
	for id in STYLES:
		ok = await _with_style(_style(id), "test_fleet_inspection", "test_three_drones_three_stations_complete") and ok
		ok = await _with_style(_style(id), "test_fleet_race", "test_relay_in_order_completes_with_handoffs") and ok
		ok = await _with_style(_style(id), "test_lattice_reclaim", "test_reclaiming_the_gap_opens_the_entrance") and ok
	return ok

## Every exported value on a node's script, by name.
func _exports(n: Object) -> Dictionary:
	var out := {}
	for p in n.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_STORAGE:
			out[p.name] = n.get(p.name)
	return out

## Mass, flight values, collision shapes, and every assist's values of `d`.
func _flight(d: Drone) -> Dictionary:
	var shapes := []
	for c in d.get_children():
		if c is CollisionShape3D:
			shapes.append([c.shape.get_class(), c.transform, _exports(c.shape) if c.shape.get_script() else c.shape.get_property_list().map(func(p): return c.shape.get(p.name))])
	var assists := {}
	for a in d.assists.assists():
		var vals := _exports(a)
		vals.erase("drone")
		assists[a.name] = vals
	var flight := _exports(d)
	flight.erase("intent_source")
	return {"mass": d.mass, "flight": flight, "shapes": shapes, "assists": assists}

func test_flight_model_mass_and_assists_unchanged() -> bool:
	# A plain fleet drone under autopilot, and the same under every style, mid-flight.
	var base := {}
	var ok := true
	for id in [""] + STYLES:
		var d: Drone = Sim.DRONE.instantiate()
		var auto := Autopilot.new()
		auto.name = "Autopilot"
		auto.style = null if id == "" else _style(id)
		d.add_child(auto)
		d.intent_source = auto
		Sim.add(d)
		d.global_position = START
		await Sim.physics_frames(2)
		auto.go_to(PackedVector3Array(ROUTE))
		await Sim.physics_frames(120)
		var f := _flight(d)
		if id == "":
			base = f
		elif str(f) != str(base):
			ok = false
			print("        %s changed the drone" % id)
		d.free()
	# And the fleet a job builds: the same as a plain drone on the autopilot's stack.
	var s: Node = load("res://scenes/jobs/fleet_race.tscn").instantiate()
	(s.get_node("JobRunner") as JobRunner).auto_begin = false
	Sim.add(s)
	await Sim.process_frames(3)
	for d in (s.get_node("FleetCrew") as FleetCrew).drones:
		ok = ok and Autopilot.of(d).style != null and str(_flight(d)) == str(base)
	s.free()
	return ok

func _relay() -> Node:
	var s: Node = load("res://scenes/jobs/fleet_race.tscn").instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	runner.auto_begin = false
	Sim.add(s)
	return s

func test_steady_flyer_radios_advice_on_fleet_events() -> bool:
	var s := _relay()
	var crew: FleetCrew = s.get_node("FleetCrew")
	var relay: Relay = s.get_node("Relay")
	var said := []
	(s.get_node("Bark") as Bark).spoke.connect(func(id, e, text): said.append([id, e, text]))
	await Sim.process_frames(2)
	relay.leg_done.emit(0, relay.drones[0], 30.0)
	var ok: bool = crew.adviser() == &"sanjaya" and said.size() == 1 and said[0][0] == &"sanjaya" \
		and said[0][1] == &"advice" and said[0][2] != "" and not said[0][2].contains("{")
	# Not twice inside the gap, then again on a bad lap once it has passed.
	relay.lap_invalid.emit(relay.drones[1], "missed a gate")
	ok = ok and said.size() == 1
	crew._since_advice = crew.advice_gap
	relay.lap_invalid.emit(relay.drones[1], "missed a gate")
	ok = ok and said.size() == 2 and said[1][1] == &"advice"
	s.free()
	# The dead never advise: with Sanjaya gone nobody does.
	Roster.kill(&"sanjaya")
	s = _relay()
	crew = s.get_node("FleetCrew")
	said.clear()
	(s.get_node("Bark") as Bark).spoke.connect(func(id, e, text): said.append([id, e, text]))
	await Sim.process_frames(2)
	(s.get_node("Relay") as Relay).leg_done.emit(0, crew.drones[0], 30.0)
	ok = ok and crew.adviser() == &"" and said.is_empty()
	s.free()
	if not ok:
		print("        said %s" % [said])
	return ok
