extends RefCounted
# Story 30.6: Shiva's vow of letting go flies the job with the next act's
# assists already off, through the assist settings, for that job only; never
# on an Act 5 job and never turning an assist on. Krishna's vow of guiding is
# kept when a fleet job completes with no drop-in. Pay and results are as with
# the vow of keeping (30.5).

const Sim = preload("res://tests/sim.gd")
const Results = preload("res://scripts/ui/results.gd")
const LETTING_GO := "res://data/vows/letting_go.tres"
const GUIDING := "res://data/vows/guiding.tres"
const DELIVERY := "res://scenes/jobs/sample_delivery.tscn"
const FLEET_JOBS := ["res://data/jobs/fleet_race.tres", "res://data/jobs/fleet_inspection.tres"]
const FLEET_SCENE := "res://scenes/jobs/fleet_race.tscn"
const ACTS := ["res://data/assists/act1.tres", "res://data/assists/act2.tres", "res://data/assists/act3.tres",
	"res://data/assists/act4.tres", "res://data/assists/act5.tres"]
## Words a broken vow's line must never carry (as in test_vows.gd).
const SCOLDING := ["fail", "broke", "shame", "should", "sorry", "disappoint", "sin", "punish", "lost", "!"]
## The drone's stats that make the flight model; a vow changes none of them.
const STATS := ["mass", "drag", "angular_drag", "max_thrust", "arm_length", "yaw_torque_per_thrust", "battery_flight_time"]

func _letting_go() -> Vow:
	return load(LETTING_GO)

func _guiding() -> Vow:
	return load(GUIDING)

func _scene(path: String) -> Node:
	var s: Node = load(path).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	Sim.add(s)
	return s

## Each assist on the drone, by id, and the stats of its flight model.
func _assists(d: Drone) -> Dictionary:
	var out := {}
	for a in d.assists.assists():
		out[a.assist_id] = a.enabled
	return out

func _stats(d: Drone) -> Array:
	var out := []
	for p in STATS:
		out.append(d.get(p))
	return out

## Press launch as the player does and confirm the dialog with `vow` made.
func _launch_with(runner: JobRunner, vow: Vow) -> bool:
	runner.request_launch()
	await Sim.process_frames(1)
	var d := runner.launch_dialog
	if d == null or not d.visible:
		return false
	for i in d.vows.size():
		if d.vows[i] == vow:
			d.boxes[i].button_pressed = true
	d.hide()
	d.confirmed.emit()
	while runner.state == JobRunner.State.COUNTDOWN:
		await Sim.physics_frames(1)
	return runner.state == JobRunner.State.LIVE and runner.vow == vow

func test_the_jobs_offer_the_two_vows() -> bool:
	var shiva := _letting_go()
	var krishna := _guiding()
	var four: DeityList = load("res://data/deities/deities.tres")
	var ok: bool = shiva.deity == four.by_id(&"shiva") and shiva.kind == &"letting_go" and shiva.text != "" \
		and krishna.deity == four.by_id(&"krishna") and krishna.kind == &"guiding" and krishna.text != "" \
		and shiva.title() == "The vow of letting go" and krishna.title() == "The vow of guiding"
	ok = ok and shiva in (load("res://data/jobs/sample_delivery.tres") as Job).vows
	for p in FLEET_JOBS:
		ok = ok and krishna in (load(p) as Job).vows
	# Guiding only on fleet jobs; letting go never on an Act 5 job.
	for f in DirAccess.get_files_at("res://data/jobs"):
		var j = load("res://data/jobs/" + f) if f.ends_with(".tres") else null
		if j is Job and j.required_assists:
			if krishna in j.vows:
				ok = ok and not j.required_assists.single_drone_view
			if shiva in j.vows:
				ok = ok and j.required_assists.single_drone_view and shiva.offered_with(j.required_assists)
	return ok

## Story 35.1: from the mission set, the first act preset that takes anything
## away is Act 3's, which has brake and heading hold off.
func test_shiva_turns_brake_off_for_the_job_only() -> bool:
	var s := _scene(DELIVERY)
	await Sim.process_frames(2)
	var runner: JobRunner = s.get_node("JobRunner")
	var d := runner.drone
	var before := _assists(d)
	var stats := _stats(d)
	var count := d.assists.assists().size()
	var ok: bool = Career.act() == 1 and before.get(&"brake", false) and runner.state == JobRunner.State.BRIEFING \
		and _letting_go() in runner.offered_vows()
	ok = ok and await _launch_with(runner, _letting_go())
	var during := _assists(d)
	# Brake off; every other assist, the assist count and the flight model as they were.
	ok = ok and not during[&"brake"] and d.assists.assists().size() == count and _stats(d) == stats
	for id in before:
		if id != &"brake":
			ok = ok and during[id] == before[id]
	runner.complete()
	ok = ok and runner.result.vow == _letting_go() and runner.result.vow_kept
	# The next flight of the job, with no vow made, has it back on.
	runner.begin()
	ok = ok and _assists(d) == before and runner.vow == null
	s.free()
	# And so does a fresh load of the job.
	s = _scene(DELIVERY)
	await Sim.process_frames(2)
	ok = ok and _assists((s.get_node("JobRunner") as JobRunner).drone) == before
	s.free()
	if not ok:
		print("        before %s during %s" % [before, during])
	return ok

