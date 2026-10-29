extends RefCounted
# Story 21.1: the song as the theme. data/music/theme.tres is one stem, a
# stretch of the user's own song cut on bar lines, that loops with no gap or
# click (checked on the decoded samples either side of the loop point). It
# plays from the title, through the intro, to the board in every act a team
# can be in; a job still plays its act's score. 17.13's generated stems are
# gone, data/music/ stays under 10 MB, and the song is listed as own work.

const Sim = preload("res://tests/sim.gd")
const TITLE := "res://scenes/ui/title.tscn"
const BOARD := "res://scenes/ui/job_board.tscn"
const MUSIC_DIR := "res://data/music"
const LICENSES := "res://data/audio/LICENSES.md"
const BUDGET := 10 * 1024 * 1024
## Samples looked at on each side of the loop point.
const NEAR := 1024
## No team or none (Act 1), then a team for each of Acts 2, 3 and 4.
const TEAMS := [&"", &"skyline_juniors", &"city_rescue_air", &"deadweight"]

func _stop() -> void:
	Music.play(null, 0.0)
	Music.clear_log()

func _song() -> Stem:
	var sc: Score = load(MusicDirector.THEME_PATH)
	return sc.find(&"song")

func test_theme_is_one_looping_stem_of_the_song() -> bool:
	var sc: Score = load(MusicDirector.THEME_PATH)
	var s := _song()
	var ok: bool = sc.id == &"theme" and sc.stems.size() == 1 and s != null \
		and s.stream is AudioStreamOggVorbis and s.muffled is AudioStreamOggVorbis \
		and (s.stream as Resource).resource_path == MUSIC_DIR + "/theme_song.ogg"
	_stop()
	MusicDirector.title()
	var p: AudioStreamPlayer = Music.players.get(&"song")
	ok = ok and p != null and p.playing and (p.stream as AudioStreamOggVorbis).loop \
		and is_zero_approx((p.stream as AudioStreamOggVorbis).loop_offset)
	_stop()
	return ok

## Interleaved stereo 16-bit samples of `path`, decoded by ffmpeg.
func _decode(path: String) -> PackedByteArray:
	var raw := "user://song_theme_seam.raw"
	var out := []
	var code := OS.execute("ffmpeg", ["-loglevel", "error", "-y", "-i", ProjectSettings.globalize_path(path),
		"-ac", "2", "-f", "s16le", ProjectSettings.globalize_path(raw)], out, true)
	if code != 0:
		print("        ffmpeg exited %d: %s" % [code, "".join(out).strip_edges()])
		return PackedByteArray()
	var bytes := FileAccess.get_file_as_bytes(raw)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(raw))
	return bytes

func _rms_db(bytes: PackedByteArray, ch: int, from: int, count: int) -> float:
	var sum := 0.0
	for i in count:
		var v := bytes.decode_s16(((from + i) * 2 + ch) * 2) / 32768.0
		sum += v * v
	return linear_to_db(sqrt(sum / count))

## The jump from the last sample to the first is no bigger than the steps the
## song itself takes either side of the loop point (its 99th percentile), and
## neither side is silent: no click and no gap. Both the song and its muffled copy.
func test_loop_point_has_no_click_or_gap() -> bool:
	var ok := true
	for path in [MUSIC_DIR + "/theme_song.ogg", MUSIC_DIR + "/theme_song_muffled.ogg"]:
		var bytes := _decode(path)
		var n := bytes.size() / 4
		if n < NEAR * 4:
			return false
		for ch in 2:
			var at := func(i: int) -> int: return bytes.decode_s16((i * 2 + ch) * 2)
			var steps: Array[int] = []
			for i in range(n - NEAR, n):
				steps.append(absi(at.call(i) - at.call(i - 1)))
			for i in range(1, NEAR):
				steps.append(absi(at.call(i) - at.call(i - 1)))
			steps.sort()
			var jump := absi(at.call(0) - at.call(n - 1))
			var limit: int = steps[int(steps.size() * 0.99)]
			var tail := _rms_db(bytes, ch, n - 2205, 2205)
			var head := _rms_db(bytes, ch, 0, 2205)
			if jump > limit or tail < -40.0 or head < -40.0:
				print("        %s ch %d: jump %d (limit %d), last 50 ms %.1f dB, first %.1f dB" % [path, ch, jump, limit, tail, head])
				ok = false
	return ok

func test_title_intro_and_board_play_the_song_in_every_act() -> bool:
	var was := Career.team_id
	var ok: bool = (load("res://data/story/intro.tres") as Cutscene).score.resource_path == MusicDirector.THEME_PATH
	for team in TEAMS:
		Career.team_id = team
		_stop()
		Sim.tree().change_scene_to_file(TITLE)
		await Sim.process_frames(3)
		ok = ok and Music.score != null and Music.score.id == &"theme" \
			and is_equal_approx(Music.level(&"song"), _song().level_db)
		Sim.tree().change_scene_to_file(BOARD)
		await Sim.process_frames(3)
		# One play, from the title: the board keeps the song going.
		var plays := Music.log.filter(func(e): return e.event == "play")
		ok = ok and Music.score.id == &"theme" and plays.size() == 1 and Music.players[&"song"].playing
		if not ok:
			print("        team %s (act %d): %s" % [team, Career.act(), Music.log])
		Sim.tree().unload_current_scene()
		await Sim.process_frames(1)
	Career.team_id = was
	_stop()
	return ok

func test_a_job_still_plays_its_act_score() -> bool:
	var was := Career.team_id
	var ok := true
	for team in TEAMS:
		Career.team_id = team
		_stop()
		MusicDirector.title()
		var job := Job.new()
		var runner := JobRunner.new()
		runner.job = job
		MusicDirector._on_state(JobRunner.State.LIVE, JobRunner.State.COUNTDOWN, runner)
		ok = ok and Music.score.id == StringName("act_%d" % Career.act())
		runner.free()
	Career.team_id = was
	_stop()
	return ok

func test_old_generated_theme_stems_are_gone() -> bool:
	var ok := true
	for f in DirAccess.open(MUSIC_DIR).get_files():
		if f.begins_with("theme_") and not f.begins_with("theme_song"):
			print("        left over: %s" % f)
			ok = false
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MUSIC_DIR + "/manifest.json"))
	return ok and m.scores.theme.stems == ["song"]

func test_music_folder_stays_under_ten_mb() -> bool:
	var total := 0
	for f in DirAccess.open(MUSIC_DIR).get_files():
		if f.get_extension() != "import":
			total += FileAccess.open(MUSIC_DIR + "/" + f, FileAccess.READ).get_length()
	return total > 0 and total < BUDGET

func test_song_files_are_listed_as_own_work() -> bool:
	var listed := {}
	for line in FileAccess.get_file_as_string(LICENSES).split("\n"):
		var cells := line.split("|")
		if cells.size() >= 4:
			listed[cells[1].strip_edges().trim_prefix("`").trim_suffix("`")] = cells[3].strip_edges()
	return listed.get("../music/theme_song.ogg", "") == "own work" \
		and listed.get("../music/theme_song_muffled.ogg", "") == "own work"
