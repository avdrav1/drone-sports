extends RefCounted
# Story 23.2: prompts follow the device. After a pad button every prompt names
# pad buttons, after a key every prompt names keys, a PlayStation pad reads
# "Cross" where an Xbox pad reads "A", and no script hard-codes a key name in
# player-facing text.

const Sim = preload("res://tests/sim.gd")

func _parse(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	if ev is InputEventJoypadButton or ev is InputEventKey:
		var up: InputEvent = ev.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
	await Sim.process_frames(2)

## R3 by default: bound to nothing, so the press only changes the device.
func _pad_button(index := JOY_BUTTON_RIGHT_STICK) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = index
	ev.pressed = true
	await _parse(ev)

func _key(code := KEY_SHIFT) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	await _parse(ev)

func _stick(value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = JOY_AXIS_RIGHT_Y
	ev.axis_value = value
	await _parse(ev)
	var rest := InputEventJoypadMotion.new()
	rest.device = 0
	rest.axis = JOY_AXIS_RIGHT_Y
	await _parse(rest)

func _labels(node: Node) -> String:
	var out: Array[String] = []
	for l in node.find_children("*", "Label", true, false):
		if l.is_visible_in_tree():
			out.append(l.text)
	return "\n".join(out)

## Every prompt on screen in a briefing, free flight, the board, the map, a
## cutscene and the sound dialog, as one string per place.
func _prompts(job: Node, free: Node, board: JobBoard, sound: SoundDialog) -> Dictionary:
	var help: ControlsHelp = free.get_node("HUD/Help")
	return {
		"hint": (job.get_node("HUD/ControlsHint") as Label).text,
		"briefing": (job.get_node("JobRunner") as JobRunner).state_label.text,
		"help": _labels(help),
		"free": (free.get_node("HUD/Flight") as FlightHud).subtitle,
		"board": (board.find_child("Controls", true, false) as Label).text,
		"back": (board.find_child("BackHint", true, false) as Label).text,
		"map": MapScreen.close_text(),
		"skip": CutscenePlayer.skip_text(),
		"mute": sound.mute.text,
	}

func test_prompts_follow_the_last_device() -> bool:
	await _key()
	var job: Node = load("res://scenes/jobs/sample_delivery.tscn").instantiate()
	(job.get_node("JobRunner") as JobRunner).pays_out = false
	Sim.add(job)
	var free: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	PlayerProfile.choose_pilot(PlayerProfile.pilots()[0].id)
	var board: JobBoard = Sim.add(load("res://scenes/ui/job_board.tscn").instantiate())
	var sound: SoundDialog = Sim.add(SoundDialog.new())
	await Sim.process_frames(3)
	var keys := _prompts(job, free, board, sound)
	var changes := [0]
	InputPrompt.device_changed.connect(func(_pad): changes[0] += 1)
	await _pad_button()
	var pad := _prompts(job, free, board, sound)
	var on_pad := InputPrompt.pad
	await _key()
	var back := _prompts(job, free, board, sound)
	var ok: bool = on_pad and not InputPrompt.pad and changes[0] == 2 and back == keys
	var expect_keys := {
		"hint": ["↑↓←→ move", "W / S height", "A / D turn", "C camera", "M map", "Esc leave", "? all controls"],
		"briefing": ["press Enter to launch"],
		"help": ["Shift+Tab", "Esc", "Enter", "J\n"],
		"free": ["J K L H U start a job"],
		"board": ["↑/↓  MENU", "←/→  JOBS", "ENTER  SELECT", "ESC  BACK"],
		"back": ["Esc to go back"],
		"map": ["M TO CLOSE"],
		"skip": ["Any key"],
		"mute": ["Mute (N)"],
	}
	var expect_pad := {
		"hint": ["R stick move", "L stick height and turn", "Y camera", "Back map", "B leave", "D-pad ↑ all controls"],
		"briefing": ["press A to launch"],
		"help": ["R stick ↑↓", "LB", "RB", "Start", "Back", "D-pad ↓", "L3", "Any flying stick"],
		"free": ["B job board"],
		"board": ["D-PAD ↑↓  MENU", "D-PAD ←→  JOBS", "A  SELECT", "B  BACK"],
		"back": ["B to go back"],
		"map": ["BACK TO CLOSE"],
		"skip": ["Any button"],
		"mute": ["Mute"],
	}
	for place in expect_keys:
		for s in expect_keys[place]:
			if not keys[place].contains(s):
				print("        keys %s lacks %s: %s" % [place, s, keys[place]])
				ok = false
		for s in expect_pad[place]:
			if not pad[place].contains(s):
				print("        pad %s lacks %s: %s" % [place, s, pad[place]])
				ok = false
	# No key names left on the pad, and no keyboard-only rows.
	for place in pad:
		for k in ["Enter", "Esc", "Shift+Tab", "↑↓←→", "W / S", "(N)", "Any key", "Delivery", "start a job"]:
			if pad[place].contains(k):
				print("        pad %s still says %s" % [place, k])
				ok = false
	for n in [job, free, board, sound]:
		n.free()
	return ok

## A device change in the frame the panel arrives, before its first layout,
## still leaves it centred on screen.
func test_help_stays_centred_when_the_device_changes() -> bool:
	await _key()
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	Sim.add(view)
	var free: Node = load("res://scenes/debug_flight.tscn").instantiate()
	view.add_child(free)
	var help: ControlsHelp = free.get_node("HUD/Help")
	InputPrompt.use_pad(0, "Xbox Controller")
	await Sim.process_frames(3)
	var rect := help.get_global_rect()
	var ok := rect.get_center().distance_to(Vector2(640, 360)) < 2.0 and Rect2(0, 0, 1280, 720).encloses(rect)
	if not ok:
		print("        help rect %s on 1280x720" % rect)
	await _key()
	view.free()
	return ok

func test_stick_under_the_deadzone_does_not_count() -> bool:
	await _key()
	await _stick(0.1)
	var still_keys := not InputPrompt.pad
	await _stick(-0.9)
	var pad := InputPrompt.pad
	await _key()
	return still_keys and pad and not InputPrompt.pad

func test_pad_family_names_the_buttons() -> bool:
	var names := {}
	for joy in ["Xbox Wireless Controller", "PS5 Controller", "Sony DualSense", "Nintendo Switch Pro Controller", "Generic USB Gamepad"]:
		InputPrompt.use_pad(0, joy)
		names[joy] = [InputPrompt.text(&"ui_accept"), InputPrompt.text(&"prev_drone"), InputPrompt.text(&"pause")]
	var job: Node = load("res://scenes/jobs/sample_delivery.tscn").instantiate()
	(job.get_node("JobRunner") as JobRunner).pays_out = false
	Sim.add(job)
	await Sim.process_frames(3)
	var label := (job.get_node("JobRunner") as JobRunner).state_label
	InputPrompt.use_pad(0, "Xbox 360 Controller")
	var xbox := label.text
	InputPrompt.use_pad(0, "PS4 Controller")
	var ps := label.text
	InputPrompt.use_keys()
	job.free()
	var ok: bool = names["Xbox Wireless Controller"] == ["A", "LB", "Start"] \
		and names["PS5 Controller"] == ["Cross", "L1", "Options"] and names["Sony DualSense"][0] == "Cross" \
		and names["Nintendo Switch Pro Controller"] == ["B", "L", "+"] \
		and names["Generic USB Gamepad"] == names["Xbox Wireless Controller"] \
		and xbox.contains("press A to launch") and ps.contains("press Cross to launch")
	if not ok:
		print("        %s / %s / %s" % [names, xbox, ps])
	return ok

func test_lattice_hint_names_the_tag_button() -> bool:
	InputPrompt.use_keys()
	var s: Node = load("res://scenes/boss/lattice_job.tscn").instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	runner.confirm_risk = false
	Sim.add(s)
	await Sim.process_frames(2)
	runner.launch(true)
	while runner.state != JobRunner.State.LIVE:
		await Sim.physics_frames(1)
	var hud: LatticeHud = s.find_children("*", "LatticeHud", true, false)[0]
	var keys := hud.lines()
	InputPrompt.use_pad(0, "PS5 Controller")
	var ps := hud.lines()
	InputPrompt.use_keys()
	s.free()
	return keys.contains("T tags a head") and ps.contains("Square tags a head")

## Player-facing strings name keys through InputPrompt, never by hand. The key
## table in InputPrompt is the one place key names live.
func test_no_hard_coded_key_names() -> bool:
	var names := RegEx.create_from_string("(?i)\\b(enter|esc|space|click)\\b")
	var literal := RegEx.create_from_string("([&^]?)\"((?:[^\"\\\\]|\\\\.)*)\"")
	var allowed := ["res://scripts/ui/input_prompt.gd:const KEY_NAMES"]
	var ok := true
	var files := _scripts("res://scripts")
	for path in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code := _code(lines[i])
			if allowed.any(func(a): return a == "%s:%s" % [path, code.substr(0, a.length() - path.length() - 1)]):
				continue
			for m in literal.search_all(code):
				if m.get_string(1) == "" and names.search(m.get_string(2)):
					print("        %s:%d %s" % [path, i + 1, m.get_string(0)])
					ok = false
	return ok and files.size() > 100

func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out

# The line without its comment.
func _code(line: String) -> String:
	var quote := ""
	for i in line.length():
		var c := line[i]
		if quote == "" and c == "#":
			return line.substr(0, i)
		if c == "\"" and (i == 0 or line[i - 1] != "\\"):
			quote = "" if quote == "\"" else ("\"" if quote == "" else quote)
	return line
