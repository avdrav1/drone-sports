extends RefCounted
# Story 15.8: desert ground. Seeded scatter kept off the city and the courses,
# collision only on what stands above the knee, and dust that follows the wind.

const Sim = preload("res://tests/sim.gd")
const DESERT := preload("res://scenes/world/desert.tscn")
const COUNTS := Vector3i(2000, 3000, 400)

## A terrain built but not in the tree, so it scatters nothing of its own.
func _terrain(seed: int) -> DesertTerrain:
	var t: DesertTerrain = DESERT.instantiate()
	t.noise_seed = seed
	t.build()
	return t

func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i][0] != b[i][0] or a[i][1] != b[i][1] or not a[i][2].is_equal_approx(b[i][2]) or a[i][3] != b[i][3]:
			return false
	return true

func test_scatter_repeats_with_seed() -> bool:
	var a := _terrain(5)
	var b := _terrain(5)
	var c := _terrain(6)
	var keep := [[Vector2.ZERO, Vector2.ZERO, 140.0]]
	var pa := DesertScatter._generate(a, keep, COUNTS)
	var pb := DesertScatter._generate(b, keep, COUNTS)
	var pc := DesertScatter._generate(c, keep, COUNTS)
	var kinds := [0, 0, 0]
	for item in pa:
		kinds[item[0]] += 1
	a.free()
	b.free()
	c.free()
	# Every kind is placed in bulk.
	return _same(pa, pb) and not _same(pa, pc) and kinds[0] > 500 and kinds[1] > 500 and kinds[2] > 100

## Every scattered item in a loaded scene's ground.
func _scene_plan(scene: Node) -> Array:
	var ground: DesertTerrain = scene.get_node("Ground")
	var scatter: DesertScatter = ground.get_node("Scatter")
	var keep := DesertScatter.keep_outs(scene, ground)
	return DesertScatter.plan(ground, keep, Vector3i(scatter.rock_count, scatter.scrub_count, scatter.cactus_count))

func test_scatter_stays_out_of_city_core_and_clearings() -> bool:
	var scene: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	await Sim.process_frames(2)
	var city: City = scene.get_node("City")
	var ok := scene.get_node("Ground/Scatter").get_child_count() > 0
	var core := Vector2(city.global_position.x, city.global_position.z)
	var items := _scene_plan(scene)
	ok = ok and items.size() > 1000
	for item in items:
		var p := Vector2(item[2].origin.x, item[2].origin.z)
		if p.distance_to(core) < city.layout.core_radius:
			ok = false
		for cl in city.layout.clearings:
			var c3 := city.to_global(Vector3(cl.x, 0.0, cl.y))
			if p.distance_to(Vector2(c3.x, c3.z)) < cl.z:
				ok = false
	scene.free()
	return ok

## Distance from p to the line between gates i and i + 1 of a course, flat.
func _to_course(p: Vector2, course: Course) -> float:
	var gates := course.data.gates
	var best := INF
	for i in gates.size():
		var a := course.to_global(gates[i].origin)
		var b := course.to_global(gates[(i + 1) % gates.size()].origin)
		var q := Geometry2D.get_closest_point_to_segment(p, Vector2(a.x, a.z), Vector2(b.x, b.z))
		best = minf(best, p.distance_to(q))
	return best

func test_scatter_clear_of_course_lines() -> bool:
	var scene: Node = Sim.add(load("res://scenes/jobs/test_race.tscn").instantiate())
	await Sim.process_frames(2)
	var course: Course = scene.get_node("Course")
	var radius := DesertScatter.gate_radius(course.data)
	var ok := radius > 0.0
	for item in _scene_plan(scene):
		if _to_course(Vector2(item[2].origin.x, item[2].origin.z), course) < radius:
			ok = false
	scene.free()
	# A course out on the dunes, where scatter would otherwise lie, is kept clear too.
	var t := _terrain(1)
	var line := [Vector2(200.0, -60.0), Vector2(420.0, 80.0), radius]
	var near_without := 0
	for item in DesertScatter._generate(t, [], COUNTS):
		if DesertScatter.clearance(Vector2(item[2].origin.x, item[2].origin.z), [line]) < 0.0:
			near_without += 1
	for item in DesertScatter._generate(t, [line], COUNTS):
		if DesertScatter.clearance(Vector2(item[2].origin.x, item[2].origin.z), [line]) < 0.0:
			ok = false
	t.free()
	return ok and near_without > 0

func test_only_tall_scatter_collides_outside_flat_area() -> bool:
	var t := _terrain(1)
	var ok := true
	var tall := 0
	for item in DesertScatter._generate(t, [], COUNTS):
		var xf: Transform3D = item[2]
		var expect: bool = item[0] == DesertScatter.Kind.CACTUS or (item[0] == DesertScatter.Kind.ROCK and xf.basis.get_scale().y * DesertScatter.rock_top(item[1]) > DesertScatter.KNEE)
		if item[3] != expect:
			ok = false
		if item[3]:
			tall += 1
			if Vector2(xf.origin.x, xf.origin.z).length() < t.flat_radius:
				ok = false
	t.free()
	return ok and tall > 0

func test_cactus_is_a_contact_and_scrub_is_not() -> bool:
	var scene: Node = Sim.add(load("res://scenes/jobs/test_race.tscn").instantiate())
	await Sim.physics_frames(2)
	var ground: DesertTerrain = scene.get_node("Ground")
	var scatter: DesertScatter = ground.get_node("Scatter")
	var space := ground.get_world_3d().direct_space_state
	var cactus_hit := false
	var scrub_through := false
	for item in _scene_plan(scene):
		var xf: Transform3D = item[2]
		var from := xf.origin + Vector3.UP * 20.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, xf.origin + Vector3.DOWN))
		if item[0] == DesertScatter.Kind.CACTUS and not cactus_hit:
			cactus_hit = not hit.is_empty() and hit.collider == scatter
		elif item[0] == DesertScatter.Kind.SCRUB and not scrub_through:
			# Unless a rock or cactus stands over it, a ray down a bush reaches the ground.
			scrub_through = not hit.is_empty() and hit.collider == ground
		if cactus_hit and scrub_through:
			break
	scene.free()
	return cactus_hit and scrub_through

func _dust_amount(base: Vector3) -> int:
	var dust: DesertDust = Sim.add(DesertDust.new())
	if base != Vector3.INF:
		dust.wind = Wind.new()
		dust.wind.base = base
	dust.advance(0.1)
	var n := dust.particles.amount if dust.particles else 0
	dust.free()
	return n

func test_dust_follows_wind_speed_and_is_zero_in_still_air() -> bool:
	var none := _dust_amount(Vector3.INF)
	var still := _dust_amount(Vector3.ZERO)
	var light := _dust_amount(Vector3(5.0, 0.0, 0.0))
	var strong := _dust_amount(Vector3(0.0, 0.0, -12.0))
	var gale := _dust_amount(Vector3(30.0, 0.0, 0.0))
	var probe := DesertDust.new()
	var curve: bool = probe.amount_for(0.0) == 0 and probe.amount_for(probe.lift_speed) == 0 and probe.amount_for(probe.full_speed) == probe.max_amount
	probe.free()
	return none == 0 and still == 0 and light > 0 and strong > light and gale >= strong and curve
