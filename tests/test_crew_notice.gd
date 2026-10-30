extends RefCounted
# Story 27.7: the crew notice. New paint or a new part leaves a notice that the
# next board says once, a part by Nala while Nala lives; the dead never say
# one. The drone's name shows on the results screen and in the HUD's job
# panel, and a drone with no name shows none. Every new line fits the radio.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"
const SIZES: Array[Vector2] = [Vector2(960, 720), Vector2(1920, 1080)]
const CAST: Array[StringName] = [&"arjuna", &"sanjaya", &"nala", &"bhima", &"sushena", &"drona"]

func _board() -> JobBoard:
	Sim.tree().change_scene_to_file(BOARD)
	await Sim.process_frames(3)
	return Sim.tree().current_scene

func _close() -> void:
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)

## Lines `board` said on `event` since it opened, as {id, text}.
func _said(board: JobBoard, event: StringName) -> Array:
	var out := []
	for id in board.bark.used:
		for t in board.bark.used[id]:
			if t in Bark.pool(id, event):
				out.append({"id": id, "text": t})
	return out

## A part the catalog does not ship, for the length of one test.
func _test_part(kind: StringName) -> Part:
	var p := Part.new()
	p.id = StringName("test_notice_" + kind)
	p.kind = kind
	Hangar.catalog.parts.append(p)
	return p

func _repaint(slot := 0) -> void:
	var l := Hangar.livery(slot)
	l.body_color = Color(0.7, 0.2, 0.1)
	Hangar.set_livery(slot, l)

func test_notices_are_events_and_nala_speaks_on_parts() -> bool:
	var ok := true
	for e in Bark.NOTICES:
		ok = ok and e in Bark.EVENTS and Bark.DEFAULT_FACES.get(e, &"") in CharacterPortrait.EXPRESSIONS
	return ok and &"new_part" in Roster.character(&"nala").speaks_on

func test_a_livery_change_is_said_once_on_the_next_board() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	Bark.moment_times.clear()
	_repaint(2)
	var board: JobBoard = await _board()
	var lines := _said(board, &"new_livery")
	var ok: bool = lines.size() == 1 and Roster.is_alive(lines[0].id) and lines[0].id != &"arjuna" \
		and _said(board, &"hello").is_empty() and Hangar.notices.is_empty()
	await _close()
	# Once: the board after says hello, not the paint again.
	Bark.moment_times.clear()
	board = await _board()
	ok = ok and _said(board, &"new_livery").is_empty() and not _said(board, &"hello").is_empty()
	await _close()
	return ok

func test_a_rename_or_the_same_paint_leaves_no_notice() -> bool:
	var l := Hangar.livery(0)
	Hangar.set_livery(0, l)
	l.drone_name = "Garuda"
	Hangar.set_livery(0, l)
	var ok := Hangar.notices.is_empty()
	# Fitting the part already fitted is no change either.
	ok = ok and Hangar.fit(0, Hangar.part_id(0, &"frame")) and Hangar.notices.is_empty()
	_repaint()
	_repaint()
	return ok and Hangar.notices == [&"new_livery"]

func test_a_part_change_is_said_by_nala_while_nala_lives() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	var props := _test_part(&"props")
	Hangar.fit(1, props.id)
	var board: JobBoard = await _board()
	var lines := _said(board, &"new_part")
	var ok: bool = lines.size() == 1 and lines[0].id == &"nala"
	await _close()
	# Nala gone (and not just now, so the board is not quiet): someone living says it.
	Roster.kill(&"nala")
	Roster.job_done()
	Hangar.fit(1, Hangar.default_part(&"props").id)
	board = await _board()
	lines = _said(board, &"new_part")
	ok = ok and lines.size() == 1 and lines[0].id != &"nala" and Roster.is_alive(lines[0].id) and lines[0].id != &"arjuna"
	await _close()
	Hangar.catalog.parts.erase(props)
	return ok

func test_the_hook_raises_a_notice_and_it_keeps_until_said() -> bool:
	# The hook the hangar page (Story 27.5) can call for a change made any other way.
	Hangar.notice(&"new_part")
	Hangar.notice(&"new_part")
	Hangar.notice(&"not_a_notice")
	var ok := Hangar.notices == [&"new_part"]
	SaveGame.load_all(Sim.tree())
	ok = ok and Hangar.notices == [&"new_part"]
	ok = ok and Hangar.take_notices() == [&"new_part"] and Hangar.notices.is_empty()
	SaveGame.load_all(Sim.tree())
	return ok and Hangar.notices.is_empty()

