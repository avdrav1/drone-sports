extends RefCounted
# Story 7.5: injury, death, and the launch gate. One strike injures; a strike on a
# later job kills the injured; lethal jobs kill outright; launching with injured
# crew asks first; the dead leave the field; the results show who and their line.

const Sim = preload("res://tests/sim.gd")
const RESULTS := preload("res://scripts/ui/results.gd")
const ZONE_AT := Vector3(0, 5, -30)

## A job rig with Marlo in the field: a zone, a crew figure, and a Bark.
func _rig(tags: Array[StringName] = []) -> Node:
	var job := Job.new()
	job.crew_in_field = [&"marlo"]
	job.tags = tags
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	runner.results_scene = null
	runner.back_scene = ""
	var zone := HazardZone.new()
	zone.name = "Zone"
	zone.character = &"marlo"
	root.add_child(zone)
	zone.global_position = ZONE_AT
	var prop := CrewProp.new()
	prop.name = "Prop"
	prop.character = &"marlo"
	root.add_child(prop)
	var bark := Bark.new()
	bark.name = "Bark"
	bark.runner = runner
	bark.seed = 3
	root.add_child(bark)
	return root

## Begin, launch past any confirmation, and wait out the countdown.
func _go_live(root: Node) -> void:
	var runner: JobRunner = root.get_node("Runner")
	runner.begin()
	runner.launch(true)
	while runner.state == JobRunner.State.COUNTDOWN:
		await Sim.physics_frames(1)

## A scripted strike on Marlo after a full warning.
func _strike(root: Node) -> bool:
	var zone: HazardZone = root.get_node("Zone")
	for i in 75:
		zone.threaten()
		await Sim.physics_frames(1)
	return zone.strike(&"timer")

## One job: go live, strike Marlo, fail it. Returns the result.
func _job_with_strike(tags: Array[StringName] = []) -> JobResult:
	var root := _rig(tags)
	await _go_live(root)
	var heard := []  # strike lines only; the threat also draws a warning line
	root.get_node("Bark").spoke.connect(func(id, e, t): if e == &"strike": heard.append([id, e, t]))
	await _strike(root)
	var runner: JobRunner = root.get_node("Runner")
	runner.fail("test")
	var r := runner.result
	r.set_meta("heard", heard)
	root.free()
	return r

func test_one_strike_injures() -> bool:
	var r := await _job_with_strike()
	var heard: Array = r.get_meta("heard")
	# The strike line is from Marlo as they were: unhurt.
	var line_ok: bool = heard.size() == 1 and heard[0][1] == &"strike" \
		and heard[0][2] in Bark.lines_of(&"marlo").strike.active
	return Roster.status(&"marlo") == Roster.Status.INJURED and Roster.jobs_benched(&"marlo") == Roster.INJURY_JOBS \
		and r.casualties == {&"marlo": Roster.Status.INJURED} and line_ok

func test_second_job_strike_kills() -> bool:
	await _job_with_strike()
	var injured := Roster.status(&"marlo") == Roster.Status.INJURED
	var r := await _job_with_strike()
	var heard: Array = r.get_meta("heard")
	# Dead on the strike, so no strike line.
	return injured and Roster.status(&"marlo") == Roster.Status.DEAD \
		and r.casualties == {&"marlo": Roster.Status.DEAD} and heard.is_empty()

func test_lethal_job_kills_on_first_strike() -> bool:
	var r := await _job_with_strike([&"lethal"])
	return Roster.status(&"marlo") == Roster.Status.DEAD and r.casualties[&"marlo"] == Roster.Status.DEAD

func test_launch_with_injured_crew_asks_first() -> bool:
	Roster.injure(&"marlo")
	var root := _rig()
	var runner: JobRunner = root.get_node("Runner")
	var declined := [false]
	runner.launch_declined.connect(func(): declined[0] = true)
	runner.begin()
	runner.launch()
	await Sim.process_frames(1)
	var dialog := runner.launch_dialog
	var asked: bool = runner.state == JobRunner.State.BRIEFING and dialog != null and dialog.visible \
		and dialog.dialog_text.contains("Marlo") and dialog.dialog_text.contains("kill")
	dialog.canceled.emit()
	var backed_out: bool = declined[0] and runner.state == JobRunner.State.BRIEFING
	dialog.confirmed.emit()
	var launched := runner.state == JobRunner.State.COUNTDOWN
	root.free()
	var fresh := JobRunner.new()
	var goes_back := fresh.back_scene == "res://scenes/ui/job_board.tscn"
	fresh.free()
	return asked and backed_out and launched and goes_back

func test_healthy_crew_launch_without_asking() -> bool:
	var root := _rig()
	var runner: JobRunner = root.get_node("Runner")
	runner.begin()
	runner.launch()
	var ok := runner.state == JobRunner.State.COUNTDOWN and runner.launch_dialog == null
	root.free()
	return ok

func test_dead_crew_leave_the_field() -> bool:
	Roster.kill(&"marlo")
	var root := _rig()
	var runner: JobRunner = root.get_node("Runner")
	runner.begin()
	runner.launch()
	await Sim.process_frames(1)
	var ok: bool = runner.crew_in_field().is_empty() and runner.state == JobRunner.State.COUNTDOWN \
		and root.get_node_or_null("Zone") == null and root.get_node_or_null("Prop") == null \
		and runner.hazard_zones().is_empty()
	root.free()
	return ok

func test_results_show_injury_and_death_with_lines() -> bool:
	var hurt := await _job_with_strike()
	var hurt_row: HBoxContainer = RESULTS.casualty_row(hurt, &"marlo")
	var hurt_text: String = (hurt_row.get_child(1) as Label).text
	var hurt_line: String = hurt.casualty_lines[&"marlo"]
	var dead := await _job_with_strike()
	var dead_row: HBoxContainer = RESULTS.casualty_row(dead, &"marlo")
	var dead_text: String = (dead_row.get_child(1) as Label).text
	var ok: bool = hurt_text.contains("Marlo injured") and hurt_line in Bark.lines_of(&"marlo").hurt.active \
		and hurt_text.contains(hurt_line) and not (hurt_row.get_child(0) as CharacterPortrait).greyed \
		and dead_text.contains("Marlo died") and dead_text.contains(Bark.memorial(&"marlo")) \
		and Bark.memorial(&"marlo") != "" and (dead_row.get_child(0) as CharacterPortrait).greyed
	hurt_row.free()
	dead_row.free()
	return ok
