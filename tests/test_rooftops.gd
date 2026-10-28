extends RefCounted
# Story 12.4: rooftops. Seeded clutter on the roofs, landing pads with markers.

const Sim = preload("res://tests/sim.gd")
const ROOFTOPS := preload("res://scenes/world/rooftops.tscn")

func _roofs() -> Rooftops:
	return Sim.add(ROOFTOPS.instantiate())

func test_clutter_sits_on_its_roof_clear_of_pads() -> bool:
	var r := _roofs()
	var ok := r.pieces.size() > 50
	for f in r.pieces:
		var lot: Rect2 = r.plan.lots[f.lot]
		var base: Vector3 = f.base
		var foot := Rect2(base.x - f.size.x * 0.5, base.z - f.size.z * 0.5, f.size.x, f.size.z)
		if not is_equal_approx(base.y, r.plan.heights[f.lot]) or not lot.encloses(foot):
			ok = false
		for p in r.pads:
			var near := Vector2(clampf(p.x, foot.position.x, foot.end.x), clampf(p.z, foot.position.y, foot.end.y))
			if near.distance_to(Vector2(p.x, p.z)) < r.pad_radius:
				ok = false
	r.free()
	return ok

func test_tall_pieces_have_collision() -> bool:
	var r := _roofs()
	var shapes: Array[CollisionShape3D] = []
	for n in r.get_children():
		if n is CollisionShape3D:
			shapes.append(n)
	var tall := r.pieces.filter(func(f): return f.size.y > 1.0)
	var antennas := tall.filter(func(f): return f.kind == Rooftops.Kind.ANTENNA)
	var ok := not antennas.is_empty() and shapes.size() == tall.size() \
		and r.pieces.any(func(f): return f.size.y <= 1.0)
	for f in tall:
		var centre: Vector3 = f.base + Vector3.UP * f.size.y * 0.5
		var match := shapes.any(func(s): return s.position.is_equal_approx(centre) and (s.shape as BoxShape3D).size.is_equal_approx(f.size))
		ok = ok and match
	r.free()
	return ok

func test_at_least_three_pads_with_markers() -> bool:
	var r := _roofs()
	var markers := MapMarker.collect(r).filter(func(m): return m.kind == &"pad")
	var ok := r.pads.size() >= 3 and markers.size() == r.pads.size()
	for i in r.pads.size():
		var pad := r.get_node("Pad%d" % i) as MeshInstance3D
		ok = ok and pad != null and pad.visible and pad.mesh != null
	r.free()
	return ok

func test_same_layout_same_rooftops() -> bool:
	Rooftops._cache.clear()
	var a := _roofs()
	Rooftops._cache.clear()
	var b := _roofs()
	var ok: bool = a.pads == b.pads and a.pieces.size() == b.pieces.size()
	for i in mini(a.pieces.size(), b.pieces.size()):
		ok = ok and a.pieces[i].base == b.pieces[i].base and a.pieces[i].size == b.pieces[i].size \
			and a.pieces[i].kind == b.pieces[i].kind
	a.free()
	b.free()
	return ok
