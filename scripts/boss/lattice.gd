class_name Lattice
extends Node3D
# The Lattice's shell (docs/BOSS.md): a hollow sphere of captured drones round a
# core. Units are the drone's own body drawn through one MultiMesh, with no
# physics each; contact with the shell is worked out from its shape instead.
#
# Shape, in this node's space, outside in: a lid, the trench (a tunnel running
# round the equator from the entrance at +x for trench_arc degrees), the floor,
# then the hollow inside with the core at the centre. The entrance is a shaft
# down through the lid, covered by units until they are reclaimed (8.3). At the
# far end a shutter shaft drops through the floor to the core's override port.

@export var boss: Boss
@export var material: Material
## Grey for units nobody is missing.
@export var unit_color := Color(0.42, 0.44, 0.48)

## Units: {pos (local), layer, crew (StringName or &"")}.
var units: Array = []
## Unit index -> crew member whose lost drone it is.
var crew_units := {}
## Units covering the entrance, nearest the shaft's centre first.
var entrance_units: Array[int] = []
var entrance_open := false
var multimesh: MultiMesh

var _hidden := {}

func _ready() -> void:
	if boss:
		build()

# --- Shape -----------------------------------------------------------------

func r_out() -> float:
	return boss.radius

func r_in() -> float:
	return boss.radius - boss.lid - boss.tunnel_height - boss.floor

## The tunnel's inner and outer radius (horizontal, from the axis).
func tunnel_span() -> Vector2:
	return Vector2(r_in() + boss.floor, r_out() - boss.lid)

func arc() -> float:
	return deg_to_rad(boss.trench_arc)

## Unit vector from the centre toward the trench at angle a (radians, from +x).
static func toward(a: float) -> Vector3:
	return Vector3(cos(a), 0.0, sin(a))

## Where the override port sits, local: on the core, facing the shutter.
func port() -> Vector3:
	return toward(arc()) * (boss.core_radius + 1.5)

## Angle round from the entrance, radians in (-PI, PI].
static func angle_of(p: Vector3) -> float:
	return atan2(p.z, p.x)

func _in_band(p: Vector3) -> bool:
	return absf(p.y) < boss.trench_width * 0.5

## Arc-length distance from angle `a` along the equator at p's radius.
func _off(p: Vector3, a: float) -> float:
	var rho := Vector2(p.x, p.z).length()
	return absf(wrapf(angle_of(p) - a, -PI, PI)) * rho

func in_tunnel(p: Vector3) -> bool:
	if not _in_band(p):
		return false
	var rho := Vector2(p.x, p.z).length()
	var span := tunnel_span()
	if rho < span.x or rho > span.y:
		return false
	var a := angle_of(p)
	var pad := boss.trench_width * 0.5 / rho
	return a >= -pad and a <= arc() + pad

func in_entrance(p: Vector3) -> bool:
	return _in_band(p) and _off(p, 0.0) < boss.trench_width * 0.5 and Vector2(p.x, p.z).length() >= tunnel_span().y - 0.01

func in_shutter(p: Vector3) -> bool:
	var rho := Vector2(p.x, p.z).length()
	return _in_band(p) and _off(p, arc()) < boss.trench_width * 0.5 and rho <= tunnel_span().x + 0.01 and rho >= r_in() - 0.01

## Solid shell or core at a local point.
func solid(p: Vector3) -> bool:
	var r := p.length()
	if r <= boss.core_radius:
		return true
	if r < r_in() or r > r_out():
		return false
	if in_tunnel(p) or in_shutter(p):
		return false
	if entrance_open and in_entrance(p):
		return false
	return true

const _DIRS := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK,
	Vector3(0.577, 0.577, 0.577), Vector3(-0.577, 0.577, 0.577), Vector3(0.577, -0.577, 0.577), Vector3(0.577, 0.577, -0.577),
	Vector3(-0.577, -0.577, 0.577), Vector3(-0.577, 0.577, -0.577), Vector3(0.577, -0.577, -0.577), Vector3(-0.577, -0.577, -0.577)]

## A sphere of `radius` at world point `at` overlaps the shell or core.
func touching(at: Vector3, radius: float) -> bool:
	var p := to_local(at)
	if solid(p):
		return true
	for d in _DIRS:
		if solid(p + d * radius):
			return true
	return false

## Sweeps a sphere from `a` to `b` (world). Returns how far it got, 0..1; 1 is clear.
func sphere_cast(a: Vector3, b: Vector3, radius: float, step := 0.25) -> float:
	var n := maxi(1, ceili(a.distance_to(b) / step))
	for i in n + 1:
		var t := float(i) / n
		if touching(a.lerp(b, t), radius):
			return maxf(0.0, float(i - 1) / n)
	return 1.0

