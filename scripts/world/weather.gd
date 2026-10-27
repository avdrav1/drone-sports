class_name Weather
extends Resource
# Per-job weather: fog for the eye, wind for the sim. A job with no Weather
# flies in the scene's own clear golden-hour haze with no wind.

## Exponential fog density, replacing the scene's. Visual only.
@export var fog_density := 0.0016
## Fed to the drone's wind sim (Story 1.7). Null is still air.
@export var wind: Wind
