class_name RaceHud
extends Control
# Race overlay on top of the flight HUD: position, lap, split delta against the
# best lap, and a marker on the next gate (at the screen edge, pointing, when off screen).
# Lights the player's next gate. Reads the course; never changes it.

@export var course: Course
## The player's racer, usually their Drone.
@export var racer: Node3D
@export var camera_rig: CameraRig
## Seconds a split delta stays up after a gate.
@export var split_hold := 3.0
## Distance the edge marker keeps from the screen border, px.
@export var edge_margin := 48.0

const LINE := Color(1, 1, 1, 0.9)
const DIM := Color(1, 1, 1, 0.35)
const ACCENT := Color(1.0, 0.76, 0.25)
const AHEAD := Color(0.35, 0.95, 0.45)
const BEHIND := Color(1.0, 0.32, 0.25)
const SHADOW := Color(0, 0, 0, 0.35)

## Seconds against the best lap at the last gate; negative is ahead. NAN when none.
var split_delta := NAN
var _split_age := 0.0
var _lit_gate := -1
var font: Font

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	font = get_theme_default_font()
	if course:
		course.gate_passed.connect(_on_gate_passed)

func _process(delta: float) -> void:
	_split_age += delta
	_light_next_gate()
	queue_redraw()

func position_text() -> String:
	return "%d/%d" % [course.place_of(racer), course.racers().size()]

func lap_text() -> String:
	var p = course.progress(racer)
	var lap := mini(p.laps + 1, course.laps()) if p.started else 1
	return "%d/%d" % [lap, course.laps()]

func split_color() -> Color:
	return AHEAD if split_delta <= 0.0 else BEHIND

func split_visible() -> bool:
	return not is_nan(split_delta) and _split_age < split_hold

func next_gate() -> Gate:
	var p = course.progress(racer)
	return course.gates[p.next] if p and not p.finished else null

## Where to draw the next-gate marker: {pos, on_screen, angle}. Angle points from
## screen centre toward the gate, for the edge arrow.
func marker() -> Dictionary:
	var gate := next_gate()
	var cam := camera_rig.camera if camera_rig else get_viewport().get_camera_3d()
	if gate == null or cam == null:
		return {}
	var rect := get_viewport_rect()
	var center := rect.size * 0.5
	var world := gate.global_position
	var behind := cam.is_position_behind(world)
	var p := cam.unproject_position(world)
	if behind:
		p = center - (p - center) # unproject mirrors points behind the camera
	var m := margin()
	var inner := Rect2(Vector2.ONE * m, rect.size - Vector2.ONE * m * 2.0)
	if not behind and inner.has_point(p):
		return {"pos": p, "on_screen": true, "angle": 0.0}
	var dir := (p - center)
	if dir.length_squared() < 1.0:
		dir = Vector2.DOWN
	# Scale the direction until it touches the inner rect.
	var half := inner.size * 0.5
	var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	return {"pos": center + dir * k, "on_screen": false, "angle": dir.angle()}

## Edge margin, shrunk on tiny viewports so the inner rect never inverts.
func margin() -> float:
	var r := get_viewport_rect().size
	return minf(edge_margin, minf(r.x, r.y) * 0.25)

func _on_gate_passed(who: Node3D, gate: int) -> void:
	if who != racer:
		return
	var p = course.progress(who)
	if p.best_splits.has(gate) and p.splits.has(gate):
		split_delta = p.splits[gate] - p.best_splits[gate]
		_split_age = 0.0

func _light_next_gate() -> void:
	var gate := next_gate()
	var index := gate.index if gate else -1
	if index == _lit_gate:
		return
	if _lit_gate >= 0:
		course.gates[_lit_gate].set_highlight(false)
	if gate:
		gate.set_highlight(true)
	_lit_gate = index

func _text(at: Vector2, t: String, size_px: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, at + Vector2(1, 1), t, align, width, size_px, SHADOW)
	draw_string(font, at, t, align, width, size_px, color)

func _draw() -> void:
	if course == null or racer == null or course.progress(racer) == null:
		return
	var s := size
	var right := s.x - 28.0
	_text(Vector2(right - 200, 40), "POSITION", 12, DIM, HORIZONTAL_ALIGNMENT_RIGHT, 200)
	_text(Vector2(right - 200, 74), position_text(), 32, LINE, HORIZONTAL_ALIGNMENT_RIGHT, 200)
	_text(Vector2(right - 200, 100), "LAP", 12, DIM, HORIZONTAL_ALIGNMENT_RIGHT, 200)
	_text(Vector2(right - 200, 128), lap_text(), 24, LINE, HORIZONTAL_ALIGNMENT_RIGHT, 200)
	if split_visible():
		_text(Vector2(s.x * 0.5 - 100, 190), "%+.2f" % split_delta, 26, split_color(), HORIZONTAL_ALIGNMENT_CENTER, 200)
	var m := marker()
	if m.is_empty():
		return
	var c: Vector2 = m.pos
	if m.on_screen:
		var r := 11.0
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)])
		draw_polyline(pts, ACCENT, 2.0)
	else:
		var a: float = m.angle
		var tip := c + Vector2.from_angle(a) * 14.0
		var l := c + Vector2.from_angle(a + 2.5) * 12.0
		var rr := c + Vector2.from_angle(a - 2.5) * 12.0
		draw_colored_polygon(PackedVector2Array([tip, l, rr]), ACCENT)
	var dist := racer.global_position.distance_to(next_gate().global_position)
	_text(c + Vector2(-40, 30), "%d m" % roundi(dist), 12, LINE, HORIZONTAL_ALIGNMENT_CENTER, 80)
