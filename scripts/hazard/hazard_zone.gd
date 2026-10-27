class_name HazardZone
extends Area3D
# Where a crew member stands during a hazard job. This story only reports what
# enters it; strikes, warnings, and consequences come in Story 7.4.

signal debris_in_zone(debris: Debris)

## Character id from data/characters/, set per job scene.
@export var character: StringName

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Debris:
		debris_in_zone.emit(body)
