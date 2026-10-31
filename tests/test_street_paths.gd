extends RefCounted
# Story 26.4: streets as paths. Beside its rectangles the plan describes each
# street as a centreline with a width and a kind, the junctions joining them,
# and each block as a polygon the lots are cut from. For seed 7 and 20 broken
# grid seeds the general form covers the same ground as the rectangles and the
# lots are those from before the story. Job scenes keep their obstacle
# fingerprints: test_obstacle_structures checks them against the same md5s.

const Variety = preload("res://tests/test_city_variety.gd")
const Broken = preload("res://tests/test_broken_grids.gd")
const SANDBOX := preload("res://data/city/sandbox_city.tres")
const DESERT := preload("res://scenes/world/desert.tscn")

## md5s of [lots, heights, streets, street_axis, blocks, dropped, squares,
## vacant], taken from the plan generator before this story (commit 83a1bff).
## Seed 7 is the sandbox; the others are Broken._broken(seed).
const BEFORE := {
	7: "6752339c616d3d31351e263de0e4d558",
	26400: "0b22cc4e98b15842385c4d2c40faed70",
	27013: "546d7f3eb0ac38118816c1c78abaad62",
	27626: "166339c15cb19fd89fad437e2f330736",
	28239: "d3b1d04c9ba018463cdbd9b70ea17543",
	28852: "cc88a5f7cb5fb874039434082366de83",
	29465: "89c066d4d50d5ded307d934e1e24a6ff",
	30078: "d624398c67a03db35e36515ba473fe08",
	30691: "82a0f2685fe42163a52f1e3f3b8ba57e",
	31304: "e217d599bc653481d5ea1201dfd5be2d",
	31917: "c01f7ce3ee8e9224d3907e95708dfc8b",
	32530: "1a723956d1c09f8a59e457958dfdf4a9",
	33143: "f0be9ffb82c07c5a0ec2c20bf4861180",
	33756: "0f3604423b2d1d7f41203a0ef36a1d43",
	34369: "6bb284cfc37d2accb916c68db06ace1e",
	34982: "74e8eec199cef0dd7d33e917d5945e16",
	35595: "919ae80485301173db4aba1a1ac2233b",
	36208: "5510a3a04aeeb0bc5a8379a3b489ddbc",
	36821: "b91a46595a53b3b907021ab1e6162148",
	37434: "378507563df03605d2783be56d07f3cf",
	38047: "9d8abcc2c355d268841e4ff7999caa47",
}

static func _layout(s: int) -> CityLayout:
	return SANDBOX if s == 7 else Broken._broken(s)

static func _text(p: CityPlan) -> String:
	return "%s %s %s %s %s %s %s %s" % [p.lots, p.heights, p.streets, p.street_axis, p.blocks, p.dropped,
		p.squares, p.vacant]

## True when `q` lies on the ground the path covers: within half its width of
## a centreline segment, between the segment's ends.
static func _on_path(path: CityPlan.Street, q: Vector2) -> bool:
	for i in path.points.size() - 1:
		var a := path.points[i]
		var d := path.points[i + 1] - a
		var t := (q - a).dot(d) / d.length_squared()
		if t >= 0.0 and t <= 1.0 and absf((q - a).cross(d.normalized())) <= path.width * 0.5:
			return true
	return false

func test_lots_are_the_ones_from_before() -> bool:
	var ok := true
	for s: int in BEFORE:
		var p := CityPlan._generate(_layout(s))
		if _text(p).md5_text() != BEFORE[s]:
			print("        seed %d: plan differs from before" % s)
			ok = false
		ok = ok and p.lot_block.size() == p.lots.size() and p.vacant_block.size() == p.vacant.size() \
			and p.paths.size() == p.streets.size() and p.block_polygons.size() == p.blocks.size()
	return ok

