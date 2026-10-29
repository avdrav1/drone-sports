class_name Bark
extends Node
# Crew lines on job events: briefing, gate passed, strike warning, strike,
# complete, fail, and results. Lines are data (data/dialogue/<id>.json), picked by
# the speaker's status. The dead never speak, and a line never repeats within a
# job unless it is the only one. On a strike the line matches how the character
# was before it, and a strike that kills leaves only a memorial line on the
# results screen. Every line announced on `spoke` plays its speaker's chirp
# (Story 14.8); lines kept for the results screen chirp when shown there.
# Story 17.2: a line is a string or {"text": ..., "face": ...}; the face is one
# of CharacterPortrait.EXPRESSIONS, or the event's default when it has none.
# Story 17.4: `pitch` is a job card's one-liner on the board, never said in a job.
# Story 17.7: every announced line also goes out on `said` with its face, for the
# radio panel, which then plays the chirp itself when the line opens.
# Story 17.9: the crew react to a FlightWatcher's flight events, each line with a
# face; who reacts from afar is their `speaks_on`.
# Story 18.4: a line may say {you}, filled from the speaker's `calls_you`.
# Story 18.6: the chirp follows the line's face (CHIRPS); strike, injury and
# memorial lines keep the plain one.
# Story 18.5: little moments (MOMENTS): a hello on the board, a cheer on a
# streak of clean gates, a retry of the job just failed, an unlock, and a
# goodbye. Any living crew member but the pilot you fly as may say one, each at
# most once a MOMENT_COOLDOWN per moment; none is said on a boss job.
# Story 18.8: babble_for picks the speaker's babble loop for a line (slower and
# lower on serious lines, none for memorials or the dead); the radio plays it.
# Holds no character or job names.

const EVENTS: Array[StringName] = [&"briefing", &"gate_passed", &"warning", &"strike", &"complete", &"fail", &"results", &"pitch",
	&"takeoff", &"near_miss", &"low_pass", &"top_speed", &"battery_low", &"crash", &"reset", &"weather_change", &"long_hover",
	&"hello", &"streak", &"retry", &"unlock", &"goodbye"]
## The face a line makes when its entry names none. Other events look neutral.
const DEFAULT_FACES := {
	&"briefing": &"determined",
	&"gate_passed": &"happy",
	&"warning": &"shocked",
	&"strike": &"sad",
	&"complete": &"happy",
	&"fail": &"sad",
	&"hello": &"happy",
	&"streak": &"happy",
	&"retry": &"determined",
	&"unlock": &"happy",
	&"goodbye": &"happy",
}

## The little moments (Story 18.5), and the least seconds before the same
## character says the same one again.
const MOMENTS: Array[StringName] = [&"hello", &"streak", &"retry", &"unlock", &"goodbye"]
const MOMENT_COOLDOWN := 60.0

## The chirp variant for each face (Story 18.6). Sound events in the bank.
const CHIRPS := {
	&"neutral": &"crew_chirp",
	&"happy": &"crew_chirp_happy",
	&"determined": &"crew_chirp_happy",
	&"worried": &"crew_chirp_worried",
	&"shocked": &"crew_chirp_worried",
	&"sad": &"crew_chirp_sad",
}
## A happy or eager line on these events celebrates: the giggle trill.
const CELEBRATE_EVENTS: Array[StringName] = [&"complete", &"unlock", &"streak"]
const CELEBRATE_CHIRP := &"crew_chirp_celebrate"
## Serious events keep the plain chirp whatever the face.
const PLAIN_EVENTS: Array[StringName] = [&"warning", &"strike", &"hurt", &"memorial"]
## Serious lines babble slower and lower (Story 18.8): their loop played at this
## pitch scale, a fourth down (a ratio of the key's scale, so it stays in key).
const SERIOUS_BABBLE: Array[StringName] = [&"warning", &"strike", &"hurt"]
const SERIOUS_BABBLE_PITCH := 0.75
## Lines said in silence: no babble at all.
const SILENT_BABBLE: Array[StringName] = [&"memorial"]

signal spoke(id: StringName, event: StringName, text: String)
## Every line announced on `spoke`, as {id, event, text, face}. A line emitted
## straight onto `spoke` (Marlo's trench calls) comes here too, its face read
## from its entry.
signal said(line: Dictionary)

@export var runner: JobRunner
## Optional: gate callouts on a race.
@export var course: Course
## Optional: the drone's flight events (Story 17.8).
@export var watcher: FlightWatcher
## Seconds between gate callouts, so a fast lap is not a wall of text.
@export var gate_gap := 2.5
## Clean gates in a row that make a streak (Story 18.5).
@export var streak_gates := 5
## Seeds who speaks and which line. Negative picks at random.
@export var seed := -1
## Off when a radio panel plays the chirp as each line opens instead.
var chirp_on_spoke := true

## Character id -> lines said this job.
var used := {}
var _rng := RandomNumberGenerator.new()
var _since_gate := INF
## True while say() announces, so _on_spoke leaves `said` to it.
var _saying := false
## Gates passed since the last crash, reset, or strike.
var streak := 0

