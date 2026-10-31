class_name Streets
extends StaticBody3D
# The street level of a CityPlan: an asphalt road mesh just above the ground
# (segments between crossings, plus the crossings), raised pavements on the
# blocks behind a kerb on every edge, and street lights along the kerbs. Lights,
# kerbs, and pavements collide; the road does not. Cached per layout, like City.
# Story 15.7: the road, pavements, and kerbs take library surfaces, and road
# segments carry their markings and decals (crosswalks, stop lines, lane arrows,
# patches, manholes, drains) as vertex data the road shader draws, placed from
# the layout's seed in chunks so each decal sits inside its own chunk's quad.
# Story 26.5: everything reads the plan's general form (paths, junctions, block
# polygons), so streets can run at any angle. Roads are built per street leg in
# the leg's own frame, cut where another street crosses its width, with a patch
# over each crossing's leftover ground and over the outside of each bend;
# kerbs, pavements and lights follow the block outlines. A grid builds exactly
# what it did from rectangles.

## Road decals placed from the seed, besides crosswalks.
enum Mark { MANHOLE, DRAIN, PATCH, ARROW }

const ROAD_Y := 0.02
## Empty vertex data (Color() is opaque black, which reads as "present").
const NONE := Color(0, 0, 0, 0)
## Crosswalks start this far from a segment's end and run this deep.
const CROSSWALK_GAP := 0.5
const CROSSWALK_DEPTH := 3.0
## An arrow sits this far back from its crosswalk's far edge, and is this long.
const ARROW_BACK := 1.5
const ARROW_LENGTH := 4.0
const MANHOLE_RADIUS := 0.35
const DRAIN_SIZE := Vector2(0.9, 0.45)

@export var layout: CityLayout
@export var road_material: ShaderMaterial
@export var light_material: Material
## Library surfaces (Story 15.2) for the road, the pavements, and the kerbs.
@export var asphalt: SurfaceSet
@export var paving: SurfaceSet
@export var kerb_stone: SurfaceSet
## Metres between street lights along a kerb.
@export var light_spacing := 15.0
## How far in from the kerb a light stands.
@export var light_inset := 0.8
@export var pole_height := 6.0
@export var pole_radius := 0.12
## Pavement and kerb top, above the street.
@export var kerb_height := 0.15
@export var kerb_width := 0.3
## Road segments split into chunks at least this long; each holds at most one of
## each decal.
@export var chunk_length := 10.0

## params -> [road, pavement, poles, heads, lights, pole shape, kerb MultiMesh,
## kerbs, pavement boxes, crosswalks, decals].
static var _cache := {}

var plan: CityPlan
## Where each light stands, on the ground.
var lights := PackedVector3Array()
## Each kerb along a block edge, as its Kerbs MultiMesh transform (a unit box
## scaled and turned; box_of() gives its bounds); same order as the MultiMesh.
var kerbs: Array[Transform3D] = []
## Each crosswalk's footprint in XZ, a quad.
var crosswalks: Array[PackedVector2Array] = []
## Each decal: [Mark kind, footprint in XZ (a quad), index of its road chunk].
var decals: Array = []

func _ready() -> void:
	build()

func build() -> void:
	plan = CityPlan.build(layout)
	var key := layout.params() + [light_spacing, light_inset, pole_height, pole_radius, kerb_height, kerb_width, chunk_length]
	if not _cache.has(key):
		_cache[key] = _generate()
	var built: Array = _cache[key]
	var mats := _materials()
	_mesh("Road", built[0], mats[0])
	_mesh("Sidewalks", built[1], mats[1])
	for i in 3:
		var mm := MultiMeshInstance3D.new()
		mm.name = ["Poles", "Heads", "Kerbs"][i]
		mm.multimesh = built[[2, 3, 6][i]]
		mm.material_override = light_material if i < 2 else mats[2]
		add_child(mm)
	lights = built[4]
	kerbs = built[7]
	crosswalks = built[9]
	decals = built[10]
	for i in lights.size():
		_shape("Light%d" % i, built[5], lights[i] + Vector3.UP * pole_height * 0.5)
	for i in kerbs.size():
		var k := kerbs[i]
		var shape := BoxShape3D.new()
		shape.size = k.basis.get_scale()
		_shape("Kerb%d" % i, shape, k.origin, k.basis.orthonormalized())
	var pavements: Array = built[8]
	for i in pavements.size():
		var p = pavements[i]
		if p is AABB:
			var shape := BoxShape3D.new()
			shape.size = p.size
			_shape("Pavement%d" % i, shape, p.get_center())
		else:
			# An outline that is not a rect: a prism up to the pavement's top.
			var shape := ConvexPolygonShape3D.new()
			var points := PackedVector3Array()
			for q: Vector2 in p:
				points.append(Vector3(q.x, 0.0, q.y))
				points.append(Vector3(q.x, kerb_height, q.y))
			shape.points = points
			_shape("Pavement%d" % i, shape, Vector3.ZERO)

## Frees what build() made, keeping the scene's own children, so the node can
## build again from a new layout (Story 26.1).
func clear() -> void:
	for c in get_children():
		if c.owner == null:
			remove_child(c)
			c.queue_free()

## Drops cached builds of every layout but `keep`.
static func prune(keep: CityLayout) -> void:
	keep.prune(_cache)

func _shape(n: String, s: Shape3D, at: Vector3, turn := Basis()) -> void:
	var shape := CollisionShape3D.new()
	shape.name = n
	shape.shape = s
	shape.transform = Transform3D(turn, at)
	add_child(shape)

