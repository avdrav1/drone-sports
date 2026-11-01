class_name Fences
extends StaticBody3D
# Story 26.10: fences with holes. Chain-link fences on posts round some vacant
# lots, and along stretches of block edge with no building behind them (the
# yards odd-shaped blocks leave, the ground round squares and clearings' edges),
# placed from the layout's seed (its fence_* fields). Every run has holes a drone
# can fly through: a panel missing, a torn opening at drone height, or a bottom
# edge lifted off the ground. Collision is per panel, so a hole is a gap in the
# collision too: a solid panel is one box, a torn one the four strips round its
# opening, a lifted one the box above its gap, a missing one nothing; each post
# is one box. Panels draw through one MultiMesh with a see-through chain-link
# shader, posts through another. Sits under a Streets node after its Clutter and
# reads the plan, the lights, the clutter and its lanes; cached per layout, like
# StreetClutter.
#
# Fences keep out of lanes, crossings, clearings, the core's edge, buildings and
# whatever stands on the pavement, and stand on the ground: on the pavement's
# top along a block edge, on the sand inside a vacant lot. A hole is only made
# where the ground either side of it is clear far enough to fly through.

enum Hole { NONE, MISSING, TORN, LIFTED }

@export var panel_material: Material
@export var post_material: Material
## A post's side, and a panel's thickness.
@export var post_size := 0.08
@export var panel_thickness := 0.04

## A vacant lot's fence stands this far inside the lot.
const LOT_INSET := 0.25
## A block-edge fence stands this far behind the back of the pavement.
const EDGE_IN := 0.3
## Runs keep this far from where their edge turns.
const END_MARGIN := 0.5
## Clearance kept from buildings, street clutter, lights and other runs.
const KEEP := 0.4
## A hole needs this much clear ground either side of it.
const ROOM := 2.0
## A torn opening's rim (each side of it, within its panel) is at most this wide.
const RIM := 0.3

## key -> [runs, multimeshes, shapes].
static var _cache := {}

## One panel between two posts: `x0` and `x1` along its run (post centres),
## `hole` what kind of hole it is, `gap` the opening as a rect in the run's
## frame (x along, y up from the run's base; empty for none), and `boxes` its
## solid parts in the same frame.
class Bay extends RefCounted:
	var x0 := 0.0
	var x1 := 0.0
	var hole := Hole.NONE
	var gap := Rect2()
	var boxes: Array[Rect2] = []

## A straight run of panels from `a` along unit `d`, `n` its normal (into the
## lot or block), standing on ground at height `base`, `height` tall. `vacant`
## the vacant lot it rounds (-1 along a block edge).
class Run extends RefCounted:
	var a := Vector2.ZERO
	var d := Vector2.ZERO
	var n := Vector2.ZERO
	var base := 0.0
	var height := 0.0
	var length := 0.0
	var vacant := -1
	var panels: Array[Bay] = []

	func world(x: float, y := 0.0) -> Vector3:
		var p := a + d * x
		return Vector3(p.x, base + y, p.y)

	## The ground strip `x0` to `x1` along the run, `half` either side of it.
	func strip(x0: float, x1: float, half: float) -> PackedVector2Array:
		var p0 := a + d * x0
		var p1 := a + d * x1
		return PackedVector2Array([p0 - n * half, p1 - n * half, p1 + n * half, p0 + n * half])

	## A box in the run's frame (x along, y up from base), `thick` deep: [size, transform].
	func box(r: Rect2, thick: float) -> Array:
		var x := Vector3(d.x, 0.0, d.y)
		var basis := Basis(x, Vector3.UP, x.cross(Vector3.UP))
		return [Vector3(r.size.x, r.size.y, thick), Transform3D(basis, world(r.get_center().x, r.get_center().y))]

	## Every post's position along the run.
	func posts() -> PackedFloat32Array:
		var out := PackedFloat32Array()
		for p in panels:
			out.append(p.x0)
		if not panels.is_empty():
			out.append(panels[panels.size() - 1].x1)
		return out

