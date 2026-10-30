extends RefCounted
# Story 27.4: parts with trade-offs. Frames, props and batteries step the
# drone's exported stats through Garage.apply, like upgrades: each one trades,
# none touches an assist, the defaults change nothing, every job still finishes
# with every frame, and a part only reaches its own slot's drone.

const Sim = preload("res://tests/sim.gd")
const ACT1 := preload("res://data/assists/act1.tres")
## The existing job suites, rerun with each frame fitted to the player's drone
## (job scenes call Garage.apply). Not all of them fly: some place the drone
## where an objective wants it, so the autopilot route below and the Lattice's
## trench run (flown on an autopilot through the shell) carry the flying. The
## fleet and AI racer suites fly their own drones beside the player's.
const RUNS := ["test_race_objectives.gd", "test_test_path.gd", "test_common_objectives.gd",
	"test_hold_station.gd", "test_rescue.gd", "test_demolition.gd", "test_job_runner.gd",
	"test_perk_jobs.gd", "test_ai_racers.gd", "test_fleet_race.gd", "test_fleet_inspection.gd",
	"test_lattice_power_down.gd", "test_lattice_trench.gd", "test_lattice_override.gd",
	"test_lattice_reclaim.gd"]

## The drone of `slot` with the garage applied, as its stats.
func _stats(slot := 0) -> Dictionary:
	var d: Drone = Sim.drone(Sim.intent())
	Garage.apply(d, slot)
	var out := {}
	for s in Part.STATS:
		out[s] = d.get(s)
	d.free()
	return out

## The stats of a drone straight from the scene, plus the pilot's edge.
func _stock() -> Dictionary:
	var d: Drone = Sim.DRONE.instantiate()
	var out := {}
	for s in Part.STATS:
		out[s] = d.get(s)
	d.free()
	for s in PlayerProfile.pilot().edge.stats:
		out[s.stat] += s.step
	return out

func _non_default() -> Array[Part]:
	var out: Array[Part] = []
	for p in Hangar.catalog.parts:
		if not p in Hangar.catalog.default_parts:
			out.append(p)
	return out

func _frames() -> Array[Part]:
	return _non_default().filter(func(p): return p.kind == &"frame")

func test_every_part_trades_one_strength_for_another() -> bool:
	var ok := true
	var kinds := {}
	for p in _non_default():
		var problems := p.validate()
		if not problems.is_empty():
			print("        ", problems)
		ok = ok and problems.is_empty() and not p.better().is_empty() and not p.worse().is_empty()
		kinds[p.kind] = kinds.get(p.kind, 0) + 1
	for p in Hangar.catalog.default_parts:
		ok = ok and p.validate(true).is_empty()
	# Three frames, three props, and two batteries beside the standard one.
	ok = ok and kinds == {&"frame": 3, &"props": 3, &"battery": 2} \
		and Hangar.default_part(&"battery").name == "Standard battery"
	for id in [&"light_racer", &"heavy_hauler", &"freestyle", &"grip_props", &"speed_props",
			&"quiet_props", &"long_battery", &"light_battery"]:
		ok = ok and Hangar.part(id) != null
	# A frame changes the look: its hull shape, and the arms where it steps them.
	for p in _frames():
		ok = ok and p.hull != Vector3.ONE
	# The racer is light and twitchy but short on battery; the hauler heavy, slow
	# to turn, and stronger; the freestyle quick to yaw.
	var racer := Hangar.part(&"light_racer")
	var hauler := Hangar.part(&"heavy_hauler")
	ok = ok and &"mass" in racer.better() and &"battery_flight_time" in racer.worse() \
		and &"angular_drag" in hauler.worse() and &"mass" in hauler.worse() \
		and &"yaw_torque_per_thrust" in Hangar.part(&"freestyle").better()
	return ok

func test_default_parts_leave_every_stat_as_it_is() -> bool:
	var ok := _stats() == _stock()
	for kind in Part.KINDS:
		ok = ok and Hangar.part_id(0, kind) == Hangar.default_part(kind).id
	var d: Drone = Sim.drone(Sim.intent())
	Garage.apply(d)
	var look: DroneLook = d.get_node("Look")
	ok = ok and look.hull == Vector3.ONE and d.mass == 1.0 and d.arm_length == 0.15
	d.free()
	return ok

