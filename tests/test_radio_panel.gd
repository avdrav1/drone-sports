extends RefCounted
# Story 17.7: radio panel. Urgent lines cut in, the rest queue, stale chatter is
# dropped, chatter keeps its gap, a line opens with static and its speaker's
# chirp and face, and the panel stays clear of the radar, objectives and race HUD.

const Sim = preload("res://tests/sim.gd")

func _radio(gap := 6.0) -> BarkBox:
	var b := Bark.new()
	b.seed = 1
	Sim.add(b)
	var box := BarkBox.new()
	box.bark = b
	box.chatter_gap = gap
	Sim.add(box)
	return box

func _free(box: BarkBox) -> void:
	box.bark.free()
	box.free()

func _line(event: StringName, text: String, id := &"marlo") -> Dictionary:
	return {"id": id, "event": event, "text": text, "face": &"neutral"}

## Frames until `box` shows a line other than `line`, up to `limit`.
func _until_changed(box: BarkBox, line: Dictionary, limit: int) -> int:
	var frames := 0
	while box.current == line and frames < limit:
		await Sim.process_frames(1)
		frames += 1
	return frames

func test_warning_replaces_chatter_at_once() -> bool:
	var box := _radio()
	var chat := _line(&"gate_passed", "Clean gate, keep it up.")
	box.bark.said.emit(chat)
	await Sim.process_frames(2)
	var chatting: bool = box.current == chat and box.typing()
	box.bark.said.emit(_line(&"warning", "Heads up!", &"dot"))
	var ok: bool = chatting and box.current.event == &"warning" and box.current.id == &"dot" and box.typing()
	_free(box)
	return ok

func test_two_chatter_lines_play_one_after_the_other() -> bool:
	var box := _radio(0.0)
	var a := _line(&"gate_passed", "One.")
	var b := _line(&"gate_passed", "Two.", &"rin")
	box.bark.said.emit(a)
	box.bark.said.emit(b)
	var first: bool = box.current == a and box.queue.size() == 1
	var frames := await _until_changed(box, a, 240)
	# The second waits until the first has typed out and had its beat.
	var waited := frames / 60.0
	var ok: bool = first and box.current == b and box.queue.is_empty() \
		and waited >= a.text.length() / box.type_rate + box.beat - 0.05 and waited < box.stale_after
	_free(box)
	return ok

func test_stale_chatter_is_dropped() -> bool:
	var box := _radio(6.0)
	var a := _line(&"gate_passed", "One.")
	var b := _line(&"gate_passed", "Two.", &"rin")
	box.bark.said.emit(a)
	box.bark.said.emit(b)
	var heard := [box.current]
	for i in 60 * 5:
		await Sim.process_frames(1)
		if box.current != heard.back():
			heard.append(box.current)
	var ok: bool = heard == [a] and box.queue.is_empty()
	_free(box)
	return ok

func test_chatter_keeps_its_gap() -> bool:
	var box := _radio(2.0)
	box.stale_after = 10.0
	var lines := [_line(&"gate_passed", "One."), _line(&"gate_passed", "Two."), _line(&"gate_passed", "Three.")]
	for l in lines:
		box.bark.said.emit(l)
	var starts := [0]
	var shown: Dictionary = box.current
	for i in 60 * 6:
		await Sim.process_frames(1)
		if box.current != shown:
			shown = box.current
			starts.append(i + 1)
	var ok := starts.size() == 3
	for i in range(1, starts.size()):
		ok = ok and starts[i] - starts[i - 1] >= 2.0 * 60 - 1
	_free(box)
	return ok

func test_other_lines_wait_their_turn() -> bool:
	var box := _radio()
	var brief := _line(&"briefing", "Package is at the yard, take it slow.")
	var order := _line(&"order", "On my way.", &"bea")
	box.bark.said.emit(brief)
	box.bark.said.emit(order)
	var waiting: bool = box.current == brief and box.queue.size() == 1
	var frames := await _until_changed(box, brief, 300)
	var ok: bool = waiting and box.current == order and frames / 60.0 >= brief.text.length() / box.type_rate
	_free(box)
	return ok

func test_line_opens_with_static_chirp_face_and_role() -> bool:
	SaveGame.write_section("roster", {})
	Roster.load_saved()
	var box := _radio()
	var saved: Dictionary = Bark.lines_of(&"marlo")
	Bark._cache[&"marlo"] = JSON.parse_string('{"briefing": {"active": [{"text": "Grim line.", "face": "worried"}]}}')
	Sfx.clear_log()
	var said := box.bark.say(&"briefing", &"marlo")
	Bark._cache[&"marlo"] = saved
	var chirps := Sfx.log.filter(func(l): return String(l.id).begins_with("crew_chirp"))
	var ok: bool = box.current == said and box.portrait.expression == &"worried" \
		and box.portrait.size.x >= 72 and Sfx.count(&"radio_static") == 1 and chirps.size() == 1 \
		and Sfx.log[0].id == &"radio_static" and box.name_label.text == "MARLO  ·  SPOTTER" \
		and box.label.text == "Grim line."
	# A queued line chirps when it opens, not when it is said.
	Sfx.clear_log()
	box.bark.say(&"briefing", &"rin")
	ok = ok and Sfx.log.filter(func(l): return String(l.id).begins_with("crew_chirp")).is_empty() and Sfx.count(&"radio_static") == 0
	_free(box)
	return ok

func test_panel_clear_of_radar_objectives_and_race_hud() -> bool:
	var scene: Node = load("res://scenes/jobs/test_race.tscn").instantiate()
	var runner: JobRunner = scene.get_node("JobRunner")
	runner.pays_out = false
	Sim.add(scene)
	await Sim.process_frames(3)
	var radar: Radar = scene.get_node("HUD/Radar")
	var flight: FlightHud = scene.get_node("HUD/Flight")
	var race: RaceHud = scene.get_node("HUD/Race")
	var ok := true
	for s in [Vector2(960, 720), Vector2(1920, 1080)]:
		for c in [radar, flight, race]:
			c.size = s
		var panel := BarkBox.panel_rect(s)
		var others: Array[Rect2] = [radar.rect(), flight.panel_rect(), race.panel_rect()]
		for r in others:
			if panel.intersects(r):
				print("        %s: panel %s overlaps %s" % [s, panel, r])
				ok = false
		ok = ok and Rect2(Vector2.ZERO, s).encloses(panel)
	scene.free()
	return ok
