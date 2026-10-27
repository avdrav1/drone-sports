extends RefCounted
# Story 0.4: controls overlay. Every project action is listed with its key; the
# sandbox opens with the panel up, a flying key hides it and ? brings it back;
# each job shows a one-line hint during its briefing only.
# Story 0.5: Esc leaves a job (asking first in flight), and free flight says
# how to start one.

const Sim = preload("res://tests/sim.gd")

func _project_actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for p in ProjectSettings.get_property_list():
		var n: String = p.name
		if n.begins_with("input/") and not n.begins_with("input/ui_"):
			out.append(StringName(n.trim_prefix("input/")))
	return out

func test_every_action_listed_with_a_key() -> bool:
	var listed := ControlsHelp.listed_actions()
	var ok := _project_actions().size() >= 18
	for a in _project_actions():
		if not a in listed:
			print("        not listed: %s" % a)
			ok = false
	for a in listed:
		ok = ok and InputMap.has_action(a) and ControlsHelp.key_text(a) != ""
	return ok and ControlsHelp.key_text(&"pitch_forward") == "↑" and ControlsHelp.key_text(&"throttle_up") == "W" \
		and ControlsHelp.key_text(&"toggle_help") == "?"

func _key(scene: Node, code: Key, physical := true) -> void:
	var ev := InputEventKey.new()
	if physical:
		ev.physical_keycode = code
	else:
		ev.keycode = code
	ev.pressed = true
	scene.get_viewport().push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	scene.get_viewport().push_input(up)

func test_sandbox_opens_with_help_and_flying_hides_it() -> bool:
	var scene: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	await Sim.process_frames(2)
	var help: ControlsHelp = scene.get_node("HUD/Help")
	var opened := help.visible
	_key(scene, KEY_W)
	await Sim.process_frames(1)
	var hidden := not help.visible
	_key(scene, KEY_SLASH)
	await Sim.process_frames(1)
	var back := help.visible
	_key(scene, KEY_SLASH)
	await Sim.process_frames(1)
	var toggled_off := not help.visible
	scene.free()
	return opened and hidden and back and toggled_off

func test_job_hint_only_during_briefing() -> bool:
	var ok := true
	for f in ["sample_delivery", "test_race", "inspection", "demolition", "rescue"]:
		var scene: Node = load("res://scenes/jobs/%s.tscn" % f).instantiate()
		var runner: JobRunner = scene.get_node("JobRunner")
		runner.pays_out = false
		Sim.add(scene)
		await Sim.process_frames(3)
		var hint: ControlsHint = scene.get_node("HUD/ControlsHint")
		var help: ControlsHelp = scene.get_node("HUD/Help")
		var briefing: bool = hint.visible and hint.text.contains("↑") and hint.text.contains("all keys") and not help.visible
		runner.launch(true)
		await Sim.process_frames(1)
		ok = ok and briefing and not hint.visible
		scene.free()
	return ok

func _job() -> Node:
	var scene: Node = load("res://scenes/jobs/sample_delivery.tscn").instantiate()
	var runner: JobRunner = scene.get_node("JobRunner")
	runner.pays_out = false
	runner.back_scene = ""
	Sim.add(scene)
	return scene

func test_esc_in_briefing_leaves_at_once() -> bool:
	var scene := _job()
	await Sim.process_frames(3)
	var runner: JobRunner = scene.get_node("JobRunner")
	var left := [false]
	runner.job_left.connect(func(): left[0] = true)
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	scene.get_viewport().push_input(ev)
	await Sim.process_frames(1)
	var ok: bool = left[0] and runner.state == JobRunner.State.BRIEFING and runner.result == null \
		and runner.leave_dialog == null
	scene.free()
	return ok

func test_leaving_in_flight_asks_then_fails() -> bool:
	var scene := _job()
	await Sim.process_frames(3)
	var runner: JobRunner = scene.get_node("JobRunner")
	var left := [false]
	runner.job_left.connect(func(): left[0] = true)
	runner.launch(true)
	runner.request_leave()
	var asked: bool = runner.leave_dialog.visible and scene.get_tree().paused and not left[0] \
		and runner.leave_dialog.dialog_text.contains("failed")
	runner.leave_dialog.canceled.emit()
	var kept: bool = not scene.get_tree().paused and runner.state == JobRunner.State.COUNTDOWN and not left[0]
	runner.request_leave()
	runner.leave_dialog.confirmed.emit()
	await Sim.process_frames(2)
	var ok: bool = asked and kept and left[0] and not scene.get_tree().paused \
		and runner.state == JobRunner.State.FAILED and runner.fail_reason == "left" and runner.results_screen == null
	scene.free()
	return ok

func test_free_flight_says_how_to_start_a_job() -> bool:
	var scene: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	await Sim.process_frames(2)
	var hud: FlightHud = scene.get_node("HUD/Flight")
	var ok: bool = hud.title == "Free flight" and hud.subtitle.contains("J K L H U start a job") \
		and ControlsHelp.hint_line().contains("Esc leave") and &"ui_cancel" in ControlsHelp.listed_actions()
	scene.free()
	return ok
