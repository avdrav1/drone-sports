extends RefCounted
# Story 13.2: rain. Streak count follows intensity, wetness ramps up over about
# 10 s and dries back to 0, lens drops show only in FPV, and nothing shared on
# disk changes.

const Sim = preload("res://tests/sim.gd")
const ENV := preload("res://data/world/golden_hour.tres")
const SHARED := [
	"res://data/world/golden_hour.tres",
	"res://scenes/world/city.gdshader",
	"res://scenes/world/streets.gdshader",
	"res://scenes/world/desert.gdshader",
	"res://scenes/world/lens_drops.gdshader",
	"res://scenes/world/city.tscn",
	"res://scenes/world/streets.tscn",
	"res://scenes/world/desert.tscn",
]

static func _rain(intensity: float) -> Weather:
	var w := Weather.new()
	w.precipitation = Weather.Precipitation.RAIN
	w.intensity = intensity
	return w

## A scene with a camera rig and a WorldEnvironment on the shared golden hour.
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

func _rain_node(root: Node) -> Rain:
	return WeatherState.of(root).get_node("Rain")

func test_amount_scales_with_intensity_and_is_zero_without_rain() -> bool:
	var root := _scene()
	var rain := _rain_node(root)
	var camera: Camera3D = root.get_node("Rig").camera
	Weather.apply(null, null, root)
	rain.advance(0.1)
	var clear_zero: bool = rain.amount() == 0 and rain.particles == null
	Weather.apply(_rain(0.25), null, root)
	rain.advance(0.1)
	var light: int = rain.particles.amount
	var on_camera: bool = rain.particles.get_parent() == camera
	Weather.apply(_rain(1.0), null, root)
	rain.advance(0.1)
	var heavy: int = rain.particles.amount
	var scaled: bool = light == roundi(rain.max_amount * 0.25) and heavy == rain.max_amount and heavy > light
	Weather.apply(_rain(0.0), null, root)
	rain.advance(0.1)
	var zero_intensity: bool = rain.amount() == 0 and rain.particles == null
	var fog: Weather = load("res://data/weather/fog_bank.tres")
	Weather.apply(fog, null, root)
	rain.advance(0.1)
	var fog_zero: bool = rain.amount() == 0 and rain.particles == null
	root.free()
	if not (clear_zero and on_camera and scaled and zero_intensity and fog_zero):
		print("        %s %s %s(%d, %d) %s %s" % [clear_zero, on_camera, scaled, light, heavy, zero_intensity, fog_zero])
	return clear_zero and on_camera and scaled and zero_intensity and fog_zero

func _run(rain: Rain, seconds: float) -> void:
	for i in roundi(seconds / 0.1):
		rain.advance(0.1)

func test_wetness_rises_over_about_10s_and_dries_to_zero() -> bool:
	var root := _scene()
	var rain := _rain_node(root)
	Weather.apply(_rain(0.6), null, root)
	var dry_start: bool = rain.wetness == 0.0
	_run(rain, 3.0)
	var partway: float = rain.wetness
	_run(rain, 8.0)
	var soaked: float = rain.wetness
	Weather.apply(null, null, root)
	_run(rain, 2.0)
	var drying: float = rain.wetness
	_run(rain, 60.0)
	var dried: float = rain.wetness
	root.free()
	var ok: bool = dry_start and partway > 0.2 and partway < 0.5 and is_equal_approx(soaked, 1.0) \
		and drying < 1.0 and drying > 0.0 and dried == 0.0
	if not ok:
		print("        %s %.2f %.2f %.2f %.2f" % [dry_start, partway, soaked, drying, dried])
	return ok

func test_lens_drops_only_in_fpv() -> bool:
	var root := _scene()
	var rain := _rain_node(root)
	var rig: CameraRig = root.get_node("Rig")
	Weather.apply(_rain(0.8), null, root)
	rig.set_view(CameraRig.View.CHASE)
	rain.advance(0.1)
	var chase_off: bool = not rain.lens_showing()
	rig.set_view(CameraRig.View.FPV)
	rain.advance(0.1)
	var fpv_on: bool = rain.lens_showing()
	Weather.apply(null, null, root)
	rain.advance(0.1)
	var stopped_off: bool = not rain.lens_showing()
	root.free()
	return chase_off and fpv_on and stopped_off

func test_shared_environment_and_shaders_untouched() -> bool:
	var times := {}
	for path in SHARED:
		times[path] = FileAccess.get_modified_time(path)
	var codes := {}
	for path in SHARED:
		if path.ends_with(".gdshader"):
			codes[path] = (load(path) as Shader).code
	var env_before := [ENV.fog_density, ENV.fog_light_color, ENV.fog_sky_affect, ENV.ambient_light_energy]
	var root := _scene()
	var rain := _rain_node(root)
	Weather.apply(_rain(1.0), null, root)
	_run(rain, 12.0)
	Weather.apply(null, null, root)
	_run(rain, 30.0)
	root.free()
	var env_ok: bool = env_before == [ENV.fog_density, ENV.fog_light_color, ENV.fog_sky_affect, ENV.ambient_light_energy]
	var disk_ok := true
	for path in SHARED:
		if FileAccess.get_modified_time(path) != times[path]:
			disk_ok = false
		if codes.has(path) and (load(path) as Shader).code != codes[path]:
			disk_ok = false
	# The shaders read wetness as a global uniform, not a material parameter.
	var reads_global := true
	for path in ["res://scenes/world/city.gdshader", "res://scenes/world/streets.gdshader", "res://scenes/world/desert.gdshader"]:
		if not (load(path) as Shader).code.contains("global uniform float wetness"):
			reads_global = false
	return env_ok and disk_ok and reads_global
