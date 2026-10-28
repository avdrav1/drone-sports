class_name FleetHud
extends Label
# A fleet job's station board: each hold, how far along it is, and which drone
# is on it. Reads the objectives; never steers.

@export var holds: Array[FleetHold] = []

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	text = lines()

func lines() -> String:
	var out: Array[String] = []
	for h in holds:
		var near := h.occupants()
		var who: String = near[0].name if not near.is_empty() else "unmanned"
		out.append("%s  %3d%%  %s" % [h.label if h.label else String(h.name), roundi(h.progress() * 100.0), who])
	if not holds.is_empty() and not holds[0].is_done():
		out.append("All stations must be held at once." if not FleetHold.manned(holds) else "Holding")
	return "\n".join(out)
