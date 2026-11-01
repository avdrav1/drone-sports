extends RefCounted
# Story 26.4: radio text you can read. Lines and names draw at 32 px (a whole
# multiple of the pixel font's 16), the face is 192 px, a line holds for
# max(5, 2 + 0.07 N) s after typing when nothing waits, urgent lines still cut in, and the bigger panel
# stays clear of the HUD, the controls hint, the Lattice's line and the board's
# controls at 960x720 and 1920x1080.

const Sim = preload("res://tests/sim.gd")
const SIZES: Array[Vector2] = [Vector2(960, 720), Vector2(1920, 1080)]

func _radio() -> BarkBox:
	var b := Bark.new()
	b.seed = 1
	Sim.add(b)
	var box := BarkBox.new()
	box.bark = b
	Sim.add(box)
	return box

func _free(box: BarkBox) -> void:
	box.bark.free()
	box.free()

func _line(event: StringName, text: String, id := &"sanjaya") -> Dictionary:
	return {"id": id, "event": event, "text": text, "face": &"neutral"}

func test_lines_and_names_draw_at_32_px() -> bool:
	var box := _radio()
	var ok: bool = BarkBox.FONT_SIZE == 32 and BarkBox.FONT_SIZE % 16 == 0 \
		and box.label.get_theme_font_size("font_size") == 32 and box.name_label.get_theme_font_size("font_size") == 32 \
		and box.portrait.size == Vector2(192, 192) and BarkBox.FACE == 192.0
	_free(box)
	return ok

## Seconds `box` keeps showing its line after it has typed out, stepped in 1/60 s.
func _held(box: BarkBox) -> float:
	box.skip()
	var t := 0.0
	while box.showing() and t < 30.0:
		box._process(1.0 / 60.0)
		t += 1.0 / 60.0
	return t

func test_a_line_holds_for_its_length() -> bool:
	var ok := true
	for text in ["Go.", "Wide into the turn, tight out of it. That's the trick, pilot.",
			"I knew it the first time I watched you fly. I just didn't know it'd be this. Every gate, every one."]:
		var box := _radio()
		box.bark.said.emit(_line(&"briefing", text))
		var want := maxf(5.0, 2.0 + 0.07 * text.length())
		var held := _held(box)
		if held < want - 0.02 or held > want + 0.1:
			print("        %d chars held %.2f s, want %.2f" % [text.length(), held, want])
			ok = false
		_free(box)
	return ok

func test_urgent_lines_still_cut_in() -> bool:
	var box := _radio()
	box.bark.said.emit(_line(&"briefing", "A long, slow briefing that is still typing out when the warning comes."))
	box._process(0.5)
	box.bark.said.emit(_line(&"warning", "Pull up!", &"nala"))
	var ok: bool = box.current.event == &"warning" and box.current.id == &"nala" and box.typing() and box.label.text == "Pull up!"
	_free(box)
	return ok

func test_face_and_bar_stay_on_screen_and_hold_their_contents() -> bool:
	var ok := true
	for s in SIZES:
		var host := Control.new()
		host.size = s
		Sim.add(host)
		var box := BarkBox.new()
		host.add_child(box)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await Sim.process_frames(1)
		var screen := Rect2(Vector2.ZERO, s)
		var bar := BarkBox.panel_rect(s)
		var tab := BarkBox.face_rect(s)
		# Below the speed gauge's ladder (FlightHud: 60 px either side of mid-height).
		ok = ok and tab.position.y > s.y * 0.5 + 60.0 and screen.encloses(bar) and screen.encloses(tab) and tab.encloses(Rect2(box.portrait.position, box.portrait.size)) \
			and not Rect2(box.label.position, box.label.size).intersects(tab) \
			and not Rect2(box.name_label.position, box.name_label.size).intersects(tab)
		host.free()
	return ok

func test_controls_hint_clear_of_the_radio() -> bool:
	var ok := true
	for path in ["res://scenes/jobs/test_race.tscn", "res://scenes/jobs/sample_delivery.tscn", "res://scenes/jobs/inspection.tscn",
			"res://scenes/jobs/rescue.tscn", "res://scenes/jobs/demolition.tscn"]:
		var scene: Node = load(path).instantiate()
		var hud: Node = scene.get_node("HUD")
		var hint: ControlsHint = hud.get_node("ControlsHint")
		var radar: Radar = hud.get_node_or_null("Radar")
		for s in SIZES:
			# Lay the hint out on a HUD of size `s` without running the job.
			var host := Control.new()
			host.size = s
			var copy: Label = hint.duplicate(0)
			copy.set_script(null)
			host.add_child(copy)
			Sim.add(host)
			await Sim.process_frames(1)
			var text := ControlsHint.wrapped(ControlsHelp.hint_line(), copy.size.x - 4.0, copy.get_theme_font("font"), copy.get_theme_font_size("font_size"))
			copy.text = text
			await Sim.process_frames(1)
			var r := Rect2(copy.position, copy.size)
			var lines := copy.get_line_count() * copy.get_line_height()
			var radar_r := Rect2(s - Vector2(28, 104) - Vector2.ONE * 168, Vector2.ONE * 168) if radar else Rect2()
			# It breaks only between items, never between "Esc" and "leave".
			var whole := copy.get_line_count() == text.count("\n") + 1 and text.contains("Esc leave")
			if r.intersects(BarkBox.panel_rect(s)) or r.intersects(BarkBox.face_rect(s)) or r.intersects(radar_r) \
					or lines > r.size.y or not Rect2(Vector2.ZERO, s).encloses(r) or not whole:
				print("        %s at %s: hint %s" % [path.get_file(), s, r])
				ok = false
			host.free()
		scene.free()
	return ok

