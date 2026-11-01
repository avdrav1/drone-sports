extends RefCounted
# Story 26.12: traffic you can hear. A fixed pool of voices (engine and tyre
# loops on AudioStreamPlayer3Ds) follows the cars nearest the drone: the pool
# never exceeds its size whatever car_count is, and the nearest car within
# range always has a voice. The loops come from tools/sfx/generate.py, whose
# --check passes. (The web build holding frame rate is a hand check.)

const Sim = preload("res://tests/sim.gd")
const SANDBOX := preload("res://data/city/sandbox_city.tres")
const STREETS := preload("res://scenes/world/streets.tscn")
const TRAFFIC := preload("res://scenes/world/traffic.tscn")
const FREE_FLIGHT := "res://scenes/debug_flight.tscn"

## Streets and traffic from seed 7's sandbox with `cars` cars, stepped by hand,
## and a listener node the sound follows.
static func _build(cars: int) -> Array:
	var l: CityLayout = SANDBOX.duplicate()
	l.car_count = cars
	var streets: Streets = STREETS.instantiate()
	streets.layout = l
	var traffic: Traffic = TRAFFIC.instantiate()
	streets.add_child(traffic)
	var ear := Node3D.new()
	streets.add_child(ear)
	Sim.add(streets)
	await Sim.physics_frames(2)
	traffic.set_physics_process(false)
	var sound: TrafficSound = traffic.get_node("Sound")
	sound.set_physics_process(false)
	sound.target = ear
	return [streets, traffic, sound, ear]

static func _done(streets: Streets) -> void:
	streets.free()
	Streets.prune(SANDBOX)
	StreetClutter.prune(SANDBOX)
	Traffic.prune(SANDBOX)
	CityPlan.prune(SANDBOX)

## The car nearest `at` within `reach`, by brute force, or null.
static func _nearest(traffic: Traffic, at: Vector3, reach: float) -> Variant:
	var best: Variant = null
	var d := reach
	for c in traffic.cars:
		var e := c.body.global_position.distance_to(at)
		if e <= d:
			d = e
			best = c
	return best

