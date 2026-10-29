class_name AssistSetting
extends Resource
# One exported property on one assist, part of a pilot's edge (Story 19.1):
# e.g. the speed governor's max_speed. It changes how the assist rewrites the
# Intent (CLAUDE.md rule 2), never whether the assist is there or on.

## Which assist, one of AssistStack.IDS.
@export var assist: StringName
## Exported property on that assist, e.g. max_speed.
@export var property: StringName
## The value it takes while the assist is on.
@export var value := 0.0
## True when `value` is in degrees and the property in radians (angles, turn rates).
@export var degrees := false

## The value as the assist reads it.
func setting() -> float:
	return deg_to_rad(value) if degrees else value
