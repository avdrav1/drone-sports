extends RefCounted
# Story 23.1: every action has a button. The pad layout from the Epic 23 table:
# each action a player needs is bound, no two actions share a button within one
# context (bar send_lap and tag_unit), Start pauses a job in flight, and the
# flight sticks are as they were.

const Sim = preload("res://tests/sim.gd")

const FLY: Array[StringName] = [&"pitch_forward", &"pitch_back", &"roll_left", &"roll_right",
	&"throttle_up", &"throttle_down", &"yaw_left", &"yaw_right"]
## Actions live at the same time, per context.
const CONTEXTS := {
	"flight": [&"ui_accept", &"ui_cancel", &"pause", &"cycle_camera", &"toggle_map", &"toggle_help",
		&"reset_drone", &"cycle_preset", &"cycle_weather", &"toggle_readout"],
	"command view": [&"ui_cancel", &"pause", &"cycle_camera", &"toggle_map", &"toggle_help",
		&"drop_in", &"prev_drone", &"next_drone", &"send_lap", &"tag_unit"],
	"menus": [&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right"],
}
## The table's buttons (JoyButton indices).
const LAYOUT := {
	&"ui_accept": JOY_BUTTON_A, &"ui_cancel": JOY_BUTTON_B, &"drop_in": JOY_BUTTON_A,
	&"send_lap": JOY_BUTTON_X, &"tag_unit": JOY_BUTTON_X, &"cycle_camera": JOY_BUTTON_Y,
	&"toggle_map": JOY_BUTTON_BACK, &"pause": JOY_BUTTON_START,
	&"prev_drone": JOY_BUTTON_LEFT_SHOULDER, &"next_drone": JOY_BUTTON_RIGHT_SHOULDER,
	&"toggle_help": JOY_BUTTON_DPAD_UP, &"reset_drone": JOY_BUTTON_DPAD_DOWN,
	&"cycle_preset": JOY_BUTTON_DPAD_LEFT, &"cycle_weather": JOY_BUTTON_DPAD_RIGHT,
	&"toggle_readout": JOY_BUTTON_LEFT_STICK,
}
## Mode 2, as before Epic 23: [axis, value].
const AXES := {
	&"throttle_up": [JOY_AXIS_LEFT_Y, -1.0], &"throttle_down": [JOY_AXIS_LEFT_Y, 1.0],
	&"yaw_left": [JOY_AXIS_LEFT_X, -1.0], &"yaw_right": [JOY_AXIS_LEFT_X, 1.0],
	&"pitch_forward": [JOY_AXIS_RIGHT_Y, -1.0], &"pitch_back": [JOY_AXIS_RIGHT_Y, 1.0],
	&"roll_left": [JOY_AXIS_RIGHT_X, -1.0], &"roll_right": [JOY_AXIS_RIGHT_X, 1.0],
}

## Pad inputs bound to `action`, as "button 3" or "axis 1-".
func _pad(action: StringName) -> Array[String]:
	var out: Array[String] = []
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			out.append("button %d" % e.button_index)
		elif e is InputEventJoypadMotion:
			out.append("axis %d%s" % [e.axis, "-" if e.axis_value < 0 else "+"])
	return out

func _start_job_actions() -> Array:
	return ControlsHelp.GROUPS[-1][1].map(func(row): return row[0][0])

func test_every_action_has_a_pad_binding() -> bool:
	var ok := true
	var skipped := _start_job_actions() + [&"toggle_mute"]
	for a in ControlsHelp.listed_actions():
		if a in skipped:
			continue
		if _pad(a).is_empty():
			print("        no pad binding: %s" % a)
			ok = false
	return ok and &"prev_drone" in ControlsHelp.listed_actions() and &"pause" in ControlsHelp.listed_actions()

func test_buttons_match_the_layout() -> bool:
	var ok := true
	for a in LAYOUT:
		if not "button %d" % LAYOUT[a] in _pad(a):
			print("        %s is not on button %d: %s" % [a, LAYOUT[a], _pad(a)])
			ok = false
	return ok

func test_no_button_does_two_things_in_one_context() -> bool:
	var ok := true
	for context in CONTEXTS:
		var owner := {}
		for a in (FLY if context != "menus" else []) + CONTEXTS[context]:
			for b in _pad(a):
				if owner.has(b) and not ([owner[b], a] in [[&"send_lap", &"tag_unit"], [&"tag_unit", &"send_lap"]]):
					print("        %s: %s and %s share %s" % [context, owner[b], a, b])
					ok = false
				owner[b] = a
	return ok

func test_flight_sticks_unchanged() -> bool:
	var ok := true
	for a in AXES:
		ok = ok and _pad(a) == ["axis %d%s" % [AXES[a][0], "-" if AXES[a][1] < 0 else "+"]] \
			and is_equal_approx(InputMap.action_get_deadzone(a), 0.2)
	return ok

func _button(node: Node, index: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = index
	ev.pressed = true
	node.get_viewport().push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	node.get_viewport().push_input(up)
	# Prompts name pad buttons after this (Story 23.2); later tests expect keys.
	InputPrompt.use_keys()

func _job(path: String) -> Node:
	var s: Node = load(path).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	Sim.add(s)
	return s

func test_start_pauses_a_live_job_and_no_longer_resets() -> bool:
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	var off_reset := not InputMap.event_is_action(start, &"reset_drone")
	var scene := _job("res://scenes/jobs/sample_delivery.tscn")
	await Sim.process_frames(3)
	var runner: JobRunner = scene.get_node("JobRunner")
	var left := [false]
	runner.job_left.connect(func(): left[0] = true)
	# Start in the briefing neither leaves nor pauses.
	_button(scene, JOY_BUTTON_START)
	await Sim.process_frames(1)
	var briefing_kept: bool = runner.state == JobRunner.State.BRIEFING and not left[0] and runner.leave_dialog == null
	runner.launch(true)
	while runner.state == JobRunner.State.COUNTDOWN:
		await Sim.physics_frames(1)
	var live := runner.state == JobRunner.State.LIVE
	_button(scene, JOY_BUTTON_START)
	await Sim.process_frames(1)
	var paused: bool = runner.leave_dialog != null and runner.leave_dialog.visible and scene.get_tree().paused \
		and not left[0]
	runner.leave_dialog.canceled.emit()
	var resumed: bool = not scene.get_tree().paused and runner.state == JobRunner.State.LIVE
	scene.free()
	if not (off_reset and briefing_kept and live and paused and resumed):
		print("        off_reset %s briefing %s live %s paused %s resumed %s" % [off_reset, briefing_kept, live, paused, resumed])
	return off_reset and briefing_kept and live and paused and resumed

func test_a_launches_a_fleet_job_without_dropping_in() -> bool:
	var scene := _job("res://scenes/jobs/fleet_race.tscn")
	await Sim.process_frames(3)
	var runner: JobRunner = scene.get_node("JobRunner")
	var view: CommandView = scene.get_node("CommandView")
	var briefing := runner.state == JobRunner.State.BRIEFING
	_button(scene, JOY_BUTTON_A)
	await Sim.process_frames(1)
	var ok: bool = briefing and runner.state == JobRunner.State.COUNTDOWN and view.flown == null
	scene.free()
	return ok
