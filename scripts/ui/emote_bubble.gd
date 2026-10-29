class_name EmoteBubble
extends Control
# Little cartoon emotes beside a CharacterPortrait (Story 18.3): hearts,
# sparkles, a sweat drop, a "!", music notes, dizzy stars. Which emote shows
# is data (data/crew/emotes.tres); this draws it in code, one at a time, the
# newest replacing the oldest, riding the face's bob. The dead never emote.

const DRAWINGS: Array[StringName] = [&"hearts", &"sparkles", &"sweat", &"bang", &"notes", &"stars"]
const INK := CharacterPortrait.INK
## Seconds an emote takes to pop in, and to fade at the end of its time.
const POP := 0.15
const FADE := 0.25
## Where the three sparkles twinkle, per head radius from its centre.
const SPARKLES: Array[Vector2] = [Vector2(1.0, -0.9), Vector2(-1.05, -0.65), Vector2(1.2, -0.15)]

@export var table: EmoteTable = preload("res://data/crew/emotes.tres")

var portrait: CharacterPortrait
## The emote showing (or waiting for the face to go idle), or null.
var current: Emote
## Seconds `current` has shown.
var age := 0.0

## A bubble drawn over `face`, following it.
static func attach(face: CharacterPortrait) -> EmoteBubble:
	var b := EmoteBubble.new()
	b.portrait = face
	b.mouse_filter = MOUSE_FILTER_IGNORE
	face.add_child(b)
	return b

func _ready() -> void:
	if portrait == null and get_parent() is CharacterPortrait:
		portrait = get_parent()

## Shows `e` now, replacing whatever showed. Null, or a dead face, clears it.
func show_emote(e: Emote) -> void:
	current = e if e and _alive() else null
	age = 0.0
	queue_redraw()

## Shows the emote for `key` (an event or an expression), if one is mapped.
func play(key: StringName) -> void:
	show_emote(table.find(key))

## Shows the emote for a line, or clears the last one when the line has none:
## see EmoteTable.for_line.
func play_line(event: StringName, face: StringName, job_type: StringName = &"") -> void:
	show_emote(table.for_line(event, face, job_type))

func clear() -> void:
	show_emote(null)

## True while an emote is drawn.
func showing() -> bool:
	return current != null and not _waiting()

func _alive() -> bool:
	return portrait != null and portrait.character != null and not portrait.is_dead()

func _waiting() -> bool:
	return current.idle and portrait.talking

func _process(delta: float) -> void:
	if current == null:
		return
	if not _alive():
		clear()
		return
	if not _waiting():
		age += delta
		if age >= current.time:
			clear()
			return
	queue_redraw()

func _draw() -> void:
	if not showing():
		return
	var s := minf(portrait.size.x, portrait.size.y)
	var m := portrait.current_motion()
	var r := s * 0.34
	var center := portrait.size * 0.5 + Vector2(0, s * 0.08) + (m.offset as Vector2) * s
	var line := maxf(r * 0.07, 1.0)
	var pop := minf(age / POP, 1.0)
	# Pops in a little too big, then settles; fades at the end.
	var grow := 1.0 + 0.35 * sin(PI * pop) if pop < 1.0 else 1.0
	grow *= minf(pop * 2.0, 1.0)
	var alpha := clampf((current.time - age) / FADE, 0.0, 1.0)
	var col := Color(current.color, current.color.a * alpha)
	var ink := Color(INK, alpha)
	var u := r * 0.42 * grow
	var t := age
	match current.drawing:
		&"hearts":
			for i in 2:
				var k := fmod(t * 0.6 + i * 0.5, 1.0)
				var at := center + Vector2(r * (0.85 + 0.25 * i) + sin(t * 4.0 + i) * r * 0.08, -r * (0.55 + 0.7 * k))
				_heart(at, u * (1.0 - 0.3 * i), col, ink, line)
		&"sparkles":
			for i in 3:
				var at := center + SPARKLES[i] * r
				var tw := 0.85 + 0.15 * sin(t * 9.0 + i * 2.1)
				_star(at, u * 1.15 * tw * (1.0 - 0.2 * i), 4, 0.38, col, ink, line, t * 1.5)
		&"sweat":
			var slide := minf(t / 0.6, 1.0)
			_drop(center + Vector2(r * 0.95, -r * (0.55 - 0.2 * slide)), u * 0.9, col, ink, line)
		&"bang":
			_bang(center + Vector2(r * 1.05, -r * 0.85), u * 1.1, col, ink, line)
		&"notes":
			for i in 2:
				var k := fmod(t * 0.5 + i * 0.5, 1.0)
				var at := center + Vector2(r * (0.95 + 0.2 * i) + sin(t * 3.0 + i * 2.0) * r * 0.12, -r * (0.45 + 0.75 * k))
				_note(at, u * (0.9 - 0.15 * i), col, ink, line)
		&"stars":
			# Dizzy: three stars circling above the head.
			for i in 3:
				var a := t * 4.0 + TAU * i / 3.0
				var at := center + Vector2(cos(a) * r * 0.8, -r * 1.12 + sin(a) * r * 0.2)
				_star(at, u * (0.85 + 0.15 * sin(a)), 5, 0.48, col, ink, line, a * 0.5)

