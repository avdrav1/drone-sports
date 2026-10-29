extends RefCounted
# Story 15.10: obstacles as structures. Gates and job props are drawn as trusses,
# beams, decks, and real-material panels, while every collision shape, body, and
# transform stays exactly as it was, so courses and jobs play as before.

const Sim = preload("res://tests/sim.gd")
const JOBS := "res://scenes/jobs/"
const EXTRA := ["res://scenes/boss/lattice_job.tscn"]
# md5 of each scene's collision fingerprint (see fingerprint), taken before 15.10.
const FINGERPRINTS := {
	"res://scenes/jobs/demolition.tscn": "3d91fe07b24ca16fe1ba71dd24da646c",
	"res://scenes/jobs/fleet_inspection.tscn": "d41d8cd98f00b204e9800998ecf8427e",
	"res://scenes/jobs/fleet_race.tscn": "2ba19f510ffaae4a3f365acb9bcf1ce8",
	"res://scenes/jobs/inspection.tscn": "1261c60e7dd76c75468771614673d4c9",
	"res://scenes/jobs/rescue.tscn": "6ce6b686220f419c32248a1c0ee6594e",
	"res://scenes/jobs/sample_delivery.tscn": "a28c6661a910b01c6a47bae0b613470f",
	"res://scenes/jobs/spotter_drill.tscn": "ceb6061fd0ed316a304f4088fe93e820",
	"res://scenes/jobs/test_race.tscn": "ceb6061fd0ed316a304f4088fe93e820",
	"res://scenes/boss/lattice_job.tscn": "56c36d0f305ba5b5e17bc85354fb79b9",
}

static func scenes() -> Array[String]:
	var out: Array[String] = []
	for f in ResourceLoader.list_directory(JOBS):
		if f.get_extension() == "tscn":
			out.append(JOBS + f)
	out.append_array(EXTRA)
	return out

## True when `n` belongs to a drone or to the shared world (ground, city), which
## this story does not touch.
static func _outside(n: Node, root: Node) -> bool:
	while n and n != root:
		if n is Drone or n.name in ["Ground", "City", "Streets", "Rooftops"]:
			return true
		n = n.get_parent()
	return false

## Every collision object and shape under `root` that is a prop: path, transform,
## shape and size, and mass for loose pieces, one line each, sorted.
static func fingerprint(root: Node) -> String:
	var lines: Array[String] = []
	for n in root.find_children("*", "Node3D", true, false):
		if _outside(n, root):
			continue
		if n is CollisionShape3D and n.shape:
			lines.append("%s %s %s %s" % [_path(root, n), n.global_transform, n.shape.get_class(), _shape_size(n.shape)])
		elif n is CollisionObject3D:
			var extra := ("%s %s" % [n.mass, n.freeze]) if n is RigidBody3D else ""
			lines.append("%s %s %s %s %s" % [_path(root, n), n.get_class(), n.global_transform, n.collision_layer, extra])
	lines.sort()
	return "\n".join(lines)

## The node's path, with generated names (which count every node made so far)
## reduced to their class.
static func _path(root: Node, n: Node) -> String:
	var re := RegEx.create_from_string("@([A-Za-z0-9]+)@\\d+")
	return re.sub(str(root.get_path_to(n)), "@$1", true)

static func _shape_size(s: Shape3D) -> String:
	if s is BoxShape3D:
		return str(s.size)
	if s is SphereShape3D:
		return str(s.radius)
	if s is CapsuleShape3D or s is CylinderShape3D:
		return "%s %s" % [s.radius, s.height]
	return str(s.get_rid() != RID())

static func _load(path: String) -> Node:
	return Sim.add(load(path).instantiate())

func test_collision_shapes_and_transforms_unchanged() -> bool:
	var ok := true
	for path in scenes():
		var scene := _load(path)
		var md5 := fingerprint(scene).md5_text()
		scene.free()
		if FINGERPRINTS.get(path, "") != md5:
			print("        %s: %s" % [path, md5])
			ok = false
	return ok

