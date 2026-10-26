extends Node3D
# Debug flight sandbox. Every story is played by hand here.

@onready var readout: Label = $HUD/Readout

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_readout"):
		readout.visible = not readout.visible
