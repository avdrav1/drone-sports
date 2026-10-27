extends RefCounted
# Story 9.2: desert terrain. Flat flight area, seeded ridges with collision.

const Sim = preload("res://tests/sim.gd")
const DESERT := preload("res://scenes/world/desert.tscn")

func _terrain(seed := 1) -> DesertTerrain:
	var t: DesertTerrain = DESERT.instantiate()
	t.noise_seed = seed
	return Sim.add(t)

## Highest ground on a ring of radius r.
func _peak(t: DesertTerrain, r: float) -> Vector3:
	var best := Vector3.ZERO
	for i in 72:
		var a := TAU * i / 72.0
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		p.y = t.height_at(p.x, p.z)
		if p.y > best.y:
			best = p
	return best

func test_flight_area_is_flat() -> bool:
	var t := _terrain()
	await Sim.physics_frames(2)
	var space := t.get_world_3d().direct_space_state
	var ok := true
	for i in 40:
		var a := TAU * i / 40.0
		for r in [0.0, 50.0, 100.0, 148.0]:
			# Offset so no ray runs exactly down a triangle seam.
			var p := Vector3(cos(a) * r + 0.37, 0.0, sin(a) * r + 0.21)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 50.0, p + Vector3.DOWN * 50.0))
			if hit.is_empty() or absf(hit.position.y) > 0.001:
				ok = false
	t.free()
	return ok

func test_ridges_repeat_with_seed() -> bool:
	var a := _terrain(5)
	var b := _terrain(5)
	var c := _terrain(6)
	var same := true
	var differs := false
	for i in 50:
		var x := 400.0 + i * 13.0
		var z := -300.0 + i * 7.0
		same = same and a.height_at(x, z) == b.height_at(x, z)
		differs = differs or a.height_at(x, z) != c.height_at(x, z)
	var tall := _peak(a, 800.0).y > 40.0
	a.free()
	b.free()
	c.free()
	return same and differs and tall

func test_ridge_is_a_contact() -> bool:
	var t := _terrain()
	var peak := _peak(t, 700.0)
	# Motors off: it drops onto the ridge.
	var d := Sim.drone(Sim.intent(-1.0), peak + Vector3.UP * 3.0)
	d.contact_monitor = true
	d.max_contacts_reported = 4
	var hits := []
	d.body_entered.connect(func(body): hits.append(body))
	await Sim.physics_frames(120)
	# It may slide down the slope, but it rests on the surface, not inside it.
	var pos := d.global_position
	var ok := hits.has(t) and pos.y > t.height_at(pos.x, pos.z) - 0.5 and pos.y > 40.0
	d.free()
	t.free()
	return ok

func test_scenes_load_without_errors() -> bool:
	for path in ["res://scenes/debug_flight.tscn", "res://scenes/jobs/sample_delivery.tscn"]:
		var scene: Node = Sim.add(load(path).instantiate())
		await Sim.process_frames(3)
		var ok: bool = scene.get_node_or_null("Ground") is DesertTerrain
		scene.free()
		if not ok:
			return false
	return true
