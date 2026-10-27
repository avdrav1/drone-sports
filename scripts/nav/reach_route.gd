class_name ReachRoute
extends RouteSource
# Routes through the runner's unfinished ReachPoint targets and HoldStation centres, in order.

func points() -> PackedVector3Array:
	var out := PackedVector3Array()
	if runner == null:
		return out
	for o in runner.objectives():
		if o is ReachPoint and not o.is_done() and o.target:
			out.append(o.target.global_position)
		elif o is HoldStation and not o.is_done() and o.center:
			out.append(o.center.global_position)
	return out
