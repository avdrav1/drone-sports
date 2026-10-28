class_name City
extends StaticBody3D
# Builds a CityPlan into box towers: one MultiMeshInstance3D of unit boxes scaled
# per lot, and one collision box per lot. Static scenery like the ridges; it never
# touches flight or grading. Built meshes and shapes are cached per layout, like
# DesertTerrain, so scenes reload cheaply.

@export var layout: CityLayout
@export var material: Material
## Wall tints, picked per building.
@export var tints: PackedColorArray = [Color(1, 1, 1), Color(1.0, 0.9, 0.78), Color(0.92, 0.86, 0.82),
	Color(0.8, 0.84, 0.88), Color(1.0, 0.82, 0.7)]
## Fraction of windows lit, per building.
@export var lit_min := 0.04
@export var lit_max := 0.25

## Group a city joins so the drone's wind can find its lee (Story 13.4).
const SHELTER_GROUP := &"wind_shelter"

## params -> [MultiMesh, Array of [BoxShape3D, centre]].
static var _cache := {}

var plan: CityPlan

func _ready() -> void:
	add_to_group(SHELTER_GROUP)
	build()

func build() -> void:
	plan = CityPlan.build(layout)
	var key := layout.params() + [tints, lit_min, lit_max]
	if not _cache.has(key):
		_cache[key] = _generate()
	var built: Array = _cache[key]
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
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(lit_min, lit_max), 0, 0))
		var shape := BoxShape3D.new()
		shape.size = size
		boxes.append([shape, centre])
	return [mm, boxes]
