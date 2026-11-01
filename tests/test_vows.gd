extends RefCounted
# Story 30.5: the launch dialog offers a vow on jobs whose data lists one (none
# chosen by default, at most one), the runner decides it at completion, the
# save counts vows kept per thread, and the results say "Vow kept" or "Vow not
# kept" in one quiet line. A vow never moves pay, reputation, grade or unlocks.

const Sim = preload("res://tests/sim.gd")
const Results = preload("res://scripts/ui/results.gd")
const KEEPING := "res://data/vows/keeping.tres"
const CREW_JOBS := ["res://data/jobs/inspection.tres", "res://data/jobs/demolition.tres", "res://data/jobs/rescue.tres"]
const ZONE_AT := Vector3(0, 5, -30)
## Words a broken vow's line must never carry.
const SCOLDING := ["fail", "broke", "shame", "should", "sorry", "disappoint", "sin", "punish", "lost", "!"]

func _keeping() -> Vow:
	return load(KEEPING)

## A job rig with Sanjaya in the field and a zone that can strike him.
## `vows` lists what the job offers.
func _rig(vows: Array[Vow] = [], pays := false) -> Node:
	var job := Job.new()
	job.id = &"vow_test"
	job.pay = 500
	job.faction = &"city"
	job.crew_in_field = [&"sanjaya"]
	job.vows = vows
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	runner.results_scene = null
	runner.back_scene = ""
	runner.pays_out = pays
	var zone := HazardZone.new()
	zone.name = "Zone"
	zone.character = &"sanjaya"
	root.add_child(zone)
	zone.global_position = ZONE_AT
	return root

## Begin and press launch as the player does; returns the runner.
func _ask(root: Node) -> JobRunner:
	var runner: JobRunner = root.get_node("Runner")
	runner.begin()
	runner.request_launch()
	await Sim.process_frames(1)
	return runner

## Confirm the dialog with `vow` made (or none), and wait out the countdown.
func _launch_with(runner: JobRunner, vow: Vow) -> void:
	if runner.launch_dialog and runner.launch_dialog.visible:
		for i in runner.launch_dialog.vows.size():
			if runner.launch_dialog.vows[i] == vow:
				runner.launch_dialog.boxes[i].button_pressed = true
		runner.launch_dialog.hide()
		runner.launch_dialog.confirmed.emit()
	while runner.state == JobRunner.State.COUNTDOWN:
		await Sim.physics_frames(1)

func _strike(root: Node) -> bool:
	var zone: HazardZone = root.get_node("Zone")
	for i in 75:
		zone.threaten()
		await Sim.physics_frames(1)
	return zone.strike(&"timer")

## One job flown to its end: with `vow` made or none, `strikes` strikes, and
## completed or failed.
func _fly(vow: Vow, strikes: int, completes := true, pays := false) -> JobResult:
	var root := _rig([_keeping()], pays)
	var runner := await _ask(root)
	await _launch_with(runner, vow)
	for i in strikes:
		await _strike(root)
	if completes:
		runner.complete()
	else:
		runner.fail("test")
	var r := runner.result
	root.free()
	return r

func test_a_job_with_no_vows_shows_no_vow_choice() -> bool:
	var root := _rig()
	var runner := await _ask(root)
	var ok: bool = runner.launch_dialog == null and runner.state == JobRunner.State.COUNTDOWN
	root.free()
	# With injured crew the risk is asked, still with no vow to make.
	Roster.injure(&"sanjaya")
	root = _rig()
	runner = await _ask(root)
	var d := runner.launch_dialog
	ok = ok and d != null and d.visible and d.boxes.is_empty() and d.content == null \
		and d.dialog_text.contains("Sanjaya")
	d.hide()
	root.free()
	return ok

func test_the_crew_jobs_offer_the_vow_of_keeping() -> bool:
	var keeping := _keeping()
	var ok: bool = keeping.deity == (load("res://data/deities/deities.tres") as DeityList).by_id(&"vishnu") \
		and keeping.kind == &"keeping" and keeping.text != ""
	for p in CREW_JOBS:
		var j: Job = load(p)
		ok = ok and j.vows.count(keeping) == 1
	# The vow of keeping is offered only where someone is in the field.
	for p in DirAccess.get_files_at("res://data/jobs"):
		if p.ends_with(".tres"):
			var j = load("res://data/jobs/" + p)
			if j is Job and keeping in j.vows:
				ok = ok and not j.crew_in_field.is_empty()
	return ok

func test_the_dialog_offers_vows_none_chosen_and_at_most_one() -> bool:
	var other := _keeping().duplicate()
	var root := _rig([_keeping(), other])
	var runner := await _ask(root)
	var d := runner.launch_dialog
	var ok: bool = d != null and d.visible and runner.state == JobRunner.State.BRIEFING \
		and d.boxes.size() == 2 and d.chosen == null and not d.boxes[0].button_pressed and not d.boxes[1].button_pressed
	# Each vow has its thread's symbol beside it.
	for b in d.boxes:
		var symbol = b.get_parent().get_child(0)
		ok = ok and symbol is DeitySymbol and symbol.deity.id == &"vishnu"
	d.boxes[0].button_pressed = true
	d.boxes[1].button_pressed = true
	ok = ok and not d.boxes[0].button_pressed and d.chosen == other
	d.boxes[1].button_pressed = false
	ok = ok and d.chosen == null
	# Launching with none made makes none.
	await _launch_with(runner, null)
	ok = ok and runner.state == JobRunner.State.LIVE and runner.vow == null
	root.free()
	return ok

