class_name BarkBox
extends Control
# The crew's lines on the HUD: a portrait, a name, and the line, low on the left.
# Each line holds for a few seconds; a new one replaces it. No audio.

@export var bark: Bark
## Seconds a line stays up.
@export var hold := 3.5

const PANEL := Color(0, 0, 0, 0.45)

var portrait: CharacterPortrait
var label: Label
## The line on screen: {id, event, text}, or {} when none.
var current := {}
var _age := INF

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	portrait = CharacterPortrait.new()
	portrait.size = Vector2(56, 56)
	portrait.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(portrait)
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	if bark:
		bark.spoke.connect(_on_spoke)
	_layout()

func _on_spoke(id: StringName, event: StringName, text: String) -> void:
	current = {"id": id, "event": event, "text": text}
	_age = 0.0
	var c: Character = Roster.character(id)
	portrait.character = c
	portrait.queue_redraw()
	label.text = "%s: %s" % [c.name if c else String(id), text]

func showing() -> bool:
	return not current.is_empty() and _age < hold

func _process(delta: float) -> void:
	_age += delta
	visible = showing()
	_layout()
	queue_redraw()

func _rect() -> Rect2:
	return Rect2(Vector2(28, size.y - 200), Vector2(400, 64))

func _layout() -> void:
	var r := _rect()
	portrait.position = r.position + Vector2(4, 4)
	label.position = r.position + Vector2(68, 0)
	label.size = Vector2(r.size.x - 76, r.size.y)

func _draw() -> void:
	if showing():
		draw_rect(_rect(), PANEL)
