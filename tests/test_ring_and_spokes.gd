extends RefCounted
# Story 26.7: ring and spokes. A RADIAL city rings the spawn plaza with ring
# roads, each drawn as short straight segments, and runs spokes out from the
# plaza at seeded angles; blocks are the ring sectors between them, cut into
# rectangular lots. Across 30 seeds the network is connected, every lot sits
# inside its block and passes the 12.1 checks, ring segments join with no gaps
# or overlaps in the road mesh, lane markings follow the curve, and the plaza is
# where every spoke meets. Same seed, same city.

const Sim = preload("res://tests/sim.gd")
const Variety = preload("res://tests/test_city_variety.gd")
const Roads = preload("res://tests/test_roads_any_angle.gd")
const Diagonal = preload("res://tests/test_diagonal_avenues.gd")
const SANDBOX := preload("res://data/city/sandbox_city.tres")
const VARIETY := preload("res://data/city/free_flight_variety.tres")
const DESERT := preload("res://scenes/world/desert.tscn")
const STREETS := preload("res://scenes/world/streets.tscn")

static func _seeds() -> Array[int]:
	var out: Array[int] = []
	for k in 30:
		out.append(2607 + k * 4099)
	return out

## A rolled free-flight layout for seed `s`, set to the radial pattern.
static func radial(s: int) -> CityLayout:
	var l := VARIETY.roll(SANDBOX, s)
	l.pattern = CityLayout.Pattern.RADIAL
	return l

