extends RefCounted
# Story 18.9: incoming call. Every line that opens the radio panel plays its cue
# first (the alert for warnings and strikes, the chime otherwise), a line that
# replaces another replays it, the face pops in and is at rest within 0.4 s,
# and the speaker's babble still runs under it.

const Sim = preload("res://tests/sim.gd")
const LICENSES := "res://data/audio/LICENSES.md"
## Seconds after opening by which the face must be at rest.
const REST_BY := 0.4

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

func _radio() -> BarkBox:
	var b := Bark.new()
	b.seed = 1
	Sim.add(b)
	var box := BarkBox.new()
	box.bark = b
	box.chatter_gap = 0.0
	Sim.add(box)
	return box

func _free(box: BarkBox) -> void:
	box.bark.free()
	box.free()

func _line(event: StringName, text: String, id := &"sanjaya") -> Dictionary:
	return {"id": id, "event": event, "text": text, "face": &"neutral"}

func _cues() -> Array:
	return Sfx.log.filter(func(l): return l.id == BarkBox.CHIME or l.id == BarkBox.ALERT)

func test_every_line_plays_its_cue_first() -> bool:
	_fresh()
	var ok := true
	for event in [&"briefing", &"gate_passed", &"order", &"complete", &"fail", &"warning", &"strike"]:
		var box := _radio()
		Sfx.clear_log()
		box.bark.said.emit(_line(event, "Coming through."))
		var want := BarkBox.ALERT if event in [&"warning", &"strike"] else BarkBox.CHIME
		var good: bool = box.current.event == event and not Sfx.log.is_empty() and Sfx.log[0].id == want \
			and _cues().size() == 1 and Sfx.log[1].id == &"radio_static"
		if not good:
			print("        %s: %s" % [event, Sfx.log.map(func(l): return l.id)])
		ok = ok and good
		_free(box)
	return ok

func test_a_queued_line_rings_when_it_opens_not_when_said() -> bool:
	_fresh()
	var box := _radio()
	var a := _line(&"briefing", "Package is at the yard.")
	var b := _line(&"order", "On my way.", &"drona")
	box.bark.said.emit(a)
	Sfx.clear_log()
	box.bark.said.emit(b)
	var quiet := _cues().is_empty()
	var frames := 0
	while box.current == a and frames < 300:
		await Sim.process_frames(1)
		frames += 1
	var ok: bool = quiet and box.current == b and _cues().size() == 1 and _cues()[0].id == BarkBox.CHIME
	_free(box)
	return ok

func test_a_replacing_line_replays_the_cue() -> bool:
	_fresh()
	var box := _radio()
	Sfx.clear_log()
	box.bark.said.emit(_line(&"gate_passed", "Clean gate, keep it up."))
	await Sim.process_frames(3)
	box.bark.said.emit(_line(&"warning", "Heads up.", &"nala"))
	await Sim.process_frames(3)
	box.bark.said.emit(_line(&"complete", "That's the job.", &"drona"))
	var ids := _cues().map(func(l): return l.id)
	var ok: bool = ids == [BarkBox.CHIME, BarkBox.ALERT, BarkBox.CHIME] and box.current.id == &"drona"
	if not ok:
		print("        cues %s" % [ids])
	_free(box)
	return ok

func test_face_pops_in_and_rests_within_0_4_s() -> bool:
	var bounce := Vector2(0.9, 0.3)
	var ok := true
	var biggest := 0.0
	var smallest := INF
	for expr in CharacterPortrait.EXPRESSIONS:
		for i in 60:
			var age := i / 100.0
			for talking in [false, true]:
				var t := 3.0 + age
				var popped := CharacterPortrait.motion(expr, t, talking, bounce, INF, INF, age)
				var plain := CharacterPortrait.motion(expr, t, talking, bounce, INF, INF, INF)
				if age >= REST_BY and popped != plain:
					ok = false
				if not talking and expr == &"neutral":
					var k: float = (popped.scale as Vector2).x * (popped.scale as Vector2).y / ((plain.scale as Vector2).x * (plain.scale as Vector2).y)
					biggest = maxf(biggest, k)
					smallest = minf(smallest, k)
	# Starts small and overshoots: a cartoon pop, not a plain fade.
	ok = ok and smallest < 0.3 and biggest > 1.1
	# In the panel: the face is popping as the line opens and at rest by 0.4 s.
	_fresh()
	var box := _radio()
	box.bark.said.emit(_line(&"briefing", "A long line, so the face is still talking at rest."))
	await Sim.process_frames(1)
	var m0 := box.portrait.current_motion()
	var opening: bool = (m0.scale as Vector2).y < 0.9
	await Sim.process_frames(int(REST_BY * 60) + 1)
	var p := box.portrait
	var rest := CharacterPortrait.motion(p.expression, p.time, p.talking, p.character.bounce, INF, INF, INF)
	var m := p.current_motion()
	ok = ok and opening and (m.scale as Vector2).is_equal_approx(rest.scale) and (m.offset as Vector2).is_equal_approx(rest.offset)
	if not ok:
		print("        %s..%s opening %s, %s vs %s" % [smallest, biggest, m0.scale, m.scale, rest.scale])
	_free(box)
	return ok

func test_babble_keeps_running_under_the_cue() -> bool:
	_fresh()
	var box := _radio()
	Sfx.clear_log()
	box.bark.said.emit(_line(&"briefing", "Package is at the yard, take it slow."))
	var ids: Array = Sfx.log.map(func(l): return l.id)
	await Sim.process_frames(5)
	var ok: bool = ids.size() >= 4 and ids[0] == BarkBox.CHIME and box.typing() \
		and box.babbling == Roster.character(&"sanjaya").babble_event() and String(ids.back()).begins_with("babble_")
	# A warning cutting in rings the alert and starts the new speaker's babble.
	box.bark.said.emit(_line(&"warning", "Heads up.", &"nala"))
	ok = ok and box.babbling == Roster.character(&"nala").babble_event()
	if not ok:
		print("        %s, babbling %s" % [ids, box.babbling])
	_free(box)
	return ok

func test_cues_are_generated_on_the_key_on_the_ui_bus_and_licensed() -> bool:
	var bank: SoundBank = load("res://data/audio/bank.tres")
	var pitches = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio/generated/pitches.json"))
	var licenses := FileAccess.get_file_as_string(LICENSES)
	var ok: bool = pitches is Dictionary
	for id in [BarkBox.CHIME, BarkBox.ALERT]:
		var e := bank.find(id)
		ok = ok and e != null and not e.streams.is_empty() and e.bus == &"UI"
		ok = ok and pitches.has(String(id)) and ("generated/%s.wav" % id) in licenses
	ok = ok and BarkBox.cue_for(&"warning") == BarkBox.ALERT and BarkBox.cue_for(&"strike") == BarkBox.ALERT \
		and BarkBox.cue_for(&"briefing") == BarkBox.CHIME
	return ok
