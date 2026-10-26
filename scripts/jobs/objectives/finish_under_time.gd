class_name FinishUnderTime
extends Objective
# Full marks if the job completes within `target_time` seconds of live flying.

@export var target_time := 60.0

func score() -> float:
	if runner == null or runner.state == JobRunner.State.FAILED:
		return 0.0
	return 1.0 if runner.live_time <= target_time else 0.0
