class_name ReachRoute
extends RouteSource
# Routes through the targets of the runner's unreached ReachPoint objectives, in order.

func points() -> PackedVector3Array:
	var out := PackedVector3Array()
	if runner == null:
		return out
	for o in runner.objectives():
		if o is ReachPoint and not o.is_done() and o.target:
			out.append(o.target.global_position)
	return out
