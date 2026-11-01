extends RefCounted
# Story 30.3: act gates. A short scene opens each of the Four's threads, once
# per save: Brahma as a new game opens Act 1 (from the title), Vishnu on
# joining the first team and Shiva at the first Act 4 promotion (before the
# next job, or on start), Krishna before the first job flown in Act 5. Each beat shows the god's symbol card and sounds their motif; none
# has a portrait, emote, babble or bark; any key skips.

const Sim = preload("res://tests/sim.gd")
const TITLE := "res://scenes/ui/title.tscn"
const BOARD := "res://scenes/ui/job_board.tscn"
const RECRUITED := "res://scenes/story/recruited.tscn"
const FLEET := "res://data/jobs/fleet_inspection.tres"
const GATES := {1: &"brahma", 2: &"vishnu", 4: &"shiva", 5: &"krishna"}

func _scene() -> Node:
	return Sim.tree().current_scene

func _close() -> void:
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)

## The act gate playing now, or null.
func _gate() -> CutscenePlayer:
	var p := _scene() as CutscenePlayer
	return p if p and p.cutscene.gate_act > 0 else null

## Plays the current cutscene to its end, beat by beat.
func _play_through(p: CutscenePlayer) -> void:
	while is_instance_valid(p) and not p.done:
		p.t = p.beat.duration
		await Sim.process_frames(1)
	await Sim.process_frames(3)

## Opens the title and presses start on it.
func _start_from_title() -> void:
	Sim.tree().change_scene_to_file(TITLE)
	await Sim.process_frames(3)
	(_scene() as TitleScreen).start()
	await Sim.process_frames(3)

func test_the_four_gates_are_data() -> bool:
	var gates: ActGates = load(Career.GATES)
	var list: DeityList = load("res://data/deities/deities.tres")
	var ok: bool = gates.gates.size() == 4
	for act in GATES:
		var c := gates.for_act(act)
		ok = ok and c != null and c.beats.size() >= 2 and c.beats.size() <= 4 and c.seen_flag != &"" \
			and c.score == load(Deity.MOTIF_SCORE) and c.next_scene == BOARD
		for b in c.beats if c else []:
			ok = ok and b.deity == list.by_id(GATES[act]) and b.deity.thread_act == act and b.caption != ""
	# The owner's decision: Act 1 names Brahma and his principle from the first beat.
	var first: String = gates.for_act(1).beats[0].caption
	return ok and first.begins_with("Brahma") and first.contains("Creation")

func test_a_new_game_opens_on_brahma_then_the_board_once() -> bool:
	await _start_from_title()
	var p := _gate()
	var ok: bool = p != null and p.cutscene.gate_act == 1 and p.index == 0 and p.symbol_card.visible \
		and p.symbol.deity.id == &"brahma"
	await _play_through(p)
	ok = ok and _scene() is JobBoard and StoryFlags.is_set(&"act_1_gate_seen")
	await _close()
	# Never again: the next start goes straight to the board.
	await _start_from_title()
	ok = ok and _scene() is JobBoard and _gate() == null
	await _close()
	return ok

func test_joining_the_first_team_opens_vishnu_before_the_next_job() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	StoryFlags.set_flag(&"act_1_gate_seen")
	StoryFlags.set_flag(&"scouted")
	Sim.tree().change_scene_to_file(BOARD)
	await Sim.process_frames(3)
	(_scene() as JobBoard).offer_dialog.confirmed.emit()
	await Sim.process_frames(3)
	# The recruitment scene plays as before, then the board.
	var recruited := _scene() as CutscenePlayer
	var ok: bool = recruited != null and recruited.scene_file_path == RECRUITED
	await _play_through(recruited)
	ok = ok and _scene() is JobBoard and Career.act() == 2
	# The first job on the team opens Vishnu's thread, then the job.
	var race: Job = load("res://data/jobs/test_race.tres")
	(_scene() as JobBoard).fly(race)
	await Sim.process_frames(3)
	var p := _gate()
	ok = ok and p != null and p.cutscene.gate_act == 2 and p.symbol.deity.id == &"vishnu"
	await _play_through(p)
	ok = ok and _scene().scene_file_path == race.scene and StoryFlags.is_set(&"act_2_gate_seen")
	await _close()
	# Never again, nor for a second team in the same act.
	Career.team_id = &"harbor_couriers"
	ok = ok and Career.gate_due() == null and Career.gate_due(2) == null
	Career.team_id = &""
	return ok

func test_a_new_act_opens_from_the_title_too() -> bool:
	# Back on a new team's act with its gate unseen, starting plays it first.
	StoryFlags.set_flag(&"act_1_gate_seen")
	PlayerProfile.choose_pilot(&"arjuna")
	Career.team_id = &"harbor_couriers"
	await _start_from_title()
	var p := _gate()
	var ok: bool = p != null and p.cutscene.gate_act == 2
	await _play_through(p)
	ok = ok and _scene() is JobBoard
	await _close()
	Career.team_id = &""
	return ok

