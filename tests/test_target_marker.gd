extends RefCounted
# Story 10.6: target marker. The route's next point is marked on screen, or by
# an edge arrow when out of view, with the distance; nothing when guidance or
# the GPS allows none.

const Sim = preload("res://tests/sim.gd")

func _delivery() -> Node:
	var scene: Node = load("res://scenes/jobs/sample_delivery.tscn").instantiate()
	scene.get_node("JobRunner").pays_out = false
	Sim.add(scene)
	(scene.get_node("Drone") as Drone).freeze = true
	return scene

func test_marks_the_next_point_ahead() -> bool:
	var scene := _delivery()
	await Sim.process_frames(3)
	var tm: TargetMarker = scene.get_node("HUD/TargetMarker")
	var pad: Vector3 = scene.get_node("DropPad/Target").global_position
	var m := tm.marker()
	var d: Vector3 = scene.get_node("Drone").global_position
	var ok: bool = not m.is_empty() and m.on_screen and tm.target().is_equal_approx(pad) \
		and is_equal_approx(m.distance, d.distance_to(pad))
	scene.free()
	return ok

func test_edge_arrow_when_behind() -> bool:
	var scene := _delivery()
	var drone: Drone = scene.get_node("Drone")
	drone.rotate_y(PI)
	await Sim.process_frames(30)
	var tm: TargetMarker = scene.get_node("HUD/TargetMarker")
	var m := tm.marker()
	var rect := tm.get_viewport_rect()
	var ok: bool = not m.is_empty() and not m.on_screen and rect.has_point(m.pos)
	# The arrow points down the screen: the pad is behind the camera.
	ok = ok and Vector2.from_angle(m.angle).y > 0.5
	scene.free()
	return ok

func test_nothing_without_fix_or_guidance() -> bool:
	var scene := _delivery()
	await Sim.process_frames(3)
	var tm: TargetMarker = scene.get_node("HUD/TargetMarker")
	var runner: JobRunner = scene.get_node("JobRunner")
	var drone: Drone = scene.get_node("Drone")
	var start := drone.global_position
	drone.global_position = scene.get_node("Jammer").global_position + Vector3(0, 3, 0)
	var jammed := tm.marker().is_empty()
	drone.global_position = start
	var restored := not tm.marker().is_empty()
	runner.job = runner.job.duplicate()
	runner.job.guidance = Job.Guidance.NONE
	Roster.injure(&"sanjaya")  # fit, Sanjaya would raise it to the next leg (Story 19.6)
	var unguided := tm.marker().is_empty()
	scene.free()
	return jammed and restored and unguided

func test_on_every_guided_job() -> bool:
	var ok := true
	for f in ["sample_delivery", "inspection", "demolition"]:
		var scene: Node = load("res://scenes/jobs/%s.tscn" % f).instantiate()
		var tm := scene.get_node_or_null("HUD/TargetMarker") as TargetMarker
		ok = ok and tm != null and tm.route is RouteSource and tm.camera_rig is CameraRig
		scene.free()
	return ok
