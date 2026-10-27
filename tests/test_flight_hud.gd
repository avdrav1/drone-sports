extends RefCounted
# Story 9.5: flight HUD. Heading, speed, altitude, job panel, and assists read true.

const Sim = preload("res://tests/sim.gd")

func _hud(d: Drone, runner: JobRunner = null) -> FlightHud:
	var hud := FlightHud.new()
	hud.drone = d
	hud.runner = runner
	Sim.add(hud)
	return hud

func test_heading_reads_yaw() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 20, 0))
	d.freeze = true
	var hud := _hud(d)
	var out := []
	for target in [Vector3(0, 20, -10), Vector3(10, 20, 0), Vector3(0, 20, 10), Vector3(-10, 20, 0)]:
		d.look_at(target)
		out.append(roundi(hud.heading()) % 360)
	hud.free()
	d.free()
	return out == [0, 90, 180, 270]

func test_speed_and_altitude_match_drone() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(3, 37.4, -2))
	var hud := _hud(d)
	d.linear_velocity = Vector3(6, -2, 3)
	var ok := absf(hud.speed_kmh() - Vector3(6, -2, 3).length() * 3.6) < 0.5 and absf(hud.altitude() - 37.4) < 0.5
	hud.free()
	d.free()
	return ok

func test_panel_lists_objectives_and_state() -> bool:
	var job := Job.new()
	job.title = "Test run"
	job.client = "Nobody"
	var reach := ReachPoint.new()
	reach.label = "Reach it"
	var avoid := AvoidContact.new()
	avoid.label = "Touch nothing"
	var root := Sim.job_setup(job, [reach, avoid])
	var runner: JobRunner = root.get_node("Runner")
	var hud := _hud(root.get_node("Drone"), runner)
	runner.begin()
	var briefing := hud.panel()
	runner.launch()
	runner.state_time = job.countdown
	await Sim.physics_frames(2)
	var live := hud.panel()
	var labels := []
	for row in briefing.rows:
		labels.append(row.label)
	hud.free()
	root.free()
	return briefing.title == "TEST RUN" and labels == ["Reach it", "Touch nothing"] \
		and briefing.state == "BRIEFING" and live.state.begins_with("LIVE")

func test_assist_indicator_matches_drone() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 20, 0), load("res://data/assists/act3.tres"))
	var hud := _hud(d)
	var states := hud.assist_states()
	var ok := states.keys() == Array(AssistStack.IDS)
	for id in AssistStack.IDS:
		if id != &"single_drone_view":
			ok = ok and states[id] == d.assists.is_enabled(id)
	hud.free()
	d.free()
	return ok

func test_debug_panel_shows_preset() -> bool:
	var scene: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	await Sim.process_frames(1)
	var hud: FlightHud = scene.get_node("HUD/Flight")
	var first: String = hud.panel().subtitle
	scene.cycle_preset()
	var second: String = hud.panel().subtitle
	scene.free()
	return first.begins_with("Act 1") and second.begins_with("Act 2")
