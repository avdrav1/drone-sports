class_name RaceHud
extends Control
# Race overlay on top of the flight HUD: position, lap (or on an open course the
# run's gates), split delta against the best lap, and a marker on the next gate (at the screen edge, pointing, when off screen).
# Lights the player's next gate. Reads the course; never changes it. The chosen
# pilot's portrait sits beside the position (Story 7.2).

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
## The pilot's face in the top right corner, twice its old 64 px (Story
## 26.3), with the name, position and lap under it, all clear of the compass
## tape, the briefing line, the Act 1 leaderboard and the ALT gauge at 960x720.
const PILOT_FACE := 128.0
const TOP := 22.0
## Width of the readouts under the face, right-aligned to it, and of what
## they take up (a nine-letter name, POSITION, 10/10).
const READOUTS := 200.0
const READOUT_WIDTH := 90.0

## Seconds against the best lap at the last gate; negative is ahead. NAN when none.
var split_delta := NAN
var _split_age := 0.0
var _lit_gate := -1
var font: Font
## The chosen pilot avatar's face.
var pilot_face: CharacterPortrait

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	font = get_theme_default_font()
	pilot_face = CharacterPortrait.new()
	pilot_face.name = "Pilot"
	pilot_face.character = PlayerProfile.pilot()
	pilot_face.size = Vector2.ONE * PILOT_FACE
	pilot_face.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(pilot_face)
	if course:
		course.gate_passed.connect(_on_gate_passed)

func _process(delta: float) -> void:
	_split_age += delta
	_light_next_gate()
	queue_redraw()

func position_text() -> String:
	return "%d/%d" % [course.place_of(racer), course.racers().size()]

## "LAP" round a loop, "RUN" on an open course.
func lap_label() -> String:
	return "LAP" if course.is_closed() else "RUN"

## Lap n of N, or on an open course the gate the run is on of its gates.
func lap_text() -> String:
	var p = course.progress(racer)
	if not course.is_closed():
		var last := course.gates.size() - 1
		var gate: int = (last if p.finished else p.next) if p.started else 0
		return "%d/%d" % [gate, last]
	var lap := mini(p.laps + 1, course.laps()) if p.started else 1
	return "%d/%d" % [lap, course.laps()]

func split_color() -> Color:
	return AHEAD if split_delta <= 0.0 else BEHIND

## Off for good once the spotter is dead (Story 7.6).
func split_visible() -> bool:
	return not is_nan(split_delta) and _split_age < split_hold and not Consequences.in_effect(&"no_spotter")

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
	return TargetMarker.place(cam, get_viewport_rect(), gate.global_position, edge_margin)

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

## Screen area the pilot, position and lap block covers at top right.
func panel_rect() -> Rect2:
	return Rect2(Vector2(size.x - 28.0 - PILOT_FACE, TOP - 2.0), Vector2(PILOT_FACE, readouts_rect().end.y - TOP + 2.0))

## Screen area of the readouts under the face: the pilot's name, position and
## lap, right-aligned in a column READOUT_WIDTH wide.
func readouts_rect() -> Rect2:
	return Rect2(Vector2(size.x - 28.0 - READOUT_WIDTH, TOP + PILOT_FACE + 4.0), Vector2(READOUT_WIDTH, 106.0))

func _draw() -> void:
	if course == null or racer == null or course.progress(racer) == null:
		return
	var s := size
	var right := s.x - 28.0
	var col := right - READOUTS
	var y := TOP + PILOT_FACE
	pilot_face.position = Vector2(right - PILOT_FACE, TOP)
	_text(Vector2(col, y + 18), pilot_face.character.name.to_upper(), 13, LINE, HORIZONTAL_ALIGNMENT_RIGHT, READOUTS)
	_text(Vector2(col, y + 38), "POSITION", 12, DIM, HORIZONTAL_ALIGNMENT_RIGHT, READOUTS)
	_text(Vector2(col, y + 70), position_text(), 32, LINE, HORIZONTAL_ALIGNMENT_RIGHT, READOUTS)
	_text(Vector2(col, y + 88), lap_label(), 12, DIM, HORIZONTAL_ALIGNMENT_RIGHT, READOUTS)
	_text(Vector2(col, y + 110), lap_text(), 24, LINE, HORIZONTAL_ALIGNMENT_RIGHT, READOUTS)
	if split_visible():
		_text(Vector2(s.x * 0.5 - 100, 190), "%+.2f" % split_delta, 26, split_color(), HORIZONTAL_ALIGNMENT_CENTER, 200)
	var m := marker()
	if m.is_empty():
		return
	TargetMarker.draw_marker(self, m, racer.global_position.distance_to(next_gate().global_position), font)
