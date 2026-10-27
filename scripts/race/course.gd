class_name Course
extends Node3D
# Builds a CourseData's gates and tracks racers through them.
# Gate 0 is start/finish. The first forward pass of gate 0 starts a racer's run;
# a lap is gates 1..N-1 then gate 0 again. A gate passed ahead of the next one
# skips the ones between and invalidates the lap; invalid laps do not count.
# Backward passes never count. Times run from start().

## time is the lap time, s; valid is false if a gate was skipped.
signal lap_completed(time: float, racer: Node3D, lap: int, valid: bool)
signal racer_finished(racer: Node3D, place: int, total_time: float)
signal gate_passed(racer: Node3D, gate: int)

@export var data: CourseData

var gates: Array[Gate] = []
var running := false
var time := 0.0
var finish_order: Array[Node3D] = []

## Per racer: Progress.
var _progress := {}

class Progress:
	var started := false
	## Gate index the racer must pass next.
	var next := 0
	var laps := 0
	var lap_start := 0.0
	var valid := true
	var last_pos := Vector3.ZERO
	var lap_times: Array[float] = []
	## Time since lap start at each gate, this lap (by gate index).
	var splits := {}
	var best_splits := {}
	var best_lap := INF
	var finished := false
	var finish_time := 0.0

func _ready() -> void:
	if data:
		for i in data.gates.size():
			var g := Gate.new()
			g.name = "Gate%d" % i
			g.index = i
			g.size = data.gate_size
			g.transform = data.gates[i]
			add_child(g)
			gates.append(g)

func add_racer(racer: Node3D) -> void:
	var p := Progress.new()
	p.last_pos = racer.global_position
	_progress[racer] = p

func racers() -> Array:
	return _progress.keys()

func progress(racer: Node3D) -> Progress:
	return _progress.get(racer)

func start() -> void:
	running = true
	time = 0.0

func laps() -> int:
	return data.laps if data else 0

## Gates passed in lap order, for standings: valid laps, then gates, then nearness.
func race_distance(racer: Node3D) -> float:
	var p: Progress = _progress[racer]
	if not p.started:
		return -1.0
	var n := gates.size()
	var done := p.laps * n + _lap_order(p.next, n)
	var to_next := racer.global_position.distance_to(gates[p.next].global_position)
	return done - minf(to_next, 999.0) / 1000.0

## Racers sorted by place: finishers in order, then by race distance.
func standings() -> Array:
	var rest := racers().filter(func(r): return not _progress[r].finished)
	rest.sort_custom(func(a, b): return race_distance(a) > race_distance(b))
	return finish_order + rest

func place_of(racer: Node3D) -> int:
	return standings().find(racer) + 1

func _physics_process(delta: float) -> void:
	if not running:
		return
	time += delta
	for racer in _progress:
		_track(racer, _progress[racer])

func _track(racer: Node3D, p: Progress) -> void:
	var pos := racer.global_position
	var from := p.last_pos
	p.last_pos = pos
	if p.finished:
		return
	for g in gates:
		if g.crossing(from, pos) == 1:
			g.passed.emit(racer, true)
			_passed(racer, p, g.index)
		elif g.crossing(from, pos) == -1:
			g.passed.emit(racer, false)

func _passed(racer: Node3D, p: Progress, gate: int) -> void:
	var n := gates.size()
	if not p.started:
		if gate == 0:
			p.started = true
			p.lap_start = 0.0
			p.next = 1 % n
			p.splits = {}
			gate_passed.emit(racer, 0)
		return
	var ahead := _lap_order(gate, n) - _lap_order(p.next, n)
	if ahead < 0:
		return # a gate already passed this lap
	if ahead > 0:
		p.valid = false
	p.splits[gate] = time - p.lap_start
	gate_passed.emit(racer, gate)
	if gate == 0:
		_lap_done(racer, p)
	else:
		p.next = (gate + 1) % n

func _lap_done(racer: Node3D, p: Progress) -> void:
	var lap_time := time - p.lap_start
	var valid := p.valid
	if valid:
		p.laps += 1
		p.lap_times.append(lap_time)
		if lap_time < p.best_lap:
			p.best_lap = lap_time
			p.best_splits = p.splits.duplicate()
	lap_completed.emit(lap_time, racer, p.laps, valid)
	p.lap_start = time
	p.valid = true
	p.splits = {}
	p.next = 1 % gates.size()
	if p.laps >= laps():
		p.finished = true
		p.finish_time = time
		finish_order.append(racer)
		racer_finished.emit(racer, finish_order.size(), time)

## Position of a gate in lap order: gates 1..N-1 come first, gate 0 closes the lap.
static func _lap_order(gate: int, n: int) -> int:
	return posmod(gate - 1, n)
