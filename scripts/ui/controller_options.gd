class_name ControllerOptions
extends VBoxContainer
# OPTIONS > CONTROLLER (Story 23.6): stick layout (Mode 2 or Mode 1), inverted
# pitch, stick feel (expo), deadzone, and rumble. Each change is saved with the
# settings and put on the InputMap at once; a drone made after reads its expo.
# Every row works with the d-pad: up and down move, left and right slide.

const MODES := [[StickLayout.MODE_2, "Mode 2"], [StickLayout.MODE_1, "Mode 1"]]
const MODE_HINTS := {StickLayout.MODE_2: "Throttle on the left stick", StickLayout.MODE_1: "Throttle on the right stick"}
const DIM := Color(1, 1, 1, 0.55)
## A focused slider's row lights up, since the theme barely marks a slider.
const LIT := Color(1.0, 0.76, 0.25)

var layout: OptionButton
var invert: CheckBox
var feel: HSlider
var deadzone: HSlider
var rumble: CheckBox
var _mode_hint: Label
var _feel_value: Label
var _deadzone_value: Label

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	layout = OptionButton.new()
	layout.name = "Layout"
	for m in MODES:
		layout.add_item(m[1], m[0])
	layout.item_selected.connect(func(i): set_mode(layout.get_item_id(i)))
	layout.custom_minimum_size.x = 280
	var sticks := HBoxContainer.new()
	sticks.add_theme_constant_override("separation", 16)
	add_child(sticks)
	sticks.add_child(layout)
	_mode_hint = Label.new()
	_mode_hint.add_theme_color_override("font_color", DIM)
	sticks.add_child(_mode_hint)
	var checks := HBoxContainer.new()
	checks.add_theme_constant_override("separation", 24)
	add_child(checks)
	invert = CheckBox.new()
	invert.name = "Invert"
	invert.text = "Invert pitch"
	invert.toggled.connect(set_invert)
	checks.add_child(invert)
	rumble = CheckBox.new()
	rumble.name = "Rumble"
	rumble.text = "Rumble"
	rumble.toggled.connect(set_rumble)
	checks.add_child(rumble)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	add_child(grid)
	feel = _slider(grid, "Feel", "Stick feel", 0.0, 1.0, 0.05)
	feel.value_changed.connect(set_expo)
	_feel_value = grid.get_child(-1)
	deadzone = _slider(grid, "Deadzone", "Deadzone", StickLayout.DEADZONE_MIN, StickLayout.DEADZONE_MAX, 0.01)
	deadzone.value_changed.connect(set_deadzone)
	_deadzone_value = grid.get_child(-1)
	# Invert and rumble share a row: left and right move between them, and
	# both go down to the sliders and up to the layout; up from the sliders is invert.
	invert.focus_neighbor_right = invert.get_path_to(rumble)
	rumble.focus_neighbor_left = rumble.get_path_to(invert)
	for c in [invert, rumble]:
		c.focus_neighbor_top = c.get_path_to(layout)
		c.focus_neighbor_bottom = c.get_path_to(feel)
	feel.focus_neighbor_top = feel.get_path_to(invert)
	refresh()

## Shows the saved settings without saving them again.
func refresh() -> void:
	layout.select(layout.get_item_index(GameSettings.stick_mode))
	invert.set_pressed_no_signal(GameSettings.invert_pitch)
	rumble.set_pressed_no_signal(GameSettings.rumble)
	feel.set_value_no_signal(GameSettings.stick_expo)
	deadzone.set_value_no_signal(GameSettings.stick_deadzone)
	_show_values()

## The rows that take focus, top to bottom (rumble is right of invert).
func focusables() -> Array[Control]:
	return [layout, invert, feel, deadzone]

func set_mode(mode: int) -> void:
	GameSettings.stick_mode = mode
	_save()

func set_invert(on: bool) -> void:
	GameSettings.invert_pitch = on
	_save()

func set_expo(v: float) -> void:
	GameSettings.stick_expo = v
	_save()

func set_deadzone(v: float) -> void:
	GameSettings.stick_deadzone = v
	_save()

func set_rumble(on: bool) -> void:
	GameSettings.rumble = on
	_save()

func _save() -> void:
	GameSettings.save()
	StickLayout.apply()
	_show_values()

func _show_values() -> void:
	_mode_hint.text = MODE_HINTS[GameSettings.stick_mode]
	_feel_value.text = "Linear" if GameSettings.stick_expo <= 0.0 else "%d%% soft" % roundi(GameSettings.stick_expo * 100.0)
	_deadzone_value.text = "%d%%" % roundi(GameSettings.stick_deadzone * 100.0)

## A label, a slider, and a label for its value, in three grid cells.
func _slider(grid: GridContainer, slider_name: String, text: String, lo: float, hi: float, step: float) -> HSlider:
	var l := Label.new()
	l.text = text
	grid.add_child(l)
	var s := HSlider.new()
	s.name = slider_name
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size.x = 160
	s.size_flags_vertical = SIZE_SHRINK_CENTER
	grid.add_child(s)
	var v := Label.new()
	v.custom_minimum_size.x = 72
	grid.add_child(v)
	s.focus_entered.connect(func():
		for t in [l, v]:
			t.add_theme_color_override("font_color", LIT))
	s.focus_exited.connect(func():
		for t in [l, v]:
			t.remove_theme_color_override("font_color"))
	return s
