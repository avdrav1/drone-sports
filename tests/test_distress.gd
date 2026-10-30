extends RefCounted
# Story 18.10: distress and signal lost. A crew drone in trouble shows its
# pilot's distress with a repeating alarm until the trouble ends; a downed drone
# fills the portrait with static until it flies again. Never for the player's
# drone or the dead, and nothing about flight changes.

const Sim = preload("res://tests/sim.gd")
const FLEET := "res://scenes/jobs/fleet_inspection.tscn"

## A frozen drone in the air with `id`'s portrait watching it for distress.
func _setup(id: StringName) -> Array:
	var d := Sim.drone(Intent.new())
	d.freeze = true
	var face := CharacterPortrait.new()
	face.character = Roster.character(id)
	face.size = Vector2(64, 64)
	Sim.add(face)
	var cd := CrewDistress.watch(face, d)
	return [d, face, cd]

func _free(parts: Array) -> void:
	for n in parts.slice(0, 2):
		if is_instance_valid(n):
			n.free()

func test_each_trouble_event_shows_distress_and_alarm_until_it_ends() -> bool:
	var ok := true
	for event in CrewDistress.TROUBLE:
		var parts := _setup(&"drona")
		var face: CharacterPortrait = parts[1]
		var cd: CrewDistress = parts[2]
		await Sim.process_frames(1)
		Sfx.clear_log()
		cd.watcher.flight_event.emit(event)
		cd.advance(0.01)
		var started: bool = face.expression == CharacterPortrait.DISTRESS and Sfx.count(CrewDistress.ALARM) == 1 and cd.alarm_on()
		# It repeats while the trouble lasts.
		cd.advance(CrewDistress.ALARM_GAP + 0.01)
		var repeats: bool = Sfx.count(CrewDistress.ALARM) == 2
		if event == &"crash":
			# A crash is over once the drone is back up: the reset brings it back.
			cd.watcher.flight_event.emit(&"reset")
		cd.advance(float(CrewDistress.TROUBLE[event]))
		var heard := Sfx.count(CrewDistress.ALARM)
		cd.advance(CrewDistress.ALARM_GAP * 3.0)
		var stopped: bool = not cd.alarm_on() and face.expression == CrewDistress.REST and Sfx.count(CrewDistress.ALARM) == heard
		if not (started and repeats and stopped):
			print("        %s: started %s, repeats %s, stopped %s" % [event, started, repeats, stopped])
			ok = false
		_free(parts)
	# Events that are not trouble leave the face alone.
	var parts := _setup(&"drona")
	var cd2: CrewDistress = parts[2]
	await Sim.process_frames(1)
	for e in [&"takeoff", &"low_pass", &"top_speed", &"long_hover", &"weather_change"]:
		cd2.watcher.flight_event.emit(e)
	cd2.advance(0.01)
	ok = ok and not cd2.troubled() and (parts[1] as CharacterPortrait).expression != CharacterPortrait.DISTRESS
	_free(parts)
	return ok

func test_flight_trouble_shows_a_sweat_drop_and_a_shake() -> bool:
	var parts := _setup(&"nala")
	var face: CharacterPortrait = parts[1]
	var cd: CrewDistress = parts[2]
	await Sim.process_frames(1)
	cd.on_event(&"near_miss")
	cd.advance(0.01)
	var bubble := face.find_children("*", "EmoteBubble", false, false)[0] as EmoteBubble
	var ok := bubble.current != null and bubble.current.drawing == &"sweat"
	# The shake moves the face sideways, well inside 6% of its size.
	var xs := []
	for i in 40:
		var m := CharacterPortrait.motion(CharacterPortrait.DISTRESS, i * 0.013)
		xs.append((m.offset as Vector2).x)
		ok = ok and (m.offset as Vector2).length() <= 0.06
	ok = ok and xs.max() - xs.min() > 0.02
	# A wince: squeezed eyes, brows lifted at the inner ends, a grimace.
	var p := CharacterPortrait.pose(CharacterPortrait.DISTRESS, 0.5)
	ok = ok and float(p.squint) > 0.0 and float(p.brow_angle) < 0.0 and float(p.mouth_curve) < 0.0 and float(p.mouth_open) > 0.0
	# Squeezed, not shut (Story 26.1: measured against the open neutral eye).
	ok = ok and CharacterPortrait.eye_height(p) >= 0.6 * CharacterPortrait.eye_height(CharacterPortrait.pose(&"neutral", 0.5))
	for e in CharacterPortrait.EXPRESSIONS:
		ok = ok and CharacterPortrait.pose(e, 0.5) != p
	cd.advance(CrewDistress.TROUBLE[&"near_miss"])
	ok = ok and bubble.current == null
	_free(parts)
	return ok

