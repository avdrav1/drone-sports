class_name OverrideHold
extends HoldStation
# The Lattice's phase 3: hold station at the override port. Only counts once the
# fight reaches the override; the fight sets the port, radius, and time from
# the boss data. Graded like an inspection hold.

@export var fight: LatticeFight

func active() -> bool:
	return super() and fight != null and fight.phase == LatticeFight.Phase.OVERRIDE
