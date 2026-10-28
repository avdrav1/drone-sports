class_name Structure
extends MeshInstance3D
# The visible body of a gate bar or job prop (Story 15.10): a truss, beam, deck,
# pier, block wall, brick wall, or panel built at its collision box's size, so it reads as a
# real object while the box it stands in for still does all the colliding. Every
# part stays inside that box. Surfaces are 15.2 sets mapped in the piece's own
# space (structure.gdshader), so loose debris keeps its texture as it falls.

enum Kind { PANEL, BLOCKS, PIER, BEAM, TRUSS, DECK, WALL }

## Surfaces a built mesh may have, by name: the body, painted trim, and lamps.
const MAIN := &"main"
const TRIM := &"trim"
const LAMP := &"lamp"
const SHADER := preload("res://scenes/world/structure.gdshader")
## Vertex colour R holds metres below the piece's top over this, for rain streaks.
const STREAK_RANGE := 40.0

@export var kind := Kind.PANEL
## The collision box this stands in for, m.
@export var size := Vector3.ONE
## SurfaceSet id of the body.
@export var surface: StringName = &"concrete"
## Paint or palette colour, and how far the body moves to it (0 the photo, 1 paint).
@export var tint := Color(1, 1, 1)
@export_range(0.0, 1.0) var paint := 0.0
@export_range(0.0, 1.0) var metallic := 0.0
## Rain streaks under the top, dust at the base, colour patches.
@export_range(0.0, 1.0) var grime := 0.5
## Trim: a pier's hazard band, a deck's frame, a wall's concrete band.
@export var trim_surface: StringName = &"painted_metal"
@export var trim_tint := Color(0.85, 0.62, 0.12)
@export_range(0.0, 1.0) var trim_paint := 0.85
@export var lamp_color := Color(1.0, 0.25, 0.15)

static var _meshes := {}
static var _materials := {}

func _ready() -> void:
	mesh = build(kind, size)
	for i in mesh.get_surface_count():
		set_surface_override_material(i, _material_for(mesh.surface_get_name(i)))

func _material_for(part: StringName) -> Material:
	match part:
		TRIM:
			return material(trim_surface, trim_tint, trim_paint, 0.0, maxf(grime, 0.3), kind == Kind.PIER)
		LAMP:
			return lamp(lamp_color)
	return material(surface, tint, paint, metallic, grime)

## The shared material for a surface set at a paint and grime.
static func material(set_id: StringName, color: Color, paint_amount: float, metal: float, dirt: float, stripes := false) -> Material:
	var key := [set_id, color, paint_amount, metal, dirt, stripes]
	if not _materials.has(key):
		var s := SurfaceSet.named(set_id)
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("albedo_map", s.albedo)
		m.set_shader_parameter("nr_map", s.normal_rough)
		m.set_shader_parameter("tile_size", s.tile_size)
		m.set_shader_parameter("tint", Vector3(color.r, color.g, color.b))
		m.set_shader_parameter("paint", paint_amount)
		m.set_shader_parameter("metallic", metal)
		m.set_shader_parameter("grime", dirt)
		m.set_shader_parameter("stripes", 1.0 if stripes else 0.0)
		_materials[key] = m
	return _materials[key]

## An unlit lamp lens, glowing above the tonemap's glow threshold.
static func lamp(color: Color, energy := 1.4) -> StandardMaterial3D:
	var key := [&"lamp", color, energy]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		_materials[key] = m
	return _materials[key]

## The mesh for `kind` filling a box of `box_size` centred on the origin. Cached.
static func build(k: Kind, box_size: Vector3) -> ArrayMesh:
	var key := [k, box_size]
	if not _meshes.has(key):
		var b := Builder.new(box_size)
		match k:
			Kind.PANEL:
				b.chamfered(Vector3.ZERO, box_size, minf(0.03, _minor(box_size) * 0.2))
			Kind.BLOCKS:
				_blocks(b, box_size)
			Kind.PIER:
				_pier(b, box_size)
			Kind.BEAM:
				_beam(b, box_size)
			Kind.TRUSS:
				_truss(b, box_size)
			Kind.DECK:
				_deck(b, box_size)
			Kind.WALL:
				_wall(b, box_size)
		_meshes[key] = b.commit()
	return _meshes[key]

