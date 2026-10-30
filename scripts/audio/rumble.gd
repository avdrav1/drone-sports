extends Node
# Autoload Rumble (Story 23.7): the pad shakes for the moments that matter. A
# crash or hard hit (harder hits shake more and longer), a gate passed (a short
# tick), a hazard warning and a strike, and a job's end. Rumble.play(id) asks
# Input.start_joy_vibration on the pad last touched (InputPrompt), and logs the
# request the way Music.log does so headless tests can read it. Nothing is asked
# with rumble off (OPTIONS, 23.6) or while the keys were last touched. A pad or
# browser that cannot vibrate ignores the request, so nothing about play ever
# depends on it. FlightCues and JobCues call it from the drone's contacts, the
# gates, the hazard zones and the runner's states, so no job holds rumble code.
# Story 28.2: pausing the tree stops a rumble still going at once (logged as a
# `stop`), nothing is asked while paused, and unpausing restarts nothing.

## Event -> [weak motor, strong motor, seconds]. A hit's row is its hardest.
const EVENTS := {
	&"hit": [0.8, 1.0, 0.4],
	&"gate": [0.3, 0.0, 0.06],
	&"warning": [0.4, 0.2, 0.3],
	&"strike": [0.8, 1.0, 0.6],
	&"complete": [0.5, 0.2, 0.35],
	&"failed": [0.3, 0.8, 0.5],
}
## A hit's change in speed (m/s) that shakes at all, and at full strength.
const SOFT_HIT := 1.5
const HARD_HIT := 8.0
## The softest hit that counts shakes at this fraction of the hardest.
const SOFT_SCALE := 0.25
## Log entries kept.
const LOG_SIZE := 64

## The log id of a rumble cut short by the pause.
const STOP := &"stop"

## Recent requests, oldest first: {id, device, weak, strong, duration, msec}.
var log: Array[Dictionary] = []
## Pad device -> msec its last rumble runs until.
var _until := {}

## A pausable child, told when the tree pauses (Rumble itself always runs).
class PauseWatch extends Node:
	signal paused
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PAUSED:
			paused.emit()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var watch := PauseWatch.new()
	watch.name = "PauseWatch"
	watch.process_mode = Node.PROCESS_MODE_PAUSABLE
	watch.paused.connect(stop)
	add_child(watch)

## True when a request would reach a pad: rumble on and the pad in hand.
func active() -> bool:
	return GameSettings.rumble and InputPrompt.pad and InputPrompt.device >= 0

## Shakes for event `id`, its strength and length times `scale` (0 to 1).
## Returns false when nothing was asked of the pad.
func play(id: StringName, scale := 1.0) -> bool:
	if not EVENTS.has(id):
		push_warning("Rumble: no event '%s'" % id)
		return false
	if not active() or scale <= 0.0 or (is_inside_tree() and get_tree().paused):
		return false
	var e: Array = EVENTS[id]
	var k := clampf(scale, 0.0, 1.0)
	var entry := {"id": id, "device": InputPrompt.device, "weak": e[0] * k, "strong": e[1] * k,
		"duration": e[2] * k, "msec": Time.get_ticks_msec()}
	Input.start_joy_vibration(entry.device, entry.weak, entry.strong, entry.duration)
	_until[entry.device] = entry.msec + int(entry.duration * 1000.0)
	_log(entry)
	return true

## Stops every rumble still going, each logged as a `stop`. Returns how many.
func stop() -> int:
	var now := Time.get_ticks_msec()
	var stopped := 0
	for device in _until.keys():
		if _until[device] >= now:
			Input.stop_joy_vibration(device)
			_log({"id": STOP, "device": device, "weak": 0.0, "strong": 0.0, "duration": 0.0, "msec": now})
			stopped += 1
	_until.clear()
	return stopped

func _log(entry: Dictionary) -> void:
	log.append(entry)
	if log.size() > LOG_SIZE:
		log.pop_front()

## One hit that changed the drone's speed by `speed` m/s; a soft touch is nothing.
func hit(speed: float) -> bool:
	if speed < SOFT_HIT:
		return false
	return play(&"hit", lerpf(SOFT_SCALE, 1.0, clampf(inverse_lerp(SOFT_HIT, HARD_HIT, speed), 0.0, 1.0)))

## How many times `id` was asked for since the log was last cleared.
func count(id: StringName) -> int:
	return log.filter(func(l): return l.id == id).size()

func last() -> Dictionary:
	return log.back() if not log.is_empty() else {}

func clear_log() -> void:
	log.clear()
