class_name PadCheck
extends PanelContainer
# OPTIONS > PAD CHECK (Story 23.8): both sticks live, the triggers, and the name
# of each button as it is pressed, with the pad's name from Input.get_joy_name
# and the family InputPrompt reads it as. A pad the browser maps differently
# from Godot (the right stick not on axes 2 and 3, say) shows it here: the wrong
# dot moves, and the raw axis and button numbers say which. While it shows it
# takes every key and button, so nothing pressed to test moves the menu; Back
# (B or Esc) leaves. Story 28.3: the footer names the leave buttons in the
# family of the pad on the page, plus Esc, and says the rest are only shown.
# Story 28.5: REMAP (hold Start, or R) walks through the face, shoulder and
# middle buttons and takes whichever physical button is pressed for each, for a
# pad that reports them in the wrong order; Esc cancels it. RESET (hold Back, or
# Backspace) shows while the pad has a remap and puts the project's back. The
# page names buttons as remapped (PadRemap.logical).

## Back was pressed: the board shows OPTIONS again.
signal closed

const FAMILY_NAMES := {InputPrompt.Family.XBOX: "Xbox", InputPrompt.Family.PLAYSTATION: "PlayStation",
	InputPrompt.Family.NINTENDO: "Nintendo"}
## The buttons laid out on the page, in order.
const BUTTONS: Array[JoyButton] = [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y,
	JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_BACK, JOY_BUTTON_START,
	JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN,
	JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
const LIT := Color(1.0, 0.76, 0.25)
const DIM := Color(1, 1, 1, 0.55)
## Seconds Start (REMAP) or Back (RESET) is held to act.
const HOLD := 1.0

## The pad the page reads, the last one touched; -1 before any.
var device := -1
## Axis -> its value, as the last motion event left it.
var axes := {}
## Buttons held now.
var held := {}
## The last button pressed, and its name on the pad's family ("A", "Cross").
var last_button := -1
var last_button_text := ""
## The REMAP walk: the step it is on (an index into PadRemap.STEPS), -1 when
## not walking; the physical buttons given so far; the pad walked.
var walk_step := -1
var walk_map := {}
var walk_device := -1
## The line under the step, e.g. a refused button; "" for none.
var walk_note := ""
var remap_button: Button
var reset_button: Button
var left_stick: StickView
var right_stick: StickView
var left_trigger: TriggerView
var right_trigger: TriggerView

var _name: Label
var _last: Label
var _raw: Label
var _back: Label
var _buttons := {}  # JoyButton -> its Label
var _walk: Label
var _how: Label
var _last_raw := -1
var _held_for := 0.0

func _ready() -> void:
	focus_mode = FOCUS_ALL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := Label.new()
	title.text = "PAD CHECK"
	title.theme_type_variation = &"Display"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.35, 0.8, 0.95))
	box.add_child(title)
	_name = _label(box, 18)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	left_trigger = _trigger(row)
	left_stick = _stick(row, "L stick")
	right_stick = _stick(row, "R stick")
	right_trigger = _trigger(row)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = SIZE_SHRINK_CENTER
	box.add_child(grid)
	for b in BUTTONS:
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 15)
		grid.add_child(l)
		_buttons[b] = l
	_last = _label(box, 18)
	_walk = _label(box, 18)
	_walk.add_theme_color_override("font_color", LIT)
	_walk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	box.add_child(actions)
	remap_button = _action_button(actions, start_remap)
	reset_button = _action_button(actions, reset_remap)
	remap_button.text = "REMAP"
	reset_button.text = "RESET"
	_how = Label.new()
	_how.add_theme_font_size_override("font_size", 14)
	_how.add_theme_color_override("font_color", DIM)
	_how.size_flags_vertical = SIZE_SHRINK_CENTER
	actions.add_child(_how)
	_raw = _label(box, 13)
	_raw.add_theme_color_override("font_color", DIM)
	_back = _label(box, 14)
	_back.add_theme_color_override("font_color", DIM)
	InputPrompt.device_changed.connect(func(_pad): _show())
	visibility_changed.connect(func(): if visible: _show())
	_show()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if walking():
		# Every pad button is a step's answer, B and Start too; only Esc leaves.
		if event is InputEventKey and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
			cancel_remap()
		elif event is InputEventJoypadButton and event.pressed:
			take(event.device, event.button_index)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		closed.emit()
		return
	if event is InputEventJoypadMotion:
		device = event.device
		axes[event.axis] = event.axis_value
		_show()
	elif event is InputEventJoypadButton:
		device = event.device
		var b := PadRemap.logical(event.button_index)
		if event.pressed:
			held[b] = true
			last_button = b
			_last_raw = event.button_index
			last_button_text = _name_on(family_of_device(), b as JoyButton)
		else:
			held.erase(b)
		_held_for = 0.0
		_show()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			start_remap()
		elif event.physical_keycode == KEY_BACKSPACE and has_remap():
			reset_remap()
	# Nothing pressed here moves the menu or presses a button behind the page.
	# PadMenus' stick and d-pad repeats arrive as actions.
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion \
			or event is InputEventAction:
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var holding := not walking() and (held.has(JOY_BUTTON_START) or (held.has(JOY_BUTTON_BACK) and has_remap()))
	_held_for = _held_for + delta if holding else 0.0
	if _held_for >= HOLD:
		_held_for = 0.0
		if held.has(JOY_BUTTON_START):
			start_remap()
		else:
			reset_remap()