static func _minor(v: Vector3) -> float:
	return minf(v.x, minf(v.y, v.z))

## The index of the longest axis, and two others: `up` (y unless y is the long
## axis) and `side`.
static func _axes(v: Vector3) -> Array[int]:
	var a := 0 if v.x >= v.y and v.x >= v.z else (1 if v.y >= v.z else 2)
	var up := 1 if a != 1 else 2
	return [a, up, 3 - a - up]

static func _unit(i: int) -> Vector3:
	return [Vector3.RIGHT, Vector3.UP, Vector3.BACK][i]

## Precast interlocking blocks about 1.6 x 0.8 m in running bond, full depth.
static func _blocks(b: Builder, s: Vector3) -> void:
	var along := 0 if s.x >= s.z else 2
	var length := s[along]
	var n := maxi(1, roundi(length / 1.6))
	var courses := maxi(1, roundi(s.y / 0.8))
	var bl := length / n
	var ch := s.y / courses
	var rng := RandomNumberGenerator.new()
	rng.seed = 15010
	for c in courses:
		var y := -s.y * 0.5 + ch * (c + 0.5)
		# Odd courses start and end with a half block.
		var cuts: Array[float] = [-length * 0.5]
		var x := -length * 0.5 + (bl * 0.5 if c % 2 == 1 else bl)
		while x < length * 0.5 - 0.01:
			cuts.append(x)
			x += bl
		cuts.append(length * 0.5)
		for i in cuts.size() - 1:
			var center := Vector3.ZERO
			center[along] = (cuts[i] + cuts[i + 1]) * 0.5
			center.y = y
			var piece := s
			piece[along] = cuts[i + 1] - cuts[i]
			piece.y = ch
			b.shade = rng.randf_range(0.3, 0.7)
			b.chamfered(center, piece, 0.04)
	b.shade = 0.5

## A brick wall panel under a concrete band (a floor edge or coping) along its top.
static func _wall(b: Builder, s: Vector3) -> void:
	var band := minf(0.35, s.y * 0.12)
	b.chamfered(Vector3(0, -band * 0.5, 0), Vector3(s.x, s.y - band, s.z), 0.015)
	b.part = TRIM
	b.chamfered(Vector3(0, s.y * 0.5 - band * 0.5, 0), Vector3(s.x, band, s.z), 0.02)
	b.part = MAIN

## A concrete pier: footing and cap at full size, the shaft just inside them,
## a hazard band above the footing, and obstruction lamps under the cap.
static func _pier(b: Builder, s: Vector3) -> void:
	var h := s * 0.5
	var foot := minf(0.6, s.y * 0.1)
	var cap := minf(0.4, s.y * 0.08)
	var inset := minf(0.08, _minor(s) * 0.05)
	var shaft := Vector3(s.x - inset * 2.0, s.y - foot - cap, s.z - inset * 2.0)
	b.chamfered(Vector3(0, -h.y + foot * 0.5, 0), Vector3(s.x, foot, s.z), 0.04)
	b.chamfered(Vector3(0, -h.y + foot + shaft.y * 0.5, 0), shaft, 0.03)
	b.chamfered(Vector3(0, h.y - cap * 0.5, 0), Vector3(s.x, cap, s.z), 0.04)
	b.part = TRIM
	var band := minf(1.0, shaft.y * 0.15)
	var gap := minf(0.2, shaft.y * 0.1)
	b.box(Vector3(0, -h.y + foot + gap + band * 0.5, 0), Vector3(s.x - inset, band, s.z - inset))
	b.part = LAMP
	var lamp_size := minf(0.18, shaft.y * 0.2)
	var y := h.y - cap - gap - lamp_size * 0.5
	for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var out: Vector3 = dir * (Vector3(shaft.x, 0, shaft.z) * 0.5 + Vector3.ONE * inset * 0.5)
		b.box(Vector3(out.x, y, out.z), Vector3.ONE * lamp_size - dir.abs() * (lamp_size - inset))
	b.part = MAIN

