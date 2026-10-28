class_name WeatherState
extends Node
# The weather in effect in a scene, so rain, snow, lightning, and sound read one
# place. `Weather.apply` sets it, adding one to the scene if it has none (Story 13.1).
# It carries the scene's Rain (Story 13.2), Snow (Story 13.3), and Lightning (Story 13.5).
# It also blends from the weather in effect to another over a set time (Story 13.6).

signal changed(weather: Weather)
## Emitted when a blend reaches its target.
signal blended(weather: Weather)

## The weather in effect; null is clear.
var weather: Weather:
	set(value):
		weather = value
		changed.emit(value)

## True while a blend is under way.
var blending := false
var _from: Weather
var _to: Weather
var _mix := Weather.new()
var _blend_time := 0.0
var _elapsed := 0.0
var _drone: Drone
var _scope: Node

func _ready() -> void:
	if get_node_or_null(^"Rain") == null:
		var rain := Rain.new()
		rain.name = "Rain"
		add_child(rain)
	if get_node_or_null(^"Snow") == null:
		var snow := Snow.new()
		snow.name = "Snow"
		add_child(snow)
	if get_node_or_null(^"Lightning") == null:
		var lightning := Lightning.new()
		lightning.name = "Lightning"
		add_child(lightning)

## The scope's WeatherState: an existing one below it, or a new child.
static func of(scope: Node) -> WeatherState:
	for n in scope.find_children("*", "Node", true, false):
		if n is WeatherState:
			return n
	var state := WeatherState.new()
	state.name = "WeatherState"
	scope.add_child(state)
	return state

## Moves from the weather in effect to `to` over `seconds`, putting each step on
## `drone` and `scope` with Weather.apply, and `to` itself at the end. With no
## weather in effect the drone's own wind is where the blend starts.
func blend_to(to: Weather, seconds: float, drone: Drone, scope: Node) -> void:
	# A copy, since the weather in effect may be the last blend's mix.
	_from = Weather.blend(weather, weather, 0.0, _clear_environment(scope))
	if weather == null and drone and drone.wind:
		_from.wind = drone.wind
	_to = to
	_drone = drone
	_scope = scope
	_blend_time = maxf(seconds, 0.0)
	_elapsed = 0.0
	blending = true
	advance(0.0)

func _process(delta: float) -> void:
	advance(delta)

## One step of the blend, if one is under way.
func advance(delta: float) -> void:
	if not blending:
		return
	_elapsed += delta
	var drone: Drone = _drone if is_instance_valid(_drone) else null
	if _elapsed >= _blend_time or not is_instance_valid(_scope):
		blending = false
		if is_instance_valid(_scope):
			Weather.apply(_to, drone, _scope)
		blended.emit(_to)
		return
	Weather.blend(_from, _to, _elapsed / _blend_time, _clear_environment(_scope), _mix)
	Weather.apply(_mix, drone, _scope)

## The scene's own Environment, before any weather; null with none.
static func _clear_environment(scope: Node) -> Environment:
	if scope == null:
		return null
	for env_node in scope.find_children("*", "WorldEnvironment", true, false):
		return env_node.get_meta(&"clear_environment", env_node.environment)
	return null
