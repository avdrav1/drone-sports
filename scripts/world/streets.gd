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
## Each kerb's box, along a block edge; same order as the Kerbs MultiMesh.
var kerbs: Array[AABB] = []
## Each crosswalk's footprint in XZ.
var crosswalks: Array[Rect2] = []
## Each decal: [Mark kind, footprint in XZ, index of its road chunk].
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
	for boxes in [[kerbs, "Kerb"], [built[8], "Pavement"]]:
		var list: Array = boxes[0]
		for i in list.size():
			var box: AABB = list[i]
			var shape := BoxShape3D.new()
			shape.size = box.size
			_shape("%s%d" % [boxes[1], i], shape, box.get_center())

func _shape(n: String, s: Shape3D, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = n
	shape.shape = s
	shape.position = at
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

## Road pieces as XZ rects: [rect, across-axis (0 x, 1 z), width, kind]. Kind 0
## street, 1 avenue, 2 crossing. Together they cover every street exactly once.
static func road_pieces(p: CityPlan, l: CityLayout) -> Array:
	var out := []
	for i in p.streets.size():
		var s := p.streets[i]
		var along := 1 if i % 2 == 0 else 0 # streets at even indices run along z
		var width := s.size[1 - along]
		var kind := 1 if l.avenue_width > l.street_width and width > l.street_width + 0.01 else 0
		var cuts: Array[Vector2] = []
		for j in p.streets.size():
			if j % 2 == i % 2 or not s.intersects(p.streets[j]):
				continue
			# Near the core's edge a clipped street may stop partway across
			# another. Only a street that spans this one's width cuts it; the
			# shared square is a crossing only when each spans the other.
			var o := s.intersection(p.streets[j])
			if o.size[1 - along] < width - 0.001:
				continue
			cuts.append(Vector2(o.position[along], o.end[along]))
			if i % 2 == 0 and o.size[along] >= p.streets[j].size[along] - 0.001:
				out.append([o, 0, o.size.x, 2])
		cuts.sort_custom(func(a, b): return a.x < b.x)
		var at: float = s.position[along]
		for c in cuts + [Vector2(s.end[along], s.end[along])]:
			if c.x > at + 0.001:
				var r := s
				r.position[along] = at
				r.size[along] = c.x - at
				out.append([r, 1 - along, width, kind])
			at = maxf(at, c.y)
	return out

## True when another piece meets `piece`'s end at `along` (a crossing or a
## street it runs into).
static func meets(pieces: Array, piece: Array, along: float) -> bool:
	var al := 1 - int(piece[1])
	var edge: Rect2 = piece[0]
	edge.position[al] = along - 0.01
	edge.size[al] = 0.02
	for o in pieces:
		if o != piece and edge.intersects(o[0]):
			return true
	return false

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
	var kerb_boxes: Array[AABB] = []
	var pavements: Array[AABB] = []
	for b in plan.blocks:
		if CityPlan.inside(b, layout.core_radius):
			var inner := b.grow(-kerb_width)
			_quad(walk, inner, kerb_height, 0, 0.0, 3)
			pavements.append(AABB(Vector3(inner.position.x, 0.0, inner.position.y), Vector3(inner.size.x, kerb_height, inner.size.y)))
			kerb_boxes.append_array(_block_kerbs(b))
			found.append_array(_block_lights(b))
	var kerb_mm := _multimesh(BoxMesh.new(), kerb_boxes.size())
	for i in kerb_boxes.size():
		var k := kerb_boxes[i]
		kerb_mm.set_instance_transform(i, Transform3D(Basis.from_scale(k.size), k.get_center()))
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

## Writes every road piece to `st`, segments in chunks with their markings and
## decals as custom data, and returns [crosswalks, decals].
func _markings(st: SurfaceTool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed + 5
	var walks: Array[Rect2] = []
	var found := []
	var pieces := road_pieces(plan, layout)
	var chunk := 0
	for piece in pieces:
		var r: Rect2 = piece[0]
		var ac: int = piece[1]
		var al := 1 - ac
		var w: float = piece[2]
		if piece[3] == 2:
			_quad(st, r, ROAD_Y, ac, w, 2, [NONE, NONE, NONE, NONE])
			continue
		var a0 := r.position[al]
		var a1 := r.end[al]
		var length := a1 - a0
		var half := w * 0.5
		# Lane heading +along (right-hand traffic): -x for streets along z, +z
		# for streets along x, as an across offset's sign.
		var lane := -1.0 if ac == 0 else 1.0
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
			walks.append(cw)
			keep_out.append(cw)
			# An arrow in the lane approaching the crossing, pointing at it.
			var dir := -1.0 if e == 0 else 1.0
			var back := CROSSWALK_GAP + depth + ARROW_BACK + ARROW_LENGTH * 0.5
			if length >= 2.0 * (back + ARROW_LENGTH):
				var mid := a0 + back if e == 0 else a1 - back
				arrows[e] = Vector3(mid, dir, found.size())
				var across := lane * dir * w * 0.25
				var box := _rect(r, al, mid - ARROW_LENGTH * 0.5, mid + ARROW_LENGTH * 0.5, across - 0.6, across + 0.6)
				found.append([Mark.ARROW, box, -1])
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
				found.append([Mark.MANHOLE, p, chunk])
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var across := side * (half - DRAIN_SIZE.y * 0.5 - 0.05)
			var d := _place(rng, r, al, c0, c1, 0.6, DRAIN_SIZE.x * 0.5, across, 0.0, keep_out, DRAIN_SIZE.y * 0.5)
			if d.has_area():
				marks.b = _local(r, al, d.get_center()).x
				marks.a = side
				found.append([Mark.DRAIN, d, chunk])
			var size := Vector2(rng.randf_range(1.0, 3.0), rng.randf_range(0.8, 2.0))
			var q := _place(rng, r, al, c0, c1, 0.4, size.x, 0.0, maxf(0.0, half - size.y - 0.6), [], size.y)
			if q.has_area():
				var centre := _local(r, al, q.get_center())
				data[2] = Color(centre.x, centre.y, size.x, size.y)
				found.append([Mark.PATCH, q, chunk])
			data[3] = marks
			var part := r
			part.position[al] = c0
			part.size[al] = c1 - c0
			_quad(st, part, ROAD_Y, ac, w, piece[3], data)
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

## The XZ rect spanning [a0, a1] along piece `r` and [x0, x1] across its centre.
static func _rect(r: Rect2, al: int, a0: float, a1: float, x0: float, x1: float) -> Rect2:
	var c := r.get_center()[1 - al]
	var out := Rect2()
	out.position[al] = a0
	out.size[al] = a1 - a0
	out.position[1 - al] = c + x0
	out.size[1 - al] = x1 - x0
	return out

## A point in XZ as (along, across from the piece's centre line), the road UV.
static func _local(r: Rect2, al: int, p: Vector2) -> Vector2:
	return Vector2(p[al], p[1 - al] - r.get_center()[1 - al])

## The four kerbs of a block, each kerb_width deep inside its edge.
func _block_kerbs(b: Rect2) -> Array[AABB]:
	var k := kerb_width
	var out: Array[AABB] = []
	for z in [b.position.y, b.end.y - k]:
		out.append(AABB(Vector3(b.position.x, 0.0, z), Vector3(b.size.x, kerb_height, k)))
	for x in [b.position.x, b.end.x - k]:
		out.append(AABB(Vector3(x, 0.0, b.position.y + k), Vector3(k, kerb_height, b.size.y - 2.0 * k)))
	return out

## [ground point, yaw toward the street] for each light on a block's kerbs.
func _block_lights(b: Rect2) -> Array:
	var out := []
	var i := light_inset
	# Edge start, edge direction, yaw facing out of the block.
	var edges := [
		[Vector2(b.position.x, b.position.y + i), Vector2.RIGHT, 0.0],
		[Vector2(b.position.x, b.end.y - i), Vector2.RIGHT, PI],
		[Vector2(b.position.x + i, b.position.y), Vector2.DOWN, PI * 0.5],
		[Vector2(b.end.x - i, b.position.y), Vector2.DOWN, -PI * 0.5],
	]
	for e in edges:
		var length := b.size.x if e[1] == Vector2.RIGHT else b.size.y
		var n := maxi(1, floori(length / light_spacing))
		for k in n:
			var p: Vector2 = e[0] + e[1] * length * (k + 0.5) / n
			if p.length() < layout.core_radius and CityPlan.clear_of(layout, Rect2(p, Vector2.ZERO)):
				out.append([Vector3(p.x, 0.0, p.y), e[2]])
	return out

func _multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	return mm

## A flat quad over `r` at height y. UV: across the street from its centre and
## along it, in metres; UV2: width and kind (3 for pavements), for the road
## shader; CUSTOM0 to 3: the segment's markings and decals (see _markings).
static func _quad(st: SurfaceTool, r: Rect2, y: float, across: int, width: float, kind: int, data := []) -> void:
	var centre := r.get_center()
	var corners := [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]
	var verts := []
	for c in corners:
		var uv := Vector2(c.x - centre.x, c.y) if across == 0 else Vector2(c.y - centre.y, c.x)
		verts.append([Vector3(c.x, y, c.y), uv])
	for idx in [0, 1, 2, 1, 3, 2]:
		st.set_normal(Vector3.UP)
		st.set_uv(verts[idx][1])
		st.set_uv2(Vector2(width, kind))
		for ch in data.size():
			st.set_custom(ch, data[ch])
		st.add_vertex(verts[idx][0])
