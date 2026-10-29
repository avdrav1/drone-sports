extends RefCounted
# Story 23.5: Start pauses a live job with stay focused, and the pad in hand
# going away pauses it too. Reconnecting toasts and never resumes on its own.

const Sim = preload("res://tests/sim.gd")
const JOB := "res://scenes/jobs/sample_delivery.tscn"

func _job() -> Node:
	var s: Node = load(JOB).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	Sim.add(s)
	return s

func _live(s: Node) -> JobRunner:
	var runner: JobRunner = s.get_node("JobRunner")
	await Sim.process_frames(2)
	runner.launch(true)
	while runner.state != JobRunner.State.LIVE:
		await Sim.physics_frames(1)
	return runner

## Presses and releases a pad button, as pad `device`.
func _button(node: Node, index: JoyButton, device := 0) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = index
	ev.pressed = true
	node.get_viewport().push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	node.get_viewport().push_input(up)

func _toasts(runner: JobRunner) -> Array:
	return runner.get_children().filter(func(c): return c is Toast)

## Leaves the tree unpaused and prompts on keys for the tests after.
func _done(s: Node) -> void:
	s.get_tree().paused = false
	InputPrompt.use_keys()
	s.free()

func test_start_pauses_with_stay_focused_and_a_resumes() -> bool:
	var s := _job()
	var runner := await _live(s)
	_button(s, JOY_BUTTON_START)
	await Sim.process_frames(1)
	var dialog := runner.leave_dialog
	var paused: bool = dialog != null and dialog.visible and s.get_tree().paused
	var focused: bool = paused and dialog.get_cancel_button().has_focus() \
		and not dialog.dialog_text.contains("disconnected")
	_button(s, JOY_BUTTON_A)
	await Sim.process_frames(1)
	var resumed: bool = not s.get_tree().paused and not dialog.visible and runner.state == JobRunner.State.LIVE
	_done(s)
	if not (paused and focused and resumed):
		print("        paused %s focused %s resumed %s" % [paused, focused, resumed])
	return paused and focused and resumed

func test_pad_in_hand_disconnecting_pauses_a_live_job() -> bool:
	var s := _job()
	var runner := await _live(s)
	InputPrompt.use_pad(0, "Xbox Wireless Controller")
	Input.joy_connection_changed.emit(0, false)
	await Sim.process_frames(1)
	var dialog := runner.leave_dialog
	var paused: bool = dialog != null and dialog.visible and s.get_tree().paused \
		and dialog.dialog_text.begins_with("Controller disconnected") and dialog.get_cancel_button().has_focus() \
		and runner.state == JobRunner.State.LIVE
	_done(s)
	return paused

func test_another_pad_or_the_keyboard_disconnecting_does_nothing() -> bool:
	var s := _job()
	var runner := await _live(s)
	InputPrompt.use_pad(0, "")
	Input.joy_connection_changed.emit(1, false)
	await Sim.process_frames(1)
	var other: bool = runner.leave_dialog == null and not s.get_tree().paused
	InputPrompt.use_keys()
	Input.joy_connection_changed.emit(0, false)
	await Sim.process_frames(1)
	var keys: bool = runner.leave_dialog == null and not s.get_tree().paused
	_done(s)
	return other and keys

func test_disconnecting_in_the_briefing_does_nothing() -> bool:
	var s := _job()
	var runner: JobRunner = s.get_node("JobRunner")
	await Sim.process_frames(2)
	InputPrompt.use_pad(0, "")
	Input.joy_connection_changed.emit(0, false)
	await Sim.process_frames(1)
	var kept: bool = runner.state == JobRunner.State.BRIEFING and runner.leave_dialog == null and not s.get_tree().paused
	_done(s)
	return kept

func test_disconnecting_on_the_board_does_nothing() -> bool:
	var board: Node = Sim.add(load("res://scenes/ui/job_board.tscn").instantiate())
	await Sim.process_frames(2)
	InputPrompt.use_pad(0, "")
	Input.joy_connection_changed.emit(0, false)
	await Sim.process_frames(1)
	var kept := not board.get_tree().paused and board.is_inside_tree()
	_done(board)
	return kept

func test_reconnecting_toasts_and_stays_paused() -> bool:
	var s := _job()
	var runner := await _live(s)
	InputPrompt.use_pad(0, "")
	Input.joy_connection_changed.emit(0, false)
	await Sim.process_frames(1)
	Input.joy_connection_changed.emit(0, true)
	# Well past the toast: still paused, still asking.
	await Sim.process_frames(200)
	var dialog := runner.leave_dialog
	var still: bool = s.get_tree().paused and dialog.visible and runner.state == JobRunner.State.LIVE
	var toast := _toasts(runner)
	Input.joy_connection_changed.emit(0, true)
	await Sim.process_frames(1)
	var shown := _toasts(runner)
	var line: bool = shown.size() == 1 and shown[0].label.text == "Controller connected"
	_done(s)
	if not (still and toast.is_empty() and line):
		print("        still %s faded %s line %s" % [still, toast.is_empty(), line])
	return still and toast.is_empty() and line
