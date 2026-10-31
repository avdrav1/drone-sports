extends RefCounted
# Story 26.5: roads at any angle. Streets and StreetClutter read the plan's
# general form (paths, junctions, block polygons), so a grid builds what it did
# from rectangles, and a hand-made plan with a street at 30° (a fixture, not a
# pattern) gets road over every street and none under a lot, lights and
# clutter on the pavements outside lanes and clearings, and lane markings along
# each street.

const Sim = preload("res://tests/sim.gd")
const STREETS := preload("res://scenes/world/streets.tscn")
const SANDBOX := preload("res://data/city/sandbox_city.tres")
const VARIETY := preload("res://data/city/free_flight_variety.tres")
const K := StreetClutter.Kind

const FIXTURE_SEED := 30030
const ANGLE := 30.0
## md5s of each part of the street level (parts(), numbers to the centimetre),
## taken from the rectangle builders on the parent commit: the sandbox (seed 7,
## which every job scene shows) and three rolled free-flight cities with drops.
const BEFORE := {
	"sandbox": {
		"road": "8bc45b08d41fcabdabea9fc4b9b1b45e",
		"walk": "fca2049dfff5cb5f4a947db5dd414491",
		"lights": "3dbf7188956e3629fb5369de0934576b",
		"kerbs": "11f74fb42af6f6b768577171de944c8e",
		"street_shapes": "59cdd7a369f335521b33b79d9b388989",
		"crosswalks": "295d533b2a9891948222751294733633",
		"decals": "9e6160a7e36c40fe019cf975c3728844",
		"pieces": "9788cf5c8642ba124d1796d7ab25b475",
		"lanes": "30b9b30748000ce1ce8b9759095e4fc7",
		"parking": "22a5a46da5d855c465829280ea73308e",
		"clutter_shapes": "bff045ff8308eb92e12416b64f1a20aa",
		"clutter_mm": "062f9e7b019b2eb216526becc3eb143b",
	},
	"roll41": {
		"road": "b8b27c16cd057e837934a49fb1376565",
		"walk": "c3f9c397ec2b90597390f33504d98ac7",
		"lights": "c1d58dd95e7f324d4f4864641201b2aa",
		"kerbs": "d2be52b4f2f414299c3c5e84701f8d51",
		"street_shapes": "f9b3047a59fc32f48375ced5f8ff08a8",
		"crosswalks": "c6194d7841e52bc106c8c8a5ecd3936f",
		"decals": "7435c084e67e556735a1a6b1d8b19335",
		"pieces": "1b31321ff233adb6b72b93ab7772ffb1",
		"lanes": "8a1c67c161aeb9193f3a8686d016a39c",
		"parking": "70a117a1e2e9e5080c7bd772bc61abc3",
		"clutter_shapes": "02d182a68fcd9e62ec17ad650579a4ca",
		"clutter_mm": "bb6e1304fb9ade78ceb4320b9de33c06",
	},
	"roll1234": {
		"road": "f24ce7ce20a5ad4ec097694d37747d4d",
		"walk": "a120c7503e21da7b46a78487e8016abd",
		"lights": "d3650b0d915c3d32d3abacc8a0fb5f42",
		"kerbs": "b4bb58f4103569a2f9e0162cdbd671db",
		"street_shapes": "4f9c1e49aa3334db40c441c097caaefd",
		"crosswalks": "6f6b5b7bf701ef8d8ca1a66817c6ddd1",
		"decals": "05de6b65a352c1201b126ee873d175d6",
		"pieces": "92cf7be4a17e2fd56a0b5c24e0233af6",
		"lanes": "0853349b6113e38b33e9bc37ece9c2d6",
		"parking": "2edddf1e601a1b206309e926e9f3072b",
		"clutter_shapes": "52d9162605b91ecab5693ecfc7d09698",
		"clutter_mm": "65faff32a59bb789e37ab968eb136f37",
	},
	"roll98765": {
		"road": "e659fccc80114e1d4da2041310ea77cf",
		"walk": "4372f5e3757f78345ebd708953eef5d6",
		"lights": "27b637d7e00ff7ffe414091a34c4a20f",
		"kerbs": "7e3cf2885a88215400381cd9d310ce44",
		"street_shapes": "507e68e6dc335d64e02688235b4f41ef",
		"crosswalks": "d67a1257a205b217e3f610804a9610f5",
		"decals": "2cca3afbb7d572dc0ad65a78276699d2",
		"pieces": "8180461e5e424519ccf40840b5d3fb6b",
		"lanes": "acc45003cbe0a7377890b9e0e567cad5",
		"parking": "714511d7391815ec3357a52081973b71",
		"clutter_shapes": "274957bda2933d8356ed3ea8df772e3a",
		"clutter_mm": "c68cd3938ba18527449523eed4b8d7cd",
	},
}

