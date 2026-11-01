class_name Rooftops
extends StaticBody3D
# Roof clutter and landing pads for a CityPlan. AC units, water tanks, and
# antennas draw through one MultiMesh each; anything taller than collide_above
# gets a collision box. Pads go on the broadest tall roofs, clear of clutter,
# each with a map marker. All seeded and cached per layout, like City. Everything
# sits on each lot's top box, clear of its plant room (Story 15.6). The Four's
# shrines (Story 30.8) stand on the roofs the plan picks for them, which keep
# no clutter on their clear square; pads keep the layout's shrine_clearance
# from them, so no landing target sits beside a shrine.

enum Kind { AC, TANK, ANTENNA }

@export var layout: CityLayout
@export var material: Material
@export var pad_material: Material
@export var pad_count := 4
@export var pad_radius := 3.0
## Roofs at least this tall (fraction of the layout's height range) can hold a pad.
@export var pad_min_height := 0.4
@export var collide_above := 1.0
## Pieces stay this far in from a roof's edge.
@export var edge_margin := 1.0
## The shrine built on each of the plan's shrine roofs, and the Four, in the
## plan's thread order.
@export var shrine_scene: PackedScene
@export var deities: DeityList

## params -> [pieces, pads, multimeshes, shapes].
static var _cache := {}

var plan: CityPlan
## Each piece: {kind, base (centre of its foot on the roof), size, lot}.
var pieces: Array = []
## Pad centres, on the roof.
var pads := PackedVector3Array()
## The shrines built, in thread order.
var shrines: Array[Shrine] = []

func _ready() -> void:
	build()

func build() -> void:
	plan = CityPlan.build(layout)
	var key := layout.params() + [pad_count, pad_radius, pad_min_height, collide_above, edge_margin]
	if not _cache.has(key):
		_cache[key] = _generate()
	var built: Array = _cache[key]
	pieces = built[0]
	pads = built[1]
	for k in Kind.size():
		var mm := MultiMeshInstance3D.new()
		mm.name = String(Kind.keys()[k]).capitalize()
		mm.multimesh = built[2][k]
		mm.material_override = material
		add_child(mm)
	for i in built[3].size():
		var shape := CollisionShape3D.new()
		shape.name = "Piece%d" % i
		shape.shape = built[3][i][0]
		shape.position = built[3][i][1]
		add_child(shape)
	for i in pads.size():
		var pad := MeshInstance3D.new()
		pad.name = "Pad%d" % i
		var disc := CylinderMesh.new()
		disc.top_radius = pad_radius
		disc.bottom_radius = pad_radius
		disc.height = 0.08
		pad.mesh = disc
		pad.material_override = pad_material
		pad.position = pads[i] + Vector3.UP * 0.04
		add_child(pad)
		var marker := MapMarker.new()
		marker.name = "Marker"
		marker.kind = &"pad"
		marker.icon = &"circle"
		marker.label = "Pad"
		pad.add_child(marker)
	shrines.clear()
	if shrine_scene and deities:
		for i in mini(plan.shrines.size(), deities.deities.size()):
			var shrine: Shrine = shrine_scene.instantiate()
			shrine.name = "Shrine%d" % i
			shrine.deity = deities.deities[i]
			shrine.position = plan.shrines[i]
			add_child(shrine)
			shrines.append(shrine)

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

static func _side(r: Rect2) -> float:
	return minf(r.size.x, r.size.y)

## True when a piece (centre p, half-extent r) stays clear of every pad.
func _clear_of_pads(p: Vector3, r: float, at: PackedVector3Array) -> bool:
	for c in at:
		if Vector2(p.x - c.x, p.z - c.z).length() < pad_radius + r + 0.5:
			return false
	return true

## True when lot i's roof is shrine_clearance from every shrine, so it may hold a pad.
func _off_shrines(i: int) -> bool:
	var c := plan.shapes[i].roof_clear.get_center()
	for s in plan.shrines:
		if c.distance_to(Vector2(s.x, s.z)) < layout.shrine_clearance:
			return false
	return true

## True when `foot` reaches a shrine's clear square.
func _on_shrine(foot: Rect2) -> bool:
	var side := layout.shrine_side
	for s in plan.shrines:
		if Rect2(s.x - side * 0.5, s.z - side * 0.5, side, side).intersects(foot):
			return true
	return false

