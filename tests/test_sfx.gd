extends RefCounted
# Story 14.1: sound foundation. Named events from data on their buses, logged;
# unknown events warn; volumes and mute save and reload; every audio file is
# accounted for as generated or CC0.

const Sim = preload("res://tests/sim.gd")
const LICENSES := "res://data/audio/LICENSES.md"

## A bank with one event, a short silent clip, installed for the test.
func _bank() -> SoundBank:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(2205 * 2)
	wav.data = data
	var e := SoundEvent.new()
	e.id = &"test_blip"
	e.streams = [wav]
	e.bus = &"UI"
	var b := SoundBank.new()
	b.events = [e]
	return b

func test_buses_exist() -> bool:
	return Sfx.BUSES.all(func(b): return AudioServer.get_bus_index(b) >= 0)

func test_known_event_plays_on_its_bus_and_logs() -> bool:
	var saved := Sfx.bank
	Sfx.bank = _bank()
	Sfx.clear_log()
	var flat := Sfx.play(&"test_blip")
	var placed := Sfx.play(&"test_blip", Vector3(3, 4, 5))
	var ok: bool = flat is AudioStreamPlayer and flat.bus == &"UI" and placed is AudioStreamPlayer3D \
		and placed.global_position == Vector3(3, 4, 5) and Sfx.count(&"test_blip") == 2 \
		and Sfx.log[0].bus == &"UI" and Sfx.log[1].at == Vector3(3, 4, 5)
	placed.queue_free()
	Sfx.bank = saved
	return ok

func test_unknown_event_warns_without_crashing() -> bool:
	Sfx.clear_log()
	return Sfx.play(&"no_such_sound") == null and Sfx.log.is_empty()

func test_volume_and_mute_save_and_reload() -> bool:
	Sfx.set_volume(&"Flight", 0.5)
	Sfx.set_muted(true)
	GameSettings.volumes = {}
	GameSettings.muted = false
	SaveGame.load_all(Sim.tree())
	var flight := AudioServer.get_bus_index(&"Flight")
	var ok: bool = is_equal_approx(GameSettings.volumes.get("Flight", 1.0), 0.5) and GameSettings.muted \
		and is_equal_approx(AudioServer.get_bus_volume_db(flight), linear_to_db(0.5)) \
		and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master"))
	# Back to full and unmuted for the rest of the run.
	GameSettings.volumes = {}
	Sfx.set_muted(false)
	return ok and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master"))

func test_board_sound_dialog_sets_volumes() -> bool:
	var b: JobBoard = Sim.add(load("res://scenes/ui/job_board.tscn").instantiate())
	await Sim.process_frames(1)
	(b.find_child("Sound", true, false) as Button).pressed.emit()
	var slider: HSlider = b.sound.sliders[&"Weather"]
	slider.value = 0.25
	var ok := b.sound.visible and is_equal_approx(GameSettings.volumes.get("Weather", 1.0), 0.25)
	b.free()
	GameSettings.volumes = {}
	GameSettings.save()
	Sfx.apply_volumes()
	return ok

func test_every_audio_file_is_licensed() -> bool:
	var text := FileAccess.get_file_as_string(LICENSES)
	var listed := {}
	for line in text.split("\n"):
		var cells := line.split("|")
		if cells.size() >= 4:
			listed[cells[1].strip_edges().trim_prefix("`").trim_suffix("`")] = cells[3].strip_edges()
	var ok := text != ""
	for f in _audio_files("res://data/audio"):
		var licence: String = listed.get(f, "")
		if not licence in ["generated", "CC0"]:
			print("        unlisted or bad licence: %s (%s)" % [f, licence])
			ok = false
	return ok

func _audio_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.get_extension() in ["wav", "ogg", "mp3"]:
			out.append((dir + "/" + f).trim_prefix("res://data/audio/"))
	for sub in d.get_directories():
		out.append_array(_audio_files(dir + "/" + sub))
	return out