func test_shiva_takes_only_the_next_act_and_never_turns_one_on() -> bool:
	var shiva := _letting_go()
	var ok := true
	var stacks: Array[AssistStack] = []
	for p in ACTS:
		stacks.append(load(p))
	for i in stacks.size():
		var s := stacks[i]
		var vowed := shiva.stack_for(s)
		# Never an assist on that the stack had off.
		for id in AssistStack.IDS:
			ok = ok and (s.is_on(id) or not vowed.is_on(id))
		if i < 3:
			# Acts 1 to 3: exactly what the next act removes comes off.
			ok = ok and shiva.offered_with(s) and s.removed_by(vowed) == s.removed_by(stacks[i + 1])
		else:
			# Act 4's next step is the fleet layer, Act 5 has none: not offered, nothing changed.
			ok = ok and not shiva.offered_with(s) and s.removed_by(vowed).is_empty()
	# With every assist off in the settings there is nothing left to let go.
	ok = ok and not shiva.offered_with(stacks[0].all_off())
	return ok

func test_shiva_is_not_offered_once_the_career_is_past_it() -> bool:
	# An Act 4 career flying an Act 1 job flies Act 4's assists; letting go would
	# reach the fleet layer, so the vow is not offered and launch goes straight on.
	var job: Job = (load("res://data/jobs/sample_delivery.tres") as Job).duplicate()
	job.required_assists = load(ACTS[3])
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	runner.results_scene = null
	runner.back_scene = ""
	runner.pays_out = false
	runner.begin()
	var ok: bool = runner.offered_vows().is_empty()
	runner.choose_vow(_letting_go())
	ok = ok and runner.vow == null
	runner.request_launch()
	ok = ok and runner.launch_dialog == null and runner.state == JobRunner.State.COUNTDOWN
	root.free()
	return ok

## A fleet job flown live with the vow of guiding; `drop` drops into a drone
## and back out once before it completes.
func _fleet(drop: bool) -> JobResult:
	var s := _scene(FLEET_SCENE)
	await Sim.process_frames(2)
	var runner: JobRunner = s.get_node("JobRunner")
	var view: CommandView = s.get_node("CommandView")
	if not await _launch_with(runner, _guiding()):
		s.free()
		return null
	if drop:
		view.drop_in()
		await Sim.physics_frames(2)
		view.leave()
	await Sim.physics_frames(2)
	runner.complete()
	var r := runner.result
	s.free()
	return r

func test_krishna_kept_from_the_command_layer() -> bool:
	var r := await _fleet(false)
	return r != null and r.completed and r.vow == _guiding() and r.vow_kept \
		and Results.vow_text(r) == "Vow kept: the vow of guiding."

func test_krishna_not_kept_after_a_drop_in() -> bool:
	var r := await _fleet(true)
	return r != null and r.completed and r.vow == _guiding() and not r.vow_kept \
		and Results.vow_text(r) == "Vow not kept: the vow of guiding."

## A fresh career, so two runs start from the same state.
func _fresh() -> void:
	for section in ["roster", "career", "flags", "reputation", "upgrades", "hangar", "vows"]:
		SaveGame.write_section(section, {})
	SaveGame.load_all(Sim.tree())

## One paying job with `offered` on it, flown to completion with `vow` made or none.
func _paid(offered: Vow, vow: Vow, assists: AssistStack) -> Array:
	var job := Job.new()
	job.id = &"vow_test"
	job.pay = 500
	job.faction = &"city"
	job.required_assists = assists
	job.vows = [offered]
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	runner.results_scene = null
	runner.back_scene = ""
	runner.begin()
	var wallet := Wallet.balance
	await _launch_with(runner, vow)
	runner.complete()
	var r := runner.result
	root.free()
	var unlocks := []
	for u in r.unlocks:
		unlocks.append(u.name)
	return [[r.pay, r.reputation_change, r.letter, r.score, r.bonuses, unlocks, r.completed,
		Wallet.balance - wallet, Reputation.of(&"city")], r]

func test_pay_and_results_match_with_and_without_either_vow() -> bool:
	var ok := true
	for v in [_letting_go(), _guiding()]:
		var assists: AssistStack = load(ACTS[0]) if v.kind == &"letting_go" else load(ACTS[4])
		_fresh()
		var plain: Array = await _paid(v, null, assists)
		_fresh()
		var vowed: Array = await _paid(v, v, assists)
		var r: JobResult = vowed[1]
		var line := Results.vow_text(r)
		var same: bool = plain[0] == vowed[0] and (plain[1] as JobResult).vow == null and r.vow == v and r.vow_kept \
			and Vows.kept(v.deity.id) == 1 and line == "Vow kept: %s." % v.title().to_lower()
		# The not-kept line is as quiet as 30.5's.
		r.vow_kept = false
		for word in SCOLDING:
			same = same and not Results.vow_text(r).to_lower().replace("not kept", "").contains(word)
		if not same:
			print("        %s: %s vs %s" % [v.kind, plain[0], vowed[0]])
		ok = ok and same
	_fresh()
	return ok
