extends RefCounted
# Story 10.5: GPS jamming. Signal falls with depth past the zone edge; at zero the
# route and radar markers vanish; leaving restores them within a second; drift
# reproduces from a seed.

const Sim = preload("res://tests/sim.gd")

func _zone(at: Vector3, radius: float, fade: float) -> JammingZone:
	var z := JammingZone.new()
	z.radius = radius
	z.fade = fade
	z.position = at
	return z

func test_signal_falls_with_depth_past_edge() -> bool:
	var root: Node3D = Sim.add(Node3D.new())
	var z := _zone(Vector3(5, 0, 5), 20.0, 8.0)
	root.add_child(z)
	var at := func(d: float) -> float: return z.strength_at(Vector3(5 + d, 30, 5))
	var ok: bool = is_equal_approx(at.call(40.0), 1.0) and is_equal_approx(at.call(20.0), 1.0) \
		and is_equal_approx(at.call(16.0), 0.5) and is_equal_approx(at.call(12.0), 0.0) \
		and is_equal_approx(at.call(0.0), 0.0) and at.call(18.0) > at.call(15.0)
	root.free()
	return ok

func test_gps_takes_weakest_zone() -> bool:
	var root: Node3D = Sim.add(Node3D.new())
	root.add_child(_zone(Vector3.ZERO, 20.0, 8.0))
	root.add_child(_zone(Vector3(30, 0, 0), 20.0, 8.0))
	var d := Node3D.new()
	root.add_child(d)
	var gps := Gps.new()
	gps.drone = d
	root.add_child(gps)
	d.global_position = Vector3(14, 0, 0)  # 6 m inside the first, 4 m inside the second
	var mid := gps.signal_strength()
	d.global_position = Vector3(0, 0, 100)
	var clear := gps.signal_strength()
	root.free()
	return is_equal_approx(mid, 0.25) and is_equal_approx(clear, 1.0)

func _delivery() -> Node:
	var scene: Node = Sim.add(load("res://scenes/jobs/sample_delivery.tscn").instantiate())
	var d: Drone = scene.get_node("Drone")
	d.freeze = true
	return scene

## Route, map route, ribbon, radar markers and route dots, and the readout, in that order.
func _shown(scene: Node) -> Array:
	var radar: Radar = scene.get_node("HUD/Radar")
	return [scene.get_node("Route").guided().size(), scene.get_node("MapLayer/Map").route_chart().size(),
		scene.get_node("RouteRibbon").dashes, radar.blips().size(), radar.route_dots().size(),
		scene.get_node("Gps").readout()]

func test_zero_signal_hides_route_and_markers() -> bool:
	var scene := _delivery()
	await Sim.process_frames(3)
	var before := _shown(scene)
	var jammer: Vector3 = scene.get_node("Jammer").global_position
	scene.get_node("Drone").global_position = jammer + Vector3(0, 3, 0)
	await Sim.process_frames(3)
	var gps: Gps = scene.get_node("Gps")
	var after := _shown(scene)
	var ok: bool = before[0] > 0 and before[2] > 0 and before[3] > 0 and before[4] > 0 \
		and gps.signal_strength() == 0.0 and after == [0, 0, 0, 0, 0, "NO FIX"]
	scene.free()
	return ok

func test_leaving_restores_within_a_second() -> bool:
	var scene := _delivery()
	await Sim.process_frames(3)
	var d: Drone = scene.get_node("Drone")
	var start := d.global_position
	var before := _shown(scene)
	d.global_position = scene.get_node("Jammer").global_position + Vector3(0, 3, 0)
	await Sim.physics_frames(30)
	d.global_position = start
	await Sim.physics_frames(60)
	var ok: bool = _shown(scene) == before and before[0] > 0
	scene.free()
	return ok

## The fix offset after `seconds` of GPS time, with the drone `depth` metres inside a zone.
func _drift(seed: int, seconds: float, depth: float) -> Vector3:
	var root: Node3D = Sim.add(Node3D.new())
	root.add_child(_zone(Vector3.ZERO, 20.0, 8.0))
	var d := Node3D.new()
	root.add_child(d)
	d.global_position = Vector3(20.0 - depth, 0, 0)
	var gps := Gps.new()
	gps.drone = d
	gps.seed = seed
	root.add_child(gps)
	gps.time = seconds
	var out := gps.drift()
	root.free()
	return out

func test_drift_reproduces_from_seed() -> bool:
	var a := _drift(7, 3.5, 4.0)
	var b := _drift(7, 3.5, 4.0)
	var other := _drift(8, 3.5, 4.0)
	var later := _drift(7, 9.0, 4.0)
	var clear := _drift(7, 3.5, -5.0)
	# Half signal: never more than half the 30 m maximum.
	return a == b and a.length() > 0.0 and a.length() <= 15.0 and a != other and a != later \
		and clear == Vector3.ZERO