var streets: Streets
var clutter: StreetClutter
var plan: CityPlan
var layout: CityLayout
var runs: Array[Run] = []

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
	var key := layout.params() + [layout.fence_vacant_chance, layout.fence_edge_chance, layout.fence_height,
		layout.fence_panel, layout.fence_hole, layout.fence_hole_chance, post_size, panel_thickness,
		streets.kerb_height, streets.kerb_width, streets.light_spacing, streets.light_inset, clutter.pieces.size()]
	if not _cache.has(key):
		_cache[key] = _generate()
	var built: Array = _cache[key]
	runs.assign(built[0])
	for k in 2:
		var mm := MultiMeshInstance3D.new()
		mm.name = ["Panels", "Posts"][k]
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

## Every hole in every run, as [run, panel].
func holes() -> Array:
	var out := []
	for r in runs:
		for p in r.panels:
			if p.hole != Hole.NONE:
				out.append([r, p])
	return out

func _generate() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed + 53
	# What a fence keeps off: [bounds, outline] pairs, each grown by KEEP.
	var solid := []
	for lot in plan.lots:
		solid.append(_keep(CityPlan.polygon(lot.grow(KEEP))))
	for f in clutter.pieces:
		solid.append(_keep(CityPlan.polygon(Rect2(f.box.position.x, f.box.position.z, f.box.size.x, f.box.size.z).grow(KEEP))))
	for p in streets.lights:
		var r := streets.pole_radius + KEEP
		solid.append(_keep(CityPlan.polygon(Rect2(p.x - r, p.z - r, r * 2.0, r * 2.0))))
	var road := []
	for poly in clutter.lanes + clutter.parking + streets.crosswalks:
		for grown in Geometry2D.offset_polygon(poly, KEEP):
			road.append(_keep(grown))
	var corridors := []
	var found: Array[Run] = []
	# Vacant lots, each side a run on the sand.
	for v in plan.vacant.size():
		var take := rng.randf() < layout.fence_vacant_chance
		var r := plan.vacant[v].grow(-LOT_INSET)
		var corners := CityPlan.polygon(r)
		if not take or not CityPlan.inside(r, layout.core_radius - KEEP) or not CityPlan.clear_of(layout, r.grow(KEEP)):
			continue
		# The lot's own outline is open ground for its fence.
		for k in 4:
			var a := corners[k]
			var b := corners[(k + 1) % 4]
			var inward := (r.get_center() - (a + b) * 0.5).normalized()
			if absf(inward.x) > 1e-6 and absf(inward.y) > 1e-6:
				inward = Vector2(-(b - a).y, (b - a).x).normalized()
			for span in _free(a, b, solid + road, 0.0):
				_run(rng, a, (b - a).normalized(), inward, span, 0.0, v, solid, road, corridors, found)
	# Block edges with nothing behind them, on the pavement.
	var vacant := []
	for v in plan.vacant:
		vacant.append(_keep(CityPlan.polygon(v.grow(KEEP))))
	for b in plan.block_polygons:
		# A block the core's edge cuts has no pavement: its fences stand on the sand.
		var base := streets.kerb_height if Streets.within(b, layout.core_radius) else 0.0
		for line in Geometry2D.offset_polygon(b, -(layout.sidewalk + EDGE_IN), Geometry2D.JOIN_MITER):
			var turn := 1.0 if CityPlan.area(line) > 0.0 else -1.0
			var count := line.size()
			for k in count:
				var a := line[k]
				var e := line[(k + 1) % count]
				if a.distance_to(e) < layout.fence_panel * 2.0:
					continue
				var d := (e - a).normalized()
				var inward := Vector2(-d.y, d.x) * turn
				var spans := _free(a, e, solid + road + vacant, END_MARGIN)
				for span in spans:
					var take := rng.randf() < layout.fence_edge_chance
					if take:
						_run(rng, a, d, inward, span, base, -1, solid, road, corridors, found)
	var mms := []
	for k in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh(k)
		mms.append(mm)
	var panel_xf := []
	var post_xf := []
	var shapes := []
	var seen := {}
	for r in found:
		for x in r.posts():
			var at := (r.a + r.d * x).snapped(Vector2.ONE * 0.01)
			if seen.has(at):
				continue
			seen[at] = true
			var post: Array = r.box(Rect2(x - post_size * 0.5, 0.0, post_size, r.height + 0.05), post_size)
			post_xf.append(Transform3D(post[1].basis.scaled_local(post[0]), post[1].origin))
			shapes.append(post)
		for p in r.panels:
			for b in p.boxes:
				var part: Array = r.box(b, panel_thickness)
				panel_xf.append(Transform3D(part[1].basis.scaled_local(part[0]), part[1].origin))
				shapes.append(part)
	for k in 2:
		var xforms: Array = [panel_xf, post_xf][k]
		mms[k].instance_count = xforms.size()
		for j in xforms.size():
			mms[k].set_instance_transform(j, xforms[j])
	return [found, mms, shapes]

