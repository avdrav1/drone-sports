extends RefCounted
# Story 23.8: PAD CHECK. Reached from OPTIONS and left again by pad alone; it
# shows both sticks and the triggers as they move, the name of each button as
# it is pressed, and the pad's name and family. Nothing pressed on it moves the
# menu behind it.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"

func _parse(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	await Sim.process_frames(2)

func _button(index: JoyButton, pressed := true) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = index
	ev.pressed = pressed
	await _parse(ev)

func _press(index: JoyButton) -> Control:
	await _button(index)
	await _button(index, false)
	return Sim.tree().root.gui_get_focus_owner()

func _tilt(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	await _parse(ev)

func test_reached_and_left_by_pad() -> bool:
	PlayerProfile.choose_pilot(&"pip")
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	await Sim.process_frames(1)
	b.menu_button(&"Options").grab_focus()
	await _press(JOY_BUTTON_A)
	var pad: ControllerOptions = b.find_child("Controller", true, false)
	pad.rumble.grab_focus()
	var f := await _press(JOY_BUTTON_DPAD_RIGHT)
	var ok: bool = b.page == &"options" and f == pad.pad_check
	f = await _press(JOY_BUTTON_A)
	var page: PadCheck = b.pages[&"pad_check"]
	ok = ok and b.page == &"pad_check" and page.is_visible_in_tree() and f == page \
		and not b.pages[&"options"].visible
	# The d-pad and A are shown, not obeyed: focus stays and nothing opens.
	for button in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_A, JOY_BUTTON_START]:
		f = await _press(button)
		ok = ok and f == page and b.page == &"pad_check" and not b.sound.visible
	ok = ok and page.last_button == JOY_BUTTON_START
	# Tilting the left stick or holding the d-pad, which PadMenus turns into
	# repeated ui_* actions, does not move focus off the page either.
	await _tilt(JOY_AXIS_LEFT_X, -0.9)
	ok = ok and Sim.tree().root.gui_get_focus_owner() == page
	await _tilt(JOY_AXIS_LEFT_X, 0.0)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await Sim.tree().create_timer(PadMenus.REPEAT_DELAY + 3 * PadMenus.REPEAT_EVERY).timeout
	ok = ok and Sim.tree().root.gui_get_focus_owner() == page and b.page == &"pad_check"
	await _button(JOY_BUTTON_DPAD_DOWN, false)
	# B is OPTIONS again, on the button that opened the page; B again is the menu.
	f = await _press(JOY_BUTTON_B)
	ok = ok and b.page == &"options" and f == pad.pad_check and not page.visible
	f = await _press(JOY_BUTTON_B)
	ok = ok and b.page == &"jobs" and f == b.menu_button(&"Options")
	b.free()
	InputPrompt.use_keys()
	return ok

func test_shows_sticks_triggers_and_button_names() -> bool:
	PlayerProfile.choose_pilot(&"pip")
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	await Sim.process_frames(1)
	b.open_options()
	b.open_pad_check()
	var page: PadCheck = b.pages[&"pad_check"]
	var ok: bool = page.left_stick.value == Vector2.ZERO and page.right_stick.value == Vector2.ZERO and page.last_button == -1
	await _tilt(JOY_AXIS_LEFT_X, -0.5)
	await _tilt(JOY_AXIS_LEFT_Y, 0.25)
	await _tilt(JOY_AXIS_RIGHT_X, 0.75)
	await _tilt(JOY_AXIS_RIGHT_Y, -1.0)
	await _tilt(JOY_AXIS_TRIGGER_RIGHT, 0.6)
	ok = ok and page.left_stick.value.is_equal_approx(Vector2(-0.5, 0.25)) \
		and page.right_stick.value.is_equal_approx(Vector2(0.75, -1.0)) \
		and is_equal_approx(page.right_trigger.value, 0.6) and page.left_trigger.value == 0.0
	# The raw axis numbers are on the page, so a stick on the wrong axes shows.
	ok = ok and _text(page).contains("3: -1.00") and _text(page).contains("2: +0.75")
	# Each button is named as it is pressed, on the pad's own family, and lit while held.
	var family := InputPrompt.family_of(Input.get_joy_name(0))
	for button in [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_UP]:
		await _button(button)
		var want := PadCheck._name_on(family, button)
		ok = ok and page.held.has(button) and page.last_button == button and page.last_button_text == want \
			and _text(page).contains("Pressed: %s" % want)
		await _button(button, false)
		ok = ok and not page.held.has(button) and page.last_button == button
	# A PlayStation pad's names, and its name and family line.
	ok = ok and PadCheck._name_on(InputPrompt.Family.PLAYSTATION, JOY_BUTTON_X) == "Square" \
		and PadCheck._name_on(InputPrompt.Family.PLAYSTATION, JOY_BUTTON_A) == "Cross"
	ok = ok and _text(page).contains("%s layout" % PadCheck.FAMILY_NAMES[family])
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_RIGHT]:
		await _tilt(axis, 0.0)
	ok = ok and page.right_stick.value == Vector2.ZERO
	# A new visit starts clean.
	b.close_pad_check()
	b.open_pad_check()
	ok = ok and page.last_button == -1 and page.held.is_empty()
	b.free()
	InputPrompt.use_keys()
	return ok

func _text(node: Node) -> String:
	var out := ""
	for l in node.find_children("*", "Label", true, false):
		out += l.text + "\n"
	return out
