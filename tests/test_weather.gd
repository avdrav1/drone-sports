extends RefCounted
# Story 4.5: weather. Fog density and gusts load from the Job; no weather is clear and still.

const Sim = preload("res://tests/sim.gd")
const ENV := preload("res://data/world/golden_hour.tres")

func _rig(weather: Weather) -> Node:
	var job := Job.new()
	job.weather = weather
	var root := Sim.job_setup(job)
	var we := WorldEnvironment.new()
	we.environment = ENV
	root.add_child(we)
	return root

func test_weather_loads_from_job() -> bool:
	var weather: Weather = load("res://data/weather/fog_bank.tres")
	var root := _rig(weather)
	var base_density := ENV.fog_density
	var runner: JobRunner = root.get_node("Runner")
	var d: Drone = root.get_node("Drone")
	runner.begin()
	var env: Environment = root.find_children("*", "WorldEnvironment", true, false)[0].environment
	var ok := is_equal_approx(env.fog_density, 0.03) and d.wind == weather.wind \
		and is_equal_approx(d.wind.gust_amplitude, 4.0) and ENV.fog_density == base_density
	root.free()
	return ok

func test_no_weather_is_clear_and_still() -> bool:
	var root := _rig(null)
	var runner: JobRunner = root.get_node("Runner")
	var d: Drone = root.get_node("Drone")
	d.wind = load("res://data/wind/debug_breeze.tres")
	d.assists.apply_stack(Sim.all_off())
	runner.begin()
	var env: Environment = root.find_children("*", "WorldEnvironment", true, false)[0].environment
	await Sim.go_live(root)
	d.assists.apply_stack(Sim.all_off())
	await Sim.physics_frames(30)
	var ok := env == ENV and d.wind == null and d.wind_velocity() == Vector3.ZERO
	root.free()
	return ok

func test_gusts_reach_the_sim_without_the_assist() -> bool:
	var root := _rig(load("res://data/weather/fog_bank.tres"))
	var d: Drone = root.get_node("Drone")
	await Sim.go_live(root)
	d.assists.apply_stack(Sim.all_off())
	await Sim.physics_frames(30)
	var v := d.wind_velocity()
	root.free()
	return v.length() > 4.0
