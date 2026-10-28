class_name LatticeFight
extends Node
# The Lattice job's phases (docs/BOSS.md), one after another on a live job.
#
# 1. Reclaim: fleet drones fly to units covering the trench entrance and tag
#    them; a tagged unit drops out of the shell and joins the fleet. Defenders
#    disable fleet drones they touch, and each one lost is recaptured: the last
#    unit reclaimed goes back into the shell. When the gap units are all out,
#    the entrance opens. Losing the whole fleet fails the job.
#
# Holds no flight code: drones fly through their intent sources, and every
# order goes to an Autopilot.

signal phase_started(phase: Phase)
signal phase_complete(phase: Phase)
signal unit_reclaimed(unit: int, by: Drone)
signal fleet_drone_lost(drone: Drone)

enum Phase { BRIEFING, RECLAIM, TRENCH, OVERRIDE, POWER_DOWN, DONE }

const DRONE := preload("res://scenes/drone/drone.tscn")

@export var runner: JobRunner
@export var lattice: Lattice
@export var command: CommandView
## Shell defenders: Drone scenes with a Defender as intent source.
@export var defenders: Array[Drone] = []
## Seeds the defenders; the same seed fights the same way.
@export var seed := 1
## A fleet drone tags a unit by staying this close for tag_time.
@export var tag_range := 3.5
@export var tag_time := 0.5
## A defender this close disables a fleet drone.
@export var disable_range := 1.4

var phase := Phase.BRIEFING
## Units reclaimed so far, in order.
var reclaimed: Array[int] = []
## Fleet drone -> the unit it was sent to tag.
var assigned := {}
var lost := 0
var _near := {}

func _ready() -> void:
	for i in defenders.size():
		var def := _defender(defenders[i])
		def.reseed(seed + i)
		def.guard = lattice.to_global(Lattice.toward(0.0) * (lattice.r_out() + 6.0))
		def.normal = (def.guard - lattice.global_position).normalized()
		def.prey = command.drones
	runner.state_changed.connect(_on_runner_state)

static func _defender(d: Drone) -> Defender:
	for c in d.get_children():
		if c is Defender:
			return c
	return null

func boss() -> Boss:
	return lattice.boss

func _on_runner_state(state: JobRunner.State, _previous: JobRunner.State) -> void:
	match state:
		JobRunner.State.BRIEFING:
			for d in defenders:
				d.freeze = true
		JobRunner.State.LIVE:
			for d in defenders:
				d.freeze = false
			# The pilot's own drone waits until the trench is open.
			runner.drone.freeze = true
			_start(Phase.RECLAIM)

func _start(p: Phase) -> void:
	phase = p
	phase_started.emit(p)

# --- Phase 1: reclaim ------------------------------------------------------

## The units whose removal opens the entrance: side by side over the shaft.
func gap() -> Array[int]:
	return lattice.entrance_units.slice(0, boss().gap_units)

## World point just outside a unit, where a fleet drone tags it.
func approach(unit: int) -> Vector3:
	var p: Vector3 = lattice.units[unit].pos
	return lattice.to_global(p.normalized() * (lattice.r_out() + 1.5))

## The next gap unit nobody has reclaimed or been sent to; -1 when none.
func next_target() -> int:
	var taken := assigned.values()
	for u in gap():
		if not u in reclaimed and not u in taken:
			return u
	return -1

## Sends a fleet drone to tag a unit.
func tag(d: Drone, unit: int) -> void:
	if unit < 0 or d == null or not d in command.drones:
		return
	assigned[d] = unit
	_near[d] = 0.0
	Autopilot.of(d).go_to(PackedVector3Array([approach(unit)]))

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.RECLAIM and event.is_action_pressed("tag_unit") and command.selected and command.flown == null:
		tag(command.selected, next_target())
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if phase == Phase.RECLAIM and runner.state == JobRunner.State.LIVE:
		_reclaim_step(delta)

func _reclaim_step(delta: float) -> void:
	for d in assigned.keys():
		var unit: int = assigned[d]
		if d.global_position.distance_to(lattice.to_global(lattice.units[unit].pos)) <= tag_range:
			_near[d] = _near.get(d, 0.0) + delta
			if _near[d] >= tag_time:
				reclaim(unit, d)
		else:
			_near[d] = 0.0
	for def in defenders:
		for d in command.drones.duplicate():
			if d.global_position.distance_to(def.global_position) <= disable_range:
				disable(d)
	if command.drones.is_empty():
		runner.fail("fleet lost")
		return
	if gap().all(func(u): return u in reclaimed):
		_open_entrance()

## Takes a unit out of the shell; it flies on as part of the fleet.
func reclaim(unit: int, by: Drone = null) -> void:
	if unit in reclaimed:
		return
	reclaimed.append(unit)
	lattice.hide_unit(unit)
	if by:
		assigned.erase(by)
		Autopilot.of(by).go_to(PackedVector3Array([approach(unit) + (approach(unit) - lattice.global_position).normalized() * 6.0]))
	var freed: Drone = DRONE.instantiate()
	freed.name = "Freed%d" % reclaimed.size()
	var auto := Autopilot.new()
	auto.name = "Autopilot"
	freed.add_child(auto)
	freed.intent_source = auto
	command.get_parent().add_child(freed)
	# Above the tagger's way out, so the two don't meet.
	freed.global_position = approach(unit) + (approach(unit) - lattice.global_position).normalized() * 3.0 + Vector3.UP * 4.0
	command.add(freed)
	auto.go_to(PackedVector3Array([freed.global_position]))
	unit_reclaimed.emit(unit, by)

## A defender caught a fleet drone: it is gone, and the shell takes back the
## last unit reclaimed.
func disable(d: Drone) -> void:
	if not d in command.drones:
		return
	command.remove(d)
	assigned.erase(d)
	_near.erase(d)
	lost += 1
	fleet_drone_lost.emit(d)
	d.queue_free()
	if not reclaimed.is_empty():
		lattice.show_unit(reclaimed.pop_back())

func _open_entrance() -> void:
	lattice.entrance_open = true
	for u in lattice.entrance_units:
		lattice.hide_unit(u)
	phase_complete.emit(Phase.RECLAIM)
	_start(Phase.TRENCH)
