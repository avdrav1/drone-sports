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
# Story 26.5: the radio as a chat. The last CHAT_LINES lines stay on screen:
# the newest types out in the bar, the ones before it stack above the face,
# newest lowest, each with a smaller face and its speaker's name, at the font's
# native size. A fifth line scrolls the oldest off the top, a line fades out
# once it is FADE_AFTER seconds old, and when the newest has faded the chat is
# empty. The stack stays left of the screen's middle third, and ends short of
# what it must not cover (`avoid`: the flight HUD's job panel and gauges, the
# fleet boards, the board's controls); a row with no room left does not show.
# The flight HUD's speed gauge sits on the right, above altitude, so in flight
# the column from the job panel down to the face is the chat's. With `at_top`
# the rows hang below the face instead. Without `linger` (the board) the chat
# empties when the newest line's hold ends, not after FADE_AFTER.

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
## Keep the chat up FADE_AFTER seconds; false empties it, fading, when the
## newest line's hold ends (the board, whose header it covers).
@export var linger := true
## Returns the rects (in this box's space) the chat's rows must not cover.
## Unset, the rows avoid a sibling FlightHud's readouts and the controls in
## the AVOID group.
var keep_clear: Callable

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
## Lines the chat keeps on screen, the newest included.
const CHAT_LINES := 4
## Seconds after it opens that a line starts to fade, and how long it takes.
const FADE_AFTER := 20.0
const FADE_TIME := 1.5
## The faces and type of the older lines.
const SMALL_FACE := 48.0
const SMALL_SIZE := 16
## The cue before every line, and the sharper one for ALERT_EVENTS.
const CHIME := &"radio_chime"
const ALERT := &"radio_alert"
const ALERT_EVENTS: Array[StringName] = [&"warning", &"strike"]
## Controls in this group keep the chat's rows off them (a fleet job's board).
const AVOID := &"radio_avoid"

var portrait: CharacterPortrait
var emote: EmoteBubble
var label: Label
## The speaker's babble loop, on its own player so it can be stopped.
var voice: AudioStreamPlayer
## The babble's sound event while one runs, else &"".
var babbling: StringName = &""
var name_label: Label
## The newest line: {id, event, text, face}, or {} when none.
var current := {}
## Every line on screen, oldest first, the newest (current) last: {line, age}.
var chat: Array[Dictionary] = []
## The older lines' rows, nearest the bar first: {portrait, name, text}.
var rows: Array[Dictionary] = []
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
	for i in CHAT_LINES - 1:
		var face := CharacterPortrait.new()
		face.size = Vector2(SMALL_FACE, SMALL_FACE)
		face.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(face)
		var text := _label(FONT, LINE, SMALL_SIZE)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.append({"portrait": face, "name": _label(NAME_FONT, ACCENT, SMALL_SIZE), "text": text})
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

func _label(font: Font, color: Color, font_size := FONT_SIZE) -> Label:
	var l := Label.new()
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
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

## The cue that rings before a line on `event` opens the panel.
static func cue_for(event: StringName) -> StringName:
	return ALERT if event in ALERT_EVENTS else CHIME

## Puts a line on air: its cue, static, the speaker's chirp, and the face.
func _open(line: Dictionary) -> void:
	current = line
	_age = 0.0
	chat.append({"line": line, "age": 0.0})
	if chat.size() > CHAT_LINES:
		chat.pop_front()
	_fill_rows()
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

## Puts the lines before the newest into the rows above the bar, newest lowest.
func _fill_rows() -> void:
	for i in rows.size():
		var at := chat.size() - 2 - i
		var row: Dictionary = rows[i]
		var line: Dictionary = chat[at].line if at >= 0 else {}
		var c := speaker(line.id) if at >= 0 else null
		row.portrait.character = c
		row.portrait.expression = line.get("face", &"neutral")
		row.portrait.queue_redraw()
		row.name.text = (c.name if c else String(line.get("id", ""))).to_upper()
		row.text.text = line.get("text", "")

## How opaque a chat line `age` seconds old is: whole, then fading out.
static func fade(age: float) -> float:
	return clampf(1.0 - (age - FADE_AFTER) / FADE_TIME, 0.0, 1.0)

## True while the chat has a line on screen, faded or not.
func chatting() -> bool:
	return not chat.is_empty()

## How opaque the whole chat is: the newest line's fade, or without `linger`,
## fading out once its hold has run.
func _chat_alpha() -> float:
	if chat.is_empty():
		return 1.0
	var a := fade(chat.back().age)
	if not linger and not current.is_empty():
		var over := _age - type_time() - hold_time(current.get("text", ""))
		a = minf(a, clampf(1.0 - over / FADE_TIME, 0.0, 1.0))
	return a

## Seconds a line of `text` stays up after it has typed out.
func hold_time(text: String) -> float:
	return maxf(hold_min, hold_base + hold_per_char * text.length())

func showing() -> bool:
	return not current.is_empty() and _age < type_time() + hold_time(current.get("text", ""))

