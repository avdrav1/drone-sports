class_name Assist
extends Node
# One step in the assist pipeline. Reads drone state, rewrites the Intent.
# Never applies forces or touches the drone's physics: that stays in Drone.

## Matches a property name on AssistStack.
@export var assist_id: StringName
@export var enabled := true

## Override. Called every physics frame while enabled, in pipeline order.
func apply(_intent: Intent, _drone: Drone, _delta: float) -> void:
	pass

## Override to forget held state when the drone resets.
func reset() -> void:
	pass
