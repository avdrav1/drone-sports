extends RefCounted
# Story 16.6: Acts 3 and 4, hand and voice. Each act plays its own score;
# neither has a synth or kick stem (hand percussion and the sung hook instead);
# Act 4 is the same group, faster; both use the 16.4 state levels.

const SCORES := {3: "res://data/music/act_3.tres", 4: "res://data/music/act_4.tres"}
## A team of each act, to put the career there.
const TEAMS := {3: &"cannery_row", 4: &"halcyon_racing"}
const STEMS := [&"drone", &"reed", &"pluck", &"frame_drum", &"cymbals", &"mantra_voice", &"pulse",
	&"motif_bea", &"motif_dot", &"motif_marlo", &"motif_ozzie"]

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

func test_each_act_plays_its_own_score() -> bool:
	_stop()
	var was := Career.team_id
	var ok := true
	for act in SCORES:
		Career.team_id = TEAMS[act]
		ok = ok and Career.act() == act and MusicDirector.score_for(act).resource_path == SCORES[act]
		MusicDirector.board()
		ok = ok and Music.score != null and Music.score.id == StringName("act_%d" % act) \
			and Music.log.back().event in ["play", "level"] \
			and Music.log.any(func(e): return e.event == "play" and e.score == StringName("act_%d" % act))
		# The 16.4 state levels, with the harmonium and pluck in the pad's and arpeggio's places.
		ok = ok and _mix_is([&"drone", &"reed"])
		MusicDirector.set_mix(&"countdown", 0.0)
		ok = ok and _mix_is([&"drone", &"reed", &"pluck"])
		MusicDirector.set_mix(&"live", 0.0)
		ok = ok and _mix_is([])
		MusicDirector.set_mix(&"results", 0.0)
		ok = ok and _mix_is([&"drone", &"reed"])
		_stop()
	Career.team_id = was
	return ok

func test_neither_has_synth_or_kick_stems() -> bool:
	var m := _manifest()
	var banned: Array = m.get("synths", []) + ["kick"]
	var ok := banned.size() == 5
	for act in SCORES:
		var sc: Score = load(SCORES[act])
		var plays: Dictionary = m.scores.get("act_%d" % act, {}).get("plays", {})
		ok = ok and sc.stems.size() == STEMS.size() and plays.get("mantra_voice", "") == "voice" \
			and plays.get("frame_drum", "") == "frame_drum" and plays.get("cymbals", "") == "cymbals"
		for s in sc.stems:
			var inst: String = plays.get(String(s.id), "")
			if s.id not in STEMS or inst == "" or inst in banned or String(s.id) in banned:
				print("        act %d: %s played by '%s'" % [act, s.id, inst])
				ok = false
	return ok

func test_act_4_is_faster_than_act_3() -> bool:
	var a3: Score = load(SCORES[3])
	var a4: Score = load(SCORES[4])
	var m: Dictionary = _manifest().scores
	return a4.tempo > a3.tempo and is_equal_approx(m.act_3.tempo, a3.tempo) and is_equal_approx(m.act_4.tempo, a4.tempo) \
		and a3.bars == a4.bars