## Every mesh a job scene draws for a prop or gate (not the drone, ground, or city).
static func _prop_meshes(scene: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		if not _outside(n, scene) and n.get_parent() is CollisionObject3D:
			out.append(n)
	return out

func test_no_bare_box_mesh_for_a_structure() -> bool:
	var ok := true
	var structures := {}
	for path in scenes():
		var scene := _load(path)
		structures[path] = scene.find_children("*", "Structure", true, false).size()
		for m in _prop_meshes(scene):
			if m.mesh == null or m.mesh is BoxMesh:
				print("        %s: %s" % [path, scene.get_path_to(m)])
				ok = false
		scene.free()
	# Gates, the tower, the cannery and its debris, and the delivery walls are built.
	for p in ["test_race", "inspection", "demolition", "sample_delivery", "fleet_race"]:
		ok = ok and structures[JOBS + p + ".tscn"] > 0
	return ok

## Each structure stands in its collision box: a sibling box shape of the same
## size at the same place, and no part of the mesh outside it.
func test_structures_fill_their_collision_boxes() -> bool:
	var ok := true
	var count := 0
	for path in scenes():
		var scene := _load(path)
		for s: Structure in scene.find_children("*", "Structure", true, false):
			count += 1
			var matched := false
			for c in s.get_parent().get_children():
				if c is CollisionShape3D and c.shape is BoxShape3D and c.shape.size.is_equal_approx(s.size) \
						and c.transform.is_equal_approx(s.transform):
					matched = true
			var box := AABB(-s.size * 0.5, s.size).grow(0.002)
			var aabb := s.mesh.get_aabb()
			if not matched or not (box.encloses(aabb) and aabb.size.length() > s.size.length() * 0.9):
				print("        %s: %s" % [path, scene.get_path_to(s)])
				ok = false
		scene.free()
	return ok and count > 60

func test_every_kind_builds_inside_its_box() -> bool:
	var ok := true
	for k in Structure.Kind.values():
		for size in [Vector3(4.5, 0.3, 0.3), Vector3(0.5, 36, 0.5), Vector3(16, 8, 2), Vector3(3, 12, 3), Vector3(0.4, 0.4, 0.4)]:
			var mesh := Structure.build(k, size)
			var box := AABB(-size * 0.5, size).grow(0.002)
			ok = ok and mesh.get_surface_count() > 0 and box.encloses(mesh.get_aabb())
	# The same kind and size share one mesh.
	return ok and Structure.build(Structure.Kind.TRUSS, Vector3.ONE) == Structure.build(Structure.Kind.TRUSS, Vector3.ONE)

## Debris pieces, and every textured structure, use 15.2 library sets.
func test_debris_uses_library_materials() -> bool:
	var albedos := {}
	for id in SurfaceSet.ids():
		albedos[SurfaceSet.named(id).albedo] = id
	var scene := _load(JOBS + "demolition.tscn")
	var debris := scene.find_children("*", "Debris", true, false)
	var ok := debris.size() > 10
	for d in debris:
		var s: Structure = d.get_node("Mesh")
		for i in s.mesh.get_surface_count():
			var m := s.get_surface_override_material(i) as ShaderMaterial
			ok = ok and m != null and albedos.has(m.get_shader_parameter("albedo_map")) \
				and m.get_shader_parameter("nr_map") == SurfaceSet.named(albedos[m.get_shader_parameter("albedo_map")]).normal_rough
	scene.free()
	return ok

## Wetness and snow cover reach the props' shader, as they do the ground's.
func test_structure_shader_takes_weather() -> bool:
	var code := (load("res://scenes/world/structure.gdshader") as Shader).code
	return code.contains("global uniform float wetness") and code.contains("global uniform float snow_cover")

## A gate is still lit as the next target and dimmed after.
func test_gate_highlight_still_lights() -> bool:
	var g: Gate = Sim.add(Gate.new())
	var glow: StandardMaterial3D = g._glow
	g.set_highlight(true)
	var on := glow.emission_energy_multiplier
	g.set_highlight(false)
	var off := glow.emission_energy_multiplier
	var lit := 0
	for m in g.find_children("*", "MeshInstance3D", true, false):
		if m.material_override == glow:
			lit += 1
	g.free()
	return on > off and lit == 4
