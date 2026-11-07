extends RefCounted
# Story 35.1: the same assists on every mission. Every board job and the
# Lattice fly the mission set (fleet jobs with the single-drone view off),
# whatever act the career is in; a drone dropped into in command view flies
# the mission's assists; the expert setting still turns every assist off.
# Story 36.1: the set has altitude hold on. In a mission a centred stick holds
# height, upright and leaning, and full down lands quickly but not hard; the
# vow of letting go still turns it off.

const Sim = preload("res://tests/sim.gd")
const MISSION := preload("res://data/assists/mission.tres")
const FLEET := preload("res://data/assists/mission_fleet.tres")
const BOARD := "res://data/jobs/board.tres"
const TEAMS := ["", "skyline_juniors", "harbor_couriers", "cannery_row", "city_rescue_air", "halcyon_racing", "deadweight"]
const VIEW := preload("res://scenes/fleet/command_view.tscn")
const RIG := preload("res://scenes/camera/camera_rig.tscn")

func _jobs() -> Array[Job]:
	var out: Array[Job] = []
	out.assign((load(BOARD) as JobList).jobs)
	out.append((load(BossGate.DATA) as Boss).job)
	return out

func test_the_mission_set_is_act_3_with_brake_and_altitude_hold_on() -> bool:
	var on := {&"collision_guard": false, &"brake": true, &"altitude_hold": true, &"auto_level": false,
		&"horizon": true, &"speed_governor": true, &"battery_wind": true}
	var ok := MISSION.single_drone_view and not FLEET.single_drone_view
	for id in on:
		ok = ok and MISSION.get(id) == on[id] and FLEET.get(id) == on[id]
	return ok

func test_every_mission_flies_the_set_in_every_act() -> bool:
	var ok := true
	var acts := {}
	for team in TEAMS:
		Career.team_id = StringName(team)
		acts[Career.act()] = true
		for job in _jobs():
			var want: AssistStack = FLEET if job.job_type in [&"fleet", &"relay"] or job.id == &"lattice" else MISSION
			var got := JobRunner.assists_for(job)
			if got != want:
				print("        %s in act %d flies %s" % [job.id, Career.act(), got.label])
				ok = false
	Career.team_id = &""
	# Teams carry Acts 2 to 4; no career is in Act 5 (only jobs are).
	return ok and acts.size() == 4

func test_a_dropped_in_fleet_drone_flies_the_mission_set() -> bool:
	# At home (Act 1) the career's preset has collision guard and altitude hold on;
	# the dropped-in drone must fly the fleet job's set instead.
	Career.team_id = &""
	var root: Node3D = Sim.add(Node3D.new())
	var d: Drone = Sim.DRONE.instantiate()
	var auto := Autopilot.new()
	d.add_child(auto)
	d.intent_source = auto
	root.add_child(d)
	d.global_position = Vector3(0, 10, 0)
	var rig: CameraRig = RIG.instantiate()
	root.add_child(rig)
	var runner := JobRunner.new()
	runner.job = load("res://data/jobs/fleet_inspection.tres")
	runner.auto_begin = false
	root.add_child(runner)
	var view: CommandView = VIEW.instantiate()
	view.drones = [d] as Array[Drone]
	view.camera_rig = rig
	view.runner = runner
	root.add_child(view)
	await Sim.physics_frames(2)
	view.select(d)
	view.drop_in()
	var ok: bool = view.flown == d
	for id in [&"collision_guard", &"brake", &"altitude_hold", &"auto_level", &"horizon", &"speed_governor", &"battery_wind"]:
		ok = ok and d.assists.is_enabled(id) == FLEET.get(id)
	root.free()
	return ok

func test_the_expert_setting_still_turns_every_assist_off() -> bool:
	GameSettings.expert_all_assists_off = true
	var ok := true
	for job in _jobs():
		var s := GameSettings.effective_stack(JobRunner.assists_for(job))
		for id in AssistStack.IDS:
			ok = ok and not s.get(id)
	GameSettings.expert_all_assists_off = false
	return ok

const DELIVERY := "res://scenes/jobs/sample_delivery.tscn"

