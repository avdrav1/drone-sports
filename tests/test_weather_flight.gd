extends RefCounted
# Story 13.8: weather in the flight model. Rain slows the drone, cold drains the
# battery, snow below freezing ices the props, and the battery and wind assist
# shields all of it.

const Sim = preload("res://tests/sim.gd")

static func _stack(shielded: bool) -> AssistStack:
	var s := Sim.all_off()
	s.auto_level = true
	s.altitude_hold = true
	s.battery_wind = shielded
	return s

static func _weather(precipitation: Weather.Precipitation, intensity: float, temperature: float) -> Weather:
	var w := Weather.new()
	w.precipitation = precipitation
	w.intensity = intensity
	w.temperature = temperature
	return w

static func _rain() -> Weather:
	return _weather(Weather.Precipitation.RAIN, 1.0, 15.0)

static func _snow() -> Weather:
	return _weather(Weather.Precipitation.SNOW, 1.0, -5.0)

## Horizontal speed after flying full forward for 6 s in `w`.
static func _top_speed(w: Weather, shielded: bool) -> float:
	var d := Sim.drone(Sim.intent(0.0, -1.0), Vector3(0, 30, 0), _stack(shielded))
	d.weather = w
	await Sim.physics_frames(360)
	var v := d.linear_velocity
	d.free()
	return Vector2(v.x, v.z).length()

## Battery left after 3 s of hover at `temperature`.
static func _battery_after(temperature: float, shielded: bool) -> float:
	var d := Sim.drone(Sim.intent(), Vector3(0, 30, 0), _stack(shielded))
	d.battery_flight_time = 20.0
	d.weather = _weather(Weather.Precipitation.NONE, 0.0, temperature)
	await Sim.physics_frames(180)
	var b := d.battery
	d.free()
	return b

## Vertical speed after 1 s of full throttle from rest, level.
static func _climb(d: Drone) -> float:
	d.global_position = Vector3(0, 30, 0)
	d.linear_velocity = Vector3.ZERO
	d.freeze = false
	d.intent_source.value = Sim.intent(1.0)
	await Sim.physics_frames(60)
	var vy := d.linear_velocity.y
	d.freeze = true
	d.intent_source.value = Sim.intent()
	return vy

static func _level_stack(shielded: bool) -> AssistStack:
	var s := Sim.all_off()
	s.auto_level = true
	s.battery_wind = shielded
	return s

func test_heavy_rain_lowers_top_speed() -> bool:
	var dry: float = await _top_speed(null, false)
	var wet: float = await _top_speed(_rain(), false)
	if not wet < dry * 0.9:
		print("        dry %.2f wet %.2f" % [dry, wet])
	return dry > 5.0 and wet < dry * 0.9

func test_cold_drains_battery_faster() -> bool:
	var warm: float = await _battery_after(20.0, false)
	var cold: float = await _battery_after(-10.0, false)
	var mild: float = await _battery_after(10.0, false)
	if not (cold < warm - 0.02 and is_equal_approx(mild, warm)):
		print("        20C %.3f 10C %.3f -10C %.3f" % [warm, mild, cold])
	return warm < 1.0 and cold < warm - 0.02 and is_equal_approx(mild, warm)

func test_icing_builds_lowers_climb_and_sheds() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 30, 0), _level_stack(false))
	d.ice_build_time = 2.0
	d.ice_shed_time = 1.0
	d.freeze = true
	var clear: float = await _climb(d)
	d.weather = _snow()
	await Sim.physics_frames(150)
	var built: bool = d.icing > 0.99
	var iced: float = await _climb(d)
	# Still iced: snow keeps it on. Then clear skies shed it.
	d.weather = null
	await Sim.physics_frames(90)
	var shed: bool = d.icing == 0.0
	var after: float = await _climb(d)
	# Warm snow never ices.
	d.weather = _weather(Weather.Precipitation.SNOW, 1.0, 2.0)
	await Sim.physics_frames(120)
	var warm_clear: bool = d.icing == 0.0
	d.free()
	var ok: bool = built and iced < clear * 0.8 and shed and is_equal_approx(after, clear) and warm_clear
	if not ok:
		print("        built %s climb %.2f iced %.2f after %.2f shed %s warm %s" % [built, clear, iced, after, shed, warm_clear])
	return ok

func test_hud_shows_icing_chip() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 30, 0), _level_stack(false))
	d.freeze = true
	var hud := FlightHud.new()
	hud.drone = d
	Sim.add(hud)
	await Sim.physics_frames(2)
	var before := hud.icing_shown()
	d.ice_build_time = 1.0
	d.weather = _snow()
	await Sim.physics_frames(30)
	var during := hud.icing_shown()
	hud.free()
	d.free()
	return not before and during

func test_assist_shields_every_weather_effect() -> bool:
	var ok := true
	# Rain: same top speed as dry.
	var dry: float = await _top_speed(null, true)
	var wet: float = await _top_speed(_rain(), true)
	ok = ok and is_equal_approx(dry, wet)
	# Cold: battery never drains.
	ok = ok and (await _battery_after(-10.0, true)) == 1.0
	# Snow below freezing: no ice, same climb.
	var d := Sim.drone(Sim.intent(), Vector3(0, 30, 0), _level_stack(true))
	d.ice_build_time = 1.0
	d.freeze = true
	var clear: float = await _climb(d)
	d.weather = _snow()
	await Sim.physics_frames(120)
	var no_ice: bool = d.icing == 0.0
	var climb: float = await _climb(d)
	d.free()
	ok = ok and no_ice and is_equal_approx(climb, clear)
	if not ok:
		print("        dry %.3f wet %.3f ice %s climb %.3f vs %.3f" % [dry, wet, no_ice, climb, clear])
	return ok
