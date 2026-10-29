class_name StatStep
extends Resource
# One step on an exported Drone stat, part of a pilot's edge (Story 19.1).
# Added once, like one shop level (CLAUDE.md rule 5: stats, never assists).

## Exported Drone property this changes, one of Upgrade.STATS.
@export var stat: StringName
## Added to the stat; negative lowers it (drag).
@export var step := 0.0
## Unit shown after the step, e.g. "s flight time".
@export var unit := ""

## E.g. "+15 s flight time".
func effect_text() -> String:
	return "%s%s %s" % ["+" if step > 0.0 else "", str(step), unit]
