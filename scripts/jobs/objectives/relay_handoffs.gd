class_name RelayHandoffs
extends Objective
# Clean handoffs: full marks for a mean gap at or under `sharp` seconds, none at
# `slow` or over.

@export var relay: Relay
@export var sharp := 1.0
@export var slow := 6.0

func mean() -> float:
	if relay == null or relay.handoffs.is_empty():
		return INF
	var sum := 0.0
	for h in relay.handoffs:
		sum += h
	return sum / relay.handoffs.size()

func score() -> float:
	if relay == null or not relay.done:
		return 0.0
	return clampf(inverse_lerp(slow, sharp, mean()), 0.0, 1.0)
