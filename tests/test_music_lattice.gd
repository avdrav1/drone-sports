extends RefCounted
# Story 16.11: the Lattice sings. Its score is a choir of the hook at four
# densities over the tonic drone, in tune with lattice_drone; the densities
# follow the share of units reclaimed, the override hold leaves only the voice
# and the drone, nothing plays once the boss is disabled, and with the boss
# disabled in its data the score is never loaded.

const Sim = preload("res://tests/sim.gd")
const SCENE := "res://scenes/boss/lattice_job.tscn"
const LATTICE := "res://data/music/lattice.tres"
const DENSITIES := [&"density_4", &"density_3", &"density_2", &"density_1"]

func _stop() -> void:
	Music.play(null, 0.0)
	Music.clear_log()

func _job() -> Node:
	BossGate.boss = null
	var s: Node = load(SCENE).instantiate()
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

## Stem id -> the level it is at or fading to, for every stem of the score.
func _levels() -> Dictionary:
	var out := {}
	for st in Music.score.stems:
		out[st.id] = Music.level(st.id)
	return out

func _sounding() -> Array:
	var out := []
	for st in Music.score.stems:
		if Music.level(st.id) > Music.SILENT_DB:
			out.append(st.id)
	out.sort()
	return out

## Where the choir sits between densest (0) and sparsest (3), by power.
func _centre() -> float:
	var sum := 0.0
	var at := 0.0
	for i in DENSITIES.size():
		var p := db_to_linear(Music.level(DENSITIES[i]) - Music.score.find(DENSITIES[i]).level_db) ** 2 \
			if Music.level(DENSITIES[i]) > Music.SILENT_DB else 0.0
		sum += p
		at += i * p
	return at / sum if sum > 0.0 else -1.0

func test_score_is_a_dense_choir_in_tune_with_the_drone() -> bool:
	var sc: Score = load(LATTICE)
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/music/manifest.json"))
	var pitches: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio/generated/pitches.json"))
	var listed: Dictionary = m.scores.get("lattice", {})
	var ok: bool = sc.id == &"lattice" and sc.bars == 8 and is_equal_approx(sc.tonic, m.tonic) \
		and sc.find(&"drone") != null and sc.find(&"voice") != null \
		and listed.get("plays", {}).get("voice", "") == "voice"
	var voices := 0
	for id in MusicDirector.DENSITIES:
		ok = ok and id in DENSITIES and sc.find(id) != null and listed.plays.get(String(id), "") == "voice"
	# Sparsest to densest, each more voices than the last, up to thousands.
	for id in ["density_1", "density_2", "density_3", "density_4"]:
		var n := int(listed.get("densities", {}).get(id, 0))
		ok = ok and n > voices
		voices = n
	ok = ok and voices >= 1000
	var drone: Dictionary = listed.get("drone", {})
	var want: Dictionary = pitches.get("lattice_drone", {})
	ok = ok and not want.is_empty() and int(drone.get("degree", 0)) == int(want.degree) \
		and int(drone.get("octave", 99)) == int(want.octave) and is_equal_approx(float(drone.get("hz", 0.0)), float(want.hz))
	return ok

func test_densities_follow_the_reclaimed_fraction() -> bool:
	_stop()
	var s := _job()
	var fight: LatticeFight = s.get_node("Fight")
	await Sim.process_frames(2)
	var ok := MusicDirector.boss_fight == fight and not MusicDirector.boss_off
	MusicDirector.play_score(MusicDirector.lattice_score(), &"live")
	ok = ok and Music.score != null and Music.score.id == &"lattice"
	var sc := Music.score
	# None reclaimed: the densest choir alone, at its level.
	ok = ok and is_equal_approx(Music.level(&"density_4"), sc.find(&"density_4").level_db) \
		and DENSITIES.slice(1).all(func(id): return Music.level(id) <= Music.SILENT_DB) \
		and is_equal_approx(Music.level(&"voice"), sc.find(&"voice").level_db)
	var gap := fight.gap()
	var last := _centre()
	ok = ok and is_equal_approx(last, 0.0)
	for i in gap.size():
		fight.reclaim(gap[i])
		ok = ok and is_equal_approx(MusicDirector.reclaimed_fraction(), float(i + 1) / gap.size())
		var c := _centre()
		if not c > last:
			print("        centre %s after %d reclaimed, was %s" % [c, i + 1, last])
			ok = false
		last = c
	# All reclaimed: the sparsest choir alone.
	ok = ok and is_equal_approx(Music.level(&"density_1"), sc.find(&"density_1").level_db) \
		and DENSITIES.slice(0, 3).all(func(id): return Music.level(id) <= Music.SILENT_DB)
	# A fleet drone lost gives a unit back, and the choir thickens again.
	var view: CommandView = s.get_node("CommandView")
	fight.disable(view.drones[0])
	await Sim.process_frames(1)
	ok = ok and fight.reclaimed.size() == gap.size() - 1 and _centre() < last
	s.free()
	_stop()
	return ok