## The road material with the library maps, and copies for pavements and kerbs.
func _materials() -> Array:
	if road_material == null:
		return [null, null, null]
	var out := []
	for layer in 3:
		var m: ShaderMaterial = road_material.duplicate()
		var s: SurfaceSet = [asphalt, paving, kerb_stone][layer]
		m.set_shader_parameter("layer", layer)
		if s:
			m.set_shader_parameter("surface_albedo", s.albedo)
			m.set_shader_parameter("surface_nr", s.normal_rough)
			m.set_shader_parameter("tile", s.tile_size)
		m.set_shader_parameter("crack_seed", float(layout.seed % 1000))
		out.append(m)
	return out

## A piece of road (Story 26.5): a stretch of one street between the places
## other streets cut it, or a patch where streets meet. Each works in a local
## frame: u = p·d along the street and v = p·n across it, where n is d turned a
## quarter (both picked so x + z > 0, so a grid street's frame is the world's own
## axes). A stretch covers u from a0 to a1 and v within width / 2 of c.
class Piece extends RefCounted:
	## 0 street, 1 avenue, 2 a patch where streets meet.
	var kind := 0
	## The plan's path this stretch lies on; -1 for a patch.
	var street := -1
	var width := 0.0
	var d := Vector2.ZERO
	var n := Vector2.ZERO
	var a0 := 0.0
	var a1 := 0.0
	var c := 0.0
	## Footprint in XZ (a stretch's four corners, or a patch's outline).
	var poly := PackedVector2Array()
	## A patch over a bend or two street ends meeting at an angle, not a crossing:
	## the road runs on through it, so it does not end a stretch (meets()).
	var joint := false
	## For a stretch, whether its a0 and a1 ends stop at a joint.
	var joined := [false, false]

	func local(p: Vector2) -> Vector2:
		return Vector2(p.dot(d), p.dot(n))

	func world(l: Vector2) -> Vector2:
		return d * l.x + n * l.y

	## A local rect (x along, y across) as a quad in XZ.
	func area(r: Rect2) -> PackedVector2Array:
		return PackedVector2Array([world(r.position), world(Vector2(r.end.x, r.position.y)), world(r.end),
			world(Vector2(r.position.x, r.end.y))])

	## The whole stretch as a local rect.
	func span() -> Rect2:
		return Rect2(a0, c - width * 0.5, a1 - a0, width)

	## The across sign of the lane heading +d (right-hand traffic).
	func lane() -> float:
		return signf(Vector2(-d.y, d.x).dot(n))

	func bounds() -> Rect2:
		return Streets.bounds(poly)

	## True when `p` lies on this piece (a stretch's far edges excluded, as Rect2).
	func has_point(p: Vector2) -> bool:
		if kind == 2:
			return bounds().has_point(p) if Streets.square(poly) else Geometry2D.is_point_in_polygon(p, poly)
		return span().has_point(local(p))

## `v` flipped, if need be, so that x + z > 0 (x > 0 on a tie), and with no
## negative zeros, so frames and yaws come out the same for every grid street.
static func canon(v: Vector2) -> Vector2:
	var s := v.x + v.y
	if s < -1e-9 or (absf(s) <= 1e-9 and v.x < 0.0):
		v = -v
	return v + Vector2.ZERO

## The axis-aligned bounds of a polygon.
static func bounds(poly: PackedVector2Array) -> Rect2:
	var out := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		out = out.expand(p)
	return out

## True when `poly` is an axis-aligned rectangle (its bounds, exactly).
static func square(poly: PackedVector2Array) -> bool:
	if poly.size() != 4:
		return false
	for i in 4:
		var e := poly[(i + 1) % 4] - poly[i]
		if e.x != 0.0 and e.y != 0.0:
			return false
	return true

