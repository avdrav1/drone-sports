extends RefCounted
# Story 16.1: music foundation. A Score's stems start on one frame on the Music
# bus and every play and fade is logged; every score's stems are the same
# length in samples; the Music volume saves, reloads and mutes; data/music/
# stays under budget and every file in it is licensed as generated.

const Sim = preload("res://tests/sim.gd")
const MUSIC_DIR := "res://data/music"
const LICENSES := "res://data/audio/LICENSES.md"
const BUDGET := 8 * 1024 * 1024

## Two stems of silence, one quieter, for tests that need more than one.
func _score(id: StringName) -> Score:
	var sc := Score.new()
	sc.id = id
	for k in 2:
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var data := PackedByteArray()
		data.resize(22050 * 2)
		wav.data = data
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = 22050
		var s := Stem.new()
		s.id = [&"drone", &"pad"][k]
		s.stream = wav
		s.level_db = [-6.0, -18.0][k]
		sc.stems.append(s)
	return sc

func _stop() -> void:
	Music.play(null, 0.0)
	Music.clear_log()

func test_music_bus_and_slider_exist() -> bool:
	return AudioServer.get_bus_index(Music.BUS) >= 0 and Music.BUS in Sfx.BUSES \
		and AudioServer.get_bus_send(AudioServer.get_bus_index(Music.BUS)) == &"Master"

func test_play_starts_every_stem_on_one_frame_and_logs() -> bool:
	_stop()
	var sc := _score(&"test_a")
	var frame := Engine.get_process_frames()
	Music.play(sc)
	var ok: bool = Music.score == sc and Music.players.size() == 2
	for s in sc.stems:
		var p: AudioStreamPlayer = Music.players[s.id]
		ok = ok and p.playing and p.bus == Music.BUS and p.stream == s.stream \
			and is_equal_approx(p.volume_db, s.level_db) and is_equal_approx(Music.level(s.id), s.level_db)
	var e: Dictionary = Music.log.back()
	ok = ok and Music.log.size() == 1 and e.event == "play" and e.score == &"test_a" \
		and e.stems == [&"drone", &"pad"] and e.frame == frame
	_stop()
	return ok

func test_play_crossfades_from_the_current_score() -> bool:
	_stop()
	var a := _score(&"test_a")
	var b := _score(&"test_b")
	Music.play(a, 0.0)
	var old: AudioStreamPlayer = Music.players[&"drone"]
	Music.play(b, 0.1)
	var fresh: AudioStreamPlayer = Music.players[&"drone"]
	var ok: bool = fresh != old and fresh.volume_db <= Music.SILENT_DB and fresh.playing \
		and Music.score == b and Music.log.back().score == &"test_b" and is_equal_approx(Music.log.back().time, 0.1)
	await Sim.process_frames(12)
	ok = ok and not is_instance_valid(old) and is_equal_approx(fresh.volume_db, -6.0)
	# The same score again changes nothing.
	var n := Music.log.size()
	Music.play(b)
	ok = ok and Music.log.size() == n and Music.players[&"drone"] == fresh
	_stop()
	return ok

func test_set_level_fades_one_stem_and_logs() -> bool:
	_stop()
	Music.play(_score(&"test_a"), 0.0)
	Music.set_level(&"pad", -3.0, 0.05)
	var e: Dictionary = Music.log.back()
	var ok: bool = e.event == "level" and e.stem == &"pad" and is_equal_approx(e.db, -3.0) \
		and is_equal_approx(Music.level(&"pad"), -3.0)
	await Sim.process_frames(6)
	ok = ok and is_equal_approx(Music.players[&"pad"].volume_db, -3.0) \
		and is_equal_approx(Music.players[&"drone"].volume_db, -6.0)
	# Unknown stems warn and log nothing.
	var n := Music.log.size()
	Music.set_level(&"no_such_stem", 0.0)
	ok = ok and Music.log.size() == n
	_stop()
	return ok