func test_paths_cover_the_same_ground_as_the_street_rects() -> bool:
	var ok := true
	var avenues := 0
	for s: int in BEFORE:
		var l := _layout(s)
		var p := CityPlan._generate(l)
		for i in p.streets.size():
			var rect := p.streets[i]
			var path := p.paths[i]
			var ax := p.street_axis[i]
			# One straight centreline down the rect's middle, end to end, with
			# its points in order, and the rect's width across.
			var a := path.points[0]
			var e := path.points[path.points.size() - 1]
			var width := rect.size.x if ax == 0 else rect.size.y
			var mid := rect.get_center()
			var want_a := Vector2(mid.x, rect.position.y) if ax == 0 else Vector2(rect.position.x, mid.y)
			var want_e := Vector2(mid.x, rect.end.y) if ax == 0 else Vector2(rect.end.x, mid.y)
			ok = ok and a.is_equal_approx(want_a) and e.is_equal_approx(want_e) and is_equal_approx(path.width, width)
			for k in range(1, path.points.size()):
				var step := path.points[k] - path.points[k - 1]
				ok = ok and step.length() > 0.001 and absf(step.normalized().cross((e - a).normalized())) < 0.0001 \
					and step.dot(e - a) > 0.0
			var avenue := is_equal_approx(width, l.avenue_width)
			ok = ok and path.kind == (CityPlan.Kind.AVENUE if avenue else CityPlan.Kind.STREET)
			avenues += int(avenue)
		# The same ground, point by point over the core: on a street rect exactly
		# when on a path, and in a block rect exactly when in a block polygon.
		var r := l.core_radius
		var x := -r + 0.37
		while x < r:
			var z := -r + 0.61
			while z < r:
				var q := Vector2(x, z)
				var on_rect := p.streets.any(func(st): return st.has_point(q))
				var on_path := p.paths.any(func(pa): return _on_path(pa, q))
				var in_block := p.blocks.any(func(b): return b.has_point(q))
				var in_poly := p.block_polygons.any(func(pg): return Geometry2D.is_point_in_polygon(q, pg))
				if on_rect != on_path or in_block != in_poly:
					print("        seed %d: %s street %s/%s block %s/%s" % [s, q, on_rect, on_path, in_block, in_poly])
					ok = false
				z += 2.0
			x += 2.0
		if not ok:
			print("        seed %d: paths and rects differ" % s)
			return false
	return ok and avenues > 20

func test_junctions_join_crossing_streets() -> bool:
	var ok := true
	var tees := 0
	var crossings := 0
	for s: int in BEFORE:
		var p := CityPlan._generate(_layout(s))
		for j in p.junctions:
			ok = ok and j.streets.size() >= 2
			for n in j.streets:
				# On each street's ground, with the point on its centreline
				# nearest it among the centreline's points. Where two streets
				# cross that point is the junction itself.
				var path: CityPlan.Street = p.paths[n]
				var near := Geometry2D.get_closest_point_to_segment(j.at, path.points[0], path.points[-1])
				ok = ok and Array(path.points).any(func(pt): return pt.distance_to(near) < 0.001) \
					and p.streets[n].grow(0.001).has_point(j.at)
				crossings += int(near.distance_to(j.at) < 0.001)
		# Every pair of streets that share ground meet at a junction, and only those.
		for i in p.streets.size():
			for k in range(i + 1, p.streets.size()):
				var meet := p.junctions.any(func(j): return j.streets.has(i) and j.streets.has(k))
				ok = ok and meet == p.streets[i].intersects(p.streets[k])
		# The junction graph is connected exactly when the rects are.
		var seen := {0: true}
		var todo := [0]
		while not todo.is_empty():
			var i: int = todo.pop_back()
			for j in p.junctions:
				if j.streets.has(i):
					for n in j.streets:
						if not seen.has(n):
							seen[n] = true
							todo.append(n)
		ok = ok and (seen.size() == p.streets.size()) == CityPlan.connected(p.streets) and CityPlan.connected(p.streets)
		# Streets cut short by a drop end across another street: a T-junction.
		for i in p.paths.size():
			for end in [p.paths[i].points[0], p.paths[i].points[-1]]:
				for k in p.streets.size():
					if k != i and p.street_axis[k] != p.street_axis[i] and p.streets[k].grow(0.001).has_point(end):
						tees += 1
		if not ok:
			print("        seed %d: junctions wrong" % s)
			return false
	return ok and tees > 10 and crossings > 500

