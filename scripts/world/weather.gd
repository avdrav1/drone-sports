class_name Weather
extends Resource
# Per-job weather in layers: precipitation, temperature, wind, fog, and storm.
# Fog is for the eye; everything else reaches the drone only through the
# environment sim. A job with no Weather flies in the scene's own clear
# golden-hour haze with no wind. Free flight cycles through presets (Story 4.6).
# New layers default to off (Story 13.1).

enum Precipitation { NONE, RAIN, SNOW }

## Shown when free flight switches to it.
@export var label := ""

## Exponential fog density, replacing the scene's. Visual only.
@export var fog_density := 0.0016
## Fed to the drone's wind sim (Story 1.7). Null is still air.
@export var wind: Wind
## The fog's colour; transparent keeps the scene's golden haze.
@export var fog_color := Color(0, 0, 0, 0)
## How much the fog hides the sky, 0..1; below 0 keeps the scene's.
@export var sky_affect := -1.0

## What falls, if anything.
@export var precipitation := Precipitation.NONE
## How hard it falls, 0..1. Ignored with no precipitation.
@export_range(0.0, 1.0) var intensity := 0.0
## Air temperature, °C. 15 is mild: no cold or icing effects.
@export var temperature := 15.0

## Lightning strikes per minute; 0 is no storm. Atmosphere only.
@export var lightning_per_minute := 0.0
## Nearest and farthest a strike lands from the scene's centre, m.
@export var strike_distance := Vector2(400.0, 2000.0)

## Problems with this preset; empty when it is valid. Precipitation is one
## kind at a time: a stored value of RAIN | SNOW (rain and snow together) is
## rejected, as are intensities outside 0..1 and a strike range that runs backwards.
func validate() -> Array[String]:
	var out: Array[String] = []
	var p := int(precipitation)
	if p == Precipitation.RAIN | Precipitation.SNOW:
		out.append("%s: rain and snow together; pick one" % label)
	elif not p in Precipitation.values():
		out.append("%s: unknown precipitation %d" % [label, p])
	if intensity < 0.0 or intensity > 1.0:
		out.append("%s: intensity %.2f outside 0..1" % [label, intensity])
	if strike_distance.x < 0.0 or strike_distance.x > strike_distance.y:
		out.append("%s: strike distance must run min to max" % label)
	return out

## Puts `w` on a scene: its wind and weather on the drone, its fog on a copy of each
## WorldEnvironment's own Environment, so the shared resource is untouched.
## Null clears: still air and the scene's own environment back. The scope's
## WeatherState then holds `w` as the weather in effect.
static func apply(w: Weather, drone: Drone, scope: Node) -> void:
	if drone:
		drone.wind = w.wind if w else null
		drone.weather = w
	if scope == null:
		return
	WeatherState.of(scope).weather = w
	for env_node in scope.find_children("*", "WorldEnvironment", true, false):
		if not env_node.has_meta(&"clear_environment"):
			env_node.set_meta(&"clear_environment", env_node.environment)
		var clear: Environment = env_node.get_meta(&"clear_environment")
		if w == null:
			env_node.environment = clear
		else:
			var env: Environment = clear.duplicate()
			env.fog_density = w.fog_density
			if w.fog_color.a > 0.0:
				env.fog_light_color = w.fog_color
				env.fog_sun_scatter = 0.0
			if w.sky_affect >= 0.0:
				env.fog_sky_affect = w.sky_affect
			env_node.environment = env