func test_no_line_plays_for_the_dead() -> bool:
	var b := Bark.new()
	b.seed = 2
	Sim.add(b)
	Roster.kill(&"nala")
	Roster.kill(&"sanjaya")
	var ok := true
	for i in 30:
		for e in Bark.NOTICES:
			b.used.clear()
			var line := b.say(e)
			ok = ok and not line.is_empty() and Roster.is_alive(line.id) and line.text in Bark.pool(line.id, e)
			ok = ok and b.say(e, &"nala").is_empty()
	b.free()
	# Right after a death the board stays quiet, and the notice goes unsaid.
	PlayerProfile.choose_pilot(&"arjuna")
	_repaint()
	var board: JobBoard = await _board()
	ok = ok and _said(board, &"new_livery").is_empty() and Hangar.notices.is_empty()
	await _close()
	return ok

func test_every_cast_member_has_notice_lines_without_pronouns() -> bool:
	var ok := true
	var words := RegEx.create_from_string("(?i)\\b(he|she|him|his|her|hers|himself|herself)\\b")
	for id in CAST:
		var c: Character = Roster.character(id)
		for e in Bark.NOTICES:
			var entry: Dictionary = Bark.lines_of(id).get(String(e), {})
			ok = ok and entry.get("active", []).size() >= 3
			if c.can_be_harmed:
				ok = ok and entry.get("injured", []).size() >= 3
			for status in entry:
				for line in entry[status]:
					if words.search(Bark.text_of(line)):
						print("        %s %s: %s" % [id, e, Bark.text_of(line)])
						ok = false
	return ok

func test_only_nala_names_nala_on_a_part() -> bool:
	# Anyone else's part line plays only once Nala is gone, so none of them
	# credits Nala with the work.
	var ok := true
	for id in CAST:
		if id == &"nala":
			continue
		for t in Bark.pool(id, &"new_part") + Bark.pool(id, &"new_part", Roster.Status.INJURED):
			if "nala" in t.to_lower():
				print("        %s: %s" % [id, t])
				ok = false
	return ok

func test_every_new_line_fits_the_radio_at_both_sizes() -> bool:
	var ok := true
	var texts := []
	for id in CAST:
		for e in Bark.NOTICES:
			for t in Bark.pool(id, e) + Bark.pool(id, e, Roster.Status.INJURED):
				texts.append({"id": id, "event": e, "text": t})
	ok = texts.size() >= 60
	for s in SIZES:
		for top in [true, false]:
			var host := Control.new()
			host.size = s
			Sim.add(host)
			var box := BarkBox.new()
			var b := Bark.new()
			box.bark = b
			box.at_top = top
			host.add_child(b)
			host.add_child(box)
			box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			await Sim.process_frames(1)
			var bar := BarkBox.panel_rect(s, top)
			for l in texts:
				b.said.emit({"id": l.id, "event": l.event, "text": l.text, "face": &"happy"})
				box.skip()
				box._layout()
				var drawn: float = box.label.get_visible_line_count() * box.label.get_line_height()
				var fits: bool = box.label.get_line_count() <= BarkBox.MAX_LINES \
					and box.label.position.y + drawn <= bar.end.y and bar.encloses(Rect2(box.label.position, box.label.size))
				if not fits:
					print("        %s top %s: %s" % [s, top, l.text])
					ok = false
			host.free()
	return ok

func test_the_drone_name_shows_on_results_and_in_the_hud() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 20, 0))
	d.freeze = true
	var hud := FlightHud.new()
	hud.drone = d
	Sim.add(hud)
	var r := JobResult.new()
	r.job = load("res://data/jobs/test_job.tres")
	var screen: Control = load("res://scenes/ui/results.tscn").instantiate()
	Sim.add(screen)
	# No name, none shown.
	screen.show_result(r)
	await Sim.process_frames(1)
	var bare := hud.panel()
	var ok: bool = bare.drone == "" and screen.get_node("%Rows").get_node_or_null("Drone") == null \
		and hud.panel_rect().size.y == 64.0
	var l := Hangar.livery(0)
	l.drone_name = "Garuda"
	Hangar.set_livery(0, l)
	screen.show_result(r)
	await Sim.process_frames(1)
	var named := hud.panel()
	var row: Label = screen.get_node("%Rows").get_node_or_null("Drone")
	ok = ok and named.drone == "DRONE  GARUDA" and row != null and row.text == "Drone  Garuda" \
		and hud.panel_rect().size.y == 84.0 and row.get_index() == 0
	# A fleet slot's name is not the player's drone.
	var fleet := Hangar.livery(1)
	fleet.drone_name = "Vayu"
	Hangar.set_livery(1, fleet)
	ok = ok and hud.panel().drone == "DRONE  GARUDA"
	screen.free()
	hud.free()
	d.free()
	return ok
