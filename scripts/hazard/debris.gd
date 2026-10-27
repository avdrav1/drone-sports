class_name Debris
extends RigidBody3D
# A loose piece of a hazard: held frozen until its event, then a free body.
# Pre-authored, never generated at runtime. HazardZones notice it landing.

## Event that lets it fall. Empty means it is loose from the start.
@export var release_on: StringName

func _ready() -> void:
	if release_on:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true

func release() -> void:
	freeze = false
