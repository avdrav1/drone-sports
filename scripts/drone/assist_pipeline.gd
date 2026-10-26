class_name AssistPipeline
extends Node
# Runs child Assist nodes in tree order every physics frame, before the mixer.

func assists() -> Array[Assist]:
	var out: Array[Assist] = []
	for c in get_children():
		if c is Assist:
			out.append(c)
	return out

func run(intent: Intent, drone: Drone, delta: float) -> void:
	for a in assists():
		if a.enabled:
			a.apply(intent, drone, delta)

## True if an assist with this id is present and on.
func is_enabled(id: StringName) -> bool:
	for a in assists():
		if a.assist_id == id:
			return a.enabled
	return false

func apply_stack(stack: AssistStack) -> void:
	for a in assists():
		a.enabled = stack.is_on(a.assist_id)

func summary() -> String:
	var parts := []
	for a in assists():
		parts.append("%s %s" % [a.assist_id, "ON" if a.enabled else "off"])
	return "(empty)" if parts.is_empty() else ", ".join(parts)
