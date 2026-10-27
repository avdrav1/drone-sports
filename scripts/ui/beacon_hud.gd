class_name BeaconHud
extends Control
# The beacon as a HUD arc: it fills with signal strength and flashes on each
# ping. No direction and no marker; the player searches. Shows the rescue clock.

@export var beacon: Beacon
@export var timer: RescueTimer
@export var title := "BEACON"

const LINE := FlightHud.LINE
const DIM := FlightHud.DIM
const ACCENT := FlightHud.ACCENT
const ALARM := Color(1.0, 0.35, 0.3)

var _flash := 0.0
var font: Font

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	font = get_theme_default_font()
	if beacon:
		beacon.pinged.connect(func(_s): _flash = 1.0)

func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 4.0, 0.0)
	queue_redraw()

func _draw() -> void:
	if beacon == null:
		return
	var c := Vector2(size.x * 0.5, size.y - 70.0)
	var r := 60.0
	var s := beacon.strength()
	draw_arc(c, r, PI, TAU, 48, Color(1, 1, 1, 0.2), 6.0, true)
	if s > 0.0:
		draw_arc(c, r, PI, PI + PI * s, 48, Color(ACCENT, 0.6 + 0.4 * _flash), 6.0, true)
	if _flash > 0.0:
		draw_arc(c, r + 10.0 * (1.0 - _flash), PI, TAU, 48, Color(ACCENT, _flash * 0.5), 2.0, true)
	draw_string(font, c + Vector2(-60, -14), title, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, DIM)
	draw_string(font, c + Vector2(-60, 8), "%d%%" % roundi(s * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 120, 20, LINE)
	if timer:
		var left := timer.remaining()
		draw_string(font, c + Vector2(-80, 30), "%d:%02d LEFT" % [int(left) / 60, int(left) % 60], HORIZONTAL_ALIGNMENT_CENTER, 160, 14, ALARM if left < 15.0 else LINE)