func test_flying_in_act_1_never_opens_a_gate() -> bool:
	# Brahma's gate opens a new game from the title, never a job.
	var ok: bool = Career.gate_due(1) == null and Career.gate_due().gate_act == 1
	Sim.tree().change_scene_to_file(BOARD)
	await Sim.process_frames(3)
	var race: Job = load("res://data/jobs/test_race.tres")
	(_scene() as JobBoard).fly(race)
	await Sim.process_frames(3)
	ok = ok and _gate() == null and _scene().scene_file_path == race.scene
	await _close()
	return ok

func test_the_first_act_4_promotion_plays_shiva_once() -> bool:
	for a in [1, 2]:
		StoryFlags.set_flag(StringName("act_%d_gate_seen" % a))
	PlayerProfile.choose_pilot(&"arjuna")
	Career.team_id = &"cannery_row"  # Act 3: no gate of its own
	var ok: bool = Career.gate_due() == null
	Career.team_id = &"deadweight"  # Act 4
	var job: Job = load("res://data/jobs/demolition.tres")
	Sim.tree().change_scene_to_file(BOARD)
	await Sim.process_frames(3)
	(_scene() as JobBoard).fly(job)
	await Sim.process_frames(3)
	var p := _gate()
	ok = ok and p != null and p.cutscene.gate_act == 4 and p.symbol.deity.id == &"shiva"
	await _play_through(p)
	ok = ok and _scene().scene_file_path == job.scene
	await _close()
	Career.team_id = &"halcyon_racing"  # another Act 4 team
	ok = ok and Career.gate_due() == null
	Career.team_id = &""
	return ok

func test_krishna_opens_the_first_fleet_job_then_the_job() -> bool:
	for a in [1, 2]:
		StoryFlags.set_flag(StringName("act_%d_gate_seen" % a))
	PlayerProfile.choose_pilot(&"arjuna")
	Career.team_id = &"city_rescue_air"  # Act 3, flies fleet jobs
	var job: Job = load(FLEET)
	# Not before it is needed: the career's own act has no Krishna gate.
	var ok: bool = Career.gate_due() == null and Career.gate_due(5).gate_act == 5
	Sim.tree().change_scene_to_file(BOARD)
	await Sim.process_frames(3)
	(_scene() as JobBoard).fly(job)
	await Sim.process_frames(3)
	var p := _gate()
	ok = ok and p != null and p.cutscene.gate_act == 5 and p.symbol.deity.id == &"krishna"
	await _play_through(p)
	ok = ok and _scene() != null and _scene().scene_file_path == job.scene \
		and StoryFlags.is_set(&"act_5_gate_seen")
	await _close()
	# Never again.
	Sim.tree().change_scene_to_file(BOARD)
	await Sim.process_frames(3)
	(_scene() as JobBoard).fly(job)
	await Sim.process_frames(3)
	ok = ok and _gate() == null and _scene().scene_file_path == job.scene
	await _close()
	Career.team_id = &""
	return ok

func test_any_key_skips_a_gate() -> bool:
	await _start_from_title()
	var p := _gate()
	var ok: bool = p != null and p.index == 0
	await Sim.physics_frames(40)  # past the skip grace
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	p.get_viewport().push_input(ev)
	await Sim.process_frames(3)
	ok = ok and StoryFlags.is_set(&"act_1_gate_seen") and _scene() is JobBoard
	await _close()
	return ok

func test_no_portrait_emote_babble_or_bark_and_only_the_motif() -> bool:
	var gates: ActGates = load(Career.GATES)
	var ok := true
	for act in GATES:
		var c := gates.for_act(act)
		for b in c.beats:
			ok = ok and b.portrait == &"" and not b.silhouette and not b.bezel
		CutscenePlayer.replay = true
		var p := CutscenePlayer.new()
		p.cutscene = c
		p.then = BOARD
		Sim.tree().unload_current_scene()
		Sim.tree().change_scene_to_node(p)
		await Sim.process_frames(3)
		var spoken := []
		for bark in p.find_children("Bark", "", true, false):
			if bark.has_signal("spoke"):
				bark.spoke.connect(func(_id, _e, text): spoken.append(text))
		for i in c.beats.size():
			await Sim.process_frames(20)
			ok = ok and not p.card.visible and p.symbol_card.visible and p.symbol.deity.id == GATES[act]
			# Of the Four's score only this god's motif sounds.
			for s in Music.score.stems if Music.score else []:
				var on: bool = Music.level(s.id) > Music.SILENT_DB
				ok = ok and on == (s.id == p.symbol.deity.motif)
			ok = ok and Music.score != null and Music.score.id == c.score.id
			for comp in p.find_children("Companion", "", true, false):
				ok = ok and comp.silenced()
			ok = ok and p.find_children("*", "CharacterPortrait", true, false).all(func(n): return not n.is_visible_in_tree())
			p.t = p.beat.duration
			await Sim.process_frames(1)
		ok = ok and spoken.is_empty()
		await Sim.process_frames(3)
		await _close()
	return ok
