extends RefCounted
# Story 11.1: intro. Plays on a new game from the first beat; finishing or any
# key ends it, sets intro_seen, and opens the board; once seen, launch goes
# straight to the board; the beats hold together; the board marks START HERE
# and can replay it. Since Story 17.3 the title stands between the intro and
# the board. The game now opens on the title, even the first time; the intro
# plays only from Watch intro.

const Sim = preload("res://tests/sim.gd")
const INTRO := "res://scenes/story/intro.tscn"
const BOARD := "res://scenes/ui/job_board.tscn"
const TITLE := "res://scenes/ui/title.tscn"

func _open(path: String) -> Node:
	Sim.tree().change_scene_to_file(path)
	await Sim.process_frames(3)
	return Sim.tree().current_scene

func _close() -> void:
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)

func test_launch_opens_the_title_and_the_intro_plays_from_the_first_beat() -> bool:
	# A first launch goes straight to the title and its PLAY, not the intro.
	var ok: bool = ProjectSettings.get_setting("application/run/main_scene") == TITLE \
		and not StoryFlags.is_set(&"intro_seen")
	TitleScreen.needs_play = true
	var t: TitleScreen = await _open(TITLE)
	ok = ok and t is TitleScreen and t.play_button.visible and t.crawl != null
	await _close()
	TitleScreen.needs_play = false
	CutscenePlayer.replay = true
	var p: CutscenePlayer = await _open(INTRO)
	ok = ok and p is CutscenePlayer and p.index == 0 and not p.done and p.camera.current \
		and p.caption.text == p.cutscene.beats[0].caption and p.backdrop != null
	await _close()
	return ok

func test_beats_hold_together() -> bool:
	var c: Cutscene = load("res://data/story/intro.tres")
	var total := c.total_time()
	var ok: bool = c.beats.size() >= 5 and total >= 45.0 and total <= 90.0 and c.beats[0].backdrop != "" \
		and c.seen_flag == &"intro_seen" and c.next_scene == TITLE
	var backdrop: Node = null
	for b in c.beats:
		if b.backdrop != "":
			if backdrop:
				backdrop.free()
			var packed: PackedScene = load(b.backdrop)
			ok = ok and packed != null
			backdrop = packed.instantiate()
		ok = ok and backdrop.get_node_or_null(b.focus) is Node3D and (b.caption != "" or b.title != "")
		if b.portrait != &"":
			ok = ok and Roster.character(b.portrait) != null
	backdrop.free()
	return ok

func test_walks_every_beat_then_opens_the_title() -> bool:
	var p: CutscenePlayer = await _open(INTRO)
	var beats := p.cutscene.beats.size()
	var captions := []
	while is_instance_valid(p) and not p.done:
		captions.append(p.caption.text)
		p.t = p.beat.duration  # jump to the end of the beat
		await Sim.process_frames(1)
	await Sim.process_frames(3)
	var now := Sim.tree().current_scene
	var ok: bool = captions.size() == beats and StoryFlags.is_set(&"intro_seen") \
		and now.scene_file_path == TITLE
	await _close()
	return ok

func test_any_key_skips() -> bool:
	var p: CutscenePlayer = await _open(INTRO)
	await Sim.physics_frames(40)  # past the skip grace
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	p.get_viewport().push_input(ev)
	await Sim.process_frames(3)
	var ok: bool = StoryFlags.is_set(&"intro_seen") and Sim.tree().current_scene.scene_file_path == TITLE
	await _close()
	return ok

func test_once_seen_launch_goes_to_the_title() -> bool:
	StoryFlags.set_flag(&"intro_seen")
	var first: Node = await _open(INTRO)
	var ok: bool = first == null or first.scene_file_path == TITLE
	ok = ok and Sim.tree().current_scene != null and Sim.tree().current_scene.scene_file_path == TITLE
	await _close()
	return ok

func test_board_marks_start_here_and_replays_the_intro() -> bool:
	StoryFlags.set_flag(&"intro_seen")
	var b: JobBoard = await _open(BOARD)
	var marked: bool = b.job_rows[&"test_race"].get_child(0).get_node_or_null("StartHere") != null \
		and b.job_rows[&"sample_delivery"].get_child(0).get_node_or_null("StartHere") == null
	b.watch_intro()
	await Sim.process_frames(3)
	var p := Sim.tree().current_scene as CutscenePlayer
	var replays: bool = p != null and p.index == 0 and not p.done
	await _close()
	Career.job_completed(&"test_race")
	var b2: JobBoard = load(BOARD).instantiate()
	Sim.add(b2)
	var cleared: bool = b2.job_rows[&"test_race"].get_child(0).get_node_or_null("StartHere") == null
	b2.free()
	return marked and replays and cleared
