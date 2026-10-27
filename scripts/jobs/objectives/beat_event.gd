class_name BeatEvent
extends Objective
# Get `objective` done before the hazard timeline fires `event`, or the job
# fails with `reason`. E.g. exit the building before the roof comes down.

@export var hazard: HazardScene
@export var event: StringName
@export var objective: Objective
@export var reason := "too late"

var beaten := false

func bind(r: JobRunner) -> void:
	super(r)
	if hazard and not hazard.event_fired.is_connected(_on_event):
		hazard.event_fired.connect(_on_event)

func _physics_process(_delta: float) -> void:
	if not beaten and objective and objective.is_done() and not hazard.fired.has(event):
		beaten = true

func _on_event(e: StringName, _time: float) -> void:
	if e != event or beaten:
		return
	if objective and objective.is_done():
		beaten = true
	elif is_live():
		runner.fail(reason)

func is_done() -> bool:
	return beaten

func score() -> float:
	return 1.0 if beaten else 0.0
