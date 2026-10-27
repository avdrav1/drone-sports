extends RefCounted
# Story 10.3: full map screen. M toggles it in every flying scene, chart and
# world coordinates round-trip, the job keeps running, and the track records only Live.

const Sim = preload("res://tests/sim.gd")
const SCENES := ["res://scenes/debug_flight.tscn", "res://scenes/jobs/sample_delivery.tscn", "res://scenes/jobs/test_race.tscn"]

func _press_map(scene: Node) -> void:
	var ev := InputEventAction.new()
	ev.action = &"toggle_map"
	ev.pressed = true
	scene.get_viewport().push_input(ev)

func test_m_toggles_map_in_every_scene() -> bool:
	var ok := true
	for path in SCENES:
		var scene: Node = Sim.add(load(path).instantiate())
		await Sim.process_frames(1)
		var map: MapScreen = scene.get_node("MapLayer/Map")
		var before := map.visible
		_press_map(scene)
		await Sim.process_frames(1)
		var opened := map.visible
		_press_map(scene)
		await Sim.process_frames(1)
		ok = ok and not before and opened and not map.visible
		scene.free()
	return ok

func test_world_and_chart_round_trip() -> bool:
	var d: Node3D = Sim.add(Node3D.new())
	var gps := Gps.new()
	gps.drone = d
	gps.map = load("res://data/maps/delivery_yard.tres")
	var map := MapScreen.new()
	map.gps = gps
	map.add_child(gps)
	Sim.add(map)
	map.size = Vector2(1280, 720)
	var b := gps.map.bounds
	var r := map.chart_rect()
	# The south-west corner sits at the chart's bottom left: north is up.
	var ok := map.to_chart(Vector3(b.position.x, 0, b.end.y)).distance_to(Vector2(r.position.x, r.end.y)) < 1.0
	for w in [Vector3(0, 3, 0), Vector3(-37.5, 0, -61.2), Vector3(59, 9, -99), Vector3(-60, 0, 20)]:
		var px := map.to_chart(w)
		var back := map.to_world(px)
		ok = ok and map.to_chart(back).distance_to(px) < 1.0 and Vector2(back.x, back.z).distance_to(Vector2(w.x, w.z)) < b.size.x / r.size.x
	map.free()
	d.free()
	return ok

func test_job_runs_and_track_records_only_live() -> bool:
	var scene: Node = Sim.add(load("res://scenes/jobs/sample_delivery.tscn").instantiate())
	await Sim.process_frames(2)
	var runner: JobRunner = scene.get_node("JobRunner")
	var map: MapScreen = scene.get_node("MapLayer/Map")
	map.toggle()
	await Sim.physics_frames(30)
	var briefing_track := map.track.size()
	runner.launch()
	runner.state_time = runner.job.countdown
	await Sim.physics_frames(2)
	var t0 := runner.live_time
	await Sim.physics_frames(60)
	var ok := runner.state == JobRunner.State.LIVE and map.visible and not scene.get_tree().paused \
		and runner.live_time - t0 > 0.9 and briefing_track == 0 and map.track.size() >= 4
	scene.free()
	return ok
