class_name ControlsHint
extends Label
# One line of keys at the foot of the screen while a job is in its briefing,
# named for the device last touched. Gone once the drone launches, and while the
# controls panel is up: it says the same.

@export var runner: JobRunner

const SEPARATOR := "  ·  "

func _ready() -> void:
	add_theme_font_override("font", ControlsHelp.font())
	mouse_filter = MOUSE_FILTER_IGNORE
	_set_line()
	resized.connect(_set_line)
	InputPrompt.device_changed.connect(_on_device_changed)

func _process(_delta: float) -> void:
	var help := get_parent().get_node_or_null("Help") as ControlsHelp
	visible = runner != null and runner.state == JobRunner.State.BRIEFING and not (help and help.visible)

func _on_device_changed(_pad: bool) -> void:
	_set_line()

func _set_line() -> void:
	text = wrapped(ControlsHelp.hint_line(), size.x - 4.0, get_theme_font("font"), get_theme_font_size("font_size"))

## `line` broken only between its items, never between a key and its action,
## to fit `width` (Story 26.4: the hint sits beside the radio, narrow at 960).
static func wrapped(line: String, width: float, font: Font, font_size: int) -> String:
	if width <= 0.0:
		return line
	var lines: Array[String] = []
	var at := ""
	for item in line.split(SEPARATOR):
		var longer := item if at == "" else at + SEPARATOR + item
		if at != "" and font.get_string_size(longer, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			lines.append(at)
			at = item
		else:
			at = longer
	lines.append(at)
	return "\n".join(lines)
