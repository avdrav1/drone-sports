class_name Race
extends Node
# Wires a Course to a JobRunner: registers the player and opponents as racers,
# holds opponents still until Live, and starts the course clock on Live.

@export var runner: JobRunner
@export var course: Course
@export var opponents: Array[Drone] = []

func _ready() -> void:
	if runner.drone:
		course.add_racer(runner.drone)
	for d in opponents:
		course.add_racer(d)
		d.freeze = true
	runner.state_changed.connect(_on_state)

func _on_state(state: JobRunner.State, _previous: JobRunner.State) -> void:
	if state == JobRunner.State.BRIEFING:
		for d in opponents:
			if runner.job.required_assists and d.assists:
				d.assists.apply_stack(runner.job.required_assists)
	elif state == JobRunner.State.LIVE:
		for d in opponents:
			d.freeze = false
		course.start()