## A wide-flange steel beam along the long axis, with end plates.
static func _beam(b: Builder, s: Vector3) -> void:
	var ax := _axes(s)
	var a := _unit(ax[0])
	var u := _unit(ax[1])
	var w := _unit(ax[2])
	var length := s[ax[0]]
	var depth := s[ax[1]]
	var width := s[ax[2]]
	var flange := clampf(depth * 0.1, 0.012, 0.05)
	var web := clampf(width * 0.07, 0.01, 0.03)
	var plate := minf(0.02, length * 0.02)
	var inner := length - plate * 2.0
	for sgn in [-1.0, 1.0]:
		b.box(u * (depth * 0.5 - flange * 0.5) * sgn, a * inner + u * flange + w * width)
		b.box(a * (length * 0.5 - plate * 0.5) * sgn, a * plate + u * depth + w * width)
	b.box(Vector3.ZERO, a * inner + u * (depth - flange * 2.0) + w * web)

## A box truss along the long axis: a square chord at each corner, laced on every
## face with diagonals at about 45 degrees, and a batten frame at each end and
## every few bays.
static func _truss(b: Builder, s: Vector3) -> void:
	var ax := _axes(s)
	var a := _unit(ax[0])
	var length := s[ax[0]]
	var cross := minf(s[ax[1]], s[ax[2]])
	var chord := clampf(cross * 0.14, 0.03, 0.08)
	var lace := chord * 0.5
	var hu := s[ax[1]] * 0.5 - chord * 0.5
	var hw := s[ax[2]] * 0.5 - chord * 0.5
	var u := _unit(ax[1])
	var w := _unit(ax[2])
	for su in [-1.0, 1.0]:
		for sw in [-1.0, 1.0]:
			b.box(u * hu * su + w * hw * sw, a * length + (u + w) * chord)
	var bays := maxi(1, roundi(length / cross))
	var bay := length / bays
	var start := -length * 0.5
	# Faces: [the face's normal offset, the axis across it, half its width].
	var faces := [[u * hu, w, hw], [-u * hu, w, hw], [w * hw, u, hu], [-w * hw, u, hu]]
	for f in faces:
		var plane: Vector3 = f[0]
		var across: Vector3 = f[1]
		var half: float = f[2]
		for i in bays:
			var flip := 1.0 if i % 2 == 0 else -1.0
			# Ends pulled in by a lace width so the bar's corners stay in the box.
			var p0 := plane + a * (start + bay * i + lace) - across * half * flip
			var p1 := plane + a * (start + bay * (i + 1) - lace) + across * half * flip
			b.strut(p0, p1, plane.normalized(), lace)
	var every := maxi(1, roundi(6.0 / bay))
	for i in bays + 1:
		if i % every != 0 and i != bays:
			continue
		var at := a * clampf(start + bay * i, start + lace * 0.5, -start - lace * 0.5)
		for f in faces:
			var plane: Vector3 = f[0]
			var across: Vector3 = f[1]
			var half: float = f[2]
			b.box(at + plane, a * lace + across * half * 2.0 + plane.normalized().abs() * lace)

## A steel platform: a channel frame round the edge, joists under a top plate.
static func _deck(b: Builder, s: Vector3) -> void:
	var h := s * 0.5
	var rim := clampf(_minor(s) * 0.15, 0.04, 0.08)
	var plate := minf(0.03, s.y * 0.2)
	b.box(Vector3(0, h.y - plate * 0.5, 0), Vector3(s.x - rim * 2.0, plate, s.z - rim * 2.0))
	b.part = TRIM
	for sgn in [-1.0, 1.0]:
		b.box(Vector3(0, 0, (h.z - rim * 0.5) * sgn), Vector3(s.x, s.y, rim))
		b.box(Vector3((h.x - rim * 0.5) * sgn, 0, 0), Vector3(rim, s.y, s.z - rim * 2.0))
	var joists := maxi(1, roundi(s.x / 1.2) - 1)
	for i in joists:
		var x := -h.x + s.x * (i + 1) / (joists + 1)
		b.box(Vector3(x, h.y - plate - s.y * 0.3, 0), Vector3(rim * 0.6, s.y * 0.6 - plate, s.z - rim * 2.0))
	b.part = MAIN

