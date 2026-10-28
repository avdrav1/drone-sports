class_name City
extends StaticBody3D
# Builds a CityPlan into towers. Each lot's shape (Story 15.6) is stacked boxes
# plus trims; each part kind draws through its own MultiMeshInstance3D of unit
# boxes scaled per part, and every stacked box and plant room gets a collision
# box. Each tower's walls take one of `walls` from its seed (Story 15.4); the
# shader maps them in world space. Static scenery like the ridges; it never
# touches flight or grading. Built meshes and shapes are cached per layout, like
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
## Window grid, metres: one window per cell, none below the ground floor.
## Handed to the shader, which lays windows out the same way (Story 15.5).
## Keep in step with the layout's storey and ground_floor.
@export var window_cell := Vector2(3.0, 3.5)
@export var ground_floor := 4.0

## Group a city joins so the drone's wind can find its lee (Story 13.4).
const SHELTER_GROUP := &"wind_shelter"

const MAX_WALLS := 4

## MultiMeshInstance3D names: the stacked boxes, then one per CityPlan.Trim.
const KIND_NAMES: Array[String] = ["Towers", "Parapets", "Ledges", "PlantRooms"]

## params -> [MultiMeshes by kind, Array of [BoxShape3D, centre], seeds, wall
## indices, parts, part lots, window seeds, lit counts].
static var _cache := {}

var plan: CityPlan
## Per lot: the seed the shader reads (custom data x) and the index into `walls`
## it picked, kept because a MultiMesh's instance data cannot be read back.
var seeds: PackedFloat32Array
var wall_index: PackedInt32Array
## Every lot's stacked boxes in turn, and the lot each belongs to.
var parts: Array[AABB] = []
var part_lot: PackedInt32Array
## Per part: the window seed (custom data w, 0 to 2047) and how many of its
## windows are lit (custom data y). Whole numbers, so the shader reads them exactly.
var window_seeds: PackedInt32Array
var lit_counts: PackedInt32Array

func _ready() -> void:
	add_to_group(SHELTER_GROUP)
	build()

func build() -> void:
	plan = CityPlan.build(layout)
	var key := layout.params() + [tints, lit_min, lit_max, walls.size(), window_cell, ground_floor]
	if not _cache.has(key):
		_cache[key] = _generate()
	var built: Array = _cache[key]
	seeds = built[2]
	wall_index = built[3]
	parts = built[4]
	part_lot = built[5]
	window_seeds = built[6]
	lit_counts = built[7]
	_apply_surfaces()
	# Trims share the shader without windows or the base's contact shadow.
	var trim_material: ShaderMaterial = null
	if material:
		trim_material = material.duplicate()
		trim_material.set_shader_parameter("trim", true)
	for k in KIND_NAMES.size():
		var mmi := MultiMeshInstance3D.new()
		mmi.name = KIND_NAMES[k]
		mmi.multimesh = built[0][k]
		mmi.material_override = material if k == 0 else trim_material
		add_child(mmi)
	var i := 0
	for box in built[1]:
		var shape := CollisionShape3D.new()
		shape.name = "Part%d" % i
		shape.shape = box[0]
		shape.position = box[1]
		add_child(shape)
		i += 1

func _generate() -> Array:
	seeds = PackedFloat32Array()
	wall_index = PackedInt32Array()
	parts = []
	part_lot = PackedInt32Array()
	window_seeds = PackedInt32Array()
	lit_counts = PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed + 1
	# Per kind: transforms, tints, custom data.
	var drawn := []
	for k in KIND_NAMES.size():
		drawn.append([[], [], []])
	# Colliders: every stacked box, then every plant room, then every parapet.
	var boxes := []
	var plants := []
	var parapets := []
	for i in plan.lots.size():
		var shape := plan.shapes[i]
		var tint := tints[rng.randi() % tints.size()]
		var lot_seed := rng.randf()
		var lit := rng.randf_range(lit_min, lit_max)
		seeds.append(lot_seed)
		wall_index.append(wall_for(lot_seed, walls.size()))
		for j in shape.boxes.size():
			var b := shape.boxes[j]
			parts.append(b)
			part_lot.append(i)
			# From the lot's seed, so the rng sequence (tints, walls) is as before.
			window_seeds.append(_hash32(int(lot_seed * 0x7FFFFFFF) + j) & 2047)
			lit_counts.append(lit_count(window_count(b.size, b.position.y), lit))
			var n := parts.size() - 1
			_draw(drawn[0], b, tint, Color(lot_seed, lit_counts[n], wall_index[i], window_seeds[n]))
			boxes.append(_collider(b))
		for j in shape.trims.size():
			var t := shape.trims[j]
			_draw(drawn[1 + shape.trim_kinds[j]], t, tint, Color(lot_seed, 0.0, wall_index[i], 0.0))
			if shape.trim_kinds[j] == CityPlan.Trim.PLANT:
				plants.append(_collider(t))
			elif shape.trim_kinds[j] == CityPlan.Trim.PARAPET:
				parapets.append(_collider(t))
	boxes.append_array(plants)
	boxes.append_array(parapets)
	var mms: Array[MultiMesh] = []
	for d in drawn:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = BoxMesh.new()
		mm.instance_count = d[0].size()
		for j in d[0].size():
			mm.set_instance_transform(j, d[0][j])
			mm.set_instance_color(j, d[1][j])
			mm.set_instance_custom_data(j, d[2][j])
		mms.append(mm)
	return [mms, boxes, seeds, wall_index, parts, part_lot, window_seeds, lit_counts]