## The street level as text, part by part: meshes, MultiMesh transforms,
## collision, and the footprints, crosswalks, decals, lanes and parking (as
## their bounds, which for a grid are the rects they used to be).
static func parts(s: Streets) -> Dictionary:
	var c: StreetClutter = s.get_node("Clutter")
	var road: Array = (s.get_node("Road") as MeshInstance3D).mesh.surface_get_arrays(0)
	var walk: Array = (s.get_node("Sidewalks") as MeshInstance3D).mesh.surface_get_arrays(0)
	var d := {}
	d.road = "%s\n%s\n%s\n%s\n%s\n%s\n%s" % [road[Mesh.ARRAY_VERTEX], road[Mesh.ARRAY_TEX_UV], road[Mesh.ARRAY_TEX_UV2],
		road[Mesh.ARRAY_CUSTOM0], road[Mesh.ARRAY_CUSTOM1], road[Mesh.ARRAY_CUSTOM2], road[Mesh.ARRAY_CUSTOM3]]
	d.walk = "%s\n%s\n%s" % [walk[Mesh.ARRAY_VERTEX], walk[Mesh.ARRAY_TEX_UV], walk[Mesh.ARRAY_TEX_UV2]]
	d.lights = "%s\n%s\n%s" % [s.lights, _mm(s.get_node("Poles")), _mm(s.get_node("Heads"))]
	d.kerbs = _mm(s.get_node("Kerbs"))
	d.street_shapes = _shapes(s)
	d.crosswalks = "\n".join(s.crosswalks.map(func(x): return str(Streets.bounds(x))))
	d.decals = "\n".join(s.decals.map(func(x): return "%s %s %s" % [x[0], Streets.bounds(x[1]), x[2]]))
	d.pieces = "\n".join(c.pieces.map(func(f): return "%s %s %s %s %s" % [f.kind, f.xform, f.box, f.lot, f.tint]))
	d.lanes = "\n".join(c.lanes.map(func(x): return str(Streets.bounds(x))))
	d.parking = "\n".join(c.parking.map(func(x): return str(Streets.bounds(x))))
	d.clutter_shapes = _shapes(c)
	var mms := []
	for n in c.get_children():
		if n is MultiMeshInstance3D:
			mms.append("%s\n%s" % [n.name, _mm(n)])
	d.clutter_mm = "\n".join(mms)
	return d

static func _mm(n: MultiMeshInstance3D) -> String:
	var out := []
	for i in n.multimesh.instance_count:
		out.append(str(n.multimesh.get_instance_transform(i)))
		if n.multimesh.use_colors:
			out.append(str(n.multimesh.get_instance_color(i)))
	return "\n".join(out)

static func _shapes(n: Node) -> String:
	var out := []
	for c in n.get_children():
		if c is CollisionShape3D:
			var s: Shape3D = c.shape
			var size = s.size if s is BoxShape3D else ("%s %s" % [s.radius, s.height] if s is CylinderShape3D else s.get_class())
			out.append("%s %s %s %s" % [c.name, s.get_class(), size, c.transform])
	return "\n".join(out)

