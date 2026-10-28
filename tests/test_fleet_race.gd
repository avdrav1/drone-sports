extends RefCounted
# Story 6.4: fleet race. A relay where each lap is a different drone and the
# start gate is the handoff.

const Sim = preload("res://tests/sim.gd")
const SCENE := "res://scenes/jobs/fleet_race.tscn"

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

## Waits for the relay's leg count or invalid count to change, up to `seconds`.
func _await_lap(relay: Relay, seconds: float) -> void:
	var legs := relay.leg
	var bad := relay.invalid
	for k in int(seconds * 60):
		await Sim.physics_frames(1)
		if relay.leg != legs or relay.invalid != bad:
			return

func _fleet(s: Node, i: int) -> Drone:
	return s.get_node("Fleet%d" % i)

func test_relay_in_order_completes_with_handoffs() -> bool:
	var s := _job()
	var relay: Relay = s.get_node("Relay")
	await _live(s)
	for i in 3:
		relay.send(_fleet(s, i + 1))
		await _await_lap(relay, 90.0)
	await Sim.physics_frames(5)
	var runner: JobRunner = s.get_node("JobRunner")
	var ok := relay.done and relay.invalid == 0 and relay.leg_times.size() == 3 and relay.handoffs.size() == 2 \
		and runner.state == JobRunner.State.COMPLETE
	if not ok:
		print("        leg %d invalid %d (%s) handoffs %s state %s" % [relay.leg, relay.invalid, relay.last_invalid, relay.handoffs, runner.state])
	s.free()
	return ok

func test_lap_by_the_wrong_drone_is_invalid() -> bool:
	var s := _job()
	var relay: Relay = s.get_node("Relay")
	await _live(s)
	relay.send(_fleet(s, 1))
	await _await_lap(relay, 90.0)
	var first := relay.leg == 1
	# Leg two belongs to Fleet2; Fleet3 flies it instead.
	var flagged := []
	relay.lap_invalid.connect(func(d, why): flagged.append([d, why]))
	relay.send(_fleet(s, 3))
	await _await_lap(relay, 90.0)
	var ok: bool = first and relay.leg == 1 and relay.invalid == 1 and flagged.size() == 1 \
		and flagged[0][0] == _fleet(s, 3) and flagged[0][1] == "wrong drone" and relay.leg_times.size() == 1
	# The right drone still flies it.
	relay.send(_fleet(s, 2))
	await _await_lap(relay, 90.0)
	ok = ok and relay.leg == 2 and relay.invalid == 1
	if not ok:
		print("        leg %d invalid %d flagged %s" % [relay.leg, relay.invalid, flagged])
	s.free()
	return ok

func test_hud_shows_handoff_timing() -> bool:
	var s := _job()
	var relay: Relay = s.get_node("Relay")
	var hud: RelayHud = s.get_node("HUD/Board")
	await _live(s)
	var before := hud.lines()
	relay.send(_fleet(s, 1))
	# Send the next drone as soon as the first finishes: a quick handoff.
	relay.leg_done.connect(func(_l, _d, _t): if relay.current(): relay.send(relay.current()), CONNECT_ONE_SHOT)
	await _await_lap(relay, 90.0)
	for k in 60 * 20:
		await Sim.physics_frames(1)
		if not relay.handoffs.is_empty():
			break
	await Sim.process_frames(2)
	var after := hud.lines()
	var ok := before.begins_with("Leg 1/3") and relay.handoffs.size() == 1 \
		and after.contains("Handoff 1  %.2f s" % relay.handoffs[0]) and after.contains("Leg 2/3")
	if not ok:
		print("        before %s / after %s" % [before.replace("\n", " | "), after.replace("\n", " | ")])
	s.free()
	return ok
