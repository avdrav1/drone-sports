class_name Part
extends Resource
# Story 27.1: a part fitted in a hangar slot, one per kind.
# Story 27.4: what it does: steps on the drone's exported stats, added by
# Garage.apply with the upgrades and the pilot's edge (rule 5: stats only, never
# assists, never physics code). A part trades: every one but the defaults makes
# at least one stat better and at least one worse. A frame also sets the hull's
# shape, and its arm length step moves the arms; DroneLook draws both.

const KINDS: Array[StringName] = [&"frame", &"props", &"battery"]
## The exported drone stats a part may step.
const STATS: Array[StringName] = [&"mass", &"drag", &"angular_drag", &"max_thrust", &"arm_length",
	&"yaw_torque_per_thrust", &"battery_flight_time"]
## Stat -> 1 where more is better for the pilot, -1 where less is: lighter
## accelerates harder, less drag is faster, less angular drag turns quicker,
## longer arms give more roll and pitch authority, more yaw torque yaws quicker.
const BETTER := {
	&"mass": -1, &"drag": -1, &"angular_drag": -1, &"max_thrust": 1, &"arm_length": 1,
	&"yaw_torque_per_thrust": 1, &"battery_flight_time": 1,
}

@export var id: StringName
## One of KINDS.
@export var kind: StringName
@export var name := ""
## One line for the hangar, e.g. "Fast and twitchy, short on battery".
@export var blurb := ""
## Steps on STATS; empty for a default part, which changes nothing.
@export var stats: Array[StatStep] = []
## Frames only: the hull's size against stock (x wide, y tall, z long).
@export var hull := Vector3.ONE

## Adds each step to the drone's stat. Once per drone; Garage.apply guards that.
func apply_stats(drone: Drone) -> void:
	for s in stats:
		drone.set(s.stat, drone.get(s.stat) + s.step)

## Stats the part makes better, and worse, for the pilot.
func better() -> Array[StringName]:
	return _sided(1)

func worse() -> Array[StringName]:
	return _sided(-1)

func _sided(side: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for s in stats:
		if s and s.stat in BETTER and int(signf(s.step)) * BETTER[s.stat] == side:
			out.append(s.stat)
	return out

## Problems with this part; empty when it is valid. A trade unless `is_default`.
func validate(is_default := false) -> Array[String]:
	var out: Array[String] = []
	if id == &"" or name.is_empty() or not kind in KINDS:
		out.append("%s: needs an id, a name and one of %s" % [id, KINDS])
	for s in stats:
		if s == null or not s.stat in STATS or s.step == 0.0:
			out.append("%s: each stat step must change one of %s" % [id, STATS])
	if is_default and (not stats.is_empty() or hull != Vector3.ONE):
		out.append("%s: a default part changes nothing" % id)
	if not is_default and (better().is_empty() or worse().is_empty()):
		out.append("%s: must make one stat better and one worse" % id)
	if kind != &"frame" and hull != Vector3.ONE:
		out.append("%s: only a frame shapes the hull" % id)
	return out
