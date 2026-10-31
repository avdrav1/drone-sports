extends RefCounted
# Story 26.6: diagonal avenues. A DIAGONAL city lays the grid, then one or two
# avenues across it at a seeded angle (20° to 70° to the grid) through or near
# the centre, splitting the blocks they cross into wedges along their kerbs.
# Across 30 seeds the network is connected, every clearing touches a street,
# every lot sits inside its block and passes the 12.1 checks, no wedge holds a
# lot narrower than lot_min, and each avenue runs at its angle across the whole
# core. CityVariety weights the patterns, so a seed picks one.

const Sim = preload("res://tests/sim.gd")
const Variety = preload("res://tests/test_city_variety.gd")
const Roads = preload("res://tests/test_roads_any_angle.gd")
const SANDBOX := preload("res://data/city/sandbox_city.tres")
const VARIETY := preload("res://data/city/free_flight_variety.tres")
const DESERT := preload("res://scenes/world/desert.tscn")
const STREETS := preload("res://scenes/world/streets.tscn")

static func _seeds() -> Array[int]:
	var out: Array[int] = []
	for k in 30:
		out.append(2606 + k * 4099)
	return out

## A rolled free-flight layout for seed `s`, set to the diagonal pattern.
static func diagonal(s: int) -> CityLayout:
	var l := VARIETY.roll(SANDBOX, s)
	l.pattern = CityLayout.Pattern.DIAGONAL
	return l

## True when the polygon shares more than `least` m² with the other.
static func _meets(a: PackedVector2Array, b: PackedVector2Array, least := 0.01) -> bool:
	if not Streets.bounds(a).intersects(Streets.bounds(b)):
		return false
	for part in Geometry2D.intersect_polygons(a, b):
		if absf(CityPlan.area(part)) > least:
			return true
	return false

## True when the circle (x, z, radius) reaches into the polygon.
static func _reaches(c: Vector3, poly: PackedVector2Array) -> bool:
	var at := Vector2(c.x, c.y)
	if Geometry2D.is_point_in_polygon(at, poly):
		return true
	for i in poly.size():
		if Geometry2D.get_closest_point_to_segment(at, poly[i], poly[(i + 1) % poly.size()]).distance_to(at) < c.z:
			return true
	return false

## True when the block polygon is not an axis-aligned rect: a wedge.
static func _wedge(poly: PackedVector2Array) -> bool:
	return not Streets.square(poly)

func test_variety_weights_pick_a_pattern_per_seed() -> bool:
	var seen := {}
	var ok := VARIETY.pattern_weights.size() == CityLayout.Pattern.size()
	for k in 40:
		var s := 77 + k * 613
		var a := VARIETY.roll(SANDBOX, s)
		var b := VARIETY.roll(SANDBOX, s)
		ok = ok and a.pattern == b.pattern
		seen[a.pattern] = true
	# A weight of 0 never comes up; the pattern is picked from its own stream,
	# so every other rolled field is what it was.
	var only_grid: CityVariety = VARIETY.duplicate()
	only_grid.pattern_weights = PackedFloat32Array([1.0, 0.0, 0.0])
	var only_diagonal: CityVariety = VARIETY.duplicate()
	only_diagonal.pattern_weights = PackedFloat32Array([0.0, 1.0, 0.0])
	for k in 20:
		var g := only_grid.roll(SANDBOX, 5 + k)
		var d := only_diagonal.roll(SANDBOX, 5 + k)
		ok = ok and g.pattern == CityLayout.Pattern.GRID and d.pattern == CityLayout.Pattern.DIAGONAL
		for f in CityVariety.FIELDS:
			ok = ok and g.get(f) == d.get(f)
	# Every pattern comes up (Story 26.7 added the radial one).
	return ok and seen.size() == CityLayout.Pattern.size() and SANDBOX.pattern == CityLayout.Pattern.GRID