## Drives the traffic for `ticks` steps with the listener hopping to a new
## car's side every two seconds (and out past every car now and then),
## calling `check` after each sound update.
static func _run(traffic: Traffic, sound: TrafficSound, ear: Node3D, ticks: int, check: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2612
	for tick in ticks:
		if tick % 120 == 0:
			if tick % 600 == 480:
				ear.global_position = Vector3(5000, 30, 5000)
			else:
				var c: Traffic.Car = traffic.cars[rng.randi() % traffic.cars.size()]
				ear.global_position = c.body.global_position + Vector3(rng.randf_range(-15, 15), rng.randf_range(2, 20), rng.randf_range(-15, 15))
		else:
			ear.global_position += Vector3(0.1, 0, 0.05)
		traffic.step(1.0 / 60.0)
		traffic._place()
		sound.update()
		check.call()

## However many cars drive, the pool holds exactly its voices (two players
## each) and never follows more cars than it has voices, nor one car twice.
func test_voice_pool_never_exceeds_its_size() -> bool:
	var ok := true
	for cars in [26, 200]:
		var built: Array = await _build(cars)
		var traffic: Traffic = built[1]
		var sound: TrafficSound = built[2]
		var players := sound.find_children("*", "AudioStreamPlayer3D", true, false).size()
		var stats := {"most": 0, "bad": 0}
		_run(traffic, sound, built[3], 1800, func():
			var playing := 0
			for p in sound.find_children("*", "AudioStreamPlayer3D", true, false):
				playing += 1 if p.playing else 0
			var on := sound.heard.filter(func(c): return c != null)
			stats.most = maxi(stats.most, on.size())
			var seen := {}
			for c in on:
				if seen.has(c):
					stats.bad += 1
				seen[c] = true
			if on.size() > sound.voices or playing > 2 * sound.voices or sound.heard.size() != sound.voices:
				stats.bad += 1)
		var good: bool = players == 2 * sound.voices and stats.bad == 0 and stats.most == sound.voices \
			and traffic.cars.size() > sound.voices and (cars == 26 or traffic.cars.size() > 26)
		if not good:
			print("        car_count %d: %d cars, %d players, most heard %d, %d bad ticks" % [
				cars, traffic.cars.size(), players, stats.most, stats.bad])
		ok = ok and good
		_done(built[0])
	return ok

## Every tick the car nearest the drone within reach has a voice, every voiced
## car is within reach, and with no car in reach every voice is silent.
func test_the_nearest_car_within_range_always_has_a_voice() -> bool:
	var built: Array = await _build(26)
	var traffic: Traffic = built[1]
	var sound: TrafficSound = built[2]
	var ear: Node3D = built[3]
	var stats := {"miss": 0, "far": 0, "heard": 0, "alone": 0}
	_run(traffic, sound, ear, 3600, func():
		var near: Variant = _nearest(traffic, ear.global_position, sound.reach)
		if near == null:
			stats.alone += 1
			stats.miss += sound.voiced()
		else:
			stats.heard += 1
			if sound.voice_of(near) < 0:
				stats.miss += 1
		for c in sound.heard:
			if c != null and c.body.global_position.distance_to(ear.global_position) > sound.reach:
				stats.far += 1)
	_done(built[0])
	var ok: bool = stats.miss == 0 and stats.far == 0 and stats.heard > 1000 and stats.alone > 100
	if not ok:
		print("        %s" % stats)
	return ok

## A car keeps its voice while it stays among the nearest, and the engine
## pitch and tyre level rise with its speed.
func test_a_voice_sticks_to_its_car_and_follows_its_speed() -> bool:
	var built: Array = await _build(26)
	var traffic: Traffic = built[1]
	var sound: TrafficSound = built[2]
	var ear: Node3D = built[3]
	var c: Traffic.Car = traffic.cars[0]
	ear.global_position = c.body.global_position + Vector3(0, 3, 0)
	sound.update()
	var v := sound.voice_of(c)
	c.speed = 0.0
	sound.update()
	var slow_pitch := sound.engines[v].pitch_scale
	var slow_db := sound.tyres[v].volume_db
	c.speed = sound.top_speed
	sound.update()
	var ok := v >= 0 and sound.voice_of(c) == v and is_equal_approx(slow_pitch, sound.idle_pitch) \
		and is_equal_approx(sound.engines[v].pitch_scale, sound.full_pitch) and sound.tyres[v].volume_db > slow_db + 10.0 \
		and sound.engines[v].global_position.is_equal_approx(c.body.global_position)
	_done(built[0])
	return ok

## The nearest pick, on many points: at most n, nearest first, all in reach.
func test_nearest_picks_at_most_n_nearest_first() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 26
	var pts := PackedVector3Array()
	for i in 1000:
		pts.append(Vector3(rng.randf_range(-300, 300), 0, rng.randf_range(-300, 300)))
	var picks := TrafficSound.nearest(pts, Vector3.ZERO, 4, 60.0)
	var inside := []
	for i in pts.size():
		if pts[i].length() <= 60.0:
			inside.append(i)
	inside.sort_custom(func(a, b): return pts[a].length() < pts[b].length())
	return picks.size() == 4 and Array(picks) == inside.slice(0, 4) \
		and TrafficSound.nearest(pts, Vector3(5000, 0, 0), 4, 60.0).is_empty() \
		and TrafficSound.nearest(PackedVector3Array([Vector3.ONE]), Vector3.ZERO, 4, 60.0).size() == 1

## The engine and tyre loops are generated sounds in the bank, looped, on the
## World bus, and the generator's --check passes.
func test_car_loops_are_generated_and_check_passes() -> bool:
	var ok := true
	for id in [TrafficSound.ENGINE, TrafficSound.TYRES]:
		var e := Sfx.bank.find(id)
		var s: AudioStreamWAV = e.streams[0] if e and not e.streams.is_empty() else null
		ok = ok and s != null and s.loop_mode == AudioStreamWAV.LOOP_FORWARD and e.bus == &"World" \
			and s.resource_path.begins_with("res://data/audio/generated/")
	var out := []
	var code := OS.execute("python3", [ProjectSettings.globalize_path("res://tools/sfx/generate.py"), "--check"], out, true)
	if code != 0:
		print("        sfx generate.py --check exited %d: %s" % [code, "".join(out).strip_edges()])
	return ok and code == 0

## Free flight hears its traffic from the drone, and still does after a reroll.
func test_free_flight_hears_traffic_from_the_drone() -> bool:
	var s: Node = load(FREE_FLIGHT).instantiate()
	s.use_city_seed(7)
	Sim.add(s)
	await Sim.physics_frames(3)
	var sound: TrafficSound = s.get_node("Streets/Traffic/Sound")
	var drone: Node3D = s.get_node("Drone")
	var ok: bool = sound.target == drone and sound.traffic == s.get_node("Streets/Traffic")
	s.reroll_city()
	await Sim.physics_frames(3)
	var c: Traffic.Car = sound.traffic.cars[0]
	drone.global_position = c.body.global_position + Vector3(0, 2, 0)
	sound.update()
	ok = ok and s.get_node_or_null("Streets/Traffic/Sound") == sound and sound.voice_of(c) >= 0 \
		and sound.find_children("*", "AudioStreamPlayer3D", true, false).size() == 2 * sound.voices
	s.free()
	return ok
