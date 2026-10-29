class_name CrewDistress
extends Node
# Story 18.10: a crew member's portrait shows when their drone is in trouble.
# Driven by 17.8's flight events for that drone (the FlightWatcher its DroneFace
# owns, or one of its own): battery low, a near miss or a crash shows distress
# (CharacterPortrait.DISTRESS, a wince and a shake, with a sweat drop) for a
# while, and so does flying close to a HazardZone, for as long as it lasts; a
# repeating alarm plays meanwhile. A crash puts the drone down: the portrait
# shows static and SIGNAL LOST until the drone is back up in the air. A downed
# drone is not a death: the dead get none of this. Reads the drone, never
# writes to it (rules 1 and 2), and nothing is graded on it (rule 8).

## Flight event -> seconds of distress it causes.
const TROUBLE := {&"battery_low": 3.0, &"near_miss": 1.5, &"crash": 2.5}
## Flying within this many metres of a HazardZone's edge is trouble.
const HAZARD_MARGIN := 4.0
const ALARM := &"crew_alarm"
## Seconds between alarm beeps while the trouble lasts.
const ALARM_GAP := 0.9
## A downed drone's signal is back after this long upright in the air, s.
const UP_TIME := 0.5
## Upright enough to count as flying again, radians (about 45 degrees).
const UPRIGHT_TILT := 0.8
## The emote key (data/crew/emotes.tres) for the sweat drop.
const EMOTE := &"distress"
## The face once the trouble is over.
const REST := &"neutral"

var portrait: CharacterPortrait
var drone: Drone
var watcher: FlightWatcher
## The job's runner: its hazard zones, and its job type (the Lattice stays
## sincere, so no sweat drop on a boss job).
var runner: JobRunner
var zones: Array[HazardZone] = []
## Seconds this has run; trouble ends in it.
var time := 0.0
## Cause (a flight event, or `hazard`) -> the time it ends.
var trouble := {}
## The drone crashed and is not yet back in the air.
var down := false
## Alarm beeps played.
var alarms := 0
var _next_alarm := 0.0
var _up_for := 0.0
var _bubble: EmoteBubble

## Watches `d` for trouble and shows it on `face`, which it rides as a child.
static func watch(face: CharacterPortrait, d: Drone, job_runner: JobRunner = null) -> CrewDistress:
	var cd := CrewDistress.new()
	cd.name = "Distress"
	cd.portrait = face
	cd.drone = d
	cd.runner = job_runner
	if job_runner:
		cd.zones = job_runner.hazard_zones()
	face.add_child(cd)
	return cd

## The distress watching `face`, or null.
static func of(face: Node) -> CrewDistress:
	return face.get_node_or_null("Distress") as CrewDistress if is_instance_valid(face) else null

func _ready() -> void:
	var f := DroneFace.of(drone)
	watcher = f.watcher if f and f.watcher else null
	if watcher == null:
		watcher = FlightWatcher.new()
		watcher.name = "Watcher"
		watcher.drone = drone
		add_child(watcher)
	watcher.flight_event.connect(on_event)
	_bubble = EmoteBubble.attach(portrait)

func _exit_tree() -> void:
	if is_instance_valid(watcher) and watcher.flight_event.is_connected(on_event):
		watcher.flight_event.disconnect(on_event)

func _process(delta: float) -> void:
	advance(delta)

## True while the pilot is alive: the dead never get distress, static or alarms.
func alive() -> bool:
	return portrait != null and portrait.character != null and not portrait.is_dead()

## A flight event from the drone: trouble starts, or a downed drone is back.
func on_event(event: StringName) -> void:
	if not alive():
		return
	if TROUBLE.has(event):
		trouble[event] = maxf(float(trouble.get(event, -INF)), time + float(TROUBLE[event]))
	if event == &"crash":
		down = true
		_up_for = 0.0
	elif event == &"reset" or event == &"takeoff":
		down = false
	_show()

## True while the drone is in trouble: a recent event, a hazard close by, or down.
func troubled() -> bool:
	return alive() and (not trouble.is_empty() or down)

## True while the alarm sounds: trouble on a drone the player is not flying.
func alarm_on() -> bool:
	return troubled() and not player_flown()

## The player dropped into this drone: it is theirs, and never sounds the alarm.
func player_flown() -> bool:
	return is_instance_valid(drone) and drone.intent_source is PilotInput

## Within HAZARD_MARGIN of a hazard zone's edge.
func near_hazard() -> bool:
	if not is_instance_valid(drone) or not drone.is_inside_tree():
		return false
	for z in zones:
		if is_instance_valid(z) and z.is_inside_tree() and drone.global_position.distance_to(z.global_position) <= z.radius + HAZARD_MARGIN:
			return true
	return false

## Steps by `delta` seconds: trouble ends, a downed drone comes back, the alarm beeps.
func advance(delta: float) -> void:
	time += delta
	if not alive():
		trouble.clear()
		down = false
		_next_alarm = 0.0
		_show()
		return
	for k in trouble.keys():
		if time >= float(trouble[k]):
			trouble.erase(k)
	if near_hazard():
		trouble[&"hazard"] = time + delta
	if down and is_instance_valid(drone):
		var up: bool = watcher.height > watcher.rules.takeoff_height and FlightControl.tilt(drone) < UPRIGHT_TILT
		_up_for = _up_for + delta if up else 0.0
		if _up_for >= UP_TIME:
			down = false
	if alarm_on():
		if time >= _next_alarm:
			Sfx.play(ALARM)
			alarms += 1
			_next_alarm = time + ALARM_GAP
	else:
		_next_alarm = 0.0
	_show()

## Puts the state on the portrait: distress or rest, static while down, and a
## sweat drop for flight trouble (none near a hazard, none on the Lattice).
func _show() -> void:
	if portrait == null:
		return
	portrait.signal_lost = down and alive()
	if troubled():
		portrait.expression = CharacterPortrait.DISTRESS
	elif portrait.expression == CharacterPortrait.DISTRESS:
		portrait.expression = REST
	if _bubble == null:
		return
	var sweat := alive() and not down and not _quiet() and trouble.keys().any(func(k): return TROUBLE.has(k))
	var showing := _bubble.current != null and _bubble.current.key == EMOTE
	if sweat and not showing:
		_bubble.play(EMOTE)
	elif not sweat and showing:
		_bubble.clear()

func _quiet() -> bool:
	return runner != null and runner.job != null and runner.job.job_type in _bubble.table.quiet_job_types
