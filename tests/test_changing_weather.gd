extends RefCounted
# Story 13.6: changing weather. Halfway through a blend every numeric field is
# halfway between the two presets; rain and snow swap at the midpoint; a job's
# weather sequence runs on its schedule; E in free flight lands on the next
# preset after its blend time, not before.

const Sim = preload("res://tests/sim.gd")
const ENV := preload("res://data/world/golden_hour.tres")

static func _weather(kind: Weather.Precipitation, intensity: float, temperature: float, per_minute: float, fog: float, wind_base: Vector3) -> Weather:
	var w := Weather.new()
	w.precipitation = kind
	w.intensity = intensity
	w.temperature = temperature
	w.lightning_per_minute = per_minute
	w.strike_distance = Vector2(300.0 + per_minute * 10.0, 1500.0 + per_minute * 100.0)
	w.fog_density = fog
	w.fog_color = Color(0.2 + fog * 10.0, 0.5, 0.7, 1.0)
	w.sky_affect = 0.2 + fog * 10.0
	w.wind = Wind.new()
	w.wind.base = wind_base
	w.wind.gust_amplitude = wind_base.length()
	w.wind.gust_period = 3.0 + wind_base.length()
	w.wind.turbulence = wind_base.length() * 0.5
	w.wind.shear = 0.1 + wind_base.length() * 0.01
	return w

static func _near(a: float, b: float) -> bool:
	return absf(a - b) < 1e-4

## Every numeric field of `m` is halfway between `a` and `b`.
static func _halfway(m: Weather, a: Weather, b: Weather) -> bool:
	var ok: bool = _near(m.fog_density, (a.fog_density + b.fog_density) / 2.0) \
		and _near(m.sky_affect, (a.sky_affect + b.sky_affect) / 2.0) \
		and m.fog_color.is_equal_approx(a.fog_color.lerp(b.fog_color, 0.5)) \
		and _near(m.intensity, (a.intensity + b.intensity) / 2.0) \
		and _near(m.temperature, (a.temperature + b.temperature) / 2.0) \
		and _near(m.lightning_per_minute, (a.lightning_per_minute + b.lightning_per_minute) / 2.0) \
		and m.strike_distance.is_equal_approx((a.strike_distance + b.strike_distance) / 2.0) \
		and m.wind.base.is_equal_approx((a.wind.base + b.wind.base) / 2.0) \
		and _near(m.wind.gust_amplitude, (a.wind.gust_amplitude + b.wind.gust_amplitude) / 2.0) \
		and _near(m.wind.gust_period, (a.wind.gust_period + b.wind.gust_period) / 2.0) \
		and _near(m.wind.turbulence, (a.wind.turbulence + b.wind.turbulence) / 2.0) \
		and _near(m.wind.shear, (a.wind.shear + b.wind.shear) / 2.0)
	return ok

static func _scene() -> Node3D:
	var root := Node3D.new()
	var we := WorldEnvironment.new()
	we.name = "Env"
	we.environment = ENV
	root.add_child(we)
	return root

func test_halfway_through_a_blend_every_field_is_halfway() -> bool:
	var a := _weather(Weather.Precipitation.RAIN, 0.2, 20.0, 1.0, 0.01, Vector3(2, 0, 1))
	var b := _weather(Weather.Precipitation.RAIN, 0.9, -4.0, 6.0, 0.04, Vector3(-6, 0, 8))
	var pure_ok := _halfway(Weather.blend(a, b, 0.5), a, b)
	var fog: Weather = load("res://data/weather/fog_bank.tres")
	var white: Weather = load("res://data/weather/whiteout.tres")
	var presets_ok := _halfway(Weather.blend(fog, white, 0.5), fog, white)
	# The same in a scene: WeatherState, the drone, and the fog all sit halfway.
	var base_fog := ENV.fog_density
	var base_sky := ENV.fog_sky_affect
	var root: Node3D = Sim.add(_scene())
	var d: Drone = Sim.DRONE.instantiate()
	root.add_child(d)
	Weather.apply(a, d, root)
	var state := WeatherState.of(root)
	state.blend_to(b, 4.0, d, root)
	state.advance(2.0)
	var env: Environment = (root.get_node("Env") as WorldEnvironment).environment
	var scene_ok: bool = state.blending and _halfway(state.weather, a, b) and d.weather == state.weather \
		and d.wind.base.is_equal_approx((a.wind.base + b.wind.base) / 2.0) \
		and _near(env.fog_density, (a.fog_density + b.fog_density) / 2.0) \
		and _near(env.fog_sky_affect, (a.sky_affect + b.sky_affect) / 2.0) \
		and env.fog_light_color.is_equal_approx(a.fog_color.lerp(b.fog_color, 0.5))
	state.advance(2.0)
	var landed: bool = not state.blending and state.weather == b and d.wind == b.wind and is_equal_approx(env.fog_density, b.fog_density)
	var shared_ok: bool = env != ENV and ENV.fog_density == base_fog and ENV.fog_sky_affect == base_sky
	root.free()
	if not (pure_ok and presets_ok and scene_ok and landed and shared_ok):
		print("        %s %s %s %s %s" % [pure_ok, presets_ok, scene_ok, landed, shared_ok])
	return pure_ok and presets_ok and scene_ok and landed and shared_ok