func test_network_connected_and_clearings_touch_a_street() -> bool:
	var ok := true
	for s in _seeds():
		var l := diagonal(s)
		var p := CityPlan._generate(l)
		var strips: Array[PackedVector2Array] = []
		for path in p.paths:
			strips.append(CityPlan.strip(path))
		# Through the ground streets share, every street reaches every other.
		var seen := {0: true}
		var todo := [0]
		while not todo.is_empty():
			var i: int = todo.pop_back()
			for n in p.paths.size():
				if not seen.has(n) and _meets(strips[i], strips[n]):
					seen[n] = true
					todo.append(n)
		if seen.size() != p.paths.size():
			print("        seed %d: %d of %d streets reached" % [s, seen.size(), p.paths.size()])
			ok = false
		# Every junction joins streets that share ground (a grid street's end
		# moved into an avenue leaves none behind where it no longer meets), and
		# sits on each one's points.
		for j in p.junctions:
			for n in j.streets:
				var pts := p.paths[n].points
				var q := Geometry2D.get_closest_point_to_segment(j.at, pts[0], pts[-1])
				if not Array(pts).any(func(x): return x.distance_to(q) < 0.01):
					print("        seed %d: junction %s not on street %d's points" % [s, j.at, n])
					ok = false
				for m in j.streets:
					if n < m and not _meets(strips[n], strips[m]):
						print("        seed %d: junction %s joins streets %d and %d, which do not meet" % [s, j.at, n, m])
						ok = false
		# Every diagonal meets every street it shares ground with at a junction,
		# and its junction point is on both centrelines' points.
		for d in p.diagonals:
			for i in p.paths.size():
				if i == d or not _meets(strips[d], strips[i]):
					continue
				var met := p.junctions.filter(func(j): return j.streets.has(d) and j.streets.has(i))
				if met.is_empty():
					print("        seed %d: avenue %d and street %d share ground with no junction" % [s, d, i])
					ok = false
					continue
				var at: Vector2 = met[0].at
				for n in [d, i]:
					var pts := p.paths[n].points
					var q := Geometry2D.get_closest_point_to_segment(at, pts[0], pts[-1])
					if not Array(pts).any(func(x): return x.distance_to(q) < 0.01):
						print("        seed %d: junction %s not on street %d's points" % [s, at, n])
						ok = false
		for c in l.clearings:
			if not strips.any(func(st): return _reaches(c, st)):
				print("        seed %d: clearing %s touches no street" % [s, c])
				ok = false
	return ok

func test_lots_inside_blocks_pass_12_1_and_wedges_hold_no_thin_lot() -> bool:
	var terrain: DesertTerrain = DESERT.instantiate()
	var flat := terrain.flat_radius
	terrain.free()
	var ok := true
	var wedge_lots := 0
	var empty_wedges := 0
	for s in _seeds():
		var l := diagonal(s)
		var p := CityPlan._generate(l)
		ok = ok and p.blocks.size() == p.block_polygons.size() and p.lot_block.size() == p.lots.size() \
			and p.vacant_block.size() == p.vacant.size()
		if not Variety._passes_12_1(l, p, flat):
			print("        seed %d fails the 12.1 checks" % s)
			ok = false
		var strips: Array[PackedVector2Array] = []
		for path in p.paths:
			strips.append(CityPlan.strip(path))
		var all: Array[Rect2] = p.lots + p.vacant
		var of: PackedInt32Array = p.lot_block + p.vacant_block
		var used := {}
		for i in all.size():
			var lot := all[i]
			var pg := p.block_polygons[of[i]]
			used[of[i]] = true
			if not CityPlan.fits(lot, pg) or not p.blocks[of[i]].encloses(lot):
				print("        seed %d: lot %s outside its block" % [s, lot])
				ok = false
			# Clear of every street, the avenues too, and in a wedge a sidewalk
			# back from the kerb.
			var foot: PackedVector2Array = Geometry2D.offset_polygon(CityPlan.polygon(lot), l.sidewalk - 0.01,
				Geometry2D.JOIN_ROUND)[0]
			for k in strips.size():
				if _meets(CityPlan.polygon(lot), strips[k]) or (_wedge(pg) and _meets(foot, strips[k], 0.05)):
					print("        seed %d: lot %s on street %d" % [s, lot, k])
					ok = false
			if _wedge(pg):
				wedge_lots += 1
				if lot.size.x < l.lot_min - 0.001 or lot.size.y < l.lot_min - 0.001:
					print("        seed %d: wedge lot %s narrower than %s" % [s, lot, l.lot_min])
					ok = false
		for b in p.block_polygons.size():
			if _wedge(p.block_polygons[b]) and not used.has(b):
				empty_wedges += 1
		# Downtown heights still fall off from the centre.
		var inner := []
		var outer := []
		for i in p.lots.size():
			var d := p.lots[i].get_center().length() / l.core_radius
			if d < 0.4:
				inner.append(p.heights[i])
			elif d > 0.7:
				outer.append(p.heights[i])
		var mean := func(xs: Array) -> float:
			return xs.reduce(func(a, x): return a + x, 0.0) / maxf(1.0, xs.size())
		if not inner.is_empty() and not outer.is_empty() and mean.call(inner) <= mean.call(outer):
			print("        seed %d: downtown no taller than the edge" % s)
			ok = false
	print("        %d lots in wedges, %d wedges left paved" % [wedge_lots, empty_wedges])
	return ok and wedge_lots > 100 and empty_wedges > 0

