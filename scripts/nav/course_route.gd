class_name CourseRoute
extends RouteSource
# A racer's route: the gates left this lap, in order, ending at the start/finish
# (an open course's last gate). Before the start it is the start gate and then
# the whole first lap.

@export var course: Course

func points() -> PackedVector3Array:
	var out := PackedVector3Array()
	var p = course.progress(drone) if course and drone else null
	if p == null or p.finished:
		return out
	var n := course.gates.size()
	if not p.started:
		out.append(course.gates[0].global_position)
	var i: int = p.next if p.started else 1 % n
	while true:
		out.append(course.gates[i].global_position)
		if i == course.finish_gate():
			break
		i = (i + 1) % n
	return out
