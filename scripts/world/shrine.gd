class_name Shrine
extends Node3D
# A rooftop shrine to one of the Four (Story 30.8, docs/DEITIES.md "The
# shrines"): a stepped sandstone plinth, their symbol (DeitySymbol) set flat on
# a round dais to be seen from the air, and a ring of lamps that light one by
# one as that thread's vows are kept, up to `lamps`. On the radar and map as the
# symbol, only when near: nothing points the way to it, and no job uses it.
# Meshes only: no body, no collision shape, nothing that can be struck or
# damaged, so a drone flies through it and it never moves anything.

const MARKER_KIND := &"shrine"

@export var deity: Deity
## Lamps round the dais, and so the most that can be lit.
@export var lamps := 8
## The plinth's two steps (width, height), the dais (radius, height) and the
## symbol's side on it, metres.
@export var steps: Array[Vector2] = [Vector2(5.0, 0.5), Vector2(3.8, 0.4)]
@export var dais := Vector2(1.5, 0.3)
@export var symbol_side := 2.6
@export var stone := Color(0.8, 0.66, 0.45)
@export var lamp_metal := Color(0.55, 0.38, 0.2)
@export var flame := Color(1.0, 0.72, 0.32)
## The symbol drawn for the dais and for the radar and map, px.
@export var symbol_px := 256
@export var mark_px := 20

## How many lamps are lit: the vows kept on this thread, capped at `lamps`.
var lit := 0
## The radar and map mark: the symbol, small.
var mark: Texture2D

func _ready() -> void:
	lit = mini(Vows.kept(deity.id), lamps) if deity else 0
	var y := 0.0
	for s in steps:
		var box := BoxMesh.new()
		box.size = Vector3(s.x, s.y, s.x)
		_mesh("Step", box, Vector3(0, y + s.y * 0.5, 0), _stone(1.0))
		y += s.y
	var disc := CylinderMesh.new()
	disc.top_radius = dais.x
	disc.bottom_radius = dais.x
	disc.height = dais.y
	_mesh("Dais", disc, Vector3(0, y + dais.y * 0.5, 0), _stone(0.92))
	var face := QuadMesh.new()
	face.size = Vector2.ONE * symbol_side
	face.orientation = PlaneMesh.FACE_Y
	var ink := StandardMaterial3D.new()
	ink.albedo_texture = _draw_symbol("Symbol", symbol_px)
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	ink.roughness = 0.6
	_mesh("Symbol", face, Vector3(0, y + dais.y + 0.01, 0), ink)
	_lamps(y, (steps[steps.size() - 1].x * 0.5 + dais.x) * 0.5)
	mark = _draw_symbol("Mark", mark_px)
	var marker := MapMarker.new()
	marker.name = "Marker"
	marker.kind = MARKER_KIND
	marker.symbol = mark
	marker.on_rim = false
	add_child(marker)

## The shrine's extent, in its own space: every step, the dais and the lamps.
func extent() -> AABB:
	var out := AABB()
	for m in find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (m as MeshInstance3D).transform * (m as MeshInstance3D).get_aabb()
		out = b if out.size == Vector3.ZERO else out.merge(b)
	return out

func _lamps(top: float, ring: float) -> void:
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.16
	bowl.bottom_radius = 0.09
	bowl.height = 0.1
	var metal := _plain(lamp_metal)
	var tongue := SphereMesh.new()
	tongue.radius = 0.06
	tongue.height = 0.18
	var glow := _plain(flame)
	glow.emission_enabled = true
	glow.emission = flame
	glow.emission_energy_multiplier = 3.0
	for i in lamps:
		var at := Vector3.FORWARD.rotated(Vector3.UP, TAU * (i + 0.5) / lamps) * ring + Vector3.UP * top
		var lamp := _mesh("Lamp%d" % i, bowl, at + Vector3.UP * 0.05, metal)
		lamp.set_meta(&"lit", i < lit)
		if i < lit:
			var f := MeshInstance3D.new()
			f.name = "Flame"
			f.mesh = tongue
			f.material_override = glow
			f.position = Vector3.UP * 0.13
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lamp.add_child(f)

## The deity's symbol drawn once into a texture `px` across.
func _draw_symbol(id: String, px: int) -> Texture2D:
	var view := SubViewport.new()
	view.name = id + "View"
	view.size = Vector2i(px, px)
	view.disable_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var sym := DeitySymbol.new()
	sym.deity = deity
	sym.size = Vector2(px, px)
	sym.custom_minimum_size = Vector2(px, px)
	view.add_child(sym)
	add_child(view)
	return view.get_texture()

func _mesh(id: String, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = id
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	add_child(m)
	return m

func _stone(shade: float) -> StandardMaterial3D:
	var m := _plain(stone * Color(shade, shade, shade))
	m.roughness = 0.9
	return m

static func _plain(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