func test_precipitation_swaps_at_the_midpoint() -> bool:
	var rain := _weather(Weather.Precipitation.RAIN, 0.6, 5.0, 0.0, 0.01, Vector3.ZERO)
	var snow := _weather(Weather.Precipitation.SNOW, 0.4, -5.0, 0.0, 0.01, Vector3.ZERO)
	var q1 := Weather.blend(rain, snow, 0.25)
	var mid := Weather.blend(rain, snow, 0.5)
	var q3 := Weather.blend(rain, snow, 0.75)
	var swap_ok: bool = q1.precipitation == Weather.Precipitation.RAIN and _near(q1.intensity, 0.3) \
		and _near(mid.intensity, 0.0) and q3.precipitation == Weather.Precipitation.SNOW and _near(q3.intensity, 0.2)
	# From clear, rain fades in; to clear, it fades out. Never both kinds at once.
	var fade_in := Weather.blend(null, rain, 0.5)
	var fade_out := Weather.blend(rain, null, 0.5)
	var fade_ok: bool = fade_in.precipitation == Weather.Precipitation.RAIN and _near(fade_in.intensity, 0.3) \
		and fade_out.precipitation == Weather.Precipitation.RAIN and _near(fade_out.intensity, 0.3) \
		and q1.validate().is_empty() and q3.validate().is_empty()
	return swap_ok and fade_ok

func test_job_weather_sequence_runs_on_schedule() -> bool:
	var fog: Weather = load("res://data/weather/fog_bank.tres")
	var job := Job.new()
	job.countdown = 0.1
	# Clear, then fog rolling in from 1 s over 1 s, then clear again at once at 3 s.
	var roll_in := WeatherChange.new()
	roll_in.at = 1.0
	roll_in.weather = fog
	roll_in.blend_time = 1.0
	var lift := WeatherChange.new()
	lift.at = 3.0
	lift.blend_time = 0.0
	job.weather_changes = [roll_in, lift]
	var root := Sim.job_setup(job)
	var we := WorldEnvironment.new()
	we.environment = ENV
	root.add_child(we)
	var runner: JobRunner = root.get_node("Runner")
	var d: Drone = root.get_node("Drone")
	await Sim.go_live(root)
	var state := WeatherState.of(root)
	await Sim.physics_frames(48) # 0.8 s
	var before: bool = state.weather == null and not state.blending and we.environment == ENV
	await Sim.physics_frames(30) # 1.3 s
	var rolling: bool = state.blending and we.environment.fog_density > ENV.fog_density \
		and we.environment.fog_density < fog.fog_density
	await Sim.physics_frames(48) # 2.1 s
	var fogged: bool = state.weather == fog and not state.blending and d.wind == fog.wind \
		and is_equal_approx(we.environment.fog_density, fog.fog_density)
	await Sim.physics_frames(60) # 3.1 s
	var lifted: bool = state.weather == null and we.environment == ENV and d.wind == null
	var ok: bool = runner.state == JobRunner.State.LIVE and before and rolling and fogged and lifted
	if not ok:
		print("        %s %s %s %s live %.2f" % [before, rolling, fogged, lifted, runner.live_time])
	root.free()
	return ok

