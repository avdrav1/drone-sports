class_name DroneLook
extends Node3D
# The drone's visible body: carbon frame, motors, props, lights. Reads the
# parent Drone's motor thrusts every frame; never touches physics.
# Props spin and motor rings glow with each motor's delivered thrust.
# Story 27.2: it wears a Livery: colours on body, arms, props and canopy, arm
# strips (and, lit, an under-glow) in the light colour, a decal on top of the
# canopy and the race number on the battery. The white front and red back
# heading lights never change. Materials that only follow the livery are
# shared by every drone wearing the same colours (a fleet draws many); the
# ones that follow each motor's thrust stay the drone's own.

## Prop speed at full thrust, rad/s. Visual only.
@export var max_spin := 70.0
## Motor ring emission at full thrust.
@export var max_glow := 5.0
## Above this fraction of full spin the blades fade into a blur disc.
@export var blur_from := 0.25

const CARBON := Color(0.055, 0.06, 0.07)
const ACCENT := Color(0.95, 0.68, 0.12)
const ENGINE_GLOW := Color(1.0, 0.45, 0.12)
const DEFAULT_LIVERY := preload("res://data/garage/default_livery.tres")
## The heading lights: white at the front, red at the back, in every livery.
const FRONT_LIGHT := Color(1, 0.95, 0.85)
const BACK_LIGHT := Color(1, 0.08, 0.05)
## Emission of a lit livery's under-glow and arm strips.
const STRIP_GLOW := 2.5
## Where the decal and the number sit: on the canopy's top and the battery's.
const DECAL_AT := Vector3(0, 0.0481, -0.03)
const DECAL_SIZE := 0.062
const NUMBER_AT := Vector3(0, 0.0456, 0.065)
const NUMBER_SIZE := Vector2(0.066, 0.033)

## Shared materials by what they look like (Story 27.2).
static var _materials := {}

var drone: Drone
## What the drone wears; null wears the default, the drone as it was. Set it
## with `wear`.
var livery: Livery
## The hull's size against stock, from the fitted frame (Story 27.4): x wide,
## y tall, z long. Set it with `wear`.
var hull := Vector3.ONE
## Signed prop speed per motor, rad/s.
var spin_rates := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
## Motor ring emission per motor.
var glows := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

var _props: Array[Node3D] = []
var _blades: Array[StandardMaterial3D] = []
var _discs: Array[StandardMaterial3D] = []
var _rings: Array[StandardMaterial3D] = []
## Every node `_build` added, so `rebuild` can take them away again.
var _built: Array[Node] = []

func _ready() -> void:
	drone = get_parent() as Drone
	if _built.is_empty(): # not already dressed by `wear`
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

## Puts on `l` (null for the default) on a hull of `shape`, and builds the
## body again in them.
func wear(l: Livery, shape := Vector3.ONE) -> void:
	livery = l
	hull = shape
	rebuild()

## The livery being worn: `livery`, or the default.
func worn() -> Livery:
	return livery if livery else DEFAULT_LIVERY

## Builds the body again, after a livery or the drone's arm length changes.
## Anything else under the look (a crew face) stays.
func rebuild() -> void:
	if drone == null:
		drone = get_parent() as Drone
	for n in _built:
		if is_instance_valid(n):
			n.free()
	_built.clear()
	_props.clear()
	_blades.clear()
	_discs.clear()
	_rings.clear()
	_build()

