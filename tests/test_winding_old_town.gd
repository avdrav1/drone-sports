extends RefCounted
# Story 26.8: winding old town. An OLD_TOWN city grows narrow lanes from a loop
# round the spawn plaza by seeded random walks that bend, branch, and end where
# they meet another lane or the core's edge; a few wider streets run through,
# blocks are whatever the lanes enclose, and buildings stay lower. Across 30
# seeds the network is connected, no two lanes cross without a junction, every
# lane is at least the minimum width along its whole length, every lot sits
# inside its block and passes the 12.1 checks, and a sphere the drone's guard
# size swept down every lane hits nothing. Same seed, same city.

const Sim = preload("res://tests/sim.gd")
const Variety = preload("res://tests/test_city_variety.gd")
const Diagonal = preload("res://tests/test_diagonal_avenues.gd")
const SANDBOX := preload("res://data/city/sandbox_city.tres")
const VARIETY := preload("res://data/city/free_flight_variety.tres")
const DESERT := preload("res://scenes/world/desert.tscn")
const CITY := preload("res://scenes/world/city.tscn")
const STREETS := preload("res://scenes/world/streets.tscn")
const ROOFTOPS := preload("res://scenes/world/rooftops.tscn")
const CLUTTER := preload("res://scenes/world/street_clutter.tscn")
const DRONE := preload("res://scenes/drone/drone.tscn")

static func _seeds() -> Array[int]:
	var out: Array[int] = []
	for k in 30:
		out.append(2608 + k * 4111)
	return out

## A rolled free-flight layout for seed `s`, set to the old-town pattern.
static func town(s: int) -> CityLayout:
	var l := VARIETY.roll(SANDBOX, s)
	l.pattern = CityLayout.Pattern.OLD_TOWN
	return l

## The radius of a sphere round the drone's collision box plus the collision
## guard's margin: the drone's guard size.
static func _guard_size() -> float:
	var d: Drone = DRONE.instantiate()
	var box: BoxShape3D = (d.get_node("Shape") as CollisionShape3D).shape
	d.free()
	return (box.size * 0.5).length() + CollisionGuard.new().margin

func test_network_connected_and_lanes_cross_only_at_junctions() -> bool:
	var ok := true
	var built := 0
	for s in _seeds():
		var l := town(s)
		var p := CityPlan._generate(l)
		var good := p.streets.is_empty() and p.diagonals.is_empty() and p.spokes.is_empty() and p.rings.is_empty()
		var strips: Array[PackedVector2Array] = []
		for path in p.paths:
			strips.append(CityPlan.strip(path))
			# Inside the core, one straight leg a path.
			good = good and path.points.size() >= 2 and Array(path.points).all(func(q): return q.length() <= l.core_radius + 1e-3)
		# Every leg is on exactly one lane, its legs end to end; the plaza loop
		# closes round the spawn plaza.
		var on := {}
		for lane in p.lanes:
			for k in lane.size():
				good = good and not on.has(lane[k])
				on[lane[k]] = true
				if k > 0:
					good = good and p.paths[lane[k - 1]].points[-1].distance_to(p.paths[lane[k]].points[0]) < 1e-4
		good = good and on.size() == p.paths.size()
		var loop := p.lanes[0]
		var ring := PackedVector2Array()
		for seg in loop:
			ring.append(p.paths[seg].points[0])
		good = good and p.paths[loop[-1]].points[-1].distance_to(p.paths[loop[0]].points[0]) < 1e-4 \
			and Geometry2D.is_point_in_polygon(Vector2.ZERO, ring)
		# A few wider streets run through, from the loop to the core's edge;
		# every other lane is narrower than a street.
		var through := 0
		for lane in p.lanes.slice(1):
			var w := p.paths[lane[0]].width
			if is_equal_approx(w, l.street_width):
				through += 1
				good = good and p.paths[lane[-1]].points[-1].length() > l.core_radius - 0.01
			else:
				good = good and w < l.street_width
		if not good or through < 2 or through > l.through_streets or p.lanes.size() <= 10:
			print("        seed %d: lanes or legs out of order; %d through streets, %d lanes" % [s, through, p.lanes.size()])
			ok = false
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
		# Every junction joins streets that share ground and lies on each one's
		# points; every two streets that share ground or whose centrelines
		# touch meet at a junction there.
		var met := {}
		for j in p.junctions:
			for n in j.streets:
				if not Array(p.paths[n].points).any(func(x): return x.distance_to(j.at) < 0.01):
					print("        seed %d: junction %s not on street %d's points" % [s, j.at, n])
					ok = false
				for m in j.streets:
					if n < m:
						met[Vector2i(n, m)] = j.at
						if not Diagonal._meets(strips[n], strips[m]):
							print("        seed %d: junction %s joins streets %d and %d, which do not meet" % [s, j.at, n, m])
							ok = false
		for n in p.paths.size():
			var a := p.paths[n]
			for m in range(n + 1, p.paths.size()):
				var b := p.paths[m]
				if not Streets.bounds(strips[n]).intersects(Streets.bounds(strips[m])):
					continue
				var cross = Geometry2D.segment_intersects_segment(a.points[0], a.points[-1], b.points[0], b.points[-1])
				if cross != null and (not met.has(Vector2i(n, m)) or (met[Vector2i(n, m)] as Vector2).distance_to(cross) > 0.01):
					print("        seed %d: streets %d and %d cross at %s with no junction" % [s, n, m, cross])
					ok = false
				if Diagonal._meets(strips[n], strips[m], 0.05) and not met.has(Vector2i(n, m)):
					print("        seed %d: streets %d and %d share ground with no junction" % [s, n, m])
					ok = false
		# The jammer clearing (every clearing off the plaza) touches a street.
		for c in l.clearings:
			if Vector2(c.x, c.y).length() > 0.01 and not strips.any(func(st): return Diagonal._reaches(c, st)):
				print("        seed %d: clearing %s touches no street" % [s, c])
				ok = false
		built += 1
	return ok and built == 30

## Every lane is a width from the layout's range, never under its least, and
## the road the street level builds covers that least width along the whole
## of every lane, with no block over it. What a parked car leaves of the
## narrowest lane meets the epic's collision-guard rule with room to spare.
func test_every_lane_is_at_least_the_minimum_width_along_its_length() -> bool:
	var clutter: StreetClutter = CLUTTER.instantiate()
	var park := clutter.park_width
	clutter.free()
	var guard := _guard_size()
	var ok := SANDBOX.lane_width.x - park >= guard * 2.0 * 1.5 and SANDBOX.lane_width.y < VARIETY.street_width.x
	var checked := 0
	for s in _seeds():
		var l := town(s)
		var p := CityPlan._generate(l)
		for lane in p.lanes:
			for leg in lane:
				var w := p.paths[leg].width
				ok = ok and (is_equal_approx(w, l.street_width) or (w >= l.lane_width.x - 1e-4 and w <= l.lane_width.y + 1e-4))
		# Road pieces and blocks bucketed by 8 m cells.
		var pieces := Streets.road_pieces(p)
		var cells := {}
		var add := func(key: String, i: int, box: Rect2) -> void:
			for x in range(floori(box.position.x / 8.0), floori(box.end.x / 8.0) + 1):
				for z in range(floori(box.position.y / 8.0), floori(box.end.y / 8.0) + 1):
					var c := Vector2i(x, z)
					if not cells.has(c):
						cells[c] = {"road": [], "block": []}
					cells[c][key].append(i)
		for i in pieces.size():
			add.call("road", i, pieces[i].bounds())
		for i in p.block_polygons.size():
			add.call("block", i, Streets.bounds(p.block_polygons[i]))
		var bad := 0
		for path in p.paths:
			var a := path.points[0]
			var e := path.points[-1]
			var u := (e - a).normalized()
			var across := u.orthogonal()
			var length := a.distance_to(e)
			var half := l.lane_width.x * 0.5 - 0.05
			for k in ceili(length) + 1:
				for v in [-half, 0.0, half]:
					var q: Vector2 = a + u * clampf(k, 0.02, length - 0.02) + across * v + Vector2(0.0013, 0.0007)
					var cell: Dictionary = cells.get(Vector2i(floori(q.x / 8.0), floori(q.y / 8.0)), {"road": [], "block": []})
					checked += 1
					# On road: a piece holds it, or a point a centimetre off it (where
					# it falls exactly on the edge two pieces share).
					var road: bool = [q, q + Vector2(0.01, 0.007), q - Vector2(0.007, 0.01)].any(func(x):
						return cell.road.any(func(i): return pieces[i].has_point(x)))
					var block: bool = cell.block.any(func(i): return Geometry2D.is_point_in_polygon(q, p.block_polygons[i]))
					if not road or block:
						bad += 1
		if bad > 0:
			print("        seed %d: %d points of the lanes' least width off the road" % [s, bad])
			ok = false
	return ok and checked > 30 * 1000

