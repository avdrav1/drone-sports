class_name TitleMark
extends Control
# Story 24.6: the game's name lettered in the manner of Devanagari. English
# letters in an open-licence face with a Devanagari heritage hang from one
# unbroken headline bar (the shirorekha), drawn here across the letters' tops
# and a little past the first and last, because no such face draws one across
# Latin text. The name comes from the project settings (GameName), so a changed
# name redraws with no other edit. Colours are theme overrides, as on a Label:
# font_color, font_outline_color and outline_size. The title screen and the
# intro's title card both use it.
# The owner asked for it to look more Indian: it is lettered in Amita, a face
# drawn with a Devanagari pen, the I carries the loop of the i-matra (ि) over
# the next letter, and by default it is filled saffron to gold with a maroon
# edge, as festival signs are, in place of the theme's colours.

## The title's face. Swapping the font is this one line.
const FONT := preload("res://data/ui/fonts/Amita-Bold.ttf")
const GRADIENT := preload("res://scripts/ui/title_mark.gdshader")

@export var font: Font = FONT
## The size the name is lettered at, px, when it fits; smaller when it does not.
@export var font_size := 96
## Bar thickness, as a fraction of the font size.
@export var bar_weight := 0.1
## How far the bar runs past the first and last letter, as a fraction of the font size.
@export var overhang := 0.22
## How much of the bar sits below the letters' tops, so they hang from it.
@export var bar_overlap := 0.6
## The share of the control's width the mark may fill, bar and outline included.
@export var max_width := 0.9
## The i-matra's loop rises from the first I over the letter after it.
@export var matra := true
## Saffron to gold, edged in maroon; off, the theme's font colours are used.
@export var saffron := true
@export var top_color := Color(1.0, 0.86, 0.35)
@export var bottom_color := Color(0.98, 0.45, 0.08)
@export var edge_color := Color(0.42, 0.04, 0.08)

## The name as last laid out.
var word := ""
## The size it is lettered at, after fitting.
var size_used := 0

var _line: TextLine
## Where the line is drawn from (top-left of its box), in this control.
var _origin := Vector2.ZERO
## The fill is drawn on its own item, so the gradient leaves the edge alone.
var _fill: Control
## The letters' ink the layout was made from.
var _laid_out: Array[Rect2] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill = Control.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fill.draw.connect(_draw_fill)
	add_child(_fill, false, Node.INTERNAL_MODE_FRONT)
	resized.connect(_relayout)
	_relayout()

func _process(_delta: float) -> void:
	# A glyph's ink is only known once it has been drawn at that size, so the
	# first layout can be off: lay out again until the letters stop moving.
	if GameName.title() != word or letters() != _laid_out:
		_relayout()

func _relayout() -> void:
	word = GameName.title()
	size_used = font_size
	_line = _shape(size_used)
	var room := size.x * max_width
	var needed := _line.get_size().x + 2.0 * (overhang * size_used + _outline())
	if room > 0.0 and needed > room:
		size_used = maxi(8, floori(size_used * room / needed))
		_line = _shape(size_used)
	_origin = Vector2((size.x - _line.get_size().x) * 0.5, 0.0)
	var tall := _line.get_size().y + _rise()
	if size.y > 0.0 and tall > size.y:
		size_used = maxi(8, floori(size_used * size.y / tall))
		_line = _shape(size_used)
		_origin = Vector2((size.x - _line.get_size().x) * 0.5, 0.0)
		tall = _line.get_size().y + _rise()
	var rise := _rise()
	_origin.y = (size.y - tall) * 0.5 + rise
	_laid_out = letters()
	if _fill:
		_fill.material = null
		if saffron:
			var m := ShaderMaterial.new()
			m.shader = GRADIENT
			var b := bar()
			var ink := letters()
			var low := b.end.y
			for r in ink:
				low = maxf(low, r.end.y)
			m.set_shader_parameter("top", b.position.y)
			m.set_shader_parameter("bottom", low)
			m.set_shader_parameter("top_color", top_color)
			m.set_shader_parameter("bottom_color", bottom_color)
			_fill.material = m
		_fill.queue_redraw()
	queue_redraw()

