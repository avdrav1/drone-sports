extends RefCounted
# Story 26.5: the radio as a chat. The last four lines stay on screen, newest at
# the bottom, each with its speaker's name; a fifth scrolls the first off; lines
# older than 20 s fade out and the chat empties; it never covers the screen's
# middle third at 960x720 or 1920x1080; pausing holds it as it is. Its rows
# keep off the flight HUD's readouts and the board's controls, showing only the
# rows that have room, and on the board the chat goes after the newest's hold.

const Sim = preload("res://tests/sim.gd")
const SIZES: Array[Vector2] = [Vector2(960, 720), Vector2(1920, 1080)]
const SPEAKERS: Array[StringName] = [&"sanjaya", &"drona", &"bhima", &"nala", &"hanuman"]

func _radio(size := Vector2(960, 720)) -> BarkBox:
	var host := Control.new()
	host.size = size
	Sim.add(host)
	var b := Bark.new()
	b.seed = 1
	host.add_child(b)
	var box := BarkBox.new()
	box.bark = b
	host.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return box

func _free(box: BarkBox) -> void:
	box.get_parent().free()

## Line `i`: an urgent event, so it opens at once, from SPEAKERS[i].
func _say(box: BarkBox, i: int, text := "") -> Dictionary:
	var line := {"id": SPEAKERS[i], "event": &"warning", "text": text if text else "Line %d." % i, "face": &"neutral"}
	box.bark.said.emit(line)
	return line

## The speaker names and texts the chat shows, oldest first, the bar last.
func _shown(box: BarkBox) -> Array:
	var out := []
	var rows := box.rows.filter(func(r): return r.name.visible)
	rows.reverse()
	for r in rows:
		out.append([r.name.text, r.text.text])
	out.append([box.name_label.text.get_slice(" ", 0), box.label.text])
	return out

func test_three_lines_all_show_newest_at_the_bottom() -> bool:
	var box := _radio()
	for i in 3:
		_say(box, i)
	await Sim.process_frames(2)
	var want := []
	for i in 3:
		want.append([Roster.character(SPEAKERS[i]).name.to_upper(), "Line %d." % i])
	var ok: bool = box.visible and _shown(box) == want
	# Stacked upwards from the bar: each older row above the one after it.
	var rects := BarkBox.row_rects(box.size, box._rows_in_use().map(func(r): return r.text))
	ok = ok and rects.size() == 2 and rects[1].end.y <= rects[0].position.y \
		and rects[0].end.y <= BarkBox.face_rect(box.size).position.y
	if not ok:
		print("        %s" % [_shown(box)])
	_free(box)
	return ok

func test_a_fifth_line_scrolls_the_first_off() -> bool:
	var box := _radio()
	for i in 5:
		_say(box, i)
	await Sim.process_frames(2)
	var shown := _shown(box)
	var ok: bool = box.chat.size() == BarkBox.CHAT_LINES and shown.size() == 4 \
		and shown.map(func(s): return s[1]) == ["Line 1.", "Line 2.", "Line 3.", "Line 4."]
	_free(box)
	return ok

func test_lines_older_than_20_s_fade_out_and_the_chat_empties() -> bool:
	var box := _radio()
	_say(box, 0)
	box._process(15.0)
	_say(box, 1)
	box._process(4.0)
	var row: Dictionary = box.rows[0]
	var whole: bool = row.text.visible and is_equal_approx(row.text.modulate.a, 1.0)
	box._process(2.0)
	# Line 0 is 21 s old: fading, line 1 still whole.
	var fading: bool = row.text.visible and row.text.modulate.a < 1.0 and row.text.modulate.a > 0.0 \
		and is_equal_approx(box.modulate.a, 1.0)
	box._process(1.0)
	var gone: bool = box.chat.size() == 1 and not row.text.visible and box.visible
	box._process(BarkBox.FADE_AFTER + BarkBox.FADE_TIME)
	var empty: bool = box.chat.is_empty() and not box.visible
	if not (whole and fading and gone and empty):
		print("        whole %s fading %s gone %s empty %s" % [whole, fading, gone, empty])
	_free(box)
	return whole and fading and gone and empty

func test_never_covers_the_middle_third() -> bool:
	# The longest lines the radio can say, four in a row.
	var lines: Array = load("res://tests/test_radio_font.gd").new()._all_lines()
	lines.sort_custom(func(a: String, b: String): return a.length() > b.length())
	var ok := true
	for s in SIZES:
		var box := _radio(s)
		for i in 4:
			_say(box, i, lines[i])
		await Sim.process_frames(2)
		var middle := Rect2(s / 3.0, s / 3.0)
		var screen := Rect2(Vector2.ZERO, s)
		var shown := box._shown_rows()
		var used: Array = shown.rows
		var rects: Array[Rect2] = [BarkBox.panel_rect(s), BarkBox.face_rect(s)]
		rects.append_array(shown.rects)
		ok = ok and used.size() == 3
		for r in rects:
			if r.intersects(middle) or not screen.encloses(r):
				print("        %s: %s against the middle %s" % [s, r, middle])
				ok = false
		# Nothing clipped: each older line's text fits inside its row.
		for i in used.size():
			var t: Label = used[i].text
			if not rects[2 + i].encloses(Rect2(t.position, t.size)) or t.get_line_count() > t.get_visible_line_count():
				print("        %s: row %d clipped" % [s, i])
				ok = false
		_free(box)
	return ok

