extends RefCounted
# Story 10.2: radar minimap. Heading-up, scaled, clamped to the rim, and in the
# test race it shows the opponents and lights the next gate.

const Sim = preload("res://tests/sim.gd")

func _radar(d: Node3D) -> Radar:
	var gps := Gps.new()
	gps.drone = d
	var radar := Radar.new()
	radar.gps = gps
	radar.add_child(gps)
	radar.range_m = 120.0
	radar.radius = 84.0
	Sim.add(radar)
	return radar

func test_ahead_draws_straight_up_at_any_yaw() -> bool:
	var d: Node3D = Sim.add(Node3D.new())
	d.global_position = Vector3(10, 5, -20)
	var radar := _radar(d)
	var ok := true
	for yaw in [0.0, 37.0, 90.0, 200.0, 315.0]:
		d.rotation_degrees = Vector3(0, yaw, 0)
		var ahead := d.global_position - d.global_transform.basis.z * 60.0 + Vector3(0, 8, 0)
		var p := radar.radar_point(ahead)
		# 60 m of a 120 m range on an 84 px radius: 42 px up.
		ok = ok and p.pos.is_equal_approx(Vector2(0, -42)) and not p.on_rim
	radar.free()
	d.free()
	return ok

func test_out_of_range_sits_on_rim_at_bearing() -> bool:
	var d: Node3D = Sim.add(Node3D.new())
	var radar := _radar(d)
	var east := Vector3(500, 0, 0)
	var facing_north := radar.radar_point(east)
	d.rotation_degrees = Vector3(0, -90, 0)  # facing east
	var facing_east := radar.radar_point(east)
	radar.free()
	d.free()
	return facing_north.on_rim and facing_north.pos.is_equal_approx(Vector2(84, 0)) \
		and facing_east.on_rim and facing_east.pos.is_equal_approx(Vector2(0, -84))

func test_race_radar_shows_opponents_and_next_gate() -> bool:
	var scene: Node = Sim.add(load("res://scenes/jobs/test_race.tscn").instantiate())
	await Sim.process_frames(3)
	var radar: Radar = scene.get_node("HUD/Radar")
	var race_hud: RaceHud = scene.get_node("HUD/Race")
	var drones := 0
	var lit := []
	for b in radar.blips():
		if b.marker.kind == &"drone":
			drones += 1
		if b.lit:
			lit.append(b.marker.get_parent())
	var ok := drones == 3 and lit == [race_hud.next_gate()] and radar.texture != null
	scene.free()
	return ok
