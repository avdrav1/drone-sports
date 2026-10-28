extends RefCounted
# Story 16.8: tension and weather. A hazard warning (or a collapse) drops every
# stem but `drone` and `pulse`, and clearing restores them; snow's full hush
# plays only the stems' muffled copies; the budget test (test_music.gd) still
# passes with the copies in data/music/.

const Sim = preload("res://tests/sim.gd")
const MUSIC_DIR := "res://data/music"
const TENSE := [&"drone", &"pulse"]

func _stop() -> void:
	Music.play(null, 0.0)
	Music.hush = 0.0
	Music.clear_log()

## True when every stem of the playing score is at its base level for `on`
## and silent otherwise; `on` empty means every stem.
func _mix_is(on: Array) -> bool:
	if Music.score == null:
		return false
	for s in Music.score.stems:
		var want: float = s.level_db if (on.is_empty() or s.id in on) else Music.SILENT_DB
		if not is_equal_approx(Music.level(s.id), want):
			print("        %s at %.1f, want %.1f" % [s.id, Music.level(s.id), want])
			return false
	return true

func test_every_act_score_has_a_drone_and_a_pulse() -> bool:
	var ok := true
	for f in DirAccess.open(MUSIC_DIR).get_files():
		if f.begins_with("act_") and f.get_extension() == "tres":
			var sc: Score = load(MUSIC_DIR + "/" + f)
			ok = ok and sc.find(&"drone") != null and sc.find(&"pulse") != null
	return ok and MusicDirector.MIXES[&"tension"] == TENSE

func test_a_warning_drops_all_but_drone_and_pulse() -> bool:
	_stop()
	var was := Career.team_id
	Career.team_id = &""
	var job := Job.new()
	job.countdown = 0.2
	job.crew_in_field = [&"marlo"] as Array[StringName]
	var root := Sim.job_setup(job)
	var zone := HazardZone.new()
	zone.character = &"marlo"
	root.add_child(zone)
	zone.global_position = Vector3(0, 5, -60)
	await Sim.go_live(root)
	await Sim.physics_frames(45)
	var ok: bool = Music.score.id == &"act_1" and not MusicDirector.tense() and _mix_is([])
	for i in 3:
		zone.threaten()
		await Sim.physics_frames(1)
	ok = ok and zone.warning() and MusicDirector.tense() and MusicDirector.mix == &"live" and _mix_is(TENSE)
	# The threat passes; after clear_after the warning ends and the full mix returns.
	await Sim.physics_frames(ceili(zone.clear_after * 60.0) + 5)
	ok = ok and not zone.warning() and not MusicDirector.tense() and _mix_is([])
	# A zone freed mid-warning lets go too.
	zone.threaten()
	await Sim.physics_frames(1)
	ok = ok and MusicDirector.tense()
	zone.free()
	ok = ok and not MusicDirector.tense() and _mix_is([])
	root.free()
	Career.team_id = was
	_stop()
	return ok

func test_a_collapse_drops_all_but_drone_and_pulse() -> bool:
	_stop()
	var was := Career.team_id
	Career.team_id = &""
	var job := Job.new()
	job.countdown = 0.2
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	var hz := HazardScene.new()
	hz.calm_after = 0.5
	var player := AnimationPlayer.new()
	player.name = "Timeline"
	var anim := Animation.new()
	anim.length = 2.0
	var t := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(t, NodePath("."))
	anim.track_insert_key(t, 0.5, {"method": &"fire_event", "args": [&"roof"]})
	var lib := AnimationLibrary.new()
	lib.add_animation(&"events", anim)
	player.add_animation_library(&"", lib)
	hz.add_child(player)
	player.root_node = NodePath("..")
	hz.runner = runner
	hz.timeline = player
	root.add_child(hz)
	runner.begin()
	runner.launch()
	while runner.state != JobRunner.State.LIVE:
		await Sim.physics_frames(1)
	var ok: bool = not MusicDirector.tense() and _mix_is([])
	while not hz.fired.has(&"roof"):
		await Sim.physics_frames(1)
	ok = ok and MusicDirector.tense() and _mix_is(TENSE)
	await Sim.physics_frames(ceili(hz.calm_after * 60.0) + 5)
	ok = ok and not MusicDirector.tense() and _mix_is([])
	root.free()
	Career.team_id = was
	_stop()
	return ok

func test_full_hush_plays_only_the_muffled_copies() -> bool:
	_stop()
	MusicDirector.play_score(load(MUSIC_DIR + "/act_1.tres"), &"live")
	var ok: bool = Music.muffled.size() == Music.score.stems.size()
	for s in Music.score.stems:
		var m: AudioStreamPlayer = Music.muffled[s.id]
		ok = ok and m.playing and m.stream == s.muffled and m.bus == Music.BUS \
			and is_equal_approx(Music.players[s.id].volume_db, s.level_db) and m.volume_db <= Music.SILENT_DB
	# Snow: WeatherSound's hush carries the music with the ambience.
	var root := Node3D.new()
	Sim.add(root)
	var sound: WeatherSound = WeatherState.of(root).get_node("Sound")
	var snow := Weather.new()
	snow.precipitation = Weather.Precipitation.SNOW
	snow.intensity = 1.0
	Weather.apply(snow, null, root)
	sound.advance(sound.hush_time * 0.5)
	ok = ok and is_equal_approx(Music.hush, 0.5)
	for s in Music.score.stems:
		ok = ok and Music.players[s.id].volume_db > Music.SILENT_DB and Music.muffled[s.id].volume_db > Music.SILENT_DB
	sound.advance(sound.hush_time)
	ok = ok and is_equal_approx(Music.hush, 1.0)
	for s in Music.score.stems:
		ok = ok and Music.players[s.id].volume_db <= Music.SILENT_DB \
			and is_equal_approx(Music.muffled[s.id].volume_db, s.level_db)
	# A fade under full hush moves only the muffled copy.
	MusicDirector.set_mix(&"board", 0.0)
	var arp: Stem = Music.score.find(&"arp")
	ok = ok and Music.muffled[&"arp"].volume_db <= Music.SILENT_DB \
		and is_equal_approx(Music.muffled[&"drone"].volume_db, Music.score.find(&"drone").level_db) \
		and Music.players[&"drone"].volume_db <= Music.SILENT_DB and arp != null
	# The snow scene going away lifts the hush.
	root.free()
	ok = ok and Music.hush == 0.0 and is_equal_approx(Music.players[&"drone"].volume_db, Music.score.find(&"drone").level_db)
	_stop()
	return ok
