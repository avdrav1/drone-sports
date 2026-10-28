class_name DroneLook
extends Node3D
# The drone's visible body: carbon frame, motors, props, lights. Reads the
# parent Drone's motor thrusts every frame; never touches physics.
# Props spin and motor rings glow with each motor's delivered thrust.

## Prop speed at full thrust, rad/s. Visual only.
@export var max_spin := 70.0
## Motor ring emission at full thrust.
@export var max_glow := 5.0
## Above this fraction of full spin the blades fade into a blur disc.
@export var blur_from := 0.25

const CARBON := Color(0.055, 0.06, 0.07)
const ACCENT := Color(0.95, 0.68, 0.12)
const ENGINE_GLOW := Color(1.0, 0.45, 0.12)

var drone: Drone
## Signed prop speed per motor, rad/s.
var spin_rates := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
## Motor ring emission per motor.
var glows := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

var _props: Array[Node3D] = []
var _blades: Array[StandardMaterial3D] = []
var _discs: Array[StandardMaterial3D] = []
var _rings: Array[StandardMaterial3D] = []

func _ready() -> void:
	drone = get_parent() as Drone
	_build()

func _process(delta: float) -> void:
	update_look(delta)

func update_look(delta: float) -> void:
	if drone == null:
		return
	for i in Drone.MOTOR_COUNT:
		var f := clampf(drone.motor_thrusts[i], 0.0, drone.max_thrust) / drone.max_thrust * drone.power()
		spin_rates[i] = f * max_spin * Drone.motor_spin(i)
		glows[i] = f * max_glow
		_props[i].rotate_y(spin_rates[i] * delta)
		_rings[i].emission_energy_multiplier = glows[i]
		var blur := smoothstep(blur_from, 1.0, f)
		_blades[i].albedo_color.a = 1.0 - blur * 0.85
		_discs[i].albedo_color.a = blur * 0.35

func _build() -> void:
	var carbon := _mat(CARBON, 0.35, 0.4)
	var accent := _mat(ACCENT, 0.2, 0.5)
	var metal := _mat(Color(0.18, 0.18, 0.2), 0.85, 0.3)
	var arm := drone.arm_length if drone else 0.15
	# Body: a flat hull with a raised canopy and a battery pack on the back.
	_box(Vector3(0.11, 0.035, 0.22), Vector3(0, 0, 0), carbon)
	_box(Vector3(0.07, 0.035, 0.1), Vector3(0, 0.03, -0.03), carbon)
	_box(Vector3(0.075, 0.03, 0.09), Vector3(0, 0.03, 0.065), _mat(Color(0.1, 0.1, 0.12), 0.1, 0.6))
	_box(Vector3(0.11, 0.006, 0.02), Vector3(0, 0.02, 0.0), accent)
	# Camera pod at the nose.
	_box(Vector3(0.04, 0.035, 0.03), Vector3(0, 0.005, -0.12), metal)
	for i in Drone.MOTOR_COUNT:
		var at := Drone.motor_offset(i, arm)
		# Arm from body to motor.
		var arm_mesh := _box(Vector3(0.022, 0.012, at.length()), at * 0.5, carbon)
		arm_mesh.basis = Basis.looking_at(at, Vector3.UP)
		_box(Vector3(0.03, 0.006, 0.03), at + Vector3(0, 0.0, 0), accent)
		# Motor bell and its glowing ring.
		_cylinder(0.022, 0.03, at + Vector3(0, 0.018, 0), metal)
		var ring := _mat(Color(0.2, 0.08, 0.04), 0.3, 0.4)
		ring.emission_enabled = true
		ring.emission = ENGINE_GLOW
		ring.emission_energy_multiplier = 0.0
		_rings.append(ring)
		_cylinder(0.025, 0.006, at + Vector3(0, 0.006, 0), ring)
		# Prop: two blades plus a blur disc.
		var prop := Node3D.new()
		prop.position = at + Vector3(0, 0.036, 0)
		add_child(prop)
		_props.append(prop)
		var blade := _mat(Color(0.08, 0.08, 0.09), 0.1, 0.5)
		blade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blades.append(blade)
		var b := _box(Vector3(0.17, 0.003, 0.018), Vector3.ZERO, blade, prop)
		b.rotation.x = 0.12
		var disc := _mat(Color(0.75, 0.75, 0.8, 0.0), 0.0, 0.3)
		disc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_discs.append(disc)
		_cylinder(0.088, 0.001, Vector3.ZERO, disc, prop)
	# Lights: white at the front, red at the back, so heading reads at a glance.
	for side in [-1.0, 1.0]:
		_box(Vector3(0.012, 0.01, 0.01), Vector3(side * 0.045, 0.0, -0.112), _light(Color(1, 0.95, 0.85)))
		_box(Vector3(0.012, 0.01, 0.01), Vector3(side * 0.045, 0.0, 0.112), _light(Color(1, 0.08, 0.05)))

## The body without props as one mesh, for drawing many still drones at once
## (the Lattice's shell, Story 8.2). Built from the same parts as a live drone.
static func still_mesh() -> ArrayMesh:
	var look := DroneLook.new()
	look._build()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mi in look.find_children("*", "MeshInstance3D", true, false):
		if mi.get_parent() != look:
			continue # props: they spin, so a still drone has none
		if mi.mesh is CylinderMesh:
			mi.mesh.radial_segments = 6 # thousands of these: keep them cheap
		st.append_from(mi.mesh, 0, mi.transform)
	look.free()
	return st.commit()

func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

func _light(color: Color) -> StandardMaterial3D:
	var m := _mat(color, 0.0, 0.5)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 4.0
	return m

func _box(size: Vector3, at: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(mesh, at, mat, parent)

func _cylinder(radius: float, height: float, at: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1
	return _instance(mesh, at, mat, parent)

func _instance(mesh: Mesh, at: Vector3, mat: Material, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi
