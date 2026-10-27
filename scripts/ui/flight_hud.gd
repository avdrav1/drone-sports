class_name FlightHud
extends Control
# Thin-line flight HUD: compass tape at top, speed and altitude at the sides,
# job panel at top left, assists at bottom left, battery at bottom right,
# GPS fix above the battery.
# Reads the drone and an optional JobRunner; draws everything in _draw.
# Heading: 0 is north (-Z), 90 east (+X), 270 west.

@export var drone: Drone
## Optional. When set, the panel shows its job and objectives.
@export var runner: JobRunner
## Optional. When set, shows the GPS signal and grid reference.
@export var gps: Gps
## Panel title when there is no runner.
@export var title := ""
## Panel subtitle when there is no runner, e.g. the assist preset.
var subtitle := ""

const LINE := Color(1, 1, 1, 0.9)
const DIM := Color(1, 1, 1, 0.35)
const ACCENT := Color(1.0, 0.76, 0.25)
const SHADOW := Color(0, 0, 0, 0.35)
const ASSIST_NAMES := {
	&"collision_guard": "GUARD", &"brake": "BRAKE", &"altitude_hold": "ALT HOLD", &"auto_level": "LEVEL",
	&"speed_governor": "GOVERNOR", &"battery_wind": "ENV SIM", &"single_drone_view": "SOLO VIEW",
}
const TAPE_SPAN := 120.0

var font: Font

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	font = get_theme_default_font()

func _process(_delta: float) -> void:
	queue_redraw()

func heading() -> float:
	var f := -drone.global_transform.basis.z
	return fposmod(rad_to_deg(atan2(f.x, -f.z)), 360.0)

func speed_kmh() -> float:
	return drone.linear_velocity.length() * 3.6

func altitude() -> float:
	return drone.global_position.y

## Title, subtitle, job state, then one {label, done} per objective.
func panel() -> Dictionary:
	if runner and runner.job:
		var rows := []
		for o in runner.objectives():
			rows.append({"label": o.label if o.label else String(o.name), "done": o.is_done()})
		var sub := runner.job.client + ("  ·  %d" % runner.job.pay if runner.job.pay else "")
		return {"title": runner.job.title.to_upper(), "subtitle": sub, "state": _state_line(), "rows": rows}
	return {"title": title.to_upper(), "subtitle": subtitle, "state": "", "rows": []}

func _state_line() -> String:
	var name: String = JobRunner.State.keys()[runner.state]
	if runner.state == JobRunner.State.LIVE:
		return "%s  %.1f S" % [name, runner.live_time]
	return name

## Assist id -> on, in pipeline order (single-drone view last).
func assist_states() -> Dictionary:
	var out := {}
	for id in AssistStack.IDS:
		out[id] = drone.assists.is_enabled(id) if drone.assists and id != &"single_drone_view" else true
	return out

func _draw() -> void:
	if drone == null:
		return
	var s := size
	_draw_tape(Vector2(s.x * 0.5, 34.0), minf(s.x * 0.42, 560.0))
	_draw_gauge(Vector2(64.0, s.y * 0.5), "SPD", "%d" % roundi(speed_kmh()), "KM/H", false)
	_draw_gauge(Vector2(s.x - 64.0, s.y * 0.5), "ALT", "%d" % roundi(altitude()), "M", true)
	_draw_panel(Vector2(28.0, 26.0))
	_draw_assists(Vector2(28.0, s.y - 34.0))
	_draw_battery(Vector2(s.x - 28.0, s.y - 34.0))
	if gps:
		_draw_gps(Vector2(s.x - 28.0, s.y - 76.0))

func _text(at: Vector2, t: String, size_px: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, at + Vector2(1, 1), t, align, width, size_px, SHADOW)
	draw_string(font, at, t, align, width, size_px, color)

func _draw_tape(center: Vector2, width: float) -> void:
	var h := heading()
	var px_per_deg := width / TAPE_SPAN
	var first := ceili((h - TAPE_SPAN * 0.5) / 10.0) * 10
	for deg in range(first, int(h + TAPE_SPAN * 0.5) + 1, 10):
		var x := center.x + (deg - h) * px_per_deg
		var fade := 1.0 - absf(deg - h) / (TAPE_SPAN * 0.5)
		var col := Color(LINE, LINE.a * fade)
		var d := posmod(deg, 360)
		if d % 30 == 0:
			draw_line(Vector2(x, center.y - 8), Vector2(x, center.y + 4), col, 1.5)
			var cardinal: String = {0: "N", 90: "E", 180: "S", 270: "W"}.get(d, "%d" % d)
			_text(Vector2(x - 30, center.y + 22), cardinal, 15, ACCENT if cardinal.length() == 1 else col, HORIZONTAL_ALIGNMENT_CENTER, 60)
		else:
			draw_line(Vector2(x, center.y - 3), Vector2(x, center.y + 4), Color(col, col.a * 0.6), 1.0)
	# Pointer under the tape.
	draw_colored_polygon(PackedVector2Array([center + Vector2(-6, -16), center + Vector2(6, -16), center + Vector2(0, -9)]), ACCENT)
	_text(Vector2(center.x - 30, center.y + 44), "%03d" % (roundi(h) % 360), 13, DIM, HORIZONTAL_ALIGNMENT_CENTER, 60)

