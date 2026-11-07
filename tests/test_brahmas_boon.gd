extends RefCounted
# Story 30.9: the final job's briefing names Brahma's boon, the reason only a
# human hand can stop Ravana. Lines are data on the job; the fight is unchanged
# (every assist off), and with the boss off none of it loads or shows.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"
const JOB := "res://scenes/boss/lattice_job.tscn"

func _job() -> Node:
	var s: Node = load(JOB).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	runner.confirm_risk = false
	Sim.add(s)
	var fight: LatticeFight = s.get_node("Fight")
	for d in fight.defenders:
		d.free()
	fight.defenders.clear()
	return s

func _boss(on: bool) -> void:
	var b: Boss = (load(BossGate.DATA) as Boss).duplicate()
	b.enabled = on
	BossGate.boss = b
	BossGate.loads.clear()

func _briefing() -> String:
	return (load(BossGate.DATA) as Boss).job.briefing

func test_briefing_names_the_boon_in_one_or_two_lines() -> bool:
	var text := _briefing()
	var lines := Array(text.split("\n", false))
	# Original lines, never set out as a quotation.
	var quoted := text.contains("\"") or text.contains("“") or text.contains("”")
	var ok: bool = lines.size() >= 1 and lines.size() <= 2 and text.contains("Brahma") \
		and text.contains("boon") and text.contains("human") and not quoted
	if not ok:
		print("        ", lines)
	return ok

func test_briefing_shows_while_the_job_waits() -> bool:
	var s := _job()
	await Sim.process_frames(2)
	var runner: JobRunner = s.get_node("JobRunner")
	var hud: LatticeHud = s.get_node("HUD/Phase")
	await Sim.process_frames(1)
	var briefed := runner.state == JobRunner.State.BRIEFING
	var shown := hud.text
	var fight: LatticeFight = s.get_node("Fight")
	fight.phase = LatticeFight.Phase.RECLAIM
	var after := hud.lines()
	s.queue_free()
	await Sim.process_frames(1)
	return briefed and shown == _briefing() and not after.contains("Brahma")

func test_only_the_final_job_has_it() -> bool:
	for job in (load("res://data/jobs/board.tres") as JobList).jobs:
		if job.briefing.contains("Brahma"):
			return false
	return true

func test_the_fight_is_unchanged() -> bool:
	# Flown with the fleet missions' assists (Story 35.1), in Act 5.
	var job: Job = (load(BossGate.DATA) as Boss).job
	return job.required_assists == load("res://data/assists/mission_fleet.tres") and job.act == 5 and job.tags.has(&"lethal")

func test_disabled_shows_none_of_it() -> bool:
	_boss(false)
	Career.job_completed(&"fleet_race")
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	await Sim.process_frames(2)
	var texts := b.find_children("*", "Label", true, false).map(func(l): return l.text)
	var named := texts.filter(func(t): return t.contains("Brahma") or t.contains("boon"))
	var ok: bool = named.is_empty() and not b.job_rows.has(&"lattice") and BossGate.loads.is_empty()
	b.free()
	BossGate.boss = null
	return ok

func test_boss_md_answers_the_reason() -> bool:
	var md := FileAccess.get_file_as_string("res://docs/BOSS.md")
	var line := ""
	for l in md.split("\n"):
		if l.contains("Does Ravana have a reason"):
			line = l
	return line.begins_with("- [x]") and line.contains("Brahma") and line.contains("boon")
