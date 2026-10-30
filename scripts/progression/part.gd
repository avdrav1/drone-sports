class_name Part
extends Resource
# Story 27.1: a part fitted in a hangar slot, one per kind. What it does to the
# drone's exported stats comes with Story 27.4 (rule 5: stats only, never assists).

const KINDS: Array[StringName] = [&"frame", &"props", &"battery"]

@export var id: StringName
## One of KINDS.
@export var kind: StringName
@export var name := ""
