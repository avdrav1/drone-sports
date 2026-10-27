class_name TargetMarker
extends Control
# Marks the route's next point on screen: a diamond over it when in view, an
# arrow at the screen edge pointing toward it when not, with the distance.
# Shows what the job's guidance allows and nothing without a GPS fix, like the
# radar. Reads the route; never steers.

@export var route: RouteSource
@export var camera_rig: CameraRig
## Distance the edge arrow keeps from the screen border, px.
@export var edge_margin := 56.0

const ACCENT := Color(1.0, 0.76, 0.25)
const LINE := Color(1, 1, 1, 0.9)
const SHADOW := Color(0, 0, 0, 0.45)

var font: Font

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	font = get_theme_default_font()

func _process(_delta: float) -> void:
	queue_redraw()

## The next point the route allows, or null for none.
func target() -> Variant:
	var g := route.guided() if route else PackedVector3Array()
	return g[1] if g.size() > 1 else null

## {pos, on_screen, angle, distance}, or empty when there is nothing to mark.
func marker() -> Dictionary:
	var t: Variant = target()
	var cam := camera_rig.camera if camera_rig else get_viewport().get_camera_3d()
	if t == null or cam == null:
		return {}
	var m := place(cam, get_viewport_rect(), t, edge_margin)
	m.distance = route.drone.global_position.distance_to(t)
	return m

## Where to draw a marker for `world`: {pos, on_screen, angle}. Off screen it sits
## on the inner rect `margin` px from the border, and angle points from the
## screen centre toward the point.
static func place(cam: Camera3D, rect: Rect2, world: Vector3, margin: float) -> Dictionary:
	var center := rect.size * 0.5
	var m := minf(margin, minf(rect.size.x, rect.size.y) * 0.25)
	var behind := cam.is_position_behind(world)
	var p := cam.unproject_position(world)
	if behind:
		p = center - (p - center) # unproject mirrors points behind the camera
	var inner := Rect2(Vector2.ONE * m, rect.size - Vector2.ONE * m * 2.0)
	if not behind and inner.has_point(p):
		return {"pos": p, "on_screen": true, "angle": 0.0}
	var dir := p - center
	if dir.length_squared() < 1.0:
		dir = Vector2.DOWN
	# Scale the direction until it touches the inner rect.
	var half := inner.size * 0.5
	var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	return {"pos": center + dir * k, "on_screen": false, "angle": dir.angle()}

## Draws a placed marker and its distance label onto `ci`.
static func draw_marker(ci: CanvasItem, m: Dictionary, distance: float, f: Font) -> void:
	var c: Vector2 = m.pos
	if m.on_screen:
		var r := 14.0
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)])
		ci.draw_polyline(pts, SHADOW, 5.0)
		ci.draw_polyline(pts, ACCENT, 2.5)
	else:
		var a: float = m.angle
		var tip := c + Vector2.from_angle(a) * 20.0
		var l := c + Vector2.from_angle(a + 2.5) * 16.0
		var rr := c + Vector2.from_angle(a - 2.5) * 16.0
		ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(1, 2), l + Vector2(1, 2), rr + Vector2(1, 2)]), SHADOW)
		ci.draw_colored_polygon(PackedVector2Array([tip, l, rr]), ACCENT)
	var at := c + Vector2(-40, 34)
	var t := "%d m" % roundi(distance)
	ci.draw_string(f, at + Vector2(1, 1), t, HORIZONTAL_ALIGNMENT_CENTER, 80, 14, SHADOW)
	ci.draw_string(f, at, t, HORIZONTAL_ALIGNMENT_CENTER, 80, 14, LINE)

func _draw() -> void:
	var m := marker()
	if not m.is_empty():
		draw_marker(self, m, m.distance, font)
