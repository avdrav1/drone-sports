extends Node3D
# Debug flight sandbox. Every story is played by hand here.
# F1 toggles the readout, F2 cycles the act presets, C cycles camera views,
# R (or Start) puts the drone back where it started, J flies the sample job, K the test race, L the tower inspection,
# H the demolition run, U the search and rescue.

@export var presets: Array[AssistStack] = []
@export_file("*.tscn") var sample_job := "res://scenes/jobs/sample_delivery.tscn"
@export_file("*.tscn") var race_job := "res://scenes/jobs/test_race.tscn"
@export_file("*.tscn") var inspection_job := "res://scenes/jobs/inspection.tscn"
@export_file("*.tscn") var demolition_job := "res://scenes/jobs/demolition.tscn"
@export_file("*.tscn") var rescue_job := "res://scenes/jobs/rescue.tscn"

var preset_index := 0
var _spawn: Transform3D

@onready var readout: Label = $HUD/Readout
@onready var drone: Drone = $Drone
@onready var expert_toggle: CheckBox = $HUD/Expert
@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: FlightHud = $HUD/Flight

func _ready() -> void:
	camera_rig.camera.make_current()
	_spawn = drone.global_transform
	expert_toggle.button_pressed = GameSettings.expert_all_assists_off
	expert_toggle.toggled.connect(_on_expert_toggled)
	# Start on the preset the pilot's career has earned.
	preset_index = clampi(Career.act() - 1, 0, maxi(presets.size() - 1, 0))
	apply_preset()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_readout"):
		readout.visible = not readout.visible
	elif event.is_action_pressed("cycle_preset"):
		cycle_preset()
	elif event.is_action_pressed("reset_drone"):
		reset_drone()
	elif event.is_action_pressed("start_sample_job"):
		get_tree().change_scene_to_file(sample_job)
	elif event.is_action_pressed("start_race_job"):
		get_tree().change_scene_to_file(race_job)
	elif event.is_action_pressed("start_inspection_job"):
		get_tree().change_scene_to_file(inspection_job)
	elif event.is_action_pressed("start_demolition_job"):
		get_tree().change_scene_to_file(demolition_job)
	elif event.is_action_pressed("start_rescue_job"):
		get_tree().change_scene_to_file(rescue_job)

func reset_drone() -> void:
	drone.reset(_spawn)

func cycle_preset() -> void:
	preset_index = (preset_index + 1) % presets.size()
	apply_preset()

func apply_preset() -> void:
	if presets.is_empty():
		return
	var stack := presets[preset_index]
	drone.assists.apply_stack(GameSettings.effective_stack(stack))
	readout.header = "preset: %s%s" % [stack.label, "  (expert: all assists off)" if GameSettings.expert_all_assists_off else ""]
	hud.subtitle = stack.label + ("  ·  expert" if GameSettings.expert_all_assists_off else "") \
		+ "  ·  %s start a job" % ControlsHelp.job_keys()

func _on_expert_toggled(on: bool) -> void:
	GameSettings.expert_all_assists_off = on
	apply_preset()
