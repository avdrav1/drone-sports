extends Node
# Plays named sound events from the SoundBank (Story 14.1). Sfx.play(id) for a
# flat sound, Sfx.play(id, position) for one placed in the world. Every play is
# logged, so headless tests can check what sounded. Volumes per bus and mute
# live in GameSettings and are saved with the settings. Sound is never needed
# to play: every cue that matters has a visual too.

const BANK := "res://data/audio/bank.tres"
const BUSES: Array[StringName] = [&"Master", &"Flight", &"World", &"Weather", &"UI", &"Voice"]
## Players kept for flat sounds; the oldest is reused when all are busy.
const POOL := 12
## Log entries kept.
const LOG_SIZE := 256

var bank: SoundBank
## Recent plays, oldest first: {id, bus, at (Vector3 or null), gain_db, pitch, msec}.
var log: Array[Dictionary] = []
var _flat: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bank = load(BANK) if ResourceLoader.exists(BANK) else SoundBank.new()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_flat.append(p)
	apply_volumes()

## Plays event `id`. With `at`, a 3D sound at that world point (it frees itself
## when done). `gain_db` is added to the event's volume (louder impacts), and
## `pitch` scales its pitch (a speaker's chirp). Returns the player, or null
## when the event is unknown or silent.
func play(id: StringName, at: Variant = null, gain_db := 0.0, pitch := 1.0) -> Node:
	var e := bank.find(id) if bank else null
	if e == null:
		push_warning("Sfx: no sound event '%s'" % id)
		return null
	_log(id, e.bus, at, gain_db, pitch)
	if e.streams.is_empty():
		return null
	var stream: AudioStream = e.streams[_rng.randi() % e.streams.size()]
	pitch *= 1.0 + _rng.randf_range(-e.pitch_variance, e.pitch_variance)
	if at is Vector3:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = stream
		p3.volume_db = e.volume_db + gain_db
		p3.pitch_scale = pitch
		p3.bus = e.bus
		p3.finished.connect(p3.queue_free)
		get_tree().root.add_child(p3)
		p3.global_position = at
		p3.play()
		return p3
	var p := _flat[_next]
	_next = (_next + 1) % _flat.size()
	p.stream = stream
	p.volume_db = e.volume_db + gain_db
	p.pitch_scale = pitch
	p.bus = e.bus
	p.play()
	return p

## How many times `id` played since the log was last cleared.
func count(id: StringName) -> int:
	return log.filter(func(l): return l.id == id).size()

func clear_log() -> void:
	log.clear()

func _log(id: StringName, bus: StringName, at: Variant, gain_db := 0.0, pitch := 1.0) -> void:
	log.append({"id": id, "bus": bus, "at": at, "gain_db": gain_db, "pitch": pitch, "msec": Time.get_ticks_msec()})
	if log.size() > LOG_SIZE:
		log.pop_front()

## Settings were read again (SaveGame.load_all): put them on the buses.
func load_saved() -> void:
	apply_volumes()

## Bus volumes and mute from GameSettings onto the AudioServer.
func apply_volumes() -> void:
	for b in BUSES:
		var i := AudioServer.get_bus_index(b)
		if i < 0:
			continue
		var v: float = GameSettings.volumes.get(String(b), 1.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.0 or (b == &"Master" and GameSettings.muted))

func set_volume(bus: StringName, linear: float) -> void:
	GameSettings.volumes[String(bus)] = clampf(linear, 0.0, 1.0)
	GameSettings.save()
	apply_volumes()

func set_muted(on: bool) -> void:
	GameSettings.muted = on
	GameSettings.save()
	apply_volumes()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mute"):
		set_muted(not GameSettings.muted)
