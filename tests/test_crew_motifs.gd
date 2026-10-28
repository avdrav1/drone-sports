extends RefCounted
# Story 16.10: crew motifs. Each crew member's Character.motif names a stem in
# the act scores that use it; the MusicDirector plays it only while Roster has
# them active, below its level while injured, and never again once they are
# dead, in every later score and after a save and reload (rule 7).

const MUSIC_DIR := "res://data/music"
const MANIFEST := "res://data/music/manifest.json"

func _reset() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()
	Music.play(null, 0.0)
	Music.clear_log()

func _manifest() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return d if d is Dictionary else {}

## Character id -> motif, for everyone who has one.
func _motifs() -> Dictionary:
	var out := {}
	for id in Roster.characters:
		if Roster.characters[id].motif != &"":
			out[id] = Roster.characters[id].motif
	return out

## Plays act `n`'s score fresh in mix `m`.
func _play(n: int, m := &"live") -> Score:
	Music.play(null, 0.0)
	var sc := MusicDirector.score_for(n)
	MusicDirector.play_score(sc, m)
	return sc

func test_every_motif_exists_in_the_act_scores_that_use_it() -> bool:
	var motifs := _motifs()
	var scores: Dictionary = _manifest().get("scores", {})
	# The crew have one each, distinct; nobody outside the crew has one.
	var ok: bool = motifs.size() == 4 and motifs.values().size() == motifs.size()
	for id in [&"bea", &"dot", &"marlo", &"ozzie"]:
		ok = ok and motifs.has(id)
	for id in Roster.characters:
		var c: Character = Roster.characters[id]
		ok = ok and (c.motif == &"" or c.can_be_harmed) and c.validate().is_empty()
	var used := {}
	for f in DirAccess.open(MUSIC_DIR).get_files():
		if not (f.begins_with("act_") and f.get_extension() == "tres"):
			continue
		var sc: Score = load(MUSIC_DIR + "/" + f)
		var listed: Dictionary = scores.get(String(sc.id), {})
		for m in listed.get("motifs", []):
			# Named in the manifest as used: the stem is in the score, says what
			# plays it, and is the same length as the rest (test_music checks).
			used[m] = used.get(m, []) + [sc.id]
			if sc.find(StringName(m)) == null or listed.get("plays", {}).get(m, "") == "":
				print("        %s: motif %s missing" % [sc.id, m])
				ok = false
		# Every motif stem in a score belongs to a crew member.
		for s in sc.stems:
			if String(s.id).begins_with("motif_") and not s.id in motifs.values():
				print("        %s: %s is nobody's motif" % [sc.id, s.id])
				ok = false
	for m in motifs.values():
		var acts: Array = used.get(String(m), [])
		ok = ok and acts.size() == 4
		for n in range(2, 6):
			ok = ok and StringName("act_%d" % n) in acts
	return ok

func test_active_crew_motifs_play_in_the_live_mix_only() -> bool:
	_reset()
	var ok := true
	for n in range(2, 6):
		var sc := _play(n)
		for m in _motifs().values():
			ok = ok and is_equal_approx(Music.level(m), sc.find(m).level_db) and sc.find(m).level_db > Music.SILENT_DB
		MusicDirector.set_mix(&"board", 0.0)
		for m in _motifs().values():
			ok = ok and Music.level(m) == Music.SILENT_DB
	_reset()
	return ok

func test_dead_motif_stays_silent_in_every_later_score_and_after_reload() -> bool:
	_reset()
	var sc := _play(2)
	var ok: bool = Music.level(&"motif_bea") > Music.SILENT_DB
	# Bea dies mid-score: her line falls away at once, the rest play on.
	Roster.kill(&"bea")
	ok = ok and Music.level(&"motif_bea") == Music.SILENT_DB \
		and is_equal_approx(Music.level(&"motif_dot"), sc.find(&"motif_dot").level_db)
	for n in range(2, 6):
		for m in [&"live", &"board", &"countdown", &"results"]:
			_play(n, m)
			ok = ok and Music.level(&"motif_bea") == Music.SILENT_DB
	# Saved and loaded again, and jobs go by: still gone.
	Roster.load_saved()
	for i in 5:
		Roster.job_done()
	ok = ok and Roster.status(&"bea") == Roster.Status.DEAD
	for n in range(2, 6):
		sc = _play(n)
		ok = ok and Music.level(&"motif_bea") == Music.SILENT_DB \
			and is_equal_approx(Music.level(&"motif_marlo"), sc.find(&"motif_marlo").level_db)
	# Nothing in the log ever raised it after the death.
	for e in Music.log:
		if e.event == "level" and e.stem == &"motif_bea" and e.db > Music.SILENT_DB:
			ok = false
	_reset()
	return ok

func test_injured_motif_plays_below_its_level() -> bool:
	_reset()
	Roster.injure(&"dot")
	var ok := true
	for n in range(2, 6):
		var sc := _play(n)
		var base: float = sc.find(&"motif_dot").level_db
		ok = ok and Music.level(&"motif_dot") < base and Music.level(&"motif_dot") > Music.SILENT_DB \
			and is_equal_approx(Music.level(&"motif_dot"), base - MusicDirector.INJURED_DB) \
			and is_equal_approx(Music.level(&"motif_ozzie"), sc.find(&"motif_ozzie").level_db)
	# Back on their feet after the bench: back to full.
	var sc5 := MusicDirector.score_for(5)
	for i in Roster.INJURY_JOBS:
		Roster.job_done()
	ok = ok and Roster.status(&"dot") == Roster.Status.ACTIVE \
		and is_equal_approx(Music.level(&"motif_dot"), sc5.find(&"motif_dot").level_db)
	_reset()
	return ok
