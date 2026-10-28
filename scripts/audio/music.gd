extends Node
# Plays a Score (Story 16.1). Music.play(score) starts every stem on one frame,
# each a plain AudioStreamPlayer on the Music bus at its stem's level, and fades
# out whatever played before over fade_time. Music.set_level(stem, db, time)
# fades one stem. The music changes only by stem volumes, never by live bus
# effects (the web build has no threads). Every play and level change is
# logged, so headless tests can check them. On web, as with Sfx, nothing is
# heard until the browser lets audio start on the first input. The Music bus's
# volume and mute live in GameSettings with the rest (Sfx.apply_volumes).

const BUS := &"Music"
## Below this a stem counts as silent.
const SILENT_DB := -80.0
const LOG_SIZE := 256

## Seconds a play() crossfade or set_level() takes by default.
@export var fade_time := 2.0

## The score playing now, or null.
var score: Score
## Stem id -> its player, for the current score.
var players := {}
## Stem id -> the level it is at or fading to (dB).
var levels := {}
## Recent events, oldest first: {event: "play"|"level", score, stem, db, time, frame, msec}.
var log: Array[Dictionary] = []
var _tweens := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Crossfades to `next` over `time` (fade_time if negative). Every stem starts
## on this frame; with nothing playing before, they start at their levels at
## once. play(null) fades the music out. Playing the current score again does
## nothing.
func play(next: Score, time := -1.0) -> void:
	if next == score:
		return
	if time < 0.0:
		time = fade_time
	var fading_in := score != null and time > 0.0
	for id in players:
		_fade_out(players[id], time)
	players = {}
	levels = {}
	_tweens = {}
	score = next
	if next == null:
		_log({"event": "play", "score": &"", "stems": [], "time": time})
		return
	var started: Array[StringName] = []
	for s in next.stems:
		var p := AudioStreamPlayer.new()
		p.name = "Stem_%s" % s.id
		p.stream = s.stream
		if s.stream is AudioStreamOggVorbis:
			s.stream.loop = true
		p.bus = BUS
		p.volume_db = SILENT_DB if fading_in else s.level_db
		add_child(p)
		players[s.id] = p
		levels[s.id] = s.level_db
		started.append(s.id)
	for id in started:
		players[id].play()
	_log({"event": "play", "score": next.id, "stems": started, "time": time})
	if fading_in:
		for s in next.stems:
			_fade(s.id, s.level_db, time)

## Fades stem `stem_id` of the current score to `db` over `time` (fade_time if
## negative). Unknown stems warn and change nothing.
func set_level(stem_id: StringName, db: float, time := -1.0) -> void:
	if not players.has(stem_id):
		push_warning("Music: no stem '%s'" % stem_id)
		return
	if time < 0.0:
		time = fade_time
	levels[stem_id] = db
	_log({"event": "level", "score": score.id, "stem": stem_id, "db": db, "time": time})
	_fade(stem_id, db, time)

## The level stem `stem_id` is at or fading to, or SILENT_DB if it is not playing.
func level(stem_id: StringName) -> float:
	return levels.get(stem_id, SILENT_DB)

func clear_log() -> void:
	log.clear()

func _fade(stem_id: StringName, db: float, time: float) -> void:
	var p: AudioStreamPlayer = players[stem_id]
	if _tweens.has(stem_id):
		_tweens[stem_id].kill()
	if time <= 0.0:
		p.volume_db = db
		_tweens.erase(stem_id)
		return
	var t := create_tween()
	t.tween_property(p, "volume_db", db, time)
	_tweens[stem_id] = t

func _fade_out(p: AudioStreamPlayer, time: float) -> void:
	if time <= 0.0:
		p.queue_free()
		return
	var t := create_tween()
	t.tween_property(p, "volume_db", SILENT_DB, time)
	t.tween_callback(p.queue_free)

func _log(entry: Dictionary) -> void:
	entry["frame"] = Engine.get_process_frames()
	entry["msec"] = Time.get_ticks_msec()
	log.append(entry)
	if log.size() > LOG_SIZE:
		log.pop_front()