## [bounds, outline] of an outline.
static func _keep(poly: PackedVector2Array) -> Array:
	return [Streets.bounds(poly), poly]

## The stretches from `a` to `b` (as [from, to] along it, at least two panels
## long, `margin` in from each end) that keep clear of every outline in
## `blocks`, of every clearing and of the core's edge.
func _free(a: Vector2, b: Vector2, blocks: Array, margin: float) -> Array[Vector2]:
	var length := a.distance_to(b)
	var d := (b - a) / length
	var cut: Array[Vector2] = []
	var line := Rect2(a, Vector2.ZERO).expand(b)
	for o in blocks:
		if not (o[0] as Rect2).intersects(line, true):
			continue
		for bit in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), o[1]):
			var t0 := (bit[0] - a).dot(d)
			var t1 := (bit[bit.size() - 1] - a).dot(d)
			cut.append(Vector2(minf(t0, t1), maxf(t0, t1)))
	for c in layout.clearings:
		_circle(a, d, Vector2(c.x, c.y), c.z + KEEP, cut, false)
	_circle(a, d, Vector2.ZERO, layout.core_radius - KEEP, cut, true)
	cut.sort_custom(func(x, y): return x.x < y.x)
	var out: Array[Vector2] = []
	var t := margin
	for c in cut:
		if c.x > t and c.x - t >= layout.fence_panel * 2.0:
			out.append(Vector2(t, minf(c.x, length - margin)))
		t = maxf(t, c.y)
	if length - margin - t >= layout.fence_panel * 2.0:
		out.append(Vector2(t, length - margin))
	return out.filter(func(s): return s.y - s.x >= layout.fence_panel * 2.0)

## Adds to `cut` where the line from `a` along `d` runs inside the circle (or,
## with `outside`, outside it).
static func _circle(a: Vector2, d: Vector2, c: Vector2, radius: float, cut: Array[Vector2], outside: bool) -> void:
	var f := a - c
	var bq := f.dot(d)
	var disc := bq * bq - (f.length_squared() - radius * radius)
	if disc <= 0.0:
		if outside:
			cut.append(Vector2(-INF, INF))
		return
	var s := sqrt(disc)
	if outside:
		cut.append(Vector2(-INF, -bq - s))
		cut.append(Vector2(-bq + s, INF))
	else:
		cut.append(Vector2(-bq - s, -bq + s))

