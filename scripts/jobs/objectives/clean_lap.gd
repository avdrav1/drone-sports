class_name CleanLap
extends Objective
# Fraction of the race's laps flown valid and without touching anything.

@export var course: Course

var clean := 0
var _touched := false

func bind(r: JobRunner) -> void:
	super(r)
	var d := r.drone
	if d == null or course == null:
		return
	d.contact_monitor = true
	d.max_contacts_reported = maxi(d.max_contacts_reported, 4)
	if not d.body_entered.is_connected(_on_body_entered):
		d.body_entered.connect(_on_body_entered)
	if not course.lap_completed.is_connected(_on_lap):
		course.lap_completed.connect(_on_lap)

func _on_body_entered(_body: Node) -> void:
	if is_live():
		_touched = true

func _on_lap(_time: float, racer: Node3D, _lap: int, valid: bool) -> void:
	if racer != runner.drone:
		return
	if valid and not _touched:
		clean += 1
	_touched = false

func score() -> float:
	return clampf(float(clean) / course.laps(), 0.0, 1.0) if course and course.laps() > 0 else 0.0
