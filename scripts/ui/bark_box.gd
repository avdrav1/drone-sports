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
# Story 18.3: each line sets the face's emote (or clears it): hearts on a
# finish with no strikes, the rest from data/crew/emotes.tres.
# Story 18.12: lines type out in a monospaced pixel font, like a cabinet's comm
# screen, and the name in its bold cut. The labels carry the fonts themselves,
# so the panel reads the same in the HUD and under either front-end skin.
# Story 18.8: the speaker babbles while their line types out (Bark.babble_for):
# their loop starts with the typing, after the chirp, and stops on the last
# character, when the line is skipped, or when another replaces it.
# Story 18.9: an incoming call. Every line that opens the panel plays its cue
# first (cue_for: a sharp alert for warnings and strikes, a chime otherwise),
# and the face pops in, overshooting and settling, instead of appearing.
# Story 26.4: radio text you can read. Lines and names at 32 px, twice the
# font's native size so it stays crisp; a line holds for a time set by its
# length (hold_time) instead of a flat few seconds. The face is 192 px and
# stands up out of the left end of a low bar that holds the name and the line.
# A waiting line still takes the channel after the `beat`, as in 17.7. On a
# screen whose foot is taken (the board), `at_top` hangs the panel from the top.

@export var bark: Bark
## Seconds a line stays up after it has typed out: `hold_base` plus
## `hold_per_char` for each character, and never under `hold_min`.
@export var hold_base := 2.0
@export var hold_per_char := 0.07
@export var hold_min := 5.0
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
## Hang the panel from the top of the screen, the face below the bar's left
## end, instead of standing it on the foot: for screens whose foot has controls.
@export var at_top := false
## How opaque the panel is: see-through over the flight, solid over a menu.
@export var panel_alpha := 0.75

const PANEL := Color(0, 0, 0, 0.75)
const LINE := FlightHud.LINE
const DIM := FlightHud.DIM
const ACCENT := FlightHud.ACCENT
const FACE := 192.0
## Seconds of static drawn over the panel as a line opens.
const STATIC_TIME := 0.18
## The radio's fonts (CC0, data/LICENSES.md), at twice their native 16 px.
const FONT: Font = preload("res://data/ui/fonts/PixelOperatorMonoHB.ttf")
const NAME_FONT: Font = preload("res://data/ui/fonts/PixelOperatorMono-Bold.ttf")
const FONT_SIZE := 32
## The bar's height under the face: the name and three lines of text.
const BAR_HEIGHT := 164.0
## Lines of text the bar holds under the name.
const MAX_LINES := 3
## The panel's width, clear of the radar at 960 wide.
const WIDTH := 720.0
## Gap between the panel's foot and the screen's: the assists sit below.
const FOOT := 76.0
## Gap above the panel when it hangs from the top.
const TOP := 4.0
## Padding inside the panel.
const PAD := 8.0
## The cue before every line, and the sharper one for ALERT_EVENTS.
const CHIME := &"radio_chime"
const ALERT := &"radio_alert"
const ALERT_EVENTS: Array[StringName] = [&"warning", &"strike"]

