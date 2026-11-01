class_name MapScreen
extends Control
# Full map (toggle_map, M): a north-up chart of the MapData area with terrain,
# grid, landmarks, markers, and the player's track. An overlay: it never pauses
# the job. The track records while the job is Live, or always with no job.
# Scenes put it on its own CanvasLayer above the HUD and the Act 1 bezel.
# Story 30.7: in the briefing of a job offering the vow of making, the map plans
# a path: a cursor (flight stick or arrows, or the mouse) places, moves and
# removes the runner's points. The path is drawn in its thread's colour, in the
# briefing and in flight.

@export var gps: Gps
## Optional: the ground shaded under the chart.
@export var terrain: DesertTerrain
## Buildings to draw on the image, if any.
@export var city: City
## Optional. With a runner, the track records only while Live.
@export var runner: JobRunner
## Optional: the job's route, drawn dashed.
@export var route: RouteSource
## Chart side as a share of the screen's smaller side.
@export var fill := 0.82
## Seconds between track points.
@export var track_interval := 0.25
@export var max_track_points := 4000
## Planning cursor speed, chart sides per second at full stick.
@export var cursor_speed := 0.4
## How near the cursor, px, picks up a planned point.
@export var pick_px := 12.0

const LINE := FlightHud.LINE
const DIM := FlightHud.DIM
const ACCENT := FlightHud.ACCENT
const SHADOW := FlightHud.SHADOW

## World XZ points, oldest first.
var track: PackedVector2Array = []
var texture: Texture2D
var font: Font
var _since_point := 0.0
## Planning: the cursor in chart px (negative until first placed), and the
## index of the point being moved, or -1.
var cursor := -Vector2.ONE
var held := -1

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	font = get_theme_default_font()
	bake()

## Bakes the ground and the city's lots; again after free flight rerolls the city.
func bake() -> void:
	if terrain and gps and gps.map:
		texture = TerrainImage.bake(terrain, gps.map.bounds, 256, Radar.footprints(city))

## Over the chart's corner, e.g. "NORTH UP  ·  M TO CLOSE" or "... BACK TO CLOSE".
static func close_text() -> String:
	return "NORTH UP  ·  %s TO CLOSE" % InputPrompt.text(&"toggle_map").to_upper()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		toggle()

func toggle() -> void:
	visible = not visible
	held = -1
	if visible and planning() and not chart_rect().has_point(cursor):
		cursor = to_chart(gps.drone.global_position)

## Whether the map is open to plan a path (Story 30.7).
func planning() -> bool:
	return visible and runner != null and runner.can_plan() and gps != null and gps.map != null and gps.drone != null