func test_a_hazard_close_by_is_trouble_while_it_lasts() -> bool:
	var parts := _setup(&"sanjaya")
	var d: Drone = parts[0]
	var face: CharacterPortrait = parts[1]
	var cd: CrewDistress = parts[2]
	var zone := HazardZone.new()
	Sim.add(zone)
	zone.global_position = d.global_position + Vector3(zone.radius + CrewDistress.HAZARD_MARGIN - 0.5, 0, 0)
	await Sim.process_frames(1)
	Sfx.clear_log()
	cd.zones = [zone]
	cd.advance(0.01)
	var ok := face.expression == CharacterPortrait.DISTRESS and Sfx.count(CrewDistress.ALARM) == 1
	# A hazard is a serious moment: no sweat drop by it.
	var bubble := face.find_children("*", "EmoteBubble", false, false)[0] as EmoteBubble
	ok = ok and bubble.current == null
	zone.global_position += Vector3(50, 0, 0)
	cd.advance(0.01)
	cd.advance(CrewDistress.ALARM_GAP * 2.0)
	ok = ok and face.expression == CrewDistress.REST and not cd.alarm_on() and Sfx.count(CrewDistress.ALARM) == 1
	zone.free()
	_free(parts)
	return ok

func test_a_downed_drone_shows_static_until_it_flies_again() -> bool:
	var parts := _setup(&"arjuna")
	var d: Drone = parts[0]
	var face: CharacterPortrait = parts[1]
	var cd: CrewDistress = parts[2]
	await Sim.physics_frames(2)
	var ok := not face.shows_static()
	# Crashed and turned over: down, whatever time passes.
	d.global_basis = Basis(Vector3.FORWARD, PI)
	cd.watcher.flight_event.emit(&"crash")
	for i in 30:
		await Sim.physics_frames(1)
		cd.advance(0.1)
	ok = ok and cd.down and face.signal_lost and face.shows_static() and cd.alarm_on()
	# The static moves: frames differ.
	var same := 0
	for i in 8:
		for j in 8:
			if CharacterPortrait.static_noise(i, j, 3) == CharacterPortrait.static_noise(i, j, 4):
				same += 1
	ok = ok and same < 16
	# Upright and in the air again: the face comes back after UP_TIME.
	d.global_basis = Basis()
	await Sim.physics_frames(2)
	cd.advance(CrewDistress.UP_TIME * 0.5)
	ok = ok and face.shows_static()
	cd.advance(CrewDistress.UP_TIME * 0.6)
	ok = ok and not cd.down and not face.signal_lost and not face.shows_static()
	cd.advance(CrewDistress.TROUBLE[&"crash"])
	ok = ok and face.expression == CrewDistress.REST and not cd.alarm_on()
	# A reset also brings the signal back.
	cd.on_event(&"crash")
	ok = ok and face.shows_static()
	cd.on_event(&"reset")
	ok = ok and not face.shows_static()
	_free(parts)
	return ok

func test_no_alarm_for_the_players_drone() -> bool:
	var parts := _setup(&"nala")
	var d: Drone = parts[0]
	var cd: CrewDistress = parts[2]
	var pilot := PilotInput.new()
	d.add_child(pilot)
	d.intent_source = pilot
	await Sim.process_frames(1)
	Sfx.clear_log()
	for e in CrewDistress.TROUBLE:
		cd.on_event(e)
	for i in 10:
		cd.advance(0.3)
	var ok := not cd.alarm_on() and Sfx.count(CrewDistress.ALARM) == 0
	_free(parts)
	# A single-drone job's drone is the player's own: nothing watches it.
	var job: Node = load("res://scenes/jobs/sample_delivery.tscn").instantiate()
	var runner: JobRunner = job.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	runner.auto_begin = false
	Sim.add(job)
	await Sim.process_frames(2)
	ok = ok and job.find_children("*", "CrewDistress", true, false).is_empty()
	job.free()
	return ok

