class_name LatticeHud
extends Label
# The boss job's phase line: what to do now and the clock that matters. The
# player reads the boss as Ravana and its units as heads (Story 25.3).
# Reads the fight; never steers.

@export var fight: LatticeFight

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	text = lines()

func lines() -> String:
	if fight == null:
		return ""
	match fight.phase:
		LatticeFight.Phase.RECLAIM:
			var gap := fight.gap()
			var done := gap.filter(func(u): return u in fight.reclaimed).size()
			return "RECLAIM  ·  gap %d/%d  ·  fleet %d  ·  %s tags a head" % [done, gap.size(), fight.command.drones.size(),
				InputPrompt.text(&"tag_unit")]
		LatticeFight.Phase.TRENCH:
			return "THE TRENCH  ·  closes in %d s  ·  reach the shutter" % ceili(maxf(fight.boss().trench_time - fight.trench_clock, 0.0))
		LatticeFight.Phase.OVERRIDE:
			return "OVERRIDE  ·  hold at the port"
		LatticeFight.Phase.POWER_DOWN:
			return "POWERING DOWN"
	return ""
