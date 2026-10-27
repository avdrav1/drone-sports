class_name JammingZone
extends Node3D
# A patch of ground where GPS degrades. Signal is full at the edge and falls to
# nothing `fade` metres inside it, measured flat on the ground. HUD only: the
# drone flies the same with or without a fix. Placed in job scenes as data.

const GROUP := &"jamming_zones"

## Metres from the centre to the edge, on the ground.
@export var radius := 20.0
## Metres inside the edge where the signal reaches zero.
@export var fade := 8.0

func _enter_tree() -> void:
	add_to_group(GROUP)

## 1 outside the zone, falling to 0 at `fade` metres in from the edge.
func strength_at(p: Vector3) -> float:
	var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	var depth := radius - d
	return clampf(1.0 - depth / maxf(fade, 0.001), 0.0, 1.0)

## Every zone under scope.
static func collect(scope: Node) -> Array[JammingZone]:
	var out: Array[JammingZone] = []
	for n in scope.get_tree().get_nodes_in_group(GROUP):
		if n is JammingZone and (n == scope or scope.is_ancestor_of(n)):
			out.append(n)
	return out