func walking() -> bool:
	return walk_step >= 0

## True when the pad on the page (or, before one is touched, the one in use)
## has a remap.
func has_remap() -> bool:
	return PadRemap.has_remap(joy_name() if device >= 0 else PadRemap.active)

## REMAP: starts the walk at A. The old remap stays on until the walk ends.
func start_remap() -> void:
	walk_step = 0
	walk_map = {}
	walk_device = device
	walk_note = ""
	held.clear()
	_show()

## The physical button `index` on pad `id` answers the step on now. One given
## already this walk is refused and the step stays.
func take(id: int, index: int) -> void:
	if walk_device < 0:
		walk_device = id
		device = id
	elif id != walk_device:
		return
	var f := InputPrompt.family_of(Input.get_joy_name(walk_device))
	for b in walk_map:
		if walk_map[b] == index:
			walk_note = "That button is already %s. Press another." % _name_on(f, b)
			_show()
			return
	walk_map[PadRemap.STEPS[walk_step]] = index
	walk_note = ""
	walk_step += 1
	if walk_step >= PadRemap.STEPS.size():
		walk_step = -1
		PadRemap.set_remap(Input.get_joy_name(walk_device), walk_map)
		last_button = -1
		last_button_text = ""
	_show()

## Esc mid-walk: nothing changes.
func cancel_remap() -> void:
	walk_step = -1
	walk_map = {}
	walk_note = ""
	_show()

## RESET: the pad's buttons as the project binds them.
func reset_remap() -> void:
	PadRemap.reset(joy_name() if device >= 0 else PadRemap.active)
	held.clear()
	_show()

## The pad's name as the browser or OS gives it, "" before any pad was touched.
func joy_name() -> String:
	return Input.get_joy_name(device) if device >= 0 else ""

func family_of_device() -> InputPrompt.Family:
	return InputPrompt.family_of(joy_name())

## Forgets what the last visit saw.
func reset() -> void:
	walk_step = -1
	walk_map = {}
	walk_note = ""
	_held_for = 0.0
	axes.clear()
	held.clear()
	last_button = -1
	last_button_text = ""
	_show()

func axis(a: JoyAxis) -> float:
	return axes.get(a, 0.0)

func _show() -> void:
	if _name == null:
		return
	var f := family_of_device()
	if device < 0:
		_name.text = "Press any button on the pad."
	else:
		_name.text = "%s  ·  %s layout" % [joy_name() if joy_name() != "" else "Pad %d" % device, FAMILY_NAMES[f]]
	left_stick.value = Vector2(axis(JOY_AXIS_LEFT_X), axis(JOY_AXIS_LEFT_Y))
	right_stick.value = Vector2(axis(JOY_AXIS_RIGHT_X), axis(JOY_AXIS_RIGHT_Y))
	left_trigger.value = axis(JOY_AXIS_TRIGGER_LEFT)
	right_trigger.value = axis(JOY_AXIS_TRIGGER_RIGHT)
	left_trigger.text = InputPrompt.TRIGGERS[f][0]
	right_trigger.text = InputPrompt.TRIGGERS[f][1]
	for b in _buttons:
		var l: Label = _buttons[b]
		l.text = _name_on(f, b)
		l.add_theme_color_override("font_color", LIT if held.has(b) else DIM)
	_last.text = "Pressed: %s  (button %d)" % [last_button_text, _last_raw] if last_button >= 0 else "Pressed: nothing yet"
	var raw: Array[String] = []
	for a in range(JOY_AXIS_LEFT_X, JOY_AXIS_TRIGGER_RIGHT + 1):
		raw.append("%d: %+.2f" % [a, axis(a)])
	_raw.text = "Axes  " + "   ".join(raw)
	_back.text = back_text(f)
	_walk.visible = walking()
	reset_button.visible = has_remap() and not walking()
	remap_button.visible = not walking()
	_how.visible = not walking()
	_how.text = "Hold %s or press R: REMAP." % _name_on(f, JOY_BUTTON_START)
	if reset_button.visible:
		_how.text += "\nHold %s or press Backspace: RESET." % _name_on(f, JOY_BUTTON_BACK)
	if walking():
		var wf := InputPrompt.family_of(Input.get_joy_name(walk_device)) if walk_device >= 0 else f
		var b: JoyButton = PadRemap.STEPS[walk_step]
		_walk.text = "REMAP %d of %d: press %s, %s." % [walk_step + 1, PadRemap.STEPS.size(), _name_on(wf, b), PadRemap.WHERE[b]]
		if walk_note != "":
			_walk.text += "\n" + walk_note
		_back.text = "%s: cancel REMAP, the buttons stay as they were. Every pad button answers the step." \
			% InputPrompt.key_text(&"ui_cancel")

