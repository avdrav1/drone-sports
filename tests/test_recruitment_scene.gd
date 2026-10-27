extends RefCounted
# Story 11.2: recruitment scene. Joining Skyline Juniors plays it once; declining
# doesn't; any key skips; the board afterwards shows Act 2. No franchise names
# in any cutscene line.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"
const SCENE := "res://scenes/story/recruited.tscn"
## Names the game draws on but must never use (CLAUDE.md rule 9, VISION.md).
const FORBIDDEN := ["star fox", "starfox", "starfighter", "ready player", "oasis", "nintendo", "mccloud", "arwing"]

func _board_with_offer() -> JobBoard:
	StoryFlags.set_flag(&"intro_seen")
	StoryFlags.set_flag(&"scouted")
	Sim.tree().change_scene_to_file(BOARD)
	await Sim.process_frames(3)
	return Sim.tree().current_scene

func _close() -> void:
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)

func test_joining_plays_the_scene_then_the_board_shows_act_2() -> bool:
	var b: JobBoard = await _board_with_offer()
	b.offer_dialog.confirmed.emit()
	await Sim.process_frames(3)
	var p := Sim.tree().current_scene as CutscenePlayer
	var playing: bool = p != null and p.scene_file_path == SCENE and p.index == 0 and not p.done
	while is_instance_valid(p) and not p.done:
		p.t = p.beat.duration
		await Sim.process_frames(1)
	await Sim.process_frames(3)
	var board := Sim.tree().current_scene as JobBoard
	var ok: bool = playing and board != null and board._header.text.contains("Act 2") \
		and StoryFlags.is_set(&"recruited_seen")
	await _close()
	return ok

func test_plays_once() -> bool:
	StoryFlags.set_flag(&"recruited_seen")
	Sim.tree().change_scene_to_file(SCENE)
	await Sim.process_frames(4)
	var ok := Sim.tree().current_scene.scene_file_path == BOARD
	await _close()
	return ok

func test_declining_does_not_play_it() -> bool:
	var b: JobBoard = await _board_with_offer()
	b.offer_dialog.canceled.emit()
	await Sim.process_frames(3)
	var ok: bool = Sim.tree().current_scene == b and Career.team_id == &"" and not StoryFlags.is_set(&"recruited_seen")
	await _close()
	return ok

func test_any_key_skips() -> bool:
	Sim.tree().change_scene_to_file(SCENE)
	await Sim.process_frames(3)
	var p: CutscenePlayer = Sim.tree().current_scene
	await Sim.physics_frames(40)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	p.get_viewport().push_input(ev)
	await Sim.process_frames(3)
	var ok: bool = Sim.tree().current_scene.scene_file_path == BOARD and StoryFlags.is_set(&"recruited_seen")
	await _close()
	return ok

func test_lines_hold_together_and_name_no_franchise() -> bool:
	var ok := true
	for path in ["res://data/story/intro.tres", "res://data/story/recruited.tres"]:
		var c: Cutscene = load(path)
		var backdrop: Node = null
		for b in c.beats:
			if b.backdrop != "":
				if backdrop:
					backdrop.free()
				backdrop = (load(b.backdrop) as PackedScene).instantiate()
			ok = ok and backdrop.get_node_or_null(b.focus) is Node3D
			var text := (b.caption + " " + b.title).to_lower()
			for name in FORBIDDEN:
				if text.contains(name):
					print("        %s: %s" % [path, name])
					ok = false
		backdrop.free()
	return ok
