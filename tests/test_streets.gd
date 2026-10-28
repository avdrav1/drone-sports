extends RefCounted
# Story 12.3: streets. Road mesh over every street, lights on the sidewalks.

const Sim = preload("res://tests/sim.gd")
const STREETS := preload("res://scenes/world/streets.tscn")

func _streets() -> Streets:
	return Sim.add(STREETS.instantiate())

## The road mesh's quads, as XZ rects (six vertices each).
func _road_rects(s: Streets) -> Array[Rect2]:
	var verts: PackedVector3Array = (s.get_node("Road") as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var out: Array[Rect2] = []
	for q in range(0, verts.size(), 6):
		var r := Rect2(verts[q].x, verts[q].z, 0, 0)
		for k in 6:
			r = r.expand(Vector2(verts[q + k].x, verts[q + k].z))
		out.append(r)
	return out

func test_road_covers_streets_and_no_lot() -> bool:
	var s := _streets()
	var rects := _road_rects(s)
	var ok := not rects.is_empty()
	for r in rects:
		for lot in s.plan.lots:
			if r.intersects(lot):
				ok = false
	# Sample every street on a 1 m grid; each point lies on some road quad.
	for street in s.plan.streets:
		var x := street.position.x + 0.37
		while ok and x < street.end.x:
			var z := street.position.y + 0.21
			while ok and z < street.end.y:
				var on := false
				for r in rects:
					if r.has_point(Vector2(x, z)):
						on = true
						break
				ok = on
				z += 1.0
			x += 1.0
	s.free()
	return ok

func test_lights_on_sidewalks_with_collision() -> bool:
	var s := _streets()
	await Sim.physics_frames(2)
	var layout := s.layout
	var space := s.get_world_3d().direct_space_state
	var ok := s.lights.size() > 20
	for p3 in s.lights:
		var p := Vector2(p3.x, p3.z)
		var on_walk := false
		for b in s.plan.blocks:
			if b.has_point(p) and not b.grow(-layout.sidewalk).has_point(p):
				on_walk = true
		for lot in s.plan.lots:
			if lot.grow(0.01).has_point(p):
				on_walk = false
		if not CityPlan.clear_of(layout, Rect2(p, Vector2.ZERO)):
			on_walk = false
		var q := PhysicsPointQueryParameters3D.new()
		q.position = p3 + Vector3.UP * 2.0
		var hits := space.intersect_point(q)
		var solid := hits.any(func(h): return h.collider == s)
		if not on_walk or not solid:
			ok = false
	s.free()
	return ok

func test_same_layout_same_placement() -> bool:
	Streets._cache.clear()
	var a := _streets()
	Streets._cache.clear()
	var b := _streets()
	var ok: bool = a.lights == b.lights and a.lights.size() > 0 and _road_rects(a) == _road_rects(b) \
		and a.get_node("Road").mesh != b.get_node("Road").mesh
	a.free()
	b.free()
	return ok
