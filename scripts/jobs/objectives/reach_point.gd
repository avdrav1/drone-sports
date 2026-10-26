class_name ReachPoint
extends Objective
# Fly the drone within `radius` of `target` while the job is live.

@export var target: Node3D
@export var radius := 2.0

var reached := false

func _physics_process(_delta: float) -> void:
	if reached or not is_live() or target == null or runner.drone == null:
		return
	reached = runner.drone.global_position.distance_to(target.global_position) <= radius

func is_done() -> bool:
	return reached

func score() -> float:
	return 1.0 if reached else 0.0