## The sample delivery job, live, its drone flown by a FixedSource at 10 m
## over the ground. Returns [scene, drone, ground height].
func _mission() -> Array:
	var s: Node = load(DELIVERY).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	Sim.add(s)
	await Sim.process_frames(2)
	var d := runner.drone
	var src := Sim.FixedSource.new()
	d.add_child(src)
	d.intent_source = src
	runner.launch()
	runner.state_time = runner.job.countdown
	await Sim.physics_frames(2)
	var ground := _ground(d, Vector3(0, 0, 0))
	d.reset(Transform3D(Basis(), Vector3(0, ground + 10.0, 0)))
	await Sim.physics_frames(30)
	return [s, d, ground]

func _ground(d: Drone, at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 200, at.z), Vector3(at.x, -50, at.z))
	q.exclude = [d.get_rid()]
	return d.get_world_3d().direct_space_state.intersect_ray(q).get("position", Vector3.ZERO).y

## Climb for 1 s, centre the throttle with `lean` on the sticks, let it settle
## for 1 s, then the widest height change over the next 10 s, and the lean.
func _hold(lean: Intent) -> Array:
	var m := await _mission()
	var d: Drone = m[1]
	var ok := d.assists.is_enabled(&"altitude_hold")
	d.intent_source.value = Sim.intent(0.6)
	await Sim.physics_frames(60)
	d.intent_source.value = lean
	await Sim.physics_frames(60)
	var h0 := d.global_position.y
	var spread := 0.0
	var tilt := 0.0
	for i in 600:
		await Sim.physics_frames(1)
		spread = maxf(spread, absf(d.global_position.y - h0))
		tilt += rad_to_deg(FlightControl.tilt(d)) / 600.0
	m[0].free()
	print("        height spread %.3f m over 10 s, mean lean %.1f deg" % [spread, tilt])
	return [ok, spread, tilt]

func test_a_centred_throttle_holds_height_in_a_mission() -> bool:
	var r := await _hold(Sim.intent())
	return r[0] and r[1] < 0.3

func test_a_centred_throttle_holds_height_leaning_30_degrees() -> bool:
	# Roll and yaw together: a steady 30 degree lean that circles in place.
	var r := await _hold(Sim.intent(0.0, 0.0, 0.7, 0.5))
	return r[0] and r[1] < 0.3 and absf(r[2] - 30.0) < 3.0

## Full down from 10 m: [landed after s, touchdown m/s, rest height over ground].
func _full_down() -> Array:
	var m := await _mission()
	var d: Drone = m[1]
	var ground: float = m[2]
	d.intent_source.value = Sim.intent(-1.0)
	var heights: Array[float] = []
	var speeds: Array[float] = []
	for i in 360:
		await Sim.physics_frames(1)
		heights.append(d.global_position.y)
		speeds.append(-d.linear_velocity.y)
	m[0].free()
	# At rest: the last height. Landed: the first tick within 2 cm of it.
	var rest: float = heights[-1]
	var landed := -1
	for i in heights.size():
		if heights[i] < rest + 0.02:
			landed = i
			break
	# Touchdown speed: the fastest sink over the last 15 cm before rest.
	var hit := 0.0
	for i in heights.size():
		if heights[i] < rest + 0.15 and (landed < 0 or i <= landed):
			hit = maxf(hit, speeds[i])
	return [landed / 60.0 if landed > 0 else INF, hit, rest - ground]

func test_full_down_from_10_m_lands_in_4_s_softly_for_every_pilot() -> bool:
	# A pilot's edge may climb faster (Hanuman 7 m/s); sinking stays at 4 m/s.
	var profile = SaveGame.read_section("profile", {})
	var ok := true
	for pilot in PlayerProfile.pilots():
		PlayerProfile.choose_pilot(pilot.id)
		var r := await _full_down()
		print("        %s: landed after %.2f s at %.2f m/s, rest %.2f m over ground" % [pilot.id, r[0], r[1], r[2]])
		ok = ok and r[0] < 4.0 and r[1] < 4.0 and r[2] < 0.5
	SaveGame.write_section("profile", profile)
	return ok

func test_letting_go_and_the_expert_setting_turn_altitude_hold_off() -> bool:
	var shiva: Vow = load("res://data/vows/letting_go.tres")
	var ok := MISSION.altitude_hold and shiva.offered_with(MISSION) and not shiva.stack_for(MISSION).altitude_hold
	GameSettings.expert_all_assists_off = true
	ok = ok and not GameSettings.effective_stack(MISSION).altitude_hold
	GameSettings.expert_all_assists_off = false
	return ok