var portrait: CharacterPortrait
var emote: EmoteBubble
var label: Label
## The speaker's babble loop, on its own player so it can be stopped.
var voice: AudioStreamPlayer
## The babble's sound event while one runs, else &"".
var babbling: StringName = &""
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
	voice = AudioStreamPlayer.new()
	add_child(voice)
	emote = EmoteBubble.attach(portrait)
	name_label = _label(NAME_FONT, ACCENT)
	label = _label(FONT, LINE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Lay the whole line out first, so words do not jump lines as it types.
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	# A line too long for the bar ends in an ellipsis instead of spilling out.
	label.max_lines_visible = MAX_LINES
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if bark:
		bark.said.connect(_on_said)
		bark.chirp_on_spoke = false
	_layout()

func _label(font: Font, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", FONT_SIZE)
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

## The cue that rings before a line on `event` opens the panel.
static func cue_for(event: StringName) -> StringName:
	return ALERT if event in ALERT_EVENTS else CHIME

## Puts a line on air: its cue, static, the speaker's chirp, and the face.
func _open(line: Dictionary) -> void:
	current = line
	_age = 0.0
	if line.event in chatter:
		_since_chatter = 0.0
	_hush()
	# Heard only while the HUD is shown: not under a cutscene or the title.
	var layer := get_canvas_layer_node()
	if layer == null or layer.visible:
		Sfx.play(cue_for(line.event))
		Sfx.play(&"radio_static")
		Bark.chirp(line.id, line.get("face", &"neutral"), line.event)
		var b := Bark.babble_for(line.id, line.event)
		if not b.is_empty() and not String(line.text).is_empty() and Sfx.play_on(voice, b.event, b.pitch):
			babbling = b.event
	var c := speaker(line.id)
	portrait.character = c
	portrait.expression = line.get("face", &"neutral")
	portrait.pop_in()
	portrait.queue_redraw()
	emote.play_line(_emote_event(line.event), portrait.expression, _job_type())
	name_label.text = ("%s  ·  %s" % [c.name, c.role] if c else String(line.id)).to_upper()
	label.text = line.text
	_type()

## Who says lines as `id`: a crew member, or a pilot (who is not on the roster).
static func speaker(id: StringName) -> Character:
	var c: Character = Roster.character(id)
	if c:
		return c
	for p in PlayerProfile.pilots():
		if p.id == id:
			return p
	return null

## A complete with no strikes is a clean finish; once someone is hurt, every
## line is as quiet as `hurt`.
func _emote_event(event: StringName) -> StringName:
	var runner: JobRunner = bark.runner if bark else null
	if runner and not runner.casualties.is_empty():
		return &"hurt"
	if event == &"complete" and runner and runner.strikes.is_empty():
		return &"clean_finish"
	return event

func _job_type() -> StringName:
	return bark.runner.job.job_type if bark and bark.runner and bark.runner.job else &""

## Seconds the current line takes to type out.
func type_time() -> float:
	return String(current.get("text", "")).length() / type_rate

## True while the current line is still typing out.
func typing() -> bool:
	return not current.is_empty() and _age < type_time()

## Seconds a line of `text` stays up after it has typed out.
func hold_time(text: String) -> float:
	return maxf(hold_min, hold_base + hold_per_char * text.length())

func showing() -> bool:
	return not current.is_empty() and _age < type_time() + hold_time(current.get("text", ""))

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

## Shows the rest of the current line at once, silencing its babble.
func skip() -> void:
	if typing():
		_age = type_time()
		_type()

## Stops the babble.
func _hush() -> void:
	babbling = &""
	if voice:
		voice.stop()

## Reveals the line up to where it has typed; the babble stops with it.
func _type() -> void:
	portrait.talking = typing()
	if not portrait.talking and babbling != &"":
		_hush()
	label.visible_characters = -1 if not portrait.talking else floori(_age * type_rate)

## The panel's bar, low on the left: above the assists, clear of the radar,
## and under the screen's middle third at 960x720, for a HUD of size `s`.
## With `top`, it hangs from the top of the screen instead.
static func panel_rect(s: Vector2, top := false) -> Rect2:
	var y := TOP if top else s.y - FOOT - BAR_HEIGHT
	return Rect2(Vector2(28, y), Vector2(WIDTH, BAR_HEIGHT))

## The tab behind the face, standing up out of the bar's left end, below the
## speed gauge; with `top`, hanging down from it.
static func face_rect(s: Vector2, top := false) -> Rect2:
	var bar := panel_rect(s, top)
	var h := FACE + PAD * 2.0
	var y := bar.position.y if top else bar.end.y - h
	return Rect2(Vector2(bar.position.x, y), Vector2(FACE + PAD * 2.0, h))

func _rect() -> Rect2:
	return panel_rect(size, at_top)

func _layout() -> void:
	var r := _rect()
	var tab := face_rect(size, at_top)
	portrait.position = tab.position + Vector2(PAD, PAD)
	var x := tab.end.x + PAD
	var w := r.end.x - PAD - x
	name_label.position = Vector2(x, r.position.y + PAD)
	name_label.size = Vector2(w, FONT.get_height(FONT_SIZE))
	label.position = Vector2(x, name_label.position.y + name_label.size.y + 6.0)
	label.size = Vector2(w, r.end.y - PAD - label.position.y)

func _draw() -> void:
	if not showing():
		return
	var r := _rect()
	var tab := face_rect(size, at_top)
	# The part of the tab outside the bar: above it, or below it when at_top.
	var top := Rect2(tab.position, Vector2(tab.size.x, r.position.y - tab.position.y))
	if at_top:
		top = Rect2(Vector2(tab.position.x, r.end.y), Vector2(tab.size.x, tab.end.y - r.end.y))
	var fill := Color(PANEL, panel_alpha)
	draw_rect(r, fill)
	draw_rect(top, fill)
	draw_line(Vector2(tab.position.x, minf(tab.position.y, r.position.y)), Vector2(tab.position.x, maxf(tab.end.y, r.end.y)), ACCENT, 2.0)
	if _age < STATIC_TIME:
		# Static as the channel opens: scattered bright specks, thinning out.
		var rng := RandomNumberGenerator.new()
		rng.seed = Time.get_ticks_msec()
		var left := 1.0 - _age / STATIC_TIME
		for part in [r, top]:
			for i in int(320 * left * part.get_area() / r.get_area()):
				var at: Vector2 = part.position + Vector2(rng.randf() * part.size.x, rng.randf() * part.size.y)
				draw_rect(Rect2(at, Vector2(rng.randf_range(2, 10), 1)), Color(LINE, 0.9 * left * rng.randf()))
