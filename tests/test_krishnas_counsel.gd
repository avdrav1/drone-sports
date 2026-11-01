extends RefCounted
# Story 30.10: before the final job launches, Krishna's counsel, relayed by
# Sanjaya, is the launch confirmation. The player still chooses; declining backs
# out to the board. The lines change with vows kept and crew lost; with the boss
# off it plays before the fleet final and names no boss; a dead Sanjaya never
# speaks (rule 7).

const Sim = preload("res://tests/sim.gd")
const COUNSEL := "res://data/story/counsel.tres"
const LATTICE := "res://scenes/boss/lattice_job.tscn"
const FLEET_FINAL := "res://data/jobs/fleet_race.tres"
const BOARD := "res://scenes/ui/job_board.tscn"
## Words that would name the boss.
const BOSS_WORDS := ["Ravana", "Lanka", "Lattice", "machine", "king", "boon"]
## Words a counsel line must never carry: no scolding, no quotation.
const NEVER := ["shame", "should have", "failed", "sin", "punish", "!", "\""]

func _counsel() -> Counsel:
	return load(COUNSEL)

func _boss(on: bool) -> void:
	var b: Boss = (load(BossGate.DATA) as Boss).duplicate()
	b.enabled = on
	BossGate.boss = b
	BossGate.loads.clear()

## A light rig flying `job` (no boss scene), back_scene cleared.
func _rig(job: Job) -> Node:
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	runner.results_scene = null
	runner.back_scene = ""
	runner.pays_out = false
	return root

## Begin and press launch as the player does; returns the runner.
func _ask(root: Node) -> JobRunner:
	var runner: JobRunner = root.get_node("Runner")
	runner.begin()
	runner.request_launch()
	await Sim.process_frames(1)
	return runner

## The counsel's lines for the final job, on the save as it stands.
func _lines() -> String:
	_boss(true)
	var out := "\n".join(_counsel().lines((load(BossGate.DATA) as Boss).job))
	BossGate.boss = null
	return out

func _all_text(d: LaunchDialog) -> String:
	return "\n".join(d.find_children("*", "Label", true, false).map(func(l): return l.text)) + "\n" + d.title

func test_final_job_launch_shows_the_counsel_and_waits() -> bool:
	_boss(true)
	var s: Node = load(LATTICE).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	runner.auto_begin = false
	Sim.add(s)
	var fight: LatticeFight = s.get_node("Fight")
	for d in fight.defenders:
		d.free()
	fight.defenders.clear()
	runner.begin()
	runner.request_launch()
	await Sim.process_frames(1)
	var d := runner.launch_dialog
	var c := _counsel()
	var ok: bool = d != null and d.visible and d.counsel == c and runner.state == JobRunner.State.BRIEFING
	ok = ok and d.counsel_heading == c.heading and d.counsel_lines[0] == c.hesitation_boss
	ok = ok and _has_symbol(d, c.deity)
	ok = ok and d.get_ok_button().text == c.launch_text and d.get_cancel_button().text == c.decline_text
	# Backing out is the default: a held Enter never launches unread.
	ok = ok and d.get_cancel_button().has_focus()
	# Krishna's motif alone of the Four's score sounds under it.
	ok = ok and Music.score != null and Music.score.resource_path == Deity.MOTIF_SCORE
	# Nothing launches until the player chooses.
	await Sim.physics_frames(10)
	ok = ok and runner.state == JobRunner.State.BRIEFING
	d.hide()
	d.confirmed.emit()
	ok = ok and runner.state == JobRunner.State.COUNTDOWN
	# The motif gave way to the fight's music.
	ok = ok and (Music.score == null or Music.score.resource_path != Deity.MOTIF_SCORE)
	s.free()
	BossGate.boss = null
	return ok

func _has_symbol(d: Node, deity: Deity) -> bool:
	for n in d.find_children("*", "", true, false):
		if n is DeitySymbol and n.deity == deity:
			return true
	return false

func test_the_symbol_is_krishnas() -> bool:
	_boss(true)
	var root := _rig(load(BossGate.DATA).job)
	var runner := await _ask(root)
	var ok: bool = runner.launch_dialog != null and _has_symbol(runner.launch_dialog, _counsel().deity) \
		and _counsel().deity.id == &"krishna"
	root.free()
	BossGate.boss = null
	return ok

func test_declining_returns_to_the_board() -> bool:
	_boss(true)
	var root := _rig(load(BossGate.DATA).job)
	var runner := await _ask(root)
	var declined := [false]
	runner.launch_declined.connect(func(): declined[0] = true)
	runner.launch_dialog.hide()
	runner.launch_dialog.canceled.emit()
	var ok: bool = declined[0] and runner.state == JobRunner.State.BRIEFING
	root.free()
	BossGate.boss = null
	var fresh := JobRunner.new()
	ok = ok and fresh.back_scene == BOARD
	fresh.free()
	return ok