func test_the_lattice_line_clear_of_the_radio() -> bool:
	var ok := true
	for s in SIZES:
		var line := ChorusBox.label_rect(s)
		var grid := Rect2(s.x - 104, s.y - 194, 72, 72)
		for r in [BarkBox.panel_rect(s), BarkBox.face_rect(s), grid]:
			if line.intersects(r):
				print("        %s: the Lattice's line %s overlaps %s" % [s, line, r])
				ok = false
		ok = ok and Rect2(Vector2.ZERO, s).encloses(line)
	return ok

## Every control on the board a player can see: its buttons and its job cards.
func _board_controls(board: Node) -> Array[Control]:
	var out: Array[Control] = []
	for c: Control in board.find_children("*", "Control", true, false):
		if c.is_visible_in_tree() and (c is BaseButton or String(c.name).begins_with("Card_")) \
				and c.get_global_rect().size.x > 0.0:
			out.append(c)
	return out

func test_the_board_radio_hangs_clear_of_its_controls() -> bool:
	var ok := true
	for s in SIZES:
		var host := Control.new()
		host.size = s
		Sim.add(host)
		var board: JobBoard = load("res://scenes/ui/job_board.tscn").instantiate()
		host.add_child(board)
		board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await Sim.process_frames(3)
		var controls := _board_controls(board)
		ok = ok and board.radio.at_top and controls.size() >= 6
		for r in [BarkBox.panel_rect(s, true), BarkBox.face_rect(s, true)]:
			ok = ok and Rect2(Vector2.ZERO, s).encloses(r)
			for c in controls:
				var cr := c.get_global_rect()
				if cr.intersects(Rect2(Vector2.ZERO, s)) and r.intersects(cr):
					print("        %s: the board's radio %s covers %s %s" % [s, r, c.name, cr])
					ok = false
		# The header it hangs over fades out while a line is up, then comes back.
		board.bark.said.emit(_line(&"warning", "Wind from the east, pilot."))
		await Sim.process_frames(2)
		var hidden: bool = board._under_radio.size() == 2 and board._under_radio.all(func(c): return c.modulate.a < 0.01)
		board.radio.current = {}
		board.radio.visible = false
		board._process(0.0)
		var back: bool = board._under_radio.all(func(c): return is_equal_approx(c.modulate.a, 1.0))
		if not (hidden and back):
			print("        %s: header hidden %s, back %s" % [s, hidden, back])
			ok = false
		host.free()
	return ok

func test_a_pilot_on_the_radio_has_a_face_and_role() -> bool:
	var box := _radio()
	var pilot: Character = PlayerProfile.pilots()[0]
	box.bark.said.emit(_line(&"briefing", "On the line.", pilot.id))
	var ok: bool = box.portrait.character == pilot and box.name_label.text == ("%s  ·  %s" % [pilot.name, pilot.role]).to_upper()
	_free(box)
	return ok

func test_an_overlong_line_stays_inside_the_bar() -> bool:
	var ok := true
	for s in SIZES:
		var host := Control.new()
		host.size = s
		Sim.add(host)
		var box := BarkBox.new()
		var b := Bark.new()
		box.bark = b
		host.add_child(b)
		host.add_child(box)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await Sim.process_frames(1)
		b.said.emit(_line(&"warning", "This line runs well past anything the crew says today, to see that the bar keeps it inside, not spilling below."))
		box.skip()
		box._layout()
		var bar := BarkBox.panel_rect(s)
		var drawn: float = box.label.get_visible_line_count() * box.label.get_line_height()
		ok = ok and box.label.get_visible_line_count() <= BarkBox.MAX_LINES \
			and box.label.position.y + drawn <= bar.end.y and bar.encloses(Rect2(box.label.position, box.label.size))
		# Every speaker's name and role fits, pilots too.
		for id in Roster.ids() + PlayerProfile.pilots().map(func(p): return p.id):
			var c := BarkBox.speaker(id)
			var name := ("%s  ·  %s" % [c.name, c.role]).to_upper()
			if BarkBox.NAME_FONT.get_string_size(name, 0, -1, BarkBox.FONT_SIZE).x > box.name_label.size.x:
				print("        name too wide at %s: %s" % [s, name])
				ok = false
		host.free()
	return ok
