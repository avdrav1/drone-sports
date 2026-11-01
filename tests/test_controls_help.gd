extends RefCounted
# Story 0.4: controls overlay. Every project action is listed with its key; the
# sandbox opens with the panel up, a flying key hides it and ? brings it back;
# each job shows a one-line hint during its briefing only, while the panel is
# down.
# Story 0.5: Esc leaves a job (asking first in flight), and free flight says
# how to start one.

const Sim = preload("res://tests/sim.gd")
## Every flight: each job, the boss and free flight.
const FLIGHTS := ["res://scenes/jobs/sample_delivery.tscn", "res://scenes/jobs/test_race.tscn",
	"res://scenes/jobs/inspection.tscn", "res://scenes/jobs/demolition.tscn", "res://scenes/jobs/rescue.tscn",
	"res://scenes/jobs/fleet_race.tscn", "res://scenes/jobs/fleet_inspection.tscn",
	"res://scenes/jobs/spotter_drill.tscn", "res://scenes/boss/lattice_job.tscn", "res://scenes/debug_flight.tscn"]

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
		ok = ok and InputMap.has_action(a) and InputPrompt.key_text(a) != ""
	return ok and InputPrompt.key_text(&"pitch_forward") == "↑" and InputPrompt.key_text(&"throttle_up") == "W" \
		and InputPrompt.key_text(&"toggle_help") == "?"

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
		# The panel opens over the briefing and says the same, so the hint waits.
		var under_panel: bool = help.visible and not hint.visible
		help.hide()
		await Sim.process_frames(2)
		var briefing: bool = hint.visible and hint.text.contains("↑") and hint.text.contains("all controls")
		runner.launch(true)
		await Sim.process_frames(2)
		ok = ok and under_panel and briefing and not hint.visible
		scene.free()
	return ok

## Every flight opens with the short controls up: the flying keys and a line of
## the few others. It never covers the drone, the radio or the job panel, at
## 960x720 or 1920x1080; a flying key hides it and ? brings up the whole list.
func test_every_flight_opens_with_the_keys_clear_of_the_drone() -> bool:
	var ok := true
	for path in FLIGHTS:
		for s in [Vector2i(960, 720), Vector2i(1920, 1080)]:
			var view := SubViewport.new()
			view.size = s
			Sim.add(view)
			var scene: Node = load(path).instantiate()
			var runner: JobRunner = scene.get_node_or_null("JobRunner")
			if runner:
				runner.pays_out = false
				runner.back_scene = ""
			view.add_child(scene)
			await Sim.process_frames(32)
			var help: ControlsHelp = scene.get_node("HUD/Help")
			var r := help.get_global_rect()
			var keys := true
			for a in ControlsHelp.FLY_ACTIONS:
				keys = keys and help.find_children("Key_%s" % a, "KeyCap", true, false).any(func(c): return c.is_visible_in_tree())
			var line := _labels(help)
			var short: bool = not help.full and line.contains("camera") and line.contains("leave") \
				and line.contains("all controls") and not line.contains("Debug readout")
			var keep: Array[Rect2] = [BarkBox.panel_rect(Vector2(s)), BarkBox.face_rect(Vector2(s))]
			var flight := scene.get_node_or_null("HUD/Flight") as FlightHud
			if flight:
				keep.append(flight.panel_rect())
			var drones := help.drone_rects()
			keep.append_array(drones)
			var clear := not drones.is_empty() and Rect2(Vector2.ZERO, Vector2(s)).encloses(r)
			for k in keep:
				clear = clear and not r.intersects(k)
			# The drone itself, apart from its padded rect: its middle is off the panel.
			var cam := view.get_camera_3d()
			var rig := cam.get_parent() as CameraRig
			if rig and rig.target and rig.view != CameraRig.View.FPV:
				clear = clear and not r.grow(24.0).has_point(cam.unproject_position(rig.target.global_position))
			var opened: bool = help.visible and keys and short and clear
			_key(scene, KEY_W)
			await Sim.process_frames(1)
			var hidden := not help.visible
			_key(scene, KEY_SLASH)
			await Sim.process_frames(2)
			var full: bool = help.visible and help.full and _labels(help).contains("Debug readout")
			if not (opened and hidden and full):
				print("        %s at %s: open %s keys %s short %s clear %s hidden %s full %s, panel %s, drones %s" % [
					path.get_file(), s, help.visible, keys, short, clear, hidden, full, r, drones])
				ok = false
			view.free()
	return ok

