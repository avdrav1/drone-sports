class_name ControlsHint
extends Label
# One line of keys at the foot of the screen while a job is in its briefing.
# Gone once the drone launches.

@export var runner: JobRunner

func _ready() -> void:
	text = ControlsHelp.hint_line()
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	visible = runner != null and runner.state == JobRunner.State.BRIEFING
