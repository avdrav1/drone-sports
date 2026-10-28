extends RefCounted
# Story 16.7: Act 5, call and response. A lead voice sings the call and a
# choir answers, baked at 3, 10 and 50 voices; with that many drones under
# command the matching choir is the loudest, dropping into a drone raises the
# lead, and Act 5 (a fleet job) plays act_5.

const Sim = preload("res://tests/sim.gd")
const ACT_5 := "res://data/music/act_5.tres"
const VIEW := preload("res://scenes/fleet/command_view.tscn")
const RIG := preload("res://scenes/camera/camera_rig.tscn")
const CHOIRS := {3: &"choir_3", 10: &"choir_10", 50: &"choir_50"}

func _stop() -> void:
	Music.play(null, 0.0)
	Music.clear_log()

## A command view over `n` frozen fleet drones, with a camera rig.
func _fleet(n: int) -> CommandView:
	var root: Node3D = Sim.add(Node3D.new())
	var drones: Array[Drone] = []
	for i in n:
		drones.append(_drone(root, i))
	var rig: CameraRig = RIG.instantiate()
	root.add_child(rig)
	var view: CommandView = VIEW.instantiate()
	view.drones = drones
	view.camera_rig = rig
	root.add_child(view)
	return view

func _drone(root: Node, i: int) -> Drone:
	var d: Drone = Sim.DRONE.instantiate()
	d.name = "Fleet%d" % (i + 1)
	var auto := Autopilot.new()
	d.add_child(auto)
	d.intent_source = auto
	d.freeze = true
	root.add_child(d)
	d.global_position = Vector3((i % 10) * 4, 10, (i / 10) * 4)
	return d

## The choir stem at the highest level, and every other choir below it.
func _loudest_choir() -> StringName:
	var best: StringName = &""
	for id in CHOIRS.values():
		if best == &"" or Music.level(id) > Music.level(best):
			best = id
	for id in CHOIRS.values():
		if id != best and Music.level(id) >= Music.level(best):
			return &""
	return best

func test_act_5_is_call_and_response() -> bool:
	var sc: Score = load(ACT_5)
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/music/manifest.json"))
	var listed: Dictionary = m.scores.get("act_5", {})
	var ok: bool = sc.id == &"act_5" and sc.bars == 8 and sc.find(MusicDirector.LEAD) != null \
		and listed.get("plays", {}).get(String(MusicDirector.LEAD), "") == "voice" \
		and listed.get("choirs", []).map(func(c): return int(c)) == [3, 10, 50]
	for size in CHOIRS:
		ok = ok and sc.find(CHOIRS[size]) != null and listed.plays.get(String(CHOIRS[size]), "") == "voice" \
			and MusicDirector.CHOIRS.get(size) == CHOIRS[size]
	return ok

func test_act_5_plays_act_5() -> bool:
	_stop()
	var ok: bool = MusicDirector.score_for(5).resource_path == ACT_5
	var job := Job.new()
	job.required_assists = load("res://data/assists/act5.tres")
	job.countdown = 0.2
	ok = ok and MusicDirector.act_for(job) == 5
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	runner.results_scene = null
	runner.begin()
	ok = ok and Music.score != null and Music.score.id == &"act_5" and MusicDirector.mix == &"briefing" \
		and Music.log.any(func(e): return e.event == "play" and e.score == &"act_5")
	root.free()
	# The fleet jobs fly with Act 5's assists.
	for path in ["res://data/jobs/fleet_race.tres", "res://data/jobs/fleet_inspection.tres"]:
		ok = ok and MusicDirector.act_for(load(path)) == 5
	_stop()
	return ok

func test_the_matching_choir_is_loudest() -> bool:
	_stop()
	MusicDirector.play_score(load(ACT_5), &"live")
	var view := _fleet(3)
	var ok := MusicDirector.fleet_size() == 3 and _loudest_choir() == &"choir_3" \
		and is_equal_approx(Music.level(&"choir_3"), Music.score.find(&"choir_3").level_db)
	var root := view.get_parent()
	for i in range(3, 10):
		view.add(_drone(root, i))
	ok = ok and MusicDirector.fleet_size() == 10 and _loudest_choir() == &"choir_10"
	for i in range(10, 50):
		view.add(_drone(root, i))
	ok = ok and MusicDirector.fleet_size() == 50 and _loudest_choir() == &"choir_50"
	# Losing drones thins it again.
	for i in 45:
		view.remove(view.drones.back())
	ok = ok and _loudest_choir() == &"choir_3"
	ok = ok and MusicDirector.choir_for(0) == &"choir_3" and MusicDirector.choir_for(20) == &"choir_10" \
		and MusicDirector.choir_for(30) == &"choir_50"
	root.free()
	_stop()
	return ok

func test_dropping_into_a_drone_raises_the_lead() -> bool:
	_stop()
	MusicDirector.play_score(load(ACT_5), &"live")
	var view := _fleet(3)
	var base: float = Music.score.find(MusicDirector.LEAD).level_db
	var ok := is_equal_approx(Music.level(MusicDirector.LEAD), base)
	view.drop_in()
	ok = ok and view.flown != null and Music.level(MusicDirector.LEAD) > base \
		and is_equal_approx(Music.level(MusicDirector.LEAD), base + MusicDirector.LEAD_FORWARD_DB) \
		and Music.log.back().event == "level" and Music.log.back().stem == MusicDirector.LEAD
	# The choir still follows the fleet while flying.
	ok = ok and _loudest_choir() == &"choir_3"
	view.leave()
	ok = ok and is_equal_approx(Music.level(MusicDirector.LEAD), base)
	view.get_parent().free()
	_stop()
	return ok
