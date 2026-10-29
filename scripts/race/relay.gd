class_name Relay
extends Node
# A team relay over a Course (Story 6.4). Each leg is one lap, flown by the next
# drone in `drones`; the start/finish gate is the handoff. A leg's drone starts
# by passing that gate after the last leg finished through it, and the gap
# between the two is the handoff time. A lap by the wrong drone, or one started
# before the handoff, is invalid and the leg stays open. G sends the command
# view's selected drone round the course on autopilot; a pilot can also drop in
# and fly a leg by hand.

signal leg_done(leg: int, drone: Drone, lap_time: float)
signal handoff(leg: int, seconds: float)
signal lap_invalid(drone: Drone, reason: String)
signal finished(time: float)

@export var runner: JobRunner
@export var course: Course
@export var command: CommandView
## The legs' drones, in running order.
@export var drones: Array[Drone] = []
## Where a finished drone pulls aside past the gate, m right of the line.
@export var aside := 8.0

## The leg being flown or waiting for its drone, from 0.
var leg := 0
var leg_times: Array[float] = []
## Handoff gaps, s: handoffs[0] is between legs 1 and 2.
var handoffs: Array[float] = []
var invalid := 0
var last_invalid := ""
var done := false

## Course time the last leg ended at the gate; -1 before the first.
var _handoff_at := -1.0
## Drone -> course time it last passed the gate to start a lap.
var _started := {}

func _ready() -> void:
	# The course counts laps forever; the relay decides when it is over.
	course.data = course.data.duplicate()
	course.data.laps = 1000
	for d in drones:
		course.add_racer(d)
	course.gate_passed.connect(_on_gate)
	course.lap_completed.connect(_on_lap)
	if runner:
		runner.state_changed.connect(func(s, _p):
			if s == JobRunner.State.LIVE:
				course.start())

## The drone that should fly the open leg, or null when the relay is done.
func current() -> Drone:
	return drones[leg] if leg < drones.size() else null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("send_lap") and command and command.selected and command.flown == null:
		send(command.selected)
		get_viewport().set_input_as_handled()

## Sends `d` round one lap on its autopilot: lined up through each gate, back
## through the start, then aside.
func send(d: Drone) -> void:
	var auto := Autopilot.of(d)
	if auto:
		auto.go_to(lap_route(d))

func lap_route(d: Drone) -> PackedVector3Array:
	var start := course.gates[0].global_transform
	# Straight out from where it waits to the start gate's line, then across.
	var local := start.affine_inverse() * d.global_position
	local.z = 4.5
	var out := PackedVector3Array([start * local])
	for i in course.gates.size() + 1:
		var g := course.gates[i % course.gates.size()].global_transform
		out.append(g.origin + g.basis.z * 2.5)
		out.append(g.origin - g.basis.z * 2.5)
	var slot := drones.find(d)
	out.append(start.origin - start.basis.z * 8.0 + start.basis.x * (aside + slot * 3.0) + Vector3.UP * 2.0)
	return out

func _on_gate(racer: Node3D, gate: int) -> void:
	var face := DroneFace.of(racer)
	if face:
		face.react(&"gate")
	if gate != 0 or done or not racer in drones:
		return
	if not course.progress(racer).splits.is_empty():
		return # a lap end; _on_lap has it
	_started[racer] = course.time
	if racer == current() and leg > 0 and _handoff_at >= 0.0:
		var gap := course.time - _handoff_at
		handoffs.append(gap)
		handoff.emit(leg, gap)

func _on_lap(lap_time: float, racer: Node3D, _lap: int, valid: bool) -> void:
	if done or not racer in drones:
		return
	var reason := ""
	if racer != current():
		reason = "wrong drone"
	elif not valid:
		reason = "missed a gate"
	elif _started.get(racer, -INF) < _handoff_at:
		reason = "left before the handoff"
	var at := course.time
	# Whatever happened, the gate it just passed starts its next lap.
	_started[racer] = at
	if reason != "":
		invalid += 1
		last_invalid = "%s: lap invalid, %s" % [racer.name, reason]
		lap_invalid.emit(racer, reason)
		return
	leg_times.append(lap_time)
	_handoff_at = at
	leg += 1
	leg_done.emit(leg - 1, racer, lap_time)
	if leg >= drones.size():
		done = true
		finished.emit(at)
