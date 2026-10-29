extends RefCounted
# Story 4.4: HoldStation and the tower inspection. A hold takes exactly its hold
# time, leaving past the grace resets it, holds run in order, and the job grades.

const Sim = preload("res://tests/sim.gd")

func _hold(center: Node3D, hold_time := 3.0, grace := 0.5) -> HoldStation:
	var h := HoldStation.new()
	h.center = center
	h.radius = 2.0
	h.hold_time = hold_time
	h.grace = grace
	h.ends_job = true
	return h

func _rig(holds: Array) -> Array:
	var root := Sim.job_setup(Job.new(), holds)
	var spot := Node3D.new()
	root.add_child(spot)
	var d: Drone = root.get_node("Drone")
	return [root, d, root.get_node("Runner")]

## Pins the drone at a point: frozen and placed, every frame.
func _pin(d: Drone, at: Vector3, frames: int) -> void:
	for i in frames:
		d.freeze = true
		d.global_position = at
		await Sim.physics_frames(1)

func test_hold_completes_in_exactly_hold_time() -> bool:
	var center := Node3D.new()
	var h := _hold(center, 2.5)
	var s := _rig([h])
	s[0].add_child(center)
	center.global_position = Vector3(10, 5, 0)
	var d: Drone = s[1]
	await Sim.go_live(s[0])
	var frames := 0
	while not h.is_done() and frames < 400:
		await _pin(d, center.global_position, 1)
		frames += 1
	s[0].free()
	# 2.5 s at 60 ticks a second.
	return frames == 150

func test_leaving_past_grace_resets() -> bool:
	var center := Node3D.new()
	var h := _hold(center, 3.0, 0.5)
	var s := _rig([h])
	s[0].add_child(center)
	center.global_position = Vector3(10, 5, 0)
	var d: Drone = s[1]
	await Sim.go_live(s[0])
	var away := center.global_position + Vector3(0, 0, 10)
	await _pin(d, center.global_position, 60)
	var after_inside := h.held
	await _pin(d, away, 15)  # 0.25 s out: within grace, paused
	var after_short := h.held
	await _pin(d, center.global_position, 30)
	var resumed := h.held
	await _pin(d, away, 45)  # 0.75 s out: past grace, reset
	var after_long := h.held
	var done := h.is_done()
	s[0].free()
	return absf(after_inside - 1.0) < 0.02 and absf(after_short - after_inside) < 0.001 \
		and absf(resumed - 1.5) < 0.02 and after_long == 0.0 and not done

func test_holds_run_in_order() -> bool:
	var c1 := Node3D.new()
	var c2 := Node3D.new()
	var h1 := _hold(c1, 1.0)
	var h2 := _hold(c2, 1.0)
	h2.after = h1
	var s := _rig([h1, h2])
	s[0].add_child(c1)
	s[0].add_child(c2)
	c1.global_position = Vector3(10, 5, 0)
	c2.global_position = Vector3(-10, 5, 0)
	var d: Drone = s[1]
	await Sim.go_live(s[0])
	await _pin(d, c2.global_position, 90)
	var skipped := h2.held == 0.0 and not h2.is_done()
	await _pin(d, c1.global_position, 61)
	await _pin(d, c2.global_position, 61)
	var ok := skipped and h1.is_done() and h2.is_done()
	s[0].free()
	return ok

func test_inspection_job_completes_and_grades() -> bool:
	var scene: Node = Sim.add(load("res://scenes/jobs/inspection.tscn").instantiate())
	await Sim.process_frames(2)
	var runner: JobRunner = scene.get_node("JobRunner")
	var d: Drone = scene.get_node("Drone")
	var rig: CameraRig = scene.get_node("CameraRig")
	var orbit := rig.view == CameraRig.View.ORBIT
	runner.launch()
	runner.state_time = runner.job.countdown
	await Sim.physics_frames(2)
	for i in [1, 2, 3]:
		await _pin(d, scene.get_node("Station%d" % i).global_position, 185)
	var ok: bool = orbit and runner.state == JobRunner.State.COMPLETE and runner.result != null \
		and runner.result.letter == "A" and runner.result.objectives.size() == 5
	var zone: HazardZone = scene.get_node("SanjayaZone")
	ok = ok and zone.character == &"sanjaya" and zone.find_children("*", "CrewProp").size() == 1
	scene.free()
	return ok
