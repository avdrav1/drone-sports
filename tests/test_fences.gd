extends RefCounted
# Story 26.10: fences with holes. Chain-link runs round vacant lots and along
# clear block edges, each with holes: a missing panel, a torn opening, or a
# lifted bottom edge. Every hole meets the epic's collision-guard rule and a
# drone-sized sphere passes through it; a cast through solid panel hits. Every
# fence stands on the ground, outside lanes, crossings and clearings. Same seed,
# same fences. The sandbox at seed 7 has at least 10 holes.

const Sim = preload("res://tests/sim.gd")
const Old = preload("res://tests/test_winding_old_town.gd")
const SANDBOX := preload("res://data/city/sandbox_city.tres")
const VARIETY := preload("res://data/city/free_flight_variety.tres")
const CITY := preload("res://scenes/world/city.tscn")
const STREETS := preload("res://scenes/world/streets.tscn")
const SPANS := preload("res://scenes/world/overhead_spans.tscn")
const FENCES := preload("res://scenes/world/fences.tscn")
const FREE_FLIGHT := "res://scenes/debug_flight.tscn"

## Seed 7's sandbox, then two rolled free-flight cities of each pattern, with
## lots left vacant so their fences show.
static func _layouts() -> Array[CityLayout]:
	var out: Array[CityLayout] = [SANDBOX]
	for pattern in CityLayout.Pattern.values():
		for k in 2:
			var l := VARIETY.roll(SANDBOX, 2610 + pattern * 977 + k * 4127)
			l.pattern = pattern
			l.vacant_chance = maxf(l.vacant_chance, 0.15)
			out.append(l)
	return out

## [city, streets, fences, ground] built from `l`, in the tree, with the spans
## too. The ground stands in for the desert, flat at y = 0 over the core.
static func _build(l: CityLayout) -> Array:
	var city: City = CITY.instantiate()
	city.layout = l
	var streets: Streets = STREETS.instantiate()
	streets.layout = l
	streets.add_child(SPANS.instantiate())
	var fences: Fences = FENCES.instantiate()
	streets.add_child(fences)
	var ground := StaticBody3D.new()
	var plane := CollisionShape3D.new()
	plane.shape = WorldBoundaryShape3D.new()
	ground.add_child(plane)
	for n in [city, streets, ground]:
		Sim.add(n)
	await Sim.physics_frames(2)
	return [city, streets, fences, ground]

static func _done(built: Array) -> void:
	for n in [built[0], built[1], built[3]]:
		n.free()
	City.prune(SANDBOX)
	Streets.prune(SANDBOX)
	StreetClutter.prune(SANDBOX)
	OverheadSpans.prune(SANDBOX)
	Fences.prune(SANDBOX)
	CityPlan.prune(SANDBOX)

## The least gap the epic's rule allows: the width of a sphere round the
## drone's collision box plus the guard's margin, and half again to spare.
static func _need() -> float:
	return Old._guard_size() * 3.0

## A sphere of `radius` from `from` to `to` meets nothing.
static func _sweep(space: PhysicsDirectSpaceState3D, radius: float, from: Vector3, to: Vector3) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis(), from)
	q.motion = to - from
	return space.intersect_shape(q, 1).is_empty() and space.cast_motion(q)[0] >= 1.0

## Every hole and lifted gap is at least the guard's need wide and tall, as is
## the layout's fence_hole, and a drone-sized sphere swept square through its
## middle, from clear of the fence on one side to clear of it on the other,
## meets nothing. Every run has a hole, and all three kinds turn up.
func test_every_hole_meets_the_guard_rule_and_a_drone_sphere_passes() -> bool:
	var need := _need()
	var radius := Old._guard_size()
	var ok := SANDBOX.fence_hole.x >= need and SANDBOX.fence_hole.y >= need
	var kinds := {}
	var vacant_runs := 0
	for l in _layouts():
		var built: Array = await _build(l)
		var fences: Fences = built[2]
		var space := fences.get_world_3d().direct_space_state
		var bad := 0
		for r in fences.runs:
			if r.vacant >= 0:
				vacant_runs += 1
			var holes := 0
			for p in r.panels:
				if p.hole == Fences.Hole.NONE:
					continue
				holes += 1
				kinds[p.hole] = true
				var good: bool = p.gap.size.x >= need and p.gap.size.y >= need
				var c := r.world(p.gap.get_center().x, p.gap.get_center().y)
				var n := Vector3(r.n.x, 0.0, r.n.y) * (radius + 0.3)
				var through := _sweep(space, radius, c - n, c + n)
				if not (good and through):
					bad += 1
					if bad <= 3:
						print("        seed %d: %s hole %s at %s fails (sphere passes: %s)" % [l.seed,
							Fences.Hole.keys()[p.hole], p.gap, c, through])
			if holes == 0:
				bad += 1
				print("        seed %d: a run at %s has no hole" % [l.seed, r.a])
		ok = ok and bad == 0
		_done(built)
	if kinds.size() != 3 or vacant_runs == 0:
		print("        hole kinds %s, %d runs round vacant lots" % [kinds.keys(), vacant_runs])
	return ok and kinds.size() == 3 and vacant_runs > 0

