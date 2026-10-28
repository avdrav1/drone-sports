extends RefCounted
# Story 16.9: gates in key. Gate n plays at the pitch of mantra note n (mod the
# hook's length), so a clean run plays the melody; the countdown beeps on the
# fifth and launches on the tonic. tests/test_music_key.gd checks the baked
# files really sit at the pitches recorded in pitches.json.

const Sim = preload("res://tests/sim.gd")
const TEST_COURSE := "res://data/courses/test_loop.tres"
const MANTRA := "res://tools/music/mantra.json"
const MANIFEST := "res://data/music/manifest.json"
const PITCHES := "res://data/audio/generated/pitches.json"

func _json(path: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

## The mantra's notes as pitch scales over the tonic, from mantra.json and the
## manifest's scale (degree 8 is the tonic up an octave).
func _notes() -> Array:
	var m := _json(MANTRA)
	var scale: Array = _json(MANIFEST).get("scale", [])
	var out := []
	for n in m.get("call", []) + m.get("answer", []):
		var d := int(n.degree) - 1
		out.append(float(scale[posmod(d, scale.size())]) * pow(2.0, floori(float(d) / scale.size())))
	return out

func _gate_pitches() -> Array:
	return Sfx.log.filter(func(l): return l.id == JobCues.GATE).map(func(l): return l.pitch)

func _matches(pitches: Array, notes: Array) -> bool:
	if notes.is_empty():
		return false
	for i in pitches.size():
		if absf(pitches[i] - notes[i % notes.size()]) > 1e-4:
			print("        gate %d at %.5f, mantra note %.5f" % [i, pitches[i], notes[i % notes.size()]])
			return false
	return true

func test_gate_event_holds_the_mantra_over_the_tonic() -> bool:
	var notes := _notes()
	var e: SoundEvent = Sfx.bank.find(JobCues.GATE)
	var base: Dictionary = _json(PITCHES).get("job_gate", {})
	# Its base pitch is the tonic, and it never wanders off the note.
	var ok: bool = notes.size() == 22 and e != null and e.pitch_variance == 0.0 \
		and int(base.get("degree", 0)) == 1 \
		and e.pitches.size() == notes.size() and _matches(Array(e.pitches), notes)
	for n in [0, 5, 21, 22, 23, 44, -1]:
		ok = ok and absf(JobCues.gate_pitch(n) - notes[posmod(n, notes.size())]) < 1e-4
	return ok

func test_a_clean_run_plays_the_mantra() -> bool:
	var root := Sim.job_setup(Job.new())
	var runner: JobRunner = root.get_node("Runner")
	runner.pays_out = false
	runner.results_scene = null
	var course := Course.new()
	course.data = load(TEST_COURSE)
	root.add_child(course)
	var d: Drone = runner.drone
	await Sim.go_live(root)
	d.freeze = true
	course.add_racer(d)
	course.start()
	Sfx.clear_log()
	for i in course.gates.size() + 3:
		await _through(d, course.gates[i % course.gates.size()])
	var flown := _gate_pitches()
	var ok := flown.size() == course.gates.size() + 3 and _matches(flown, _notes())
	# Past the hook's end it starts over: gate n is note n mod the length.
	var cues: JobCues = runner.find_children("*", "JobCues", true, false)[0]
	for i in 40:
		cues._on_gate(d, 0)
	flown = _gate_pitches()
	ok = ok and flown.size() == course.gates.size() + 43 and _matches(flown, _notes())
	# A new run starts the hook from its first note again.
	runner.fail("test")
	runner.begin()
	ok = ok and cues.gates == 0
	root.free()
	return ok

func test_countdown_sits_on_the_fifth_and_launches_on_the_tonic() -> bool:
	var p := _json(PITCHES)
	var beep: Dictionary = p.get("job_countdown", {})
	var go: Dictionary = p.get("job_go", {})
	var ok := int(beep.get("degree", 0)) == 5 and int(go.get("degree", 0)) == 1
	for id in [&"job_countdown", &"job_go"]:
		ok = ok and Sfx.bank.find(id).pitch_variance == 0.0
	# Played at pitch 1, so they sound at those recorded pitches.
	var job := Job.new()
	job.countdown = 3.0
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	runner.pays_out = false
	runner.results_scene = null
	Sfx.clear_log()
	await Sim.go_live(root)
	var played := Sfx.log.filter(func(l): return l.id in [&"job_countdown", &"job_go"])
	ok = ok and played.size() == 4
	for l in played:
		ok = ok and l.pitch == 1.0
	root.free()
	return ok

func _through(r: Node3D, g: Gate) -> void:
	r.global_position = g.global_transform * Vector3(0, 20, 1.5)
	await Sim.physics_frames(1)
	r.global_position = g.global_transform * Vector3(0, 0, 1.5)
	await Sim.physics_frames(1)
	r.global_position = g.global_transform * Vector3(0, 0, -1.5)
	await Sim.physics_frames(1)