## Every block polygon is closed (three or more distinct points, area, last
## joining first), never crosses itself, and every stretch of its outline
## faces a street or the core's edge: the ground just outside is street, the
## outline itself is outside the core, or a line straight out leaves the core
## within a street's width, crossing no street or block (the core's edge leaves
## such strips where a grid line fell outside the core).
func test_block_polygons_are_closed_simple_and_bounded() -> bool:
	var ok := true
	var on_street := 0
	var on_edge := 0
	for s: int in BEFORE:
		var l := _layout(s)
		var p := CityPlan._generate(l)
		var r := l.core_radius
		var reach := maxf(l.avenue_width, l.street_width) + 0.1
		for b in p.block_polygons.size():
			var pg := p.block_polygons[b]
			var n := pg.size()
			var area := CityPlan.area(pg)
			ok = ok and n >= 3 and absf(area) > 1.0 and not pg[0].is_equal_approx(pg[n - 1])
			for i in n:
				var a := pg[i]
				var e := pg[(i + 1) % n]
				ok = ok and a.distance_to(e) > 0.001
				for k in n:
					if k == i or k == (i + 1) % n or (k + 1) % n == i:
						continue
					if Geometry2D.segment_intersects_segment(a, e, pg[k], pg[(k + 1) % n]) != null:
						print("        seed %d: block %d crosses itself" % [s, b])
						ok = false
				var d := (e - a).normalized()
				var out := Vector2(d.y, -d.x) * signf(area)
				var steps := ceili(a.distance_to(e))
				for m in steps:
					var q := a.lerp(e, (m + 0.5) / steps)
					if p.streets.any(func(st): return st.grow(0.001).has_point(q + out * 0.05)):
						on_street += 1
						continue
					if _leaves_core(p, b, q, out, r, reach):
						on_edge += 1
						continue
					print("        seed %d: block %d edge at %s faces neither street nor core edge" % [s, b, q])
					ok = false
					break
		if not ok:
			return false
	print("        %d outline metres on streets, %d on the core's edge" % [on_street, on_edge])
	return ok and on_street > 0 and on_edge > 0

## True when `q` lies outside the core (the block runs on past it), or a line
## from `q` along `out` leaves the core within `reach` without crossing a
## street or another block on the way.
static func _leaves_core(p: CityPlan, mine: int, q: Vector2, out: Vector2, r: float, reach: float) -> bool:
	if q.length() >= r:
		return true
	var t := 0.05
	while t <= reach:
		var at := q + out * t
		if at.length() >= r:
			return true
		if p.streets.any(func(st): return st.has_point(at)):
			return false
		for k in p.block_polygons.size():
			if k != mine and Geometry2D.is_point_in_polygon(at, p.block_polygons[k]):
				return false
		t += 0.25
	return false

func test_lots_lie_inside_their_blocks_and_pass_12_1() -> bool:
	var terrain: DesertTerrain = DESERT.instantiate()
	var flat := terrain.flat_radius
	terrain.free()
	var ok := true
	var count := 0
	for s: int in BEFORE:
		var l := _layout(s)
		var p := CityPlan._generate(l)
		var all: Array[Rect2] = p.lots + p.vacant
		var of: PackedInt32Array = p.lot_block + p.vacant_block
		for i in all.size():
			var lot := all[i]
			var pg := p.block_polygons[of[i]]
			# Every corner inside the outline, and none of the lot outside it.
			for c in CityPlan.polygon(lot):
				ok = ok and Geometry2D.is_point_in_polygon(c, pg)
			ok = ok and CityPlan.fits(lot, pg) and p.blocks[of[i]].encloses(lot)
			ok = ok and not p.squares.has(p.blocks[of[i]])
			count += 1
		if not Variety._passes_12_1(l, p, flat):
			print("        seed %d fails the 12.1 checks" % s)
			ok = false
	# A lot sticking out of an outline does not fit.
	var square := CityPlan.polygon(Rect2(0, 0, 10, 10))
	ok = ok and CityPlan.fits(Rect2(1, 1, 8, 8), square) and not CityPlan.fits(Rect2(5, 5, 8, 2), square)
	return ok and count > 1000

func test_same_seed_same_general_form() -> bool:
	var a := CityPlan._generate(_layout(27013))
	var b := CityPlan._generate(_layout(27013))
	var text := func(p: CityPlan) -> String:
		var t := "%s %s %s" % [p.block_polygons, p.lot_block, p.vacant_block]
		for path in p.paths:
			t += "%s %s %s" % [path.points, path.width, path.kind]
		for j in p.junctions:
			t += "%s %s" % [j.at, j.streets]
		return t
	return text.call(a) == text.call(b) and not a.junctions.is_empty()