func test_e_in_free_flight_blends_over_three_seconds() -> bool:
	var s: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	await Sim.process_frames(2)
	var d: Drone = s.get_node("Drone")
	var env_node: WorldEnvironment = s.find_children("*", "WorldEnvironment", true, false)[0]
	var fog: Weather = load("res://data/weather/fog_bank.tres")
	var breeze := d.wind
	var ev := InputEventAction.new()
	ev.action = &"cycle_weather"
	ev.pressed = true
	s.get_viewport().push_input(ev)
	var state := WeatherState.of(s)
	var started: bool = state.blending and state.weather != fog and is_equal_approx(s.weather_blend_time, 3.0)
	await Sim.process_frames(90) # about 1.5 s
	var mid_fog: float = env_node.environment.fog_density
	var halfway: bool = state.blending and absf(mid_fog - (ENV.fog_density + fog.fog_density) / 2.0) < fog.fog_density * 0.05
	await Sim.process_frames(80) # about 2.8 s
	var not_yet: bool = state.blending and state.weather != fog
	await Sim.process_frames(20) # past 3 s
	var reached: bool = not state.blending and state.weather == fog and d.wind == fog.wind \
		and is_equal_approx(env_node.environment.fog_density, fog.fog_density)
	# Back to clear the same way: the scene's own sky and breeze once it lands.
	s.cycle_weather()
	s.cycle_weather()
	state.advance(s.weather_blend_time)
	var cleared: bool = state.weather == null and env_node.environment == ENV and d.wind == breeze
	var ok: bool = started and halfway and not_yet and reached and cleared
	if not ok:
		print("        %s %s(%.4f) %s %s %s" % [started, halfway, mid_fog, not_yet, reached, cleared])
	s.free()
	return ok

# Mid-session the wind changes smoothly: a blend between gust periods and seeds
# late in the drone's clock adds no extra gust cycles and no turbulence jump.
func test_wind_stays_continuous_through_a_blend() -> bool:
	var fog: Weather = load("res://data/weather/fog_bank.tres")
	var white: Weather = load("res://data/weather/whiteout.tres")
	var start := 300.0
	var steps := 300
	var dt := 3.0 / steps
	var worst := 0.0
	var prev := Weather.blend(fog, white, 0.0).wind.sample(start)
	for i in range(1, steps + 1):
		var w := Weather.blend(fog, white, float(i) / steps)
		var v := w.wind.sample(start + i * dt)
		worst = maxf(worst, v.distance_to(prev))
		prev = v
	# Either endpoint alone changes at most this much per step.
	var own := 0.0
	for wind in [fog.wind, white.wind]:
		for i in range(1, steps + 1):
			own = maxf(own, (wind as Wind).sample(start + i * dt).distance_to((wind as Wind).sample(start + (i - 1) * dt)))
	# A blend interrupted mid-way starts from the mix it was at, with no cycle.
	var root: Node3D = Sim.add(_scene())
	var state := WeatherState.of(root)
	Weather.apply(fog, null, root)
	state.blend_to(white, 3.0, null, root)
	state.advance(1.5)
	var before_v := state.weather.wind.sample(start)
	state.blend_to(fog, 3.0, null, root)
	var after_v := state.weather.wind.sample(start)
	for i in 10:
		state.blend_to(white if i % 2 == 0 else fog, 3.0, null, root)
		state.advance(0.5)
	var nested_ok: bool = state.weather.wind.mix_depth() <= Wind.MAX_MIX_DEPTH + 1
	root.free()
	var ok: bool = worst <= own * 1.5 + 0.05 and before_v.is_equal_approx(after_v) and nested_ok
	if not ok:
		print("        worst %.3f own %.3f %s %s %s" % [worst, own, before_v, after_v, nested_ok])
	return ok

# Once a blend lands, rain falls at exactly the preset's count.
func test_rain_count_is_exact_once_a_blend_lands() -> bool:
	var light := _weather(Weather.Precipitation.RAIN, 0.5, 10.0, 0.0, 0.01, Vector3.ZERO)
	var heavier := _weather(Weather.Precipitation.RAIN, 0.53, 10.0, 0.0, 0.01, Vector3.ZERO)
	var root: Node3D = Sim.add(_scene())
	var state := WeatherState.of(root)
	Weather.apply(light, null, root)
	var rain: Rain = state.get_node("Rain")
	rain.advance(0.0)
	state.blend_to(heavier, 1.0, null, root)
	state.advance(0.5)
	rain.advance(0.0)
	state.advance(0.6)
	rain.advance(0.0)
	var ok: bool = not state.blending and rain.particles != null and rain.particles.amount == rain.amount()
	if not ok:
		print("        %s %d vs %d" % [state.blending, rain.particles.amount if rain.particles else -1, rain.amount()])
	root.free()
	return ok
