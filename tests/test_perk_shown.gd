extends RefCounted
# Story 19.7: show what you'd lose. The CREW page shows each support crew
# member's perk under their status, struck through with the jobs left while
# benched and lost once dead; the crew-in-field confirmation names each perk at
# risk; the results screen's injury line says which perk is off.

const Sim = preload("res://tests/sim.gd")
const RESULTS := preload("res://scripts/ui/results.gd")
const BOARD := "res://scenes/ui/job_board.tscn"

func _perk(b: JobBoard, id: StringName) -> RichTextLabel:
	return b.crew_rows[id].get_node_or_null("Info/Perk")

func _board() -> JobBoard:
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	await Sim.process_frames(1)
	return b

func test_each_support_crew_row_shows_its_perk() -> bool:
	var b: JobBoard = await _board()
	var ok := true
	for id in Roster.ids():
		var c: Character = Roster.character(id)
		var l := _perk(b, id)
		if c.perk:
			ok = ok and l != null and l.get_parsed_text() == c.perk.line() and not l.text.contains("[s]")
		else:
			ok = ok and l == null
	var bea := _perk(b, &"bea").get_parsed_text()
	b.free()
	return ok and bea == "Site rates: +15% pay on every job"

func test_benched_perk_shows_off_with_jobs_left() -> bool:
	Roster.kill(&"ozzie")  # so Marlo is out for the full two
	Roster.injure(&"marlo")
	var b: JobBoard = await _board()
	var l := _perk(b, &"marlo")
	var ok := l.text.contains("[s]") and l.get_parsed_text().begins_with("Off for 2 more jobs:") \
		and l.get_parsed_text().ends_with("Spotting: Route guidance one step better on every job")
	b.free()
	Roster.job_done()
	b = await _board()
	ok = ok and _perk(b, &"marlo").get_parsed_text().begins_with("Off for 1 more job:")
	b.free()
	return ok

func test_dead_row_shows_the_perk_lost() -> bool:
	Roster.kill(&"bea")
	var b: JobBoard = await _board()
	var text := _perk(b, &"bea").get_parsed_text()
	var status: String = (b.crew_rows[&"bea"].get_node("Info/Status") as Label).text
	b.free()
	return text == "No more site rates" and status.contains("Died.")

func test_crew_in_field_confirmation_names_each_perk_at_risk() -> bool:
	Roster.injure(&"marlo")
	Roster.injure(&"bea")
	var job := Job.new()
	job.crew_in_field = [&"marlo", &"bea"]
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	runner.back_scene = ""
	runner.begin()
	runner.launch()
	await Sim.process_frames(1)
	var text := runner.launch_dialog.dialog_text
	runner.launch_dialog.hide()
	root.free()
	return text.contains("Sanjaya and Bhima are injured") and text.contains("You would lose") \
		and text.contains("Sanjaya's spotting") and text.contains("Bhima's site rates (+15% pay on every job)")

func test_results_injury_line_names_the_perk_off() -> bool:
	Roster.injure(&"marlo")
	var r := JobResult.new()
	r.casualties = {&"marlo": Roster.Status.INJURED}
	var row: HBoxContainer = RESULTS.casualty_row(r, &"marlo")
	var text: String = (row.get_child(1) as Label).text
	row.free()
	Roster.kill(&"marlo")
	r.casualties = {&"marlo": Roster.Status.DEAD}
	var dead_row: HBoxContainer = RESULTS.casualty_row(r, &"marlo")
	var dead: String = (dead_row.get_child(1) as Label).text
	dead_row.free()
	return text == "Sanjaya injured, out for 1 job: no spotting." and dead == "Sanjaya died."
