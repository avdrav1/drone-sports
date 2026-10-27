class_name MapMarker
extends Node3D
# Puts a point on the radar and the map. Jobs place these on gates, drop
# points, and hazards, so the map itself holds no job-specific code.

const GROUP := &"map_markers"

## What it is: gate, drop, hazard, drone, landmark.
@export var kind: StringName = &"landmark"
@export var label := ""
## Shape drawn on the radar and map: diamond, circle, triangle, square.
@export var icon: StringName = &"diamond"
## False keeps it off the map, e.g. a rescue target found by beacon only.
@export var on_map := true

## Drawn lit: the next target, e.g. the next gate.
var highlighted := false

func _enter_tree() -> void:
	add_to_group(GROUP)

## Every visible marker under `scope` (inclusive), in tree order.
static func collect(scope: Node) -> Array[MapMarker]:
	var out: Array[MapMarker] = []
	for n in scope.get_tree().get_nodes_in_group(GROUP):
		if n is MapMarker and n.on_map and (n == scope or scope.is_ancestor_of(n)):
			out.append(n)
	return out
