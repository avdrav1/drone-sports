extends RefCounted
# Story 23.6: OPTIONS > CONTROLLER. Stick layout, inverted pitch, stick feel,
# deadzone and rumble survive a save and reload; Mode 1 swaps throttle and
# pitch and nothing else; invert makes stick-up pitch back; expo and deadzone
# reach PilotInput and the InputMap; the section works by pad; and the prompts
# name the swapped sticks.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"
const FLY: Array[StringName] = [&"pitch_forward", &"pitch_back", &"roll_left", &"roll_right",
	&"throttle_up", &"throttle_down", &"yaw_left", &"yaw_right"]

## Back to the defaults, saved, so no other test flies a changed pad.
func _defaults() -> void:
	GameSettings.stick_mode = StickLayout.MODE_2
	GameSettings.invert_pitch = false
	GameSettings.stick_expo = 0.4
	GameSettings.stick_deadzone = 0.2
	GameSettings.rumble = true
	GameSettings.save()
	StickLayout.apply()
	# Pad events here switch prompts to the pad; later files expect keys.
	InputPrompt.use_keys()

## Every action's events, as text, so a change anywhere shows.
func _bindings() -> Dictionary:
	var out := {}
	for a in InputMap.get_actions():
		var events: Array[String] = []
		for e in InputMap.action_get_events(a):
			events.append(e.as_text() + (" %d %.1f" % [e.axis, e.axis_value] if e is InputEventJoypadMotion else ""))
		out[a] = events
	return out

## The [axis, value] of `action`'s stick.
func _motion(action: StringName) -> Array:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion:
			return [e.axis, e.axis_value]
	return []

