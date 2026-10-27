class_name BestSplit
extends Objective
# The player's best lap against the field's best. 1 at or under it, falling
# to 0 at `slack` slower (0.2 is 20 percent). 0 without a valid lap.

@export var course: Course
@export var slack := 0.2

func field_best() -> float:
	var best := INF
	for r in course.racers():
		best = minf(best, course.progress(r).best_lap)
	return best

func score() -> float:
	if runner == null or course == null:
		return 0.0
	var mine: float = course.progress(runner.drone).best_lap
	if mine == INF:
		return 0.0
	var behind := (mine - field_best()) / field_best()
	return clampf(1.0 - behind / slack, 0.0, 1.0)
