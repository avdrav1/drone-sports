class_name PilotEdge
extends Resource
# A pilot avatar's edge (Story 19.1): steps on the drone's exported stats and
# settings on the assists in its pipeline. Same flight model for everyone
# (CLAUDE.md rule 1); it never adds or removes an assist (rule 5).

## Shown on the pilot select card, e.g. "Hard launch".
@export var name := ""
@export var stats: Array[StatStep] = []
@export var assists: Array[AssistSetting] = []

## Add each stat step to the drone. Once per drone; Garage.apply guards that.
func apply_stats(drone: Drone) -> void:
	for s in stats:
		drone.set(s.stat, drone.get(s.stat) + s.step)

## Give each assist that is on its setting. One that is off keeps (or gets back)
## its own value, so an assist the act has removed is off and unchanged. Safe to
## call again after assists switch on or off.
func tune(pipeline: AssistPipeline) -> void:
	for s in assists:
		for a in pipeline.assists():
			if a.assist_id != s.assist:
				continue
			var key := StringName("edge_base_" + String(s.property))
			if not a.has_meta(key):
				a.set_meta(key, a.get(s.property))
			a.set(s.property, s.setting() if a.enabled else a.get_meta(key))

## Problems with this edge; empty when it is valid.
func validate() -> Array[String]:
	var out: Array[String] = []
	if name.is_empty():
		out.append("edge needs a name")
	for s in stats:
		if s == null or not s.stat in Upgrade.STATS or s.step == 0.0:
			out.append("each stat step must change one of %s" % [Upgrade.STATS])
	for s in assists:
		if s == null or not s.assist in AssistStack.IDS or s.property == &"":
			out.append("each assist setting needs an assist id and a property")
	return out