func test_the_dead_get_no_distress_static_or_alarm() -> bool:
	var parts := _setup(&"sanjaya")
	var face: CharacterPortrait = parts[1]
	var cd: CrewDistress = parts[2]
	await Sim.process_frames(1)
	cd.on_event(&"crash")
	cd.advance(0.01)
	var ok := face.shows_static()
	Roster.kill(&"sanjaya")
	Sfx.clear_log()
	cd.advance(0.01)
	ok = ok and not face.shows_static() and face.expression != CharacterPortrait.DISTRESS and not cd.alarm_on()
	for e in CrewDistress.TROUBLE:
		cd.on_event(e)
	for i in 10:
		cd.advance(0.3)
	ok = ok and Sfx.count(CrewDistress.ALARM) == 0 and not cd.troubled() and not face.shows_static()
	# Greyed (the roster's dead) never shows static even when told to.
	var grey := CharacterPortrait.new()
	grey.character = Roster.character(&"nala")
	grey.greyed = true
	grey.signal_lost = true
	ok = ok and not grey.shows_static()
	grey.free()
	_free(parts)
	return ok

func test_fleet_portraits_watch_their_drones() -> bool:
	var s: Node = load(FLEET).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	runner.auto_begin = false
	Sim.add(s)
	var view: CommandView = s.get_node("CommandView")
	await Sim.process_frames(3)
	var ok := not view.drones.is_empty()
	for d in view.drones:
		var cd := CrewDistress.of(view.portrait(d))
		# It shares the drone face's watcher instead of a second one.
		ok = ok and cd != null and cd.drone == d and cd.watcher == DroneFace.of(d).watcher
	var d0: Drone = view.drones[0]
	Sfx.clear_log()
	DroneFace.of(d0).watcher.flight_event.emit(&"battery_low")
	await Sim.process_frames(2)
	ok = ok and view.portrait(d0).expression == CharacterPortrait.DISTRESS and Sfx.count(CrewDistress.ALARM) >= 1
	s.free()
	return ok

## Mass, shapes, every exported flight value and the assists, as one list.
func _flight_of(d: Drone) -> Array:
	var out: Array = [d.mass, d.inertia, d.center_of_mass, d.collision_layer, d.collision_mask, d.assist_summary()]
	for sh in d.find_children("*", "CollisionShape3D", true, false):
		out.append([sh.transform, sh.shape])
	for p in d.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_STORAGE and not d.get(p.name) is Object:
			out.append([p.name, d.get(p.name)])
	return out

func test_flight_assists_and_grading_untouched() -> bool:
	var plain := Sim.drone(Sim.intent(0.6, 0.2, 0.1), Vector3(-20, 20, 0))
	var watched := Sim.drone(Sim.intent(0.6, 0.2, 0.1), Vector3(20, 20, 0))
	var before := _flight_of(watched)
	var face := CharacterPortrait.new()
	face.character = Roster.character(&"arjuna")
	Sim.add(face)
	var cd := CrewDistress.watch(face, watched)
	await Sim.process_frames(1)
	for e in CrewDistress.TROUBLE:
		cd.on_event(e)
	await Sim.physics_frames(90)
	var moved_plain := plain.global_position - Vector3(-20, 20, 0)
	var moved_watched := watched.global_position - Vector3(20, 20, 0)
	var ok := moved_plain.is_equal_approx(moved_watched) and plain.linear_velocity.is_equal_approx(watched.linear_velocity)
	ok = ok and _flight_of(watched) == _flight_of(plain) and _flight_of(watched).size() == before.size()
	# Nothing grades on it: it never touches a runner, a job, or a result.
	var src := FileAccess.get_file_as_string("res://scripts/fleet/crew_distress.gd")
	for word in ["JobResult", "apply_force", "apply_impulse", "apply_central", "linear_velocity =", "set_motor_thrusts", "assists.", "intent_source ="]:
		ok = ok and not word in src
	if not ok:
		print("        moved %s vs %s" % [moved_plain, moved_watched])
	face.free()
	plain.free()
	watched.free()
	return ok

func test_alarm_is_generated_on_the_key_and_licensed() -> bool:
	var bank: SoundBank = load("res://data/audio/bank.tres")
	var e := bank.find(CrewDistress.ALARM)
	var ok := e != null and not e.streams.is_empty()
	var pitches = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio/generated/pitches.json"))
	ok = ok and pitches is Dictionary and pitches.has(String(CrewDistress.ALARM))
	ok = ok and "generated/crew_alarm.wav" in FileAccess.get_file_as_string("res://data/audio/LICENSES.md")
	return ok
