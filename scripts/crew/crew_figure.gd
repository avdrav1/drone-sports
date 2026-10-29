class_name CrewFigure
extends Node3D
# A crew member as a 3D cartoon figure (Story 20.1), built from their CrewLook:
# the pack body in the look's colours, their accessory on the head bone, and
# the body's clips played by action name. Look only: no collision shape, and
# it never touches a drone, flight, assists or grading (rules 1, 2 and 8).

const SHADER := preload("res://scenes/crew/crew_body.gdshader")
const COLORMAP := preload("res://data/models/crew/colormap.png")
## The pack's figures stand about this tall to the top of the head, in model units.
const MODEL_HEIGHT := 0.7
## Seconds to blend from one clip to the next.
const BLEND := 0.15

var look: CrewLook
var skeleton: Skeleton3D
var player: AnimationPlayer
## The action playing, one of CrewBody.ACTIONS.
var action: StringName

## A figure of `look` standing `height` metres tall, playing idle.
static func build(from: CrewLook, height := 1.75) -> CrewFigure:
	var fig := CrewFigure.new()
	fig.name = "CrewFigure"
	fig.look = from
	var model: Node3D = from.body.model.instantiate()
	model.name = "Body"
	model.scale = Vector3.ONE * height / MODEL_HEIGHT
	fig.add_child(model)
	fig.skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	fig.player = model.find_children("*", "AnimationPlayer", true, false)[0]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("colormap", COLORMAP)
	for role in CrewLook.ROLES:
		mat.set_shader_parameter(role, from.color(role))
	for mi: MeshInstance3D in fig.skeleton.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
	var head := BoneAttachment3D.new()
	head.name = "Head"
	head.bone_name = "head"
	fig.skeleton.add_child(head)
	var head_y := fig.skeleton.get_bone_global_rest(fig.skeleton.find_bone("head")).origin.y
	fig._add_accessory(head, from.body.crown - head_y)
	for looped in [&"idle", &"wave", &"cheer"]:
		fig.player.get_animation(from.body.clips[looped]).loop_mode = Animation.LOOP_LINEAR
	fig.play(&"idle")
	return fig

## Plays one of CrewBody.ACTIONS with the body's closest clip.
func play(what: StringName) -> void:
	action = what
	player.play(look.body.clips[what], BLEND)

## The accessory's meshes, in the head bone's space: y up from the neck, z
## forward. The head is a box about 0.34 wide and 0.32 tall; `crown` is the
## top of the hair.
func _add_accessory(head: Node3D, crown: float) -> void:
	var a := look.accessory_color
	var b := look.accessory_detail
	match look.accessory:
		&"hardhat":
			_part(head, _dome(0.24), a, Vector3(0, crown - 0.08, 0), Vector3(1, 0.62, 1.05))
			_part(head, _cylinder(0.28, 0.03), a, Vector3(0, crown - 0.07, 0.03))
			_part(head, _box(Vector3(0.06, 0.05, 0.42)), b, Vector3(0, crown + 0.065, 0))
		&"tall":
			_part(head, _cylinder(0.24, 0.03), a, Vector3(0, crown - 0.03, 0))
			_part(head, _cylinder(0.15, 0.34), a, Vector3(0, crown + 0.14, 0))
			_part(head, _cylinder(0.155, 0.06), b, Vector3(0, crown + 0.02, 0))
		&"round":
			_part(head, _dome(0.23), a, Vector3(0, crown - 0.07, -0.01), Vector3(1, 0.55, 1))
			_part(head, _box(Vector3(0.3, 0.03, 0.18)), a, Vector3(0, crown - 0.055, 0.22))
			_part(head, _sphere(0.04), b, Vector3(0, crown + 0.06, -0.01))
		&"fin":
			_part(head, _dome(0.23), a, Vector3(0, crown - 0.07, -0.01), Vector3(1, 0.55, 1))
			var fin := PrismMesh.new()
			fin.size = Vector3(0.36, 0.24, 0.05)
			fin.left_to_right = 0.15
			_part(head, fin, b, Vector3(0, crown + 0.15, -0.03), Vector3.ONE, Vector3(0, PI * 0.5, 0))
		&"visor":
			_band(head, 0.27, b)
			_part(head, _box(Vector3(0.4, 0.05, 0.2)), a, Vector3(0, crown - 0.01, 0.12), Vector3.ONE, Vector3(-0.35, 0, 0))
		&"square":
			_band(head, 0.26, a)
			for side in [-1.0, 1.0]:
				var lens := Vector3(side * 0.085, 0.26, 0.19)
				_part(head, _cylinder(0.075, 0.05), a, lens, Vector3.ONE, Vector3(PI * 0.5, 0, 0))
				_part(head, _cylinder(0.055, 0.06), b, lens + Vector3(0, 0, 0.005), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
		&"antenna":
			_arch(head, crown, 0.2, a)
			for side in [-1.0, 1.0]:
				_part(head, _cylinder(0.07, 0.05), a, Vector3(side * 0.22, 0.15, 0), Vector3.ONE, Vector3(0, 0, PI * 0.5))
			_part(head, _cylinder(0.014, 0.3), a, Vector3(0.22, crown + 0.0, 0))
			_part(head, _sphere(0.05), b, Vector3(0.22, crown + 0.16, 0))
		&"ears":
			_arch(head, crown, 0.2, b)
			for side in [-1.0, 1.0]:
				_part(head, _sphere(0.1), a, Vector3(side * 0.23, 0.15, 0), Vector3(0.65, 1, 1))
		&"tuft":
			for x in [-0.07, 0.07, 0.0]:
				_part(head, _sphere(0.075), a, Vector3(x, crown - 0.01 + (0.06 if x == 0.0 else 0.0), -0.02))

## A headband over the top at `crown`, down both sides to y 0.15, `half` out.
func _arch(head: Node3D, crown: float, half: float, col: Color) -> void:
	_part(head, _box(Vector3(half * 2.0 + 0.035, 0.035, 0.05)), col, Vector3(0, crown, 0))
	for side in [-1.0, 1.0]:
		_part(head, _box(Vector3(0.035, crown - 0.15, 0.05)), col, Vector3(side * half, (crown + 0.15) * 0.5, 0))

## A strap round the head at height y.
func _band(head: Node3D, y: float, col: Color) -> void:
	for side in [-1.0, 1.0]:
		_part(head, _box(Vector3(0.37, 0.04, 0.02)), col, Vector3(0, y, side * 0.175 - 0.005))
		_part(head, _box(Vector3(0.02, 0.04, 0.37)), col, Vector3(side * 0.185, y, -0.005))

func _part(head: Node3D, mesh: Mesh, col: Color, at: Vector3, size := Vector3.ONE, rot := Vector3.ZERO) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.emission_enabled = true
	mat.emission = col * 0.22
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	mi.scale = size
	head.add_child(mi)

static func _dome(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.is_hemisphere = true
	m.radial_segments = 16
	m.rings = 6
	return m

static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 5
	return m

static func _cylinder(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 1
	return m

static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
