extends RefCounted
# Story 18.8: babble voices. Each crew member's gibberish loop runs while their
# line types out on the radio and stops with its last character, when the line
# is skipped, or when another replaces it. Every voice differs in pitch or rate,
# serious lines babble slower and lower, memorials and the dead are silent, and
# every loop is generated reproducibly and licensed.

const Sim = preload("res://tests/sim.gd")
const MusicKey = preload("res://tests/test_music_key.gd")
const LICENSES := "res://data/audio/LICENSES.md"
## Syllables per loop in tools/sfx/generate.py (BABBLE_SYLLABLES).
const SYLLABLES := 12

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

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

func _line(event: StringName, text: String, id := &"marlo") -> Dictionary:
	return {"id": id, "event": event, "text": text, "face": &"neutral"}

func _babbles() -> Array:
	return Sfx.log.filter(func(l): return String(l.id).begins_with("babble_"))

func test_babble_runs_while_typing_and_stops_on_the_last_character() -> bool:
	_fresh()
	var box := _radio()
	Sfx.clear_log()
	var line := _line(&"briefing", "Wind is calm, the course is yours today.")
	box.bark.said.emit(line)
	# The chirp still opens the line; the babble starts with the typing.
	var ids: Array = Sfx.log.map(func(l): return String(l.id))
	var chirp := ids.find("crew_chirp_happy") if ids.has("crew_chirp_happy") else ids.find("crew_chirp")
	var ok: bool = box.babbling == &"babble_marlo" and box.voice.playing and chirp >= 0 \
		and ids.find("babble_marlo") > chirp and _babbles().size() == 1 and is_equal_approx(_babbles()[0].pitch, 1.0) \
		and _babbles()[0].bus == &"Voice"
	var stopped_at := -1.0
	for i in 60 * 3:
		await Sim.process_frames(1)
		if box.typing() and (box.babbling == &"" or not box.voice.playing):
			print("        babble stopped while typing at %.2f s" % box._age)
			ok = false
			break
		if not box.typing():
			stopped_at = box._age
			ok = ok and box.babbling == &"" and not box.voice.playing
			break
	ok = ok and stopped_at >= 0.0 and stopped_at - box.type_time() < 0.1
	if not ok:
		print("        %s / stopped %.3f s, typed %.3f s" % [ids, stopped_at, box.type_time()])
	_free(box)
	return ok

func test_every_babble_differs_in_pitch_or_rate() -> bool:
	var ids := Roster.ids()
	var ok := ids.size() >= 2
	for i in ids.size():
		var a: Character = Roster.character(ids[i])
		ok = ok and a.validate().is_empty()
		for j in range(i + 1, ids.size()):
			var b: Character = Roster.character(ids[j])
			if is_equal_approx(a.babble_pitch, b.babble_pitch) and is_equal_approx(a.babble_rate, b.babble_rate):
				print("        %s and %s babble alike" % [a.id, b.id])
				ok = false
	# Each loop is baked from its character's data: its own sound on the Voice
	# bus, looping, SYLLABLES slots of 1 / babble_rate s, on the key's scale.
	var m = JSON.parse_string(FileAccess.get_file_as_string("res://data/music/manifest.json"))
	var scale: Array = m.get("scale", []) if m is Dictionary else []
	var mk = MusicKey.new()
	for id in ids:
		var c: Character = Roster.character(id)
		var ev := Sfx.bank.find(c.babble_event())
		var stream: AudioStreamWAV = ev.streams[0] if ev and not ev.streams.is_empty() else null
		var samples: PackedFloat32Array = mk._wav(stream.resource_path) if stream else PackedFloat32Array()
		var r := c.babble_pitch
		while r < 1.0:
			r *= 2.0
		while r >= 2.0:
			r /= 2.0
		var on_scale := false
		for k in scale:
			on_scale = on_scale or absf(r - float(k)) < 0.001
		if stream == null or ev.bus != &"Voice" or stream.loop_mode != AudioStreamWAV.LOOP_FORWARD \
				or samples.size() != SYLLABLES * roundi(22050.0 / c.babble_rate) or not on_scale:
			print("        %s: babble %s, %d samples, pitch on scale %s" % [id, ev, samples.size(), on_scale])
			ok = false
	return ok

