class_name Horizon
extends Assist
# Story 32.2: horizon mode, the trainer setting on real quads. With auto-level
# off the sticks still ask RateMode for a rotation rate, so the drone banks and
# flips, but near center this adds a turn back toward level: let go and it
# drifts upright instead of holding its lean. The pull fades as the stick moves
# out and is gone from `fade` on, so full stick is pure rate. Sits right before
# RateMode and only rewrites the pitch and roll sticks.

## Level-seeking rate per radian of tilt, 1/s: 30° of tilt turns back at 90°/s.
@export var level_gain := 3.0
## Stick deflection at which the pull toward level has faded to nothing.
@export var fade := 0.75

func _init() -> void:
	assist_id = &"horizon"

func apply(intent: Intent, drone: Drone, _delta: float) -> void:
	var pipeline := get_parent() as AssistPipeline
	var rm := pipeline.get_node_or_null("RateMode") as RateMode if pipeline else null
	if rm == null or pipeline.is_enabled(&"auto_level"):
		return
	var strength := clampf(1.0 - maxf(absf(intent.pitch), absf(intent.roll)) / fade, 0.0, 1.0)
	if strength == 0.0:
		return
	var back := level_rate(drone) * strength
	intent.pitch = rm.stick_for_rate(rm.wanted_rate(intent.pitch) + back.x)
	intent.roll = rm.stick_for_rate(rm.wanted_rate(intent.roll) + back.y)

## Nose-down and roll-right rates, rad/s, that turn the drone toward level by
## the shortest way, in proportion to its tilt. Zero when upside down.
func level_rate(drone: Drone) -> Vector2:
	var up := drone.global_transform.basis.inverse() * Vector3.UP
	# Turning body up toward world up is a body rate of (up.z, 0, -up.x);
	# nose-down rate is -x and roll-right rate is -z.
	var v := Vector2(-up.z, up.x)
	if v.length() < 0.05:
		return Vector2.ZERO
	return v.normalized() * FlightControl.tilt(drone) * level_gain
