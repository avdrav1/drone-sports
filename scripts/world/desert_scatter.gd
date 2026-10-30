class_name DesertScatter
extends StaticBody3D
# Rocks, scrub, and trees in bulk on the desert (Story 15.8), placed from the
# terrain's seed and drawn through one MultiMesh per kind, variant, and chunk, so
# far chunks drop out by visibility range. Nothing lands in a city's core (its
# streets included) or clearings, or within a gate's radius of a course line.
# Rocks above knee height and trees collide, and stay outside the terrain's flat
# area, where jobs keep their geometry; scrub and low rocks never collide.
# DesertTerrain builds this after its ground. Plans are cached like the ground.
# The trees are khejri (Prosopis cineraria), the tree of the Thar around
# Jaisalmer: a crooked trunk splitting under a wide, flat crown of fine leaves.
# They stood in for saguaro cacti, which grow nowhere near India.

enum Kind { ROCK, SCRUB, TREE }

## Rocks whose top is above this collide, m.
const KNEE := 0.5
const VARIANTS := [3, 2, 2]
## Footprint radius of each kind's mesh at scale 1, m.
const FOOTPRINT := [1.0, 0.9, 2.6]

@export var rock_count := 8000
@export var scrub_count := 18000
@export var tree_count := 900
## Side of one drawing chunk, m.
@export var chunk_size := 300.0
## Beyond this distance a chunk of each kind is not drawn, m.
@export var draw_distance := Vector3(700.0, 260.0, 550.0)
@export var rock_material: Material
@export var scrub_material: Material
@export var tree_material: Material

static var _plans := {}
static var _meshes := {}
static var _shape_parts := {}

## The scatter for `terrain` with `keep_out` ([a: Vector2, b: Vector2, radius] in
## terrain space): an Array of [kind, variant, Transform3D, collides, tint].
static func plan(terrain: DesertTerrain, keep_out: Array, counts := Vector3i(8000, 18000, 900)) -> Array:
	var key := [terrain.params(), keep_out, counts]
	if not _plans.has(key):
		_plans[key] = _generate(terrain, keep_out, counts)
	return _plans[key]

## Keep-out lines under `root`, in `terrain`'s space: each city's core (with its
## streets) and clearings, and each course's gate-to-gate line at its gate radius.
static func keep_outs(root: Node, terrain: Node3D) -> Array:
	var out := []
	if root == null:
		return out
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "Node3D", true, false))
	for n in nodes:
		if n is City and n.layout:
			var l: CityLayout = n.layout
			var c := _flat(terrain.to_local(n.global_position))
			out.append([c, c, l.core_radius + l.avenue_width])
			for cl in l.clearings:
				var p := _flat(terrain.to_local(n.to_global(Vector3(cl.x, 0.0, cl.y))))
				out.append([p, p, cl.z])
		elif n is Course and n.data:
			var gates: Array[Transform3D] = n.data.gates
			for i in gates.size():
				var a := _flat(terrain.to_local(n.to_global(gates[i].origin)))
				var b := _flat(terrain.to_local(n.to_global(gates[(i + 1) % gates.size()].origin)))
				out.append([a, b, gate_radius(n.data)])
	return out

## How far a course line keeps scatter away: the gate's half-diagonal, m.
static func gate_radius(data: CourseData) -> float:
	return data.gate_size.length() * 0.5

## Distance from `p` to the nearest keep-out edge; negative inside one.
static func clearance(p: Vector2, keep_out: Array) -> float:
	var best := INF
	for k in keep_out:
		var q := Geometry2D.get_closest_point_to_segment(p, k[0], k[1])
		best = minf(best, p.distance_to(q) - float(k[2]))
	return best

static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

