class_name RateMode
extends Node
# Story 32.1: the drone's own rate loop, as on any real quad flown with
# self-levelling off. With auto-level off the pitch and roll sticks ask for a
# rotation rate, and with the brake off the yaw stick does; released, the drone
# stops rotating and holds its attitude. Always on and not an assist: nothing
# in the act table removes it, and an axis an assist already controls is left
# alone. It sits in the pipeline right after AutoLevel and only rewrites the
# Intent.

## Pitch and roll: the rate per unit of stick near center, rad/s, and the rate
## at full stick. Between them the rate grows with the stick cubed, so small
## pushes lean gently and full stick still flips as fast as the motors allow
## (Story 1.10's 0.8 s flip).
@export var center_rate := deg_to_rad(150.0)
@export var max_rate := deg_to_rad(720.0)
## Yaw rate at full stick, rad/s (the brake's).
@export var max_yaw_rate := deg_to_rad(90.0)
## Stick per rad/s of rate error.
@export var rate_gain := 1.0
## Yaw stick per rad/s of yaw rate error.
@export var yaw_gain := 3.0

func apply(intent: Intent, drone: Drone, pipeline: AssistPipeline) -> void:
	var rate := FlightControl.body_rate(drone)
	if not pipeline.is_enabled(&"auto_level"):
		# Nose-down rate is -x, roll-right rate is -z in body axes.
		intent.pitch = clampf(rate_gain * (wanted_rate(intent.pitch) + rate.x), -1.0, 1.0)
		intent.roll = clampf(rate_gain * (wanted_rate(intent.roll) + rate.z), -1.0, 1.0)
	if not pipeline.is_enabled(&"brake"):
		# Yaw right is clockwise seen from above: negative about body up.
		intent.yaw = clampf(yaw_gain * (intent.yaw * max_yaw_rate + rate.y), -1.0, 1.0)

## The pitch or roll rate a stick at `s` (-1..1) asks for, rad/s.
func wanted_rate(s: float) -> float:
	s = clampf(s, -1.0, 1.0)
	return s * center_rate + s * s * s * (max_rate - center_rate)

## The stick that asks for `rate`, rad/s: wanted_rate's inverse, clamped to a
## full stick.
func stick_for_rate(rate: float) -> float:
	var lo := -1.0
	var hi := 1.0
	for i in 24:
		var mid := (lo + hi) * 0.5
		if wanted_rate(mid) < rate:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5
