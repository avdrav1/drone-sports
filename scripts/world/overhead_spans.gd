class_name OverheadSpans
extends StaticBody3D
# Story 26.9: ducts and pipes overhead. Spans cross streets wall to wall
# between two facing buildings that both stand taller than them, square to the
# street at whatever angle it runs: single ducts, and racks of two or three
# pipes stacked with a drone-sized gap between. Placed from the layout's seed
# (its span_* fields), drawn through one MultiMesh per model, and each duct or
# pipe collides with one box, so a rack's gaps are real gaps. Sits under a
# Streets node after its Clutter and reads the plan, the street lights, and the
# clutter; cached per layout, like StreetClutter.
#
# A span's underside is never below a light's head or the tallest street
# clutter where it crosses (a tree on another street does not hold it up), and
# stands at least `span_gap` over anything beneath it; every span keeps
# `span_gap` off every other. Its ends sink `EMBED` into the walls they meet,
# and between them it touches no building, trim, lot, or wall clutter.

enum Kind { DUCT, PIPE }

@export var duct_material: Material
@export var pipe_material: Material
## A duct's cross-section: width along the street, and height.
@export var duct_size := Vector2(1.2, 0.8)
@export var pipe_diameter := 0.35

## How far each end sinks into its wall past the face's deepest point.
const EMBED := 0.15
## Slots keep this far from a stretch's ends (crossings and joints are there).
const END_MARGIN := 4.0
## A wall more than this far past the kerb is not facing the street.
const REACH := 6.0

## key -> [spans, multimeshes, shapes].
static var _cache := {}

## One span: `at` its centre on the street's centreline, `axis` its direction
## across the street and `along` the street's, `from` and `to` how far its ends
## lie along `axis` from `at` (from < 0 < to, each sunk EMBED past its wall),
## `near` the distances along `axis` where it first meets each wall ([-x, +y]),
## `width` across it, `parts` each duct or pipe as (bottom, top), `clear` the
## height of its underside, `lots` the two lots whose walls it meets, and
## `boxes` the index into each lot's shape boxes.
class Span extends RefCounted:
	var kind := Kind.DUCT
	var at := Vector2.ZERO
	var axis := Vector2.ZERO
	var along := Vector2.ZERO
	var from := 0.0
	var to := 0.0
	var near := Vector2.ZERO
	var width := 0.0
	var parts: Array[Vector2] = []
	var clear := 0.0
	var street := -1
	var lots := PackedInt32Array()
	var boxes := PackedInt32Array()

	## The span's footprint in XZ from `a` to `b` along its axis.
	func footprint(a: float, b: float) -> PackedVector2Array:
		var h := along * width * 0.5
		return PackedVector2Array([at + axis * a - h, at + axis * b - h, at + axis * b + h, at + axis * a + h])

	func top() -> float:
		return parts[parts.size() - 1].y

	## Part `k`'s box: [size, transform] (x along the axis, z along the street).
	func box(k: int) -> Array:
		var p := parts[k]
		var x := Vector3(axis.x, 0.0, axis.y)
		var basis := Basis(x, Vector3.UP, x.cross(Vector3.UP))
		var c := at + axis * (from + to) * 0.5
		return [Vector3(to - from, p.y - p.x, width), Transform3D(basis, Vector3(c.x, (p.x + p.y) * 0.5, c.y))]

	## World bounds of every part.
	func bounds() -> AABB:
		var r := Streets.bounds(footprint(from, to))
		return AABB(Vector3(r.position.x, clear, r.position.y), Vector3(r.size.x, top() - clear, r.size.y))

var streets: Streets
var clutter: StreetClutter
var plan: CityPlan
var layout: CityLayout
var spans: Array[Span] = []

func _ready() -> void:
	streets = get_parent() as Streets
	if streets == null:
		return
	if not streets.is_node_ready():
		# Clutter, an earlier sibling, waits on the same signal, so it builds first.
		await streets.ready
	build()

