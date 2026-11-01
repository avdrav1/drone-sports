extends RefCounted
# Story 26.2: cities that differ in proportion, not just lots. Each free-flight
# seed rolls block size, street and avenue widths, heights, and vacant lots from
# CityVariety; every rolled plan still passes the 12.1 checks, a vacant_chance
# of 0 builds the plan from before the field, and free flight loads cleanly.

const Sim = preload("res://tests/sim.gd")
const SANDBOX := preload("res://data/city/sandbox_city.tres")
const VARIETY := preload("res://data/city/free_flight_variety.tres")
const DESERT := preload("res://scenes/world/desert.tscn")
const FREE_FLIGHT := "res://scenes/debug_flight.tscn"

## md5s of [lots, heights, streets, blocks] and of the shapes, taken from the
## plan generator before vacant_chance existed (commit 7ead3e5).
const BEFORE := {
	7: ["7bce7c00a1df380e9006eab1c7e1f11f", "cd07e9753d347494f9398d0e9671ea4f"],
	8: ["5ebd1ac55cfcd190df00887a02386f54", "e2aac0040aefc036bc79fa141490d07e"],
	99: ["aaeac7dd8ee55305ac47ef24f14bac39", "a82d6c3a3e806265f4822202494337b9"],
	12345: ["60416cd9659d8eaebda7a36068fc52b8", "b370418bb814ba3b256c7914b5fcde4f"],
	424242: ["1695a4be00eefaa7fdc9d90244847347", "f2226a8499a5052497dc892ef703921c"],
}

static func _fingerprint(p: CityPlan) -> Array:
	var shapes := ""
	for sh in p.shapes:
		shapes += "%s%s%s%s" % [sh.boxes, sh.trims, sh.trim_kinds, sh.roof_clear]
	return [("%s %s %s %s" % [p.lots, p.heights, p.streets, p.blocks]).md5_text(), shapes.md5_text()]

## The 12.1 checks on a plan: lots and vacant lots clear of streets, of each
## other, and of clearings, and inside the core and the flat ground.
static func _passes_12_1(layout: CityLayout, p: CityPlan, flat: float) -> bool:
	var all: Array[Rect2] = p.lots + p.vacant
	if p.lots.is_empty() or p.heights.size() != p.lots.size() or p.shapes.size() != p.lots.size():
		return false
	for i in all.size():
		var lot := all[i]
		if not CityPlan.clear_of(layout, lot) or not CityPlan.inside(lot, layout.core_radius) \
				or not CityPlan.inside(lot, flat):
			return false
		for s in p.streets:
			if lot.intersects(s):
				return false
		for j in range(i + 1, all.size()):
			if lot.intersects(all[j]):
				return false
	for h in p.heights:
		if h < layout.height_min - 0.001 or h > layout.height_max + 0.001:
			return false
	return true

func _flat_radius() -> float:
	var terrain: DesertTerrain = DESERT.instantiate()
	var flat := terrain.flat_radius
	terrain.free()
	return flat

func test_fifty_seeds_roll_in_range_and_pass_12_1() -> bool:
	var flat := _flat_radius()
	var ok := SANDBOX.core_radius <= flat and VARIETY.street_width.y < VARIETY.avenue_width.x \
		and VARIETY.lot_min.y < VARIETY.lot_max.x \
		and VARIETY.block_size.x - SANDBOX.sidewalk * 2.0 >= VARIETY.lot_min.y
	var vacant := 0
	for k in 50:
		var s := 1000 + k * 7919
		var l := VARIETY.roll(SANDBOX, s)
		ok = ok and l.seed == s and l != SANDBOX and l.core_radius == SANDBOX.core_radius \
			and l.clearings == SANDBOX.clearings
		for f in CityVariety.FIELDS:
			var r: Vector2 = VARIETY.get(f)
			var v: float = l.get(f)
			if v < r.x or v > r.y:
				print("        seed %d: %s = %s outside %s" % [s, f, v, r])
				ok = false
		var p := CityPlan._generate(l)
		vacant += p.vacant.size()
		if not _passes_12_1(l, p, flat):
			print("        seed %d fails the 12.1 checks" % s)
			ok = false
	# The shared sandbox layout is not touched by rolling.
	return ok and vacant > 0 and SANDBOX.seed == 7 and SANDBOX.block_size == 30.0 and SANDBOX.vacant_chance == 0.0

func test_one_seed_one_city() -> bool:
	var a := VARIETY.roll(SANDBOX, 4242)
	var b := VARIETY.roll(SANDBOX, 4242)
	return a.params() == b.params() and _fingerprint(CityPlan._generate(a)) == _fingerprint(CityPlan._generate(b)) \
		and CityPlan._generate(a).vacant == CityPlan._generate(b).vacant

func test_most_pairs_differ_in_two_proportions() -> bool:
	var rolled: Array[CityLayout] = []
	for k in 20:
		rolled.append(VARIETY.roll(SANDBOX, 31 + k * 104729))
	var pairs := 0
	var differ := 0
	for i in rolled.size():
		for j in range(i + 1, rolled.size()):
			var a := rolled[i]
			var b := rolled[j]
			var n := int(a.block_size != b.block_size) + int(a.street_width != b.street_width) \
				+ int(a.height_min != b.height_min or a.height_max != b.height_max)
			pairs += 1
			differ += int(n >= 2)
	print("        %d of %d pairs differ in two or more" % [differ, pairs])
	return differ * 2 > pairs

