extends RefCounted
# Story 16.4: Act 1, the home game. With Act 1 the MusicDirector plays act_1,
# a fully produced mantra pop score; each runner state (and the board) sets the
# stem levels listed for it. The intro started the act 1 score until Story
# 21.1, which gives it the title theme (the user's song).

const Sim = preload("res://tests/sim.gd")
const ACT_1 := "res://data/music/act_1.tres"
# Story 21.3 rebuilt it in the song's sound, adding keys, strings, snare,
# shaker, a fill and a counter line.
const STEMS := [&"drone", &"pad", &"keys", &"strings", &"arp", &"bass", &"kick", &"snare", &"shaker", &"clap",
	&"fill", &"counter", &"mantra_lead", &"pulse"]

func _stop() -> void:
	Music.play(null, 0.0)
	Music.clear_log()

## True when every stem of the playing score is at its level for `on` (base
## level) and silent otherwise; `on` empty means every stem.
func _mix_is(on: Array) -> bool:
	if Music.score == null:
		return false
	for s in Music.score.stems:
		var want: float = s.level_db if (on.is_empty() or s.id in on) else Music.SILENT_DB
		if not is_equal_approx(Music.level(s.id), want):
			print("        %s at %.1f, want %.1f" % [s.id, Music.level(s.id), want])
			return false
	return true

func test_act_1_is_the_full_pop_kit_over_the_drone() -> bool:
	var sc: Score = load(ACT_1)
	var ok: bool = sc.id == &"act_1" and sc.bars == 8 and sc.stems.size() == STEMS.size()
	for id in STEMS:
		ok = ok and sc.find(id) != null
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/music/manifest.json"))
	var listed: Dictionary = manifest.scores.get("act_1", {})
	return ok and listed.get("stems", []) == STEMS.map(func(s): return String(s)) \
		and is_equal_approx(listed.get("tempo", 0.0), sc.tempo)

func test_act_1_director_plays_act_1() -> bool:
	_stop()
	Career.team_id = &""
	var ok: bool = Career.act() == 1 and MusicDirector.score_for(1).id == &"act_1"
	MusicDirector.board()
	ok = ok and Music.score != null and Music.score.id == &"act_1" \
		and Music.log.front().event == "play" and Music.log.front().score == &"act_1"
	# Starting from silence, the board's levels apply at once.
	ok = ok and _mix_is([&"drone", &"pad"]) and MusicDirector.mix == &"board"
	for id in [&"arp", &"kick", &"mantra_lead"]:
		ok = ok and Music.players[id].volume_db <= Music.SILENT_DB
	_stop()
	return ok

## Since Story 17.13 the board plays the main title theme, every stem.
func test_the_board_plays_the_theme() -> bool:
	_stop()
	var b: JobBoard = Sim.add(load("res://scenes/ui/job_board.tscn").instantiate())
	await Sim.process_frames(1)
	var ok: bool = Music.score != null and Music.score.id == &"theme" and _mix_is([])
	b.free()
	_stop()
	return ok

func test_each_runner_state_sets_its_levels() -> bool:
	_stop()
	var job := Job.new()
	job.countdown = 0.2
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	runner.results_scene = null
	runner.begin()
	var ok: bool = runner.state == JobRunner.State.BRIEFING and Music.score.id == &"act_1" \
		and MusicDirector.mix == &"briefing" and _mix_is([&"drone", &"pad"])
	runner.launch()
	ok = ok and MusicDirector.mix == &"countdown" and _mix_is([&"drone", &"pad", &"arp"])
	var logged := Music.log.filter(func(e): return e.event == "level" and e.stem == &"arp")
	ok = ok and not logged.is_empty() and is_equal_approx(logged.back().db, Music.score.find(&"arp").level_db)
	while runner.state == JobRunner.State.COUNTDOWN:
		await Sim.tree().physics_frame
	ok = ok and runner.state == JobRunner.State.LIVE and MusicDirector.mix == &"live" and _mix_is([])
	runner.complete()
	ok = ok and MusicDirector.mix == &"results" and _mix_is([&"drone", &"pad"])
	root.free()
	# Failing lands on the results mix too.
	root = Sim.job_setup(job)
	runner = root.get_node("Runner")
	runner.results_scene = null
	runner.begin()
	runner.launch()
	runner.fail("test")
	ok = ok and runner.state == JobRunner.State.FAILED and _mix_is([&"drone", &"pad"])
	root.free()
	_stop()
	return ok

func test_levels_fade_and_reach_their_targets() -> bool:
	_stop()
	MusicDirector.board()
	MusicDirector.set_mix(&"live", 0.05)
	await Sim.process_frames(8)
	var ok := true
	for s in Music.score.stems:
		ok = ok and is_equal_approx(Music.players[s.id].volume_db, s.level_db)
	_stop()
	return ok

func test_runners_that_do_not_pay_out_leave_the_music_alone() -> bool:
	_stop()
	MusicDirector.board()
	var root := Sim.job_setup(Job.new())
	var runner: JobRunner = root.get_node("Runner")
	runner.pays_out = false
	runner.begin()
	runner.launch(true)
	var ok: bool = MusicDirector.mix == &"board" and _mix_is([&"drone", &"pad"])
	root.free()
	_stop()
	return ok

func test_intro_starts_the_theme() -> bool:
	_stop()
	var c: Cutscene = load("res://data/story/intro.tres")
	var ok: bool = c.score != null and c.score.resource_path == MusicDirector.THEME_PATH
	CutscenePlayer.replay = true
	Sim.tree().change_scene_to_file("res://scenes/story/intro.tscn")
	await Sim.process_frames(3)
	var p := Sim.tree().current_scene as CutscenePlayer
	ok = ok and p != null and not p.done and Music.score != null and Music.score.id == &"theme" \
		and Music.log.any(func(e): return e.event == "play" and e.score == &"theme") and _mix_is([])
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)
	_stop()
	return ok
