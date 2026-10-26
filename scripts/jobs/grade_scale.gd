class_name GradeScale
extends Resource
# Score thresholds for each letter. Anything below D is F.

@export var a_min := 0.9
@export var b_min := 0.75
@export var c_min := 0.6
@export var d_min := 0.4

func letter(score: float) -> String:
	if score >= a_min:
		return "A"
	if score >= b_min:
		return "B"
	if score >= c_min:
		return "C"
	if score >= d_min:
		return "D"
	return "F"