func test_no_vacancy_builds_the_plan_from_before() -> bool:
	var ok := true
	for s: int in BEFORE:
		var l: CityLayout = SANDBOX.duplicate()
		l.seed = s
		l.vacant_chance = 0.0
		var p := CityPlan._generate(l)
		if _fingerprint(p) != BEFORE[s] or not p.vacant.is_empty():
			print("        seed %d: %s" % [s, _fingerprint(p)])
			ok = false
		# With vacancy on, the same lots stand or lie empty, in the same order,
		# and the ones that stand keep their heights.
		var v: CityLayout = l.duplicate()
		v.vacant_chance = 0.3
		var q := CityPlan._generate(v)
		var kept := 0
		var gone := 0
		for i in p.lots.size():
			if kept < q.lots.size() and q.lots[kept] == p.lots[i]:
				ok = ok and q.heights[kept] == p.heights[i]
				kept += 1
			elif gone < q.vacant.size() and q.vacant[gone] == p.lots[i]:
				gone += 1
			else:
				ok = false
		ok = ok and kept == q.lots.size() and gone == q.vacant.size() and gone > 0 and kept > 0
	return ok

## Pavement is cut round vacant lots, so the sand shows; the cut pieces never
## overlap a vacant lot or each other and cover the rest of the block.
func test_vacant_lots_are_sand() -> bool:
	var r := Rect2(0, 0, 30, 30)
	var holes: Array[Rect2] = [Rect2(3, 3, 10, 10), Rect2(14, 3, 13, 10), Rect2(3, 20, 24, 7)]
	var pieces := Streets.cut(r, holes)
	var area := 0.0
	var whole := Streets.cut(r, [] as Array[Rect2])
	var ok := whole.size() == 1 and whole[0] == r
	for i in pieces.size():
		area += pieces[i].get_area()
		ok = ok and r.encloses(pieces[i])
		for h in holes:
			ok = ok and not pieces[i].intersects(h)
		for j in range(i + 1, pieces.size()):
			ok = ok and not pieces[i].intersects(pieces[j])
	return ok and is_equal_approx(area, 900.0 - 100.0 - 130.0 - 168.0)

func test_free_flight_loads_twenty_seeds() -> bool:
	var ok := true
	for k in 20:
		var s := 500 + k * 6151
		var scene: Node = load(FREE_FLIGHT).instantiate()
		scene.use_city_seed(s)
		Sim.add(scene)
		await Sim.process_frames(2)
		var city: City = scene.get_node("City")
		var streets: Streets = scene.get_node("Streets")
		var want := VARIETY.roll(SANDBOX, s)
		var good: bool = scene.city_seed == s and city.layout.params() == want.params() \
			and (scene.get_node("Rooftops") as Rooftops).layout == city.layout \
			and streets.plan == city.plan and city.plan.lots.size() > 20
		# No pavement over a vacant lot (shapes hold float32, so edges may touch).
		# A wedge's pavement (a diagonal city, Story 26.6) is a prism.
		for c in streets.get_children():
			if c is CollisionShape3D and c.name.begins_with("Pavement"):
				var flat := PackedVector2Array()
				if c.shape is BoxShape3D:
					var size: Vector3 = c.shape.size
					flat = CityPlan.polygon(Rect2(c.position.x - size.x * 0.5, c.position.z - size.z * 0.5, size.x, size.z))
				else:
					for q: Vector3 in (c.shape as ConvexPolygonShape3D).points:
						if q.y == 0.0:
							flat.append(Vector2(q.x, q.z) + Vector2(c.position.x, c.position.z))
				for v in city.plan.vacant:
					var over := 0.0
					for part in Geometry2D.intersect_polygons(flat, CityPlan.polygon(v)):
						over += absf(CityPlan.area(part))
					if over > 0.01:
						print("        pavement %s over vacant %s" % [Streets.bounds(flat), v])
						good = false
		if not good:
			print("        seed %d does not build its rolled city: %s %s %d" % [s, scene.city_seed,
				city.layout.params() == want.params(), city.plan.lots.size()])
		ok = ok and good
		scene.free()
	return ok

## Free flight shows rooftop pads on its radar (test_radar and test_city_sandbox
## ask for at least three) whatever city it rolls; a low city fills them from its
## tallest broad roofs.
func test_every_rolled_city_has_its_pads() -> bool:
	var ok := true
	var rooftops: PackedScene = load("res://scenes/world/rooftops.tscn")
	for k in 50:
		var s := 77 + k * 2333
		var r: Rooftops = rooftops.instantiate()
		r.layout = VARIETY.roll(SANDBOX, s)
		Sim.add(r)
		if r.pads.size() < 3:
			print("        seed %d: %d pads" % [s, r.pads.size()])
			ok = false
		r.free()
		Rooftops.prune(SANDBOX)
		CityPlan.prune(SANDBOX)
	return ok
