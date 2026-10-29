class_name FlightStyle
extends Resource
# How one crew member flies under autopilot (Story 18.11): bold, steady, or
# clumsy. The Autopilot reads it and changes only the Intent it writes (rules 1
# and 2); the drone, its mass, and its assists stay the same for everyone.

## Short name, e.g. bold.
@export var id: StringName
## Multiplies the autopilot's cruise speed: how hard they push ahead.
@export_range(0.5, 1.5) var push := 1.0
## Multiplies the speed carried through waypoints on the way (relay laps).
@export_range(0.5, 1.5) var corner_speed := 1.0
## Metres added to the pass radius: turning for the next point early cuts the corner.
@export_range(0.0, 2.0) var cut := 0.0
## Keeps this far from other fleet drones on the way, m; 0 flies anywhere.
@export_range(0.0, 6.0) var spacing := 0.0
## Sideways drift off the line, m, at its widest. Calms down near a point.
@export_range(0.0, 2.0) var wobble := 0.0
## Seconds they keep the old sticks after a waypoint, before turning for the next.
@export_range(0.0, 0.6) var delay := 0.0
## They radio the fleet advice (event "advice") on fleet events.
@export var advice := false
