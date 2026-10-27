class_name FinishPosition
extends Objective
# 1 for first place, 0 for last; 0 if the player never finishes.
# Done when the player finishes, so a race job ends there.

@export var course: Course

func _init() -> void:
	ends_job = true

func place() -> int:
	return course.finish_order.find(runner.drone) + 1 if runner and course else 0

func is_done() -> bool:
	return place() > 0

func score() -> float:
	var p := place()
	if p == 0:
		return 0.0
	var field := course.racers().size()
	return 1.0 if field <= 1 else 1.0 - float(p - 1) / (field - 1)
