extends RefCounted
# Story 14.8: crew and story sound. A chirp, pitched per speaker, under every
# bark; a chorus tone under every chorus line and none after shutdown; the
# Lattice's drone and power-down; a bed under each cutscene.

const Sim = preload("res://tests/sim.gd")
const LATTICE_JOB := "res://scenes/boss/lattice_job.tscn"
const RESULTS := "res://scenes/ui/results.tscn"

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

func _chirps() -> Array:
	return Sfx.log.filter(func(l): return l.id == &"crew_chirp")

func _lattice_job() -> Node:
	var s: Node = load(LATTICE_JOB).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	runner.confirm_risk = false
	Sim.add(s)
	var fight: LatticeFight = s.get_node("Fight")
	for d in fight.defenders:
		d.free()
	fight.defenders.clear()
	return s

func test_every_bark_plays_its_speakers_chirp() -> bool:
	_fresh()
	var b := Bark.new()
	b.seed = 3
	Sim.add(b)
	var ok := true
	var pitches := []
	for id in Roster.ids():
		var c: Character = Roster.character(id)
		ok = ok and c.validate().is_empty()
		pitches.append(c.chirp_pitch)
		for e in [&"briefing", &"strike", &"complete"]:
			Sfx.clear_log()
			var said := b.say(e, id)
			var heard := _chirps()
			if said.is_empty() or heard.size() != 1 or not is_equal_approx(heard[0].pitch, c.chirp_pitch) or heard[0].bus != &"Voice":
				print("        %s %s: %s -> %s" % [id, e, said, heard])
				ok = false
	# Each speaker sounds like themselves.
	for i in pitches.size():
		ok = ok and pitches.count(pitches[i]) == 1
	# A line emitted straight onto `spoke` (Marlo's trench calls) chirps too.
	Sfx.clear_log()
	b.spoke.emit(&"marlo", &"trench", "Left.")
	ok = ok and _chirps().size() == 1 and is_equal_approx(_chirps()[0].pitch, Roster.character(&"marlo").chirp_pitch)
	# A silent say (kept for the results screen) chirps there, not here; the dead never chirp.
	Sfx.clear_log()
	b.say(&"results", &"rin", false)
	Roster.kill(&"marlo")
	b.say(&"strike", &"marlo")
	Bark.chirp(&"marlo")
	ok = ok and _chirps().is_empty()
	b.free()
	_fresh()
	return ok

func test_results_bark_plays_its_speakers_chirp() -> bool:
	_fresh()
	var screen: Control = load(RESULTS).instantiate()
	Sim.add(screen)
	await Sim.process_frames(1)
	var r := JobResult.new()
	r.job = load("res://data/jobs/sample_delivery.tres")
	r.bark = {"id": &"rin", "event": &"results", "text": "Good flying."}
	r.casualties = {&"marlo": Roster.Status.INJURED}
	r.casualty_lines = {&"marlo": "Just a scratch."}
	Sfx.clear_log()
	screen.show_result(r)
	var pitches: Array = _chirps().map(func(l): return l.pitch)
	var ok: bool = pitches.size() == 2 and pitches.has(Roster.character(&"rin").chirp_pitch) \
		and pitches.has(Roster.character(&"marlo").chirp_pitch)
	if not ok:
		print("        %s" % [pitches])
	screen.free()
	await Sim.process_frames(1)
	_fresh()
	return ok

func test_chorus_tone_under_every_line_and_none_after_shutdown() -> bool:
	var s := _lattice_job()
	var fight: LatticeFight = s.get_node("Fight")
	var chorus: Chorus = s.get_node("Chorus")
	var sound: LatticeSound = s.get_node("Lattice/Sound")
	var lines := []
	chorus.spoke.connect(func(e, t): lines.append(t))
	await Sim.process_frames(2)
	var droning_at_start := sound.droning and sound.playing and sound.bus == &"World"
	Sfx.clear_log()
	chorus.say(&"phase_reclaim")
	chorus.say(&"strike")
	chorus.say(&"phase_trench")
	var tones_before := Sfx.count(&"lattice_tone")
	fight.boss_disabled.emit()
	var tones_at_shutdown := Sfx.count(&"lattice_tone")
	var said_at_shutdown := lines.size()
	chorus.say(&"phase_override")
	chorus.say(&"strike")
	fight.boss_disabled.emit()
	var tone: Dictionary = Sfx.log.filter(func(l): return l.id == &"lattice_tone")[0]
	var ok: bool = droning_at_start and tones_before == 3 and tones_at_shutdown == 4 and said_at_shutdown == 4 \
		and Sfx.count(&"lattice_tone") == 4 and lines.size() == 4 and tone.bus == &"Voice" \
		and not sound.droning and not sound.playing and sound.powered_down \
		and Sfx.count(&"lattice_power_down") == 1
	if not ok:
		print("        drone %s, tones %d/%d/%d, lines %d, power-down %d" % [droning_at_start, tones_before,
			tones_at_shutdown, Sfx.count(&"lattice_tone"), lines.size(), Sfx.count(&"lattice_power_down")])
	s.free()
	return ok

func test_each_cutscene_has_a_bed() -> bool:
	var ok := true
	var found := 0
	for f in DirAccess.get_files_at("res://data/story"):
		if not f.ends_with(".tres"):
			continue
		var cut := load("res://data/story/" + f) as Cutscene
		if cut == null:
			continue
		found += 1
		var e := Sfx.bank.find(cut.bed)
		if e == null or e.streams.is_empty():
			print("        %s: no bed" % f)
			ok = false
			continue
		# Played: a copy with one empty beat, so no backdrop loads and nothing follows.
		var copy: Cutscene = cut.duplicate()
		copy.beats = [CutsceneBeat.new()]
		copy.next_scene = ""
		copy.seen_flag = &""
		var p := CutscenePlayer.new()
		p.cutscene = copy
		Sim.add(p)
		await Sim.process_frames(2)
		var playing: bool = p.bed != null and p.bed.playing and p.bed.stream == e.streams[0] and p.bed.bus == e.bus
		p.finish()
		ok = ok and playing and not p.bed.playing
		if not playing:
			print("        %s: bed not playing" % f)
		p.free()
	return ok and found >= 2
