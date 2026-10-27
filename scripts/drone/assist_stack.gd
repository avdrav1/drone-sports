class_name AssistStack
extends Resource
# Which assists are on. Property names are the assist ids.

## Shown in readouts and HUDs, e.g. "Act 2".
@export var label := ""

@export var collision_guard := true
@export var brake := true
@export var altitude_hold := true
@export var auto_level := true
@export var speed_governor := true
@export var battery_wind := true
@export var single_drone_view := true

const IDS: Array[StringName] = [&"collision_guard", &"brake", &"altitude_hold", &"auto_level",
	&"speed_governor", &"battery_wind", &"single_drone_view"]

func is_on(id: StringName) -> bool:
	return id in IDS and get(id)

## All assists off, keeping the label.
func all_off() -> AssistStack:
	var s := AssistStack.new()
	s.label = label
	for id in IDS:
		s.set(id, false)
	return s

## On only where both stacks are on, keeping this label. A job's assists capped
## by what the pilot's career allows.
func intersect(other: AssistStack) -> AssistStack:
	var s := AssistStack.new()
	s.label = label
	for id in IDS:
		s.set(id, is_on(id) and other.is_on(id))
	return s

## Ids on here and off in `other`: what moving to `other` takes away.
func removed_by(other: AssistStack) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in IDS:
		if is_on(id) and not other.is_on(id):
			out.append(id)
	return out
