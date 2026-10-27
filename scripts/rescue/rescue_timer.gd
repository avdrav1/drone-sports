class_name RescueTimer
extends Node
# The rescue clock. Its zone is warned for the last stretch, so the strike that
# lands when time runs out always comes after a full warning; then the job fails.

@export var runner: JobRunner
@export var zone: HazardZone
## Seconds of live flying before the strike.
@export var seconds := 90.0

var expired := false

func remaining() -> float:
	return maxf(seconds - runner.live_time, 0.0) if runner else seconds

func _physics_process(_delta: float) -> void:
	if expired or runner == null or runner.state != JobRunner.State.LIVE:
		return
	if remaining() <= zone.lookahead:
		zone.threaten()
	if remaining() <= 0.0:
		expired = true
		zone.strike(&"timer")
		runner.fail("time ran out")
