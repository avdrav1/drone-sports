class_name ChorusBox
extends Control
# The chorus on the HUD: its dot-grid portrait and the line, low on the right.
# The grid thins as the shell loses units, so the portrait tracks the fight.

@export var chorus: Chorus
## Seconds a line stays up.
@export var hold := 4.0
## Dots per side of the full grid.
@export var grid := 9

const DOT := Color(0.8, 0.85, 0.95)
const PANEL := Color(0, 0, 0, 0.45)

var label: Label
var text := ""
var _age := INF

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", DOT)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	if chorus:
		chorus.spoke.connect(_on_spoke)

func _on_spoke(_event: StringName, line: String) -> void:
	text = line
	_age = 0.0

func _process(delta: float) -> void:
	_age += delta
	label.text = text if _age < hold else ""
	var s := get_viewport_rect().size
	label.position = Vector2(s.x - 560, s.y - 190)
	label.size = Vector2(440, 64)
	queue_redraw()

## Share of the shell still standing, 0..1.
func density() -> float:
	if chorus == null or chorus.fight.lattice.units.is_empty():
		return 0.0
	var l := chorus.fight.lattice
	return float(l.remaining()) / l.units.size()

## Dots the portrait draws now.
func dots() -> int:
	return roundi(grid * grid * density())

func _draw() -> void:
	if _age >= hold:
		return
	var s := get_viewport_rect().size
	var box := Rect2(s.x - 104, s.y - 194, 72, 72)
	draw_rect(box, PANEL)
	var n := dots()
	var step := box.size.x / grid
	# Thin from the outside in, in a fixed order, so the face erodes evenly.
	var order: Array[int] = []
	for i in grid * grid:
		order.append(i)
	order.sort_custom(func(a, b): return (a * 37) % (grid * grid) < (b * 37) % (grid * grid))
	for k in n:
		var i: int = order[k]
		draw_circle(box.position + Vector2((i % grid) + 0.5, (i / grid) + 0.5) * step, step * 0.3, DOT)
