class_name City
extends StaticBody3D
# Builds a CityPlan into box towers: one MultiMeshInstance3D of unit boxes scaled
# per lot, and one collision box per lot. Each tower's walls take one of `walls`
# from its seed (Story 15.4); the shader maps them in world space. Static scenery
# like the ridges; it never touches flight or grading. Built meshes and shapes are cached per layout, like
# DesertTerrain, so scenes reload cheaply.

@export var layout: CityLayout
@export var material: ShaderMaterial
## Wall surfaces from the material library, picked per building by its seed.
## The shader has room for four.
@export var walls: Array[SurfaceSet] = []
## The roof surface.
@export var roof: SurfaceSet
## Wall tints, picked per building.
@export var tints: PackedColorArray = [Color(1, 1, 1), Color(1.0, 0.9, 0.78), Color(0.92, 0.86, 0.82),
	Color(0.8, 0.84, 0.88), Color(1.0, 0.82, 0.7)]
## Fraction of windows lit, per building.
@export var lit_min := 0.04
@export var lit_max := 0.25

## Group a city joins so the drone's wind can find its lee (Story 13.4).
const SHELTER_GROUP := &"wind_shelter"

const MAX_WALLS := 4

## params -> [MultiMesh, Array of [BoxShape3D, centre], seeds, wall indices].
static var _cache := {}

var plan: CityPlan
## Per lot: the seed the shader reads (custom data x) and the index into `walls`
## it picked, kept because a MultiMesh's instance data cannot be read back.
var seeds: PackedFloat32Array
var wall_index: PackedInt32Array

func _ready() -> void:
	add_to_group(SHELTER_GROUP)
	build()

func build() -> void:
	plan = CityPlan.build(layout)
	var key := layout.params() + [tints, lit_min, lit_max, walls.size()]
	if not _cache.has(key):
		_cache[key] = _generate()
	var built: Array = _cache[key]
	seeds = built[2]
	wall_index = built[3]
	_apply_surfaces()
	var towers := MultiMeshInstance3D.new()
	towers.name = "Towers"
	towers.multimesh = built[0]
	towers.material_override = material
	add_child(towers)
	var i := 0
	for box in built[1]:
		var shape := CollisionShape3D.new()
		shape.name = "Lot%d" % i
		shape.shape = box[0]
		shape.position = box[1]
		add_child(shape)
		i += 1

func _generate() -> Array:
	seeds = PackedFloat32Array()
	wall_index = PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed + 1
	var mesh := BoxMesh.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = plan.lots.size()
	var boxes := []
	for i in plan.lots.size():
		var lot := plan.lots[i]
		var h := plan.heights[i]
		var size := Vector3(lot.size.x, h, lot.size.y)
		var centre := Vector3(lot.get_center().x, h * 0.5, lot.get_center().y)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(size), centre))
		mm.set_instance_color(i, tints[rng.randi() % tints.size()])
		var lot_seed := rng.randf()
		var lit := rng.randf_range(lit_min, lit_max)
		seeds.append(lot_seed)
		wall_index.append(wall_for(lot_seed, walls.size()))
		mm.set_instance_custom_data(i, Color(lot_seed, lit, wall_index[i], 0))
		var shape := BoxShape3D.new()
		shape.size = size
		boxes.append([shape, centre])
	return [mm, boxes, seeds, wall_index]

## The wall set a building with this seed (0 to 1) takes out of `count`.
static func wall_for(lot_seed: float, count: int) -> int:
	return clampi(int(lot_seed * count), 0, maxi(count - 1, 0))

## Hands the library's maps and tile sizes to the shader. The scene's material
## is shared by every City, so each one sets its own copy.
func _apply_surfaces() -> void:
	if material == null:
		return
	material = material.duplicate()
	assert(walls.size() >= 1 and walls.size() <= MAX_WALLS)
	var tiles := PackedVector2Array()
	var metal := PackedFloat32Array()
	for k in MAX_WALLS:
		var s: SurfaceSet = walls[mini(k, walls.size() - 1)]
		material.set_shader_parameter("wall_albedo_%d" % k, s.albedo)
		material.set_shader_parameter("wall_nr_%d" % k, s.normal_rough)
		tiles.append(s.tile_size)
		metal.append(s.metallic)
	material.set_shader_parameter("wall_tile", tiles)
	material.set_shader_parameter("wall_metallic", metal)
	material.set_shader_parameter("roof_albedo", roof.albedo)
	material.set_shader_parameter("roof_nr", roof.normal_rough)
	material.set_shader_parameter("roof_tile", roof.tile_size)
