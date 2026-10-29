class_name PilotEdge
extends Resource
# A pilot avatar's edge (Story 19.1): steps on the drone's exported stats and
# settings on the assists in its pipeline. Same flight model for everyone
# (CLAUDE.md rule 1); it never adds or removes an assist (rule 5).

## A short name for it, e.g. "Hard launch".
@export var name := ""
## What they are best at, finishing "Best at ...", e.g. "straight-line speed".
@export var best_at := ""
@export var stats: Array[StatStep] = []
@export var assists: Array[AssistSetting] = []

## The pilot select card's bars (Story 19.3), each fed by the drone stats and
## assist settings ("assist.property") that make a pilot better at it.
const BARS := {
	&"speed": [&"speed_governor.max_speed", &"brake.max_speed", &"drag"],
	&"cornering": [&"auto_level.max_angle", &"brake.max_yaw_rate"],
	&"climb": [&"altitude_hold.climb_rate", &"altitude_hold.height_gain", &"max_thrust"],
	&"endurance": [&"battery_flight_time"],
}
## Gain over stock, summed over a bar's inputs, that fills it.
const BAR_FULL := 0.75
## A bar's fill with nothing better than stock.
const BAR_STOCK := 0.2
## Stats where less is better.
const LOWER_IS_BETTER: Array[StringName] = [&"drag"]
const DRONE := "res://scenes/drone/drone.tscn"

static var _stock := {}

## Stock values from the drone scene: its stats by name and every assist's
## numbers as "assist.property".
static func stock() -> Dictionary:
	if _stock.is_empty():
		var d: Drone = load(DRONE).instantiate()
		for stat in Upgrade.STATS:
			_stock[stat] = d.get(stat)
		for a in d.get_node("Assists").get_children():
			if a is Assist:
				for p in a.get_property_list():
					if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.type == TYPE_FLOAT:
						_stock[StringName("%s.%s" % [a.assist_id, p.name])] = a.get(p.name)
		d.free()
	return _stock

## E.g. 15 for 15.0, 0.25 for 0.25.
static func number(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else str(snappedf(x, 0.01))

## The edge in plain words: one line per assist setting, then the stat steps.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	for s in assists:
		out.append(s.text(stock().get(StringName("%s.%s" % [s.assist, s.property]), 0.0)))
	var steps := PackedStringArray()
	for s in stats:
		steps.append(s.effect_text())
	if not steps.is_empty():
		out.append(", ".join(steps))
	return out

## Bar id -> fill in [0, 1]: BAR_STOCK at stock, full at BAR_FULL better.
## Each input counts its fraction better than stock.
func bars() -> Dictionary:
	var gain := {}
	for s in stats:
		var base: float = stock()[s.stat]
		gain[s.stat] = base / (base + s.step) - 1.0 if s.stat in LOWER_IS_BETTER else s.step / base
	for s in assists:
		var key := StringName("%s.%s" % [s.assist, s.property])
		gain[key] = s.setting() / stock()[key] - 1.0
	var out := {}
	for bar in BARS:
		var sum := 0.0
		for key in BARS[bar]:
			sum += gain.get(key, 0.0)
		out[bar] = BAR_STOCK + (1.0 - BAR_STOCK) * clampf(sum / BAR_FULL, 0.0, 1.0)
	return out

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
	if name.is_empty() or best_at.is_empty():
		out.append("edge needs a name and what they are best at")
	for s in stats:
		if s == null or not s.stat in Upgrade.STATS or s.step == 0.0:
			out.append("each stat step must change one of %s" % [Upgrade.STATS])
	for s in assists:
		if s == null or not s.assist in AssistStack.IDS or s.property == &"" or not "{value}" in s.words:
			out.append("each assist setting needs an assist id, a property, and words with {value}")
	return out
