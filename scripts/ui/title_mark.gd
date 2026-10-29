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

## The title's face. Swapping the font is this one line.
const FONT := preload("res://data/ui/fonts/YatraOne-Regular.ttf")

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

## The name as last laid out.
var word := ""
## The size it is lettered at, after fitting.
var size_used := 0

var _line: TextLine
## Where the line is drawn from (top-left of its box), in this control.
var _origin := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_relayout)
	_relayout()

func _process(_delta: float) -> void:
	if GameName.title() != word:
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
	if size.y > 0.0 and _line.get_size().y > size.y:
		size_used = maxi(8, floori(size_used * size.y / _line.get_size().y))
		_line = _shape(size_used)
	_origin = (size - _line.get_size()) * 0.5
	queue_redraw()

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

func _draw() -> void:
	if _line == null or word == "":
		return
	var b := bar()
	var outline := _outline()
	if outline > 0:
		var edge := _color(&"font_outline_color", Color.BLACK)
		draw_rect(b.grow(outline * 0.5), edge)
		_line.draw_outline(get_canvas_item(), _origin, outline, edge)
	var fill := _color(&"font_color", Color.WHITE)
	draw_rect(b, fill)
	_line.draw(get_canvas_item(), _origin, fill)
