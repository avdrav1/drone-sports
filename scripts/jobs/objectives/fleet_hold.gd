class_name FleetHold
extends HoldStation
# A HoldStation any drone in the fleet can fly. Holds in a group only count
# while every one of them has its own drone on station: one drone cannot cover
# two, so three stations need three drones at once (Story 6.3). Graded per
# station on how close to the centre its drone held.

@export var command: CommandView
## The other holds that must be manned at the same time.
@export var partners: Array[FleetHold] = []

var _offset_sum := 0.0
var _samples := 0

## Fleet drones inside this station's radius, nearest first.
func occupants() -> Array[Drone]:
	var out: Array[Drone] = []
	if center == null or command == null:
		return out
	for d in command.drones:
		if d.global_position.distance_to(center.global_position) <= radius:
			out.append(d)
	out.sort_custom(func(a, b): return a.global_position.distance_to(center.global_position) < b.global_position.distance_to(center.global_position))
	return out

## Every station in the group manned by a different drone.
func inside() -> bool:
	return FleetHold.manned([self] + partners)

## True when each hold can be given its own drone from those inside it.
static func manned(holds: Array) -> bool:
	return _assign(holds, 0, [])

static func _assign(holds: Array, i: int, used: Array) -> bool:
	if i == holds.size():
		return true
	for d in holds[i].occupants():
		if not d in used and _assign(holds, i + 1, used + [d]):
			return true
	return false

func _physics_process(delta: float) -> void:
	var was := held
	super(delta)
	if held > was or (is_done() and _samples == 0):
		var near := occupants()
		if not near.is_empty():
			_offset_sum += near[0].global_position.distance_to(center.global_position)
			_samples += 1

## Done scores 1 at dead centre, down to 0.5 at the edge of the radius.
func score() -> float:
	if not is_done():
		return 0.0
	var mean := _offset_sum / _samples if _samples > 0 else 0.0
	return 1.0 - 0.5 * clampf(mean / radius, 0.0, 1.0)
