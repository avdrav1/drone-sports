class_name Upgrade
extends Resource
# A shop item that raises or lowers one exported Drone stat per level bought
# (CLAUDE.md rule 5: stats only, never assists). Prices and effects are data.

const STATS: Array[StringName] = [&"max_thrust", &"battery_flight_time", &"drag"]

@export var id: StringName
@export var name := ""
## Exported Drone property this changes, one of STATS.
@export var stat: StringName
## Added to the stat per level; negative lowers it (drag).
@export var step := 0.0
## Price of each level in order; its size is the top level.
@export var prices: Array[int] = []
## Unit shown after the step, e.g. "N per motor".
@export var unit := ""

func max_level() -> int:
	return prices.size()

## E.g. "+0.5 N per motor".
func effect_text() -> String:
	return "%s%s %s" % ["+" if step > 0.0 else "", str(step), unit]
