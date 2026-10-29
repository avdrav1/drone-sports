extends RefCounted
# Story 10.1: map data and GPS readout. The grid reads true, markers collect
# with hidden ones left out, and every flying scene loads a map.

const Sim = preload("res://tests/sim.gd")

func _map() -> MapData:
	var m := MapData.new()
	m.bounds = Rect2(-100, -100, 200, 200)
	m.cell_size = 50.0
	return m

func test_grid_ref_reads_known_point() -> bool:
	var m := _map()
	# 30 m east and 20 m north of the south-west corner (-100, z 100).
	var p := Vector3(-70, 12, 80)
	var metres := m.grid_metres(p)
	# 160 m east, 170 m north: column D, row 4.
	var q := Vector3(60, 0, -70)
	return metres.is_equal_approx(Vector2(30, 20)) and m.grid_ref(p) == "A1" and m.grid_ref(q) == "D4"

func test_grid_cell_changes_at_boundary() -> bool:
	var m := _map()
	# x = -50 is the A/B column boundary; z = 50 is the 1/2 row boundary.
	return m.grid_ref(Vector3(-50.01, 0, 60)) == "A1" and m.grid_ref(Vector3(-49.99, 0, 60)) == "B1" \
		and m.grid_ref(Vector3(-60, 0, 50.01)) == "A1" and m.grid_ref(Vector3(-60, 0, 49.99)) == "A2"

func test_gps_reads_drone_position() -> bool:
	var d := Node3D.new()
	Sim.add(d)
	d.global_position = Vector3(-70, 12, 80)
	var gps := Gps.new()
	gps.map = _map()
	gps.drone = d
	var ok := gps.grid_ref() == "A1" and gps.readout() == "A1  0030E 0020N" and gps.signal_strength() == 1.0
	d.free()
	gps.free()
	return ok

func test_collect_skips_hidden_markers() -> bool:
	var root := Node3D.new()
	var shown := MapMarker.new()
	shown.kind = &"drop"
	var hidden := MapMarker.new()
	hidden.kind = &"rescue"
	hidden.on_map = false
	var nested := Node3D.new()
	var deep := MapMarker.new()
	deep.kind = &"hazard"
	root.add_child(shown)
	root.add_child(hidden)
	root.add_child(nested)
	nested.add_child(deep)
	Sim.add(root)
	var outside := Sim.add(MapMarker.new())
	var found := MapMarker.collect(root)
	root.free()
	outside.free()
	return found == [shown, deep]

func test_scenes_load_a_map() -> bool:
	var ok := true
	for path in ["res://scenes/debug_flight.tscn", "res://scenes/jobs/sample_delivery.tscn", "res://scenes/jobs/test_race.tscn"]:
		var scene: Node = Sim.add(load(path).instantiate())
		await Sim.process_frames(1)
		var gps: Gps = scene.get_node("Gps")
		var hud: FlightHud = scene.get_node("HUD/Flight")
		ok = ok and gps.map != null and hud.gps == gps and gps.readout() != "NO MAP"
		scene.free()
	return ok

func test_job_markers_are_on_the_map() -> bool:
	var delivery: Node = Sim.add(load("res://scenes/jobs/sample_delivery.tscn").instantiate())
	await Sim.process_frames(1)
	var drops := MapMarker.collect(delivery).filter(func(m): return m.kind == &"drop")
	delivery.free()
	var race: Node = Sim.add(load("res://scenes/jobs/test_race.tscn").instantiate())
	await Sim.process_frames(1)
	var gates := MapMarker.collect(race).filter(func(m): return m.kind == &"gate")
	race.free()
	return drops.size() == 1 and gates.size() == 10
