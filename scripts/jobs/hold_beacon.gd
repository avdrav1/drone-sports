class_name HoldBeacon
extends Node3D
# Shows a HoldStation in the world: a faint sphere the size of its radius,
# bright while it is the active hold, filling up as the hold runs. Look only.
# Lights the sibling MapMarker while active.

@export var hold: HoldStation
@export var color := Color(0.4, 0.85, 1.0)

var _mat: StandardMaterial3D
var _marker: MapMarker

func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.no_depth_test = false
	var sphere := SphereMesh.new()
	sphere.radius = hold.radius if hold else 2.5
	sphere.height = sphere.radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	for c in get_parent().get_children():
		if c is MapMarker:
			_marker = c
	_update()

func _process(_delta: float) -> void:
	_update()

func _update() -> void:
	if hold == null:
		return
	var on := hold.active()
	var a := 0.05
	if hold.is_done():
		a = 0.0
	elif on:
		a = 0.12 + 0.25 * hold.progress()
	_mat.albedo_color = Color(color, a)
	if _marker:
		_marker.highlighted = on
		_marker.on_map = not hold.is_done()
