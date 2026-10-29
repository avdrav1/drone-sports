extends RefCounted
# Story 18.6: happy chirps. Each face plays its own chirp variant (rising for
# happy, a giggle trill for celebrating, a wobble for worried, a falling "awoo"
# for sad), pitched per speaker; strike, injury and memorial lines keep the
# plain one. Every chirp starts on a degree of the key, the generator is
# reproducible byte for byte, and every chirp file is licensed.

const Sim = preload("res://tests/sim.gd")
const MusicKey = preload("res://tests/test_music_key.gd")
const RESULTS := "res://scenes/ui/results.tscn"
const PITCHES := "res://data/audio/generated/pitches.json"
const MANIFEST := "res://data/music/manifest.json"
const LICENSES := "res://data/audio/LICENSES.md"
const CHIRP_IDS: Array[StringName] = [&"crew_chirp", &"crew_chirp_happy", &"crew_chirp_celebrate",
	&"crew_chirp_worried", &"crew_chirp_sad"]

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

func _chirps() -> Array:
	return Sfx.log.filter(func(l): return String(l.id).begins_with("crew_chirp"))

func _json(path: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

## Says one line from `id` on `event` with `face` and returns the chirps heard.
func _say_with_face(b: Bark, id: StringName, event: StringName, face: StringName) -> Array:
	var saved: Dictionary = Bark.lines_of(id)
	var entry := {"text": "Test line %s." % face, "face": String(face)}
	Bark._cache[id] = {String(event): {"active": [entry], "injured": [entry]}}
	b.used.clear()
	Sfx.clear_log()
	var said := b.say(event, id)
	Bark._cache[id] = saved
	return _chirps() if not said.is_empty() else []

func test_each_face_plays_its_chirp_variant() -> bool:
	_fresh()
	var b := Bark.new()
	b.seed = 2
	Sim.add(b)
	var expect := {&"neutral": &"crew_chirp", &"happy": &"crew_chirp_happy", &"determined": &"crew_chirp_happy",
		&"worried": &"crew_chirp_worried", &"shocked": &"crew_chirp_worried", &"sad": &"crew_chirp_sad"}
	var ok := expect.size() == CharacterPortrait.EXPRESSIONS.size()
	var c: Character = Roster.character(&"bea")
	for face in CharacterPortrait.EXPRESSIONS:
		var heard := _say_with_face(b, &"bea", &"briefing", face)
		if heard.size() != 1 or heard[0].id != expect.get(face, &"") or not is_equal_approx(heard[0].pitch, c.chirp_pitch) \
				or heard[0].bus != &"Voice":
			print("        %s: %s" % [face, heard])
			ok = false
	# Celebrating: a happy finish giggles.
	var done := _say_with_face(b, &"bea", &"complete", &"happy")
	ok = ok and done.size() == 1 and done[0].id == &"crew_chirp_celebrate"
	# Serious lines keep the plain chirp, whatever their face.
	for e in [&"warning", &"strike", &"hurt"]:
		for face in [&"sad", &"worried", &"happy"]:
			var heard := _say_with_face(b, &"bea", e, face)
			if heard.size() != 1 or heard[0].id != &"crew_chirp":
				print("        %s %s: %s" % [e, face, heard])
				ok = false
	ok = ok and Bark.chirp_for(&"sad", &"memorial") == &"crew_chirp"
	# Each variant is its own sound in the bank, on the Voice bus.
	var streams := {}
	for id in CHIRP_IDS:
		var ev := Sfx.bank.find(id)
		ok = ok and ev != null and ev.streams.size() == 1 and ev.bus == &"Voice"
		if ev and not ev.streams.is_empty():
			streams[ev.streams[0].resource_path] = true
	ok = ok and streams.size() == CHIRP_IDS.size()
	# The dead never chirp, in any variant.
	Roster.kill(&"bea")
	Sfx.clear_log()
	for face in CharacterPortrait.EXPRESSIONS:
		Bark.chirp(&"bea", face, &"complete")
	ok = ok and _chirps().is_empty()
	b.free()
	_fresh()
	return ok

func test_radio_and_results_chirp_by_face() -> bool:
	_fresh()
	# The radio panel plays the variant as the line opens.
	var b := Bark.new()
	b.seed = 1
	Sim.add(b)
	var box := BarkBox.new()
	box.bark = b
	Sim.add(box)
	var heard := _say_with_face(b, &"marlo", &"briefing", &"sad")
	var ok: bool = heard.size() == 1 and heard[0].id == &"crew_chirp_sad"
	box.free()
	b.free()
	# The results screen: the bark by its face, an injured casualty's line plain.
	var screen: Control = load(RESULTS).instantiate()
	Sim.add(screen)
	await Sim.process_frames(1)
	var r := JobResult.new()
	r.job = load("res://data/jobs/sample_delivery.tres")
	r.bark = {"id": &"rin", "event": &"results", "text": "Good flying.", "face": &"happy"}
	r.casualties = {&"marlo": Roster.Status.INJURED}
	r.casualty_lines = {&"marlo": "Just a scratch."}
	Sfx.clear_log()
	screen.show_result(r)
	var ids: Array = _chirps().map(func(l): return l.id)
	ok = ok and ids.size() == 2 and ids.has(&"crew_chirp_happy") and ids.has(&"crew_chirp")
	if not ok:
		print("        %s / %s" % [heard, ids])
	screen.free()
	await Sim.process_frames(1)
	_fresh()
	return ok

func test_every_chirp_base_pitch_is_a_scale_degree() -> bool:
	var m := _json(MANIFEST)
	var tonic: float = m.get("tonic", 0.0)
	var scale: Array = m.get("scale", [])
	var p := _json(PITCHES)
	var mk = MusicKey.new()
	var ok := tonic > 0.0 and scale.size() == 7
	for id in CHIRP_IDS:
		var e: Dictionary = p.get(String(id), {})
		var degree := int(e.get("degree", 0))
		var hz: float = e.get("hz", 0.0)
		if degree < 1 or degree > 7:
			print("        %s: no degree" % id)
			ok = false
			continue
		var expect: float = tonic * float(scale[degree - 1]) * pow(2.0, int(e.get("octave", 0)))
		# The baked file really starts there: more energy at it than a semitone
		# either side.
		var s: PackedFloat32Array = mk._wav(mk._bank_file(id))
		var here: float = mk._goertzel(s, hz)
		var near := maxf(mk._goertzel(s, hz * pow(2.0, 1.0 / 12.0)), mk._goertzel(s, hz / pow(2.0, 1.0 / 12.0)))
		if absf(hz - expect) > 0.01 or s.is_empty() or here < 2.0 * near:
			print("        %s: %.2f Hz (expect %.2f), %.1f vs %.1f a semitone off" % [id, hz, expect, here, near])
			ok = false
	# Pitched per speaker by a ratio of the scale, so the base stays a degree of the key.
	for id in Roster.ids():
		var c: Character = Roster.character(id)
		var r := c.chirp_pitch
		while r < 1.0:
			r *= 2.0
		while r >= 2.0:
			r /= 2.0
		var on_scale := false
		for k in scale:
			on_scale = on_scale or absf(r - float(k)) < 0.001
		if not on_scale:
			print("        %s: chirp_pitch %s is off the scale" % [id, c.chirp_pitch])
			ok = false
	return ok

func test_generator_writes_the_same_files_twice() -> bool:
	# --check renders every sound again into build/sfx/check/ and compares each
	# file with data/audio/generated/ byte for byte.
	var out := []
	var code := OS.execute("python3", [ProjectSettings.globalize_path("res://tools/sfx/generate.py"), "--check"], out, true)
	if code != 0:
		print("        sfx generate.py --check exited %d: %s" % [code, "".join(out).strip_edges()])
	return code == 0

func test_every_chirp_file_is_licensed() -> bool:
	var listed := {}
	for line in FileAccess.get_file_as_string(LICENSES).split("\n"):
		var cells := line.split("|")
		if cells.size() >= 4:
			listed[cells[1].strip_edges().trim_prefix("`").trim_suffix("`")] = cells[3].strip_edges()
	var ok := true
	for id in CHIRP_IDS:
		var ev := Sfx.bank.find(id)
		var f: String = ev.streams[0].resource_path.trim_prefix("res://data/audio/") if ev and not ev.streams.is_empty() else ""
		if f == "" or listed.get(f, "") != "generated":
			print("        %s: %s not listed as generated" % [id, f])
			ok = false
	return ok
