class_name PilotInput
extends IntentSource
# Gamepad and keyboard sticks. Actions are defined in project.godot.

func read_intent() -> Intent:
	var i := Intent.new()
	i.throttle = Input.get_axis("throttle_down", "throttle_up")
	i.pitch = Input.get_axis("pitch_back", "pitch_forward")
	i.roll = Input.get_axis("roll_left", "roll_right")
	i.yaw = Input.get_axis("yaw_left", "yaw_right")
	return i