## The panel moves when the window shrinks and when the camera view changes,
## and stays clear of the drone each time.
func test_panel_moves_with_the_window_and_the_view() -> bool:
	var view := SubViewport.new()
	view.size = Vector2i(1920, 1080)
	Sim.add(view)
	var scene: Node = load("res://scenes/debug_flight.tscn").instantiate()
	view.add_child(scene)
	await Sim.process_frames(5)
	var help: ControlsHelp = scene.get_node("HUD/Help")
	var big := help.get_global_rect()
	view.size = Vector2i(960, 720)
	await Sim.process_frames(5)
	var small := help.get_global_rect()
	var ok := _clear(help, small, Vector2(960, 720)) and small != big
	var rig: CameraRig = scene.get_node("CameraRig")
	var before := rig.view
	rig.cycle()
	await Sim.process_frames(5)
	ok = ok and rig.view != before and _clear(help, help.get_global_rect(), Vector2(960, 720)) and help.visible
	if not ok:
		print("        1920: %s, 960: %s, after the view: %s" % [big, small, help.get_global_rect()])
	view.free()
	return ok

func _clear(help: ControlsHelp, r: Rect2, s: Vector2) -> bool:
	return Rect2(Vector2.ZERO, s).encloses(r) and not help.drone_rects().any(func(d: Rect2): return r.intersects(d))

func _labels(node: Node) -> String:
	var out: Array[String] = []
	for l in node.find_children("*", "Label", true, false):
		if l.is_visible_in_tree():
			out.append(l.text)
	return "\n".join(out)

## The panel's labels use a font that draws arrows on top of the default one,
## as a variation of it: a duplicated FontFile shared the default font's glyph
## cache, so the two overwrote each other's glyphs and the panel's text, and
## text elsewhere, came out garbled ("Ike" for "the").
func test_arrow_font_is_a_variation_of_the_default() -> bool:
	var f := ControlsHelp.font() as FontVariation
	return f != null and f.base_font == ThemeDB.fallback_font and f.fallbacks.has(ControlsHelp.ARROW_FONT) \
		and f.has_char("↑".unicode_at(0)) and f.has_char("e".unicode_at(0))

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

## The arrow keys used to vanish on the web: the default font has no arrow
## glyphs. The panel draws every flying key as a key cap, the arrows as shapes,
## and any label that names an arrow key uses a font that has them.
func test_flying_keys_show_as_key_caps_with_arrows() -> bool:
	var scene: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	await Sim.process_frames(2)
	var help: ControlsHelp = scene.get_node("HUD/Help")
	var ok := true
	for a in ControlsHelp.FLY_ACTIONS:
		var cap := help.find_child("Key_%s" % a, true, false) as KeyCap
		ok = ok and cap != null and cap.text == InputPrompt.key_text(a)
	for a in [&"pitch_forward", &"pitch_back", &"roll_left", &"roll_right"]:
		var cap := help.find_child("Key_%s" % a, true, false) as KeyCap
		ok = ok and cap != null and cap.is_arrow()
	var font := ControlsHelp.font()
	for c in "↑↓←→":
		ok = ok and font.has_char(c.unicode_at(0))
	var said := false
	for l in help.find_children("*", "Label", true, false):
		said = said or (l as Label).text.begins_with("ARROW KEYS")
	scene.free()
	var job: Node = load("res://scenes/jobs/test_race.tscn").instantiate()
	(job.get_node("JobRunner") as JobRunner).pays_out = false
	Sim.add(job)
	await Sim.process_frames(2)
	var hint: ControlsHint = job.get_node("HUD/ControlsHint")
	var hint_ok := hint.get_theme_font("font").has_char("↑".unicode_at(0))
	job.free()
	return ok and said and hint_ok
