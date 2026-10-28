extends RefCounted
# Story 13.3: snow. Flakes move with the wind's direction, cover builds while it
# snows and melts back to 0, and rain and snow together fail validation.

const Sim = preload("res://tests/sim.gd")
const ENV := preload("res://data/world/golden_hour.tres")
const MIXED := "user://test_snow_mixed.tres"

static func _snow(intensity: float, wind_base := Vector3.ZERO) -> Weather:
	var w := Weather.new()
	w.precipitation = Weather.Precipitation.SNOW
	w.intensity = intensity
	w.temperature = -4.0
	if wind_base != Vector3.ZERO:
		w.wind = Wind.new()
		w.wind.base = wind_base
	return w

func _scene() -> Node3D:
	var root := Node3D.new()
	var we := WorldEnvironment.new()
	we.environment = ENV
	root.add_child(we)
	var rig: CameraRig = load("res://scenes/camera/camera_rig.tscn").instantiate()
	rig.name = "Rig"
	root.add_child(rig)
	Sim.add(root)
	(rig.camera as Camera3D).make_current()
	return root

func _snow_node(root: Node) -> Snow:
	return WeatherState.of(root).get_node("Snow")

func _run(snow: Snow, seconds: float) -> void:
	for i in roundi(seconds / 0.1):
		snow.advance(0.1)

## Horizontal heading of the flakes' launch direction.
static func _heading(p: CPUParticles3D) -> Vector3:
	return Vector3(p.direction.x, 0.0, p.direction.z)

func test_flakes_move_with_wind_direction() -> bool:
	var root := _scene()
	var snow := _snow_node(root)
	var camera: Camera3D = root.get_node("Rig").camera
	Weather.apply(_snow(0.7), null, root)
	snow.advance(0.1)
	var still_down: bool = snow.particles != null and snow.particles.get_parent() == camera \
		and _heading(snow.particles).length() < 0.01 and snow.particles.direction.y < 0.0
	var east := Vector3(6.0, 0.0, 0.0)
	Weather.apply(_snow(0.7, east), null, root)
	snow.advance(0.1)
	var east_ok: bool = _heading(snow.particles).normalized().dot(Vector3.RIGHT) > 0.99 \
		and snow.particles.direction.y < 0.0
	var east_speed: float = snow.particles.initial_velocity_max
	var north := Vector3(0.0, 0.0, -6.0)
	Weather.apply(_snow(0.7, north), null, root)
	snow.advance(0.1)
	var north_ok: bool = _heading(snow.particles).normalized().dot(Vector3.FORWARD) > 0.99
	# Slower than rain in still air, carried faster by wind.
	Weather.apply(_snow(0.7), null, root)
	snow.advance(0.1)
	var calm_speed: float = snow.particles.initial_velocity_max
	var slow: bool = calm_speed < 3.0 and east_speed > calm_speed
	var amount_ok: bool = snow.particles.amount == roundi(snow.max_amount * 0.7)
	root.free()
	var ok: bool = still_down and east_ok and north_ok and slow and amount_ok
	if not ok:
		print("        %s %s %s %s %s" % [still_down, east_ok, north_ok, slow, amount_ok])
	return ok

func test_cover_rises_while_snowing_and_melts_to_zero() -> bool:
	var root := _scene()
	var snow := _snow_node(root)
	Weather.apply(_snow(1.0), null, root)
	var bare: bool = snow.cover == 0.0
	_run(snow, 10.0)
	var partway: float = snow.cover
	# The headless renderer may not read globals back; check when it does.
	var uniform = RenderingServer.global_shader_parameter_get(&"snow_cover")
	var uniform_ok: bool = uniform == null or is_equal_approx(float(uniform), partway)
	_run(snow, 30.0)
	var white: float = snow.cover
	Weather.apply(null, null, root)
	_run(snow, 5.0)
	var melting: float = snow.cover
	var no_flakes: bool = snow.particles == null
	_run(snow, 60.0)
	var melted: float = snow.cover
	# Rain makes no cover.
	var rain := Weather.new()
	rain.precipitation = Weather.Precipitation.RAIN
	rain.intensity = 1.0
	Weather.apply(rain, null, root)
	_run(snow, 5.0)
	var rain_bare: bool = snow.cover == 0.0 and snow.amount() == 0
	root.free()
	var ok: bool = bare and partway > 0.1 and partway < 0.6 and uniform_ok and is_equal_approx(white, 1.0) \
		and melting > 0.0 and melting < 1.0 and no_flakes and melted == 0.0 and rain_bare
	if not ok:
		print("        %s %.2f %s %.2f %.2f %s %.2f %s" % [bare, partway, uniform_ok, white, melting, no_flakes, melted, rain_bare])
	return ok

func test_shaders_read_cover_as_global() -> bool:
	for path in ["res://scenes/world/city.gdshader", "res://scenes/world/streets.gdshader", "res://scenes/world/desert.gdshader"]:
		if not (load(path) as Shader).code.contains("global uniform float snow_cover"):
			return false
	return ProjectSettings.has_setting("shader_globals/snow_cover")

func test_rain_and_snow_together_fail_validation() -> bool:
	# A preset on disk that stores both kinds at once.
	var f := FileAccess.open(MIXED, FileAccess.WRITE)
	f.store_string("[gd_resource type=\"Resource\" script_class=\"Weather\" load_steps=2 format=3]\n\n" \
		+ "[ext_resource type=\"Script\" path=\"res://scripts/world/weather.gd\" id=\"1\"]\n\n" \
		+ "[resource]\nscript = ExtResource(\"1\")\nlabel = \"Sleet\"\nprecipitation = %d\nintensity = 0.5\n" \
		% (Weather.Precipitation.RAIN | Weather.Precipitation.SNOW))
	f.close()
	var mixed: Weather = ResourceLoader.load(MIXED, "", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MIXED))
	var rejected: bool = mixed != null and not mixed.validate().is_empty() \
		and mixed.validate()[0].contains("rain and snow")
	var singles_ok: bool = _snow(0.5).validate().is_empty()
	var rain := Weather.new()
	rain.precipitation = Weather.Precipitation.RAIN
	rain.intensity = 0.5
	singles_ok = singles_ok and rain.validate().is_empty()
	for path in ["res://data/weather/fog_bank.tres", "res://data/weather/whiteout.tres"]:
		singles_ok = singles_ok and (load(path) as Weather).validate().is_empty()
	if not (rejected and singles_ok):
		print("        %s %s" % [rejected, singles_ok])
	return rejected and singles_ok
