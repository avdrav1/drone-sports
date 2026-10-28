class_name BarkBox
extends Control
# The crew's lines on the HUD: a portrait, a name, and the line, low on the left.
# Each line holds for a few seconds; a new one replaces it.
# Story 17.2: the line types out at a steady rate while the speaker's face makes
# the line's expression and talks, then holds the expression once it is all out.
# Story 17.7: a crew radio. A larger face, the speaker's name and role, a burst
# of static and their chirp as a line opens, and a queue so lines never talk
# over each other: urgent lines cut in at once, the rest wait until the line on
# air has typed out, and chatter is dropped once stale and kept to one per gap.

@export var bark: Bark
## Seconds a line stays up after it has typed out.
@export var hold := 3.5
## Characters of the line typed per second.
@export var type_rate := 30.0
## Events that cut in on anything at once. The job's end cuts in too: the job is
## over, and its line cannot wait behind the briefing.
@export var urgent: Array[StringName] = [&"warning", &"strike", &"complete", &"fail"]
## Events that are chatter: dropped instead of played late, and spaced out.
@export var chatter: Array[StringName] = [&"gate_passed", &"takeoff", &"near_miss", &"low_pass", &"top_speed",
	&"battery_low", &"crash", &"reset", &"weather_change", &"long_hover"]
## Least seconds between the starts of two chatter lines.
@export var chatter_gap := 6.0
## A chatter line still waiting after this many seconds is dropped.
@export var stale_after := 4.0
## Seconds a typed-out line stays on air before a waiting line replaces it.
@export var beat := 1.0

const PANEL := Color(0, 0, 0, 0.5)
const LINE := FlightHud.LINE
const DIM := FlightHud.DIM
const ACCENT := FlightHud.ACCENT
const FACE := 80.0
## Seconds of static drawn over the panel as a line opens.
const STATIC_TIME := 0.18

var portrait: CharacterPortrait
var label: Label
var name_label: Label
## The line on screen: {id, event, text, face}, or {} when none.
var current := {}
## Lines waiting for the channel, oldest first: {line, waited}.
var queue: Array[Dictionary] = []
var _age := INF
var _since_chatter := INF

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	portrait = CharacterPortrait.new()
	portrait.size = Vector2(FACE, FACE)
	portrait.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(portrait)
	name_label = _label(13, ACCENT)
	label = _label(16, LINE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Lay the whole line out first, so words do not jump lines as it types.
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	if bark:
		bark.said.connect(_on_said)
		bark.chirp_on_spoke = false
	_layout()

func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	return l

func _on_said(line: Dictionary) -> void:
	if line.event in urgent:
		_open(line)
		return
	queue.append({"line": line, "waited": 0.0})
	_next()

## True while a line holds the channel: typing, or within its beat after.
func on_air() -> bool:
	return not current.is_empty() and _age < type_time() + beat

## Starts the first waiting line that may go now, if the channel is free.
func _next() -> void:
	if on_air():
		return
	for i in queue.size():
		var line: Dictionary = queue[i].line
		if line.event in chatter and _since_chatter < chatter_gap:
			continue
		queue.remove_at(i)
		_open(line)
		return

## Puts a line on air: static, the speaker's chirp, and the face.
func _open(line: Dictionary) -> void:
	current = line
	_age = 0.0
	if line.event in chatter:
		_since_chatter = 0.0
	Sfx.play(&"radio_static")
	Bark.chirp(line.id)
	var c: Character = Roster.character(line.id)
	portrait.character = c
	portrait.expression = line.get("face", &"neutral")
	portrait.queue_redraw()
	name_label.text = ("%s  ·  %s" % [c.name, c.role] if c else String(line.id)).to_upper()
	label.text = line.text
	_type()

## Seconds the current line takes to type out.
func type_time() -> float:
	return String(current.get("text", "")).length() / type_rate

## True while the current line is still typing out.
func typing() -> bool:
	return not current.is_empty() and _age < type_time()

func showing() -> bool:
	return not current.is_empty() and _age < type_time() + hold

func _process(delta: float) -> void:
	_age += delta
	_since_chatter += delta
	for q in queue:
		q.waited += delta
	queue = queue.filter(func(q): return not (q.line.event in chatter and q.waited > stale_after))
	_next()
	_type()
	visible = showing()
	_layout()
	queue_redraw()

## Reveals the line up to where it has typed.
func _type() -> void:
	portrait.talking = typing()
	label.visible_characters = -1 if not portrait.talking else floori(_age * type_rate)

## The panel, low on the left: below the speed gauge, above the assists, clear
## of the radar and the controls hint, for a HUD of size `s`.
static func panel_rect(s: Vector2) -> Rect2:
	return Rect2(Vector2(28, s.y - 236), Vector2(440, 104))

func _rect() -> Rect2:
	return panel_rect(size)

func _layout() -> void:
	var r := _rect()
	portrait.position = r.position + Vector2(10, 12)
	name_label.position = r.position + Vector2(FACE + 24, 8)
	name_label.size = Vector2(r.size.x - FACE - 36, 20)
	label.position = r.position + Vector2(FACE + 24, 30)
	label.size = Vector2(r.size.x - FACE - 36, r.size.y - 36)

func _draw() -> void:
	if not showing():
		return
	var r := _rect()
	draw_rect(r, PANEL)
	draw_line(r.position, r.position + Vector2(0, r.size.y), ACCENT, 2.0)
	if _age < STATIC_TIME:
		# Static as the channel opens: scattered bright specks, thinning out.
		var rng := RandomNumberGenerator.new()
		rng.seed = Time.get_ticks_msec()
		var left := 1.0 - _age / STATIC_TIME
		for i in int(160 * left):
			var at := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
			draw_rect(Rect2(at, Vector2(rng.randf_range(2, 10), 1)), Color(LINE, 0.9 * left * rng.randf()))
