class_name PowerDown
extends Objective
# The Lattice is down: the power-down sequence has run to the end. Ends the job.

@export var fight: LatticeFight

func is_done() -> bool:
	return fight != null and fight.phase == LatticeFight.Phase.DONE

func score() -> float:
	return 1.0 if is_done() else 0.0