func test_every_score_plays_with_same_length_stems() -> bool:
	var scores := _scores()
	var ok := not scores.is_empty()
	for path in scores:
		var sc: Score = load(path)
		var lengths := {}
		for s in sc.stems:
			var file := (s.stream as Resource).resource_path
			lengths[_ogg_samples(file)] = true
			ok = ok and s.stream is AudioStreamOggVorbis and s.id != &""
		if sc.stems.is_empty() or lengths.size() != 1 or lengths.has(-1):
			print("        %s: stem lengths %s" % [path, lengths.keys()])
			ok = false
		elif sc.tempo > 0.0:
			# The loop is the score's bars at its tempo, to the sample.
			var expected := roundi(sc.bars * 4 * 60.0 / sc.tempo * 22050)
			ok = ok and lengths.keys()[0] == expected
	return ok

func test_placeholder_is_one_sine_on_the_tonic() -> bool:
	var sc: Score = load(MUSIC_DIR + "/placeholder.tres")
	return sc.id == &"placeholder" and sc.stems.size() == 1 and sc.find(&"tonic") != null and sc.tonic > 0.0

func test_music_volume_saves_reloads_and_mutes() -> bool:
	Sfx.set_volume(Music.BUS, 0.4)
	GameSettings.volumes = {}
	SaveGame.load_all(Sim.tree())
	var i := AudioServer.get_bus_index(Music.BUS)
	var ok: bool = is_equal_approx(GameSettings.volumes.get("Music", 1.0), 0.4) \
		and is_equal_approx(AudioServer.get_bus_volume_db(i), linear_to_db(0.4))
	# Its own slider at zero silences it; so does the global mute, through Master.
	Sfx.set_volume(Music.BUS, 0.0)
	ok = ok and AudioServer.is_bus_mute(i)
	Sfx.set_volume(Music.BUS, 1.0)
	Sfx.set_muted(true)
	ok = ok and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")) \
		and AudioServer.get_bus_send(i) == &"Master"
	GameSettings.volumes = {}
	Sfx.set_muted(false)
	return ok and not AudioServer.is_bus_mute(i)

func test_board_sound_dialog_has_music_slider() -> bool:
	var b: JobBoard = Sim.add(load("res://scenes/ui/job_board.tscn").instantiate())
	await Sim.process_frames(1)
	(b.find_child("Sound", true, false) as Button).pressed.emit()
	var slider: HSlider = b.sound.sliders.get(Music.BUS)
	var ok := slider != null
	if ok:
		slider.value = 0.3
		ok = is_equal_approx(GameSettings.volumes.get("Music", 1.0), 0.3)
	b.free()
	GameSettings.volumes = {}
	GameSettings.save()
	Sfx.apply_volumes()
	return ok

func test_music_folder_is_under_budget() -> bool:
	var total := 0
	var d := DirAccess.open(MUSIC_DIR)
	for f in d.get_files():
		if f.get_extension() == "import":
			continue
		var fa := FileAccess.open(MUSIC_DIR + "/" + f, FileAccess.READ)
		total += fa.get_length()
	return total > 0 and total < BUDGET

func test_every_music_file_is_licensed_as_generated() -> bool:
	var text := FileAccess.get_file_as_string(LICENSES)
	var listed := {}
	for line in text.split("\n"):
		var cells := line.split("|")
		if cells.size() >= 4:
			listed[cells[1].strip_edges().trim_prefix("`").trim_suffix("`")] = cells[3].strip_edges()
	var ok := true
	var any := false
	for f in DirAccess.open(MUSIC_DIR).get_files():
		if f.get_extension() in ["wav", "ogg", "mp3"]:
			any = true
			if listed.get("../music/" + f, "") != "generated":
				print("        unlisted or not generated: data/music/%s" % f)
				ok = false
	return ok and any

func _scores() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.open(MUSIC_DIR).get_files():
		if f.get_extension() == "tres":
			out.append(MUSIC_DIR + "/" + f)
	return out

## Samples in an Ogg Vorbis file: the granule position of its last page, or -1.
func _ogg_samples(path: String) -> int:
	var bytes := FileAccess.get_file_as_bytes(path)
	var at := bytes.size() - 27
	while at >= 0:
		if bytes[at] == 0x4F and bytes[at + 1] == 0x67 and bytes[at + 2] == 0x67 and bytes[at + 3] == 0x53:
			return bytes.decode_s64(at + 6)
		at -= 1
	return -1
