class_name LatticeHud
extends Label
# The boss job's phase line: what to do now and the clock that matters. The
# player reads the boss as Ravana and its units as heads (Story 25.3).
# Reads the fight; never steers.

@export var fight: LatticeFight
## The label above this one (the job's state line), which this sits under when
## it runs to more lines than one, as it does in the briefing.
@export var below: Control

var _top := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_top = position.y

func _process(_delta: float) -> void:
	text = lines()
	if below:
		position.y = maxf(_top, below.position.y + below.size.y + 4.0)

func lines() -> String:
	if fight == null:
		return ""
	match fight.phase:
		# Why only a human hand can stop it: the job's own briefing (Story 30.9).
		LatticeFight.Phase.BRIEFING:
			return fight.runner.job.briefing if fight.runner and fight.runner.job else ""
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