## `text` with every number rounded to the centimetre (float noise from
## building a rect as a quad stays well under that).
static func rounded(text: String) -> String:
	var re := RegEx.create_from_string("-?\\d+(\\.\\d+)?(e-?\\d+)?")
	var out := PackedStringArray()
	var at := 0
	for m in re.search_all(text):
		out.append(text.substr(at, m.get_start() - at))
		out.append("%.2f" % (snappedf(m.get_string().to_float(), 0.01) + 0.0))
		at = m.get_end()
	out.append(text.substr(at))
	return "".join(out)

static func _layouts() -> Dictionary:
	var out := {"sandbox": SANDBOX}
	for seed in [41, 1234, 98765]:
		out["roll%d" % seed] = VARIETY.roll(SANDBOX, seed)
	return out

static func _done() -> void:
	Streets.prune(SANDBOX)
	StreetClutter.prune(SANDBOX)
	CityPlan.prune(SANDBOX)

func test_grid_streets_and_clutter_unchanged() -> bool:
	var ok := true
	var layouts := _layouts()
	for k in layouts:
		var s: Streets = STREETS.instantiate()
		s.layout = layouts[k]
		Sim.add(s)
		var d := parts(s)
		for part in d:
			var md5 := rounded(d[part]).md5_text()
			if BEFORE.get(k, {}).get(part, "") != md5:
				print("        %s %s: %s" % [k, part, md5])
				ok = false
		s.free()
		_done()
	return ok

## Story 26.4's grid code never reads the rects back, so the fixture leaves
## them empty: only the general form is there to build from.
static func _strip(from: Vector2, to: Vector2, width: float) -> PackedVector2Array:
	var d := (to - from).normalized()
	var n := Vector2(-d.y, d.x) * width * 0.5
	return PackedVector2Array([from - n, to - n, to + n, from + n])

## A layout whose plan (put in CityPlan's cache under its params) is made by
## hand: two streets along z, two along x, and an avenue at ANGLE through the
## middle, each running out to the edge of a 160 × 190 m district, with blocks
## cut between them, lots fitted inside, and one lot left vacant in a wedge.
static func fixture() -> CityLayout:
	var l: CityLayout = SANDBOX.duplicate()
	l.seed = FIXTURE_SEED
	var p := CityPlan.new()
	var dir := Vector2.from_angle(deg_to_rad(ANGLE))
	var lines := [
		[Vector2(-50, -95), Vector2(-50, 95), 8.0, CityPlan.Kind.STREET],
		[Vector2(50, -95), Vector2(50, 95), 8.0, CityPlan.Kind.STREET],
		[Vector2(-80, -60), Vector2(80, -60), 8.0, CityPlan.Kind.STREET],
		[Vector2(-80, 60), Vector2(80, 60), 8.0, CityPlan.Kind.STREET],
		[dir * (-80.0 / dir.x), dir * (80.0 / dir.x), 12.0, CityPlan.Kind.AVENUE],
	]
	var strips: Array[PackedVector2Array] = []
	for line in lines:
		var path := CityPlan.Street.new()
		path.points = PackedVector2Array([line[0], line[1]])
		path.width = line[2]
		path.kind = line[3]
		p.paths.append(path)
		strips.append(_strip(line[0], line[1], line[2]))
	for i in strips.size():
		for j in range(i + 1, strips.size()):
			var shared := Geometry2D.intersect_polygons(strips[i], strips[j])
			if shared.is_empty():
				continue
			var junction := CityPlan.Junction.new()
			junction.at = Streets.bounds(shared[0]).get_center()
			junction.streets = PackedInt32Array([i, j])
			p.junctions.append(junction)
			for n in [i, j]:
				var path := p.paths[n]
				var q := Geometry2D.get_closest_point_to_segment(junction.at, path.points[0], path.points[-1])
				var k := 1
				while k < path.points.size() - 1 and path.points[k].distance_to(path.points[0]) < q.distance_to(path.points[0]):
					k += 1
				path.points.insert(k, q)
	var blocks: Array[PackedVector2Array] = [CityPlan.polygon(Rect2(-80, -95, 160, 190))]
	for strip in strips:
		var next: Array[PackedVector2Array] = []
		for b in blocks:
			for part in Geometry2D.clip_polygons(b, strip):
				if absf(CityPlan.area(part)) > 1.0:
					if CityPlan.area(part) < 0.0:
						part.reverse()
					next.append(part)
		blocks = next
	p.block_polygons = blocks
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXTURE_SEED
	var vacant := false
	for b in blocks.size():
		var inner := Streets.inset(blocks[b], l.sidewalk)
		var box := Streets.bounds(inner)
		var x := box.position.x
		while x + 12.0 <= box.end.x:
			var z := box.position.y
			while z + 12.0 <= box.end.y:
				var lot := Rect2(x, z, 12.0, 12.0)
				if CityPlan.fits(lot, inner) and CityPlan.clear_of(l, lot) and CityPlan.inside(lot, l.core_radius):
					if not vacant and not Streets.square(blocks[b]):
						vacant = true
						p.vacant.append(lot)
						p.vacant_block.append(b)
					else:
						p.lots.append(lot)
						p.lot_block.append(b)
						p.heights.append(12.0 + 3.5 * (p.lots.size() % 5))
				z += 13.0
			x += 13.0
	for i in p.lots.size():
		p.shapes.append(CityPlan._shape(l, rng, p.lots[i], p.heights[i]))
	CityPlan._cache[l.params()] = p
	return l