## The footer for a pad of family `f`: every button and key that leaves
## (ui_cancel), named on that family, e.g. "B or Esc: back to OPTIONS. ...".
static func back_text(f: InputPrompt.Family) -> String:
	return "%s: back to OPTIONS. Every other button is only shown here." % " or ".join(leave_names(f))

## The names of what leaves the page on family `f`: its pad buttons, then keys.
static func leave_names(f: InputPrompt.Family) -> Array[String]:
	var pads: Array[String] = []
	var keys: Array[String] = []
	for e in InputMap.action_get_events(&"ui_cancel"):
		if e is InputEventJoypadButton:
			pads.append(_name_on(f, PadRemap.logical(e.button_index) as JoyButton))
		elif e is InputEventKey:
			var code: Key = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
			var k := OS.get_keycode_string(code)
			keys.append(InputPrompt.KEY_NAMES.get(k, k))
	return pads + keys

## A button's name on family `f`, whatever family the prompts use.
static func _name_on(f: InputPrompt.Family, b: JoyButton) -> String:
	if InputPrompt.DPAD.has(b):
		return InputPrompt.DPAD[b]
	return InputPrompt.BUTTONS[f].get(b, "Button %d" % b)

func _action_button(row: Container, press: Callable) -> Button:
	var b := Button.new()
	# Focus stays on the page, which takes every button: these are held or keyed.
	b.focus_mode = FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(press)
	row.add_child(b)
	return b

func _label(box: Container, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	box.add_child(l)
	return l

func _stick(row: Container, caption: String) -> StickView:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var s := StickView.new()
	s.custom_minimum_size = Vector2(112, 112)
	col.add_child(s)
	var l := Label.new()
	l.text = caption
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", DIM)
	col.add_child(l)
	return s

func _trigger(row: Container) -> TriggerView:
	var t := TriggerView.new()
	t.custom_minimum_size = Vector2(36, 130)
	t.size_flags_vertical = SIZE_SHRINK_BEGIN
	row.add_child(t)
	return t

## A stick seen from above: its ring, the deadzone, and a dot where it points.
class StickView extends Control:
	var value := Vector2.ZERO:
		set(v):
			value = v
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 4.0
		draw_circle(c, r, Color(1, 1, 1, 0.06))
		draw_arc(c, r, 0.0, TAU, 48, DIM, 2.0)
		draw_arc(c, r * GameSettings.stick_deadzone, 0.0, TAU, 24, Color(1, 1, 1, 0.25), 1.0)
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(1, 1, 1, 0.12))
		draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(1, 1, 1, 0.12))
		draw_circle(c + value.limit_length(1.0) * r, 9.0, LIT)

## A trigger: a bar that fills as it is pulled, its name under it.
class TriggerView extends Control:
	var value := 0.0:
		set(v):
			value = v
			queue_redraw()
	var text := "":
		set(v):
			text = v
			queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		var label_h := 18.0
		var bar := Rect2(Vector2(8, 0), Vector2(size.x - 16, size.y - label_h - 4))
		draw_rect(bar, Color(1, 1, 1, 0.06))
		var fill := clampf(value, 0.0, 1.0) * bar.size.y
		draw_rect(Rect2(bar.position + Vector2(0, bar.size.y - fill), Vector2(bar.size.x, fill)), LIT)
		draw_rect(bar, DIM, false, 2.0)
		draw_string(font, Vector2(0, size.y - 2), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, DIM)
