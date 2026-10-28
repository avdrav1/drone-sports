extends RefCounted
# Story 13.1: weather as layers. Every new field loads from a .tres, the old
# presets apply as before, and a scene's WeatherState holds the weather in effect.

const Sim = preload("res://tests/sim.gd")
const ENV := preload("res://data/world/golden_hour.tres")
const PATH := "user://test_weather_layers.tres"

const TRES := """[gd_resource type="Resource" script_class="Weather" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/world/weather.gd" id="1_weather"]
[ext_resource type="Script" path="res://scripts/drone/wind.gd" id="2_wind"]

[sub_resource type="Resource" id="wind"]
script = ExtResource("2_wind")
base = Vector3(6, 0, 0)
gust_amplitude = 3.0
gust_period = 4.0
turbulence = 1.5
shear = 0.2

[resource]
script = ExtResource("1_weather")
label = "Storm"
fog_density = 0.01
wind = SubResource("wind")
fog_color = Color(0.4, 0.42, 0.45, 1)
sky_affect = 0.5
precipitation = 1
intensity = 0.8
temperature = -4.0
lightning_per_minute = 3.0
strike_distance = Vector2(600, 2500)
"""

func test_every_new_field_loads_from_tres() -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(TRES)
	f.close()
	var w: Weather = ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return w != null and w.precipitation == Weather.Precipitation.RAIN and is_equal_approx(w.intensity, 0.8) \
		and is_equal_approx(w.temperature, -4.0) and is_equal_approx(w.lightning_per_minute, 3.0) \
		and w.strike_distance == Vector2(600, 2500) and is_equal_approx(w.wind.turbulence, 1.5) \
		and is_equal_approx(w.wind.shear, 0.2) and is_equal_approx(w.sky_affect, 0.5) \
		and is_equal_approx(w.fog_density, 0.01) and w.fog_color == Color(0.4, 0.42, 0.45, 1)

func test_new_fields_default_to_off() -> bool:
	var w := Weather.new()
	var wind := Wind.new()
	return w.precipitation == Weather.Precipitation.NONE and w.intensity == 0.0 \
		and w.lightning_per_minute == 0.0 and w.temperature > 10.0 and wind.turbulence == 0.0 and wind.shear == 0.0

func _applied(w: Weather) -> Environment:
	var root := Node3D.new()
	var we := WorldEnvironment.new()
	we.environment = ENV
	root.add_child(we)
	Weather.apply(w, null, root)
	var env := we.environment
	root.free()
	return env

func test_old_presets_apply_exactly_as_before() -> bool:
	var fog: Weather = load("res://data/weather/fog_bank.tres")
	var white: Weather = load("res://data/weather/whiteout.tres")
	var e1 := _applied(fog)
	var e2 := _applied(white)
	var fog_ok: bool = is_equal_approx(e1.fog_density, 0.03) and e1.fog_light_color == Color(0.6, 0.62, 0.66, 1) \
		and is_equal_approx(e1.fog_sky_affect, 0.7) and e1.fog_sun_scatter == 0.0 \
		and fog.wind.base == Vector3(4, 0, 2) and is_equal_approx(fog.wind.gust_amplitude, 4.0) \
		and is_equal_approx(fog.wind.gust_period, 5.0)
	var white_ok: bool = is_equal_approx(e2.fog_density, 0.05) and e2.fog_light_color == Color(0.88, 0.9, 0.93, 1) \
		and is_equal_approx(e2.fog_sky_affect, 0.95) and white.wind.base == Vector3(4, 0, -2) \
		and is_equal_approx(white.wind.gust_amplitude, 5.0) and is_equal_approx(white.wind.gust_period, 4.0)
	# Same wind as before: the new wind fields are off, so a sample matches the old formula.
	var t := 2.3
	var w := TAU / 5.0
	var old_sample := Vector3(4, 0, 2) + Vector3(4, 0, 2).normalized() * 4.0 \
		* 0.5 * (1.0 + 0.7 * sin(w * t) + 0.3 * sin(w * 2.37 * t + 1.3))
	var wind_ok: bool = fog.wind.sample(t).is_equal_approx(old_sample)
	var layers_off: bool = fog.precipitation == Weather.Precipitation.NONE and white.precipitation == Weather.Precipitation.NONE \
		and fog.lightning_per_minute == 0.0 and white.lightning_per_minute == 0.0 \
		and fog.wind.turbulence == 0.0 and white.wind.shear == 0.0
	if not (fog_ok and white_ok and wind_ok and layers_off):
		print("        %s %s %s %s" % [fog_ok, white_ok, wind_ok, layers_off])
	return fog_ok and white_ok and wind_ok and layers_off and ENV.fog_density != 0.03

func test_weather_state_reports_after_apply() -> bool:
	var root: Node3D = Sim.add(Node3D.new())
	var placed := WeatherState.new()
	root.add_child(placed)
	var fog: Weather = load("res://data/weather/fog_bank.tres")
	Weather.apply(fog, null, root)
	var holds_fog: bool = placed.weather == fog and WeatherState.of(root) == placed
	Weather.apply(null, null, root)
	var clear: bool = placed.weather == null
	root.free()
	# A scene without one gets one.
	var bare: Node3D = Sim.add(Node3D.new())
	Weather.apply(fog, null, bare)
	var made: WeatherState = WeatherState.of(bare)
	var added: bool = made.weather == fog and made.get_parent() == bare
	bare.free()
	return holds_fog and clear and added

func test_job_and_free_flight_fill_weather_state() -> bool:
	var white: Weather = load("res://data/weather/whiteout.tres")
	var job := Job.new()
	job.weather = white
	var root := Sim.job_setup(job)
	(root.get_node("Runner") as JobRunner).begin()
	var job_ok: bool = WeatherState.of(root).weather == white
	root.free()
	var s: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	await Sim.process_frames(2)
	s.cycle_weather()
	var fog: Weather = load("res://data/weather/fog_bank.tres")
	var flight_ok: bool = WeatherState.of(s).weather == fog
	s.free()
	return job_ok and flight_ok
