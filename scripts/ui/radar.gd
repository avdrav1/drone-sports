class_name Radar
extends Control
# Heading-up radar in the bottom-right corner: the player at the centre, forward
# up. Draws visible MapMarkers over a terrain image; markers out of range sit on
# the rim at their bearing. Drawn in _draw, never by a camera (CLAUDE.md rule 8).

@export var gps: Gps
## Optional: the ground shaded under the blips.
@export var terrain: DesertTerrain
## World metres from the centre to the rim.
@export var range_m := 120.0
@export var radius := 84.0
## Gap between the screen's bottom-right corner and the radar, px.
@export var margin := Vector2(28, 104)

const LINE := FlightHud.LINE
const DIM := FlightHud.DIM
const ACCENT := FlightHud.ACCENT
const DRONE := Color(1.0, 0.45, 0.35)
const RIM_POINTS := 48

var texture: Texture2D
## World XZ the texture covers.
var texture_area: Rect2

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	if terrain and gps and gps.map:
		texture_area = gps.map.bounds.grow(range_m)
		texture = TerrainImage.bake(terrain, texture_area)

func _process(_delta: float) -> void:
	queue_redraw()

func center() -> Vector2:
	return size - margin - Vector2.ONE * radius

## The drone's forward on the ground. North if it points straight up or down.
func _forward() -> Vector3:
	var f := -gps.drone.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD

## Offset from the radar centre, px, for a world point; clamped to the rim.
func radar_point(world: Vector3) -> Dictionary:
	var d := world - gps.drone.global_position
	var f := _forward()
	var right := Vector3(-f.z, 0.0, f.x)
	var p := Vector2(d.dot(right), -d.dot(f)) * radius / range_m
	var rim := p.length() > radius
	if rim:
		p = p.normalized() * radius
	return {"pos": p, "on_rim": rim}

## World point under a radar offset (inverse of radar_point inside the rim).
func world_point(offset: Vector2) -> Vector3:
	var f := _forward()
	var right := Vector3(-f.z, 0.0, f.x)
	var k := range_m / radius
	return gps.drone.global_position + right * offset.x * k - f * offset.y * k

## Every visible marker but the player's own: {marker, pos, on_rim, lit}.
func blips() -> Array:
	var out := []
	var scope: Node = owner if owner else get_tree().root
	for m in MapMarker.collect(scope):
		if m.get_parent() == gps.drone:
			continue
		var p := radar_point(m.global_position)
		out.append({"marker": m, "pos": p.pos, "on_rim": p.on_rim, "lit": m.highlighted})
	return out

func _draw() -> void:
	if gps == null or gps.drone == null:
		return
	var c := center()
	var rim := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in RIM_POINTS:
		var o := Vector2.from_angle(TAU * i / RIM_POINTS) * radius
		rim.append(c + o)
		if texture:
			var w := world_point(o)
			uvs.append((Vector2(w.x, w.z) - texture_area.position) / texture_area.size)
	if texture:
		draw_polygon(rim, PackedColorArray([Color.WHITE]), uvs, texture)
	else:
		draw_colored_polygon(rim, Color(0, 0, 0, 0.3))
	draw_arc(c, radius, 0, TAU, RIM_POINTS, LINE, 1.5, true)
	draw_arc(c, radius * 0.5, 0, TAU, RIM_POINTS, DIM, 1.0, true)
	# North on the rim.
	var north: Vector2 = radar_point(gps.drone.global_position + Vector3.FORWARD * range_m * 10.0).pos
	draw_string(get_theme_default_font(), c + north * 0.86 + Vector2(-20, 5), "N", HORIZONTAL_ALIGNMENT_CENTER, 40, 13, ACCENT)
	for b in blips():
		_blip(c + b.pos, b.marker, b.lit, b.on_rim)
	# The player: a chevron pointing up.
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 6), c + Vector2(0, 3), c + Vector2(-6, 6)]), ACCENT)

func _blip(at: Vector2, m: MapMarker, lit: bool, on_rim: bool) -> void:
	var col := DRONE if m.kind == &"drone" else (ACCENT if lit or m.kind == &"drop" else LINE)
	if on_rim:
		col.a *= 0.6
	var r := 6.0 if lit else 4.0
	match m.icon:
		&"circle":
			draw_circle(at, r, col)
		&"square":
			draw_rect(Rect2(at - Vector2.ONE * r, Vector2.ONE * r * 2.0), col)
		&"triangle":
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, r), at + Vector2(-r, r)]), col)
		_:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), col)
	if lit:
		draw_arc(at, r + 4.0, 0, TAU, 16, col, 1.5, true)
