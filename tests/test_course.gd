extends RefCounted
# Story 3.1: gates and course.

const Sim = preload("res://tests/sim.gd")
const TEST_COURSE := "res://data/courses/test_loop.tres"

func _course() -> Course:
	var c := Course.new()
	c.data = load(TEST_COURSE)
	Sim.add(c)
	return c

## A plain node standing in for a racer, behind the start gate.
func _racer(c: Course) -> Node3D:
	var r := Node3D.new()
	c.add_child(r)
	r.global_position = c.gates[0].global_transform * Vector3(0, 0, 4)
	c.add_racer(r)
	return r

## Moves the racer through gate i (forward or backward), one physics frame per step.
func _through(r: Node3D, g: Gate, forward := true) -> void:
	var s := 1.5 if forward else -1.5
	# Arrive from high above so the move to the start side crosses no opening.
	r.global_position = g.global_transform * Vector3(0, 20, s)
	await Sim.physics_frames(1)
	r.global_position = g.global_transform * Vector3(0, 0, s)
	await Sim.physics_frames(1)
	r.global_position = g.global_transform * Vector3(0, 0, -s)
	await Sim.physics_frames(1)

func _lap(c: Course, r: Node3D, skip := -1) -> void:
	for i in range(1, c.gates.size()):
		if i != skip:
			await _through(r, c.gates[i])
	await _through(r, c.gates[0])

func test_test_course_data() -> bool:
	var data: CourseData = load(TEST_COURSE)
	return data.gates.size() == 8 and data.laps == 2

func test_gate_detects_direction() -> bool:
	var g := Gate.new()
	Sim.add(g)
	g.global_position = Vector3(0, 5, 0)
	var fwd := g.crossing(Vector3(0, 5, 1), Vector3(0, 5, -1))
	var back := g.crossing(Vector3(0, 5, -1), Vector3(0, 5, 1))
	var outside := g.crossing(Vector3(5, 5, 1), Vector3(5, 5, -1))
	g.free()
	return fwd == 1 and back == -1 and outside == 0

func test_backward_pass_does_not_count() -> bool:
	var c := _course()
	var r := _racer(c)
	c.start()
	await _through(r, c.gates[0])
	await _through(r, c.gates[1], false)
	var after_back := c.progress(r).next
	await _through(r, c.gates[1])
	var after_fwd := c.progress(r).next
	c.free()
	return after_back == 1 and after_fwd == 2

func test_full_lap_emits_lap_completed() -> bool:
	var c := _course()
	var r := _racer(c)
	var laps := []
	c.lap_completed.connect(func(t, who, n, valid): laps.append([t, who, n, valid]))
	c.start()
	await _through(r, c.gates[0])
	await _lap(c, r)
	var ok: bool = laps.size() == 1 and laps[0][1] == r and laps[0][2] == 1 and laps[0][3] \
		and is_equal_approx(laps[0][0], c.time) and laps[0][0] > 0.0
	c.free()
	return ok

func test_skipping_a_gate_invalidates_the_lap() -> bool:
	var c := _course()
	var r := _racer(c)
	var laps := []
	c.lap_completed.connect(func(t, who, n, valid): laps.append(valid))
	c.start()
	await _through(r, c.gates[0])
	await _lap(c, r, 3)
	var skipped_counted := c.progress(r).laps
	await _lap(c, r)
	var ok: bool = laps == [false, true] and skipped_counted == 0 and c.progress(r).laps == 1
	c.free()
	return ok

func test_finishes_after_course_laps() -> bool:
	var c := _course()
	var r := _racer(c)
	var finished := []
	c.racer_finished.connect(func(who, place, t): finished.append([who, place]))
	c.start()
	await _through(r, c.gates[0])
	await _lap(c, r)
	var mid := finished.size()
	await _lap(c, r)
	var ok: bool = mid == 0 and finished == [[r, 1]] and c.progress(r).lap_times.size() == 2
	c.free()
	return ok
