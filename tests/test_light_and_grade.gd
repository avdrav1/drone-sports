extends RefCounted
# Story 15.3: light and grade. AgX with the tuned exposure, a colour grade, and
# glow kept to hot spots; the sun's cascades come from data; weather and
# lightning still work on the new look.

const Sim = preload("res://tests/sim.gd")
const ENV_PATH := "res://data/world/golden_hour.tres"
const SHADOW_PATH := "res://data/world/sun_shadow.tres"
const WORLD := "res://scenes/world/golden_hour.tscn"
const WEATHER_DIR := "res://data/weather/"

func _world(tier: int, shadow: SunShadow = null) -> Node:
	var before := GameSettings.quality
	GameSettings.quality = tier
	var w: Node = load(WORLD).instantiate()
	if shadow:
		w.shadow = shadow
	Sim.add(w)
	GameSettings.quality = before
	return w

## The shared Environment's tonemap, glow, and grade, and a scene copy's match.
func _graded(env: Environment, shared: Environment) -> bool:
	return env.tonemap_mode == Environment.TONE_MAPPER_AGX \
		and env.tonemap_exposure == shared.tonemap_exposure \
		and env.tonemap_agx_white == shared.tonemap_agx_white \
		and env.tonemap_agx_contrast == shared.tonemap_agx_contrast \
		and env.glow_enabled and env.glow_bloom == 0.0 and env.glow_hdr_threshold >= 1.0 \
		and env.adjustment_enabled and env.adjustment_color_correction == shared.adjustment_color_correction

func test_environment_uses_agx_and_tuned_values() -> bool:
	var shared: Environment = load(ENV_PATH)
	# Tuned away from the engine's defaults, with a grade curve in place.
	var tuned: bool = shared.tonemap_mode == Environment.TONE_MAPPER_AGX \
		and shared.tonemap_exposure != 1.0 and shared.tonemap_agx_white != 16.5 \
		and shared.tonemap_agx_contrast != 1.0 and shared.adjustment_saturation != 1.0 \
		and shared.adjustment_color_correction is GradientTexture1D
	var ok := tuned
	for tier in [Quality.Tier.LOW, Quality.Tier.HIGH]:
		var w := _world(tier)
		var env: Environment = w.get_node("WorldEnvironment").environment
		ok = ok and env != shared and _graded(env, shared)
		w.free()
	if not ok:
		push_warning("tuned %s" % tuned)
	return ok

func test_sun_cascades_come_from_data() -> bool:
	var data: SunShadow = load(SHADOW_PATH)
	var low := _world(Quality.Tier.LOW)
	var sun: DirectionalLight3D = low.get_node("Sun")
	var from_data: bool = sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS \
		and is_equal_approx(sun.directional_shadow_max_distance, data.max_distance) \
		and is_equal_approx(sun.directional_shadow_split_1, data.split_1) \
		and is_equal_approx(sun.directional_shadow_split_2, data.split_2) \
		and is_equal_approx(sun.directional_shadow_split_3, data.split_3) \
		and is_equal_approx(sun.directional_shadow_fade_start, data.fade_start) \
		and data.split_1 < data.split_2 and data.split_2 < data.split_3
	low.free()
	# Other data moves the scene with it, on Low and on High's reach.
	var other: SunShadow = data.duplicate()
	other.max_distance = 180.0
	other.high_distance = 450.0
	other.split_1 = 0.08
	other.split_2 = 0.2
	other.split_3 = 0.5
	var w := _world(Quality.Tier.LOW, other)
	sun = w.get_node("Sun")
	var follows: bool = is_equal_approx(sun.directional_shadow_max_distance, 180.0) \
		and is_equal_approx(sun.directional_shadow_split_1, 0.08) \
		and is_equal_approx(sun.directional_shadow_split_2, 0.2) \
		and is_equal_approx(sun.directional_shadow_split_3, 0.5)
	Quality.apply(w.get_node("WorldEnvironment").environment, sun, Quality.Tier.HIGH, "forward_plus")
	var high: bool = is_equal_approx(sun.directional_shadow_max_distance, 450.0) \
		and is_equal_approx(sun.light_angular_distance, other.high_sun_angle)
	Quality.apply(w.get_node("WorldEnvironment").environment, sun, Quality.Tier.LOW, "forward_plus")
	var back: bool = is_equal_approx(sun.directional_shadow_max_distance, 180.0)
	w.free()
	var ok: bool = from_data and follows and high and back
	if not ok:
		push_warning("data %s follows %s high %s back %s" % [from_data, follows, high, back])
	return ok

func test_every_weather_preset_still_applies() -> bool:
	var shared: Environment = load(ENV_PATH)
	var ok := true
	var count := 0
	for file in DirAccess.get_files_at(WEATHER_DIR):
		if not file.ends_with(".tres"):
			continue
		var preset: Weather = load(WEATHER_DIR + file)
		var w := _world(Quality.Tier.LOW)
		Weather.apply(preset, null, w)
		var env: Environment = w.get_node("WorldEnvironment").environment
		var applied: bool = is_equal_approx(env.fog_density, preset.fog_density) and _graded(env, shared)
		if preset.fog_color.a >= 1.0:
			applied = applied and env.fog_light_color == Color(preset.fog_color, 1.0)
		Weather.apply(null, null, w)
		var cleared: bool = is_equal_approx(w.get_node("WorldEnvironment").environment.fog_density, shared.fog_density)
		if not (applied and cleared):
			push_warning("%s: applied %s cleared %s" % [file, applied, cleared])
		ok = ok and applied and cleared
		count += 1
		w.free()
	return ok and count >= 5

func test_lightning_flash_raises_and_returns_ambient() -> bool:
	var storm: Weather = load(WEATHER_DIR + "storm.tres")
	var w := _world(Quality.Tier.LOW)
	Weather.apply(storm, null, w)
	var env: Environment = w.get_node("WorldEnvironment").environment
	var base := env.ambient_light_energy
	var lightning: Lightning = WeatherState.of(w).get_node("Lightning")
	var hits := [0]
	lightning.struck.connect(func(_s: Lightning.Strike) -> void: hits[0] += 1)
	var guard := 0
	while hits[0] == 0 and guard < 20000:
		lightning.advance(0.01)
		guard += 1
	var raised: bool = hits[0] > 0 and env.ambient_light_energy > base * 1.5
	for i in 50:
		lightning.advance(0.01)
	var back: bool = is_equal_approx(env.ambient_light_energy, base)
	w.free()
	if not (raised and back):
		push_warning("raised %s back %s" % [raised, back])
	return raised and back