static func _fixture_streets() -> Streets:
	var s: Streets = STREETS.instantiate()
	s.layout = fixture()
	return Sim.add(s)

## The ground two polygons share, in m².
static func _shared(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if not Streets.bounds(a).grow(0.01).intersects(Streets.bounds(b)):
		return 0.0
	var out := 0.0
	for part in Geometry2D.intersect_polygons(a, b):
		out += absf(CityPlan.area(part))
	return out

## A clutter piece's footprint: its mesh's box turned with it.
static func _foot(c: StreetClutter, f: Dictionary) -> PackedVector2Array:
	return c._corners(f)

func test_fixture_has_a_street_at_the_angle() -> bool:
	var s := _fixture_streets()
	var pieces := Streets.road_pieces(s.plan)
	var slanted := pieces.filter(func(pc): return pc.kind != 2 and absf(pc.d.angle_to(Vector2.from_angle(deg_to_rad(ANGLE)))) < 1e-4)
	var patches := pieces.filter(func(pc): return pc.kind == 2)
	var ok := s.plan.streets.is_empty() and s.plan.blocks.is_empty() and slanted.size() == 3 and patches.size() == 6 \
		and not s.plan.lots.is_empty() and s.plan.vacant.size() == 1
	if not ok:
		print("        %d slanted stretches, %d patches" % [slanted.size(), patches.size()])
	s.free()
	_done()
	return ok

func test_fixture_road_covers_every_street_once_and_no_lot() -> bool:
	var s := _fixture_streets()
	var p := s.plan
	var pieces := Streets.road_pieces(p)
	var ok := true
	# No two pieces share ground.
	for i in pieces.size():
		for j in range(i + 1, pieces.size()):
			var both := _shared(pieces[i].poly, pieces[j].poly)
			if both > 0.01:
				print("        pieces %d and %d overlap by %.3f m²" % [i, j, both])
				ok = false
	# Every street's ground (its centreline swept half its width either side,
	# cut square at its ends) is on a piece: sampled on a 1 m grid.
	for path in p.paths:
		var a := path.points[0]
		var e := path.points[-1]
		var d := (e - a).normalized()
		var n := Vector2(-d.y, d.x)
		var u := 0.37
		while u < a.distance_to(e):
			var v := -path.width * 0.5 + 0.21
			while v < path.width * 0.5:
				var q := a + d * u + n * v
				if not pieces.any(func(pc): return Geometry2D.is_point_in_polygon(q, pc.poly)):
					print("        %s is on a street but no road" % q)
					ok = false
				v += 1.0
			u += 1.0
	# The road mesh is the pieces: the same area, every triangle on one.
	var verts: PackedVector3Array = (s.get_node("Road") as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mesh_area := 0.0
	for t in range(0, verts.size(), 3):
		var tri := PackedVector2Array([Vector2(verts[t].x, verts[t].z), Vector2(verts[t + 1].x, verts[t + 1].z),
			Vector2(verts[t + 2].x, verts[t + 2].z)])
		mesh_area += CityPlan.area(tri)
		var mid := (tri[0] + tri[1] + tri[2]) / 3.0
		ok = ok and pieces.any(func(pc): return Geometry2D.is_point_in_polygon(mid, pc.poly))
	var piece_area := 0.0
	for pc in pieces:
		piece_area += absf(CityPlan.area(pc.poly))
	if absf(mesh_area - piece_area) > 0.5:
		print("        road mesh %.2f m², pieces %.2f m² (a negative mesh area faces down)" % [mesh_area, piece_area])
		ok = false
	# No road under a lot, or a vacant one.
	for lot in p.lots + p.vacant:
		for pc in pieces:
			if _shared(pc.poly, CityPlan.polygon(lot)) > 0.001:
				print("        road under lot %s" % lot)
				ok = false
	s.free()
	_done()
	return ok

## The gradient over a triangle of a value given at its corners.
static func _gradient(tri: Array, values: Array) -> Vector2:
	var e1: Vector2 = tri[1] - tri[0]
	var e2: Vector2 = tri[2] - tri[0]
	var d1: float = values[1] - values[0]
	var d2: float = values[2] - values[0]
	var det := e1.cross(e2)
	return Vector2(d1 * e2.y - d2 * e1.y, e1.x * d2 - e2.x * d1) / det

func test_fixture_lane_markings_run_along_their_street() -> bool:
	var s := _fixture_streets()
	var p := s.plan
	var arrays: Array = (s.get_node("Road") as MeshInstance3D).mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var strips := p.paths.map(func(path): return _strip(path.points[0], path.points[-1], path.width))
	var ok := true
	var slanted := 0
	for t in range(0, verts.size(), 3):
		if uv2[t].y > 1.5:
			continue
		var tri := [Vector2(verts[t].x, verts[t].z), Vector2(verts[t + 1].x, verts[t + 1].z), Vector2(verts[t + 2].x, verts[t + 2].z)]
		var along := _gradient(tri, [uv[t].y, uv[t + 1].y, uv[t + 2].y])
		var across := _gradient(tri, [uv[t].x, uv[t + 1].x, uv[t + 2].x])
		var mid: Vector2 = (tri[0] + tri[1] + tri[2]) / 3.0
		# The street the triangle lies on: its markings run along that
		# street's centreline, and across it from the centreline out.
		var on := false
		for i in p.paths.size():
			if not Geometry2D.is_point_in_polygon(mid, strips[i]):
				continue
			var path: CityPlan.Street = p.paths[i]
			var d := (path.points[-1] - path.points[0]).normalized()
			var centre := Geometry2D.get_closest_point_to_segment(mid, path.points[0], path.points[-1])
			if absf(absf(along.dot(d)) - 1.0) < 1e-3 and absf(along.length() - 1.0) < 1e-3 \
					and absf(across.dot(d)) < 1e-3 and absf(across.length() - 1.0) < 1e-3 \
					and is_equal_approx(uv2[t].x, path.width) \
					and absf(absf((uv[t].x + uv[t + 1].x + uv[t + 2].x) / 3.0) - mid.distance_to(centre)) < 1e-2:
				on = true
				if i == 4:
					slanted += 1
		if not on:
			print("        road at %s marked along %s" % [mid, along])
			ok = false
	s.free()
	_done()
	return ok and slanted > 10

func test_fixture_lights_and_clutter_stand_on_pavements() -> bool:
	var s := _fixture_streets()
	var c: StreetClutter = s.get_node("Clutter")
	var p := s.plan
	var l := s.layout
	var lots := (p.lots + p.vacant).map(func(lot): return CityPlan.polygon(lot))
	var pieces := Streets.road_pieces(p)
	var ok := s.lights.size() > 20 and c.pieces.size() > 50
	for at in s.lights:
		var q := Vector2(at.x, at.z)
		var block := p.block_polygons.filter(func(b): return Geometry2D.is_point_in_polygon(q, b))
		var on_walk := block.size() == 1 and not Geometry2D.is_point_in_polygon(q, Streets.inset(block[0], l.sidewalk))
		on_walk = on_walk and not lots.any(func(lot): return Geometry2D.is_point_in_polygon(q, lot))
		on_walk = on_walk and CityPlan.clear_of(l, Rect2(q, Vector2.ZERO))
		on_walk = on_walk and not pieces.any(func(pc): return Geometry2D.is_point_in_polygon(q, pc.poly))
		if not on_walk:
			print("        light at %s off the pavement" % q)
			ok = false
	var slanted := {}
	for f in c.pieces:
		var foot := _foot(c, f)
		var flat := Rect2(f.box.position.x, f.box.position.z, f.box.size.x, f.box.size.z)
		var good := CityPlan.clear_of(l, flat) and not c.lanes.any(func(lane): return _shared(lane, foot) > 0.001)
		if f.kind in [K.BENCH, K.SHELTER, K.SIGN, K.TREE, K.PIT]:
			# On a pavement: inside a block's kerb line, off every lot.
			good = good and p.block_polygons.any(func(b): return _shared(Streets.inset(b, s.kerb_width), foot) >= absf(CityPlan.area(foot)) - 0.001)
			good = good and not lots.any(func(lot): return _shared(lot, foot) > 0.001)
			good = good and absf(f.xform.origin.y - s.kerb_height) < 0.01
		elif f.kind == K.CAR:
			good = good and c.parking.any(func(strip): return _shared(strip, foot) >= absf(CityPlan.area(foot)) - 0.001)
		if not good:
			print("        %s at %s off its place" % [K.keys()[f.kind], f.xform.origin])
			ok = false
		var fwd: Vector3 = f.xform.basis.z.normalized()
		for axis in [Vector2.from_angle(deg_to_rad(ANGLE)), Vector2.from_angle(deg_to_rad(ANGLE + 90.0))]:
			if absf(absf(Vector2(fwd.x, fwd.z).dot(axis)) - 1.0) < 1e-3:
				slanted[f.kind] = slanted.get(f.kind, 0) + 1
	# The slanted avenue has parked cars, and its pavements things on them.
	for kind in [K.CAR, K.TREE]:
		if slanted.get(kind, 0) < 2:
			print("        only %d %s turned to the avenue" % [slanted.get(kind, 0), K.keys()[kind]])
			ok = false
	# Kerbs stand inside their blocks and off the road.
	for xf in s.kerbs:
		var foot := PackedVector2Array()
		for corner in [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]:
			var w: Vector3 = xf * corner
			foot.append(Vector2(w.x, w.z))
		if pieces.any(func(pc): return _shared(pc.poly, foot) > 0.01) \
				or not p.block_polygons.any(func(b): return _shared(b, foot) >= absf(CityPlan.area(foot)) - 0.01):
			print("        kerb at %s off its block" % xf.origin)
			ok = false
	s.free()
	_done()
	return ok

func test_fixture_loads_and_collides() -> bool:
	var s := _fixture_streets()
	await Sim.physics_frames(2)
	var space := s.get_world_3d().direct_space_state
	var hit := func(at: Vector2) -> bool:
		var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 2.0, at.y), Vector3(at.x, -0.5, at.y))
		var r := space.intersect_ray(q)
		return not r.is_empty() and r.collider == s
	var ok := true
	# A pavement in a wedge block is solid; the avenue between is not.
	var wedges := s.plan.block_polygons.filter(func(b): return not Streets.square(b))
	ok = ok and wedges.size() >= 4
	for b in wedges:
		var inner := Streets.inset(b, s.layout.sidewalk * 0.5)
		var mid := Vector2.ZERO
		for q in inner:
			mid += q
		mid /= inner.size()
		if s.plan.vacant.any(func(v): return v.grow(0.5).has_point(mid)):
			continue
		ok = ok and hit.call(inner[0].lerp(mid, 0.05))
	var dir := Vector2.from_angle(deg_to_rad(ANGLE))
	for t in [-70.0, -20.0, 20.0, 70.0]:
		ok = ok and not hit.call(dir * t)
	s.free()
	_done()
	return ok