## Builds a run over `span` (along `d` from `a`) and adds it to `found` when it
## keeps off every run there and at least one of its holes can be flown through.
func _run(rng: RandomNumberGenerator, a: Vector2, d: Vector2, n: Vector2, span: Vector2, base: float, vacant: int,
		solid: Array, road: Array, corridors: Array, found: Array[Run]) -> void:
	var count := floori((span.y - span.x) / layout.fence_panel)
	var w := (span.y - span.x) / count
	var r := Run.new()
	r.a = a + d * span.x
	r.d = d
	r.n = n
	r.base = base
	r.height = layout.fence_height
	r.length = span.y - span.x
	r.vacant = vacant
	# Draws for every panel, so one panel's fit never shifts the next one's.
	var kinds := []
	for k in count:
		kinds.append([rng.randf() < layout.fence_hole_chance, rng.randi_range(Hole.MISSING, Hole.LIFTED),
			rng.randf(), rng.randf()])
	var first := rng.randi_range(0, count - 1)
	var whole := r.strip(0.0, r.length, KEEP)
	var whole_box := Streets.bounds(whole)
	for o in found:
		if o.vacant >= 0 and o.vacant == vacant:
			continue
		if Streets.overlaps(whole, o.strip(0.0, o.length, KEEP)):
			return
	# Another hole's flying room stays clear of this run's panels and posts.
	whole = r.strip(0.0, r.length, post_size)
	for c in corridors:
		if (c[0] as Rect2).intersects(whole_box) and Streets.overlaps(whole, c[1]):
			return
	var flyable: Array[bool] = []
	for k in count:
		var lane := _room(r, k * w, (k + 1) * w)
		var ok := true
		for o in solid + road:
			if (o[0] as Rect2).intersects(Streets.bounds(lane)) and Streets.overlaps(lane, o[1]):
				ok = false
				break
		for o in found:
			ok = ok and not Streets.overlaps(lane, o.strip(0.0, o.length, post_size))
		flyable.append(ok)
	var chosen := []
	for k in count:
		chosen.append(kinds[k][0] and flyable[k])
	if not chosen.has(true):
		for j in count:
			var k := (first + j) % count
			if flyable[k]:
				chosen[k] = true
				break
	if not chosen.has(true):
		return
	var h := layout.fence_height
	var hole_size := layout.fence_hole
	for k in count:
		var p := Bay.new()
		p.x0 = k * w
		p.x1 = (k + 1) * w
		var inner := Rect2(p.x0 + post_size * 0.5, 0.0, w - post_size, h)
		var kind: int = kinds[k][1] if chosen[k] else Hole.NONE
		# A torn opening needs room for its rim; a panel too narrow is left missing.
		if kind == Hole.TORN and inner.size.x - hole_size.x < 0.1:
			kind = Hole.MISSING
		p.hole = kind
		match kind:
			Hole.NONE:
				p.boxes.append(inner)
			Hole.MISSING:
				p.gap = inner
			Hole.TORN:
				var rim := minf(RIM, (inner.size.x - hole_size.x) * 0.5)
				var y0 := lerpf(0.4, h - hole_size.y - 0.4, kinds[k][2])
				p.gap = Rect2(inner.position.x + rim, y0, inner.size.x - rim * 2.0, hole_size.y)
				p.boxes.append(Rect2(inner.position.x, 0.0, rim, h))
				p.boxes.append(Rect2(p.gap.end.x, 0.0, rim, h))
				p.boxes.append(Rect2(p.gap.position.x, 0.0, p.gap.size.x, y0))
				p.boxes.append(Rect2(p.gap.position.x, p.gap.end.y, p.gap.size.x, h - p.gap.end.y))
			Hole.LIFTED:
				var lift := lerpf(hole_size.y, minf(hole_size.y + 0.4, h - 0.8), kinds[k][3])
				p.gap = Rect2(inner.position.x, 0.0, inner.size.x, lift)
				p.boxes.append(Rect2(inner.position.x, lift, inner.size.x, h - lift))
		r.panels.append(p)
		if chosen[k]:
			var lane := _room(r, p.x0, p.x1)
			corridors.append([Streets.bounds(lane), lane])
	found.append(r)

## The ground a hole between posts at `x0` and `x1` needs clear to fly
## through: ROOM either side of the run, a little in from each post.
func _room(r: Run, x0: float, x1: float) -> PackedVector2Array:
	return r.strip(x0 + post_size + 0.3, x1 - post_size - 0.3, ROOM)

func _mesh(kind: int) -> Mesh:
	var box := BoxMesh.new()
	box.material = panel_material if kind == 0 else post_material
	return box