## World points from outside the shell, down the entrance, round the trench,
## down the shutter, to the port.
func trench_path(step_degrees := 4.0) -> PackedVector3Array:
	var span := tunnel_span()
	var mid := (span.x + span.y) * 0.5
	var out := PackedVector3Array([toward(0.0) * (r_out() + 12.0), toward(0.0) * (r_out() + 2.0), toward(0.0) * mid])
	var steps := ceili(boss.trench_arc / step_degrees)
	for i in range(1, steps + 1):
		out.append(toward(arc() * i / steps) * mid)
	out.append(toward(arc()) * (r_in() - 2.0))
	out.append(port())
	var world := PackedVector3Array()
	for p in out:
		world.append(to_global(p))
	return world

# --- Units -----------------------------------------------------------------

## Layers: the outer skin (lid), the tunnel's walls, the floor.
func layer_radii() -> PackedFloat32Array:
	var span := tunnel_span()
	return PackedFloat32Array([r_out() - 1.0, (span.x + span.y) * 0.5, r_in() + 1.0])

func build() -> void:
	units.clear()
	crew_units.clear()
	entrance_units.clear()
	var radii := layer_radii()
	for layer in radii.size():
		var r := radii[layer]
		var n := maxi(1, roundi(boss.unit_count * pow(r / r_out(), 2.0)))
		var golden := PI * (3.0 - sqrt(5.0))
		for i in n:
			var y := 1.0 - (i + 0.5) / n * 2.0
			var ring := sqrt(1.0 - y * y)
			var p := Vector3(cos(golden * i) * ring, y, sin(golden * i) * ring) * r
			if in_tunnel(p) or in_shutter(p):
				continue
			if layer == 0 and in_entrance(p):
				entrance_units.append(units.size())
			units.append({"pos": p, "layer": layer, "crew": &""})
	entrance_units.sort_custom(func(a, b): return _off(units[a].pos, 0.0) + absf(units[a].pos.y) < _off(units[b].pos, 0.0) + absf(units[b].pos.y))
	# The crew's lost drones: one each, on the outer skin, away from the entrance.
	var rng := RandomNumberGenerator.new()
	rng.seed = boss.seed
	var outer := range(units.size()).filter(func(i): return units[i].layer == 0 and not i in entrance_units)
	for id in FleetCrew.tagged():
		var pick: int = outer[rng.randi() % outer.size()]
		while crew_units.has(pick):
			pick = outer[rng.randi() % outer.size()]
		crew_units[pick] = id
		units[pick].crew = id
	_draw_units()

func _draw_units() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = DroneLook.still_mesh()
	multimesh.instance_count = units.size()
	for i in units.size():
		multimesh.set_instance_transform(i, unit_transform(i))
		multimesh.set_instance_color(i, color_of(i))
	var mmi := get_node_or_null("Units") as MultiMeshInstance3D
	if mmi == null:
		mmi = MultiMeshInstance3D.new()
		mmi.name = "Units"
		add_child(mmi)
	mmi.multimesh = multimesh
	mmi.material_override = material

## A unit's colour: its crew member's, if it is one of their lost drones.
func color_of(i: int) -> Color:
	var id: StringName = units[i].crew
	return Roster.character(id).colors[0] if id != &"" else unit_color

## A unit standing on the sphere, belly to the core, scaled up.
func unit_transform(i: int) -> Transform3D:
	if _hidden.has(i):
		return Transform3D(Basis().scaled(Vector3.ZERO), units[i].pos)
	var p: Vector3 = units[i].pos
	var up := p.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.99 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	return Transform3D(Basis(side, up, -fwd).scaled(Vector3.ONE * boss.unit_scale), p)

## Draws a unit moved by `offset` from its place, e.g. falling free.
func offset_unit(i: int, offset: Vector3) -> void:
	if multimesh and not _hidden.has(i):
		var t := unit_transform(i)
		t.origin += offset
		multimesh.set_instance_transform(i, t)

## Takes a unit out of the shell (reclaimed, or fallen free).
func hide_unit(i: int) -> void:
	_hidden[i] = true
	if multimesh:
		multimesh.set_instance_transform(i, unit_transform(i))

func show_unit(i: int) -> void:
	_hidden.erase(i)
	if multimesh:
		multimesh.set_instance_transform(i, unit_transform(i))

func is_hidden(i: int) -> bool:
	return _hidden.has(i)

## Units still in the shell.
func remaining() -> int:
	return units.size() - _hidden.size()
