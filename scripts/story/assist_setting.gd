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
## The setting in plain words on the pilot select card (Story 19.3). {value} is
## this pilot's, {others} the stock assist's, e.g. "Top speed {value} m/s while
## the governor is on, others {others}".
@export var words := ""

## The value as the assist reads it.
func setting() -> float:
	return deg_to_rad(value) if degrees else value

## `words` filled in, given the stock value of the property as the assist reads it.
## A number never wraps away from its unit.
func text(stock: float) -> String:
	var others := rad_to_deg(stock) if degrees else stock
	return words.replace("{value} ", "{value}\u00a0").replace("others {others}", "others\u00a0{others}").format({"value": PilotEdge.number(value), "others": PilotEdge.number(others)})