func _build() -> void:
	var l := worn()
	var body := _paint(l.body_color)
	var arms := _paint(l.arm_color)
	var canopy := _paint(l.canopy_color)
	var accent: StandardMaterial3D = _shared("accent:" + l.light_color.to_html(), func(): return _mat(l.light_color, 0.2, 0.5))
	var metal: StandardMaterial3D = _shared("metal", func(): return _mat(Color(0.18, 0.18, 0.2), 0.85, 0.3))
	var battery: StandardMaterial3D = _shared("battery", func(): return _mat(Color(0.1, 0.1, 0.12), 0.1, 0.6))
	var arm := drone.arm_length if drone else 0.15
	# Body: a flat hull with a raised canopy and a battery pack on the back.
	var h := hull
	_box(Vector3(0.11, 0.035, 0.22) * h, Vector3(0, 0, 0), body)
	_box(Vector3(0.07, 0.035, 0.1) * h, Vector3(0, 0.03, -0.03) * h, canopy)
	_box(Vector3(0.075, 0.03, 0.09) * h, Vector3(0, 0.03, 0.065) * h, battery)
	_box(Vector3(0.11, 0.006, 0.02) * h, Vector3(0, 0.02, 0.0) * h, accent)
	# Camera pod at the nose.
	_box(Vector3(0.04, 0.035, 0.03) * h, Vector3(0, 0.005, -0.12) * h, metal)
	for i in Drone.MOTOR_COUNT:
		var at := Drone.motor_offset(i, arm)
		# Arm from body to motor.
		var arm_mesh := _box(Vector3(0.022, 0.012, at.length()), at * 0.5, arms)
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
		_built.append(prop)
		_props.append(prop)
		var blade := _mat(l.prop_color, 0.1, 0.5)
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
	var front: StandardMaterial3D = _shared("front", func(): return _light(FRONT_LIGHT))
	var back: StandardMaterial3D = _shared("back", func(): return _light(BACK_LIGHT))
	for side in [-1.0, 1.0]:
		_box(Vector3(0.012, 0.01, 0.01), Vector3(side * 0.045, 0.0, -0.112) * h, front)
		_box(Vector3(0.012, 0.01, 0.01), Vector3(side * 0.045, 0.0, 0.112) * h, back)
	if l.glow:
		_build_glow(l, arm)
	if l.decal != &"":
		_build_decal(l)
	if l.race_number > 0:
		_build_number(l)

# Lit livery: a strip along the top of each arm and an under-glow panel below
# the hull, in the light colour. Both sit inside the hull's outline.
func _build_glow(l: Livery, arm: float) -> void:
	var lit: StandardMaterial3D = _shared("glow:" + l.light_color.to_html(), func():
		var m := _light(l.light_color)
		m.emission_energy_multiplier = STRIP_GLOW
		return m)
	_box(Vector3(0.08, 0.004, 0.18) * Vector3(hull.x, 1.0, hull.z), Vector3(0, -0.002 - 0.0175 * hull.y, 0), lit)
	for i in Drone.MOTOR_COUNT:
		var at := Drone.motor_offset(i, arm)
		var strip := _box(Vector3(0.006, 0.003, at.length() * 0.6), at * 0.55 + Vector3(0, 0.0075, 0), lit)
		strip.basis = Basis.looking_at(at, Vector3.UP)

func _build_decal(l: Livery) -> void:
	var tex := DecalArt.texture(l.decal, team_colors())
	if tex == null:
		return
	# The team emblem keeps its own colours; every other decal takes the livery's.
	var tint := Color.WHITE if l.decal == &"team" else l.decal_color
	var key := "decal:%d:%s" % [tex.get_instance_id(), tint.to_html()]
	_flat(Vector2.ONE * DECAL_SIZE * minf(hull.x, hull.z), DECAL_AT * hull, _shared(key, func(): return _sticker(tex, tint)))

## The pilot's team's colours, for the team emblem; the home game's with no team.
static func team_colors() -> Array[Color]:
	var team: Team = Career.team()
	if team and team.colors.size() >= 2:
		return [team.colors[0], team.colors[1]]
	return DecalArt.HOME_COLORS

func _build_number(l: Livery) -> void:
	var tex := DecalArt.number_texture(l.race_number)
	var key := "number:%d:%s" % [l.race_number, l.decal_color.to_html()]
	_flat(NUMBER_SIZE * minf(hull.x, hull.z), NUMBER_AT * hull, _shared(key, func(): return _sticker(tex, l.decal_color)))

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

## The material made by `make`, made once per `key` and shared after that.
static func _shared(key: String, make: Callable) -> Material:
	if not _materials.has(key):
		_materials[key] = make.call()
	return _materials[key]

## The painted carbon of the hull, canopy and arms, in `color`.
func _paint(color: Color) -> StandardMaterial3D:
	return _shared("paint:" + color.to_html(), func(): return _mat(color, 0.35, 0.4))

## A decal: the texture's mask, tinted, cut out at its edges.
func _sticker(tex: Texture2D, tint: Color) -> StandardMaterial3D:
	var m := _mat(tint, 0.1, 0.5)
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	return m

# A quad lying flat on a top face, its image's top toward the nose, so it reads
# the right way up from behind the drone.
func _flat(size: Vector2, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var mi := _instance(mesh, at, mat, self)
	mi.rotation.x = -PI / 2.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

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
	if parent == self:
		_built.append(mi)
	return mi
