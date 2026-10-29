class_name JobCarousel
extends VBoxContainer
# The board's jobs, one big card at a time (Story 17.4). Left and right (keys,
# d-pad, or the arrows either side) flip through them and wrap at the ends; the
# dots below mark where you are. Enter, pad A, or a click on the card asks the
# board to fly it (`activated`); a card that cannot fly gets `shake()`.
# Holds no job logic: the board builds the cards and decides what Enter does.

signal activated(index: int)
signal moved(index: int)

const ACCENT := Color(1.0, 0.76, 0.25)
const DIM := Color(1, 1, 1, 0.3)
const COUNTER := Color(1, 1, 1, 0.55)

## Seconds and pixels of a locked card's shake.
@export var shake_time := 0.35
@export var shake_px := 14.0

var cards: Array[Control] = []
var index := 0
## The lit card's border and the current dot; the board sets its skin's.
var accent := ACCENT:
	set(v):
		accent = v
		if dots:
			dots.accent = v
## Times a card has shaken; tests read it.
var shakes := 0
## Lights the card as if focused, e.g. while the menu's FLY item has focus.
var highlight := false:
	set(v):
		highlight = v
		_restyle()

var prev_button: Button
var next_button: Button
var dots: Dots
## "JOB 2 OF 8" beside the dots.
var counter: Label

var _stage: MarginContainer
var _tween: Tween

func _init() -> void:
	focus_mode = FOCUS_ALL
	add_theme_constant_override("separation", 8)
	var row := HBoxContainer.new()
	row.size_flags_vertical = SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	prev_button = _arrow("Prev", "<", prev)
	row.add_child(prev_button)
	_stage = MarginContainer.new()
	_stage.name = "Stage"
	_stage.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(_stage)
	next_button = _arrow("Next", ">", next)
	row.add_child(next_button)
	# The count and the dots share one line under the card.
	var pager := HBoxContainer.new()
	pager.name = "Pager"
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_theme_constant_override("separation", 16)
	add_child(pager)
	dots = Dots.new()
	dots.name = "Dots"
	dots.custom_minimum_size.y = 16
	counter = Label.new()
	counter.name = "Counter"
	counter.theme_type_variation = &"Display"
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.add_theme_color_override("font_color", COUNTER)
	counter.add_theme_font_size_override("font_size", 14)
	pager.add_child(counter)
	pager.add_child(dots)
	focus_entered.connect(_restyle)
	focus_exited.connect(_restyle)

## Replaces the cards, showing `start`. Old cards are freed.
func set_cards(new_cards: Array[Control], start := 0) -> void:
	for c in cards:
		c.free()
	cards = new_cards
	for c in cards:
		c.size_flags_vertical = SIZE_SHRINK_CENTER
		c.gui_input.connect(_on_card_input)
		_stage.add_child(c)
	dots.count = cards.size()
	dots.custom_minimum_size.x = 20.0 * cards.size()
	go(start)

func current() -> Control:
	return cards[index] if index < cards.size() else null

func go(i: int) -> void:
	if cards.is_empty():
		index = 0
		dots.current = 0
		counter.text = ""
		return
	index = posmod(i, cards.size())
	for j in cards.size():
		cards[j].visible = j == index
	dots.current = index
	counter.text = "JOB %d OF %d" % [index + 1, cards.size()]
	_restyle()
	moved.emit(index)

func next() -> void:
	go(index + 1)

func prev() -> void:
	go(index - 1)

func activate() -> void:
	if current():
		activated.emit(index)

## The current card wobbles side to side: it cannot fly.
func shake() -> void:
	var c := current()
	if c == null:
		return
	shakes += 1
	if _tween:
		_tween.kill()
	var home := 0.0  # the stage has no margins
	_tween = create_tween()
	for k in 4:
		_tween.tween_property(c, "position:x", home + shake_px * (1.0 if k % 2 == 0 else -1.0) * (1.0 - k / 4.0), shake_time / 5.0)
	_tween.tween_property(c, "position:x", home, shake_time / 5.0)
	_tween.finished.connect(_stage.queue_sort)

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right", true):
		next()
	elif event.is_action_pressed("ui_left", true):
		prev()
	elif event.is_action_pressed("ui_accept"):
		activate()
	else:
		return
	accept_event()

func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		activate()

## The shown card's border lights up while the carousel has focus.
func _restyle() -> void:
	var c := current()
	if c == null:
		return
	c.remove_theme_stylebox_override("panel")
	var box := c.get_theme_stylebox("panel")
	if box is StyleBoxFlat:
		var lit: StyleBoxFlat = box.duplicate()
		var on := has_focus() or highlight
		lit.border_color = accent if on else box.border_color
		lit.set_border_width_all(box.border_width_left + (2 if on else 0))
		c.add_theme_stylebox_override("panel", lit)

func _arrow(n: String, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = n
	b.text = text
	b.focus_mode = FOCUS_NONE
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(40, 72)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(action)
	return b

## One dot per card; the current one larger and lit.
class Dots extends Control:
	var count := 0:
		set(v):
			count = v
			queue_redraw()
	var current := 0:
		set(v):
			current = v
			queue_redraw()
	var accent := ACCENT
	func _draw() -> void:
		var gap := 20.0
		var left := size.x * 0.5 - gap * (count - 1) * 0.5
		for i in count:
			var at := Vector2(left + gap * i, size.y * 0.5)
			if i == current:
				draw_circle(at, 6.0, accent)
			else:
				draw_circle(at, 4.0, DIM)