func test_each_part_steps_its_stats_and_the_frame_its_look() -> bool:
	var stock := _stock()
	var ok := true
	for p in _non_default():
		Hangar.fitted.clear()
		ok = ok and Hangar.fit(0, p.id)
		var d: Drone = Sim.drone(Sim.intent())
		Garage.apply(d)
		for s in Part.STATS:
			var want: float = stock[s]
			for step in p.stats:
				want += step.step if step.stat == s else 0.0
			ok = ok and is_equal_approx(d.get(s), want)
		var look: DroneLook = d.get_node("Look")
		ok = ok and look.hull == (p.hull if p.kind == &"frame" else Vector3.ONE)
		# The arms reach the motors at the drone's arm length.
		var props: Array = look._props
		ok = ok and props[3].position.is_equal_approx(Drone.motor_offset(3, d.arm_length) + Vector3(0, 0.036, 0))
		d.free()
	return ok

## Every assist's id, on or off, and its numbers, for one drone.
func _assists(d: Drone) -> Array:
	var out := []
	for a in d.assists.assists():
		var row := [a.assist_id, a.enabled]
		for prop in a.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.type in [TYPE_FLOAT, TYPE_INT, TYPE_BOOL]:
				row.append([prop.name, a.get(prop.name)])
		out.append(row)
	return out

func test_no_part_adds_or_removes_an_assist() -> bool:
	var plain: Drone = Sim.drone(Sim.intent(), Vector3(0, 20, 0), ACT1)
	Garage.apply(plain)
	var want := _assists(plain)
	plain.free()
	var ok := want.size() == 6
	for p in _non_default():
		Hangar.fitted.clear()
		Hangar.fit(0, p.id)
		var d: Drone = Sim.drone(Sim.intent(), Vector3(0, 20, 0), ACT1)
		Garage.apply(d)
		ok = ok and _assists(d) == want
		d.free()
	return ok

func test_parts_apply_to_their_slot_only() -> bool:
	var stock := _stats(0)
	Hangar.fit(2, &"heavy_hauler")
	Hangar.fit(2, &"long_battery")
	var ok := _stats(0) == stock and _stats(1) == stock and _stats(2) != stock \
		and is_equal_approx(_stats(2)[&"mass"], stock[&"mass"] + 0.45)
	Hangar.fit(0, &"light_racer")
	ok = ok and _stats(0)[&"mass"] < stock[&"mass"] and _stats(1) == stock
	# The look follows the slot's frame too.
	var d: Drone = Sim.drone(Sim.intent())
	Garage.apply(d, 2)
	ok = ok and d.get_node("Look").hull == Hangar.part(&"heavy_hauler").hull
	d.free()
	return ok

## Flies the autopilot's five-waypoint route (Story 6.1) on a drone set up as
## the player's; true if it reaches every point and holds on the last.
func _flies_the_route() -> bool:
	var d: Drone = Sim.DRONE.instantiate()
	var pilot := Autopilot.new()
	pilot.name = "Autopilot"
	d.add_child(pilot)
	d.intent_source = pilot
	Sim.add(d)
	d.global_position = Vector3(0, 20, 0)
	Garage.apply(d)
	var points := PackedVector3Array([Vector3(12, 22, 0), Vector3(12, 26, -14), Vector3(-6, 24, -20),
		Vector3(-14, 18, -4), Vector3(-2, 21, 8)])
	pilot.go_to(points)
	var frames := 0
	while not pilot.done() and frames < 60 * 90:
		await Sim.physics_frames(1)
		frames += 1
	var drift := 0.0
	for k in 120:
		await Sim.physics_frames(1)
		drift = maxf(drift, d.global_position.distance_to(points[4]))
	var ok := pilot.done() and drift < 2.0
	d.free()
	return ok

## As the test runner starts each test, but keeping the hangar.
func _fresh() -> void:
	for section in ["roster", "career", "flags", "reputation", "upgrades", "profile"]:
		SaveGame.write_section(section, {})
	for autoload in ["Roster", "Career", "Reputation", "Garage"]:
		var node := Sim.tree().root.get_node_or_null(autoload)
		if node:
			node.load_saved()

func test_every_job_finishes_with_every_frame() -> bool:
	var ok := true
	for frame in _frames():
		_fresh()
		Hangar.fitted.clear()
		Hangar.fit(0, frame.id)
		var flown: bool = await _flies_the_route()
		if not flown:
			print("        %s: the autopilot route did not finish" % frame.id)
		ok = ok and flown and _stats() != _stock()
		for file in RUNS:
			var suite = load("res://tests/" + file).new()
			for m in suite.get_method_list():
				if not m.name.begins_with("test_"):
					continue
				_fresh()
				var passed = await suite.call(m.name)
				if passed == false:
					print("        %s: %s::%s failed" % [frame.id, file, m.name])
					ok = false
			# The run kept the frame on.
			ok = ok and Hangar.part_id(0, &"frame") == frame.id
	return ok
