extends Node3D
# Debug flight sandbox. Every story is played by hand here.
# F1 toggles the readout, F2 cycles the act presets.

@export var presets: Array[AssistStack] = []

var preset_index := 0

@onready var readout: Label = $HUD/Readout
@onready var drone: Drone = $Drone
@onready var expert_toggle: CheckBox = $HUD/Expert

func _ready() -> void:
	expert_toggle.button_pressed = GameSettings.expert_all_assists_off
	expert_toggle.toggled.connect(_on_expert_toggled)
	apply_preset()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_readout"):
		readout.visible = not readout.visible
	elif event.is_action_pressed("cycle_preset"):
		cycle_preset()

func cycle_preset() -> void:
	preset_index = (preset_index + 1) % presets.size()
	apply_preset()

func apply_preset() -> void:
	if presets.is_empty():
		return
	var stack := presets[preset_index]
	drone.assists.apply_stack(GameSettings.effective_stack(stack))
	readout.header = "preset: %s%s" % [stack.label, "  (expert: all assists off)" if GameSettings.expert_all_assists_off else ""]

func _on_expert_toggled(on: bool) -> void:
	GameSettings.expert_all_assists_off = on
	apply_preset()
