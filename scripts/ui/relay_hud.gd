class_name RelayHud
extends Label
# The relay board: whose leg it is, each handoff's time, and the last invalid
# lap. Reads the Relay; never steers.

@export var relay: Relay

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	text = lines()

func lines() -> String:
	if relay == null:
		return ""
	var out: Array[String] = []
	var n := relay.drones.size()
	if relay.done:
		out.append("Relay done: %d legs" % n)
	else:
		out.append("Leg %d/%d  ·  %s to fly" % [relay.leg + 1, n, relay.current().name])
	for i in relay.handoffs.size():
		out.append("Handoff %d  %.2f s" % [i + 1, relay.handoffs[i]])
	if relay.last_invalid != "":
		out.append(relay.last_invalid)
	return "\n".join(out)
