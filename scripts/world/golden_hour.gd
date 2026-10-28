extends Node3D
# The shared golden-hour sky and sun. Gives the scene its own copy of the
# Environment with the quality tier's extras on it (Story 15.1); weather then
# layers on that copy, and the shared resource is never touched.

func _ready() -> void:
	var env_node: WorldEnvironment = $WorldEnvironment
	var env: Environment = env_node.environment.duplicate()
	Quality.apply(env, $Sun)
	env_node.environment = env
