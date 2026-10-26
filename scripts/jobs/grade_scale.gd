class_name GradeScale
extends Resource
# Score thresholds for each letter, and what each letter pays. Anything below D is F.

@export var a_min := 0.9
@export var b_min := 0.75
@export var c_min := 0.6
@export var d_min := 0.4

## Fraction of the job's pay, by letter.
@export var pay_multiplier := {"A": 1.0, "B": 0.8, "C": 0.6, "D": 0.3, "F": 0.0}
## Reputation change with the client faction, by letter.
@export var reputation_change := {"A": 10, "B": 6, "C": 3, "D": 1, "F": -5}

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