## A vertical ladder with a big readout beside it.
func _draw_gauge(at: Vector2, name: String, value: String, unit: String, right: bool) -> void:
	var dir := -1.0 if right else 1.0
	var x := at.x
	draw_line(Vector2(x, at.y - 60), Vector2(x, at.y + 60), DIM, 1.0)
	for i in range(-6, 7):
		var w := 10.0 if i % 3 == 0 else 5.0
		draw_line(Vector2(x, at.y + i * 10), Vector2(x - w * dir, at.y + i * 10), DIM, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(x, at.y - 5), Vector2(x, at.y + 5), Vector2(x + 8 * dir, at.y)]), ACCENT)
	var tx := x + 18.0 * dir
	var align := HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	var left := tx - 160.0 if right else tx
	_text(Vector2(left, at.y - 26), name, 14, DIM, align, 160)
	_text(Vector2(left, at.y + 12), value, 34, LINE, align, 160)
	_text(Vector2(left, at.y + 32), unit, 13, DIM, align, 160)

func _draw_panel(at: Vector2) -> void:
	var p := panel()
	var y := at.y + 64
	if p.state:
		_text(Vector2(at.x + 14, y - 4), p.state, 12, DIM)
		y += 20
	draw_line(at, Vector2(at.x, y - 18 + 22 * p.rows.size()), ACCENT, 2.0)
	_text(at + Vector2(14, 16), p.title, 17, LINE)
	_text(at + Vector2(14, 38), p.subtitle, 15, ACCENT)
	for row in p.rows:
		_diamond(Vector2(at.x + 20, y - 5), 5.0, row.done)
		_text(Vector2(at.x + 34, y), row.label, 14, LINE if not row.done else DIM)
		y += 22

func _diamond(c: Vector2, r: float, filled: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if filled:
		draw_colored_polygon(pts, ACCENT)
	else:
		pts.append(pts[0])
		draw_polyline(pts, LINE, 1.5)

func _draw_assists(at: Vector2) -> void:
	_text(at + Vector2(0, -24), "ASSISTS", 12, DIM)
	var x := at.x
	var states := assist_states()
	for id in states:
		var on: bool = states[id]
		var label: String = ASSIST_NAMES[id]
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
		var rect := Rect2(x, at.y - 14, w, 22)
		if on:
			draw_rect(rect, Color(ACCENT, 0.18))
		draw_rect(rect, ACCENT if on else DIM, false, 1.0)
		_text(Vector2(x + 7, at.y + 2), label, 12, LINE if on else DIM)
		x += w + 6.0

func _draw_battery(at: Vector2) -> void:
	var w := 150.0
	var pct := clampf(drone.battery, 0.0, 1.0)
	_text(Vector2(at.x - w, at.y - 12), "BATTERY", 12, DIM)
	_text(Vector2(at.x - 60, at.y - 12), "%d%%" % roundi(pct * 100.0), 15, LINE, HORIZONTAL_ALIGNMENT_RIGHT, 60)
	draw_rect(Rect2(at.x - w, at.y, w, 4), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(at.x - w, at.y, w * pct, 4), ACCENT if pct > 0.2 else Color(1, 0.3, 0.2))

## Signal bars, then the grid reference, right-aligned at `at`.
func _draw_gps(at: Vector2) -> void:
	var strength := gps.signal_strength()
	_text(Vector2(at.x - 150, at.y - 12), "GPS", 12, DIM)
	for i in 4:
		var h := 4.0 + i * 3.0
		var lit := strength > i / 4.0
		draw_rect(Rect2(at.x - 118 + i * 7, at.y - 12 - h, 4, h), ACCENT if lit else Color(1, 1, 1, 0.15))
	_text(Vector2(at.x - 200, at.y + 8), gps.readout(), 15, LINE, HORIZONTAL_ALIGNMENT_RIGHT, 200)
