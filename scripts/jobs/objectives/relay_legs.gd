class_name RelayLegs
extends Objective
# Every leg of a Relay flown. Each invalid lap on the way costs `penalty`.

@export var relay: Relay
@export var penalty := 0.25

func is_done() -> bool:
	return relay != null and relay.done

func score() -> float:
	if not is_done():
		return 0.0
	return maxf(1.0 - relay.invalid * penalty, 0.0)
