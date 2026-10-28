class_name WeatherState
extends Node
# The weather in effect in a scene, so rain, snow, lightning, and sound read one
# place. `Weather.apply` sets it, adding one to the scene if it has none (Story 13.1).
# It carries the scene's Rain (Story 13.2) and Snow (Story 13.3).

signal changed(weather: Weather)

## The weather in effect; null is clear.
var weather: Weather:
	set(value):
		weather = value
		changed.emit(value)

func _ready() -> void:
	if get_node_or_null(^"Rain") == null:
		var rain := Rain.new()
		rain.name = "Rain"
		add_child(rain)
	if get_node_or_null(^"Snow") == null:
		var snow := Snow.new()
		snow.name = "Snow"
		add_child(snow)

## The scope's WeatherState: an existing one below it, or a new child.
static func of(scope: Node) -> WeatherState:
	for n in scope.find_children("*", "Node", true, false):
		if n is WeatherState:
			return n
	var state := WeatherState.new()
	state.name = "WeatherState"
	scope.add_child(state)
	return state
