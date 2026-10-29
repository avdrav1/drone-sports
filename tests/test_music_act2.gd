extends RefCounted
# Story 16.5: Act 2, the tryout. With Act 2 the MusicDirector plays act_2, the
# same hook on real instruments with no synth stems; it uses the 16.4 state
# levels (the harmonium in the pad's place, the plucked tanpura in the
# arpeggio's); the recruitment scene crossfades from act 1 to act 2 on the
# beat the bezel falls away.

const Sim = preload("res://tests/sim.gd")
const ACT_2 := "res://data/music/act_2.tres"
const SCENE := "res://scenes/story/recruited.tscn"
# Story 21.3 adds strings and the song's hats on a shaker.
const STEMS := [&"drone", &"reed", &"strings", &"pluck", &"kick", &"frame_drum", &"shaker", &"mantra_reed", &"pulse",
	&"motif_bhima", &"motif_nala", &"motif_sanjaya", &"motif_sushena"]

func _stop() -> void:
	Music.play(null, 0.0)
	Music.clear_log()

func _manifest() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/music/manifest.json"))
	return d if d is Dictionary else {}

func _mix_is(on: Array) -> bool:
	if Music.score == null:
		return false
	for s in Music.score.stems:
		var want: float = s.level_db if (on.is_empty() or s.id in on) else Music.SILENT_DB
		if not is_equal_approx(Music.level(s.id), want):
			print("        %s at %.1f, want %.1f" % [s.id, Music.level(s.id), want])
			return false
	return true

func test_act_2_has_no_synth_stems() -> bool:
	var sc: Score = load(ACT_2)
	var m := _manifest()
	var synths: Array = m.get("synths", [])
	var listed: Dictionary = m.scores.get("act_2", {})
	var plays: Dictionary = listed.get("plays", {})
	var ok: bool = sc.id == &"act_2" and sc.stems.size() == STEMS.size() and synths.size() == 4 \
		and listed.get("stems", []) == STEMS.map(func(s): return String(s))
	for s in sc.stems:
		# Every stem says what plays it, and none is a synth (by instrument or by name).
		var inst: String = plays.get(String(s.id), "")
		if s.id not in STEMS or inst == "" or inst in synths or String(s.id) in synths:
			print("        %s played by '%s'" % [s.id, inst])
			ok = false
	# The kick is lighter than act 1's; the frame drum takes the clap's place.
	var act_1: Score = load("res://data/music/act_1.tres")
	return ok and sc.find(&"kick").level_db < act_1.find(&"kick").level_db and sc.find(&"clap") == null \
		and plays.get("reed", "") == "reed" and plays.get("pluck", "") == "tanpura"

func test_act_2_director_plays_act_2_with_the_state_levels() -> bool:
	_stop()
	var was := Career.team_id
	Career.team_id = &"skyline_juniors"
	var ok: bool = Career.act() == 2 and MusicDirector.score_for(2).id == &"act_2"
	MusicDirector.board()
	ok = ok and Music.score != null and Music.score.id == &"act_2" and _mix_is([&"drone", &"reed"])
	MusicDirector.set_mix(&"briefing", 0.0)
	ok = ok and _mix_is([&"drone", &"reed"])
	MusicDirector.set_mix(&"countdown", 0.0)
	ok = ok and _mix_is([&"drone", &"reed", &"pluck"])
	MusicDirector.set_mix(&"live", 0.0)
	ok = ok and _mix_is([])
	MusicDirector.set_mix(&"results", 0.0)
	ok = ok and _mix_is([&"drone", &"reed"])
	Career.team_id = was
	_stop()
	return ok

func test_bezel_drop_starts_the_crossfade_to_act_2() -> bool:
	_stop()
	var c: Cutscene = load("res://data/story/recruited.tres")
	# The bezel beat: the first beat without the bezel after beats with it.
	var drop := -1
	for i in range(1, c.beats.size()):
		if drop < 0 and c.beats[i - 1].bezel and not c.beats[i].bezel:
			drop = i
	var ok: bool = drop > 0 and c.score != null and c.score.id == &"act_1" \
		and c.beats[drop].score != null and c.beats[drop].score.id == &"act_2"
	for i in c.beats.size():
		ok = ok and (i == drop or c.beats[i].score == null)
	CutscenePlayer.replay = true
	Sim.tree().change_scene_to_file(SCENE)
	await Sim.process_frames(3)
	var p := Sim.tree().current_scene as CutscenePlayer
	ok = ok and p != null and Music.score != null and Music.score.id == &"act_1"
	while ok and is_instance_valid(p) and not p.done and p.index < drop:
		ok = ok and Music.score.id == &"act_1"
		p.t = p.beat.duration
		await Sim.process_frames(1)
	ok = ok and is_instance_valid(p) and p.index == drop and not p.bezel.visible and Music.score.id == &"act_2"
	var plays := Music.log.filter(func(e): return e.event == "play" and e.score == &"act_2")
	# A crossfade, not a cut: act 2 fades in over Music's fade time.
	ok = ok and plays.size() == 1 and plays[0].time > 0.0 and _mix_is([])
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)
	_stop()
	return ok
