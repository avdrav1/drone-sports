extends RefCounted
# Story 25.3: the boss is Ravana wherever a player sees it: the job board, the
# briefing, the HUD (its units are heads), the controls help and its lines. No
# player-facing string says "Lattice"; the code's Lattice* names stay. Off, the
# boss shows nowhere, its name included.

const Sim = preload("res://tests/sim.gd")
const NAMES = preload("res://tests/test_new_names.gd")
const BOARD := "res://scenes/ui/job_board.tscn"
const SCENE := "res://scenes/boss/lattice_job.tscn"

func _job() -> Node:
	var s: Node = load(SCENE).instantiate()
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

func _files(dir: String, out: Array[String]) -> Array[String]:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in NAMES.KINDS:
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_files(dir.path_join(d), out)
	return out

func test_no_player_string_says_lattice() -> bool:
	var word := RegEx.create_from_string("(?i)\\blattice\\b")
	var bad := []
	for root in NAMES.ROOTS:
		for path in _files(root, [] as Array[String]):
			var lines := FileAccess.get_file_as_string(path).split("\n")
			for i in lines.size():
				for s in NAMES.player_strings(lines[i], path.get_extension()):
					# The boss's id, e.g. the music manifest's "lattice" key.
					if s != "lattice" and word.search(s):
						bad.append("%s:%d %s" % [path, i + 1, s])
	if not bad.is_empty():
		print("        ", bad)
	return bad.is_empty()

func test_the_board_card_names_ravana() -> bool:
	_boss(true)
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	await Sim.process_frames(1)
	var card: Control = b.job_rows.get(&"lattice")
	var titles := card.find_children("*", "Label", true, false).map(func(l): return l.text) if card else []
	b.free()
	BossGate.boss = null
	return BossGate.data().job.title == "Ravana" and "Ravana" in titles

func test_briefing_hud_and_lines_name_ravana() -> bool:
	var s := _job()
	await Sim.process_frames(2)
	var runner: JobRunner = s.get_node("JobRunner")
	var briefing: String = (s.get_node("HUD/State") as Label).text
	var fight: LatticeFight = s.get_node("Fight")
	var hud: LatticeHud = s.get_node("HUD/Phase")
	fight.phase = LatticeFight.Phase.RECLAIM
	var reclaim := hud.lines()
	var chorus: Chorus = s.get_node("Chorus")
	var box: ChorusBox = s.get_node("HUD/ChorusBox")
	var line := chorus.say(&"strike")
	await Sim.process_frames(1)
	var said := box.label.text
	var objectives := runner.objectives().map(func(o): return o.label)
	var briefed := runner.state == JobRunner.State.BRIEFING
	s.queue_free()
	await Sim.process_frames(1)
	return briefed and briefing.contains("Ravana") \
		and reclaim.contains("tags a head") and not reclaim.contains("unit") \
		and line != "" and said == "Ravana: " + line and "Ravana is down" in objectives

func test_help_names_ravana_only_while_the_boss_is_on() -> bool:
	var rows := func() -> Array:
		var help := ControlsHelp.new()
		Sim.add(help)
		var texts := help.find_children("*", "Label", true, false).map(func(l): return l.text) \
			.filter(func(t): return t.contains("Ravana"))
		help.free()
		return texts
	_boss(false)
	var off: Array = rows.call()
	_boss(true)
	var on: Array = rows.call()
	BossGate.boss = null
	return off.is_empty() and on == ["Ravana: send the selected drone to tag one of his heads"]
