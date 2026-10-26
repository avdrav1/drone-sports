extends RefCounted
# Story 2.2: objectives and graders.

class Fixed extends Objective:
	var value := 0.0
	func score() -> float:
		return value

func _obj(weight: float, value: float) -> Fixed:
	var o := Fixed.new()
	o.weight = weight
	o.value = value
	return o

func _free(objs: Array) -> void:
	for o in objs:
		o.free()

func test_weights_2_and_1_grade_to_c() -> bool:
	var objs := [_obj(2.0, 1.0), _obj(1.0, 0.0)]
	var total := Grader.total(objs)
	var letter := Grader.grade(objs)
	_free(objs)
	return absf(total - 0.6667) < 0.001 and letter == "C"

func test_thresholds_from_data() -> bool:
	var scale: GradeScale = load("res://data/jobs/grade_scale.tres")
	return scale.letter(0.9) == "A" and scale.letter(0.89) == "B" and scale.letter(0.75) == "B" \
		and scale.letter(0.6) == "C" and scale.letter(0.4) == "D" and scale.letter(0.39) == "F" \
		and scale.letter(1.0) == "A" and scale.letter(0.0) == "F"

func test_scores_are_clamped() -> bool:
	var objs := [_obj(1.0, 3.0), _obj(1.0, -2.0)]
	var total := Grader.total(objs)
	_free(objs)
	return is_equal_approx(total, 0.5)

func test_runner_finds_and_binds_objectives() -> bool:
	var runner := JobRunner.new()
	runner.job = Job.new()
	runner.auto_begin = false
	var a := _obj(1.0, 1.0)
	var b := _obj(1.0, 0.5)
	runner.add_child(a)
	runner.add_child(Node.new())
	runner.add_child(b)
	runner.begin()
	var ok := runner.objectives() == [a, b] and a.runner == runner and b.runner == runner
	runner.free()
	return ok
