extends Node3D
# The shared golden-hour sky and sun. Gives the scene its own copy of the
# Environment with the quality tier's extras on it (Story 15.1); weather then
# layers on that copy, and the shared resource is never touched. The sun's
# shadow cascades come from data (Story 15.3).

## The sun's cascade layout; null keeps the scene's own.
@export var shadow: SunShadow

func _ready() -> void:
	var env_node: WorldEnvironment = $WorldEnvironment
	var env: Environment = env_node.environment.duplicate()
	if shadow:
		shadow.apply($Sun)
	Quality.apply(env, $Sun)
	env_node.environment = env
