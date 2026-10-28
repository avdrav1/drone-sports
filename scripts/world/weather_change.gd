class_name WeatherChange
extends Resource
# One step in a job's weather sequence (Story 13.6): at a time into live flying,
# the scene starts blending to a new weather.

## Seconds of live flying before this change starts.
@export var at := 0.0
## The weather to blend to; null is clear.
@export var weather: Weather
## Seconds the blend takes; 0 switches at once.
@export var blend_time := 10.0
