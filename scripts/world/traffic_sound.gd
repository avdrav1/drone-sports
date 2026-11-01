class_name TrafficSound
extends Node3D
# Story 26.12: traffic you can hear. A fixed pool of voices, each an engine
# loop and a tyre loop on two AudioStreamPlayer3Ds, follows the cars nearest
# the drone, so the audio cost stays the same whatever `car_count` is. Every
# physics tick the `voices` nearest cars within `reach` are picked; a car still
# picked keeps its voice (no restart), a voice whose car dropped out is handed
# to a newly picked one, and the rest fall silent. The engine is pitched up
# and the tyres raised with the car's speed. Sits under Traffic; reads its
# cars, never moves them. No Doppler beyond Godot's own (off by default).

## Voices in the pool: the most cars heard at once.
@export var voices := 4
## Cars farther than this from the drone are not heard, in metres.
@export var reach := 60.0
## What the cars are heard from; the active camera when unset.
@export var target: Node3D
## Engine pitch standing and at `top_speed`.
@export var idle_pitch := 0.75
@export var full_pitch := 1.5
## Speed (m/s) the engine and tyres reach full pitch and level at.
@export var top_speed := 14.0
## Tyre level standing and at `top_speed`, dB on top of the event's.
@export var tyres_idle_db := -24.0
@export var tyres_full_db := 0.0

const ENGINE := &"car_engine"
const TYRES := &"car_tyres"

var traffic: Traffic
## Per voice: its engine and tyre players, and the car it follows (or null).
var engines: Array[AudioStreamPlayer3D] = []
var tyres: Array[AudioStreamPlayer3D] = []
var heard: Array = []

func _ready() -> void:
	traffic = get_parent() as Traffic
	for i in voices:
		engines.append(_player(ENGINE, "Engine%d" % i))
		tyres.append(_player(TYRES, "Tyres%d" % i))
		heard.append(null)

func _physics_process(_delta: float) -> void:
	update()

## Where the cars are heard from: the target, else the active camera; null
## when there is neither.
func listener() -> Variant:
	if is_instance_valid(target) and target.is_inside_tree():
		return target.global_position
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam else null

## Hands the voices to the nearest cars and sets each one's pitch and level.
func update() -> void:
	var at: Variant = listener()
	var cars: Array = traffic.cars if traffic else []
	var points := PackedVector3Array()
	for c in cars:
		points.append(c.body.global_position if c.body and c.body.is_inside_tree() else Vector3.INF)
	var picks := nearest(points, at, voices, reach) if at is Vector3 else PackedInt32Array()
	var wanted := {}
	for i in picks:
		wanted[cars[i]] = true
	for v in heard.size():
		if heard[v] != null and not wanted.has(heard[v]):
			heard[v] = null
	var held := {}
	for v in heard.size():
		if heard[v] != null:
			held[heard[v]] = true
	for i in picks:
		if held.has(cars[i]):
			continue
		var free := heard.find(null)
		if free < 0:
			break
		heard[free] = cars[i]
		held[cars[i]] = true
	for v in heard.size():
		_voice(v, heard[v])

## Indices of the (at most) `n` points nearest `at` within `reach`, nearest first.
static func nearest(points: PackedVector3Array, at: Vector3, n: int, reach: float) -> PackedInt32Array:
	var near: Array = []
	var r2 := reach * reach
	for i in points.size():
		var d := points[i].distance_squared_to(at)
		if d > r2:
			continue
		if near.size() == n and d >= near[n - 1][0]:
			continue
		var k := near.size()
		while k > 0 and near[k - 1][0] > d:
			k -= 1
		near.insert(k, [d, i])
		if near.size() > n:
			near.pop_back()
	var out := PackedInt32Array()
	for e in near:
		out.append(e[1])
	return out

## How many voices are following a car now.
func voiced() -> int:
	return heard.filter(func(c): return c != null).size()

## The voice following `car`, or -1.
func voice_of(car: Object) -> int:
	return heard.find(car)

func _voice(v: int, car: Variant) -> void:
	var e := engines[v]
	var t := tyres[v]
	if car == null:
		_set_playing(e, false)
		_set_playing(t, false)
		return
	var f := clampf(car.speed / top_speed, 0.0, 1.0)
	var at: Vector3 = car.body.global_position
	e.global_position = at
	t.global_position = at
	e.pitch_scale = lerpf(idle_pitch, full_pitch, f)
	e.volume_db = _event_db(ENGINE)
	t.volume_db = _event_db(TYRES) + lerpf(tyres_idle_db, tyres_full_db, sqrt(f))
	# Each voice starts its loops at its own point, so voices do not phase.
	_set_playing(e, true, v * 0.23)
	_set_playing(t, true, v * 0.41)

func _player(id: StringName, label: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = label
	var e := Sfx.bank.find(id) if Sfx.bank else null
	if e and not e.streams.is_empty():
		p.stream = e.streams[0]
		p.bus = e.bus
	p.max_distance = reach
	p.unit_size = 8.0
	add_child(p)
	return p

func _event_db(id: StringName) -> float:
	var e := Sfx.bank.find(id) if Sfx.bank else null
	return e.volume_db if e else 0.0

func _set_playing(p: AudioStreamPlayer3D, on: bool, from := 0.0) -> void:
	if on and not p.playing and p.stream:
		p.play(fmod(from, p.stream.get_length()) if p.stream.get_length() > 0.0 else 0.0)
	elif not on and p.playing:
		p.stop()
