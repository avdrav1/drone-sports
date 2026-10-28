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
## Seeds when and where strikes land; the same seed repeats the storm (Story 13.5).
@export var storm_seed := 0

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

## `a` turned `t` (0..1) of the way into `b`, written into `into` (a new Weather
## when null) so a blend can reuse one resource. Every number and colour moves
## linearly; null is Weather.new(), clear and still. Precipitation keeps one
## kind: from or to none it fades in or out, and between rain and snow it swaps
## at the midpoint, where intensity passes through zero. A side that keeps the
## scene's own fog colour or sky cover blends from `clear`'s (Story 13.6).
static func blend(a: Weather, b: Weather, t: float, clear: Environment = null, into: Weather = null) -> Weather:
	a = a if a else Weather.new()
	b = b if b else Weather.new()
	t = clampf(t, 0.0, 1.0)
	var out := into if into else Weather.new()
	out.label = a.label if t < 0.5 else b.label
	out.fog_density = lerpf(a.fog_density, b.fog_density, t)
	out.fog_color = _own_color(a.fog_color, b.fog_color).lerp(_own_color(b.fog_color, a.fog_color), t)
	out.sky_affect = lerpf(_own_sky(a.sky_affect, b.sky_affect, clear), _own_sky(b.sky_affect, a.sky_affect, clear), t)
	var pa := a.intensity if a.precipitation != Precipitation.NONE else 0.0
	var pb := b.intensity if b.precipitation != Precipitation.NONE else 0.0
	if a.precipitation == b.precipitation or a.precipitation == Precipitation.NONE or b.precipitation == Precipitation.NONE:
		out.precipitation = b.precipitation if b.precipitation != Precipitation.NONE else a.precipitation
		out.intensity = lerpf(pa, pb, t)
	else:
		out.precipitation = a.precipitation if t < 0.5 else b.precipitation
		out.intensity = pa * (1.0 - 2.0 * t) if t < 0.5 else pb * (2.0 * t - 1.0)
	out.temperature = lerpf(a.temperature, b.temperature, t)
	out.lightning_per_minute = lerpf(a.lightning_per_minute, b.lightning_per_minute, t)
	out.strike_distance = a.strike_distance.lerp(b.strike_distance, t)
	# One storm throughout when only one side has one, so it does not restart.
	var a_storm: bool = a.lightning_per_minute > 0.0 and (t < 0.5 or b.lightning_per_minute <= 0.0)
	out.storm_seed = a.storm_seed if a_storm else b.storm_seed
	if a.wind == null and b.wind == null:
		out.wind = null
	else:
		var wa := a.wind if a.wind else Wind.new()
		var wb := b.wind if b.wind else Wind.new()
		# A new Wind each step: an older mix may still sample through the last one.
		out.wind = Wind.new()
		out.wind.mix(wa, wb, t)
	return out

## A fog colour that keeps the scene's (alpha 0) takes `other`'s hue at alpha 0,
## so a blend fades the tint in rather than through black.
static func _own_color(c: Color, other: Color) -> Color:
	return c if c.a > 0.0 else Color(other, 0.0)

## A sky cover that keeps the scene's (below 0) resolves to `clear`'s, or to
## `other`'s with no Environment to ask.
static func _own_sky(v: float, other: float, clear: Environment) -> float:
	if v >= 0.0:
		return v
	if clear:
		return clear.fog_sky_affect
	return other if other >= 0.0 else v

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
			# Reuse this scene's copy, so a blend does not copy every frame.
			var env: Environment = env_node.environment if env_node.environment != clear else clear.duplicate()
			env.fog_density = w.fog_density
			# The fog colour's alpha is how much it replaces the scene's.
			var a := clampf(w.fog_color.a, 0.0, 1.0)
			env.fog_light_color = Color(w.fog_color, 1.0) if a >= 1.0 else clear.fog_light_color.lerp(Color(w.fog_color, 1.0), a)
			env.fog_sun_scatter = lerpf(clear.fog_sun_scatter, 0.0, a)
			env.fog_sky_affect = w.sky_affect if w.sky_affect >= 0.0 else clear.fog_sky_affect
			env_node.environment = env
