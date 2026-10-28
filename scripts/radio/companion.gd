class_name Companion
extends Node
# One crew member rides along on the radio in free flight (Story 17.10): the
# first living one in the suggestion list's companions. They greet you soon
# after spawn, react to the FlightWatcher's events in their own voice, and when
# the radio has been quiet a while they suggest something to try, lighting its
# target on the radar until you reach it (a short reaction) or another
# suggestion plays. Holds no character names; never grades or saves anything,
# and stays silent under a cutscene or the title, where the sandbox is a backdrop.

@export var bark: Bark
@export var watcher: FlightWatcher
## The drone and the map (its landmarks).
@export var gps: Gps
@export var list: SuggestionList = preload("res://data/radio/suggestions.tres")
## Seconds after spawn before the greeting.
@export var greet_after := 1.5
## Seconds of radio silence before a suggestion.
@export var quiet_gap := 45.0
## No suggestion before this many seconds after spawn.
@export var first_suggestion := 10.0
## Seeds which suggestion. Negative picks at random.
@export var seed := -1

## The crew member riding along; &"" when nobody can.
var id: StringName
## Seconds since spawn, and since the last radio line.
var age := 0.0
var quiet := 0.0
var greeted := false
## The suggestion in play and the marker lit for it, or null.
var suggestion: Suggestion
var target: MapMarker
var _last_suggestion := -1
## A marker made for a landmark target, freed once it is done with.
var _made: MapMarker
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	id = pick(list.companions if list else [])
	if bark:
		bark.said.connect(func(_l): quiet = 0.0)
	if watcher:
		watcher.flight_event.connect(_on_flight_event)

## The first living crew member in `ids`; &"" when none is.
static func pick(ids: Array) -> StringName:
	for c in ids:
		if Roster.character(c) and Roster.is_alive(c):
			return c
	return &""

## True when the sandbox is a backdrop (the title, a cutscene) or a job is on.
func silenced() -> bool:
	if id == &"" or bark == null:
		return true
	var n := get_parent()
	while n:
		if n is CutscenePlayer or n.get_children().any(func(k): return k is JobRunner):
			return true
		n = n.get_parent()
	return false

func _process(delta: float) -> void:
	if silenced():
		return
	age += delta
	quiet += delta
	if not greeted and age >= greet_after:
		greeted = true
		_say(&"free_greet")
	if target and _drone() and _drone().global_position.distance_to(target.global_position) <= suggestion.reach:
		_clear()
		_say(&"free_arrive")
	if greeted and age >= first_suggestion and quiet >= quiet_gap:
		suggest()

func _drone() -> Drone:
	return gps.drone if gps else null

## Plays a suggestion other than the last one and lights its target. False when
## none has a target here.
func suggest() -> bool:
	if list == null or list.suggestions.is_empty():
		return false
	var options := []
	for i in list.suggestions.size():
		if i != _last_suggestion or list.suggestions.size() == 1:
			options.append(i)
	_shuffle(options)
	_clear()
	for i in options:
		var s: Suggestion = list.suggestions[i]
		var m := _target_of(s)
		if m == null:
			continue
		suggestion = s
		target = m
		target.highlighted = true
		_last_suggestion = i
		bark.announce_line({"id": id, "event": &"suggest", "text": s.text, "face": s.face})
		return true
	return false

## Shuffles in place from the seeded generator.
func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

## The marker a suggestion points at: the nearest of its kind, or a marker made
## at its landmark. Null when this map has neither.
func _target_of(s: Suggestion) -> MapMarker:
	var d := _drone()
	if s.kind != &"":
		var best: MapMarker = null
		for m in MapMarker.collect(owner if owner else get_parent()):
			if m.kind == s.kind and (best == null or (d and d.global_position.distance_to(m.global_position) < d.global_position.distance_to(best.global_position))):
				best = m
		return best
	if gps == null or gps.map == null or not gps.map.landmarks.has(s.landmark):
		return null
	var m := MapMarker.new()
	m.name = "Suggested"
	m.kind = &"landmark"
	m.label = s.landmark
	m.icon = &"circle"
	add_child(m)
	m.global_position = gps.map.landmarks[s.landmark]
	_made = m
	return m

## Puts out the lit target.
func _clear() -> void:
	if is_instance_valid(target):
		target.highlighted = false
	if is_instance_valid(_made):
		_made.queue_free()
	target = null
	_made = null
	suggestion = null

func _on_flight_event(event: StringName) -> void:
	if not silenced():
		_say(event)

## Says a line on `event`. Bark's no-repeat rule holds within a job; free flight
## has no job to end, so once every line on an event has been said the pool
## starts over, keeping out only the line said last so it never plays twice in
## a row.
func _say(event: StringName) -> Dictionary:
	if bark.available(id, event).is_empty():
		var p := Bark.pool(id, event)
		var said: Array = bark.used.get(id, [])
		var last := ""
		for l in said:
			if l in p:
				last = l
		bark.used[id] = said.filter(func(l): return not l in p or l == last)
	return bark.say(event, id)