func test_each_avenue_runs_at_its_angle_across_the_core() -> bool:
	var ok := true
	var counts := {}
	for s in _seeds():
		var l := diagonal(s)
		var p := CityPlan._generate(l)
		var r := l.core_radius
		var n := p.diagonals.size()
		counts[n] = true
		ok = ok and n >= l.diagonals.x and n <= l.diagonals.y and p.diagonal_angles.size() == n
		for k in n:
			var path := p.paths[p.diagonals[k]]
			var deg := p.diagonal_angles[k]
			var to_grid := minf(absf(deg), 90.0 - absf(deg))
			var dir := Vector2.from_angle(deg_to_rad(deg))
			ok = ok and absf(deg) >= l.diagonal_angle.x and absf(deg) <= l.diagonal_angle.y \
				and to_grid >= 20.0 - 0.001 and path.kind == CityPlan.Kind.AVENUE
			# Every leg runs at the angle, end to end from core edge to core edge.
			for i in path.points.size() - 1:
				var leg := (path.points[i + 1] - path.points[i]).normalized()
				if absf(leg.cross(dir)) > 1e-4 or leg.dot(dir) <= 0.0:
					print("        seed %d: avenue %d leg %d off its angle" % [s, k, i])
					ok = false
			var a := path.points[0]
			var e := path.points[-1]
			# It may run on a little past the edge, to cross a street there whole,
			# but no more than diagonal_run_on along itself.
			var most := r + l.diagonal_run_on + 0.01
			if a.length() < r - 0.01 or e.length() < r - 0.01 or absf(a.dot(dir)) > most or absf(e.dot(dir)) > most:
				print("        seed %d: avenue %d ends %s %s not at the core's edge" % [s, k, a, e])
				ok = false
			var near := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, a, e).length()
			ok = ok and near <= l.diagonal_offset + 0.001
			# No block is left under the avenue: each it crossed was split.
			var st := CityPlan.strip(path)
			for b in p.block_polygons:
				if _meets(b, st, 0.05):
					print("        seed %d: a block lies under avenue %d" % [s, k])
					ok = false
					break
		# Two avenues lean opposite ways, so they cross.
		if n == 2:
			ok = ok and signf(p.diagonal_angles[0]) != signf(p.diagonal_angles[1]) \
				and p.junctions.any(func(j): return j.streets.has(p.diagonals[0]) and j.streets.has(p.diagonals[1]))
	return ok and counts.has(1) and counts.has(2)

## No road leaves the flat ground: across 300 seeds every corner of every
## street's ground, avenues and the grid street ends moved into them alike,
## lies inside the radius out to which the terrain is exactly level (seeds 199
## and 201 ran their avenues on to 174 and 184 m before the run-on was capped).
func test_roads_stay_on_flat_ground() -> bool:
	var terrain: DesertTerrain = DESERT.instantiate()
	var flat := terrain.flat_radius + terrain.step() * 1.5
	terrain.free()
	var ok := SANDBOX.core_radius + SANDBOX.diagonal_run_on < flat
	for s in 300:
		var p := CityPlan._generate(diagonal(s))
		for i in p.paths.size():
			for q in CityPlan.strip(p.paths[i]):
				if q.length() > flat:
					print("        seed %d: street %d reaches %.1f m, past the flat %.1f m" % [s, i, q.length(), flat])
					ok = false
	return ok

