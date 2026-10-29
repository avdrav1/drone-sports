class_name FlightCues
extends Node
# Sounds for what the pilot needs to notice (Story 14.3): crash recovery, the
# battery turning low, the collision guard or the brake cutting in, and a camera
# view change. A child of CameraRig, so it follows whichever drone is being
# flown. Each plays once per event: an assist that flickers on and off counts as
# one event until it has stayed off for `rearm_time`. Reads state; never flies.
# Story 23.7: each knock the flown drone's DroneSound plays also shakes the pad
# (Rumble.hit), harder for a harder hit.

## Battery fraction where the HUD bar turns red.
@export var low_battery := 0.2
## Seconds an assist must stay out before cutting in again is a new event.
@export var rearm_time := 0.75

const RECOVERED := &"flight_recovered"
const LOW_BATTERY := &"flight_low_battery"
const GUARD := &"flight_guard"
const BRAKE := &"flight_brake"
const VIEW := &"camera_view"

var rig: CameraRig
var drone: Drone
var _view := -1
var _battery_low := false
var _active := {}  # cue id -> true while its assist is in an event
var _out_for := {}  # cue id -> seconds its assist has been out
var _impacts := 0  # the flown drone's DroneSound.impacts already felt

func _ready() -> void:
	rig = get_parent() as CameraRig
	if rig:
		# The rig takes its default view in its own _ready, after this one.
		_view = rig.default_view
		rig.view_changed.connect(_on_view_changed)

func _physics_process(delta: float) -> void:
	var target: Drone = null
	if rig and is_instance_valid(rig.target):
		target = rig.target as Drone
	if target != drone or not is_instance_valid(drone):
		_watch(target)
	if drone == null:
		return
	var low := drone.battery <= low_battery
	if low and not _battery_low:
		Sfx.play(LOW_BATTERY)
	_battery_low = low
	_assist(GUARD, _guard_braking(), delta)
	_assist(BRAKE, _brake_stopping(), delta)
	_feel_impacts()

## Follows a new drone. Whatever state it is already in is not an event.
func _watch(d: Drone) -> void:
	if is_instance_valid(drone) and drone.recovered.is_connected(_on_recovered):
		drone.recovered.disconnect(_on_recovered)
	drone = d
	_active.clear()
	_out_for.clear()
	if drone == null:
		return
	drone.recovered.connect(_on_recovered)
	_battery_low = drone.battery <= low_battery
	_active[GUARD] = _guard_braking()
	_active[BRAKE] = _brake_stopping()
	var sound := _sound()
	_impacts = sound.impacts if sound else 0

## The pad feels each new knock of the flown drone (Story 23.7).
func _feel_impacts() -> void:
	var sound := _sound()
	if sound == null or sound.impacts == _impacts:
		return
	_impacts = sound.impacts
	Rumble.hit(sound.last_impact_speed)

func _sound() -> DroneSound:
	return drone.get_node_or_null("Sound") as DroneSound

func _assist(id: StringName, on: bool, delta: float) -> void:
	if on:
		if not _active.get(id, false):
			Sfx.play(id)
		_active[id] = true
		_out_for[id] = 0.0
		return
	_out_for[id] = _out_for.get(id, 0.0) + delta
	if _out_for[id] >= rearm_time:
		_active[id] = false

func _guard_braking() -> bool:
	var g := _find(&"collision_guard") as CollisionGuard
	return g != null and g.braking

func _brake_stopping() -> bool:
	var b := _find(&"brake") as Brake
	return b != null and b.stopping

func _find(id: StringName) -> Assist:
	if drone.assists == null:
		return null
	for a in drone.assists.assists():
		if a.assist_id == id and a.enabled:
			return a
	return null

func _on_recovered() -> void:
	Sfx.play(RECOVERED)

func _on_view_changed(v: CameraRig.View) -> void:
	if v == _view:
		return
	_view = v
	Sfx.play(VIEW)