## Collision is per panel: one box per post and per solid part of a panel, so
## a sphere cast through the middle of every solid panel meets the fence, and
## a thin ray through each hole's middle does not.
func test_a_cast_through_solid_panel_hits() -> bool:
	var ok := true
	var solid := 0
	for l in _layouts():
		var built: Array = await _build(l)
		var fences: Fences = built[2]
		var space := fences.get_world_3d().direct_space_state
		var parts := 0
		for r in fences.runs:
			parts += r.posts().size()
			for p in r.panels:
				parts += p.boxes.size()
				var mid: float = (p.x0 + p.x1) * 0.5
				var c: Vector3 = r.world(mid, r.height * 0.5) if p.hole == Fences.Hole.NONE \
					else r.world(p.gap.get_center().x, p.gap.get_center().y)
				var n := Vector3(r.n.x, 0.0, r.n.y) * 0.6
				if p.hole == Fences.Hole.NONE:
					solid += 1
					var sphere := SphereShape3D.new()
					sphere.radius = 0.3
					var q := PhysicsShapeQueryParameters3D.new()
					q.shape = sphere
					q.transform = Transform3D(Basis(), c - n)
					q.motion = n * 2.0
					q.collide_with_bodies = true
					var hit := space.cast_motion(q)[0] < 1.0
					q.transform = Transform3D(Basis(), c - n + q.motion * space.cast_motion(q)[1])
					var on_fence := space.intersect_shape(q, 4).any(func(h): return h.collider == fences)
					if not (hit and on_fence):
						ok = false
						print("        seed %d: a cast through solid panel at %s misses the fence" % [l.seed, c])
				else:
					var ray := space.intersect_ray(PhysicsRayQueryParameters3D.create(c - n, c + n))
					if ray and ray.collider == fences:
						ok = false
						print("        seed %d: a ray through the hole at %s hits the fence" % [l.seed, c])
		# Panels are drawn by the posts and solid parts, nothing else.
		var shapes := fences.get_children().filter(func(x): return x is CollisionShape3D and x.shape is BoxShape3D)
		if shapes.size() != parts:
			# Corner posts two runs share are one post.
			var unique := {}
			for r in fences.runs:
				for x in r.posts():
					unique[(r.a + r.d * x).snapped(Vector2.ONE * 0.01)] = true
			var want := parts
			for r in fences.runs:
				want -= r.posts().size()
			want += unique.size()
			if shapes.size() != want:
				ok = false
				print("        seed %d: %d boxes for %d parts" % [l.seed, shapes.size(), want])
		_done(built)
	return ok and solid > 0

## Every post stands on the ground: a ray down from just above its foot meets
## the pavement or the sand at its base (vacant lots' fences on the sand). Every run's footprint stays off the
## lanes and crossings, the parking strips and crosswalks, every clearing,
## every building's lot, and the core's edge.
func test_every_fence_stands_on_the_ground_outside_lanes_crossings_and_clearings() -> bool:
	var ok := true
	var posts := 0
	for l in _layouts():
		var built: Array = await _build(l)
		var streets: Streets = built[1]
		var fences: Fences = built[2]
		var clutter: StreetClutter = streets.get_node("Clutter")
		var plan := streets.plan
		var space := fences.get_world_3d().direct_space_state
		var road: Array[PackedVector2Array] = []
		road.append_array(clutter.lanes)
		road.append_array(clutter.parking)
		road.append_array(streets.crosswalks)
		var bad := 0
		for r in fences.runs:
			for x in r.posts():
				posts += 1
				var foot := r.world(x)
				var q := PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 0.5, foot - Vector3.UP * 0.5)
				q.exclude = [fences.get_rid()]
				var hit := space.intersect_ray(q)
				# The pavement's top, or the sand (a vacant lot, a block the core's edge cuts).
				var expect: Node = built[3] if r.base == 0.0 else streets
				if not hit or hit.collider != expect or absf(hit.position.y - foot.y) > 0.01:
					bad += 1
					if bad <= 3:
						print("        seed %d: post at %s stands on %s" % [l.seed, foot, hit.get("position", "nothing")])
			var strip := r.strip(-fences.post_size * 0.5, r.length + fences.post_size * 0.5, fences.post_size * 0.5)
			var clear := Streets.within(strip, l.core_radius) and _clear_of_circles(strip, l)
			for poly in road:
				clear = clear and not Streets.overlaps(strip, poly)
			for lot in plan.lots:
				clear = clear and not Streets.overlaps(strip, CityPlan.polygon(lot))
			if r.vacant >= 0:
				clear = clear and r.base == 0.0 and plan.vacant[r.vacant].encloses(Streets.bounds(strip))
			else:
				for v in plan.vacant:
					clear = clear and not Streets.overlaps(strip, CityPlan.polygon(v))
			if not clear:
				bad += 1
				if bad <= 3:
					print("        seed %d: run at %s stands in a lane, crossing, clearing or lot" % [l.seed, r.a])
		ok = ok and bad == 0
		_done(built)
	return ok and posts > 0