func _process(delta: float) -> void:
	_age += delta
	_since_chatter += delta
	for entry in chat:
		entry.age += delta
	if not chat.is_empty() and fade(chat.front().age) <= 0.0:
		chat = chat.filter(func(e): return fade(e.age) > 0.0)
		_fill_rows()
	if not chat.is_empty() and _chat_alpha() <= 0.0:
		chat.clear()
		_fill_rows()
	for q in queue:
		q.waited += delta
	queue = queue.filter(func(q): return not (q.line.event in chatter and q.waited > stale_after))
	_next()
	_type()
	visible = chatting()
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
## screen's middle; with `top`, hanging down from it.
static func face_rect(s: Vector2, top := false) -> Rect2:
	var bar := panel_rect(s, top)
	var h := FACE + PAD * 2.0
	var y := bar.position.y if top else bar.end.y - h
	return Rect2(Vector2(bar.position.x, y), Vector2(FACE + PAD * 2.0, h))

func _rect() -> Rect2:
	return panel_rect(size, at_top)

## The column the older lines stack in, above the face: as wide as the bar, but
## never into the screen's middle third.
static func chat_width(s: Vector2) -> float:
	return minf(WIDTH, s.x / 3.0 - 28.0 - PAD)

## The rect each older line's row covers, nearest the bar first, for rows whose
## text labels are `texts`, on a HUD of size `s`. The rows stack up from the
## face (down from it, with `top`); a row that would cover a rect in `avoid`
## or leave the screen ends the stack, so fewer rects may come back.
static func row_rects(s: Vector2, texts: Array, avoid: Array = [], top := false) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if chat_width(s) <= SMALL_FACE or s.y <= 8.0:
		return out
	var tab := face_rect(s, top)
	var edge := tab.end.y if top else tab.position.y
	var screen := Rect2(Vector2.ZERO, s).grow(-4.0)
	var name_h := NAME_FONT.get_height(SMALL_SIZE)
	for t: Label in texts:
		var lines := maxi(1, t.get_line_count())
		var h := maxf(SMALL_FACE, name_h + 2.0 + lines * t.get_line_height()) + PAD * 2.0
		var r := Rect2(Vector2(28, edge + 4.0 if top else edge - 4.0 - h), Vector2(chat_width(s), h))
		# The rows stop at the first thing in the way rather than skip past it,
		# so the chat reads as one stack, in order, with no gap.
		if not screen.encloses(r) or avoid.any(func(a: Rect2): return r.intersects(a)):
			break
		out.append(r)
		edge = r.end.y if top else r.position.y
	return out

## The rects the rows keep off: `keep_clear`'s, or a sibling FlightHud's
## readouts and the visible controls in the AVOID group.
func avoid() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if keep_clear.is_valid():
		out.assign(keep_clear.call())
		return out
	if get_parent():
		for n in get_parent().get_children():
			if n is FlightHud and n.visible:
				out.append_array(n.readout_rects())
	if is_inside_tree():
		for n in get_tree().get_nodes_in_group(AVOID):
			if n is Control and n.is_visible_in_tree():
				out.append(n.get_global_rect())
	return out

## The rows that hold a line, nearest the bar first.
func _rows_in_use() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in mini(rows.size(), chat.size() - 1):
		out.append(rows[i])
	return out

## The rows that show and their rects: those in use that have room.
func _shown_rows() -> Dictionary:
	var used := _rows_in_use()
	var rects := row_rects(size, used.map(func(row): return row.text), avoid(), at_top)
	return {"rows": used.slice(0, rects.size()), "rects": rects}

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
	modulate.a = _chat_alpha()
	var tw := chat_width(size) - SMALL_FACE - PAD * 3.0
	for row in rows:
		row.text.size = Vector2(tw, 0)
	var shown := _shown_rows()
	var used: Array = shown.rows
	var rects: Array[Rect2] = shown.rects
	for row in rows:
		var on: bool = row in used
		for n: Control in [row.portrait, row.name, row.text]:
			n.visible = on
	for i in used.size():
		var row: Dictionary = used[i]
		var at := rects[i].position + Vector2(PAD, PAD)
		row.portrait.position = at
		row.name.position = at + Vector2(SMALL_FACE + PAD, 0)
		row.name.size = Vector2(tw, NAME_FONT.get_height(SMALL_SIZE))
		row.text.position = row.name.position + Vector2(0, row.name.size.y + 2.0)
		row.text.size = Vector2(tw, rects[i].end.y - PAD - row.text.position.y)
		# Relative to the box, which fades with the newest line.
		var a := fade(chat[chat.size() - 2 - i].age) / maxf(modulate.a, 0.001)
		for n: Control in [row.portrait, row.name, row.text]:
			n.modulate.a = minf(a, 1.0)

func _draw() -> void:
	if not chatting():
		return
	var shown := _shown_rows()
	for i in shown.rows.size():
		draw_rect(shown.rects[i], Color(PANEL, panel_alpha * shown.rows[i].text.modulate.a))
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
