extends RefCounted
# Story 13.7: presets and placement. Every preset in data/weather/ loads and
# validates, free flight's E cycles them all, and jobs name their weather in
# their .tres. Completion with that weather is checked by each job's own test
# (test_demolition, test_fleet_race, test_rescue), which load the same scenes.

const Sim = preload("res://tests/sim.gd")
const DIR := "res://data/weather/"
const PRESETS := ["clear", "light_rain", "storm", "blizzard", "fog_bank", "whiteout"]
## Job, its weather preset, and the scene its existing completion test flies.
const PLACED := {
	"demolition": "light_rain",
	"fleet_race": "storm",
	"rescue": "whiteout",
}

func _presets() -> Array[Weather]:
	var out: Array[Weather] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".tres"):
			out.append(load(DIR + f))
	return out

func test_every_preset_loads_and_validates() -> bool:
	var names: Array = []
	var ok := true
	for w in _presets():
		names.append(w.resource_path.get_file().get_basename())
		var problems := w.validate()
		if w.label.is_empty() or not problems.is_empty():
			print("        %s: %s" % [w.resource_path, problems])
			ok = false
	for n in PRESETS:
		ok = ok and n in names
	var rain: Weather = load(DIR + "light_rain.tres")
	var storm: Weather = load(DIR + "storm.tres")
	var snow: Weather = load(DIR + "blizzard.tres")
	var clear: Weather = load(DIR + "clear.tres")
	ok = ok and rain.precipitation == Weather.Precipitation.RAIN and rain.intensity < 0.5 \
		and storm.precipitation == Weather.Precipitation.RAIN and storm.lightning_per_minute > 0.0 \
		and snow.precipitation == Weather.Precipitation.SNOW and snow.temperature < 0.0 \
		and clear.precipitation == Weather.Precipitation.NONE and clear.wind == null
	return ok

func test_free_flight_e_cycles_every_preset() -> bool:
	var s: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	await Sim.process_frames(2)
	var seen: Array = []
	for i in s.weathers.size() + 1:
		var ev := InputEventAction.new()
		ev.action = &"cycle_weather"
		ev.pressed = true
		s.get_viewport().push_input(ev)
		WeatherState.of(s).advance(s.weather_blend_time)
		var w: Weather = WeatherState.of(s).weather
		seen.append(w.resource_path.get_file().get_basename() if w else "clear")
	# Clear is free flight's own sky and breeze (index -1), so clear.tres is not cycled.
	var ok: bool = seen.back() == "clear" and s.weather_index == -1
	for n in PRESETS:
		ok = ok and n in seen
	if not ok:
		print("        seen %s" % [seen])
	s.free()
	return ok

func test_job_weather_is_set_in_its_tres() -> bool:
	var ok := true
	for id in PLACED:
		var job: Job = load("res://data/jobs/%s.tres" % id)
		ok = ok and job.weather != null and job.weather.resource_path == DIR + PLACED[id] + ".tres"
		# The scene's runner flies that same job, so its existing test flies in this weather.
		var scene: Node = load(job.scene).instantiate()
		var runner: JobRunner = scene.get_node("JobRunner")
		ok = ok and runner.job.weather == job.weather
		scene.free()
	# Every job on the board names its weather from data/weather/, or none.
	for job in (load("res://data/jobs/board.tres") as JobList).jobs:
		if job.weather and not job.weather.resource_path.begins_with(DIR):
			print("        %s: inline weather" % job.id)
			ok = false
	return ok

func test_launch_applies_the_jobs_weather() -> bool:
	var scene: Node = Sim.add(load("res://scenes/jobs/demolition.tscn").instantiate())
	await Sim.process_frames(2)
	var runner: JobRunner = scene.get_node("JobRunner")
	runner.launch()
	await Sim.physics_frames(2)
	var d: Drone = scene.get_node("Drone")
	var rain: Weather = load(DIR + "light_rain.tres")
	# Act 3 keeps the battery and wind assist on: the rain is seen, not felt.
	var ok: bool = WeatherState.of(scene).weather == rain and d.weather == rain \
		and not d.intent.environment_sim
	scene.free()
	return ok
