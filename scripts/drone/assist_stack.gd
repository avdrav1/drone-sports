class_name AssistStack
extends Resource
# Which assists are on. Property names are the assist ids.

@export var collision_guard := true
@export var altitude_hold := true
@export var auto_level := true
@export var speed_governor := true
@export var battery_wind := true
@export var single_drone_view := true

const IDS: Array[StringName] = [&"collision_guard", &"altitude_hold", &"auto_level",
	&"speed_governor", &"battery_wind", &"single_drone_view"]

func is_on(id: StringName) -> bool:
	return id in IDS and get(id)
