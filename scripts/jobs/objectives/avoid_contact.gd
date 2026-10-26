class_name AvoidContact
extends Objective
# Starts at 1. Each collision while live costs `penalty`, down to 0.

@export var penalty := 0.25

var contacts := 0

func bind(r: JobRunner) -> void:
	super(r)
	var d := r.drone
	if d == null:
		return
	d.contact_monitor = true
	d.max_contacts_reported = maxi(d.max_contacts_reported, 4)
	if not d.body_entered.is_connected(_on_body_entered):
		d.body_entered.connect(_on_body_entered)

func _on_body_entered(_body: Node) -> void:
	if is_live():
		contacts += 1

func score() -> float:
	return maxf(1.0 - contacts * penalty, 0.0)