## Collects flat-shaded triangles per part, with metres below the top in COLOR.r
## and a per-piece shade in COLOR.b.
class Builder:
	var part := MAIN
	var shade := 0.5
	var top := 0.0
	var _tools := {}

	func _init(box_size: Vector3) -> void:
		top = box_size.y * 0.5

	func _st() -> SurfaceTool:
		if not _tools.has(part):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_tools[part] = st
		return _tools[part]

	## One triangle, wound to face `out`.
	func tri(p: Vector3, q: Vector3, r: Vector3, out: Vector3) -> void:
		var n := (q - p).cross(r - p)
		if n.dot(out) > 0.0:
			var t := q
			q = r
			r = t
			n = -n
		var st := _st()
		st.set_normal(-n.normalized())
		for v in [p, q, r]:
			st.set_color(Color(clampf((top - v.y) / STREAK_RANGE, 0.0, 1.0), 0.0, shade))
			st.add_vertex(v)

	func quad(p: Vector3, q: Vector3, r: Vector3, t: Vector3, out: Vector3) -> void:
		tri(p, q, r, out)
		tri(p, r, t, out)

	## A box from a centre and its three full-length edge vectors.
	func oriented(c: Vector3, ex: Vector3, ey: Vector3, ez: Vector3) -> void:
		var e := [ex * 0.5, ey * 0.5, ez * 0.5]
		for i in 3:
			var n: Vector3 = e[i]
			var j: Vector3 = e[(i + 1) % 3]
			var k: Vector3 = e[(i + 2) % 3]
			for sgn in [-1.0, 1.0]:
				var f: Vector3 = c + n * sgn
				quad(f - j - k, f + j - k, f + j + k, f - j + k, n * sgn)

	## An axis-aligned box.
	func box(c: Vector3, s: Vector3) -> void:
		oriented(c, Vector3(s.x, 0, 0), Vector3(0, s.y, 0), Vector3(0, 0, s.z))

	## A square bar of `width` from p to q, its faces turned square to `normal`.
	func strut(p: Vector3, q: Vector3, normal: Vector3, width: float) -> void:
		var along := q - p
		var side := along.cross(normal).normalized() * width
		oriented((p + q) * 0.5, along, normal * width, side)

	## An axis-aligned box with its edges and corners cut back by `c`.
	func chamfered(center: Vector3, s: Vector3, c: float) -> void:
		var h := s * 0.5
		var i := h - Vector3.ONE * minf(c, minf(h.x, minf(h.y, h.z)) * 0.9)
		for ax in 3:
			var a := _axis(ax)
			var b := _axis((ax + 1) % 3)
			var d := _axis((ax + 2) % 3)
			for sa in [-1.0, 1.0]:
				# Face.
				var f: Vector3 = center + a * h[ax] * sa
				var jb := b * i[(ax + 1) % 3]
				var jd := d * i[(ax + 2) % 3]
				quad(f - jb - jd, f + jb - jd, f + jb + jd, f - jb + jd, a * sa)
				for sb in [-1.0, 1.0]:
					# Edge between this face and the next axis's face.
					var p: Vector3 = center + a * h[ax] * sa + b * i[(ax + 1) % 3] * sb
					var q: Vector3 = center + a * i[ax] * sa + b * h[(ax + 1) % 3] * sb
					quad(p - jd, q - jd, q + jd, p + jd, a * sa + b * sb)
					for sd in [-1.0, 1.0]:
						if ax == 0:
							# Corner, once per octant.
							var o := Vector3(sa, sb, sd)
							tri(center + Vector3(h.x, i.y, i.z) * o, center + Vector3(i.x, h.y, i.z) * o,
								center + Vector3(i.x, i.y, h.z) * o, o)

	func _axis(i: int) -> Vector3:
		return [Vector3.RIGHT, Vector3.UP, Vector3.BACK][i]

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for p in [MAIN, TRIM, LAMP]:
			if _tools.has(p):
				_tools[p].commit(mesh)
				mesh.surface_set_name(mesh.get_surface_count() - 1, p)
		return mesh
