extends RefCounted
# Story 12.5: the sandbox flies in the city.

const Sim = preload("res://tests/sim.gd")
const SANDBOX := "res://scenes/debug_flight.tscn"

func _sandbox() -> Node:
	return Sim.add(load(SANDBOX).instantiate())

func test_city_replaces_the_boxes() -> bool:
	var s := _sandbox()
	var ok := s.get_node_or_null("Boxes") == null and s.get_node_or_null("City") is City \
		and s.get_node_or_null("Streets") is Streets and s.get_node_or_null("Rooftops") is Rooftops
	s.free()
	return ok

func test_act1_hover_at_spawn_has_no_contact() -> bool:
	var s := _sandbox()
	var d: Drone = s.get_node("Drone")
	d.contact_monitor = true
	d.max_contacts_reported = 4
	var hits := []
	d.body_entered.connect(func(b): hits.append(b))
	var spawn := d.global_position
	await Sim.physics_frames(2)
	var act1: bool = s.preset_index == 0
	await Sim.physics_frames(300)
	var ok: bool = act1 and hits.is_empty() and d.global_position.distance_to(spawn) < 1.5
	s.free()
	return ok

## The drone starts in the open desert just outside the city, a metre or so above
## the sand, facing the skyline so the first view is the whole city.
func test_spawn_is_in_the_desert_facing_the_city() -> bool:
	var s := _sandbox()
	var d: Drone = s.get_node("Drone")
	var city: City = s.get_node("City")
	var ground: DesertTerrain = s.get_node("Ground")
	var p := d.global_position
	var flat := Vector2(p.x, p.z)
	var outside := flat.length() > city.layout.core_radius + 30.0
	var clearance := p.y - ground.height_at(p.x, p.z)
	var to_city := (city.global_position - p) * Vector3(1, 0, 1)
	var facing := (-d.global_basis.z).dot(to_city.normalized()) > 0.95
	var ok := outside and clearance > 0.5 and clearance < 2.0 and facing
	s.free()
	return ok

func test_radar_shows_rooftop_pads() -> bool:
	var s := _sandbox()
	await Sim.process_frames(3)
	var radar: Radar = s.get_node("HUD/Radar")
	var pads := radar.blips().filter(func(b): return b.marker.kind == &"pad")
	var ok: bool = pads.size() == (s.get_node("Rooftops") as Rooftops).pads.size() and pads.size() >= 3
	s.free()
	return ok

func test_map_is_darker_under_buildings() -> bool:
	var s := _sandbox()
	await Sim.process_frames(2)
	var map: MapScreen = s.get_node("MapLayer/Map")
	var img := map.texture.get_image()
	var bounds: Rect2 = s.get_node("Gps").map.bounds
	var plan := (s.get_node("City") as City).plan
	var px := func(p: Vector2) -> Color:
		var at := ((p - bounds.position) / bounds.size * Vector2(img.get_size())).floor()
		return img.get_pixelv(Vector2i(at))
	var lit := func(c: Color) -> float:
		return c.get_luminance() * c.a
	var ok := true
	for i in 10:
		var under: Color = px.call(plan.lots[i * 7].get_center())
		# A street's centre, between crossings.
		var street := plan.streets[(i * 2) % plan.streets.size()].get_center() + Vector2(0, 20.0 if i % 2 == 0 else -20.0)
		var open: Color = px.call(street)
		ok = ok and lit.call(under) < lit.call(open)
	s.free()
	return ok

func test_job_hotkeys_still_launch_every_job() -> bool:
	var keys := {&"start_sample_job": "sample_job", &"start_race_job": "race_job",
		&"start_inspection_job": "inspection_job", &"start_demolition_job": "demolition_job",
		&"start_rescue_job": "rescue_job"}
	var ok := true
	for action in keys:
		Sim.tree().change_scene_to_file(SANDBOX)
		await Sim.process_frames(3)
		var s := Sim.tree().current_scene
		var want: String = s.get(keys[action])
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = true
		s.get_viewport().push_input(ev)
		await Sim.process_frames(3)
		ok = ok and Sim.tree().current_scene != null and Sim.tree().current_scene.scene_file_path == want
		Sim.tree().unload_current_scene()
		await Sim.process_frames(1)
	return ok
