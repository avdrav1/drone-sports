extends RefCounted
# Story 18.7: drone faces. A crew-flown drone wears its pilot's face on an LED
# panel driven by CharacterPortrait.pose(); it reacts to its own flight events
# and changes nothing about how the drone flies.

const Sim = preload("res://tests/sim.gd")
const FLEET := "res://scenes/jobs/fleet_inspection.tscn"
const RACE := "res://scenes/jobs/fleet_race.tscn"
const PROBE := "res://tests/drone_face_probe.gd"
const PROBE_TIMEOUT_MS := 60000

func _job(path: String) -> Node:
	var s: Node = load(path).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	runner.auto_begin = false
	Sim.add(s)
	return s

func _still_drone() -> Drone:
	var d := Sim.drone(Intent.new())
	d.freeze = true
	return d

func test_crew_flown_drones_wear_their_pilots_face() -> bool:
	var s := _job(FLEET)
	var view: CommandView = s.get_node("CommandView")
	var crew: FleetCrew = s.get_node("FleetCrew")
	await Sim.process_frames(2)
	var ok := not view.drones.is_empty()
	for d in view.drones:
		var face := DroneFace.of(d)
		ok = ok and face != null and face.visible and face.character == Roster.character(crew.pilot_of(d))
	# A drone handed back with its pilot (the Lattice's returned drones) wears
	# theirs; one added without a pilot wears none.
	var home: Drone = Sim.DRONE.instantiate()
	var freed: Drone = Sim.DRONE.instantiate()
	s.add_child(home)
	s.add_child(freed)
	var nala: Character = Roster.character(&"nala")
	view.add(home, nala)
	view.add(freed)
	ok = ok and DroneFace.of(home) != null and DroneFace.of(home).character == nala and DroneFace.of(freed) == null
	s.free()
	return ok

func test_player_and_unpiloted_drones_show_none() -> bool:
	var d := _still_drone()
	var ok := DroneFace.of(d) == null and d.find_children("*", "DroneFace", true, false).is_empty()
	d.free()
	# A single-drone job's runner drone is the player's own: no face.
	var job := _job("res://scenes/jobs/sample_delivery.tscn")
	await Sim.process_frames(2)
	ok = ok and (job.get_node("JobRunner") as JobRunner).drone != null and job.find_children("*", "DroneFace", true, false).is_empty()
	job.free()
	return ok

func test_the_dead_never_appear_on_a_drone() -> bool:
	var d := _still_drone()
	var face := DroneFace.wear(d, Roster.character(&"sanjaya"))
	face.advance(0.1)
	var ok := face.visible
	Roster.kill(&"sanjaya")
	face.advance(0.1)
	ok = ok and not face.visible and not face.react(&"crash")
	var other := _still_drone()
	ok = ok and DroneFace.wear(other, Roster.character(&"sanjaya")) == null
	d.free()
	other.free()
	return ok

func test_panel_pose_matches_portrait_pose() -> bool:
	var d := _still_drone()
	var c: Character = Roster.character(&"arjuna")
	var face := DroneFace.wear(d, c)
	var ok := true
	for e in CharacterPortrait.EXPRESSIONS:
		face.hold(e, INF)
		# Past the shocked eye pop, at times with and without a blink.
		for t in [1.0, 2.5, 4.2, 7.9]:
			face.time = face.time + t
			face.advance(0.0)
			var want := CharacterPortrait.pose(e, face.time, false, hash(c.id))
			var got := face.current_pose()
			var mat := face.material_override as ShaderMaterial
			for k in want:
				var same: bool = is_equal_approx(float(got[k]), float(want[k])) if not want[k] is Vector2 else (got[k] as Vector2).is_equal_approx(want[k])
				var drawn = mat.get_shader_parameter(k)
				var shown: bool = is_equal_approx(float(drawn), float(want[k])) if not want[k] is Vector2 else (drawn as Vector2).is_equal_approx(want[k])
				if not (same and shown):
					print("        %s at %.2f: %s is %s, drawn %s, pose() %s" % [e, face.time, k, got[k], drawn, want[k]])
					ok = false
	d.free()
	return ok

