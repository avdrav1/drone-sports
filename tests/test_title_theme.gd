extends RefCounted
# Story 17.13: the main title theme plays on the title and the job board,
# every stem, whatever the act, and keeps playing from one to the other; jobs
# still bring in the act's score.

const Sim = preload("res://tests/sim.gd")
const TITLE := "res://scenes/ui/title.tscn"
const BOARD := "res://scenes/ui/job_board.tscn"

func _stop() -> void:
	Music.play(null, 0.0)
	Music.clear_log()

func _all_at_level() -> bool:
	if Music.score == null:
		return false
	for s in Music.score.stems:
		if not is_equal_approx(Music.level(s.id), s.level_db):
			return false
	return true

func _plays() -> Array:
	return Music.log.filter(func(e): return e.event == "play")

func test_theme_is_generated_in_the_key() -> bool:
	var sc: Score = load(MusicDirector.THEME_PATH)
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/music/manifest.json"))
	var listed: Dictionary = m.scores.get("theme", {})
	var ids: Array = sc.stems.map(func(s): return String(s.id))
	return sc.id == &"theme" and ids == ["orchestra", "drums"] and listed.get("stems", []) == ids \
		and is_equal_approx(sc.tonic, m.tonic) and listed.get("call", "") == "mantra call" \
		and listed.get("answer", "") == "mantra answer" \
		and ["brass", "strings", "timpani", "snare"].all(func(i): return i in m.instruments)

func test_title_plays_every_stem_of_the_theme() -> bool:
	_stop()
	MusicDirector.title()
	var ok: bool = Music.score.id == &"theme" and MusicDirector.mix == &"title" and _all_at_level()
	_stop()
	return ok

func test_title_to_board_keeps_the_theme_playing() -> bool:
	_stop()
	var was := Career.team_id
	var ok := true
	for team in [&"", &"skyline_juniors"]:
		Career.team_id = team
		_stop()
		Sim.tree().change_scene_to_file(TITLE)
		await Sim.process_frames(3)
		ok = ok and Music.score != null and Music.score.id == &"theme" and _all_at_level()
		Sim.tree().change_scene_to_file(BOARD)
		await Sim.process_frames(3)
		# One play, from the title: the board picks up the same score.
		ok = ok and Music.score.id == &"theme" and _plays().size() == 1
		Sim.tree().unload_current_scene()
		await Sim.process_frames(1)
	Career.team_id = was
	_stop()
	return ok

func test_a_job_still_plays_the_act_score() -> bool:
	_stop()
	MusicDirector.title()
	MusicDirector.board()
	var ok: bool = Music.score.id == &"act_1" and MusicDirector.mix == &"board"
	_stop()
	return ok
