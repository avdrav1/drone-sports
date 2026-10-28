class_name DroneSound
extends Node3D
# What a drone sounds like (Story 14.2): a motor hum whose pitch and level follow
# its motors' delivered thrust (the reading DroneLook uses), prop wash while
# PropWash blows dust, and one knock per contact, louder the harder it hit.
# 3D players, so AI racers and the fleet are heard around you. Reads the parent
# Drone; never touches physics. A frozen drone is silent.

## Hum pitch at the lowest thrust and at full thrust.
@export var idle_pitch := 0.55
@export var full_pitch := 1.6
## Hum level at the lowest thrust and at full thrust, dB on top of the event's.
@export var idle_db := -18.0
@export var full_db := 0.0
## Below this total thrust fraction the motors are off: no hum.
@export var off_below := 0.01
## Wash level at its strongest, dB on top of the event's; it fades to silence.
@export var wash_db := 0.0
## How fast pitch and level follow thrust, 1/s.
@export var response := 12.0
## Change in speed (m/s) a contact needs to knock at full volume.
@export var loud_impact := 8.0
## A body touching again within this many seconds is the same contact.
@export var contact_gap := 0.15

const HUM := &"drone_hum"
const WASH := &"drone_wash"
const IMPACT := &"drone_impact"
const QUIET_DB := -60.0

var drone: Drone
var hum: AudioStreamPlayer3D
var wash: AudioStreamPlayer3D
## What the players were set to on the last update, for tests and debugging.
var humming := false
var hum_pitch := 1.0
var hum_db := QUIET_DB
var washing := false
var wash_level_db := QUIET_DB
## Impacts this drone has played, and the speed and gain of the last one.
var impacts := 0
var last_impact_speed := 0.0
var last_impact_db := 0.0

var _velocity := Vector3.ZERO
var _time := 0.0
var _touched := {}  # body instance id -> time of its last contact

func _ready() -> void:
	drone = get_parent() as Drone
	hum = _player(HUM)
	wash = _player(WASH)
	if drone:
		drone.contact_monitor = true
		drone.max_contacts_reported = maxi(drone.max_contacts_reported, 4)
		drone.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_time += delta
	if drone:
		_velocity = drone.linear_velocity
	update_sound(delta)

## Hum and wash follow the drone's thrust and the ground below it.
func update_sound(delta: float) -> void:
	if drone == null:
		return
	var f := 0.0
	for t in drone.motor_thrusts:
		f += clampf(t, 0.0, drone.max_thrust)
	f = f / (drone.max_thrust * Drone.MOTOR_COUNT) * drone.power()
	var k := 1.0 - exp(-response * delta)
	var on := not drone.freeze and f >= off_below
	if on:
		if not humming:
			hum_pitch = idle_pitch # spin up from idle, not from the last flight
		hum_pitch = lerpf(hum_pitch, lerpf(idle_pitch, full_pitch, f), k)
		hum_db = lerpf(hum_db, lerpf(idle_db, full_db, sqrt(f)), k)
	else:
		hum_db = QUIET_DB
	_set_playing(hum, on)
	humming = on
	hum.pitch_scale = hum_pitch
	hum.volume_db = _event_db(HUM) + hum_db
	var pw := drone.get_node_or_null("PropWash") as PropWash
	var strength := pw.strength if pw and on else 0.0
	washing = strength > 0.0
	wash_level_db = wash_db + linear_to_db(clampf(strength, 0.001, 1.0)) if washing else QUIET_DB
	_set_playing(wash, washing)
	wash.volume_db = _event_db(WASH) + wash_level_db

func _on_body_entered(body: Node) -> void:
	if drone.freeze:
		return
	var id := body.get_instance_id()
	var again := _time - float(_touched.get(id, -INF)) < contact_gap
	_touched[id] = _time
	if again:
		return
	impact((_velocity - drone.linear_velocity).length())

## Plays one knock for a contact that changed the drone's speed by `speed` m/s.
func impact(speed: float) -> void:
	last_impact_speed = speed
	last_impact_db = linear_to_db(clampf(speed / loud_impact, 0.05, 1.0))
	impacts += 1
	Sfx.play(IMPACT, global_position, last_impact_db)

func _player(id: StringName) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = String(id).capitalize().replace(" ", "")
	var e := Sfx.bank.find(id) if Sfx.bank else null
	if e and not e.streams.is_empty():
		p.stream = e.streams[0]
		p.bus = e.bus
	p.max_distance = 120.0
	add_child(p)
	return p

func _event_db(id: StringName) -> float:
	var e := Sfx.bank.find(id) if Sfx.bank else null
	return e.volume_db if e else 0.0

func _set_playing(p: AudioStreamPlayer3D, on: bool) -> void:
	if on and not p.playing and p.stream:
		p.play()
	elif not on and p.playing:
		p.stop()