func test_lots_inside_their_blocks_pass_12_1() -> bool:
	var terrain: DesertTerrain = DESERT.instantiate()
	var flat := terrain.flat_radius
	terrain.free()
	var ok := true
	var total := 0
	var fewest := 1 << 20
	var squeezed := 0
	for s in _seeds():
		var l := town(s)
		var p := CityPlan._generate(l)
		ok = ok and p.blocks.size() == p.block_polygons.size() and p.lot_block.size() == p.lots.size() \
			and p.vacant_block.size() == p.vacant.size()
		if not Variety._passes_12_1(l, p, flat):
			print("        seed %d fails the 12.1 checks" % s)
			ok = false
		# Buildings stay lower here.
		for h in p.heights:
			ok = ok and h <= l.old_town_height.y + 1e-3 and h >= l.height_min - 1e-3
		var strips: Array[PackedVector2Array] = []
		for path in p.paths:
			strips.append(CityPlan.strip(path))
		# Every block's outline is simple, wound counterclockwise, and keeps
		# off every street; no two blocks overlap.
		for i in p.block_polygons.size():
			var b := p.block_polygons[i]
			if CityPlan.area(b) < 1.0 or Geometry2D.decompose_polygon_in_convex(b).is_empty():
				print("        seed %d: block %s is not a simple outline" % [s, Streets.bounds(b)])
				ok = false
			if not Streets.convex(b):
				squeezed += 1
			for st in strips:
				if Diagonal._meets(b, st, 0.05):
					print("        seed %d: block %s lies on a street" % [s, Streets.bounds(b)])
					ok = false
					break
			for j in range(i + 1, p.block_polygons.size()):
				if Diagonal._meets(b, p.block_polygons[j], 0.05):
					print("        seed %d: blocks %d and %d overlap" % [s, i, j])
					ok = false
		var all: Array[Rect2] = p.lots + p.vacant
		var of: PackedInt32Array = p.lot_block + p.vacant_block
		for i in all.size():
			var lot := all[i]
			if not CityPlan.fits(lot, p.block_polygons[of[i]]) or not p.blocks[of[i]].encloses(lot):
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
	print("        %d lots over 30 old-town seeds, fewest %d; %d odd-shaped blocks" % [total, fewest, squeezed])
	return ok and fewest > 20 and squeezed > 30

