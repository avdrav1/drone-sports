class_name Objective
extends Node
# One graded thing a job asks for. Jobs add objectives as children of their JobRunner.

## Shown on the results screen.
@export var label := ""
@export var weight := 1.0

## Set by the runner on Briefing.
var runner: JobRunner

func bind(r: JobRunner) -> void:
	runner = r

## Override. 0 is a total miss, 1 is perfect.
func score() -> float:
	return 0.0
