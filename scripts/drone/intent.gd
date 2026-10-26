class_name Intent
extends Resource
# What the pilot (or an AI, or an assist) wants this physics frame.
# Assists rewrite it before the mixer turns it into motor thrusts.
# Sticks are -1..1 with 0 centered.

## Collective. -1 is motors off, 1 is full thrust, 0 is centered (half thrust).
@export var throttle := 0.0
## Positive pitches the nose down (flies forward).
@export var pitch := 0.0
## Positive rolls right.
@export var roll := 0.0
## Positive yaws right (clockwise seen from above).
@export var yaw := 0.0

func copy() -> Intent:
	var c := Intent.new()
	c.throttle = throttle
	c.pitch = pitch
	c.roll = roll
	c.yaw = yaw
	return c
