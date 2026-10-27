class_name RouteRibbon
extends MeshInstance3D
# The route in the world: faint flat dashes along RouteSource.guided(), starting
# a little ahead of the drone. Rebuilt every frame; draws nothing without guidance.

@export var route: RouteSource
## Metres of route drawn from the drone.
@export var reach := 150.0
## Gap kept clear in front of the drone, m.
@export var lead := 4.0
@export var dash := 1.5
@export var width := 0.25
@export var color := Color(1.0, 0.76, 0.25, 0.35)

var dashes := 0
var _mesh := ImmediateMesh.new()

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	material_override = mat

func _process(_delta: float) -> void:
	rebuild()

func rebuild() -> void:
	_mesh.clear_surfaces()
	dashes = 0
	if route == null:
		return
	var line := route.guided()
	if line.size() < 2:
		return
	var starts: Array[Vector3] = []
	var travelled := [0.0]
	RouteSource.walk(line, dash * 2.0, func(at: Vector3) -> void:
		travelled[0] += dash * 2.0
		if travelled[0] > lead and travelled[0] < reach:
			starts.append(at))
	var verts := PackedVector3Array()
	for i in starts.size():
		var a := starts[i]
		var b := starts[i + 1] if i + 1 < starts.size() else line[line.size() - 1]
		var dir := b - a
		if dir.length() < 0.01:
			continue
		dir = dir.normalized()
		var side := dir.cross(Vector3.UP)
		side = side.normalized() * width * 0.5 if side.length() > 0.01 else Vector3.RIGHT * width * 0.5
		var c := a + dir * dash
		verts.append_array([a - side, a + side, c + side, a - side, c + side, c - side])
		dashes += 1
	if verts.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in verts:
		_mesh.surface_add_vertex(v)
	_mesh.surface_end()