## True when the strip keeps out of every clearing, corner to corner and along
## its sides (a strip's bounds can touch a clearing it never enters).
static func _clear_of_circles(strip: PackedVector2Array, l: CityLayout) -> bool:
	for c in l.clearings:
		var at := Vector2(c.x, c.y)
		if Geometry2D.is_point_in_polygon(at, strip):
			return false
		for i in strip.size():
			var p: Vector2 = Geometry2D.get_closest_point_to_segment(at, strip[i], strip[(i + 1) % strip.size()])
			if p.distance_to(at) < c.z:
				return false
	return true

## Same seed, same fences and holes: two builds from scratch match run for run.
func test_same_seed_same_fences_and_holes() -> bool:
	var ok := true
	for l in [SANDBOX, _layouts()[3]]:
		var runs := []
		for n in 2:
			var built: Array = await _build(l)
			var out := []
			for r in (built[2] as Fences).runs:
				out.append([r.a, r.d, r.base, r.length, r.vacant, r.panels.map(func(p): return [p.hole, p.gap, p.boxes])])
			runs.append(str(out))
			_done(built)
			Fences._cache.clear()
		ok = ok and runs[0] == runs[1] and runs[0] != "[]"
	return ok

## The sandbox at seed 7 has at least 10 holes.
func test_the_sandbox_at_seed_7_has_at_least_10_holes() -> bool:
	var built: Array = await _build(SANDBOX)
	var fences: Fences = built[2]
	var n := fences.holes().size()
	var runs := fences.runs.size()
	_done(built)
	if n < 10:
		print("        seed 7: %d holes in %d runs" % [n, runs])
	return SANDBOX.seed == 7 and n >= 10

## The panels draw see-through chain link from a shader that keeps to what GL
## Compatibility runs: it discards between the wires and reads no screen or
## depth texture.
func test_panels_use_a_compatibility_chain_link_shader() -> bool:
	var fences: Fences = FENCES.instantiate()
	var mat := fences.panel_material as ShaderMaterial
	fences.free()
	if mat == null or mat.shader == null:
		return false
	var code := mat.shader.code
	var ok := code.contains("discard") and code.contains("cull_disabled")
	for banned in ["hint_screen_texture", "hint_depth_texture", "hint_normal_roughness_texture", "SCREEN_TEXTURE", "DEPTH_TEXTURE"]:
		ok = ok and not code.contains(banned)
	return ok and mat.shader.get_shader_uniform_list().size() > 0

## Free flight builds fences for its city, and a reroll rebuilds them for the
## new one, keeping one layout's entries in the cache.
func test_free_flight_has_fences_and_a_reroll_rebuilds_them() -> bool:
	var s: Node = Sim.add(load(FREE_FLIGHT).instantiate())
	await Sim.physics_frames(2)
	var fences: Fences = s.get_node("Streets/Fences")
	var ok: bool = fences.layout == s.city.layout and fences.get_child_count() > 0
	s.reroll_city()
	await Sim.physics_frames(2)
	ok = ok and fences.layout == s.city.layout and Fences._cache.size() == 1
	var parts := 0
	for r in fences.runs:
		for p in r.panels:
			parts += p.boxes.size()
	ok = ok and fences.get_children().filter(func(c): return c is CollisionShape3D).size() >= parts
	s.free()
	return ok