func _tilt(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
	await Sim.process_frames(2)

func _pad(index: JoyButton) -> Control:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = index
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await Sim.process_frames(2)
	return Sim.tree().root.gui_get_focus_owner()

func test_settings_survive_a_save_and_reload() -> bool:
	GameSettings.stick_mode = StickLayout.MODE_1
	GameSettings.invert_pitch = true
	GameSettings.stick_expo = 0.75
	GameSettings.stick_deadzone = 0.27
	GameSettings.rumble = false
	GameSettings.save()
	_defaults_in_memory_only()
	SaveGame.load_all(Sim.tree())
	var ok := GameSettings.stick_mode == StickLayout.MODE_1 and GameSettings.invert_pitch \
		and is_equal_approx(GameSettings.stick_expo, 0.75) and is_equal_approx(GameSettings.stick_deadzone, 0.27) \
		and not GameSettings.rumble
	# Loading put them on the InputMap too, as on boot.
	ok = ok and _motion(&"throttle_up")[0] == JOY_AXIS_RIGHT_Y \
		and is_equal_approx(InputMap.action_get_deadzone(&"roll_left"), 0.27)
	_defaults()
	return ok

func _defaults_in_memory_only() -> void:
	GameSettings.stick_mode = StickLayout.MODE_2
	GameSettings.invert_pitch = false
	GameSettings.stick_expo = 0.4
	GameSettings.stick_deadzone = 0.2
	GameSettings.rumble = true

func test_mode_2_is_the_layout_as_shipped() -> bool:
	_defaults()
	var ok := true
	for a in StickLayout.AXES:
		ok = ok and _motion(a) == StickLayout.AXES[a]
	return ok and is_equal_approx(InputMap.action_get_deadzone(&"pitch_forward"), 0.2)

func test_mode_1_swaps_throttle_and_pitch_only() -> bool:
	_defaults()
	var before := _bindings()
	GameSettings.stick_mode = StickLayout.MODE_1
	StickLayout.apply()
	var after := _bindings()
	var ok: bool = _motion(&"throttle_up") == [JOY_AXIS_RIGHT_Y, -1.0] and _motion(&"throttle_down") == [JOY_AXIS_RIGHT_Y, 1.0] \
		and _motion(&"pitch_forward") == [JOY_AXIS_LEFT_Y, -1.0] and _motion(&"pitch_back") == [JOY_AXIS_LEFT_Y, 1.0]
	for a in before:
		if a in [&"throttle_up", &"throttle_down", &"pitch_forward", &"pitch_back"]:
			# Their keys stay as they were.
			ok = ok and before[a].filter(func(t): return not t.contains("Joypad Motion")) \
				== after[a].filter(func(t): return not t.contains("Joypad Motion"))
		elif before[a] != after[a]:
			print("        %s changed: %s -> %s" % [a, before[a], after[a]])
			ok = false
	# The right stick pushed up now climbs; the left stick pushed up flies forward.
	await _tilt(JOY_AXIS_RIGHT_Y, -1.0)
	ok = ok and Input.get_axis(&"throttle_down", &"throttle_up") > 0.9 and Input.get_axis(&"pitch_back", &"pitch_forward") == 0.0
	await _tilt(JOY_AXIS_RIGHT_Y, 0.0)
	await _tilt(JOY_AXIS_LEFT_Y, -1.0)
	ok = ok and Input.get_axis(&"pitch_back", &"pitch_forward") > 0.9 and Input.get_axis(&"throttle_down", &"throttle_up") == 0.0
	await _tilt(JOY_AXIS_LEFT_Y, 0.0)
	_defaults()
	return ok and _bindings() == before

func test_invert_makes_stick_up_pitch_back() -> bool:
	_defaults()
	await _tilt(JOY_AXIS_RIGHT_Y, -1.0)
	var forward := Input.get_axis(&"pitch_back", &"pitch_forward")
	await _tilt(JOY_AXIS_RIGHT_Y, 0.0)
	GameSettings.invert_pitch = true
	StickLayout.apply()
	await _tilt(JOY_AXIS_RIGHT_Y, -1.0)
	var inverted := Input.get_axis(&"pitch_back", &"pitch_forward")
	await _tilt(JOY_AXIS_RIGHT_Y, 0.0)
	# Inverted in Mode 1 too, on the left stick.
	GameSettings.stick_mode = StickLayout.MODE_1
	StickLayout.apply()
	await _tilt(JOY_AXIS_LEFT_Y, -1.0)
	var mode_1 := Input.get_axis(&"pitch_back", &"pitch_forward")
	await _tilt(JOY_AXIS_LEFT_Y, 0.0)
	_defaults()
	return forward > 0.9 and inverted < -0.9 and mode_1 < -0.9

func test_expo_and_deadzone_reach_pilot_input_and_input_map() -> bool:
	_defaults()
	var section := ControllerOptions.new()
	Sim.add(section)
	section.feel.value = 0.8
	section.deadzone.value = 0.12
	var pilot := PilotInput.new()
	Sim.add(pilot)
	var ok: bool = is_equal_approx(GameSettings.stick_expo, 0.8) and is_equal_approx(pilot.expo, 0.8)
	for a in FLY:
		ok = ok and is_equal_approx(InputMap.action_get_deadzone(a), 0.12)
	# Saved as it changes.
	var saved: Dictionary = SaveGame.read_section("settings", {})
	ok = ok and is_equal_approx(float(saved.get("stick_expo", 0.0)), 0.8) and is_equal_approx(float(saved.get("stick_deadzone", 0.0)), 0.12)
	# A tilt under the deadzone does nothing; one over it does.
	await _tilt(JOY_AXIS_RIGHT_X, 0.1)
	ok = ok and Input.get_axis(&"roll_left", &"roll_right") == 0.0
	await _tilt(JOY_AXIS_RIGHT_X, 0.5)
	ok = ok and Input.get_axis(&"roll_left", &"roll_right") > 0.0
	await _tilt(JOY_AXIS_RIGHT_X, 0.0)
	# The deadzone stays in its range.
	section.deadzone.value = 0.9
	ok = ok and is_equal_approx(GameSettings.stick_deadzone, StickLayout.DEADZONE_MAX)
	section.free()
	pilot.free()
	_defaults()
	return ok

func test_section_works_by_pad() -> bool:
	_defaults()
	PlayerProfile.choose_pilot(&"pip")
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	await Sim.process_frames(1)
	b.open_options()
	var pad: ControllerOptions = b.find_child("Controller", true, false)
	var ok := pad != null and pad.is_visible_in_tree()
	# Down from Watch intro walks every row of the section, and back up.
	b.find_child("WatchIntro", true, false).grab_focus()
	for c in pad.focusables():
		var f := await _pad(JOY_BUTTON_DPAD_DOWN)
		if f != c:
			print("        expected %s, focus on %s" % [c.name, f.name if f else "nothing"])
			ok = false
			c.grab_focus()
	for c in [pad.feel, pad.invert, pad.layout, b.find_child("WatchIntro", true, false)]:
		var f := await _pad(JOY_BUTTON_DPAD_UP)
		ok = ok and f == c
	# Rumble is right of invert.
	pad.invert.grab_focus()
	ok = ok and await _pad(JOY_BUTTON_DPAD_RIGHT) == pad.rumble and await _pad(JOY_BUTTON_DPAD_DOWN) == pad.feel
	# Right slides the focused slider; left on a box goes back to the menu.
	pad.deadzone.grab_focus()
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	ok = ok and GameSettings.stick_deadzone > 0.2
	await _pad(JOY_BUTTON_DPAD_LEFT)
	ok = ok and is_equal_approx(GameSettings.stick_deadzone, 0.2)
	pad.invert.grab_focus()
	await _pad(JOY_BUTTON_A)
	ok = ok and GameSettings.invert_pitch and _motion(&"pitch_forward")[1] > 0.0
	await _pad(JOY_BUTTON_A)
	ok = ok and not GameSettings.invert_pitch
	pad.rumble.grab_focus()
	await _pad(JOY_BUTTON_A)
	ok = ok and not GameSettings.rumble
	pad.invert.grab_focus()
	var f := await _pad(JOY_BUTTON_DPAD_LEFT)
	ok = ok and f == b.menu_button(&"Options")
	# The layout picker opens, changes and closes by pad.
	pad.layout.grab_focus()
	await _pad(JOY_BUTTON_A)
	var popup := pad.layout.get_popup()
	ok = ok and popup.visible
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	ok = ok and not popup.visible and GameSettings.stick_mode == StickLayout.MODE_1
	# B leaves the page as Esc does.
	pad.layout.grab_focus()
	f = await _pad(JOY_BUTTON_B)
	ok = ok and b.page == &"jobs" and f == b.menu_button(&"Options")
	b.free()
	_defaults()
	return ok

func test_prompts_show_the_swapped_sticks() -> bool:
	_defaults()
	InputPrompt.use_pad(0, "Xbox Controller")
	var mode_2 := [ControlsHelp.keys_text([&"throttle_up", &"throttle_down"]), ControlsHelp.keys_text([&"pitch_forward", &"pitch_back"]),
		ControlsHelp.hint_line()]
	GameSettings.stick_mode = StickLayout.MODE_1
	StickLayout.apply()
	var mode_1 := [ControlsHelp.keys_text([&"throttle_up", &"throttle_down"]), ControlsHelp.keys_text([&"pitch_forward", &"pitch_back"]),
		ControlsHelp.hint_line()]
	# The controls panel, built after the change, names the swapped sticks.
	var help := ControlsHelp.new()
	Sim.add(help)
	var shown := _labels(help)
	InputPrompt.use_keys()
	help.free()
	_defaults()
	return mode_2[0] == "L stick ↑↓" and mode_2[1] == "R stick ↑↓" and mode_2[2].begins_with("R stick move") \
		and mode_1[0] == "R stick ↑↓" and mode_1[1] == "L stick ↑↓" \
		and mode_1[2].begins_with("L stick ↑↓ + R stick ←→ move") and mode_1[2].contains("R stick ↑↓ height") \
		and mode_1[2].contains("L stick ←→ turn") and shown.contains("L stick ↑↓\nForward / back") \
		and shown.contains("R stick ↑↓\nClimb / descend")

func _labels(node: Node) -> String:
	var out := ""
	for l in node.find_children("*", "Label", true, false):
		out += l.text + "\n"
	return out
