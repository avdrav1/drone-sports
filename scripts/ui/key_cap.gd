class_name KeyCap
extends Control
# One keyboard key drawn as a key cap. Arrow keys draw their arrow as a shape,
# so it shows whatever the font: the default font has no arrow glyphs.

const SIZE := 46.0
## Arrow key text to the direction its triangle points.
const ARROWS := {"↑": Vector2.UP, "↓": Vector2.DOWN, "←": Vector2.LEFT, "→": Vector2.RIGHT}

var text := ""
var color := Color(1.0, 0.76, 0.25)

func _init(key: String = "", tint := Color(1.0, 0.76, 0.25)) -> void:
	text = key
	color = tint
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = MOUSE_FILTER_IGNORE

func is_arrow() -> bool:
	return ARROWS.has(text)

func _draw() -> void:
	var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.1, 0.11, 0.14, 0.95)
	face.border_color = color
	face.set_border_width_all(2)
	face.border_width_bottom = 5
	face.set_corner_radius_all(7)
	draw_style_box(face, r)
	var c := r.get_center() - Vector2(0, 1.5)
	if is_arrow():
		var d: Vector2 = ARROWS[text]
		var s := r.size.x * 0.24
		var side := d.orthogonal() * s * 0.9
		draw_colored_polygon(PackedVector2Array([c + d * s, c - d * s * 0.6 + side, c - d * s * 0.6 - side]), color)
		return
	var font := get_theme_default_font()
	var fs := 20 if text.length() == 1 else 13
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, c + Vector2(-w.x / 2.0, font.get_ascent(fs) / 2.0 - 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
