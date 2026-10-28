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
const BANNER := Color(0.92, 0.9, 0.85)

var index := 0
var _glow: StandardMaterial3D
var _marker: MapMarker

func _ready() -> void:
	_build()
	_marker = MapMarker.new()
	_marker.name = "MapMarker"
	_marker.kind = &"gate"
	_marker.label = "Gate %d" % index
	add_child(_marker)

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
	if _marker:
		_marker.highlighted = on

func _build() -> void:
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = LIT
	_glow.emission_enabled = true
	_glow.emission = LIT
	_glow.emission_energy_multiplier = 0.6
	var w := size.x + bar * 2.0
	var h := size.y + bar * 2.0
	# Top, bottom, left, right bars, each a black box truss with an LED strip on
	# its inner face (Story 15.10). The collision is the bar's box.
	var bars := [
		[Vector3(w, bar, bar), Vector3(0, (size.y + bar) * 0.5, 0)],
		[Vector3(w, bar, bar), Vector3(0, -(size.y + bar) * 0.5, 0)],
		[Vector3(bar, h, bar), Vector3(-(size.x + bar) * 0.5, 0, 0)],
		[Vector3(bar, h, bar), Vector3((size.x + bar) * 0.5, 0, 0)],
	]
	for b in bars:
		var truss := Structure.new()
		truss.kind = Structure.Kind.TRUSS
		truss.size = b[0]
		truss.surface = &"painted_metal"
		truss.tint = FRAME
		truss.paint = 0.9
		truss.grime = 0.15
		truss.position = b[1]
		add_child(truss)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = b[0]
		shape.position = b[1]
		add_child(shape)
		var s: Vector3 = b[0]
		var at: Vector3 = b[1]
		var strip := MeshInstance3D.new()
		strip.mesh = Structure.build(Structure.Kind.PANEL, Vector3(s.x * 0.9 if s.x > s.y else 0.035, s.y * 0.9 if s.y > s.x else 0.035, bar * 0.5))
		strip.material_override = _glow
		strip.position = at - at.normalized() * (bar * 0.5 - 0.018)
		add_child(strip)
	_add_sign(w)

## A banner on the top bar, front and back, with the gate's number, laid flat
## on the truss so it stays inside the bar.
func _add_sign(w: float) -> void:
	var y := (size.y + bar) * 0.5
	for side in [1.0, -1.0]:
		var banner := MeshInstance3D.new()
		banner.mesh = Structure.build(Structure.Kind.PANEL, Vector3(minf(w * 0.5, 2.4), bar * 0.8, 0.01))
		banner.material_override = Structure.material(&"painted_metal", BANNER, 0.95, 0.0, 0.1)
		banner.position = Vector3(0, y, (bar * 0.5 - 0.006) * side)
		add_child(banner)
		var label := Label3D.new()
		label.text = "%d" % index if index > 0 else "START"
		label.font_size = 64
		label.pixel_size = bar * 0.55 / 64.0
		label.modulate = Color(0.08, 0.08, 0.1)
		label.outline_size = 0
		label.double_sided = false
		label.position = Vector3(0, y, bar * 0.5 * side)
		label.rotation.y = 0.0 if side > 0.0 else PI
		add_child(label)