## Each ring's centreline corners, in order round it.
static func _corners(p: CityPlan, k: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for seg in p.rings[k]:
		out.append(p.paths[seg].points[0])
	return out

## The road ground of ring `k`: its outer kerb outline and its inner one,
## mitred at every corner, each `by` in from its kerb.
static func _ring_ground(p: CityPlan, k: int, by := 0.0) -> Array[PackedVector2Array]:
	var w := p.paths[p.rings[k][0]].width
	var c := _corners(p, k)
	return [CityPlan._offset(c, w * 0.5 - by), CityPlan._offset(c, -w * 0.5 + by)]

func test_network_connected_and_the_jammer_clearing_touches_a_street() -> bool:
	var ok := true
	var counts := {}
	for s in _seeds():
		var l := radial(s)
		var p := CityPlan._generate(l)
		counts[Vector2i(p.spokes.size(), p.rings.size())] = true
		ok = ok and p.streets.is_empty() and p.diagonals.is_empty() and p.rings.size() >= 2 \
			and p.spokes.size() == l.spokes
		var strips: Array[PackedVector2Array] = []
		for path in p.paths:
			strips.append(CityPlan.strip(path))
		# Through the ground streets share, every street reaches every other.
		var seen := {0: true}
		var todo := [0]
		while not todo.is_empty():
			var i: int = todo.pop_back()
			for n in p.paths.size():
				if not seen.has(n) and Diagonal._meets(strips[i], strips[n]):
					seen[n] = true
					todo.append(n)
		if seen.size() != p.paths.size():
			print("        seed %d: %d of %d streets reached" % [s, seen.size(), p.paths.size()])
			ok = false
		# Every junction joins streets that share ground and sits on each one's
		# points; every two streets that share ground meet at a junction.
		var met := {}
		for j in p.junctions:
			for n in j.streets:
				if not Array(p.paths[n].points).any(func(x): return x.distance_to(j.at) < 0.01):
					print("        seed %d: junction %s not on street %d's points" % [s, j.at, n])
					ok = false
				for m in j.streets:
					if n < m:
						met[Vector2i(n, m)] = true
						if not Diagonal._meets(strips[n], strips[m]):
							print("        seed %d: junction %s joins streets %d and %d, which do not meet" % [s, j.at, n, m])
							ok = false
		for n in p.paths.size():
			for m in range(n + 1, p.paths.size()):
				if Diagonal._meets(strips[n], strips[m], 0.05) and not met.has(Vector2i(n, m)):
					print("        seed %d: streets %d and %d share ground with no junction" % [s, n, m])
					ok = false
		# Each ring closes: every segment ends where the next starts.
		for ring in p.rings:
			for k in ring.size():
				var a := p.paths[ring[k]]
				var b := p.paths[ring[(k + 1) % ring.size()]]
				ok = ok and a.points[-1].distance_to(b.points[0]) < 1e-4
		# The jammer clearing (every clearing off the plaza) touches a street.
		for c in l.clearings:
			if Vector2(c.x, c.y).length() > 0.01 and not strips.any(func(st): return Diagonal._reaches(c, st)):
				print("        seed %d: clearing %s touches no street" % [s, c])
				ok = false
	print("        (spokes, rings) seen: %s" % [counts.keys()])
	return ok and counts.size() >= 3

func test_lots_inside_their_blocks_pass_12_1() -> bool:
	var terrain: DesertTerrain = DESERT.instantiate()
	var flat := terrain.flat_radius
	terrain.free()
	var ok := true
	var total := 0
	var fewest := 1 << 20
	for s in _seeds():
		var l := radial(s)
		var p := CityPlan._generate(l)
		ok = ok and p.blocks.size() == p.block_polygons.size() and p.lot_block.size() == p.lots.size() \
			and p.vacant_block.size() == p.vacant.size()
		if not Variety._passes_12_1(l, p, flat):
			print("        seed %d fails the 12.1 checks" % s)
			ok = false
		var strips: Array[PackedVector2Array] = []
		for path in p.paths:
			strips.append(CityPlan.strip(path))
		# Every block's outline is simple and keeps off every street.
		for b in p.block_polygons:
			if absf(CityPlan.area(b)) < 1.0 or CityPlan.area(b) < 0.0 \
					or Geometry2D.decompose_polygon_in_convex(b).is_empty():
				print("        seed %d: block %s is not a simple outline" % [s, Streets.bounds(b)])
				ok = false
			for st in strips:
				if Diagonal._meets(b, st, 0.05):
					print("        seed %d: block %s lies on a street" % [s, Streets.bounds(b)])
					ok = false
					break
		var all: Array[Rect2] = p.lots + p.vacant
		var of: PackedInt32Array = p.lot_block + p.vacant_block
		for i in all.size():
			var lot := all[i]
			var pg := p.block_polygons[of[i]]
			if not CityPlan.fits(lot, pg) or not p.blocks[of[i]].encloses(lot):
				print("        seed %d: lot %s outside its block" % [s, lot])
				ok = false
			if lot.size.x < l.lot_min - 0.001 or lot.size.y < l.lot_min - 0.001:
				print("        seed %d: lot %s narrower than %s" % [s, lot, l.lot_min])
				ok = false
			# Clear of every street by a sidewalk.
			var foot: PackedVector2Array = Geometry2D.offset_polygon(CityPlan.polygon(lot), l.sidewalk - 0.01,
				Geometry2D.JOIN_ROUND)[0]
			for k in strips.size():
				if Diagonal._meets(foot, strips[k], 0.05):
					print("        seed %d: lot %s on street %d" % [s, lot, k])
					ok = false
		total += p.lots.size()
		fewest = mini(fewest, p.lots.size())
	print("        %d lots over 30 radial seeds, fewest %d" % [total, fewest])
	return ok and fewest > 20

func test_the_plaza_is_where_every_spoke_meets() -> bool:
	var ok := true
	for s in _seeds():
		var l := radial(s)
		var p := CityPlan._generate(l)
		var plaza := p.block_polygons[0]
		# The plaza is the block inside the first ring, round the spawn clearing.
		ok = ok and Geometry2D.is_point_in_polygon(Vector2.ZERO, plaza) and p.lots.all(func(x): return not CityPlan.fits(x, plaza))
		var radii: Array[float] = []
		for k in p.rings.size():
			var c := _corners(p, k)
			var lo := INF
			var hi := 0.0
			for q in c:
				lo = minf(lo, q.length())
				hi = maxf(hi, q.length())
			radii.append(lo)
			# A ring is round: every corner the same distance from the plaza's centre.
			ok = ok and hi - lo < 1e-3 and (k == 0 or lo > radii[k - 1])
			ok = ok and CityPlan.area(c) > 0.0
		ok = ok and is_equal_approx(radii[0], l.hub_radius)
		var angles: Array[float] = []
		for sp in p.spokes:
			var path := p.paths[sp]
			var a := path.points[0]
			var e := path.points[-1]
			var dir := (e - a).normalized()
			angles.append(dir.angle())
			# Pointing straight out from the plaza's centre, from the plaza ring
			# to the core's edge.
			if absf(a.cross(dir)) > 1e-3 or a.dot(dir) <= 0.0 or absf(e.length() - l.core_radius) > 1e-3:
				print("        seed %d: spoke %d does not run out from the plaza" % [s, sp])
				ok = false
			# It meets every ring, the plaza's first, at a junction on its start
			# for the plaza ring, square across a segment centred on it.
			for k in p.rings.size():
				var at := p.junctions.filter(func(j): return j.streets.has(sp) and Array(p.rings[k]).any(func(seg): return j.streets.has(seg)))
				if at.size() != 1:
					print("        seed %d: spoke %d meets ring %d at %d junctions" % [s, sp, k, at.size()])
					ok = false
					continue
				var seg: CityPlan.Street = p.paths[Array(at[0].streets).filter(func(n): return n != sp)[0]]
				var along := (seg.points[-1] - seg.points[0]).normalized()
				ok = ok and absf(along.dot(dir)) < 1e-4 and at[0].at.distance_to((seg.points[0] + seg.points[-1]) * 0.5) < 1e-3
				if k == 0:
					ok = ok and at[0].at.distance_to(a) < 1e-4
		# Spokes stand at seeded angles, never closer than the jitter allows.
		angles.sort()
		for i in angles.size():
			var gap := angle_difference(angles[i], angles[(i + 1) % angles.size()])
			gap = gap if gap > 0.0 else gap + TAU
			ok = ok and gap > TAU / angles.size() * (1.0 - 2.0 * CityPlan.SPOKE_JITTER) - 1e-4
	return ok

## A clearing no street would touch turns the spokes together until one
## points at it; the gaps between them stay as seeded.
func test_a_clearing_off_every_street_turns_the_spokes_onto_it() -> bool:
	var l := radial(2607)
	l.rings = 3
	l.ring_spacing = 40.0
	var open: CityLayout = l.duplicate()
	open.clearings = PackedVector3Array([Vector3(0, 0, 32)])
	var p := CityPlan._generate(open)
	var a0 := (p.paths[p.spokes[0]].points[-1]).angle()
	var a1 := (p.paths[p.spokes[1]].points[-1]).angle()
	# Midway between the second and third rings, and between two spokes.
	var at := Vector2.from_angle(a0 + angle_difference(a0, a1) * 0.5) * (l.hub_radius + l.ring_spacing * 1.5)
	var c := Vector3(at.x, at.y, 5.0)
	l.clearings = PackedVector3Array([Vector3(0, 0, 32), c])
	var q := CityPlan._generate(l)
	var touched := func(plan: CityPlan) -> bool:
		return plan.paths.any(func(path): return Diagonal._reaches(c, CityPlan.strip(path)))
	var ok: bool = p.rings.size() == 3 and not touched.call(p) and touched.call(q) and q.spokes.size() == p.spokes.size()
	var aimed := false
	var turn := angle_difference((p.paths[p.spokes[0]].points[-1]).angle(), (q.paths[q.spokes[0]].points[-1]).angle())
	for k in q.spokes.size():
		var dir := q.paths[q.spokes[k]].points[-1].normalized()
		aimed = aimed or absf(dir.cross(at.normalized())) < 1e-4
		var was := (p.paths[p.spokes[k]].points[-1]).angle()
		ok = ok and absf(angle_difference(was + turn, dir.angle())) < 1e-4
	return ok and aimed

## Builds a radial city's street level for `s` headless.
static func _streets(s: int) -> Streets:
	var st: Streets = STREETS.instantiate()
	st.layout = radial(s)
	Sim.add(st)
	return st

## True when `q` lies inside the convex counterclockwise polygon `poly`.
static func _in_convex(q: Vector2, poly: PackedVector2Array) -> bool:
	for i in poly.size():
		if (poly[(i + 1) % poly.size()] - poly[i]).cross(q - poly[i]) < 0.0:
			return false
	return true

static func _near_outline(q: Vector2, poly: PackedVector2Array, by: float) -> bool:
	for i in poly.size():
		if Geometry2D.get_closest_point_to_segment(q, poly[i], poly[(i + 1) % poly.size()]).distance_to(q) < by:
			return true
	return false

func test_ring_segments_join_with_no_gaps_or_overlaps() -> bool:
	var ok := true
	for s in [2607, 23102, 43597, 64092]:
		var st := _streets(s)
		var p := st.plan
		var pieces := Streets.road_pieces(p)
		var overlaps := 0
		for i in pieces.size():
			for j in range(i + 1, pieces.size()):
				if Roads._shared(pieces[i].poly, pieces[j].poly) > 0.01:
					overlaps += 1
		# No road on a block: the road lies only on the streets' ground.
		var off := 0
		for pc in pieces:
			for b in p.block_polygons:
				if Roads._shared(pc.poly, b) > 0.01:
					off += 1
		var cells := {}
		for pc in pieces:
			var b: Rect2 = pc.bounds()
			for cx in range(floori(b.position.x / 5.0), floori(b.end.x / 5.0) + 1):
				for cz in range(floori(b.position.y / 5.0), floori(b.end.y / 5.0) + 1):
					var key := Vector2i(cx, cz)
					if not cells.has(key):
						cells[key] = []
					cells[key].append(pc)
		# On a piece, or within a millimetre of one's outline (a sample can land
		# on the line two pieces share, where float noise puts it in neither).
		var on_road := func(q: Vector2) -> bool:
			return cells.get(Vector2i(floori(q.x / 5.0), floori(q.y / 5.0)), []).any(func(pc): return pc.has_point(q) \
				or _near_outline(q, pc.poly, 0.001))
		# Every point of each ring's mitred ground is on the road: a metre
		# lattice over the ring, and a quarter-metre one round every corner.
		var holes := 0
		var checked := 0
		for k in p.rings.size():
			var ground := _ring_ground(p, k, 0.01)
			var w := p.paths[p.rings[k][0]].width
			var samples := PackedVector2Array()
			var box := Streets.bounds(ground[0])
			var x := box.position.x + 0.137
			while x < box.end.x:
				var z := box.position.y + 0.211
				while z < box.end.y:
					samples.append(Vector2(x, z))
					z += 1.0
				x += 1.0
			for q in _corners(p, k):
				for a in range(-ceili(w * 2.0) - 2, ceili(w * 2.0) + 3):
					for b in range(-ceili(w * 2.0) - 2, ceili(w * 2.0) + 3):
						samples.append(q + Vector2(a, b) * 0.25 + Vector2(0.013, 0.007))
			for q in samples:
				if not _in_convex(q, ground[0]) or _in_convex(q, ground[1]):
					continue
				checked += 1
				if not on_road.call(q):
					holes += 1
					if holes <= 3:
						print("        seed %d: %s is on ring %d but no road" % [s, q, k])
		# And every spoke's ground inside the core.
		for sp in p.spokes:
			var path := p.paths[sp]
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
					if Geometry2D.is_point_in_polygon(q, ground):
						checked += 1
						if not on_road.call(q):
							holes += 1
							if holes <= 3:
								print("        seed %d: %s is on spoke %d but no road" % [s, q, sp])
					z += 1.0
				x += 1.0
		var joints := pieces.filter(func(pc): return pc.joint).size()
		if overlaps > 0 or off > 0 or holes > 0 or st.lights.is_empty() or joints == 0:
			print("        seed %d: %d overlaps, %d on blocks, %d holes of %d, %d lights, %d joints" % [s, overlaps, off,
				holes, checked, st.lights.size(), joints])
			ok = false
		st.free()
		Roads._done()
	return ok

func test_lane_markings_follow_the_curve() -> bool:
	var ok := true
	var ring_tris := 0
	for s in [2607, 43597]:
		var st := _streets(s)
		var p := st.plan
		# Each ring turns steadily one way at every corner, a full turn in all.
		for ring in p.rings:
			var total := 0.0
			for k in ring.size():
				var a := p.paths[ring[k]]
				var b := p.paths[ring[(k + 1) % ring.size()]]
				var turn := angle_difference((a.points[-1] - a.points[0]).angle(), (b.points[-1] - b.points[0]).angle())
				ok = ok and turn > 0.0
				total += turn
			ok = ok and absf(total - TAU) < 1e-3 and ring.size() > p.spokes.size() * 2
		# Every triangle of road stretch is marked along the street it lies on,
		# and across it from that street's centreline: on a ring, along its own
		# segment.
		var arrays: Array = (st.get_node("Road") as MeshInstance3D).mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var on_ring := {}
		for ring in p.rings:
			for seg in ring:
				on_ring[seg] = true
		var strips: Array[PackedVector2Array] = []
		for path in p.paths:
			strips.append(CityPlan.strip(path))
		for t in range(0, verts.size(), 3):
			if uv2[t].y > 1.5:
				continue
			var tri := [Vector2(verts[t].x, verts[t].z), Vector2(verts[t + 1].x, verts[t + 1].z), Vector2(verts[t + 2].x, verts[t + 2].z)]
			var along := Roads._gradient(tri, [uv[t].y, uv[t + 1].y, uv[t + 2].y])
			var across := Roads._gradient(tri, [uv[t].x, uv[t + 1].x, uv[t + 2].x])
			var mid: Vector2 = (tri[0] + tri[1] + tri[2]) / 3.0
			var on := false
			for i in p.paths.size():
				if not Streets.bounds(strips[i]).has_point(mid) or not Geometry2D.is_point_in_polygon(mid, strips[i]):
					continue
				var path := p.paths[i]
				var d := (path.points[-1] - path.points[0]).normalized()
				var centre := Geometry2D.get_closest_point_to_segment(mid, path.points[0], path.points[-1])
				if absf(absf(along.dot(d)) - 1.0) < 1e-3 and absf(across.dot(d)) < 1e-3 \
						and is_equal_approx(uv2[t].x, path.width) \
						and absf(absf((uv[t].x + uv[t + 1].x + uv[t + 2].x) / 3.0) - mid.distance_to(centre)) < 1e-2:
					on = true
					if on_ring.has(i):
						ring_tris += 1
					break
			if not on:
				print("        seed %d: road at %s marked along %s" % [s, mid, along])
				ok = false
		st.free()
		Roads._done()
	print("        %d ring triangles marked along their segment" % ring_tris)
	return ok and ring_tris > 200

## The street level's clutter (a child of Streets) builds on a radial city:
## parked cars in the lanes, things on the pavements.
func test_clutter_builds_on_a_radial_city() -> bool:
	var ok := true
	for s in [2607, 64092]:
		var st := _streets(s)
		var c: StreetClutter = st.get_node("Clutter")
		ok = ok and c.plan == st.plan and c.get_child_count() > 0
		st.free()
		Roads._done()
	return ok

func test_same_seed_same_city() -> bool:
	var text := func(p: CityPlan) -> String:
		var t := "%s %s %s %s %s %s %s" % [p.lots, p.heights, p.block_polygons, p.lot_block, p.vacant, p.spokes, p.rings]
		for path in p.paths:
			t += "%s %s %s" % [path.points, path.width, path.kind]
		for j in p.junctions:
			t += "%s %s" % [j.at, j.streets]
		for sh in p.shapes:
			t += "%s%s" % [sh.boxes, sh.trims]
		return t
	var a: String = text.call(CityPlan._generate(radial(4242)))
	var b: String = text.call(CityPlan._generate(radial(4242)))
	var c: String = text.call(CityPlan._generate(radial(4243)))
	var g := radial(4242)
	g.pattern = CityLayout.Pattern.GRID
	var grid := CityPlan._generate(g)
	return a == b and a != c and grid.spokes.is_empty() and grid.rings.is_empty()

## Free flight picks the radial pattern for some seeds, and rolls its spoke
## and ring counts and spacing within CityVariety's ranges.
func test_variety_rolls_radial_cities() -> bool:
	var ok := VARIETY.pattern_weights.size() == CityLayout.Pattern.size() \
		and VARIETY.pattern_weights[CityLayout.Pattern.RADIAL] > 0.0
	var radial_seeds := 0
	var spokes := {}
	for k in 40:
		var l := VARIETY.roll(SANDBOX, 300 + k * 977)
		radial_seeds += int(l.pattern == CityLayout.Pattern.RADIAL)
		spokes[l.spokes] = true
		ok = ok and l.spokes >= VARIETY.spokes.x and l.spokes <= VARIETY.spokes.y and l.rings >= VARIETY.rings.x \
			and l.rings <= VARIETY.rings.y and l.ring_spacing >= VARIETY.ring_spacing.x and l.ring_spacing <= VARIETY.ring_spacing.y
	return ok and radial_seeds > 0 and spokes.size() > 1