func test_flight_events_change_the_face_then_it_rests() -> bool:
	var d := _still_drone()
	var face := DroneFace.wear(d, Roster.character(&"drona"))
	await Sim.process_frames(2)
	var ok := face.watcher != null and face.watcher.watched() == d and face.expression == DroneFace.REST
	for event in DroneFace.REACTIONS:
		var r: Array = DroneFace.REACTIONS[event]
		face.watcher.flight_event.emit(event)
		var changed: bool = face.expression == r[0] and face.expression != DroneFace.REST
		face.advance(float(r[1]) * 0.5)
		var held: bool = face.expression == r[0]
		face.advance(float(r[1]) * 0.5 + 0.05)
		var rested: bool = face.expression == DroneFace.REST and not face.dizzy
		if not (changed and held and rested):
			print("        %s: changed %s, held %s, rested %s" % [event, changed, held, rested])
			ok = false
	# Unmapped events leave the face alone.
	face.watcher.flight_event.emit(&"weather_change")
	ok = ok and face.expression == DroneFace.REST
	d.free()
	return ok

func test_a_relay_gate_makes_the_pilot_happy() -> bool:
	var s := _job(RACE)
	var relay: Relay = s.get_node("Relay")
	await Sim.process_frames(2)
	var d := relay.drones[0]
	relay.course.gate_passed.emit(d, 1)
	var ok := DroneFace.of(d) != null and DroneFace.of(d).expression == DroneFace.REACTIONS[&"gate"][0]
	s.free()
	return ok

## Mass, shapes and every exported flight value, as one comparable list.
func _physics_of(d: Drone) -> Array:
	var out: Array = [d.mass, d.inertia, d.center_of_mass, d.collision_layer, d.collision_mask]
	for sh in d.find_children("*", "CollisionShape3D", true, false):
		out.append([sh.transform, (sh.shape as BoxShape3D).size if sh.shape is BoxShape3D else sh.shape])
	for p in d.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_STORAGE and not d.get(p.name) is Object:
			out.append([p.name, d.get(p.name)])
	return out

func test_a_face_changes_nothing_about_flight() -> bool:
	var plain := Sim.drone(Sim.intent(0.6, 0.2, 0.1), Vector3(-20, 20, 0))
	var faced := Sim.drone(Sim.intent(0.6, 0.2, 0.1), Vector3(20, 20, 0))
	var before := _physics_of(faced)
	DroneFace.wear(faced, Roster.character(&"arjuna"))
	var ok := _physics_of(faced) == before and _physics_of(faced) == _physics_of(plain)
	await Sim.physics_frames(90)
	# Flown the same, they end the same, a face or not.
	var moved_plain := plain.global_position - Vector3(-20, 20, 0)
	var moved_faced := faced.global_position - Vector3(20, 20, 0)
	ok = ok and moved_plain.is_equal_approx(moved_faced) and plain.linear_velocity.is_equal_approx(faced.linear_velocity)
	ok = ok and _physics_of(faced) == _physics_of(plain)
	if not ok:
		print("        moved %s vs %s\n        %s\n        %s" % [moved_plain, moved_faced, _physics_of(plain), _physics_of(faced)])
	plain.free()
	faced.free()
	return ok

func test_the_panel_compiles_and_draws_under_gl_compatibility() -> bool:
	var out := ProjectSettings.globalize_path("user://face_probe_%d.json" % OS.get_process_id())
	DirAccess.remove_absolute(out)
	var args := ["--path", ProjectSettings.globalize_path("res://"), "--rendering-method", "gl_compatibility",
		"--rendering-driver", "opengl3", "--resolution", "320x180", "-s", PROBE, "--", out]
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		print("        could not start the render probe")
		return false
	var start := Time.get_ticks_msec()
	while OS.is_process_running(pid) and Time.get_ticks_msec() - start < PROBE_TIMEOUT_MS:
		await Sim.tree().process_frame
	if OS.is_process_running(pid):
		OS.kill(pid)
	var text := FileAccess.get_file_as_string(out)
	DirAccess.remove_absolute(out)
	var r = JSON.parse_string(text)
	if not r is Dictionary:
		print("        the render probe wrote nothing (needs a display and OpenGL 3.3)")
		return false
	# The pilot's colour fills a good part of the frame, and nothing logged an error.
	var ok: bool = r.errors.is_empty() and r.body_pixels > r.pixels * 0.05
	if not ok:
		print("        %s" % r)
	return ok
