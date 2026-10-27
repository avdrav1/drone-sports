class_name Bark
extends Node
# Crew lines on job events: briefing, gate passed, strike warning, strike,
# complete, fail, and results. Lines are data (data/dialogue/<id>.json), picked by
# the speaker's status. The dead never speak, and a line never repeats within a
# job unless it is the only one. Holds no character or job names.

const EVENTS: Array[StringName] = [&"briefing", &"gate_passed", &"warning", &"strike", &"complete", &"fail", &"results"]

signal spoke(id: StringName, event: StringName, text: String)

@export var runner: JobRunner
## Optional: gate callouts on a race.
@export var course: Course
## Seconds between gate callouts, so a fast lap is not a wall of text.
@export var gate_gap := 2.5
## Seeds who speaks and which line. Negative picks at random.
@export var seed := -1

## Character id -> lines said this job.
var used := {}
var _rng := RandomNumberGenerator.new()
var _since_gate := INF

static var _cache := {}

func _ready() -> void:
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	if runner:
		runner.state_changed.connect(_on_state)
		runner.finished.connect(_on_finished)
		if runner.state == JobRunner.State.BRIEFING:
			_on_state(runner.state, JobRunner.State.IDLE)
	if course:
		course.gate_passed.connect(_on_gate)

func _process(delta: float) -> void:
	_since_gate += delta

## Every line file, parsed once. Event -> {"active": [...], "injured": [...]}.
static func lines_of(id: StringName) -> Dictionary:
	if not _cache.has(id):
		var c: Character = Roster.character(id)
		var res: JSON = load(c.lines) if c and ResourceLoader.exists(c.lines) else null
		_cache[id] = res.data if res and res.data is Dictionary else {}
	return _cache[id]

## The lines this character can say on an event right now. None when dead; the
## injured variant when injured and one exists.
static func pool(id: StringName, event: StringName) -> Array:
	if Roster.character(id) == null or not Roster.is_alive(id):
		return []
	var e: Dictionary = lines_of(id).get(String(event), {})
	if Roster.status(id) == Roster.Status.INJURED and e.has("injured"):
		return e.injured
	return e.get("active", [])

## Lines not yet said this job; the whole pool when it holds a single line.
func available(id: StringName, event: StringName) -> Array:
	var p := pool(id, event)
	if p.size() == 1:
		return p
	var said: Array = used.get(id, [])
	return p.filter(func(l): return not l in said)

## Who may speak: the subject alone, or the crew in the field plus anyone who
## speaks on this event from afar.
func speakers(event: StringName, subject: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	if subject != &"":
		out.append(subject)
		return out
	if runner and runner.job:
		for id in runner.job.crew_in_field:
			if not id in out:
				out.append(id)
	for id in Roster.ids():
		var c: Character = Roster.character(id)
		if c and event in c.speaks_on and not id in out:
			out.append(id)
	return out

## Picks a speaker and an unsaid line. Returns {id, event, text}, or {} when nobody
## can. Announces it on `spoke` (the HUD) unless `announce` is false.
func say(event: StringName, subject: StringName = &"", announce := true) -> Dictionary:
	var who: Array[StringName] = []
	for id in speakers(event, subject):
		if not available(id, event).is_empty():
			who.append(id)
	if who.is_empty():
		return {}
	var id := who[_rng.randi() % who.size()]
	var lines := available(id, event)
	var text: String = lines[_rng.randi() % lines.size()]
	if not used.has(id):
		used[id] = []
	used[id].append(text)
	if announce:
		spoke.emit(id, event, text)
	return {"id": id, "event": event, "text": text}

func _on_state(s: JobRunner.State, _previous: JobRunner.State) -> void:
	match s:
		JobRunner.State.BRIEFING:
			used.clear()
			for z in runner.hazard_zones():
				if not z.warning_started.is_connected(_on_warning):
					z.warning_started.connect(_on_warning)
					z.struck.connect(_on_struck)
			say(&"briefing")
		JobRunner.State.COMPLETE:
			say(&"complete")
		JobRunner.State.FAILED:
			say(&"fail")

func _on_finished(result: JobResult) -> void:
	# Shown on the results screen, not the HUD, so the fail or complete line stays up.
	result.bark = say(&"results", &"", false)

func _on_warning(id: StringName) -> void:
	say(&"warning", id)

func _on_struck(id: StringName, _cause: StringName) -> void:
	say(&"strike", id)

func _on_gate(who: Node3D, _gate: int) -> void:
	if runner and who != runner.drone:
		return
	if _since_gate < gate_gap:
		return
	if not say(&"gate_passed").is_empty():
		_since_gate = 0.0
