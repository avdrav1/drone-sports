class_name Weather
extends Resource
# Per-job weather: fog for the eye, wind for the sim. A job with no Weather
# flies in the scene's own clear golden-hour haze with no wind. Free flight
# cycles through presets (Story 4.6).

## Shown when free flight switches to it.
@export var label := ""

## Exponential fog density, replacing the scene's. Visual only.
@export var fog_density := 0.0016
## Fed to the drone's wind sim (Story 1.7). Null is still air.
@export var wind: Wind

## Puts `w` on a scene: its wind on the drone, its fog on a copy of each
## WorldEnvironment's own Environment, so the shared resource is untouched.
## Null clears: still air and the scene's own environment back.
static func apply(w: Weather, drone: Drone, scope: Node) -> void:
	if drone:
		drone.wind = w.wind if w else null
	if scope == null:
		return
	for env_node in scope.find_children("*", "WorldEnvironment", true, false):
		if not env_node.has_meta(&"clear_environment"):
			env_node.set_meta(&"clear_environment", env_node.environment)
		var clear: Environment = env_node.get_meta(&"clear_environment")
		if w == null:
			env_node.environment = clear
		else:
			var env: Environment = clear.duplicate()
			env.fog_density = w.fog_density
			env_node.environment = env