func build(terrain: DesertTerrain, keep_out: Array) -> void:
	var items := plan(terrain, keep_out, Vector3i(rock_count, scrub_count, tree_count))
	var materials := [rock_material, scrub_material, tree_material]
	# Group transforms by kind, variant, and chunk.
	var groups := {}
	for item in items:
		var xform: Transform3D = item[2]
		var chunk := Vector2i(floori(xform.origin.x / chunk_size), floori(xform.origin.z / chunk_size))
		var gkey := [item[0], item[1], chunk]
		if not groups.has(gkey):
			groups[gkey] = []
		groups[gkey].append(item)
		if item[3]:
			for part in _shapes(item[0], item[1]):
				var owner_id := create_shape_owner(self)
				shape_owner_add_shape(owner_id, part[0])
				shape_owner_set_transform(owner_id, xform * part[1])
	for gkey in groups:
		var list: Array = groups[gkey]
		var chunk: Vector2i = gkey[2]
		var centre := Vector3((chunk.x + 0.5) * chunk_size, 0.0, (chunk.y + 0.5) * chunk_size)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh(gkey[0], gkey[1])
		mm.instance_count = list.size()
		for i in list.size():
			var xf: Transform3D = list[i][2]
			mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - centre))
			mm.set_instance_custom_data(i, Color(list[i][4], 0.0, 0.0, 0.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s%d_%d_%d" % [Kind.keys()[gkey[0]], gkey[1], chunk.x, chunk.y]
		mmi.multimesh = mm
		mmi.material_override = materials[gkey[0]]
		mmi.position = centre
		mmi.visibility_range_end = draw_distance[gkey[0]]
		add_child(mmi)

static func _generate(terrain: DesertTerrain, keep_out: Array, counts: Vector3i) -> Array:
	var items := []
	var clump := FastNoiseLite.new()
	clump.seed = terrain.noise_seed + 211
	clump.frequency = 0.012
	var half := terrain.size * 0.5 - terrain.step() * 2.0
	var flat_edge := terrain.flat_radius + 10.0
	for kind in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([terrain.noise_seed, kind, "scatter"])
		var want: int = counts[kind]
		var placed := 0
		for attempt in want * 8:
			if placed >= want:
				break
			var x := rng.randf_range(-half, half)
			var z := rng.randf_range(-half, half)
			var roll := rng.randf()
			var variant := rng.randi_range(0, VARIANTS[kind] - 1)
			var size := rng.randf()
			var yaw := rng.randf() * TAU
			var tint := rng.randf()
			var h := terrain.height_at(x, z)
			var gx := terrain.height_at(x + 1.5, z) - terrain.height_at(x - 1.5, z)
			var gz := terrain.height_at(x, z + 1.5) - terrain.height_at(x, z - 1.5)
			var normal := Vector3(-gx, 3.0, -gz).normalized()
			var slope := 1.0 - normal.y
			var c := clump.get_noise_2d(x, z) * 0.5 + 0.5
			var r := Vector2(x, z).length()
			var scale := 1.0
			var chance := 0.0
			match kind:
				Kind.ROCK:
					# Strewn everywhere, thickest in clumps and on slopes; big ones are rare.
					chance = (0.25 + 0.75 * smoothstep(0.05, 0.3, slope)) * (0.3 + 0.7 * c)
					scale = lerpf(0.15, 0.9, pow(size, 2.0))
					if size > 0.9:
						scale *= 1.0 + (size - 0.9) * 30.0
				Kind.SCRUB:
					# Flat and gentle sand, in patches; little on the high ridges.
					chance = (1.0 - smoothstep(0.08, 0.3, slope)) * (0.15 + 0.85 * smoothstep(0.25, 0.65, c)) * (1.0 - smoothstep(25.0, 60.0, h))
					scale = lerpf(0.5, 1.5, size)
				Kind.TREE:
					# Khejri stand apart on the flats, a few to a clump.
					chance = (1.0 - smoothstep(0.05, 0.15, slope)) * (0.2 + 0.8 * c) * (1.0 - smoothstep(15.0, 35.0, h))
					scale = lerpf(0.7, 1.2, size)
			if roll >= chance:
				continue
			var foot: float = FOOTPRINT[kind] * scale
			var collides := kind == Kind.TREE or (kind == Kind.ROCK and scale * rock_top(variant) > KNEE)
			if collides and r < flat_edge + foot:
				if kind == Kind.TREE:
					continue
				# A pebble in the flat area instead of a boulder.
				scale = KNEE / rock_top(variant) * 0.95
				foot = FOOTPRINT[kind] * scale
				collides = false
			if clearance(Vector2(x, z), keep_out) < foot:
				continue
			var up := Vector3.UP
			if kind == Kind.ROCK:
				up = Vector3.UP.lerp(normal, 0.7).normalized()
			elif kind == Kind.SCRUB:
				up = Vector3.UP.lerp(normal, 0.4).normalized()
			var basis := _tilt(up) * Basis(Vector3.UP, yaw)
			items.append([kind, variant, Transform3D(basis.scaled(Vector3.ONE * scale), Vector3(x, h, z)), collides, tint])
			placed += 1
	return items

## A rotation taking +Y to `up`.
static func _tilt(up: Vector3) -> Basis:
	var axis := Vector3.UP.cross(up)
	if axis.length_squared() < 1e-8:
		return Basis()
	return Basis(axis.normalized(), Vector3.UP.angle_to(up))

## Height of a rock variant's top above the ground at scale 1, m.
static func rock_top(variant: int) -> float:
	return mesh(Kind.ROCK, variant).get_aabb().end.y

## The shared mesh for a kind and variant, built once.
static func mesh(kind: int, variant: int) -> ArrayMesh:
	var key := Vector2i(kind, variant)
	if not _meshes.has(key):
		match kind:
			Kind.ROCK:
				_meshes[key] = _rock_mesh(variant)
			Kind.SCRUB:
				_meshes[key] = _scrub_mesh(variant)
			_:
				_meshes[key] = _tree_mesh(variant)
	return _meshes[key]

## Collision for a kind and variant at scale 1: [[Shape3D, Transform3D], ...].
static func _shapes(kind: int, variant: int) -> Array:
	var key := Vector2i(kind, variant)
	if not _shape_parts.has(key):
		var out := []
		if kind == Kind.ROCK:
			out.append([mesh(kind, variant).create_convex_shape(true, true), Transform3D()])
		else:
			for part in _tree_parts(variant):
				var a: Vector3 = part[0]
				var b: Vector3 = part[1]
				var cyl := CylinderShape3D.new()
				cyl.height = a.distance_to(b)
				cyl.radius = part[2]
				out.append([cyl, Transform3D(_tilt((b - a).normalized()), (a + b) * 0.5)])
			# The crown, as a flat disc.
			var crown: Array = _crown(variant)
			var disc := CylinderShape3D.new()
			disc.radius = crown[1]
			disc.height = crown[2] * 1.4
			out.append([disc, Transform3D(Basis(), crown[0])])
		_shape_parts[key] = out
	return _shape_parts[key]

# An icosahedron subdivided `levels` times: [unit vertices, triangle indices].
static func _icosphere(levels: int) -> Array:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var verts := PackedVector3Array([
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)])
	for i in verts.size():
		verts[i] = verts[i].normalized()
	var tris := PackedInt32Array([0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4,
		11, 10, 2, 10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5,
		2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1])
	for level in levels:
		var mids := {}
		var next := PackedInt32Array()
		for f in tris.size() / 3:
			var abc := [tris[f * 3], tris[f * 3 + 1], tris[f * 3 + 2]]
			var m := []
			for e in 3:
				var i0: int = abc[e]
				var i1: int = abc[(e + 1) % 3]
				var ek := Vector2i(mini(i0, i1), maxi(i0, i1))
				if not mids.has(ek):
					mids[ek] = verts.size()
					verts.append(((verts[i0] + verts[i1]) * 0.5).normalized())
				m.append(mids[ek])
			next.append_array([abc[0], m[0], m[2], abc[1], m[1], m[0], abc[2], m[2], m[1], m[0], m[1], m[2]])
		tris = next
	return [verts, tris]

# Adds counter-clockwise triangles (outward by the right-hand rule) flipped to
# Godot's clockwise front faces.
static func _add_tris(st: SurfaceTool, tris: Variant, base: int) -> void:
	for f in tris.size() / 3:
		st.add_index(base + tris[f * 3])
		st.add_index(base + tris[f * 3 + 2])
		st.add_index(base + tris[f * 3 + 1])

static func _commit(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()

# A lumpy, squat boulder with its base sunk below y = 0.
static func _rock_mesh(variant: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = 31 + variant
	noise.frequency = 0.9
	var squash: Vector3 = [Vector3(1.0, 0.62, 0.85), Vector3(0.8, 0.8, 1.0), Vector3(1.1, 0.5, 0.9)][variant]
	var sphere := _icosphere(1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in sphere[0]:
		var p := v * (1.0 + noise.get_noise_3dv(v * 1.7) * 0.45) * squash
		p.y = maxf(p.y, -0.3) + 0.15
		st.add_vertex(p)
	_add_tris(st, sphere[1], 0)
	return _commit(st)

# A shrub: a cluster of rough lumps of foliage, with normals bent out from the
# bush's middle so it shades as one mass rather than as separate balls.
static func _scrub_mesh(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71 + variant
	var noise := FastNoiseLite.new()
	noise.seed = 51 + variant
	noise.frequency = 2.5
	var sphere := _icosphere(0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lumps := 6 + variant * 2
	var base := 0
	for k in lumps:
		var a := TAU * k / lumps + rng.randf() * 0.6
		var d := rng.randf_range(0.05, 0.5)
		var r := rng.randf_range(0.24, 0.4)
		var centre := Vector3(cos(a) * d, r * 0.5 + rng.randf() * 0.4 * (1.0 - d), sin(a) * d)
		for v: Vector3 in sphere[0]:
			var p := centre + v * r * (1.0 + noise.get_noise_3dv(v + centre * 3.0) * 0.7) * Vector3(1.0, 0.7, 1.0)
			p.y = maxf(p.y, 0.02)
			st.set_normal(v.lerp((p - Vector3(0.0, 0.2, 0.0)).normalized(), 0.75).normalized())
			st.add_vertex(p)
		_add_tris(st, sphere[1], base)
		base += sphere[0].size()
	return st.commit()

# Khejri trunk and boughs, [from, to, radius] at scale 1: a leaning trunk that
# splits at about head height into boughs reaching up and out to the crown.
static func _tree_parts(variant: int) -> Array:
	if variant == 0:
		return [
			[Vector3.ZERO, Vector3(0.25, 1.9, 0.05), 0.22],
			[Vector3(0.25, 1.85, 0.05), Vector3(1.3, 3.3, 0.4), 0.13],
			[Vector3(0.25, 1.85, 0.05), Vector3(-0.9, 3.4, 0.5), 0.12],
			[Vector3(0.25, 1.85, 0.05), Vector3(0.1, 3.6, -1.0), 0.12],
			[Vector3(0.25, 1.85, 0.05), Vector3(0.5, 3.8, 0.1), 0.1]]
	return [
		[Vector3.ZERO, Vector3(-0.2, 1.5, 0.15), 0.18],
		[Vector3(-0.2, 1.45, 0.15), Vector3(0.8, 2.7, -0.2), 0.11],
		[Vector3(-0.2, 1.45, 0.15), Vector3(-0.9, 2.8, 0.4), 0.1],
		[Vector3(-0.2, 1.45, 0.15), Vector3(0.0, 3.0, 0.7), 0.09]]

## The crown: [centre, radius, half thickness] at scale 1.
static func _crown(variant: int) -> Array:
	if variant == 0:
		return [Vector3(0.2, 3.9, 0.0), 2.5, 0.65]
	return [Vector3(-0.05, 3.1, 0.15), 1.8, 0.6]

# The tree: tapering boughs in bark (vertex colour black), under a crown of
# flattened leafy lumps (white), so the scatter shader shades each apart.
static func _tree_mesh(variant: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 7
	var base := 0
	for part in _tree_parts(variant):
		var a: Vector3 = part[0]
		var b: Vector3 = part[1]
		var radius: float = part[2]
		var basis := _tilt((b - a).normalized())
		for j in 2:
			var r := radius * (1.0 if j == 0 else 0.55)
			for i in sides:
				var ang := TAU * i / sides
				var out := basis * Vector3(cos(ang), 0.0, sin(ang))
				st.set_color(Color.BLACK)
				st.set_normal(out)
				st.add_vertex((a if j == 0 else b) + out * r)
		for i in sides:
			var i1 := (i + 1) % sides
			_add_tris(st, [base + i, base + sides + i, base + i1, base + i1, base + sides + i, base + sides + i1], 0)
		base += sides * 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 + variant
	var noise := FastNoiseLite.new()
	noise.seed = 61 + variant
	noise.frequency = 2.0
	var sphere := _icosphere(1)
	var crown: Array = _crown(variant)
	var centre: Vector3 = crown[0]
	var reach: float = crown[1]
	var thick: float = crown[2]
	var lumps := 9 + variant * 2
	for k in lumps:
		# A ring of lumps round one in the middle, flattest at the rim: an umbrella.
		var a := TAU * k / lumps + rng.randf() * 0.5
		var d := 0.0 if k == 0 else reach * rng.randf_range(0.45, 0.75)
		var r := reach * rng.randf_range(0.3, 0.42)
		var at := centre + Vector3(cos(a) * d, rng.randf_range(-0.15, 0.2) - d * 0.08, sin(a) * d)
		for v: Vector3 in sphere[0]:
			var p := at + v * r * (1.0 + noise.get_noise_3dv(v + at) * 0.5) * Vector3(1.0, thick / r * 0.9, 1.0)
			st.set_color(Color.WHITE)
			st.set_normal(v.lerp((p - centre + Vector3(0.0, reach * 0.4, 0.0)).normalized(), 0.7).normalized())
			st.add_vertex(p)
		_add_tris(st, sphere[1], base)
		base += sphere[0].size()
	return st.commit()
