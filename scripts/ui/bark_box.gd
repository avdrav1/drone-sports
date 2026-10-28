class_name BarkBox
extends Control
# The crew's lines on the HUD: a portrait, a name, and the line, low on the left.
# Each line holds for a few seconds; a new one replaces it. No audio.
# Story 17.2: the line types out at a steady rate while the speaker's face makes
# the line's expression and talks, then holds the expression once it is all out.

@export var bark: Bark
## Seconds a line stays up after it has typed out.
@export var hold := 3.5
## Characters of the line typed per second.
@export var type_rate := 30.0

const PANEL := Color(0, 0, 0, 0.45)

var portrait: CharacterPortrait
var label: Label
## The line on screen: {id, event, text, face}, or {} when none.
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
	# Lay the whole line out first, so words do not jump lines as it types.
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	if bark:
		bark.spoke.connect(_on_spoke)
	_layout()

func _on_spoke(id: StringName, event: StringName, text: String) -> void:
	current = {"id": id, "event": event, "text": text, "face": Bark.face_of(id, event, text)}
	_age = 0.0
	var c: Character = Roster.character(id)
	portrait.character = c
	portrait.expression = current.face
	portrait.queue_redraw()
	label.text = "%s: %s" % [c.name if c else String(id), text]
	_type()

## Seconds the current line takes to type out.
func type_time() -> float:
	return String(current.get("text", "")).length() / type_rate

## True while the current line is still typing out.
func typing() -> bool:
	return not current.is_empty() and _age < type_time()

func showing() -> bool:
	return not current.is_empty() and _age < type_time() + hold

func _process(delta: float) -> void:
	_age += delta
	_type()
	visible = showing()
	_layout()
	queue_redraw()

## Reveals the name at once and the line up to where it has typed.
func _type() -> void:
	portrait.talking = typing()
	if not portrait.talking:
		label.visible_characters = -1
		return
	var line := String(current.text)
	label.visible_characters = label.text.length() - line.length() + floori(_age * type_rate)

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
