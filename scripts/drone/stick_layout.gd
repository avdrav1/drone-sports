class_name StickLayout
extends RefCounted
# The pad's flight sticks from OPTIONS > CONTROLLER (Story 23.6): Mode 2 or
# Mode 1, inverted pitch, and the deadzone, written onto the flight actions'
# InputEventJoypadMotion. Keys are left as they are, and so is every other
# action. Shaping only (rule 2): nothing here touches the flight model.

## Throttle and yaw on the left stick, pitch and roll on the right (the default).
const MODE_2 := 2
## Throttle and pitch swap sticks: pitch on the left stick's Y, throttle on the right's.
const MODE_1 := 1
const DEADZONE_MIN := 0.1
const DEADZONE_MAX := 0.3
## Mode 2, stick up is negative: action -> [axis, value].
const AXES := {
	&"throttle_up": [JOY_AXIS_LEFT_Y, -1.0], &"throttle_down": [JOY_AXIS_LEFT_Y, 1.0],
	&"yaw_left": [JOY_AXIS_LEFT_X, -1.0], &"yaw_right": [JOY_AXIS_LEFT_X, 1.0],
	&"pitch_forward": [JOY_AXIS_RIGHT_Y, -1.0], &"pitch_back": [JOY_AXIS_RIGHT_Y, 1.0],
	&"roll_left": [JOY_AXIS_RIGHT_X, -1.0], &"roll_right": [JOY_AXIS_RIGHT_X, 1.0],
}

## The flight actions' [axis, value] for a layout. Inverted, stick up pitches back.
static func axes(mode: int, invert: bool) -> Dictionary:
	var out := {}
	for action in AXES:
		var axis: JoyAxis = AXES[action][0]
		var value: float = AXES[action][1]
		if mode == MODE_1 and axis in [JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_Y]:
			axis = JOY_AXIS_RIGHT_Y if axis == JOY_AXIS_LEFT_Y else JOY_AXIS_LEFT_Y
		if invert and action in [&"pitch_forward", &"pitch_back"]:
			value = -value
		out[action] = [axis, value]
	return out

## Puts the saved layout, invert and deadzone (GameSettings) on the InputMap.
static func apply() -> void:
	var table := axes(GameSettings.stick_mode, GameSettings.invert_pitch)
	for action in table:
		if not InputMap.has_action(action):
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadMotion:
				InputMap.action_erase_event(action, e)
		var m := InputEventJoypadMotion.new()
		m.device = -1
		m.axis = table[action][0]
		m.axis_value = table[action][1]
		InputMap.action_add_event(action, m)
		InputMap.action_set_deadzone(action, GameSettings.stick_deadzone)
