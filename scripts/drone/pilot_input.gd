class_name PilotInput
extends IntentSource
# Gamepad and keyboard sticks. Actions are defined in project.godot.
# Keys are digital, so held keys ramp the stick instead of snapping it, and
# once altitude hold is off the keyboard throttle stays where it was left.
# Shaping only: nothing here changes how the drone flies.

const AXES := {
	&"throttle": [&"throttle_down", &"throttle_up"],
	&"pitch": [&"pitch_back", &"pitch_forward"],
	&"roll": [&"roll_left", &"roll_right"],
	&"yaw": [&"yaw_left", &"yaw_right"],
}

## Seconds for a held key to move the stick from center to full.
@export var key_ramp_time := 0.15
## Expo on pitch, roll, yaw: 0 is linear, 1 is fully cubic.
@export var expo := 0.4
## Latched keyboard throttle change per second while W or S is held.
@export var throttle_nudge_rate := 0.5

## Latched throttle level used while altitude hold is off.
var throttle_level := 0.0
var _ramped := {&"throttle": 0.0, &"pitch": 0.0, &"roll": 0.0, &"yaw": 0.0}
var _latched := false
var _throttle_from_keys := true

func read_intent() -> Intent:
	var keys := {}
	var pad := {}
	for axis in AXES:
		var neg: StringName = AXES[axis][0]
		var pos: StringName = AXES[axis][1]
		keys[axis] = float(_key_held(pos)) - float(_key_held(neg))
		pad[axis] = Input.get_axis(neg, pos) if keys[axis] == 0.0 else 0.0
	return shape(keys, pad, get_physics_process_delta_time(), _wants_latch())

## Pure shaping step. keys: -1/0/1 per axis from the keyboard; pad: analog per axis.
func shape(keys: Dictionary, pad: Dictionary, delta: float, latch: bool) -> Intent:
	var i := Intent.new()
	for axis in [&"pitch", &"roll", &"yaw"]:
		i.set(axis, curve(_stick(axis, keys[axis], pad[axis], delta)))
	if latch and not _latched:
		throttle_level = _hover_throttle()
		_throttle_from_keys = true
	_latched = latch
	if not latch:
		i.throttle = _stick(&"throttle", keys.throttle, pad.throttle, delta)
	elif keys.throttle != 0.0:
		_throttle_from_keys = true
		throttle_level = clampf(throttle_level + keys.throttle * throttle_nudge_rate * delta, -1.0, 1.0)
		i.throttle = throttle_level
	elif absf(pad.throttle) > 0.0:
		_throttle_from_keys = false
		i.throttle = pad.throttle
	else:
		i.throttle = throttle_level if _throttle_from_keys else 0.0
	return i

func curve(x: float) -> float:
	return x * (1.0 - expo) + x * x * x * expo

func throttle_latched() -> bool:
	return _latched

# Keys ramp toward their target; an analog pad value is used as is.
func _stick(axis: StringName, key: float, pad_value: float, delta: float) -> float:
	if key == 0.0 and pad_value != 0.0:
		_ramped[axis] = pad_value
	else:
		_ramped[axis] = move_toward(_ramped[axis], key, delta / key_ramp_time)
	return _ramped[axis]

func _key_held(action: StringName) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			if e.physical_keycode != KEY_NONE and Input.is_physical_key_pressed(e.physical_keycode):
				return true
			if e.keycode != KEY_NONE and Input.is_key_pressed(e.keycode):
				return true
	return false

func _drone() -> Drone:
	return get_parent() as Drone

# Latch only when this input flies a drone whose altitude hold is off.
func _wants_latch() -> bool:
	var d := _drone()
	return d != null and d.assists != null and not d.assists.is_enabled(&"altitude_hold")

func _hover_throttle() -> float:
	var d := _drone()
	return Mixer.hover_throttle(d.hover_thrust(), d.max_thrust) if d else 0.0
