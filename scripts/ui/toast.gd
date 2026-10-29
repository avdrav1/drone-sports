class_name Toast
extends CanvasLayer
# A short line near the top of the screen that fades on its own, e.g.
# "Controller connected" (Story 23.5). It runs while the game is paused and
# takes no input, so it never closes or answers the dialog under it.

## Seconds the line holds before it fades.
@export var hold := 2.0
## Seconds the fade takes.
@export var fade := 0.5

var label: Label

## Shows `line` over `parent`'s screen and frees itself once faded.
static func show_line(parent: Node, line: String) -> Toast:
	var t := Toast.new()
	t.name = "Toast"
	parent.add_child(t)
	t.label.text = line
	return t

func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.position.y = 140
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.6)
	box.set_content_margin_all(10)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.set_corner_radius_all(4)
	label.add_theme_stylebox_override("normal", box)
	add_child(label)

func _ready() -> void:
	var tw := create_tween()
	tw.tween_interval(hold)
	tw.tween_property(label, "modulate:a", 0.0, fade)
	tw.tween_callback(queue_free)
