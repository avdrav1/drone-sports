class_name Scanlines
extends Control
# The cabinet skin's CRT lines (Story 17.6): a faint dark line every few pixels
# over the whole screen and a soft dark edge. Takes no input.

@export var gap := 3
@export var line := Color(0, 0, 0, 0.16)

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), line, 1.0)
		y += gap
	# The tube's edge: a few nested dark frames.
	for i in 6:
		var a := 0.05 * (6 - i)
		draw_rect(Rect2(Vector2.ONE * i * 3.0, size - Vector2.ONE * i * 6.0), Color(0, 0, 0, a), false, 3.0)
