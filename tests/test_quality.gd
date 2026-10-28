extends RefCounted
# Story 15.1: a Quality setting (Low, High) picking each scene's renderer extras.

const Sim = preload("res://tests/sim.gd")
const ENV_PATH := "res://data/world/golden_hour.tres"
const WORLD := "res://scenes/world/golden_hour.tscn"

func _extras(env: Environment) -> Array:
	return [env.ssao_enabled, env.ssil_enabled, env.ssr_enabled, env.sdfgi_enabled, env.volumetric_fog_enabled]

func _world(tier: int) -> Node:
	var before := GameSettings.quality
	GameSettings.quality = tier
	var w: Node = Sim.add(load(WORLD).instantiate())
	GameSettings.quality = before
	return w

func test_quality_saves_and_reloads() -> bool:
	var b: JobBoard = Sim.add(load("res://scenes/ui/job_board.tscn").instantiate())
	await Sim.process_frames(1)
	var pick: OptionButton = b.find_child("Quality", true, false)
	pick.select(pick.get_item_index(Quality.Tier.LOW))
	pick.item_selected.emit(pick.selected)
	var shown := pick.visible
	b.free()
	GameSettings.quality = Quality.Tier.HIGH
	SaveGame.load_all(Sim.tree())
	var low := GameSettings.quality == Quality.Tier.LOW
	GameSettings.quality = Quality.Tier.HIGH
	GameSettings.save()
	SaveGame.load_all(Sim.tree())
	var high := GameSettings.quality == Quality.Tier.HIGH
	return low and high and shown and GameSettings.default_quality() == Quality.Tier.HIGH

func test_high_under_forward_plus_turns_every_extra_on() -> bool:
	var env: Environment = load(ENV_PATH).duplicate()
	var sun := DirectionalLight3D.new()
	sun.directional_shadow_max_distance = 250.0
	Quality.apply(env, sun, Quality.Tier.HIGH, "forward_plus")
	var ok: bool = _extras(env) == [true, true, true, true, true] \
		and sun.directional_shadow_max_distance > 250.0 and sun.light_angular_distance > 0.0
	sun.free()
	return ok

func test_low_or_compatibility_turns_every_extra_off() -> bool:
	var ok := true
	for c in [[Quality.Tier.LOW, "forward_plus"], [Quality.Tier.HIGH, "gl_compatibility"], [Quality.Tier.LOW, "gl_compatibility"]]:
		var env: Environment = load(ENV_PATH).duplicate()
		var sun := DirectionalLight3D.new()
		sun.directional_shadow_max_distance = 250.0
		# From High back down, so Low has to undo it.
		Quality.apply(env, sun, Quality.Tier.HIGH, "forward_plus")
		Quality.apply(env, sun, c[0], c[1])
		ok = ok and _extras(env) == [false, false, false, false, false] \
			and sun.directional_shadow_max_distance == 250.0 and sun.light_angular_distance == 0.0
		sun.free()
	return ok and not Quality.extras_on(Quality.Tier.HIGH, "mobile")

func test_scene_follows_the_setting() -> bool:
	var hi := _world(Quality.Tier.HIGH)
	var lo := _world(Quality.Tier.LOW)
	var hi_env: Environment = hi.get_node("WorldEnvironment").environment
	var lo_env: Environment = lo.get_node("WorldEnvironment").environment
	# Headless runs report Forward+; the tier alone decides here.
	var on := Quality.renderer() == "forward_plus"
	var ok: bool = _extras(hi_env) == [on, on, on, on, on] and _extras(lo_env) == [false, false, false, false, false]
	hi.free()
	lo.free()
	return ok

func test_shared_environment_untouched_on_disk() -> bool:
	var before := FileAccess.get_file_as_string(ENV_PATH)
	var shared: Environment = load(ENV_PATH)
	var shared_extras := _extras(shared)
	var hi := _world(Quality.Tier.HIGH)
	var lo := _world(Quality.Tier.LOW)
	var ok: bool = hi.get_node("WorldEnvironment").environment != shared \
		and lo.get_node("WorldEnvironment").environment != shared
	hi.free()
	lo.free()
	var on_disk: Environment = ResourceLoader.load(ENV_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	return ok and FileAccess.get_file_as_string(ENV_PATH) == before and _extras(shared) == shared_extras \
		and _extras(on_disk) == shared_extras

func test_weather_fog_applies_on_both_tiers() -> bool:
	var fog: Weather = load("res://data/weather/fog_bank.tres")
	var ok := true
	for tier in [Quality.Tier.LOW, Quality.Tier.HIGH]:
		var w := _world(tier)
		Weather.apply(fog, null, w)
		var env: Environment = w.get_node("WorldEnvironment").environment
		var fogged: bool = is_equal_approx(env.fog_density, fog.fog_density) and env.fog_light_color == fog.fog_color
		if env.volumetric_fog_enabled:
			fogged = fogged and tier == Quality.Tier.HIGH and is_equal_approx(env.volumetric_fog_density, fog.fog_density * Quality.VOLUMETRIC_PER_FOG) \
				and env.volumetric_fog_albedo == fog.fog_color
		Weather.apply(null, null, w)
		var cleared: bool = is_equal_approx(w.get_node("WorldEnvironment").environment.fog_density, load(ENV_PATH).fog_density)
		if not (fogged and cleared):
			push_warning("tier %d: fogged %s cleared %s" % [tier, fogged, cleared])
		ok = ok and fogged and cleared
		w.free()
	return ok
