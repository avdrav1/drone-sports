class_name HoldStation
extends Objective
# Stay within `radius` of `center` for `hold_time` seconds of live flying.
# Leaving pauses the timer; staying out longer than `grace` resets it.
# With `after` set, the hold only counts once that one is done, so holds run in order.
# Generic on purpose: the fleet inspection (6.3) and the boss override (8.5) reuse it.

@export var center: Node3D
@export var radius := 2.5
@export var hold_time := 3.0
## Seconds outside before the held time resets.
@export var grace := 0.75
@export var after: HoldStation

## Seconds held so far.
var held := 0.0
var _outside := 0.0
var _done := false

## Live, not done, and the previous hold (if any) is done.
func active() -> bool:
	return is_live() and not _done and (after == null or after.is_done())

func inside() -> bool:
	return center != null and runner != null and runner.drone != null \
		and runner.drone.global_position.distance_to(center.global_position) <= radius

## 0..1 of the hold.
func progress() -> float:
	return 1.0 if _done else clampf(held / hold_time, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	if not active():
		return
	if inside():
		_outside = 0.0
		held += delta
		# A tick's worth of float error must not cost a whole extra frame.
		if held >= hold_time - 1e-4:
			_done = true
	elif held > 0.0:
		_outside += delta
		if _outside > grace:
			held = 0.0
			_outside = 0.0

func is_done() -> bool:
	return _done

func score() -> float:
	return 1.0 if _done else 0.0
