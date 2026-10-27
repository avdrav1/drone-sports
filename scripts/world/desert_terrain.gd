class_name DesertTerrain
extends StaticBody3D
# Sand flats, dunes, and a ring of rocky ridges, generated from a seeded noise at load.
# Inside flat_radius the ground is exactly y = 0, so jobs keep their geometry.
# Built meshes and shapes are cached per parameter set: scenes reload cheaply.

@export var noise_seed := 1
## Side of the square terrain, m.
@export var size := 2400.0
## Grid cells per side.
@export var cells := 300
@export var flat_radius := 150.0
## Dunes rise over this distance past the flat area, m.
@export var dune_blend := 120.0
@export var dune_height := 10.0
## Ridges start rising at this radius, m.
@export var ridge_start := 330.0
@export var ridge_height := 150.0
@export var material: Material

static var _cache := {}

var _dunes := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()

func _ready() -> void:
	build()

func step() -> float:
	return size / cells

## Ground height at a world XZ point (terrain at the origin).
func height_at(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	# One and a half cells of margin keep the triangles at the edge flat too.
	var flat_edge := flat_radius + step() * 1.5
	if r <= flat_edge:
		return 0.0
	var dune := (_dunes.get_noise_2d(x, z) * 0.5 + 0.5) * dune_height
	dune *= smoothstep(flat_edge, flat_edge + dune_blend, r)
	# A slow mask varies ridge height so the skyline isn't a uniform saw.
	var mask := _dunes.get_noise_2d(x * 0.08, z * 0.08) * 0.5 + 0.5
	var ridge := pow(_ridges.get_noise_2d(x, z) * 0.5 + 0.5, 1.6) * ridge_height * (0.35 + mask)
	ridge *= smoothstep(ridge_start, ridge_start + 450.0, r)
	return dune + ridge

func build() -> void:
	_dunes.seed = noise_seed
	_dunes.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_dunes.frequency = 0.008
	_dunes.fractal_octaves = 3
	_ridges.seed = noise_seed + 101
	_ridges.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridges.frequency = 0.0018
	_ridges.fractal_octaves = 4
	_ridges.fractal_gain = 0.45
	var key := [noise_seed, size, cells, flat_radius, dune_blend, dune_height, ridge_start, ridge_height]
	if not _cache.has(key):
		_cache[key] = _generate()
	var built: Array = _cache[key]
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = built[0]
	mesh_instance.material_override = material
	add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = built[1]
	# HeightMapShape3D has 1 m spacing; scale uniformly and store heights in scaled units.
	shape.scale = Vector3.ONE * step()
	add_child(shape)

func _generate() -> Array:
	var n := cells + 1
	var s := step()
	var half := size * 0.5
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = height_at(-half + i * s, -half + j * s)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			st.set_uv(Vector2(i, j) / cells)
			st.add_vertex(Vector3(-half + i * s, heights[j * n + i], -half + j * s))
	for j in cells:
		for i in cells:
			var a := j * n + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + n)
			st.add_index(a + 1)
			st.add_index(a + n + 1)
			st.add_index(a + n)
	st.generate_normals()
	var mesh := st.commit()
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	var scaled := heights.duplicate()
	for k in scaled.size():
		scaled[k] /= s
	shape.map_data = scaled
	return [mesh, shape]