static var _cache := {}
## "id/moment" -> when it was last said, s since start: cooldowns hold across scenes.
static var moment_times := {}
## The job that just failed, until the next job briefs: relaunching it is a retry.
static var last_failed: StringName = &""

func _ready() -> void:
	spoke.connect(_on_spoke)
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	if runner:
		runner.state_changed.connect(_on_state)
		runner.finished.connect(_on_finished)
		runner.crew_struck.connect(_on_struck)
		if runner.state == JobRunner.State.BRIEFING:
			_on_state(runner.state, JobRunner.State.IDLE)
	if course:
		course.gate_passed.connect(_on_gate)
	if watcher:
		watcher.flight_event.connect(_on_flight_event)

func _process(delta: float) -> void:
	_since_gate += delta

## The speaker's chirp under a bark, pitched from their Character, its variant
## from the line's face and event (chirp_for). The dead never speak, so they
## never chirp.
static func chirp(id: StringName, face: StringName = &"neutral", event: StringName = &"") -> void:
	var c: Character = Roster.character(id)
	if c and Roster.is_alive(id):
		Sfx.play(chirp_for(face, event), null, 0.0, c.chirp_pitch)

## The babble under a line from `id` on `event` (Story 18.8): {event, pitch},
## the sound event and the pitch scale to loop it at, or {} for silence: the
## dead, memorials, and anyone without a babble in the bank.
static func babble_for(id: StringName, event: StringName) -> Dictionary:
	var c: Character = Roster.character(id)
	if c == null or not Roster.is_alive(id) or event in SILENT_BABBLE:
		return {}
	if Sfx.bank == null or Sfx.bank.find(c.babble_event()) == null:
		return {}
	return {"event": c.babble_event(), "pitch": SERIOUS_BABBLE_PITCH if event in SERIOUS_BABBLE else 1.0}

## The chirp sound event for a line with this face on this event.
static func chirp_for(face: StringName, event: StringName = &"") -> StringName:
	if event in PLAIN_EVENTS:
		return &"crew_chirp"
	if event in CELEBRATE_EVENTS and face in [&"happy", &"determined"]:
		return CELEBRATE_CHIRP
	return CHIRPS.get(face, &"crew_chirp")

func _on_spoke(id: StringName, event: StringName, text: String) -> void:
	var face := face_of(id, event, text)
	if chirp_on_spoke:
		chirp(id, face, event)
	if not _saying:
		said.emit({"id": id, "event": event, "text": text, "face": face})

## Every line file, parsed once. Event -> {"active": [...], "injured": [...]}.
static func lines_of(id: StringName) -> Dictionary:
	if not _cache.has(id):
		var c: Character = Roster.character(id)
		var res: JSON = load(c.lines) if c and ResourceLoader.exists(c.lines) else null
		_cache[id] = res.data if res and res.data is Dictionary else {}
	return _cache[id]

## A line entry's text, whether it is a string or {"text", "face"}.
static func text_of(line: Variant) -> String:
	return str(line.get("text", "")) if line is Dictionary else str(line)

## A line as said: {you} becomes one of the speaker's names for you, picked by
## the line itself so the same line always reads the same.
static func fill(c: Character, text: String) -> String:
	if not text.contains("{you}"):
		return text
	var names: PackedStringArray = c.calls_you if c and not c.calls_you.is_empty() else PackedStringArray(["pilot"])
	return text.replace("{you}", names[absi(hash(text)) % names.size()])

## The face for a line: its entry's `face` when that is a known expression,
## otherwise the event's default.
static func face_of(id: StringName, event: StringName, text: String) -> StringName:
	var e: Variant = lines_of(id).get(String(event), {})
	if e is Dictionary:
		for line in e.get("active", []) + e.get("injured", []):
			if line is Dictionary and fill(Roster.character(id), text_of(line)) == text:
				var face := StringName(str(line.get("face", "")))
				if face in CharacterPortrait.EXPRESSIONS:
					return face
	return DEFAULT_FACES.get(event, &"neutral")

## The lines this character can say on an event right now, as text. None when
## dead; the injured variant when injured and one exists.
## `as_status` reads the lines as if the character had that status (alive only).
static func pool(id: StringName, event: StringName, as_status := -1) -> Array:
	if Roster.character(id) == null or not Roster.is_alive(id):
		return []
	var e: Dictionary = lines_of(id).get(String(event), {})
	var status: int = Roster.status(id) if as_status < 0 else as_status
	var lines: Array = e.injured if status == Roster.Status.INJURED and e.has("injured") else e.get("active", [])
	var c: Character = Roster.character(id)
	return lines.map(func(l): return fill(c, text_of(l)))

## Lines not yet said this job; the whole pool when it holds a single line.
func available(id: StringName, event: StringName, as_status := -1) -> Array:
	var p := pool(id, event, as_status)
	if p.size() == 1:
		return p
	var said: Array = used.get(id, [])
	return p.filter(func(l): return not l in said)