func test_pausing_holds_the_chat() -> bool:
	var box := _radio()
	_say(box, 0)
	_say(box, 1)
	await Sim.process_frames(2)
	var ages: Array = box.chat.map(func(e): return e.age)
	var tree := Sim.tree()
	tree.paused = true
	await Sim.process_frames(30)
	var held: bool = box.chat.map(func(e): return e.age) == ages and box.visible and _shown(box).size() == 2
	tree.paused = false
	await Sim.process_frames(2)
	var moved: bool = box.chat[0].age > ages[0]
	_free(box)
	return held and moved

## Four of the longest lines and three short ones, as the chat would show them.
func _lines(long: bool) -> Array:
	if not long:
		return ["Gate three, left side.", "Wind from the east, pilot.", "Steady. Breathe.", "You are clear, go."]
	var lines: Array = load("res://tests/test_radio_font.gd").new()._all_lines()
	lines.sort_custom(func(a: String, b: String): return a.length() > b.length())
	return lines.slice(0, 4)

func test_rows_keep_off_the_flight_readouts() -> bool:
	var scene: Node = load("res://scenes/jobs/test_race.tscn").instantiate()
	var runner: JobRunner = scene.get_node("JobRunner")
	runner.pays_out = false
	Sim.add(scene)
	await Sim.process_frames(3)
	var box: BarkBox = scene.get_node("HUD/BarkBox")
	var flight: FlightHud = scene.get_node("HUD/Flight")
	var radar: Radar = scene.get_node("HUD/Radar")
	var race: RaceHud = scene.get_node("HUD/Race")
	var ok := true
	for s in SIZES:
		for long in [false, true]:
			for c in [box, flight, radar, race]:
				c.size = s
			box.chat.clear()
			for i in 4:
				_say(box, i, _lines(long)[i])
				box._layout()
				var shown := box._shown_rows()
				var keep: Array[Rect2] = flight.readout_rects()
				keep.append_array([radar.rect(), race.panel_rect()])
				for r: Rect2 in shown.rects:
					for k in keep:
						if r.intersects(k):
							print("        %s: a chat row %s covers %s" % [s, r, k])
							ok = false
				# After three lines all three show, in flight, at both sizes and
				# with the longest lines; four short lines all show too.
				var want := i if i < 2 or not long else 2
				var visible := box.rows.filter(func(r): return r.text.visible).size()
				if shown.rows.size() < want or shown.rows.size() != visible:
					print("        %s long %s: after %d lines %d rows show" % [s, long, i + 1, shown.rows.size()])
					ok = false
				# One stack: each row sits right above the one after it.
				for j in range(1, shown.rects.size()):
					if shown.rects[j - 1].position.y - shown.rects[j].end.y > 4.5:
						print("        %s: a gap in the chat" % [s])
						ok = false
	scene.free()
	return ok

func test_on_the_board_the_chat_keeps_off_the_controls_and_goes() -> bool:
	var ok := true
	# A pilot chosen, so the board shows its jobs, not the pilot select.
	PlayerProfile.choose_pilot(PlayerProfile.pilots()[0].id)
	for s in SIZES:
		var host := Control.new()
		host.size = s
		Sim.add(host)
		var board: JobBoard = load("res://scenes/ui/job_board.tscn").instantiate()
		host.add_child(board)
		board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await Sim.process_frames(3)
		var box := board.radio
		box.size = s
		for i in 4:
			_say(box, i, _lines(false)[i])
		box._layout()
		var shown := box._shown_rows()
		var keep := board.radio_clear()
		var mine: Array[Rect2] = [BarkBox.panel_rect(s, true), BarkBox.face_rect(s, true)]
		mine.append_array(shown.rects)
		for r in mine:
			for k in keep:
				if k.intersects(Rect2(Vector2.ZERO, s)) and r.intersects(k):
					print("        %s: the board's chat %s covers %s" % [s, r, k])
					ok = false
		# At 1920x1080 the rows hang below the face, over the empty top.
		ok = ok and keep.size() >= 6 and (s.x < 1920 or shown.rows.size() >= 2)
		# The chat goes once the newest line has had its hold, not after 20 s.
		box.skip()
		box._process(box.hold_time(box.current.text) + BarkBox.FADE_TIME + 0.1)
		ok = ok and box.chat.is_empty() and not box.visible
		host.free()
	return ok