func test_serious_lines_babble_slower_and_lower_and_memorials_are_silent() -> bool:
	_fresh()
	var ok := true
	for e in [&"warning", &"strike", &"hurt"]:
		var b := Bark.babble_for(&"bea", e)
		ok = ok and b.get("event") == &"babble_bea" and b.get("pitch", 1.0) < 1.0
	ok = ok and Bark.babble_for(&"bea", &"briefing").get("pitch", 0.0) == 1.0
	ok = ok and Bark.babble_for(&"bea", &"memorial").is_empty()
	# On the radio: a warning's babble plays at the lower pitch.
	var box := _radio()
	Sfx.clear_log()
	box.bark.said.emit(_line(&"warning", "Hold back, crew under the wall.", &"bea"))
	var heard := _babbles()
	ok = ok and heard.size() == 1 and is_equal_approx(heard[0].pitch, Bark.SERIOUS_BABBLE_PITCH) \
		and is_equal_approx(box.voice.pitch_scale, Bark.SERIOUS_BABBLE_PITCH)
	_free(box)
	return ok

func test_skipped_or_replaced_line_stops_its_babble() -> bool:
	_fresh()
	var box := _radio()
	box.bark.said.emit(_line(&"gate_passed", "Clean gate, keep that line going now."))
	var ok: bool = box.babbling == &"babble_marlo" and box.voice.playing
	box.skip()
	ok = ok and box.babbling == &"" and not box.voice.playing and not box.typing() \
		and box.label.visible_characters == -1
	# A warning replaces a line mid-type: the new speaker babbles instead.
	box.beat = 0.0
	box.bark.said.emit(_line(&"briefing", "Long one today, so pace the battery."))
	var first: bool = box.babbling == &"babble_marlo"
	box.bark.said.emit(_line(&"warning", "Heads up, crew below.", &"dot"))
	ok = ok and first and box.babbling == &"babble_dot" and box.voice.playing
	# Replaced by a silent line: the old babble stops and none starts.
	box.bark.said.emit(_line(&"strike", "", &"dot"))
	ok = ok and box.babbling == &"" and not box.voice.playing
	_free(box)
	return ok

func test_the_dead_never_babble() -> bool:
	_fresh()
	Roster.kill(&"marlo")
	var box := _radio()
	Sfx.clear_log()
	box.bark.said.emit(_line(&"briefing", "This should never be heard at all."))
	var ok: bool = box.babbling == &"" and not box.voice.playing and _babbles().is_empty()
	for e in Bark.EVENTS:
		ok = ok and Bark.babble_for(&"marlo", e).is_empty()
	_free(box)
	_fresh()
	return ok

func test_generator_is_deterministic_and_every_babble_is_licensed() -> bool:
	var out := []
	var code := OS.execute("python3", [ProjectSettings.globalize_path("res://tools/sfx/generate.py"), "--check"], out, true)
	var ok := code == 0
	if not ok:
		print("        sfx generate.py --check exited %d: %s" % [code, "".join(out).strip_edges()])
	var listed := {}
	for line in FileAccess.get_file_as_string(LICENSES).split("\n"):
		var cells := line.split("|")
		if cells.size() >= 4:
			listed[cells[1].strip_edges().trim_prefix("`").trim_suffix("`")] = cells[3].strip_edges()
	for id in Roster.ids():
		var ev := Sfx.bank.find(Roster.character(id).babble_event())
		var f: String = ev.streams[0].resource_path.trim_prefix("res://data/audio/") if ev and not ev.streams.is_empty() else ""
		if f == "" or listed.get(f, "") != "generated":
			print("        %s: %s not listed as generated" % [id, f])
			ok = false
	return ok
