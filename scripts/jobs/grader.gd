class_name Grader
extends RefCounted
# Combines objective scores into one weighted score and a letter.

const DEFAULT_SCALE := "res://data/jobs/grade_scale.tres"

## Weighted mean of clamped scores. No objectives (or no weight) scores 1.
static func total(objectives: Array) -> float:
	var weight := 0.0
	var sum := 0.0
	for o in objectives:
		weight += o.weight
		sum += o.weight * clampf(o.score(), 0.0, 1.0)
	return sum / weight if weight > 0.0 else 1.0

static func grade(objectives: Array, scale: GradeScale = null) -> String:
	if scale == null:
		scale = load(DEFAULT_SCALE)
	return scale.letter(total(objectives))