## Queues one unit box scaled to `box` into a kind's [transforms, tints, custom].
static func _draw(into: Array, box: AABB, tint: Color, custom: Color) -> void:
	into[0].append(Transform3D(Basis.from_scale(box.size), box.get_center()))
	into[1].append(tint)
	into[2].append(custom)

static func _collider(box: AABB) -> Array:
	var shape := BoxShape3D.new()
	shape.size = box.size
	return [shape, box.get_center()]

## The wall set a building with this seed (0 to 1) takes out of `count`.
static func wall_for(lot_seed: float, count: int) -> int:
	return clampi(int(lot_seed * count), 0, maxi(count - 1, 0))

## Windows on a box of this size standing at `base`: whole cells across each
## face, whole storeys above the ground floor and inside the box. (columns on an
## x face, on a z face, rows), matching the shader.
func window_grid(size: Vector3, base := 0.0) -> Vector3i:
	return Vector3i(floori(size.z / window_cell.x + 0.001), floori(size.x / window_cell.x + 0.001),
		maxi(_last_row(size.y + base) - _first_row(base), 0))

func window_count(size: Vector3, base := 0.0) -> int:
	var g := window_grid(size, base)
	return 2 * g.z * (g.x + g.y)

## The first storey row (counted from the ground floor) wholly above `base`,
## and the row past the last one wholly below `top`.
func _first_row(base: float) -> int:
	return ceili((maxf(base, ground_floor) - ground_floor) / window_cell.y - 0.001)

func _last_row(top: float) -> int:
	return floori((top - ground_floor) / window_cell.y + 0.001)

## How many of `count` windows to light for a lit fraction of `lit`, kept so the
## real fraction (a whole number over count) stays within lit_min to lit_max.
func lit_count(count: int, lit: float) -> int:
	var low := ceili(lit_min * count - 0.0001)
	var high := maxi(floori(lit_max * count + 0.0001), low)
	return clampi(roundi(lit * count), low, high)

## The shader's choice for window `index` of part `i` (faces +x, -x, +z, -z, row
## by row): (lit 0 or 1, blind 0 to 7, room 0 to 3, lamp 0 to 2).
func window_at(i: int, index: int) -> Vector4i:
	var n := window_count(parts[i].size, parts[i].position.y)
	var key := window_seeds[i]
	var pick := _hash32(index ^ (key << 16))
	var lit := 1 if _rank(index, n, key) < lit_counts[i] else 0
	return Vector4i(lit, pick & 7, (pick >> 3) & 3, (pick >> 5) % 3)

## The shader's hash32 (lowbias32), in 32-bit unsigned arithmetic.
static func _hash32(x: int) -> int:
	x &= 0xFFFFFFFF
	x ^= x >> 16
	x = _mul32(x, 0x7feb352d)
	x ^= x >> 15
	x = _mul32(x, 0x846ca68b)
	x ^= x >> 16
	return x

static func _mul32(a: int, b: int) -> int:
	return (a * (b & 0xFFFF) + (((a * (b >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF

## The shader's window_rank: window i's place in a keyed shuffle of 0..n-1.
static func _rank(i: int, n: int, key: int) -> int:
	var m := 1
	while (1 << m) < n:
		m += 1
	var mask := (1 << m) - 1
	var s := maxi(m >> 1, 1)
	var k := _hash32(key)
	var x := i
	for _t in 64:
		x = (x ^ k) & mask
		x = (x * 739982445) & mask
		x ^= x >> s
		x = (x * 695872825 + (k >> 16)) & mask
		x ^= x >> s
		if x < n:
			break
	return x

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
	material.set_shader_parameter("window_cell", window_cell)
	material.set_shader_parameter("ground_floor", ground_floor)