## How far the matra rises above the line's box, at the current origin's y.
func _rise() -> float:
	var loop := matra_loop()
	if loop.is_empty():
		return 0.0
	var top := _origin.y
	for p in loop:
		top = minf(top, p.y)
	return maxf(0.0, _origin.y - top + _stroke() * 0.5 + _outline())

func _stroke() -> float:
	return maxf(2.0, round(bar_weight * size_used)) * 0.85

func _shape(px: int) -> TextLine:
	var line := TextLine.new()
	line.add_string(word, font, px)
	return line

func _outline() -> int:
	return get_theme_constant("outline_size") if has_theme_constant("outline_size") else 0

func _color(name: StringName, fallback: Color) -> Color:
	return get_theme_color(name) if has_theme_color(name) else fallback

## Each letter's ink, in this control's coordinates (blank glyphs left out).
func letters() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _line == null:
		return out
	var ts := TextServerManager.get_primary_interface()
	var baseline := _origin.y + _line.get_line_ascent()
	var x := _origin.x
	for g in ts.shaped_text_get_glyphs(_line.get_rid()):
		var at := Vector2i(size_used, 0)
		var offset: Vector2 = ts.font_get_glyph_offset(g.font_rid, at, g.index)
		var ink: Vector2 = ts.font_get_glyph_size(g.font_rid, at, g.index)
		if ink.x > 0.0 and ink.y > 0.0:
			out.append(Rect2(Vector2(x, baseline) + g.offset + offset, ink))
		x += g.advance * g.repeat
	return out

## The headline bar: across the letters' tops and past the first and last.
## It hangs from the lowest top, so every letter reaches into it; a letter that
## rises higher pokes through, as marks above the line do in Devanagari.
func bar() -> Rect2:
	var ink := letters()
	if ink.is_empty():
		return Rect2()
	var left := ink[0].position.x
	var right := ink[0].end.x
	var lowest_top := ink[0].position.y
	for r in ink:
		left = minf(left, r.position.x)
		right = maxf(right, r.end.x)
		lowest_top = maxf(lowest_top, r.position.y)
	var thick := maxf(2.0, round(bar_weight * size_used))
	var run := overhang * size_used
	var bottom := lowest_top + thick * bar_overlap
	return Rect2(left - run, bottom - thick, right - left + 2.0 * run, thick)

## The i-matra's loop, as a line through its middle: from the top of the first
## I, up and over the letter after it, down to the bar. Empty with no matra, or
## no I with a letter after it.
func matra_loop() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var at := word.replace(" ", "").find("I")
	var ink := letters()
	if not matra or at < 0 or at + 1 >= ink.size():
		return pts
	var b := bar()
	var mid := b.position.y + b.size.y * 0.5
	var x0 := ink[at].get_center().x
	var x1 := ink[at + 1].end.x + size_used * 0.05
	var h := size_used * 0.5
	var p0 := Vector2(x0, mid)
	var p1 := Vector2(x0 - size_used * 0.02, b.position.y - h * 1.5)
	var p2 := Vector2(x1 + size_used * 0.45, b.position.y - h * 1.05)
	var p3 := Vector2(x1, mid)
	for k in 33:
		var t := k / 32.0
		var u := 1.0 - t
		pts.append(u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3)
	return pts

func _draw() -> void:
	if _line == null or word == "":
		return
	var outline := _outline()
	if outline > 0:
		var edge := edge_color if saffron else _color(&"font_outline_color", Color.BLACK)
		draw_rect(bar().grow(outline * 0.5), edge)
		var loop := matra_loop()
		if not loop.is_empty():
			draw_polyline(loop, edge, _stroke() + outline, true)
		_line.draw_outline(get_canvas_item(), _origin, outline, edge)
	if _fill:
		_fill.queue_redraw()

## The letters, bar and loop in the fill colour: white under the gradient.
func _draw_fill() -> void:
	if _line == null or word == "":
		return
	var fill := Color.WHITE if saffron else _color(&"font_color", Color.WHITE)
	_fill.draw_rect(bar(), fill)
	var loop := matra_loop()
	if not loop.is_empty():
		_fill.draw_polyline(loop, fill, _stroke(), true)
	_line.draw(_fill.get_canvas_item(), _origin, fill)
