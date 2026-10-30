class_name ControlsHint
extends Label
# One line of keys at the foot of the screen while a job is in its briefing,
# named for the device last touched. Gone once the drone launches.

@export var runner: JobRunner

func _ready() -> void:
	text = ControlsHelp.hint_line()
	add_theme_font_override("font", ControlsHelp.font())
	mouse_filter = MOUSE_FILTER_IGNORE
	InputPrompt.device_changed.connect(_on_device_changed)

func _process(_delta: float) -> void:
	visible = runner != null and runner.state == JobRunner.State.BRIEFING

func _on_device_changed(_pad: bool) -> void:
	text = ControlsHelp.hint_line()
