class_name StatStep
extends Resource
# One step on an exported Drone stat, part of a pilot's edge (Story 19.1) or a
# hangar part (Story 27.4). Added once, like one shop level (CLAUDE.md rule 5:
# stats, never assists).

## Exported Drone property this changes: one of Upgrade.STATS for an edge, of
## Part.STATS for a part.
@export var stat: StringName
## Added to the stat; negative lowers it (drag).
@export var step := 0.0
## Unit shown after the step, e.g. "s flight time".
@export var unit := ""

## E.g. "+15 s flight time", the number never wrapping away from its unit.
func effect_text() -> String:
	return "%s%s\u00a0%s" % ["+" if step > 0.0 else "", PilotEdge.number(step), unit]