func test_kept_with_no_strike() -> bool:
	var r := await _fly(_keeping(), 0, true, true)
	return r.completed and r.vow == _keeping() and r.vow_kept and Vows.kept(&"vishnu") == 1 \
		and Results.vow_text(r) == "Vow kept: the vow of keeping."

func test_one_strike_is_not_kept() -> bool:
	var r := await _fly(_keeping(), 1, true, true)
	return r.completed and r.strikes.get(&"sanjaya", 0) == 1 and r.vow == _keeping() and not r.vow_kept \
		and Vows.kept(&"vishnu") == 0 and Results.vow_text(r) == "Vow not kept: the vow of keeping."

func test_a_failed_job_records_nothing() -> bool:
	var r := await _fly(_keeping(), 0, false, true)
	return not r.completed and r.vow == null and not r.vow_kept and Vows.kept(&"vishnu") == 0 \
		and Results.vow_text(r) == ""

func test_kept_vows_count_per_thread() -> bool:
	await _fly(_keeping(), 0, true, true)
	await _fly(_keeping(), 0, true, true)
	var all: Dictionary = SaveGame.read_section(Vows.SECTION, {})
	# A preview (no pay-out) records nothing.
	await _fly(_keeping(), 0, true, false)
	return Vows.kept(&"vishnu") == 2 and all.size() == 1 and int(all.get("vishnu", 0)) == 2 and Vows.kept(&"shiva") == 0

## A fresh career, so two runs start from the same state.
func _fresh() -> void:
	for section in ["roster", "career", "flags", "reputation", "upgrades", "hangar", "vows"]:
		SaveGame.write_section(section, {})
	SaveGame.load_all(Sim.tree())

func _summary(r: JobResult) -> Array:
	var unlocks := []
	for u in r.unlocks:
		unlocks.append(u.name)
	return [r.pay, r.reputation_change, r.letter, r.score, r.bonuses, unlocks, r.completed, r.casualties]

func test_pay_reputation_grade_and_unlocks_match_with_and_without_a_vow() -> bool:
	var ok := true
	for strikes in [0, 1]:
		_fresh()
		var wallet_before := Wallet.balance
		var plain := await _fly(null, strikes, true, true)
		var plain_wallet := Wallet.balance - wallet_before
		var plain_rep := Reputation.of(&"city")
		_fresh()
		wallet_before = Wallet.balance
		var vowed := await _fly(_keeping(), strikes, true, true)
		var same: bool = _summary(plain) == _summary(vowed) and Wallet.balance - wallet_before == plain_wallet \
			and Reputation.of(&"city") == plain_rep and plain.vow == null and vowed.vow != null
		if not same:
			print("        %d strikes: %s vs %s" % [strikes, _summary(plain), _summary(vowed)])
		ok = ok and same
	_fresh()
	return ok

func test_results_show_one_quiet_line_and_never_scold() -> bool:
	var screen: Control = load("res://scenes/ui/results.tscn").instantiate()
	Sim.add(screen)
	var rows: VBoxContainer = screen.get_node("%Rows")
	var r := JobResult.new()
	r.job = load("res://data/jobs/inspection.tres")
	r.completed = true
	screen.show_result(r)
	await Sim.process_frames(1)
	var bare := rows.get_child_count()
	var ok: bool = rows.get_node_or_null("Vow") == null
	var colours := []
	for kept in [true, false]:
		r.vow = _keeping()
		r.vow_kept = kept
		screen.show_result(r)
		await Sim.process_frames(1)
		var row: HBoxContainer = rows.get_node_or_null("Vow")
		ok = ok and row != null and rows.get_child_count() == bare + 1 and row.get_child_count() == 2
		if row == null:
			break
		var symbol = row.get_child(0)
		var line: Label = row.get_child(1)
		ok = ok and symbol is DeitySymbol and symbol.deity.id == &"vishnu" and line.text == Results.vow_text(r)
		for word in SCOLDING:
			ok = ok and not line.text.to_lower().replace("not kept", "").contains(word)
		colours.append(line.get_theme_color("font_color"))
	screen.free()
	return ok and colours.size() == 2 and colours[0] == colours[1] and colours[0] == Results.VOW_COLOUR

func test_the_player_launch_key_asks_on_a_vow_job() -> bool:
	# Healthy crew on a job that offers a vow: the launch key opens the dialog,
	# focused on launching, so a doubled press launches with none made.
	var root := _rig([_keeping()])
	var runner := await _ask(root)
	var d := runner.launch_dialog
	var ok: bool = d != null and d.visible and d.title == "Launch" and d.get_ok_button().has_focus() \
		and d.dialog_text == "" and d.content != null
	d.hide()
	root.free()
	# Injured crew too: one dialog, the risk named above the vow, backing out focused.
	Roster.injure(&"sanjaya")
	root = _rig([_keeping()])
	runner = await _ask(root)
	d = runner.launch_dialog
	ok = ok and d.visible and d.title == "Crew at risk" and d.get_cancel_button().has_focus() \
		and d.boxes.size() == 1 and d._text.text.contains("Sanjaya") and d._text.text.contains(LaunchDialog.VOW_INTRO)
	d.hide()
	root.free()
	return ok