func build() -> void:
	clutter = streets.get_node("Clutter") as StreetClutter
	plan = streets.plan
	layout = streets.layout
	var key := layout.params() + [layout.span_spacing, layout.span_chance, layout.span_lane_chance,
		layout.span_max_width, layout.span_clear, layout.span_gap, layout.rack_chance, duct_size, pipe_diameter,
		streets.pole_height, streets.light_spacing, streets.light_inset, clutter.pieces.size()]
	if not _cache.has(key):
		_cache[key] = _generate()
	var built: Array = _cache[key]
	spans.assign(built[0])
	for k in Kind.size():
		var mm := MultiMeshInstance3D.new()
		mm.name = String(Kind.keys()[k]).capitalize() + "s"
		mm.multimesh = built[1][k]
		add_child(mm)
	for i in built[2].size():
		var shape := BoxShape3D.new()
		shape.size = built[2][i][0]
		var cs := CollisionShape3D.new()
		cs.name = "Part%d" % i
		cs.shape = shape
		cs.transform = built[2][i][1]
		add_child(cs)

## Frees what build() made, so the node can build again from a new layout.
func clear() -> void:
	for c in get_children():
		if c.owner == null:
			remove_child(c)
			c.queue_free()

## Drops cached builds of every layout but `keep`.
static func prune(keep: CityLayout) -> void:
	keep.prune(_cache)

## The lowest a span's underside may be where it crosses the street, over
## `area` (XZ): never below a street light's head, and a gap over the tallest
## street clutter or light head standing within it. A tree on another street
## does not hold a lane's spans up.
func floor_height(area: Rect2) -> float:
	var out := streets.pole_height + 0.06
	for f in clutter.pieces:
		if f.lot < 0 and Rect2(f.box.position.x, f.box.position.z, f.box.size.x, f.box.size.z).intersects(area):
			out = maxf(out, f.box.end.y + layout.span_gap)
	for p in streets.lights:
		if Rect2(p.x - 0.9, p.z - 0.9, 1.8, 1.8).intersects(area):
			out = maxf(out, streets.pole_height + 0.06 + layout.span_gap)
	return out

func _generate() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed + 41
	# What stands beneath a span: street clutter and light heads, as XZ rects and tops.
	var beneath := []
	for f in clutter.pieces:
		if f.lot < 0:
			beneath.append([Rect2(f.box.position.x, f.box.position.z, f.box.size.x, f.box.size.z), f.box.end.y])
	for p in streets.lights:
		beneath.append([Rect2(p.x - 0.9, p.z - 0.9, 1.8, 1.8), streets.pole_height + 0.06])
	var walls: Array[AABB] = []
	for f in clutter.pieces:
		if f.lot >= 0:
			walls.append(f.box)
	var found: Array[Span] = []
	for piece: Streets.Piece in Streets.road_pieces(plan, layout):
		if piece.kind == 2 or piece.width > layout.span_max_width + 1e-3:
			continue
		var chance := layout.span_lane_chance if piece.width < layout.street_width - 1e-3 else layout.span_chance
		var t := piece.a0 + END_MARGIN + rng.randf() * layout.span_spacing
		while t <= piece.a1 - END_MARGIN:
			var take := rng.randf() < chance
			var rack := rng.randf() < layout.rack_chance
			var pipes := rng.randi_range(2, 3)
			var u := rng.randf()
			var gaps: Array[float] = [rng.randf_range(0.0, 0.6), rng.randf_range(0.0, 0.6)]
			if take:
				var at := piece.world(Vector2(t, piece.c))
				var reach := piece.width * 0.5 + layout.sidewalk + REACH
				# The floor is what stands on this street across the slot: within a
				# gap of the widest, longest span it could hold.
				var across := Streets.bounds(piece.area(Rect2(t - duct_size.x * 0.5, piece.c - reach - 1.0,
					duct_size.x, (reach + 1.0) * 2.0))).grow(layout.span_gap)
				var low := maxf(layout.span_clear.x, floor_height(across))
				var high := maxf(low, layout.span_clear.y)
				# The underside goes no higher than lets the lower facing wall stand
				# over the top; a rack too tall for it loses pipes, then is a duct.
				var wall := _wall_top(at, piece.n, low, reach)
				for n in ([pipes, 2, 1] if rack else [1]):
					var offsets: Array[Vector2] = []
					if n == 1:
						offsets.append(Vector2(0.0, duct_size.y))
					else:
						var y := 0.0
						for k in n:
							offsets.append(Vector2(y, y + pipe_diameter))
							y += pipe_diameter + layout.span_gap + gaps[mini(k, 1)]
					var cap := minf(high, wall - offsets[offsets.size() - 1].y - 0.5)
					if cap < low:
						continue
					var s := Span.new()
					s.kind = Kind.DUCT if n == 1 else Kind.PIPE
					s.at = at
					s.along = piece.d
					s.axis = piece.n
					s.street = piece.street
					s.clear = lerpf(low, cap, u)
					s.width = duct_size.x if n == 1 else pipe_diameter
					for o in offsets:
						s.parts.append(o + Vector2.ONE * s.clear)
					if _place(s, piece, beneath, walls, found):
						found.append(s)
					break
			t += layout.span_spacing
	var mms := []
	var shapes := []
	for k in Kind.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh(k)
		var xforms := []
		for s in found:
			if s.kind == k:
				for j in s.parts.size():
					var b: Array = s.box(j)
					var xf: Transform3D = b[1]
					var size: Vector3 = b[0]
					if k == Kind.PIPE:
						# The unit cylinder stands along y: lay it along the span's axis.
						xform_pipe(xforms, xf, size)
					else:
						xforms.append(Transform3D(xf.basis.scaled_local(size), xf.origin))
		mm.instance_count = xforms.size()
		for j in xforms.size():
			mm.set_instance_transform(j, xforms[j])
		mms.append(mm)
	for s in found:
		for j in s.parts.size():
			shapes.append(s.box(j))
	return [found, mms, shapes]

