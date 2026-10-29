extends Node
# Autoload InputPrompt: which device the player last touched, and the name of
# an action's key or button on it (Story 23.2). A key or mouse button means
# keys; a pad button, or a stick past the flight deadzone, means the pad. The
# pad's family comes from its name, so a PlayStation pad reads "Cross" where an
# Xbox pad reads "A". Prompts call text(action) and redraw on device_changed.
# Text only, in the existing fonts: no glyph images.

## The player switched between keys and pad, or to another family of pad.
signal device_changed(pad: bool)

enum Family { XBOX, PLAYSTATION, NINTENDO }

## Key names as shown to the player (the key table; OS names otherwise).
const KEY_NAMES := {"Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "Slash": "?", "Escape": "Esc"}
const DPAD := {JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓",
	JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →"}
## Face, shoulder and middle buttons per family, by JoyButton index.
const BUTTONS := {
	Family.XBOX: {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB"},
	Family.PLAYSTATION: {JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square",
		JOY_BUTTON_Y: "Triangle", JOY_BUTTON_BACK: "Create", JOY_BUTTON_GUIDE: "PS", JOY_BUTTON_START: "Options",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1"},
	# Godot names buttons by position: the bottom one (A) is Nintendo's B.
	Family.NINTENDO: {JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
		JOY_BUTTON_BACK: "−", JOY_BUTTON_GUIDE: "Home", JOY_BUTTON_START: "+",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R"},
}
const TRIGGERS := {
	Family.XBOX: ["LT", "RT"], Family.PLAYSTATION: ["L2", "R2"], Family.NINTENDO: ["ZL", "ZR"],
}
## Words in a pad's name that give its family away.
const PLAYSTATION_NAMES: Array[String] = ["playstation", "dualshock", "dualsense", "sony", "ps3", "ps4", "ps5"]
const NINTENDO_NAMES: Array[String] = ["nintendo", "switch", "joy-con", "joycon"]

## True once the pad was the last thing touched.
var pad := false
var family := Family.XBOX
## The pad last touched, or -1.
var device := -1

func _ready() -> void:
	# Pause dialogs still need the right names.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The window hears every event before any node can mark it handled; _input
	# also hears events pushed straight into the viewport.
	get_tree().root.window_input.connect(seen)

func _input(event: InputEvent) -> void:
	seen(event)

## Notes which device `event` came from.
func seen(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			use_keys()
	elif event is InputEventJoypadButton:
		if event.is_pressed():
			use_pad(event.device, Input.get_joy_name(event.device))
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > InputMap.action_get_deadzone(&"pitch_forward"):
			use_pad(event.device, Input.get_joy_name(event.device))

func use_keys() -> void:
	if pad:
		pad = false
		device_changed.emit(false)

## The pad `id`, named `joy_name`, was touched.
func use_pad(id: int, joy_name: String) -> void:
	device = id
	var f := family_of(joy_name)
	if not pad or f != family:
		pad = true
		family = f
		device_changed.emit(true)

static func family_of(joy_name: String) -> Family:
	var n := joy_name.to_lower()
	for word in PLAYSTATION_NAMES:
		if n.contains(word):
			return Family.PLAYSTATION
	for word in NINTENDO_NAMES:
		if n.contains(word):
			return Family.NINTENDO
	return Family.XBOX

## `action`'s key or button on the device last touched, e.g. "Enter" or "A".
## On a pad, empty when the action has no button (a keyboard-only shortcut).
func text(action: StringName) -> String:
	return pad_text(action) if pad else key_text(action)

## Several actions as one prompt: "W / S" on keys; on a pad, one stick's axis
## reads "L stick ↑↓", a whole stick "R stick", and d-pad arrows "D-pad ↑↓".
func group_text(actions: Array, separator := " / ") -> String:
	if pad:
		var stick := stick_text(actions)
		if stick != "":
			return stick
		var split := split_stick_text(actions)
		if split != "":
			return split
		var names: Array = actions.map(func(a): return pad_text(a))
		if names.all(func(s): return DPAD.values().has(s)):
			return "D-pad " + "".join(names.map(func(s): return s.trim_prefix("D-pad ")))
		return separator.join(names)
	return separator.join(actions.map(func(a): return key_text(a)))

## The first keyboard key bound to `action`; empty when none.
func key_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var code: Key = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
			var s := OS.get_keycode_string(code)
			return ("Shift+" if e.shift_pressed else "") + KEY_NAMES.get(s, s)
	return ""

## The first pad button or stick bound to `action`, named for the current family.
func pad_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			return button_name(e.button_index)
		if e is InputEventJoypadMotion:
			return axis_name(e.axis, e.axis_value)
	return ""

func button_name(index: JoyButton) -> String:
	if DPAD.has(index):
		return DPAD[index]
	return BUTTONS[family].get(index, "Button %d" % index)

func axis_name(axis: JoyAxis, value: float) -> String:
	match axis:
		JOY_AXIS_TRIGGER_LEFT:
			return TRIGGERS[family][0]
		JOY_AXIS_TRIGGER_RIGHT:
			return TRIGGERS[family][1]
	var arrow := ("←" if value < 0.0 else "→") if axis in [JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X] \
		else ("↑" if value < 0.0 else "↓")
	return "%s %s" % [_stick_name(axis), arrow]

func _stick_name(axis: JoyAxis) -> String:
	return "L stick" if axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] else "R stick"

## On a pad, "L stick ↑↓" when every action is one axis of one stick, "R stick"
## when they cover both of its axes; empty otherwise, and always on keys.
func stick_text(actions: Array) -> String:
	if not pad:
		return ""
	var axes := {}
	for a in actions:
		var motion: InputEventJoypadMotion = null
		for e in InputMap.action_get_events(a) if InputMap.has_action(a) else []:
			if e is InputEventJoypadButton:
				return ""
			if e is InputEventJoypadMotion:
				motion = e
				break
		if motion == null or motion.axis > JOY_AXIS_RIGHT_Y:
			return ""
		axes[motion.axis] = true
	var names := {}
	for axis in axes:
		names[_stick_name(axis)] = true
	if axes.is_empty() or names.size() != 1:
		return ""
	if axes.size() > 1:
		return names.keys()[0]
	var horizontal: bool = axes.keys()[0] in [JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X]
	return "%s %s" % [names.keys()[0], "←→" if horizontal else "↑↓"]

## On a pad, actions spread over both sticks one stick at a time, e.g. Mode 1's
## pitch and roll as "L stick ↑↓ + R stick ←→" (Story 23.6); empty otherwise.
func split_stick_text(actions: Array) -> String:
	var by_stick := {}
	for a in actions:
		var motion: InputEventJoypadMotion = null
		for e in InputMap.action_get_events(a) if InputMap.has_action(a) else []:
			if e is InputEventJoypadMotion:
				motion = e
				break
		if motion == null or motion.axis > JOY_AXIS_RIGHT_Y:
			return ""
		var stick := _stick_name(motion.axis)
		if not by_stick.has(stick):
			by_stick[stick] = []
		by_stick[stick].append(a)
	if by_stick.size() < 2:
		return ""
	var parts: Array[String] = []
	for stick in by_stick:
		parts.append(stick_text(by_stick[stick]))
	return "" if parts.has("") else " + ".join(parts)
