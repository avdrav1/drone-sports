extends RefCounted
# Story 17.3: title screen. Launching with the intro seen opens the title, not
# the board; any key, click, or pad button opens the board, with pilot select
# first on a new game; the best score is the save's best single payout; the
# backdrop loads and its camera orbits; Esc on the board comes back.

const Sim = preload("res://tests/sim.gd")
const INTRO := "res://scenes/story/intro.tscn"
const TITLE := "res://scenes/ui/title.tscn"
const BOARD := "res://scenes/ui/job_board.tscn"

func _open(path: String) -> Node:
	Sim.tree().change_scene_to_file(path)
	await Sim.process_frames(3)
	return Sim.tree().current_scene

func _close() -> void:
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)

## Opens the title, presses `event` once the start grace is over, and returns the scene after.
func _press(event: InputEvent) -> Node:
	var t: TitleScreen = await _open(TITLE)
	t._age = t.start_grace
	event.pressed = true
	t.get_viewport().push_input(event)
	await Sim.process_frames(3)
	return Sim.tree().current_scene

func test_launch_with_intro_seen_opens_the_title() -> bool:
	StoryFlags.set_flag(&"intro_seen")
	await _open(INTRO)
	await Sim.process_frames(2)
	var now := Sim.tree().current_scene
	var ok: bool = now is TitleScreen and now.scene_file_path == TITLE
	await _close()
	return ok

func test_any_key_click_or_pad_button_opens_the_board() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	var ok := true
	var key := InputEventKey.new()
	key.physical_keycode = KEY_X
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	for ev in [key, click, pad]:
		var now: Node = await _press(ev)
		ok = ok and now is JobBoard and not now.pilot_select.visible
		await _close()
	return ok

func test_a_key_held_from_the_last_screen_does_not_start() -> bool:
	var t: TitleScreen = await _open(TITLE)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	t.get_viewport().push_input(key)
	await Sim.process_frames(3)
	# Nor does it reach the sandbox behind, whose Esc would open the board.
	var ok: bool = Sim.tree().current_scene == t and not t.started
	await _close()
	return ok

func test_new_game_opens_pilot_select_first() -> bool:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ENTER
	var now: Node = await _press(key)
	var ok: bool = not PlayerProfile.has_pilot() and now is JobBoard and now.pilot_select.visible
	await _close()
	return ok

func test_best_score_matches_the_save() -> bool:
	var before := Wallet.best_pay
	SaveGame.write_section("best_pay", 0)
	Wallet.load_saved()
	var t: TitleScreen = await _open(TITLE)
	var ok: bool = t.best_label.text.ends_with(TitleScreen.NO_SCORE)
	await _close()
	SaveGame.write_section("best_pay", 840)
	Wallet.load_saved()
	t = await _open(TITLE)
	ok = ok and Wallet.best_pay == 840 and t.best_label.text.ends_with(" 840")
	await _close()
	Wallet.best_pay = before
	Wallet.save()
	return ok

func test_payout_keeps_the_best_single_job() -> bool:
	var before := Wallet.best_pay
	var balance := Wallet.balance
	Wallet.best_pay = 0
	var scale: GradeScale = load("res://data/jobs/grade_scale.tres")
	var pays: Array[int] = []
	for letter in ["A", "C"]:
		var r := JobResult.new()
		r.job = load("res://data/jobs/test_job.tres")
		r.letter = letter
		Payout.settle(r, scale)
		pays.append(r.pay)
	var ok: bool = pays[0] > pays[1] and int(SaveGame.read_section("best_pay", 0)) == pays[0]
	Wallet.best_pay = before
	Wallet.balance = balance
	Wallet.save()
	return ok

func test_backdrop_loads_and_orbits() -> bool:
	var t: TitleScreen = await _open(TITLE)
	var b := t.backdrop
	var ok: bool = b.backdrop != null and b.focus_node() != null and b.camera.current
	for layer in b.backdrop.find_children("*", "CanvasLayer", true, false):
		ok = ok and not layer.visible
	var from := b.camera.global_position
	await Sim.process_frames(30)
	var to := b.camera.global_position
	var at := b.focus_node().global_position
	ok = ok and from.distance_to(to) > 0.5 and absf(Vector2(from.x - at.x, from.z - at.z).length() - Vector2(to.x - at.x, to.z - at.z).length()) < 5.0
	await _close()
	return ok

func test_esc_on_the_board_returns_to_the_title() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	var b: JobBoard = await _open(BOARD)
	var ok: bool = b is JobBoard and not b.pilot_select.visible
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	b.get_viewport().push_input(esc)
	await Sim.process_frames(3)
	ok = ok and Sim.tree().current_scene is TitleScreen
	await _close()
	return ok