## The planning keys and buttons, before the job's own: the cursor's press,
## remove, and Esc to close.
func _input(event: InputEvent) -> void:
	if not planning():
		return
	if event is InputEventMouseMotion:
		cursor = _clamp(make_input_local(event).position)
	elif event is InputEventMouseButton and event.pressed:
		cursor = _clamp(make_input_local(event).position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			press()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			remove()
	elif event.is_action_pressed("ui_accept"):
		press()
	elif event.is_action_pressed("reset_drone"):
		remove()
	elif event.is_action_pressed("ui_cancel"):
		toggle()
	else:
		return
	get_viewport().set_input_as_handled()

## At the cursor: put down the point being moved, else pick up the point there,
## else place a new one at the end of the path.
func press() -> void:
	if held >= 0:
		runner.move_point(held, to_world(cursor))
		held = -1
		return
	var i := point_at(cursor)
	if i >= 0:
		held = i
	else:
		runner.place_point(to_world(cursor))

## Removes the point at the cursor, or the last one.
func remove() -> void:
	var i := held if held >= 0 else point_at(cursor)
	held = -1
	runner.remove_point(i if i >= 0 else runner.plan.size() - 1)

## The planned point within pick_px of `px`, or -1.
func point_at(px: Vector2) -> int:
	for i in runner.plan.size():
		if to_chart(runner.plan[i]).distance_to(px) <= pick_px:
			return i
	return -1

func _clamp(px: Vector2) -> Vector2:
	var r := chart_rect()
	return px.clamp(r.position, r.end)

func recording() -> bool:
	return runner == null or runner.state == JobRunner.State.LIVE

func _physics_process(delta: float) -> void:
	if gps == null or gps.drone == null or not recording():
		return
	_since_point += delta
	if _since_point >= track_interval or track.is_empty():
		_since_point = 0.0
		var p := gps.drone.global_position
		track.append(Vector2(p.x, p.z))
		if track.size() > max_track_points:
			track.remove_at(0)

func _process(delta: float) -> void:
	if planning():
		var v := Input.get_vector(&"roll_left", &"roll_right", &"pitch_forward", &"pitch_back")
		var r := chart_rect()
		cursor = _clamp(cursor + v * cursor_speed * maxf(r.size.x, r.size.y) * delta)
	if visible:
		queue_redraw()

## The chart on screen, shaped like the map's bounds and centred.
func chart_rect() -> Rect2:
	var b := gps.map.bounds
	var side := minf(size.x, size.y) * fill
	var k := side / maxf(b.size.x, b.size.y)
	var s := b.size * k
	return Rect2((size - s) * 0.5, s)

## World point to chart px. North (-Z) is up.
func to_chart(world: Vector3) -> Vector2:
	var b := gps.map.bounds
	var r := chart_rect()
	return r.position + (Vector2(world.x, world.z) - b.position) / b.size * r.size

## Chart px to a world point on y = 0.
func to_world(px: Vector2) -> Vector3:
	var b := gps.map.bounds
	var r := chart_rect()
	var xz := b.position + (px - r.position) / r.size * b.size
	return Vector3(xz.x, 0.0, xz.y)

func _draw() -> void:
	if gps == null or gps.map == null or gps.drone == null:
		return
	var map := gps.map
	var r := chart_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.05, 0.75))
	draw_rect(r, Color(0.16, 0.1, 0.08))
	if texture:
		draw_texture_rect(texture, r, false)
	else:
		draw_rect(r, Color(0.32, 0.2, 0.12, 0.55))
	_draw_grid(map, r)
	draw_rect(r, LINE, false, 1.5)
	_text(r.position + Vector2(0, -12), map.title.to_upper(), 17, LINE)
	_text(Vector2(r.end.x - 200, r.position.y - 12), close_text(), 12, DIM, HORIZONTAL_ALIGNMENT_RIGHT, 200)
	for name in map.landmarks:
		var at := to_chart(map.landmarks[name])
		draw_circle(at, 3.0, DIM)
		_text(at + Vector2(6, 4), String(name), 12, DIM)
	_draw_track()
	_draw_plan()
	var leg := route_chart()
	for i in leg.size() - 1:
		draw_dashed_line(leg[i], leg[i + 1], ACCENT, 2.0, 6.0)
	for m in MapMarker.collect(owner if owner else get_tree().root):
		if m.get_parent() == gps.drone:
			continue
		var at := to_chart(m.global_position)
		var lit := m.highlighted
		Radar.draw_icon(self, at, m.icon, 6.0 if lit else 4.5, Radar.marker_color(m))
		if m.label and m.kind != &"gate":
			_text(at + Vector2(8, 4), m.label, 12, LINE)
	_draw_player()

## The route as chart points, drone first. Empty when there is no guidance.
func route_chart() -> PackedVector2Array:
	var out := PackedVector2Array()
	if route:
		for p in route.guided():
			out.append(to_chart(p))
	return out

func _draw_grid(map: MapData, r: Rect2) -> void:
	var b := map.bounds
	var cols := ceili(b.size.x / map.cell_size)
	var rows := ceili(b.size.y / map.cell_size)
	var grid := Color(1, 1, 1, 0.12)
	for i in range(1, cols):
		var x := r.position.x + i * map.cell_size / b.size.x * r.size.x
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), grid, 1.0)
	for j in range(1, rows):
		var y := r.end.y - j * map.cell_size / b.size.y * r.size.y
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), grid, 1.0)
	for i in cols:
		var x := r.position.x + (i + 0.5) * map.cell_size / b.size.x * r.size.x
		_text(Vector2(x - 10, r.end.y + 16), char(65 + i % 26), 12, DIM, HORIZONTAL_ALIGNMENT_CENTER, 20)
	for j in rows:
		var y := r.end.y - (j + 0.5) * map.cell_size / b.size.y * r.size.y
		_text(Vector2(r.position.x - 34, y + 4), "%d" % (j + 1), 12, DIM, HORIZONTAL_ALIGNMENT_RIGHT, 26)