## The top of the lower of the two walls a ray from `at` along `axis`, either
## way, first meets at height `y` within `reach`; -INF when either way meets none.
func _wall_top(at: Vector2, axis: Vector2, y: float, reach: float) -> float:
	var out := INF
	for side: float in [-1.0, 1.0]:
		var best := INF
		var top := -INF
		for i in plan.lots.size():
			if not plan.lots[i].grow(reach).has_point(at):
				continue
			for b in plan.shapes[i].boxes:
				if b.position.y <= y and b.end.y > y:
					var e := _ray_rect(at, axis * side, Rect2(b.position.x, b.position.z, b.size.x, b.size.z))
					if e.x < best:
						best = e.x
						top = b.end.y
		if best > reach:
			return -INF
		out = minf(out, top)
	return out

static func xform_pipe(out: Array, xf: Transform3D, size: Vector3) -> void:
	var b := Basis(xf.basis.y, -xf.basis.x, xf.basis.z)
	out.append(Transform3D(b.scaled_local(Vector3(size.y, size.x, size.z)), xf.origin))

## Finds span `s`'s walls along its axis and checks it fits: both ends on one
## stacked box of a lot facing the street that stands taller than it, nothing
## else in its way, clear of what stands beneath and of every span `found`.
func _place(s: Span, piece: Streets.Piece, beneath: Array, walls: Array[AABB], found: Array[Span]) -> bool:
	var y0 := s.clear
	var y1 := s.top()
	var reach := piece.width * 0.5 + layout.sidewalk + REACH
	var near_lots := []
	var zone := Rect2(s.at, Vector2.ZERO).grow(reach + 3.0)
	for i in plan.lots.size():
		if plan.lots[i].intersects(zone):
			near_lots.append(i)
	var ends := []
	for side: float in [-1.0, 1.0]:
		var dir := s.axis * side
		var lot := -1
		var box := -1
		var lo := INF
		var hi := -INF
		var out := INF
		for off: float in [-0.5, 0.0, 0.5]:
			var o := s.at + s.along * s.width * off
			var best := INF
			var hit := Vector2i(-1, -1)
			var leave := INF
			for i in near_lots:
				var bs := plan.shapes[i].boxes
				for j in bs.size():
					var b := bs[j]
					if b.end.y <= y0 or b.position.y >= y1:
						continue
					var e := _ray_rect(o, dir, Rect2(b.position.x, b.position.z, b.size.x, b.size.z))
					if e.x < best:
						best = e.x
						hit = Vector2i(i, j)
						leave = e.y
			if hit.x < 0 or best > reach or (lot >= 0 and hit != Vector2i(lot, box)):
				return false
			lot = hit.x
			box = hit.y
			lo = minf(lo, best)
			hi = maxf(hi, best)
			out = minf(out, leave)
		var b := plan.shapes[lot].boxes[box]
		# The box holds the whole span's height, with room above it.
		if b.position.y > y0 + 1e-3 or b.end.y < y1 + 0.5 or hi - lo > 1.5 or hi + EMBED > out - 0.1:
			return false
		ends.append([lot, box, lo, hi + EMBED])
	if ends[0][0] == ends[1][0]:
		return false
	s.lots = PackedInt32Array([ends[0][0], ends[1][0]])
	s.boxes = PackedInt32Array([ends[0][1], ends[1][1]])
	s.near = Vector2(-ends[0][2], ends[1][2])
	s.from = -ends[0][3]
	s.to = ends[1][3]
	if (s.at + s.axis * s.from).length() > layout.core_radius or (s.at + s.axis * s.to).length() > layout.core_radius:
		return false
	var inner := s.footprint(s.near.x + 0.02, s.near.y - 0.02)
	# Anything under the span, near it, stands a gap below its underside.
	var wide := Streets.bounds(s.footprint(s.from, s.to)).grow(layout.span_gap)
	var whole := s.footprint(s.from, s.to)
	for i in near_lots:
		if i != s.lots[0] and i != s.lots[1] and Streets.overlaps(whole, CityPlan.polygon(plan.lots[i])):
			return false
		var shape := plan.shapes[i]
		var solid: Array[AABB] = []
		for j in shape.boxes.size():
			if not (i == s.lots[0] and j == s.boxes[0]) and not (i == s.lots[1] and j == s.boxes[1]):
				solid.append(shape.boxes[j])
		solid.append_array(shape.trims)
		for b in solid:
			if _meets(whole, y0, y1, b) or _under(wide, y0, b):
				return false
		for j in shape.boxes.size():
			if _meets(inner, y0, y1, shape.boxes[j]):
				return false
	for w in walls:
		if _meets(whole, y0, y1, w) or _under(wide, y0, w):
			return false
	for b in beneath:
		if (b[0] as Rect2).intersects(wide) and b[1] + layout.span_gap > y0:
			return false
	var room := s.bounds().grow(layout.span_gap)
	for o in found:
		if o.bounds().intersects(room):
			return false
	return true

