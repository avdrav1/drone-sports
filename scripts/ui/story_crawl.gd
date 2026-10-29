class_name StoryCrawl
extends Control
# The title's story crawl (Story 17.12): the Crawl's text, set flat in a
# SubViewport, drawn on a plane tipped away from the viewer so it rolls up and
# shrinks into the distance. It loops; it never takes input.

const SHADER := preload("res://scripts/ui/crawl_tilt.gdshader")
## Width the text is set at, in text pixels.
const TEXT_WIDTH := 900
## Width of the plane at its top edge, as a fraction of the bottom's.
const TOP_WIDTH := 0.3

@export var crawl: Crawl
@export var color := Color(1.0, 0.76, 0.25)
@export var font: Font
@export var heading_font: Font

## Text pixel at the bottom edge; below zero, nothing has appeared yet.
var scroll := 0.0
## Loops played through.
var loops := 0
var text_height := 0.0

var _view: SubViewport
var _page: VBoxContainer
var _plane: TextureRect

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_view = SubViewport.new()
	_view.transparent_bg = true
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_view)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 40)
	_page.custom_minimum_size.x = TEXT_WIDTH
	_view.add_child(_page)
	for para in paragraphs():
		_page.add_child(_paragraph(para))
	_plane = TextureRect.new()
	_plane.set_anchors_preset(PRESET_FULL_RECT)
	_plane.mouse_filter = MOUSE_FILTER_IGNORE
	_plane.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plane.texture = _view.get_texture()
	_plane.material = ShaderMaterial.new()
	_plane.material.shader = SHADER
	_plane.material.set_shader_parameter("text_tex", _view.get_texture())
	_plane.material.set_shader_parameter("top_width", TOP_WIDTH)
	add_child(_plane)
	_page.minimum_size_changed.connect(_fit)
	_fit()
	restart()

func _process(delta: float) -> void:
	scroll += delta * crawl.speed
	if scroll > end():
		loops += 1
		restart(crawl.loop_pause)
	_plane.material.set_shader_parameter("scroll", scroll)
	_plane.material.set_shader_parameter("rect_size", size)

## Starts again from below the bottom edge, after `delay` seconds.
func restart(delay := -1.0) -> void:
	scroll = -(crawl.start_delay if delay < 0.0 else delay) * crawl.speed

## The scroll at which the last line has left the top.
func end() -> float:
	return text_height + visible_depth()

## How much text the plane shows at once, in text pixels.
func visible_depth() -> float:
	var s := TEXT_WIDTH / maxf(size.x, 1.0)
	return s * size.y / (1.0 - TOP_WIDTH) * (1.0 / TOP_WIDTH - 1.0)

func paragraphs() -> PackedStringArray:
	var out := PackedStringArray()
	for p in crawl.text.split("\n\n", false):
		out.append(p.strip_edges())
	return out

static func is_heading(p: String) -> bool:
	return p == p.to_upper()

func _paragraph(p: String) -> Label:
	var l := Label.new()
	l.text = p
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = TEXT_WIDTH
	var head := is_heading(p)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var f := heading_font if head and heading_font else font
	if f:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", 44 if head else 34)
	l.add_theme_constant_override("line_spacing", 10)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	return l

## The viewport takes the text's full height, and draws it once more.
func _fit() -> void:
	text_height = _page.get_combined_minimum_size().y
	_view.size = Vector2i(TEXT_WIDTH, int(ceil(text_height)))
	_page.size = Vector2(TEXT_WIDTH, text_height)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_plane.material.set_shader_parameter("text_size", Vector2(_view.size))
