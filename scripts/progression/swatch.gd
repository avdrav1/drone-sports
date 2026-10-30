class_name Swatch
extends Resource
# Story 27.3: one colour of the hangar's palette, for paint, lights and decals.
# The palette is all the hangar offers (no free colour wheel, Story 27.5); the
# swatches the default livery wears are open from the start.

@export var id: StringName
@export var name := ""
@export var color := Color.BLACK
