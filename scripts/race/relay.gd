class_name Relay
extends Node
# A team relay over a Course (Story 6.4). Each leg is one lap, flown by the next
# drone in `drones`; the start/finish gate is the handoff. A leg's drone starts
# by passing that gate after the last leg finished through it, and the gap
# between the two is the handoff time. A lap by the wrong drone, or one started
# before the handoff, is invalid and the leg stays open. G sends the command
# view's selected drone round the course on autopilot; a pilot can also drop in
# and fly a leg by hand.
# Story 22.2: on an open course a leg is the run of gates from one handoff gate
# to the next (`leg_ends`), each drone waits beside its leg's first gate, and
# the last leg ends the relay at the course's last gate. A leg's drone starts it
# by passing that gate; the same rules make a leg invalid. G sends a drone along
# its own leg.

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
## On an open course, the gate each leg ends at, in order, the last being the
## finish. Unless it has one per drone, the path is split evenly.
@export var leg_ends: Array[int] = []
## On an open course, where a drone waits for its leg: m right of and behind
## its first gate.
@export var wait := Vector2(6.0, 6.0)

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
## Open course: drone -> the Run it is flying.
var _runs := {}

## A drone's way along one leg of an open course.
class Run:
	var leg := 0
	## Gate it must pass next.
	var next := 0
	var valid := true
	var start := 0.0

func _ready() -> void:
	if course.is_closed():
		# The course counts laps forever; the relay decides when it is over.
		course.data = course.data.duplicate()
		course.data.laps = 1000
	else:
		for k in drones.size():
			var g := course.gates[leg_start(k)].global_transform
			drones[k].global_transform = Transform3D(g.basis, g * Vector3(wait.x, 0.0, wait.y))
		for g in course.gates:
			g.passed.connect(_on_pass.bind(g.index))
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

## The gate each leg of an open course ends at.
func ends() -> Array[int]:
	var n := drones.size()
	if leg_ends.size() == n:
		return leg_ends
	var out: Array[int] = []
	for i in n:
		out.append(roundi(float(i + 1) * (course.gates.size() - 1) / n))
	return out

## The handoff gate leg `k` of an open course starts at.
func leg_start(k: int) -> int:
	return 0 if k == 0 else ends()[k - 1]

## Sends `d` on its autopilot: round one lap, lined up through each gate, back
## through the start, then aside; on an open course, along leg `k` (its own by
## default).
func send(d: Drone, k := -1) -> void:
	var auto := Autopilot.of(d)
	if auto:
		auto.go_to(lap_route(d) if course.is_closed() else leg_route(drones.find(d) if k < 0 else k))

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

## Leg `k` of an open course: in line behind its first gate, through each gate
## to its last, then aside past it.
func leg_route(k: int) -> PackedVector3Array:
	var first := course.gates[leg_start(k)].global_transform
	var out := PackedVector3Array([first * Vector3(0.0, 0.0, 4.5)])
	for i in range(leg_start(k), ends()[k] + 1):
		var g := course.gates[i].global_transform
		out.append(g.origin + g.basis.z * 2.5)
		out.append(g.origin - g.basis.z * 2.5)
	out.append(course.gates[ends()[k]].global_transform * Vector3(aside, 2.0, -8.0))
	return out

func _on_gate(racer: Node3D, gate: int) -> void:
	var face := DroneFace.of(racer)
	if face:
		face.react(&"gate")
	if gate != 0 or done or not racer in drones or not course.is_closed():
		return
	if not course.progress(racer).splits.is_empty():
		return # a lap end; _on_lap has it
	_started[racer] = course.time
	if racer == current() and leg > 0 and _handoff_at >= 0.0:
		var gap := course.time - _handoff_at
		handoffs.append(gap)
		handoff.emit(leg, gap)

func _on_lap(lap_time: float, racer: Node3D, _lap: int, valid: bool) -> void:
	if done or not racer in drones or not course.is_closed():
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

## Open course: a forward pass of any gate by a fleet drone. It moves the
## drone's run on, ends it at its leg's last gate, or starts one at a handoff gate.
func _on_pass(racer: Node3D, forward: bool, gate: int) -> void:
	if not forward or done or not racer in drones:
		return
	var face := DroneFace.of(racer)
	if face and not course.progress(racer).started:
		face.react(&"gate") # a started racer reacts in _on_gate
	var run: Run = _runs.get(racer)
	if run and gate > leg_start(run.leg) and gate <= ends()[run.leg]:
		if gate < run.next:
			return
		if gate > run.next:
			run.valid = false
		run.next = gate + 1
		if gate == ends()[run.leg]:
			_runs.erase(racer)
			_leg_flown(racer, run)
		return
	var k := 0 if gate == 0 else ends().find(gate) + 1
	if (gate > 0 and k == 0) or k >= drones.size():
		return
	run = Run.new()
	run.leg = k
	run.next = gate + 1
	run.start = course.time
	_runs[racer] = run
	if k == leg and racer == current() and leg > 0 and _handoff_at >= 0.0 and handoffs.size() < leg:
		var gap := course.time - _handoff_at
		handoffs.append(gap)
		handoff.emit(leg, gap)

## Open course: `racer` reached the end of `run`'s leg.
func _leg_flown(racer: Node3D, run: Run) -> void:
	if run.leg < leg:
		return # a leg already flown
	var reason := ""
	if racer != drones[run.leg]:
		reason = "wrong drone"
	elif run.leg > leg or run.start < _handoff_at:
		reason = "left before the handoff"
	elif not run.valid:
		reason = "missed a gate"
	if reason != "":
		invalid += 1
		last_invalid = "%s: leg invalid, %s" % [racer.name, reason]
		lap_invalid.emit(racer, reason)
		return
	leg_times.append(course.time - run.start)
	_handoff_at = course.time
	leg += 1
	leg_done.emit(leg - 1, racer, leg_times[-1])
	if leg >= drones.size():
		done = true
		finished.emit(course.time)