func _generate() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed + 2
	# Pads: the broadest clear roofs among the tall ones.
	var tall := layout.height_min + (layout.height_max - layout.height_min) * pad_min_height
	var order := range(plan.lots.size()).filter(func(i):
		return _off_shrines(i) and plan.heights[i] >= tall and _side(plan.shapes[i].roof_clear) >= (pad_radius + edge_margin) * 2.0)
	order.sort_custom(func(a, b):
		var sa := _side(plan.shapes[a].roof_clear)
		var sb := _side(plan.shapes[b].roof_clear)
		return sa > sb if not is_equal_approx(sa, sb) else a < b)
	# Too few tall roofs (a low, spread-out free-flight city, Story 26.2): the
	# tallest broad roofs below the line make up the count.
	if order.size() < pad_count:
		var low := range(plan.lots.size()).filter(func(i):
			return _off_shrines(i) and plan.heights[i] < tall and _side(plan.shapes[i].roof_clear) >= (pad_radius + edge_margin) * 2.0)
		low.sort_custom(func(a, b): return plan.heights[a] > plan.heights[b] if plan.heights[a] != plan.heights[b] else a < b)
		order.append_array(low)
	var pad_at := PackedVector3Array()
	for i in order.slice(0, pad_count):
		var c := plan.shapes[i].roof_clear.get_center()
		pad_at.append(Vector3(c.x, plan.heights[i], c.y))
	var found: Array = []
	for i in plan.lots.size():
		var shape := plan.shapes[i]
		var top := shape.top()
		var h := plan.heights[i]
		var inner := Rect2(top.position.x, top.position.z, top.size.x, top.size.z).grow(-edge_margin)
		if inner.size.x <= 0.0 or inner.size.y <= 0.0:
			continue
		for n in rng.randi_range(1, 4):
			var kind: int = rng.randi() % Kind.size()
			var size: Vector3
			match kind:
				Kind.AC:
					size = Vector3(rng.randf_range(1.2, 2.0), rng.randf_range(0.7, 1.3), rng.randf_range(1.0, 1.6))
				Kind.TANK:
					var d := rng.randf_range(1.6, 2.6)
					size = Vector3(d, rng.randf_range(2.0, 3.2), d)
				_:
					size = Vector3(0.12, rng.randf_range(3.0, 7.0), 0.12)
			if size.x > inner.size.x or size.z > inner.size.y:
				continue
			var p := Vector3(rng.randf_range(inner.position.x + size.x * 0.5, inner.end.x - size.x * 0.5), h,
				rng.randf_range(inner.position.y + size.z * 0.5, inner.end.y - size.z * 0.5))
			var foot := Rect2(p.x - size.x * 0.5, p.z - size.z * 0.5, size.x, size.z)
			var free := _clear_of_pads(p, maxf(size.x, size.z) * 0.5, pad_at) and not _on_shrine(foot)
			for j in shape.trims.size():
				var t := shape.trims[j]
				if shape.trim_kinds[j] == CityPlan.Trim.PLANT \
						and Rect2(t.position.x, t.position.z, t.size.x, t.size.z).grow(0.3).intersects(foot):
					free = false
			for other in found:
				if other.lot == i and other.foot.grow(0.3).intersects(foot):
					free = false
			if free:
				found.append({"kind": kind, "base": p, "size": size, "lot": i, "foot": foot})
	# Unit meshes, scaled per piece: 1 m across and 1 m tall.
	var meshes := [BoxMesh.new(), CylinderMesh.new(), CylinderMesh.new()]
	for m in meshes.slice(1):
		m.height = 1.0
		m.top_radius = 0.5
		m.bottom_radius = 0.5
	var mms: Array[MultiMesh] = []
	for k in Kind.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[k]
		var mine := found.filter(func(f): return f.kind == k)
		mm.instance_count = mine.size()
		for j in mine.size():
			var f: Dictionary = mine[j]
			mm.set_instance_transform(j, Transform3D(Basis.from_scale(f.size), f.base + Vector3.UP * f.size.y * 0.5))
		mms.append(mm)
	var shapes := []
	for f in found:
		if f.size.y > collide_above:
			var box := BoxShape3D.new()
			box.size = f.size
			shapes.append([box, f.base + Vector3.UP * f.size.y * 0.5])
	return [found, pad_at, mms, shapes]