## The city is built (buildings, street level with its clutter, roof clutter)
## and a sphere the drone's guard size is swept down the centreline of every
## lane end to end, leg after leg, through every bend's mitred joint and every
## T, at heights from just over a parked car to over the roofs, without a hit.
## Only a dead end is swept a radius short (past its kerb is not lane). Every
## leg of every lane is swept. A sphere swept through a building does hit, so
## the casts see the city.
func test_a_guard_sized_sphere_swept_down_every_lane_hits_nothing() -> bool:
	var radius := _guard_size()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var ok := true
	var swept := 0
	for s in _seeds():
		var l := town(s)
		var city: City = CITY.instantiate()
		city.layout = l
		var streets: Streets = STREETS.instantiate()
		streets.layout = l
		var roofs: Rooftops = ROOFTOPS.instantiate()
		roofs.layout = l
		for n in [city, streets, roofs]:
			Sim.add(n)
		await Sim.physics_frames(2)
		var space := city.get_world_3d().direct_space_state
		var cast := func(from: Vector3, to: Vector3) -> bool:
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = sphere
			q.transform = Transform3D(Basis(), from)
			q.motion = to - from
			return space.intersect_shape(q, 1).is_empty() and space.cast_motion(q)[0] >= 1.0
		var hits := 0
		var plan := city.plan
		var r := l.core_radius
		var legs := {}
		for lane in plan.lanes:
			for k in lane.size():
				var leg := lane[k]
				var from := plan.paths[leg].points[0]
				var to := plan.paths[leg].points[-1]
				# A lane's last leg ends in a T, a joint, or at the core's edge, where
				# the road runs on or the open ground beyond the blocks starts;
				# otherwise it is a dead end, swept to a radius short of its kerb.
				if k == lane.size() - 1 and to.length() < r - 0.01 and not plan.junctions.any(func(j):
						return j.at.distance_to(to) < 0.01 and leg in j.streets):
					to -= (to - from).normalized() * radius
				legs[leg] = true
				for y in [radius + 1.6, 4.0, 12.0, 40.0]:
					if not cast.call(Vector3(from.x, y, from.y), Vector3(to.x, y, to.y)):
						hits += 1
						if hits <= 3:
							print("        seed %d: a sphere down leg %d, %s to %s, hits at %.1f m" % [s, leg, from, to, y])
		var tallest := 0
		for i in city.plan.lots.size():
			if city.plan.heights[i] > city.plan.heights[tallest]:
				tallest = i
		var c := city.plan.lots[tallest].get_center()
		var through: bool = cast.call(Vector3(c.x - 60.0, 2.0, c.y), Vector3(c.x + 60.0, 2.0, c.y))
		if hits > 0 or through or legs.size() != plan.paths.size():
			print("        seed %d: %d hits, %d of %d legs swept, through a building: %s" % [s, hits, legs.size(),
				plan.paths.size(), through])
			ok = false
		swept += 1
		for n in [city, streets, roofs]:
			n.free()
		City.prune(SANDBOX)
		Streets.prune(SANDBOX)
		StreetClutter.prune(SANDBOX)
		Rooftops.prune(SANDBOX)
		CityPlan.prune(SANDBOX)
	return ok and swept == 30

func test_same_seed_same_city() -> bool:
	var a := CityPlan._generate(town(2608))
	var b := CityPlan._generate(town(2608))
	var c := CityPlan._generate(town(6719))
	var same := func(x: CityPlan, y: CityPlan) -> bool:
		if x.paths.size() != y.paths.size() or x.lots != y.lots or x.heights != y.heights or x.vacant != y.vacant \
				or x.block_polygons != y.block_polygons or x.junctions.size() != y.junctions.size() or x.lanes != y.lanes:
			return false
		for i in x.paths.size():
			if x.paths[i].points != y.paths[i].points or x.paths[i].width != y.paths[i].width:
				return false
		return true
	# Free flight rolls the old town for some seeds, and builds it lower.
	var only: CityVariety = VARIETY.duplicate()
	only.pattern_weights = PackedFloat32Array([0.0, 0.0, 0.0, 1.0])
	var rolled := only.roll(SANDBOX, 2608)
	return same.call(a, b) and not same.call(a, c) and rolled.pattern == CityLayout.Pattern.OLD_TOWN \
		and rolled.params() == town(2608).params() and SANDBOX.old_town_height.y < VARIETY.height_max.x