func _draw_track() -> void:
	if track.size() < 2:
		return
	var pts := PackedVector2Array()
	for p in track:
		pts.append(to_chart(Vector3(p.x, 0.0, p.y)))
	draw_polyline(pts, Color(ACCENT, 0.7), 2.0, true)

## The planned path as chart points, the one being moved at the cursor.
func plan_chart() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in runner.plan.size() if runner else 0:
		out.append(cursor if i == held else to_chart(runner.plan[i]))
	return out

## The planned path in its thread's colour: a numbered ring per point, passed
## ones filled; while planning, the cursor and the keys.
func _draw_plan() -> void:
	var v: Vow = runner.making_vow() if runner else null
	if v == null:
		return
	var col := v.deity.colour
	var pts := plan_chart()
	if pts.size() > 1:
		draw_polyline(pts, Color(SHADOW, 0.6), 5.0, true)
		draw_polyline(pts, col, 2.5, true)
	for i in pts.size():
		draw_circle(pts[i], 8.0, Color(col, 0.85) if i < runner.plan_passed else Color(0, 0, 0, 0.55))
		draw_arc(pts[i], 8.0, 0, TAU, 24, col, 2.0, true)
		_text(pts[i] + Vector2(-8, 4), "%d" % (i + 1), 11, LINE, HORIZONTAL_ALIGNMENT_CENTER, 16)
	if not planning():
		return
	draw_arc(cursor, pick_px, 0, TAU, 24, LINE, 1.5, true)
	draw_line(cursor - Vector2(pick_px + 6, 0), cursor - Vector2(pick_px - 4, 0), LINE, 1.5)
	draw_line(cursor + Vector2(pick_px - 4, 0), cursor + Vector2(pick_px + 6, 0), LINE, 1.5)
	draw_line(cursor - Vector2(0, pick_px + 6), cursor - Vector2(0, pick_px - 4), LINE, 1.5)
	draw_line(cursor + Vector2(0, pick_px - 4), cursor + Vector2(0, pick_px + 6), LINE, 1.5)
	var r := chart_rect()
	# The arrows need ControlsHelp's font; the theme's has no arrow glyphs.
	var at := Vector2(r.position.x, r.end.y + 40)
	draw_string(ControlsHelp.font(), at + Vector2(1, 1), plan_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SHADOW)
	draw_string(ControlsHelp.font(), at, plan_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)

## Under the chart while planning, e.g. "PLAN YOUR PATH  ·  3/8  ·
## ← → ↑ ↓ MOVE  ·  SPACE PLACE OR PICK UP  ·  R REMOVE".
func plan_text() -> String:
	var move := InputPrompt.group_text([&"roll_left", &"roll_right", &"pitch_forward", &"pitch_back"], " ")
	return "PLAN YOUR PATH  ·  %d/%d  ·  %s MOVE  ·  %s PLACE OR PICK UP  ·  %s REMOVE" % [runner.plan.size(),
		runner.making_vow().max_points, move.to_upper(), InputPrompt.text(&"ui_accept").to_upper(),
		InputPrompt.text(&"reset_drone").to_upper()]

func _draw_player() -> void:
	var at := to_chart(gps.drone.global_position)
	var f := -gps.drone.global_transform.basis.z
	var dir := Vector2(f.x, f.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector2.UP
	var side := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([at + dir * 10.0, at - dir * 6.0 + side * 6.0, at - dir * 2.0, at - dir * 6.0 - side * 6.0]), ACCENT)
	_text(at + Vector2(10, -8), gps.grid_ref(), 12, ACCENT)

func _text(at: Vector2, t: String, size_px: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, at + Vector2(1, 1), t, align, width, size_px, SHADOW)
	draw_string(font, at, t, align, width, size_px, color)
