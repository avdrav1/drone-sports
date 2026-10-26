class_name BatteryWind
extends Assist
# While on, the drone ignores wind and its battery never drains.
# Switching it off is what turns the environment sim on.

func _init() -> void:
	assist_id = &"battery_wind"

func apply(intent: Intent, _drone: Drone, _delta: float) -> void:
	intent.environment_sim = false