func test_same_seed_same_city() -> bool:
	var text := func(p: CityPlan) -> String:
		var t := "%s %s %s %s %s %s %s" % [p.lots, p.heights, p.block_polygons, p.lot_block, p.vacant, p.diagonals,
			p.diagonal_angles]
		for path in p.paths:
			t += "%s %s %s" % [path.points, path.width, path.kind]
		for j in p.junctions:
			t += "%s %s" % [j.at, j.streets]
		for sh in p.shapes:
			t += "%s%s" % [sh.boxes, sh.trims]
		return t
	var a: String = text.call(CityPlan._generate(diagonal(4242)))
	var b: String = text.call(CityPlan._generate(diagonal(4242)))
	var c: String = text.call(CityPlan._generate(diagonal(4243)))
	var g := diagonal(4242)
	g.pattern = CityLayout.Pattern.GRID
	var grid := CityPlan._generate(g)
	return a == b and a != c and grid.diagonals.is_empty() and grid.paths.size() == grid.streets.size()

## A diagonal city's street level builds headless with no errors, its road
## pieces never overlap, and no road lies under a lot.
func test_diagonal_streets_build() -> bool:
	var ok := true
	for s in [2606, 6705, 10804, 39497]:
		var st: Streets = STREETS.instantiate()
		st.layout = diagonal(s)
		Sim.add(st)
		var pieces := Streets.road_pieces(st.plan)
		# Two edge streets clipped by the core may share a corner, as in a grid
		# (Story 26.5's Note); every other piece is on its own ground.
		var grid := st.plan.streets.size()
		var overlaps := 0
		for i in pieces.size():
			for j in range(i + 1, pieces.size()):
				var both_grid: bool = pieces[i].kind != 2 and pieces[j].kind != 2 and pieces[i].street < grid \
					and pieces[j].street < grid
				if not both_grid and Roads._shared(pieces[i].poly, pieces[j].poly) > 0.05:
					overlaps += 1
		var under := 0
		for pc in pieces:
			for lot in st.plan.lots:
				if Roads._shared(pc.poly, CityPlan.polygon(lot)) > 0.01:
					under += 1
		# Every street's ground inside the core is on a piece: sampled each metre,
		# with the pieces bucketed by 10 m cell.
		var cells := {}
		for pc in pieces:
			var b: Rect2 = pc.bounds()
			for cx in range(floori(b.position.x / 10.0), floori(b.end.x / 10.0) + 1):
				for cz in range(floori(b.position.y / 10.0), floori(b.end.y / 10.0) + 1):
					var key := Vector2i(cx, cz)
					if not cells.has(key):
						cells[key] = []
					cells[key].append(pc)
		var holes := 0
		for path in st.plan.paths:
			# A centimetre in from its kerbs and ends, so a sample on a kerb line
			# is not lost to float noise.
			var thin := CityPlan.Street.new()
			var along := (path.points[-1] - path.points[0]).normalized() * 0.01
			thin.points = PackedVector2Array([path.points[0] + along, path.points[-1] - along])
			thin.width = path.width - 0.02
			var ground := CityPlan.strip(thin)
			var box := Streets.bounds(ground)
			var x := box.position.x + 0.137
			while x < box.end.x:
				var z := box.position.y + 0.211
				while z < box.end.y:
					var q := Vector2(x, z)
					if q.length() < st.layout.core_radius and Geometry2D.is_point_in_polygon(q, ground) \
							and not cells.get(Vector2i(floori(x / 10.0), floori(z / 10.0)), []).any(func(pc): return pc.has_point(q)):
						holes += 1
						if holes <= 3:
							print("        seed %d: %s is on a street but no road" % [s, q])
					z += 1.0
				x += 1.0
		if overlaps > 0 or under > 0 or holes > 0 or st.lights.is_empty():
			print("        seed %d: %d road overlaps, %d under lots, %d holes, %d lights" % [s, overlaps, under, holes,
				st.lights.size()])
			ok = false
		st.free()
		Roads._done()
	return ok

## A wedge's tip can have an edge shorter than the kerb; standing it in by the
## kerb must still leave a simple convex pavement, never a folded one that the
## engine cannot split (seeds 6, 7 and 18 folded before this check).
func test_wedge_pavements_inset_convex() -> bool:
	var ok := true
	for s in [6, 7, 18, 20, 23] + _seeds():
		var plan := CityPlan.build(diagonal(s))
		for b in plan.block_polygons:
			var p := Streets.inset(b, 0.3)
			if p.size() >= 3 and not Streets.convex(p):
				print("  seed %d: folded pavement %s" % [s, p])
				ok = false
	return ok