## True when two polygons share ground (more than touching).
static func overlaps(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if not bounds(a).intersects(bounds(b)):
		return false
	if square(a) and square(b):
		return true
	for part in Geometry2D.intersect_polygons(a, b):
		if absf(CityPlan.area(part)) > 1e-6:
			return true
	return false

## The ground two polygons share, as one polygon (empty for none). Two
## axis-aligned rects give their rect exactly.
static func _shared(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	if not bounds(a).intersects(bounds(b)):
		return PackedVector2Array()
	if square(a) and square(b):
		return CityPlan.polygon(bounds(a).intersection(bounds(b)))
	var best := PackedVector2Array()
	for part in Geometry2D.intersect_polygons(a, b):
		if absf(CityPlan.area(part)) > maxf(1e-4, absf(CityPlan.area(best))):
			best = part
	return best

## A street's straight legs: [from, to] for each run of its centreline that
## keeps one direction.
static func _legs(path: CityPlan.Street) -> Array:
	# Repeated points (a junction's point on an end) would make empty legs.
	var points := PackedVector2Array()
	for q in path.points:
		if points.is_empty() or points[-1].distance_to(q) > 1e-4:
			points.append(q)
	var out := []
	var start := 0
	for k in range(1, points.size()):
		if k < points.size() - 1:
			var d1 := (points[k] - points[start]).normalized()
			var d2 := (points[k + 1] - points[k]).normalized()
			if d1.dot(d2) > 0.99999:
				continue
		out.append([points[start], points[k]])
		start = k
	return out

## Where two legs meet end to end at an angle (a bend in a path, or the ends of
## two legs that meet and no others): both legs cut back, in place, to where
## the kerb lines on the inside of the turn cross, and the ground left on the
## outside as a patch, mitred (bevelled past a 120° turn). `ends` holds each
## leg's [from, to]; returns [patch, leg, leg] for each joint.
static func _joints(p: CityPlan, legs: Array[Piece], ends: Array, of: Dictionary) -> Array:
	var pairs := []
	var tips := []
	for i in p.paths.size():
		var mine: Array = of[i]
		for k in range(1, mine.size()):
			pairs.append([mine[k - 1], 1, mine[k], 0])
		if not mine.is_empty():
			tips.append([mine[0], 0])
			tips.append([mine[-1], 1])
	for x in tips.size():
		for y in range(x + 1, tips.size()):
			var a: Array = tips[x]
			var b: Array = tips[y]
			var q: Vector2 = ends[a[0]][a[1]]
			if a[0] == b[0] or q.distance_to(ends[b[0]][b[1]]) > 1e-3:
				continue
			if tips.any(func(t): return t != a and t != b and q.distance_to(ends[t[0]][t[1]]) <= 1e-3):
				continue
			pairs.append([a[0], a[1], b[0], b[1]])
	var out := []
	for pr in pairs:
		var A: Piece = legs[pr[0]]
		var B: Piece = legs[pr[2]]
		var q: Vector2 = ends[pr[0]][pr[1]]
		# Each leg's direction away from where they meet.
		var ea: Vector2 = (ends[pr[0]][1 - pr[1]] - q).normalized()
		var eb: Vector2 = (ends[pr[2]][1 - pr[3]] - q).normalized()
		var dot := ea.dot(eb)
		if dot < -0.99999 or dot > 0.99:
			continue
		# Normals toward the other leg: the inside of the turn.
		var na := Vector2(-ea.y, ea.x)
		if na.dot(eb) < 0.0:
			na = -na
		var nb := Vector2(-eb.y, eb.x)
		if nb.dot(ea) < 0.0:
			nb = -nb
		var ha := A.width * 0.5
		var hb := B.width * 0.5
		var inner = Geometry2D.line_intersects_line(q + na * ha, ea, q + nb * hb, eb)
		var outer = Geometry2D.line_intersects_line(q - na * ha, ea, q - nb * hb, eb)
		if inner == null or outer == null:
			continue
		var ta: float = (inner - q).dot(ea)
		var tb: float = (inner - q).dot(eb)
		if ta < 0.0 or tb < 0.0 or ta >= A.a1 - A.a0 - 0.01 or tb >= B.a1 - B.a0 - 0.01:
			continue
		_trim(A, ea, ta)
		_trim(B, eb, tb)
		var ca := q + ea * ta - na * ha
		var cb := q + eb * tb - nb * hb
		var poly := PackedVector2Array([inner, ca, outer, cb]) if dot <= 0.5 else PackedVector2Array([inner, ca, cb])
		out.append([poly, pr[0], pr[2]])
	return out

## Cuts `by` off the end of stretch `L` that direction `away` (into the leg)
## leaves from.
static func _trim(L: Piece, away: Vector2, by: float) -> void:
	if away.dot(L.d) > 0.0:
		L.a0 += by
		L.joined[0] = true
	else:
		L.a1 -= by
		L.joined[1] = true
	L.poly = L.area(L.span())

static func _stretch(i: int, path: CityPlan.Street, from: Vector2, to: Vector2) -> Piece:
	var p := Piece.new()
	p.street = i
	p.kind = 1 if path.kind == CityPlan.Kind.AVENUE else 0
	p.width = path.width
	p.d = canon((to - from).normalized())
	p.n = canon(Vector2(-p.d.y, p.d.x))
	p.a0 = minf(from.dot(p.d), to.dot(p.d))
	p.a1 = maxf(from.dot(p.d), to.dot(p.d))
	p.c = from.dot(p.n)
	p.poly = p.area(p.span())
	return p

## The road, as pieces that together cover every street exactly once: each
## street's legs, cut back at bends and where street ends meet at an angle
## (_joints), cut wherever another street crosses its whole width, and a patch
## over the ground each crossing or joint leaves, emitted (once) just before
## the stretches of the street at it that runs most nearly along z.
static func road_pieces(p: CityPlan, _l: CityLayout = null) -> Array:
	var legs: Array[Piece] = []
	var ends := []
	var of := {}
	for i in p.paths.size():
		of[i] = []
		for leg in _legs(p.paths[i]):
			of[i].append(legs.size())
			ends.append(leg)
			legs.append(_stretch(i, p.paths[i], leg[0], leg[1]))
	var cuts := {}
	for k in legs.size():
		cuts[k] = []
	# Patches: [zones, legs at it, legs cut there, true for a joint only].
	var patches := []
	for j in _joints(p, legs, ends, of):
		patches.append([[j[0]], {j[1]: true, j[2]: true}, {j[1]: true, j[2]: true}, true])
	for j in p.junctions:
		var zones: Array[PackedVector2Array] = []
		var at := {}
		var cut := {}
		for x in j.streets:
			for y in j.streets:
				if x == y:
					continue
				for a: int in of[x]:
					for b: int in of[y]:
						var o := _shared(legs[a].poly, legs[b].poly)
						if o.is_empty():
							continue
						at[a] = true
						var L := legs[a]
						var lo := Vector2(INF, INF)
						var hi := -lo
						for q in o:
							var lq := L.local(q)
							lo = Vector2(minf(lo.x, lq.x), minf(lo.y, lq.y))
							hi = Vector2(maxf(hi.x, lq.x), maxf(hi.y, lq.y))
						# Only a street that spans this one's width cuts it.
						if hi.y - lo.y < L.width - 0.001:
							continue
						cuts[a].append(Vector2(lo.x, hi.x))
						cut[a] = true
						var zone := L.area(Rect2(lo.x, L.c - L.width * 0.5, hi.x - lo.x, L.width))
						if not zones.any(func(z): return _same(z, zone)):
							zones.append(zone)
		if not zones.is_empty():
			patches.append([zones, at, cut, false])
	# Patches that share ground are one patch.
	var k := 0
	while k < patches.size():
		var merged := false
		for m in range(k + 1, patches.size()):
			if patches[k][0].any(func(z): return patches[m][0].any(func(w): return overlaps(z, w))):
				for z in patches[m][0]:
					if not patches[k][0].any(func(w): return _same(z, w)):
						patches[k][0].append(z)
				patches[k][1].merge(patches[m][1])
				patches[k][2].merge(patches[m][2])
				patches[k][3] = patches[k][3] and patches[m][3]
				patches.remove_at(m)
				merged = true
				break
		if not merged:
			k += 1
	var before := {}
	for patch in patches:
		var polys := _patch(patch[0], patch[1], patch[2], legs, cuts)
		if polys.is_empty():
			continue
		var owner := -1
		for a in patch[2]:
			if owner < 0 or absf(legs[a].d.y) > absf(legs[owner].d.y) + 1e-9 \
					or (absf(absf(legs[a].d.y) - absf(legs[owner].d.y)) <= 1e-9 and legs[a].street < legs[owner].street):
				owner = a
		var key := INF
		for a in patch[2]:
			if a != owner:
				key = minf(key, legs[a].street)
		if not before.has(owner):
			before[owner] = []
		var L := legs[owner]
		for poly in polys:
			var piece := Piece.new()
			piece.kind = 2
			piece.joint = patch[3]
			piece.width = L.width
			piece.d = L.d
			piece.n = L.n
			piece.poly = poly
			var lo := Vector2(INF, INF)
			var hi := -lo
			for q in poly:
				var lq := L.local(q)
				lo = Vector2(minf(lo.x, lq.x), minf(lo.y, lq.y))
				hi = Vector2(maxf(hi.x, lq.x), maxf(hi.y, lq.y))
			piece.a0 = lo.x
			piece.a1 = hi.x
			piece.c = (lo.y + hi.y) * 0.5
			before[owner].append([key, piece])
	var out := []
	for a in legs.size():
		if before.has(a):
			var mine: Array = before[a]
			mine.sort_custom(func(x, y): return x[0] < y[0])
			for e in mine:
				out.append(e[1])
		var L := legs[a]
		var list: Array = cuts[a]
		list.sort_custom(func(x, y): return x.x < y.x)
		var from := L.a0
		for c in list + [Vector2(L.a1, L.a1)]:
			if c.x > from + 0.001:
				var piece := Piece.new()
				piece.kind = L.kind
				piece.street = L.street
				piece.width = L.width
				piece.d = L.d
				piece.n = L.n
				piece.c = L.c
				piece.a0 = from
				piece.a1 = c.x
				piece.joined = [L.joined[0] and from == L.a0, L.joined[1] and c.x == L.a1]
				piece.poly = piece.area(piece.span())
				out.append(piece)
			from = maxf(from, c.y)
	return out

## True when two polygons have the same corners in the same order.
static func _same(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not a[i].is_equal_approx(b[i]):
			return false
	return true

## The ground a crossing leaves between the stretches round it: its zones
## together, less any leg there that runs on uncut (which already covers it),
## and less what the stretches of a leg cut there cover outside its cuts (a
## diagonal avenue cut by one street can still run over another's T end,
## Story 26.6; at a grid crossing they only touch, so nothing changes).
static func _patch(zones: Array, at: Dictionary, cut: Dictionary, legs: Array, cuts := {}) -> Array[PackedVector2Array]:
	var parts: Array[PackedVector2Array] = []
	parts.assign(zones)
	for a in at:
		if cut.has(a):
			if cuts.has(a):
				parts = _less_stretches(parts, legs[a], cuts[a])
			continue
		var cover: PackedVector2Array = legs[a].poly
		var next: Array[PackedVector2Array] = []
		for z in parts:
			if square(z) and square(cover) and bounds(cover).encloses(bounds(z)):
				continue
			if not overlaps(z, cover):
				next.append(z)
				continue
			for rest in Geometry2D.clip_polygons(z, cover):
				if CityPlan.area(rest) > 0.01:
					next.append(rest)
		parts = next
	if parts.size() <= 1:
		return parts
	var union: Array[PackedVector2Array] = [parts[0]]
	for z in parts.slice(1):
		var merged := false
		for u in union.size():
			if overlaps(union[u], z):
				var both := Geometry2D.merge_polygons(union[u], z).filter(func(q): return CityPlan.area(q) > 0.0)
				union[u] = both[0]
				for extra in both.slice(1):
					union.append(extra)
				merged = true
				break
		if not merged:
			union.append(z)
	return union

## `parts` less the ground leg `L`'s stretches cover between its cuts
## `list`; only parts sharing more than a hundredth of a m² with a stretch
## are clipped, so ones a stretch only touches keep their corners exactly.
static func _less_stretches(parts: Array[PackedVector2Array], L: Piece, list: Array) -> Array[PackedVector2Array]:
	var sorted := list.duplicate()
	sorted.sort_custom(func(x, y): return x.x < y.x)
	var from := L.a0
	for c in sorted + [Vector2(L.a1, L.a1)]:
		if c.x > from + 0.001:
			var cover := L.area(Rect2(from, L.c - L.width * 0.5, c.x - from, L.width))
			var next: Array[PackedVector2Array] = []
			for z in parts:
				var shared := 0.0
				if bounds(z).intersects(bounds(cover)):
					for q in Geometry2D.intersect_polygons(z, cover):
						shared += absf(CityPlan.area(q))
				if shared <= 0.01:
					next.append(z)
					continue
				for rest in Geometry2D.clip_polygons(z, cover):
					if CityPlan.area(rest) > 0.01:
						next.append(rest)
			parts = next
		from = maxf(from, c.y)
	return parts

## True when another piece meets `piece`'s end at `along` (a crossing or a
## street it runs into; a joint, where the road runs on, is neither).
static func meets(pieces: Array, piece: Piece, along: float) -> bool:
	if (piece.joined[0] and absf(along - piece.a0) < 1e-3) or (piece.joined[1] and absf(along - piece.a1) < 1e-3):
		return false
	var edge := piece.span()
	edge.position.x = along - 0.01
	edge.size.x = 0.02
	var sliver := piece.area(edge)
	for o in pieces:
		if o != piece and not o.joint and overlaps(sliver, o.poly):
			return true
	return false

## A block outline's edges (Story 26.5), each [start, unit direction, inward
## normal, length, s0, s1]. The direction is canon()'s, so a rect gives its -z,
## +z, -x, +x sides in that order: edges running nearer x first, each group from
## low to high across. s0 and s1 are how far the edge's kerb stands back from
## its start and end corners so kerbs meet without overlapping: at each corner
## the edge running nearer x (on a tie, the one starting there in outline order)
## runs to the corner, as near as the corner's angle lets it, and the other
## stops behind it.
static func edges(poly: PackedVector2Array, kerb: float) -> Array:
	var count := poly.size()
	var turn := 1.0 if CityPlan.area(poly) > 0.0 else -1.0
	var dirs: Array[Vector2] = []
	for i in count:
		dirs.append((poly[(i + 1) % count] - poly[i]).normalized())
	var out := []
	for i in count:
		var dir := dirs[i]
		var back := [0.0, 0.0]
		for side in 2:
			var other := dirs[(i - 1 + count) % count] if side == 0 else dirs[(i + 1) % count]
			var mine := dir if side == 0 else -dir
			var theirs := -other if side == 0 else other
			var cos_a := mine.dot(theirs)
			var sin_a := absf(mine.cross(theirs))
			var convex := (other.cross(dir) if side == 0 else dir.cross(other)) * turn > 0.0
			var owner := absf(dir.x) > absf(other.x) + 1e-9 or (absf(absf(dir.x) - absf(other.x)) <= 1e-9 and side == 0)
			if convex and sin_a > 1e-6:
				if owner:
					back[side] = maxf(0.0, kerb * cos_a / sin_a)
				elif cos_a > 0.0:
					back[side] = kerb * (1.0 + cos_a) / sin_a
				else:
					# The least setback that keeps clear of the owner's kerb (which
					# runs to the corner): kerb * sin_a, kerb at a right angle.
					back[side] = kerb * sin_a
		var along := canon(dir)
		var flip := not along.is_equal_approx(dir)
		var start := poly[(i + 1) % count] if flip else poly[i]
		var finish := poly[i] if flip else poly[(i + 1) % count]
		var inward := Vector2(-dir.y, dir.x) * turn + Vector2.ZERO
		var mid := (start + finish) * 0.5
		out.append([start, along, inward, (finish - start).length(), back[1] if flip else back[0],
			back[0] if flip else back[1], absf(along.x) >= absf(along.y), mid.dot(canon(Vector2(-along.y, along.x)))])
	var order := range(count)
	order.sort_custom(func(x, y):
		var ex: Array = out[x]
		var ey: Array = out[y]
		if ex[6] != ey[6]:
			return ex[6]
		if absf(ex[7] - ey[7]) > 1e-6:
			return ex[7] < ey[7]
		return x < y)
	return order.map(func(x): return (out[x] as Array).slice(0, 6))

## True when every corner of `poly` turns the same way.
static func convex(poly: PackedVector2Array) -> bool:
	var sign := 0.0
	for i in poly.size():
		var a := poly[(i + 1) % poly.size()] - poly[i]
		var b := poly[(i + 2) % poly.size()] - poly[(i + 1) % poly.size()]
		var x := a.cross(b)
		if absf(x) > 1e-9:
			if sign != 0.0 and signf(x) != sign:
				return false
			sign = signf(x)
	return true

## A polygon stood in by `by` on every side; a convex one keeps its corners
## exactly where a rect's grow(-by) would put them.
static func inset(poly: PackedVector2Array, by: float) -> PackedVector2Array:
	if not convex(poly):
		var grown := Geometry2D.offset_polygon(poly, -by)
		return grown[0] if not grown.is_empty() else PackedVector2Array()
	var count := poly.size()
	var turn := 1.0 if CityPlan.area(poly) > 0.0 else -1.0
	var out := PackedVector2Array()
	for i in count:
		var prev := (poly[i] - poly[(i - 1 + count) % count]).normalized()
		var next := (poly[(i + 1) % count] - poly[i]).normalized()
		var m0 := Vector2(-prev.y, prev.x) * turn
		var m1 := Vector2(-next.y, next.x) * turn
		out.append(poly[i] + (m0 + m1) * (by / (1.0 + m0.dot(m1))))
	# An edge shorter than the inset at a sharp corner (a wedge's tip) folds the
	# moved corners past each other; let the clipper drop that edge instead.
	if not convex(out) or CityPlan.area(out) * turn <= 0.0:
		var grown := Geometry2D.offset_polygon(poly, -by, Geometry2D.JOIN_MITER)
		return grown[0] if not grown.is_empty() else PackedVector2Array()
	return out

## True when `r` lies inside the polygon `poly` (edges included).
static func encloses(poly: PackedVector2Array, r: Rect2) -> bool:
	if square(poly):
		return bounds(poly).encloses(r)
	return CityPlan.fits(r, poly)

## True when the polygon `inner` lies inside the polygon `poly`.
static func holds(poly: PackedVector2Array, inner: PackedVector2Array) -> bool:
	var left := 0.0
	for part in Geometry2D.clip_polygons(inner, poly):
		left += absf(CityPlan.area(part))
	return left <= 1e-4

## True when every corner of `poly` lies within `radius` of the origin.
static func within(poly: PackedVector2Array, radius: float) -> bool:
	for p in poly:
		if p.length() > radius:
			return false
	return true

## A kerb's box (Kerbs MultiMesh transform: a unit box scaled and turned).
static func box_of(xform: Transform3D) -> AABB:
	return xform * AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)

func _mesh(n: String, m: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.material_override = mat
	add_child(mi)

func _generate() -> Array:
	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in 4:
		road.set_custom_format(c, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var marks := _markings(road)
	var walk := SurfaceTool.new()
	walk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var found := []
	var kerb_boxes: Array[Transform3D] = []
	var pavements := []
	for b in plan.block_polygons:
		if within(b, layout.core_radius):
			# Vacant lots (Story 26.2) are holes in the pavement: the sand shows.
			for inner in cut_polygon(inset(b, kerb_width), plan.vacant):
				_polygon(walk, inner, kerb_height, Vector2.DOWN, Vector2.RIGHT, bounds(inner).get_center().x, 0.0, 3)
				if square(inner):
					var r := bounds(inner)
					pavements.append(AABB(Vector3(r.position.x, 0.0, r.position.y), Vector3(r.size.x, kerb_height, r.size.y)))
				else:
					pavements.append(inner)
			kerb_boxes.append_array(_block_kerbs(b))
			found.append_array(_block_lights(b))
	var kerb_mm := _multimesh(BoxMesh.new(), kerb_boxes.size())
	for i in kerb_boxes.size():
		kerb_mm.set_instance_transform(i, kerb_boxes[i])
	var at := PackedVector3Array()
	var poles := _multimesh(CylinderMesh.new(), found.size())
	poles.mesh.top_radius = pole_radius * 0.6
	poles.mesh.bottom_radius = pole_radius
	poles.mesh.height = pole_height
	var heads := _multimesh(BoxMesh.new(), found.size())
	heads.mesh.size = Vector3(0.25, 0.12, 0.9)
	for i in found.size():
		var p: Vector3 = found[i][0]
		var facing: float = found[i][1]
		at.append(p)
		poles.set_instance_transform(i, Transform3D(Basis(), p + Vector3.UP * pole_height * 0.5))
		var turn := Basis(Vector3.UP, facing)
		heads.set_instance_transform(i, Transform3D(turn, p + Vector3.UP * pole_height + turn * Vector3(0, 0, -0.4)))
	var shape := CylinderShape3D.new()
	shape.radius = pole_radius
	shape.height = pole_height
	return [road.commit(), walk.commit(), poles, heads, at, shape, kerb_mm, kerb_boxes, pavements, marks[0], marks[1]]

## Writes every road piece to `st`, stretches in chunks with their markings and
## decals as custom data, and returns [crosswalks, decals]. Each stretch works
## in its own frame (Piece.span(): x along, y across), so markings run along
## its street at any angle; footprints go out as quads in XZ.
func _markings(st: SurfaceTool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed + 5
	var walks: Array[PackedVector2Array] = []
	var found := []
	var pieces := road_pieces(plan, layout)
	var chunk := 0
	for piece: Piece in pieces:
		var w := piece.width
		if piece.kind == 2:
			_polygon(st, piece.poly, ROAD_Y, piece.d, piece.n, piece.c, w, 2, [NONE, NONE, NONE, NONE])
			continue
		var r := piece.span()
		var al := 0
		var a0 := r.position.x
		var a1 := r.end.x
		var length := a1 - a0
		var half := w * 0.5
		# Lane heading +along (right-hand traffic), as an across offset's sign.
		var lane := piece.lane()
		var ends := [meets(pieces, piece, a0), meets(pieces, piece, a1)]
		var depth := minf(CROSSWALK_DEPTH, length * 0.5 - CROSSWALK_GAP)
		var keep_out: Array[Rect2] = []
		# Per end: along, direction (0 for none), index in found.
		var arrows := [Vector3.ZERO, Vector3.ZERO]
		for e in 2:
			if not ends[e] or depth < 1.0:
				ends[e] = false
				continue
			var near := a0 + CROSSWALK_GAP if e == 0 else a1 - CROSSWALK_GAP - depth
			var cw := _rect(r, al, near, near + depth, -half, half)
			walks.append(piece.area(cw))
			keep_out.append(cw)
			# An arrow in the lane approaching the crossing, pointing at it.
			var dir := -1.0 if e == 0 else 1.0
			var back := CROSSWALK_GAP + depth + ARROW_BACK + ARROW_LENGTH * 0.5
			if length >= 2.0 * (back + ARROW_LENGTH):
				var mid := a0 + back if e == 0 else a1 - back
				arrows[e] = Vector3(mid, dir, found.size())
				var across := lane * dir * w * 0.25
				var box := _rect(r, al, mid - ARROW_LENGTH * 0.5, mid + ARROW_LENGTH * 0.5, across - 0.6, across + 0.6)
				found.append([Mark.ARROW, piece.area(box), -1])
				keep_out.append(box)
		var flags := (1.0 if ends[0] else 0.0) + (2.0 if ends[1] else 0.0)
		var n := maxi(1, floori(length / chunk_length))
		for k in n:
			var c0 := a0 + length * k / n
			var c1 := a0 + length * (k + 1) / n
			var data := [Color(a0, a1, flags, lane), NONE, NONE, NONE]
			var marks := NONE
			for e in 2:
				if arrows[e].y != 0.0 and arrows[e].x > c0 and arrows[e].x < c1:
					marks.r = arrows[e].x
					marks.g = arrows[e].y
					found[int(arrows[e].z)][2] = chunk
			# A manhole in a lane, a drain at the kerb, and a patch, each by chance
			# and only where it misses the markings.
			var p := _place(rng, r, al, c0, c1, 0.45, MANHOLE_RADIUS, 0.0, half * 0.6, keep_out)
			if p.has_area():
				var centre := _local(r, al, p.get_center())
				data[1] = Color(centre.x, centre.y, MANHOLE_RADIUS, 1.0)
				found.append([Mark.MANHOLE, piece.area(p), chunk])
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var across := side * (half - DRAIN_SIZE.y * 0.5 - 0.05)
			var d := _place(rng, r, al, c0, c1, 0.6, DRAIN_SIZE.x * 0.5, across, 0.0, keep_out, DRAIN_SIZE.y * 0.5)
			if d.has_area():
				marks.b = _local(r, al, d.get_center()).x
				marks.a = side
				found.append([Mark.DRAIN, piece.area(d), chunk])
			var size := Vector2(rng.randf_range(1.0, 3.0), rng.randf_range(0.8, 2.0))
			var q := _place(rng, r, al, c0, c1, 0.4, size.x, 0.0, maxf(0.0, half - size.y - 0.6), [], size.y)
			if q.has_area():
				var centre := _local(r, al, q.get_center())
				data[2] = Color(centre.x, centre.y, size.x, size.y)
				found.append([Mark.PATCH, piece.area(q), chunk])
			data[3] = marks
			var part := r
			part.position.x = c0
			part.size.x = c1 - c0
			_polygon(st, piece.area(part), ROAD_Y, piece.d, piece.n, piece.c, w, piece.kind, data)
			chunk += 1
	return [walks, found]

## A decal footprint inside chunk [c0, c1] of piece `r`, by chance `odds`, at a
## random along and an across within `spread` of `across`; `half` and `half_w`
## are its half length and half width. Empty when it is skipped or every try
## hits a keep-out rect.
static func _place(rng: RandomNumberGenerator, r: Rect2, al: int, c0: float, c1: float, odds: float,
		half: float, across: float, spread: float, keep_out: Array, half_w := -1.0) -> Rect2:
	var hit := rng.randf() < odds
	if half_w < 0.0:
		half_w = half
	for t in 4:
		var along := rng.randf_range(c0 + half + 0.2, c1 - half - 0.2)
		var off := across + rng.randf_range(-spread, spread)
		var box := _rect(r, al, along - half, along + half, off - half_w, off + half_w)
		if hit and c1 - c0 > 2.0 * half + 0.4 and not keep_out.any(func(o): return o.intersects(box)):
			return box
	return Rect2()

## The rect spanning [a0, a1] along piece `r` and [x0, x1] across its centre.
static func _rect(r: Rect2, al: int, a0: float, a1: float, x0: float, x1: float) -> Rect2:
	var c := r.get_center()[1 - al]
	var out := Rect2()
	out.position[al] = a0
	out.size[al] = a1 - a0
	out.position[1 - al] = c + x0
	out.size[1 - al] = x1 - x0
	return out

## A point as (along, across from the piece's centre line), the road UV.
static func _local(r: Rect2, al: int, p: Vector2) -> Vector2:
	return Vector2(p[al], p[1 - al] - r.get_center()[1 - al])

## A kerb along each edge of a block outline, kerb_width deep inside it, as
## the Kerbs MultiMesh transform of a unit box: its x axis is whichever of the
## kerb's length and depth runs nearer world x, so a rect's kerbs are plain
## scaled boxes.
func _block_kerbs(b: PackedVector2Array) -> Array[Transform3D]:
	var k := kerb_width
	var out: Array[Transform3D] = []
	for e in edges(b, k):
		var dir: Vector2 = e[1]
		var inward: Vector2 = e[2]
		var s0: float = e[4]
		var length: float = e[3] - (s0 + e[5])
		if length <= 0.05:
			continue
		var from: Vector2 = e[0] + dir * s0
		var centre := from + dir * (length * 0.5) + inward * (k * 0.5)
		var across := canon(Vector2(-dir.y, dir.x))
		var x := Vector3(dir.x, 0.0, dir.y) * length
		var z := Vector3(across.x, 0.0, across.y) * k
		if absf(dir.x) < absf(dir.y):
			var t := x
			x = z
			z = t
		# An edge at 45° keeps its axes unswapped; keep the box unmirrored.
		if Basis(x, Vector3.UP, z).determinant() < 0.0:
			z = -z
		out.append(Transform3D(Basis(x + Vector3.ZERO, Vector3(0.0, kerb_height, 0.0), z + Vector3.ZERO),
			Vector3(centre.x, kerb_height * 0.5, centre.y)))
	return out

## [ground point, yaw toward the street] for each light along a block's edges.
func _block_lights(b: PackedVector2Array) -> Array:
	var out := []
	var i := light_inset
	for e in edges(b, kerb_width):
		var dir: Vector2 = e[1]
		var inward: Vector2 = e[2]
		var length: float = e[3]
		var start: Vector2 = e[0] + inward * i
		# Facing out of the block: the head hangs toward -z of its turn.
		var yaw := atan2(inward.x, inward.y) + 0.0
		if yaw <= -PI + 1e-9:
			yaw = PI
		var n := maxi(1, floori(length / light_spacing))
		for k in n:
			var p: Vector2 = start + dir * length * (k + 0.5) / n
			if p.length() < layout.core_radius and CityPlan.clear_of(layout, Rect2(p, Vector2.ZERO)):
				out.append([Vector3(p.x, 0.0, p.y), yaw])
	return out

func _multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	return mm

## `r` less every rect in `holes`, as rects that do not overlap; just `r` when
## no hole touches it. Slivers under 5 cm (float error at shared edges) are dropped.
static func cut(r: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for p in cut_polygon(CityPlan.polygon(r), holes):
		out.append(bounds(p))
	return out

## `poly` (convex, or split into convex parts first) less every rect in
## `holes`, as convex polygons that do not overlap. Each hole splits a piece it
## touches into the strips below and above it across the piece and the parts
## left and right of it between them, so a rect cuts into rects as before.
## Slivers under 5 cm are dropped.
static func cut_polygon(poly: PackedVector2Array, holes: Array[Rect2]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if poly.size() < 3:
		return out
	if convex(poly):
		out.append(poly)
	else:
		out.assign(Geometry2D.decompose_polygon_in_convex(poly))
	for h in holes:
		var next: Array[PackedVector2Array] = []
		for p in out:
			var i := bounds(p).intersection(h)
			if not i.has_area():
				next.append(p)
				continue
			var below := _half(p, Vector2(0, 1), i.position.y)
			var above := _half(p, Vector2(0, -1), -i.end.y)
			var band := _half(_half(p, Vector2(0, -1), -i.position.y), Vector2(0, 1), i.end.y)
			for piece in [below, above, _half(band, Vector2(1, 0), i.position.x), _half(band, Vector2(-1, 0), -i.end.x)]:
				if piece.size() >= 3:
					var r := bounds(piece)
					if r.size.x > 0.05 and r.size.y > 0.05 and absf(CityPlan.area(piece)) > 0.0025:
						next.append(piece)
		out = next
	return out

## The part of convex `poly` where p·n <= at. A cut along an axis puts its new
## corners exactly on the line.
static func _half(poly: PackedVector2Array, n: Vector2, at: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var da := a.dot(n) - at
		var db := b.dot(n) - at
		if da <= 0.0:
			out.append(a)
		if (da < 0.0 and db > 0.0) or (da > 0.0 and db < 0.0):
			var q := a + (b - a) * (da / (da - db))
			if n.x == 0.0:
				q.y = at * n.y
			elif n.y == 0.0:
				q.x = at * n.x
			out.append(q)
	return out

## A flat polygon at height y. UV: across the street from its centre line `c`
## (p·n - c) and along it (p·d), in metres; UV2: width and kind (3 for
## pavements), for the road shader; CUSTOM0 to 3: the stretch's markings and
## decals (see _markings). Corners start from the one nearest -x -z and wind as
## a rect's do, so a rect gives the same two triangles as before.
static func _polygon(st: SurfaceTool, poly: PackedVector2Array, y: float, d: Vector2, n: Vector2, c: float,
		width: float, kind: int, data := []) -> void:
	var ring := poly.duplicate()
	if CityPlan.area(ring) < 0.0:
		ring.reverse()
	var first := 0
	for i in ring.size():
		var s := ring[i].x + ring[i].y
		var best := ring[first].x + ring[first].y
		if s < best - 1e-9 or (absf(s - best) <= 1e-9 and ring[i].x < ring[first].x):
			first = i
	var order := PackedVector2Array()
	for i in ring.size():
		order.append(ring[(first + i) % ring.size()])
	var tris := PackedInt32Array([0, 1, 3, 1, 2, 3]) if order.size() == 4 else Geometry2D.triangulate_polygon(order)
	for idx in tris:
		var p := order[idx]
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(p.dot(n) - c, p.dot(d)))
		st.set_uv2(Vector2(width, kind))
		for ch in data.size():
			st.set_custom(ch, data[ch])
		st.add_vertex(Vector3(p.x, y, p.y))