func _outline(pts: PackedVector2Array, fill: Color, ink: Color, line: float) -> void:
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, ink, line, true)

func _heart(at: Vector2, size_: float, fill: Color, ink: Color, line: float) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		var x := 16.0 * pow(sin(a), 3)
		var y := -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		pts.append(at + Vector2(x, y) * size_ / 16.0)
	_outline(pts, fill, ink, line)
	draw_circle(at + Vector2(-0.4, -0.35) * size_, size_ * 0.18, Color(1, 1, 1, ink.a))

## A star with `points` points; `inner` is the inner radius per outer radius.
func _star(at: Vector2, size_: float, points: int, inner: float, fill: Color, ink: Color, line: float, spin := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := spin - PI / 2.0 + PI * i / points
		pts.append(at + Vector2(cos(a), sin(a)) * size_ * (1.0 if i % 2 == 0 else inner))
	_outline(pts, fill, ink, line)

func _drop(at: Vector2, size_: float, fill: Color, ink: Color, line: float) -> void:
	# A teardrop: a round bottom drawn up to a point.
	var pts := PackedVector2Array([at + Vector2(0, -size_ * 1.5)])
	for i in 17:
		var a := lerpf(-PI * 0.2, PI * 1.2, i / 16.0)
		pts.append(at + Vector2(cos(a), sin(a)) * size_)
	_outline(pts, fill, ink, line)
	draw_circle(at + Vector2(-0.35, -0.2) * size_, size_ * 0.22, Color(1, 1, 1, ink.a))

func _bang(at: Vector2, size_: float, fill: Color, ink: Color, line: float) -> void:
	# A chunky "!": a bar wide at the top, tapering, and a round dot.
	_outline(PackedVector2Array([at + Vector2(-0.42, -1.5) * size_, at + Vector2(0.42, -1.5) * size_,
		at + Vector2(0.2, 0.3) * size_, at + Vector2(-0.2, 0.3) * size_]), fill, ink, line)
	var dot := at + Vector2(0, 0.85) * size_
	draw_circle(dot, size_ * 0.3, fill)
	draw_circle(dot, size_ * 0.3, ink, false, line, true)

func _note(at: Vector2, size_: float, fill: Color, ink: Color, line: float) -> void:
	# An eighth note: a round head, a stem, and a flag.
	var head := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		head.append(at + Vector2(cos(a) * 0.62, sin(a) * 0.48).rotated(-0.4) * size_)
	var top := at + Vector2(0.52, -1.6) * size_
	var stem := PackedVector2Array([at + Vector2(0.52, -0.1) * size_, top, top + Vector2(0.45, 0.35) * size_, top + Vector2(0.4, 0.85) * size_])
	# Inked, then filled with colour, so it reads on a dark panel.
	draw_polyline(stem, ink, line * 3.0, true)
	draw_polyline(stem, fill, line * 1.2, true)
	_outline(head, fill, ink, line)