func test_a_direct_launch_asks_too() -> bool:
	_boss(true)
	var root := _rig(load(BossGate.DATA).job)
	var runner: JobRunner = root.get_node("Runner")
	runner.begin()
	runner.launch()
	var ok: bool = runner.state == JobRunner.State.BRIEFING and runner.launch_dialog != null \
		and runner.launch_dialog.counsel != null
	root.free()
	BossGate.boss = null
	return ok

func test_only_the_final_job_has_it() -> bool:
	_boss(true)
	var c := _counsel()
	var ok := c.applies_to(load(BossGate.DATA).job) and not c.applies_to(load(FLEET_FINAL))
	for p in ["res://data/jobs/inspection.tres", "res://data/jobs/rescue.tres", "res://data/jobs/fleet_inspection.tres"]:
		ok = ok and not c.applies_to(load(p))
	# Another job launches as before, with no dialog.
	var root := _rig(load(FLEET_FINAL))
	var runner := await _ask(root)
	ok = ok and runner.launch_dialog == null and runner.state == JobRunner.State.COUNTDOWN
	root.free()
	BossGate.boss = null
	return ok

func test_different_saves_show_different_lines() -> bool:
	var none := _lines()
	for d in (load(Counsel.DEITIES) as DeityList).deities:
		Vows.record_kept(d.id)
	var every := _lines()
	SaveGame.write_section(Vows.SECTION, {})
	Vows.record_kept(&"vishnu")
	var one := _lines()
	SaveGame.write_section(Vows.SECTION, {})
	Roster.kill(&"bhima")
	var death := _lines()
	var c := _counsel()
	return none != every and none != death and every != death and one != none and one != every \
		and none.contains(c.none_kept) and every.contains(c.all_kept) and one.contains(c.kept_lines["vishnu"]) \
		and death.contains("Bhima") and not none.contains("Bhima") and none.contains(c.crew_whole)

func test_the_lines_speak_to_duty_outcome_and_crew() -> bool:
	var c := _counsel()
	var text := _lines().to_lower()
	var ok: bool = c.lines_duty.size() >= 2 and text.contains("work") and text.contains("outcome") \
		and text.contains("crew") and text.contains("yours")
	var all: Array[String] = [c.heading, c.heading_unspoken, c.hesitation_boss, c.hesitation_final, c.all_kept,
		c.none_kept, c.crew_whole, c.crew_lost, c.closing]
	all.append_array(c.lines_duty)
	for v in c.kept_lines.values():
		all.append(v)
	for line in all:
		ok = ok and line != ""
		for w in NEVER:
			ok = ok and not line.to_lower().contains(w)
	return ok and c.kept_lines.size() == 4

func test_disabled_boss_counsels_the_fleet_final_naming_no_boss() -> bool:
	_boss(false)
	var root := _rig(load(FLEET_FINAL))
	var runner := await _ask(root)
	var d := runner.launch_dialog
	var ok: bool = d != null and d.visible and d.counsel != null and runner.state == JobRunner.State.BRIEFING \
		and d.counsel_lines[0] == _counsel().hesitation_final
	var text := _all_text(d) if d else ""
	for w in BOSS_WORDS:
		ok = ok and RegEx.create_from_string("(?i)\\b%s\\b" % w).search(text) == null
	d.hide()
	d.confirmed.emit()
	ok = ok and runner.state == JobRunner.State.COUNTDOWN and BossGate.loads.is_empty()
	root.free()
	BossGate.boss = null
	return ok

func test_a_dead_sanjaya_never_speaks() -> bool:
	_boss(true)
	var root := _rig(load(BossGate.DATA).job)
	var runner := await _ask(root)
	var c := _counsel()
	var alive: bool = runner.launch_dialog.counsel_heading == c.heading and c.heading.contains("Sanjaya")
	root.free()
	Roster.kill(&"sanjaya")
	root = _rig(load(BossGate.DATA).job)
	runner = await _ask(root)
	var d := runner.launch_dialog
	var heading := d.counsel_heading
	# Text with no speaker: the heading names no one, and his name is only in
	# the line that carries the crew lost.
	var ok: bool = alive and d.visible and heading == c.heading_unspoken and not heading.contains("Sanjaya") \
		and not c.spoken()
	for line in d.counsel_lines:
		ok = ok and (not line.contains("Sanjaya") or line == c.crew_lost.format({"names": "Sanjaya"}))
	root.free()
	BossGate.boss = null
	return ok
