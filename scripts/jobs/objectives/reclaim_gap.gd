class_name ReclaimGap
extends Objective
# The Lattice's phase 1: the trench entrance opened. Each fleet drone lost on
# the way costs `penalty`.

@export var fight: LatticeFight
@export var penalty := 0.2

func is_done() -> bool:
	return fight != null and fight.lattice.entrance_open

func score() -> float:
	return maxf(1.0 - fight.lost * penalty, 0.0) if is_done() else 0.0
