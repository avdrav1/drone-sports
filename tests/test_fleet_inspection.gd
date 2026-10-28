extends RefCounted
# Story 6.3: fleet inspection. Three rooftop relays held at once by three drones.

const Sim = preload("res://tests/sim.gd")
const SCENE := "res://scenes/jobs/fleet_inspection.tscn"
## Above every roof and antenna in the sandbox city.
const CRUISE := 56.0

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

## Up to cruise height, across, and down onto the point.
func _send(d: Drone, to: Vector3) -> void:
	var p := d.global_position
	Autopilot.of(d).go_to(PackedVector3Array([Vector3(p.x, CRUISE, p.z), Vector3(to.x, CRUISE, to.z), to]))

func _station(s: Node, i: int) -> Vector3:
	return s.get_node("Station%d" % i).global_position

func _wait_done(s: Node, seconds: float) -> void:
	var runner: JobRunner = s.get_node("JobRunner")
	for k in int(seconds * 60):
		await Sim.physics_frames(1)
		if runner.is_over():
			return

func test_three_drones_three_stations_complete() -> bool:
	var s := _job()
	await _live(s)
	for i in 3:
		_send(s.get_node("Fleet%d" % (i + 1)), _station(s, i + 1))
	await _wait_done(s, 60.0)
	var runner: JobRunner = s.get_node("JobRunner")
	var ok := runner.state == JobRunner.State.COMPLETE
	if not ok:
		print("        state %s, %s" % [runner.state, s.get_node("HUD/Stations").lines()])
	s.free()
	return ok

func test_one_drone_touring_every_station_never_completes() -> bool:
	var s := _job()
	await _live(s)
	var d: Drone = s.get_node("Fleet1")
	var route := PackedVector3Array([Vector3(d.global_position.x, CRUISE, d.global_position.z)])
	for i in 3:
		var st := _station(s, i + 1)
		route.append_array([Vector3(st.x, CRUISE, st.z), st])
	var auto := Autopilot.of(d)
	auto.go_to(route)
	var holds: Array = s.get_node("JobRunner").objectives()
	var on_each := [false, false, false]
	var ever_held := false
	while not auto.done():
		await Sim.physics_frames(1)
		for i in 3:
			on_each[i] = on_each[i] or holds[i].occupants().has(d)
		ever_held = ever_held or holds.any(func(h): return h.held > 0.0)
	# And sits on the last one well past its hold time.
	await Sim.physics_frames(60 * 8)
	# Two drones on one station and none on the third: still nothing.
	var two: Drone = s.get_node("Fleet2")
	var three: Drone = s.get_node("Fleet3")
	# Each down its own column, so their guards don't hold them apart above it.
	_send(two, _station(s, 1) + Vector3(-1.6, 0, 0))
	_send(three, _station(s, 1) + Vector3(1.6, 0, 0))
	for k in 60 * 60:
		await Sim.physics_frames(1)
		if Autopilot.of(two).done() and Autopilot.of(three).done():
			break
	await Sim.physics_frames(60 * 8)
	var stacked: bool = holds[0].occupants().size() >= 2
	ever_held = ever_held or holds.any(func(h): return h.held > 0.0)
	var runner: JobRunner = s.get_node("JobRunner")
	var ok: bool = on_each == [true, true, true] and stacked and not ever_held and runner.state == JobRunner.State.LIVE
	if not ok:
		print("        visited %s stacked %s held %s; d2 %.1f d3 %.1f" % [on_each, stacked, ever_held,
			two.global_position.distance_to(_station(s, 1)), three.global_position.distance_to(_station(s, 1))])
	s.free()
	return ok

func test_graded_per_station_and_combined() -> bool:
	var s := _job()
	var runner: JobRunner = s.get_node("JobRunner")
	var results := []
	runner.finished.connect(func(r): results.append(r))
	await _live(s)
	_send(s.get_node("Fleet1"), _station(s, 1))
	_send(s.get_node("Fleet2"), _station(s, 2))
	# The third holds two metres off centre: a lower score for its relay only.
	_send(s.get_node("Fleet3"), _station(s, 3) + Vector3(2.0, 0, 0))
	await _wait_done(s, 60.0)
	var ok: bool = results.size() == 1 and results[0].completed
	if ok:
		var r: JobResult = results[0]
		var scores: Array = r.objectives.map(func(o): return o.score)
		var labels: Array = r.objectives.map(func(o): return o.label)
		var mean: float = scores.reduce(func(a, b): return a + b, 0.0) / 3.0
		ok = labels == ["Relay 1", "Relay 2", "Relay 3"] and scores[0] > 0.9 and scores[1] > 0.9 \
			and scores[2] < 0.8 and scores[2] > 0.5 and is_equal_approx(r.score, mean) \
			and is_equal_approx(r.score, Grader.total(runner.objectives()))
		if not ok:
			print("        %s %s %.3f" % [labels, scores, r.score])
	s.free()
	return ok
