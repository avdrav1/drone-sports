class_name SoundDialog
extends AcceptDialog
# Sound settings from the job board: a slider per bus and a mute box. Changes
# apply at once and are saved with the settings.

const LABELS := {&"Master": "All sound", &"Flight": "Drones", &"World": "World", &"Weather": "Weather",
	&"UI": "Interface", &"Voice": "Crew", &"Music": "Music"}

## Bus -> its slider.
var sliders := {}
var mute: CheckBox

func _ready() -> void:
	title = "Sound"
	ok_button_text = "Done"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	mute = CheckBox.new()
	mute.name = "Mute"
	mute.text = _mute_text()
	InputPrompt.device_changed.connect(_on_device_changed)
	mute.toggled.connect(func(on): Sfx.set_muted(on))
	box.add_child(mute)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	box.add_child(grid)
	for bus in Sfx.BUSES:
		var l := Label.new()
		l.text = LABELS.get(bus, String(bus))
		grid.add_child(l)
		var s := HSlider.new()
		s.name = String(bus)
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.custom_minimum_size.x = 220
		s.value_changed.connect(func(v): Sfx.set_volume(bus, v))
		grid.add_child(s)
		sliders[bus] = s

func open() -> void:
	mute.set_pressed_no_signal(GameSettings.muted)
	for bus in sliders:
		sliders[bus].set_value_no_signal(GameSettings.volumes.get(String(bus), 1.0))
	popup_centered()
	# Focus starts at the top, so the d-pad walks down the sliders to Done (Story 23.3).
	mute.grab_focus()

## "Mute (N)"; just "Mute" on a pad, which has no mute button (OPTIONS has the box).
func _mute_text() -> String:
	var key := InputPrompt.text(&"toggle_mute")
	return "Mute (%s)" % key if key != "" else "Mute"

func _on_device_changed(_pad: bool) -> void:
	mute.text = _mute_text()
