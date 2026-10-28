extends RefCounted
# Story 17.8: flight events. Each event fires from a scripted drone state that
# meets its threshold and not from one just short of it, keeps its cooldown,
# battery low fires once per charge, a crash is a hard contact and a landing is
# not, and the watcher changes nothing it reads.

const Sim = preload("res://tests/sim.gd")
const RULES := preload("res://data/radio/flight_events.tres")

## A coasting drone: motors off, no gravity, no drag, so it holds `velocity`.
## The battery holds too (it drains against gravity), so tests set it.
func _coaster(at: Vector3, velocity := Vector3.ZERO) -> Drone:
	var still := Sim.intent(-1.0)
	still.environment_sim = false
	var d := Sim.drone(still, at)
	d.gravity_scale = 0.0
	d.drag = 0.0
	d.angular_drag = 0.0
	d.linear_velocity = velocity
	return d

## A watcher on `d` that logs its events into `heard`.
func _watcher(d: Drone, heard: Array) -> FlightWatcher:
	var w := FlightWatcher.new()
	w.drone = d
	w.flight_event.connect(func(e): heard.append(e))
	Sim.add(w)
	return w

func _box(at: Vector3, extents: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var s := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = extents
	s.shape = shape
	b.add_child(s)
	Sim.add(b)
	b.global_position = at
	return b

func _free(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.free()

## Runs `frames` physics frames of a coaster from `at` at `velocity` past
## `boxes` (each [centre, size]) and returns what was heard.
func _fly(at: Vector3, velocity: Vector3, frames: int, boxes := []) -> Array:
	var made := []
	for b in boxes:
		made.append(_box(b[0], b[1]))
	var d := _coaster(at, velocity)
	var heard := []
	var w := _watcher(d, heard)
	await Sim.physics_frames(frames)
	_free(made + [d, w])
	return heard

const FLOOR := [Vector3(0, -0.5, 0), Vector3(400, 1, 400)]

func test_takeoff() -> bool:
	var rose: Array = await _fly(Vector3(0, 0.2, 0), Vector3(0, 2, 0), 60, [FLOOR])
	var short: Array = await _fly(Vector3(0, 0.2, 0), Vector3(0, 2, 0), 30, [FLOOR])
	# Already in the air at the start is not a takeoff.
	var aloft: Array = await _fly(Vector3(0, 5, 0), Vector3(0, 2, 0), 60, [FLOOR])
	return &"takeoff" in rose and not &"takeoff" in short and not &"takeoff" in aloft

func test_near_miss() -> bool:
	# A wall 4 m long whose face is at x = 0; the drone passes along it.
	var wall := [Vector3(-1, 50, 0), Vector3(2, 20, 4)]
	var close: Array = await _fly(Vector3(1.6, 50, -8), Vector3(0, 0, 9), 120, [wall])
	var wide: Array = await _fly(Vector3(2.4, 50, -8), Vector3(0, 0, 9), 120, [wall])
	var slow: Array = await _fly(Vector3(1.6, 50, -8), Vector3(0, 0, 7.5), 150, [wall])
	# Hitting it is a crash, not a near miss.
	var hit: Array = await _fly(Vector3(4, 50, -1), Vector3(-9, 0, 0), 60, [wall])
	return close.count(&"near_miss") == 1 and not &"near_miss" in wide and not &"near_miss" in slow \
		and not &"near_miss" in hit and &"crash" in hit

func test_low_pass() -> bool:
	var low: Array = await _fly(Vector3(0, 2.5, 0), Vector3(11, 0, 0), 90, [FLOOR])
	var high: Array = await _fly(Vector3(0, 3.5, 0), Vector3(11, 0, 0), 90, [FLOOR])
	var slow: Array = await _fly(Vector3(0, 2.5, 0), Vector3(9, 0, 0), 90, [FLOOR])
	# A long low pass is one event.
	return low.count(&"low_pass") == 1 and not &"low_pass" in high and not &"low_pass" in slow

func test_top_speed() -> bool:
	var flat_out: Array = await _fly(Vector3(0, 50, 0), Vector3(26, 0, 0), 30)
	var short: Array = await _fly(Vector3(0, 50, 0), Vector3(24, 0, 0), 30)
	return flat_out.count(&"top_speed") == 1 and not &"top_speed" in short

func test_battery_low_once_per_charge() -> bool:
	var d := _coaster(Vector3(0, 50, 0))
	var heard := []
	var w := _watcher(d, heard)
	var steps := [[0.3, 0], [0.26, 0], [0.25, 1], [0.2, 1], [0.1, 1]]
	var ok := true
	for s in steps:
		d.battery = s[0]
		await Sim.physics_frames(2)
		ok = ok and heard.count(&"battery_low") == s[1]
	# A fresh charge arms it again, past the cooldown.
	d.battery = 1.0
	await Sim.physics_frames(2)
	w.time += RULES.cooldown(&"battery_low")
	d.battery = 0.24
	await Sim.physics_frames(2)
	ok = ok and heard.count(&"battery_low") == 2
	_free([d, w])
	return ok

func test_crash_not_landing() -> bool:
	var crash: Array = await _fly(Vector3(0, 2, 0), Vector3(0, -6, 0), 60, [FLOOR])
	var landing: Array = await _fly(Vector3(0, 1, 0), Vector3(0, -1, 0), 90, [FLOOR])
	return &"crash" in crash and not &"crash" in landing

func test_reset_and_recovery() -> bool:
	var d := _coaster(Vector3(0, 50, 0))
	var heard := []
	var w := _watcher(d, heard)
	await Sim.physics_frames(2)
	d.reset(Transform3D(Basis(), Vector3(0, 60, 0)))
	var first := heard.count(&"reset")
	w.time += RULES.cooldown(&"reset")
	d.recover(Transform3D(Basis(), Vector3(0, 60, 0)))
	var ok := first == 1 and heard.count(&"reset") == 2
	_free([d, w])
	return ok

func test_weather_change() -> bool:
	var d := _coaster(Vector3(0, 50, 0))
	d.weather = load("res://data/weather/clear.tres")
	var heard := []
	var w := _watcher(d, heard)
	await Sim.physics_frames(2)
	# The same weather again is no change.
	d.weather = load("res://data/weather/clear.tres").duplicate()
	await Sim.physics_frames(2)
	var same := heard.count(&"weather_change")
	d.weather = load("res://data/weather/light_rain.tres")
	await Sim.physics_frames(2)
	var ok := same == 0 and heard.count(&"weather_change") == 1
	_free([d, w])
	return ok

func test_long_hover() -> bool:
	var frames := roundi(RULES.hover_time * 60.0)
	var held: Array = await _fly(Vector3(0, 10, 0), Vector3.ZERO, frames + 10, [FLOOR])
	var short: Array = await _fly(Vector3(0, 10, 0), Vector3.ZERO, frames - 30, [FLOOR])
	# Sitting on the ground is not hovering.
	var parked: Array = await _fly(Vector3(0, 0.2, 0), Vector3.ZERO, frames + 10, [FLOOR])
	return held.count(&"long_hover") == 1 and not &"long_hover" in short and not &"long_hover" in parked

func test_every_event_keeps_its_cooldown() -> bool:
	var d := _coaster(Vector3(0, 50, 0))
	var heard := []
	var w := _watcher(d, heard)
	var ok := FlightEvents.EVENTS.size() == 9
	for e in FlightEvents.EVENTS:
		var cd := RULES.cooldown(e)
		ok = ok and cd > 0.0 and w.raise(e) and not w.raise(e)
		w.time += cd * 0.9
		ok = ok and not w.raise(e)
		w.time += cd * 0.11
		ok = ok and w.raise(e) and heard.count(e) == 2
	_free([d, w])
	return ok

## Everything the watcher could touch: the drone's stats and state, its intent,
## and every assist's settings.
func _state(d: Drone) -> Array:
	var out := [d.global_position, d.linear_velocity, d.angular_velocity, d.battery, d.icing,
		d.motor_thrusts, d.weather == null, d.wind == null, d.freeze, d.contact_monitor, d.max_contacts_reported,
		d.gravity_scale, d.mass]
	for p in d.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(_plain(d.get(p.name)))
	var i := d.intent
	out.append([i.throttle, i.pitch, i.roll, i.yaw, i.environment_sim])
	for a in d.assists.get_children():
		for p in a.get_property_list():
			# The frame counter differs between runs by when they ran, not by the watcher.
			if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.name != "_last_frame":
				out.append([a.name, p.name, _plain(a.get(p.name))])
	return out

## Values compare across runs; nodes and resources by what they are, not by id.
func _plain(v: Variant) -> Variant:
	if v is Intent:
		return [v.throttle, v.pitch, v.roll, v.yaw, v.environment_sim]
	if v is Object:
		return v.get_class() if v else null
	return v

## The same run of a drone into a wall, past a ledge and low over the floor.
func _run(watch: bool) -> Array:
	var boxes := [_box(FLOOR[0], FLOOR[1]), _box(Vector3(10, 1, 0), Vector3(1, 6, 6))]
	var d := Sim.drone(Sim.intent(0.2, 0.3), Vector3(0, 2.5, 0), load("res://data/assists/act1.tres"))
	d.linear_velocity = Vector3(12, 0, 0)
	var heard := []
	var w: FlightWatcher = _watcher(d, heard) if watch else null
	var before := _state(d)
	await Sim.physics_frames(90)
	var after := _state(d)
	_free(boxes + [d, w])
	return [before, after, heard]

func test_watcher_changes_nothing() -> bool:
	var with: Array = await _run(true)
	var without: Array = await _run(false)
	var ok: bool = str(with[0]) == str(without[0]) and str(with[1]) == str(without[1]) and not with[2].is_empty()
	if not ok:
		print("        heard %s" % [with[2]])
		for k in with[1].size():
			if str(with[1][k]) != str(without[1][k]):
				print("        %d: %s vs %s" % [k, with[1][k], without[1][k]])
	return ok

func test_jobs_and_sandbox_place_a_watcher() -> bool:
	var scenes := ["res://scenes/debug_flight.tscn", "res://scenes/boss/lattice_job.tscn"]
	for f in DirAccess.get_files_at("res://scenes/jobs"):
		if f.ends_with(".tscn"):
			scenes.append("res://scenes/jobs/" + f)
	var ok := scenes.size() >= 10
	for path in scenes:
		var s: Node = load(path).instantiate()
		var w := s.get_node_or_null("FlightWatcher") as FlightWatcher
		var runner := s.get_node_or_null("JobRunner") as JobRunner
		# A job watches its runner's drone (a fleet job's lead); the sandbox its own.
		var watching: bool = w != null and (w.runner == runner if runner else w.drone == s.get_node("Drone"))
		if not watching:
			print("        %s: no watcher on the player's drone" % path)
		ok = ok and watching
		s.free()
	return ok