func test_override_leaves_voice_and_drone_then_silence() -> bool:
	_stop()
	var s := _job()
	var fight: LatticeFight = s.get_node("Fight")
	var runner: JobRunner = s.get_node("JobRunner")
	await Sim.process_frames(2)
	runner.launch(true)
	while runner.state != JobRunner.State.LIVE:
		await Sim.physics_frames(1)
	# The runner's states play the Lattice's score, not an act's.
	runner.pays_out = true
	MusicDirector._on_state(JobRunner.State.LIVE, JobRunner.State.COUNTDOWN, runner)
	runner.pays_out = false
	var ok: bool = Music.score != null and Music.score.id == &"lattice" and MusicDirector.mix == &"live" \
		and _sounding().size() > 2
	fight.open_entrance()
	runner.drone.freeze = true
	fight.start_override()
	ok = ok and MusicDirector.holding() and _sounding() == [&"drone", &"voice"] \
		and is_equal_approx(Music.level(&"voice"), Music.score.find(&"voice").level_db) \
		and is_equal_approx(Music.level(&"drone"), Music.score.find(&"drone").level_db)
	fight.boss_disabled.emit()
	ok = ok and MusicDirector.boss_off and _sounding().is_empty()
	# The results screen brings nothing back: no stinger, no fanfare.
	runner.pays_out = true
	MusicDirector._on_state(JobRunner.State.COMPLETE, JobRunner.State.LIVE, runner)
	runner.pays_out = false
	ok = ok and Music.score.id == &"lattice" and _sounding().is_empty() \
		and not Music.log.any(func(e): return e.event == "play" and e.score != &"lattice" and e.score != &"")
	s.free()
	_stop()
	return ok

func test_boss_levels_alone() -> bool:
	var sc: Score = load(LATTICE)
	var base := MusicDirector.levels_for(sc, &"live")
	var half := MusicDirector.boss_levels(base.duplicate(), 0.5, false, false)
	var hold := MusicDirector.boss_levels(base.duplicate(), 0.5, true, false)
	var off := MusicDirector.boss_levels(base.duplicate(), 0.0, false, true)
	var act := MusicDirector.levels_for(load("res://data/music/act_5.tres"), &"live")
	var ok: bool = half[&"density_3"] > Music.SILENT_DB and half[&"density_2"] > Music.SILENT_DB \
		and is_equal_approx(half[&"density_3"], half[&"density_2"]) and half[&"density_3"] < base[&"density_3"] \
		and half[&"density_4"] <= Music.SILENT_DB and half[&"density_1"] <= Music.SILENT_DB
	for id in hold:
		ok = ok and ((hold[id] > Music.SILENT_DB) == (id in MusicDirector.HOLD))
	ok = ok and off.values().all(func(db): return db <= Music.SILENT_DB)
	# Other scores pass through unchanged.
	ok = ok and MusicDirector.boss_levels(act.duplicate(), 1.0, true, true) == act
	return ok

func test_disabled_boss_never_loads_the_score() -> bool:
	_stop()
	await Sim.process_frames(2)
	var b: Boss = (load(BossGate.DATA) as Boss).duplicate()
	b.enabled = false
	BossGate.boss = b
	BossGate.loads.clear()
	var ok := MusicDirector.lattice_score() == null
	MusicDirector.board()
	for act in range(1, 6):
		var sc := MusicDirector.score_for(act)
		ok = ok and sc != null and sc.id != &"lattice"
	ok = ok and BossGate.loads.is_empty() and not ResourceLoader.has_cached(LATTICE) \
		and not Music.log.any(func(e): return e.event == "play" and e.score == &"lattice")
	BossGate.boss = null
	BossGate.loads.clear()
	_stop()
	return ok
