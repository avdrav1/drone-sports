class_name Gate
extends StaticBody3D
# A race gate: an opening in the local XY plane, passed along -Z.
# The frame has collision, so clipping a gate is a contact. Builds its own look.

signal passed(racer: Node3D, forward: bool)

@export var size := Vector2(4.0, 3.0)
## Frame bar thickness, m.
@export var bar := 0.25

const FRAME := Color(0.08, 0.08, 0.1)
const LIT := Color(1.0, 0.6, 0.2)

var index := 0
var _glow: StandardMaterial3D

func _ready() -> void:
	_build()

## Where a segment from `a` to `b` (world) crosses the opening, if it does.
## Returns 1 for a forward pass, -1 backward, 0 for no pass.
func crossing(a: Vector3, b: Vector3) -> int:
	var inv := global_transform.affine_inverse()
	var la := inv * a
	var lb := inv * b
	if signf(la.z) == signf(lb.z) or la.z == lb.z:
		return 0
	var t := la.z / (la.z - lb.z)
	var p := la.lerp(lb, t)
	if absf(p.x) > size.x * 0.5 or absf(p.y) > size.y * 0.5:
		return 0
	return 1 if la.z > lb.z else -1

## Lights the gate as the racer's next target.
func set_highlight(on: bool) -> void:
	if _glow:
		_glow.emission_energy_multiplier = 1.8 if on else 0.6

func _build() -> void:
	var frame := StandardMaterial3D.new()
	frame.albedo_color = FRAME
	frame.metallic = 0.4
	frame.roughness = 0.5
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = LIT
	_glow.emission_enabled = true
	_glow.emission = LIT
	_glow.emission_energy_multiplier = 0.6
	var w := size.x + bar * 2.0
	var h := size.y + bar * 2.0
	# Top, bottom, left, right bars, each with a thin lit strip on the inner edge.
	var bars := [
		[Vector3(w, bar, bar), Vector3(0, (size.y + bar) * 0.5, 0)],
		[Vector3(w, bar, bar), Vector3(0, -(size.y + bar) * 0.5, 0)],
		[Vector3(bar, h, bar), Vector3(-(size.x + bar) * 0.5, 0, 0)],
		[Vector3(bar, h, bar), Vector3((size.x + bar) * 0.5, 0, 0)],
	]
	for b in bars:
		var mesh := BoxMesh.new()
		mesh.size = b[0]
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = frame
		mi.position = b[1]
		add_child(mi)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = b[0]
		shape.position = b[1]
		add_child(shape)
		var strip := MeshInstance3D.new()
		var strip_mesh := BoxMesh.new()
		var s: Vector3 = b[0]
		strip_mesh.size = Vector3(s.x * 0.98 if s.x > s.y else 0.05, s.y * 0.98 if s.y > s.x else 0.05, bar + 0.02)
		strip.mesh = strip_mesh
		strip.material_override = _glow
		var at: Vector3 = b[1]
		strip.position = at - at.normalized() * (bar * 0.5)
		add_child(strip)