## True when box `b` stands under `wide` (XZ) and less than a gap below y0.
func _under(wide: Rect2, y0: float, b: AABB) -> bool:
	return b.end.y <= y0 and b.end.y + layout.span_gap > y0 \
		and Rect2(b.position.x, b.position.z, b.size.x, b.size.z).intersects(wide)

## True when the footprint `poly` from y0 to y1 shares space with box `b`.
static func _meets(poly: PackedVector2Array, y0: float, y1: float, b: AABB) -> bool:
	if b.end.y <= y0 or b.position.y >= y1:
		return false
	return Streets.overlaps(poly, CityPlan.polygon(Rect2(b.position.x, b.position.z, b.size.x, b.size.z)))

## Where a ray from `o` along unit `dir` enters and leaves rect `r`, as
## (enter, leave); (INF, INF) when it misses or starts inside.
static func _ray_rect(o: Vector2, dir: Vector2, r: Rect2) -> Vector2:
	var t0 := -INF
	var t1 := INF
	for a in 2:
		if absf(dir[a]) < 1e-9:
			if o[a] < r.position[a] or o[a] > r.end[a]:
				return Vector2(INF, INF)
			continue
		var ta := (r.position[a] - o[a]) / dir[a]
		var tb := (r.end[a] - o[a]) / dir[a]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	if t1 < t0 or t0 <= 0.0:
		return Vector2(INF, INF)
	return Vector2(t0, t1)

func _mesh(kind: int) -> Mesh:
	if kind == Kind.DUCT:
		var box := BoxMesh.new()
		box.material = duct_material
		return box
	var pipe := CylinderMesh.new()
	pipe.top_radius = 0.5
	pipe.bottom_radius = 0.5
	pipe.height = 1.0
	pipe.radial_segments = 10
	pipe.rings = 1
	pipe.material = pipe_material
	return pipe
