extends RefCounted
# Story 22.2: the fleet race on a path. The team relay runs on the open test
# path, split into legs at handoff gates; each leg is a different drone, which
# waits beside its leg's first gate, and the last leg ends at the last gate.

const Sim = preload("res://tests/sim.gd")
const SCENE := "res://scenes/jobs/fleet_race.tscn"
const STYLES := ["bold", "steady", "clumsy", "gentle"]

func _job() -> Node:
	var s: Node = load(SCENE).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	Sim.add(s)
	return s

func _live(s: Node) -> void:
	var runner: JobRunner = s.get_node("JobRunner")
	await Sim.process_frames(2)
	runner.launch(true)
	while runner.state != JobRunner.State.LIVE:
		await Sim.physics_frames(1)

## Passes `d` forward through gates `from`..`to` of the relay's course, a few
## frames apart, without flying: the relay only hears the gates.
func _pass(relay: Relay, d: Drone, from: int, to: int) -> void:
	for i in range(from, to + 1):
		await Sim.physics_frames(3)
		relay.course.gates[i].passed.emit(d, true)

func test_fleet_race_runs_on_an_open_course() -> bool:
	var s := _job()
	await Sim.process_frames(2)
	var relay: Relay = s.get_node("Relay")
	var course := relay.course
	var n := relay.drones.size()
	var ends := relay.ends()
	var ok: bool = not course.is_closed() and n >= 3 and ends.size() == n and ends[-1] == course.gates.size() - 1 \
		and course.data.gates == (load("res://data/courses/test_path.tres") as CourseData).gates
	for k in n:
		# Legs follow on: each starts where the last ended and has gates of its own.
		ok = ok and relay.leg_start(k) < ends[k] and (k == 0 or relay.leg_start(k) == ends[k - 1])
		# Its drone waits beside and behind that first gate, clear of the opening.
		var local := course.gates[relay.leg_start(k)].global_transform.affine_inverse() * relay.drones[k].global_position
		ok = ok and local.z > 2.0 and absf(local.x) > course.data.gate_size.x and local.length() < 12.0
	if not ok:
		print("        ends %s closed %s" % [ends, course.is_closed()])
	s.free()
	return ok

func test_wrong_drone_missed_gate_or_early_start_is_invalid() -> bool:
	var s := _job()
	await Sim.process_frames(2)
	var relay: Relay = s.get_node("Relay")
	relay.course.start()
	var d: Array[Drone] = relay.drones
	var flagged := []
	relay.lap_invalid.connect(func(drone, why): flagged.append([drone, why]))
	# Leg one with a gate skipped.
	await _pass(relay, d[0], 0, 1)
	await _pass(relay, d[0], 3, relay.ends()[0])
	var ok: bool = relay.leg == 0 and flagged == [[d[0], "missed a gate"]]
	# The second drone leaves before the first is back, then the first flies leg one clean.
	await _pass(relay, d[1], relay.leg_start(1), relay.leg_start(1))
	await _pass(relay, d[0], 0, relay.ends()[0])
	ok = ok and relay.leg == 1
	await _pass(relay, d[1], relay.leg_start(1) + 1, relay.ends()[1])
	ok = ok and relay.leg == 1 and flagged.size() == 2 and flagged[1] == [d[1], "left before the handoff"]
	# The third drone flies leg two.
	await _pass(relay, d[2], relay.leg_start(1), relay.ends()[1])
	ok = ok and relay.leg == 1 and flagged.size() == 3 and flagged[2] == [d[2], "wrong drone"]
	# The second, after the handoff, flies it right; the handoff is timed.
	await _pass(relay, d[1], relay.leg_start(1), relay.ends()[1])
	ok = ok and relay.leg == 2 and relay.invalid == 3 and relay.handoffs.size() == 1 and relay.handoffs[0] > 0.0
	if not ok:
		print("        leg %d flagged %s handoffs %s" % [relay.leg, flagged, relay.handoffs])
	s.free()
	return ok

func test_hud_shows_the_leg_gates_and_handoff_timing() -> bool:
	var s := _job()
	await Sim.process_frames(2)
	var relay: Relay = s.get_node("Relay")
	var hud: RelayHud = s.get_node("HUD/Board")
	relay.course.start()
	var d: Array[Drone] = relay.drones
	var before := hud.lines()
	await _pass(relay, d[0], 0, relay.ends()[0])
	await Sim.physics_frames(30)
	await _pass(relay, d[1], relay.leg_start(1), relay.leg_start(1))
	var after := hud.lines()
	var ok: bool = before.contains("gates 0-%d" % relay.ends()[0]) and relay.handoffs.size() == 1 \
		and relay.handoffs[0] > 0.5 and after.contains("Handoff 1  %.2f s" % relay.handoffs[0]) \
		and after.contains("gates %d-%d" % [relay.leg_start(1), relay.ends()[1]])
	if not ok:
		print("        before %s / after %s" % [before.replace("\n", " | "), after.replace("\n", " | ")])
	s.free()
	return ok

## Flies the whole relay on autopilot, each drone sent as the last hands off.
## True when every leg is a different drone and it ends at the last gate, once.
func _fly_relay() -> bool:
	var s := _job()
	var relay: Relay = s.get_node("Relay")
	var runner: JobRunner = s.get_node("JobRunner")
	await _live(s)
	var last := relay.course.gates[-1]
	var at_last := []
	last.passed.connect(func(drone, fwd): if fwd: at_last.append([drone, relay.course.time]))
	var flown := []
	var ends := []
	relay.leg_done.connect(func(_l, drone, _t): flown.append(drone))
	relay.finished.connect(func(t): ends.append(t))
	relay.leg_done.connect(func(_l, _d, _t): if relay.current(): relay.send(relay.current()))
	relay.send(relay.drones[0])
	for k in 60 * 240:
		await Sim.physics_frames(1)
		if relay.done:
			break
	# Past the finish nothing more counts.
	await _pass(relay, relay.drones[-1], relay.leg_start(relay.drones.size() - 1), last.index)
	await Sim.physics_frames(5)
	var n := relay.drones.size()
	var distinct := {}
	for f in flown:
		distinct[f] = true
	var ok: bool = relay.done and relay.invalid == 0 and flown.size() == n and distinct.size() == n \
		and ends.size() == 1 and not at_last.is_empty() and at_last[0][0] == relay.drones[-1] \
		and is_equal_approx(at_last[0][1], ends[0]) and relay.leg_times.size() == n \
		and relay.handoffs.size() == n - 1 and runner.state == JobRunner.State.COMPLETE
	if not ok:
		print("        leg %d invalid %d (%s) ends %s handoffs %s state %s" % [relay.leg, relay.invalid, relay.last_invalid, ends, relay.handoffs, runner.state])
	else:
		print("        relay done in %.1f s, legs %s" % [ends[0], relay.leg_times.map(func(t): return snappedf(t, 0.1))])
	s.free()
	return ok

func test_each_leg_a_different_drone_ending_at_the_last_gate() -> bool:
	return await _fly_relay()

func test_every_pilot_style_completes_the_path() -> bool:
	var ok := true
	for id in STYLES:
		var style: FlightStyle = load("res://data/crew/styles/%s.tres" % id)
		var saved := {}
		for c in FleetCrew.tagged():
			saved[c] = Roster.character(c).flight_style
			Roster.character(c).flight_style = style
		var done: bool = await _fly_relay()
		for c in saved:
			Roster.character(c).flight_style = saved[c]
		if not done:
			print("        failed with every pilot %s" % id)
		ok = ok and done
	return ok
