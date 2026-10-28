class_name Streets
extends StaticBody3D
# The street level of a CityPlan: an asphalt road mesh just above the ground
# (segments between crossings, plus the crossings), sidewalks on the blocks, and
# street lights along the kerbs. Lights are real obstacles, so each has a thin
# collision shape; nothing else here collides. Cached per layout, like City.

const ROAD_Y := 0.02
const SIDEWALK_Y := 0.04

@export var layout: CityLayout
@export var road_material: Material
@export var sidewalk_material: Material
@export var light_material: Material
## Metres between street lights along a kerb.
@export var light_spacing := 15.0
## How far in from the kerb a light stands.
@export var light_inset := 0.8
@export var pole_height := 6.0
@export var pole_radius := 0.12

## params -> [road mesh, sidewalk mesh, pole MultiMesh, head MultiMesh, lights, pole shape].
static var _cache := {}

var plan: CityPlan
## Where each light stands, on the ground.
var lights := PackedVector3Array()

func _ready() -> void:
	build()

func build() -> void:
	plan = CityPlan.build(layout)
	var key := layout.params() + [light_spacing, light_inset, pole_height, pole_radius]
	if not _cache.has(key):
		_cache[key] = _generate()
	var built: Array = _cache[key]
	_mesh("Road", built[0], road_material)
	_mesh("Sidewalks", built[1], sidewalk_material)
	for i in 2:
		var mm := MultiMeshInstance3D.new()
		mm.name = ["Poles", "Heads"][i]
		mm.multimesh = built[2 + i]
		mm.material_override = light_material
		add_child(mm)
	lights = built[4]
	for i in lights.size():
		var shape := CollisionShape3D.new()
		shape.name = "Light%d" % i
		shape.shape = built[5]
		shape.position = lights[i] + Vector3.UP * pole_height * 0.5
		add_child(shape)

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

func _mesh(n: String, m: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.material_override = mat
	add_child(mi)

func _generate() -> Array:
	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in road_pieces(plan, layout):
		_quad(road, piece[0], ROAD_Y, piece[1], piece[2], piece[3])
	var walk := SurfaceTool.new()
	walk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var found := []
	for b in plan.blocks:
		if CityPlan.inside(b, layout.core_radius):
			_quad(walk, b, SIDEWALK_Y, 0, 0.0, 2)
			found.append_array(_block_lights(b))
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
	return [road.commit(), walk.commit(), poles, heads, at, shape]

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
## along it, in metres; UV2: width and kind, for the road shader.
static func _quad(st: SurfaceTool, r: Rect2, y: float, across: int, width: float, kind: int) -> void:
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
		st.add_vertex(verts[idx][0])
