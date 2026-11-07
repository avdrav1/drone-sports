extends RefCounted
# Story 35.1: the same assists on every mission. Every board job and the
# Lattice fly the mission set (fleet jobs with the single-drone view off),
# whatever act the career is in; a drone dropped into in command view flies
# the mission's assists; the expert setting still turns every assist off.

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

func test_the_mission_set_is_act_3_with_brake_on() -> bool:
	var on := {&"collision_guard": false, &"brake": true, &"altitude_hold": false, &"auto_level": false,
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