## Who may speak: the subject alone, or the crew in the field plus anyone who
## speaks on this event from afar. A moment is anyone's but the player's pilot.
func speakers(event: StringName, subject: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	if subject != &"":
		out.append(subject)
		return out
	if event in MOMENTS:
		var me := PlayerProfile.pilot()
		for id in Roster.ids():
			if not (me and me.id == id):
				out.append(id)
		return out
	if runner and runner.job:
		for id in runner.crew_in_field():
			if not id in out:
				out.append(id)
	for id in Roster.ids():
		var c: Character = Roster.character(id)
		if c and event in c.speaks_on and not id in out:
			out.append(id)
	return out

## Picks a speaker and an unsaid line. Returns {id, event, text, face}, or {} when
## nobody can. Announces it on `spoke` (the HUD) unless `announce` is false.
func say(event: StringName, subject: StringName = &"", announce := true, as_status := -1) -> Dictionary:
	var who: Array[StringName] = []
	for id in speakers(event, subject):
		if not available(id, event, as_status).is_empty() and cooled(id, event):
			who.append(id)
	if who.is_empty():
		return {}
	var id := who[_rng.randi() % who.size()]
	if event in MOMENTS:
		moment_times["%s/%s" % [id, event]] = now()
	var lines := available(id, event, as_status)
	var text: String = lines[_rng.randi() % lines.size()]
	if not used.has(id):
		used[id] = []
	used[id].append(text)
	var line := {"id": id, "event": event, "text": text, "face": face_of(id, event, text)}
	if announce:
		announce_line(line)
	return line

## False while `id` said `event`, a moment, less than MOMENT_COOLDOWN ago.
static func cooled(id: StringName, event: StringName) -> bool:
	var at: Variant = moment_times.get("%s/%s" % [id, event])
	return not event in MOMENTS or at == null or now() - float(at) >= MOMENT_COOLDOWN

## Seconds since the game started, the clock moment cooldowns run on.
static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Says a moment, unless this is a boss job (the Lattice gets no cheer).
func moment(event: StringName) -> Dictionary:
	if runner and runner.job and runner.job.job_type == &"boss":
		return {}
	return say(event)

## Puts a line on `spoke` and `said` as given, face and all, e.g. a free-flight
## suggestion whose text and face are data (Story 17.10).
func announce_line(line: Dictionary) -> void:
	_saying = true
	spoke.emit(line.id, line.event, line.text)
	_saying = false
	said.emit(line)

func _on_state(s: JobRunner.State, _previous: JobRunner.State) -> void:
	match s:
		JobRunner.State.BRIEFING:
			used.clear()
			streak = 0
			for z in runner.hazard_zones():
				if not z.warning_started.is_connected(_on_warning):
					z.warning_started.connect(_on_warning)
			var again: bool = runner.job != null and runner.job.id == last_failed
			last_failed = &""
			say(&"briefing")
			if again:
				moment(&"retry")
		JobRunner.State.COMPLETE:
			last_failed = &""
			say(&"complete")
		JobRunner.State.FAILED:
			# After someone is hurt, nobody cheers the next go (Story 18.5).
			last_failed = runner.job.id if runner.job and runner.casualties.is_empty() else &""
			say(&"fail")

func _on_finished(result: JobResult) -> void:
	# Shown on the results screen, not the HUD, so the fail or complete line stays up.
	result.bark = say(&"results", &"", false)
	# The injured say how they are; the dead get their memorial line.
	for id in result.casualties:
		if result.casualties[id] == Roster.Status.DEAD:
			result.casualty_lines[id] = memorial(id)
		else:
			result.casualty_lines[id] = say(&"hurt", id, false).get("text", "")

## A job card's pitch from `id`, {text, face}, or {} when they have none.
## Picked by `key` (the job id), so a card shows the same line every time.
static func pitch(id: StringName, key: StringName) -> Dictionary:
	var lines := pool(id, &"pitch")
	if lines.is_empty():
		return {}
	var text: String = lines[absi(hash(String(key))) % lines.size()]
	return {"text": text, "face": face_of(id, &"pitch", text)}

## A dead character's memorial line, from their line file.
static func memorial(id: StringName) -> String:
	return str(lines_of(id).get("memorial", ""))

func _on_warning(id: StringName) -> void:
	say(&"warning", id)

func _on_struck(id: StringName, before: Roster.Status) -> void:
	streak = 0
	say(&"strike", id, true, before)

func _on_flight_event(event: StringName) -> void:
	if event in [&"crash", &"reset"]:
		streak = 0
	say(event)

func _on_gate(who: Node3D, _gate: int) -> void:
	if runner and who != runner.drone:
		return
	# The streak's gate cheers instead of the callout, once per streak; never
	# once the crew is hurt (as with retry).
	streak += 1
	var hurt: bool = runner != null and not runner.casualties.is_empty()
	if streak == streak_gates and not hurt and not moment(&"streak").is_empty():
		_since_gate = 0.0
		return
	# Gates are the spotter's call; without one, nobody makes it (Story 7.6).
	if Consequences.in_effect(&"no_spotter"):
		return
	if _since_gate < gate_gap:
		return
	if not say(&"gate_passed").is_empty():
		_since_gate = 0.0
