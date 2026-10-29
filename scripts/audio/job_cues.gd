class_name JobCues
extends Node
# Sounds for any job (Story 14.4): a sound on every runner state change, a beep
# on each whole second of the countdown (on the fifth, Story 16.9), a blip per
# gate the flown drone passes (the next note of the mantra),
# ticks through each hold and a chime when it is done, and the hazard warning
# and strike. JobRunner adds one to itself, so every job gets them; it reads the
# runner, its objectives, and the scene's Courses and HazardZones, and holds no
# job-specific code. The results screen plays the payout count itself.
# Story 23.7: the gate, the hazard warning and strike, and the job's end also
# shake the pad (Rumble).

## Sound per state the runner enters. The countdown's first beep is its own.
const STATE_CUES := {
	JobRunner.State.BRIEFING: &"job_briefing",
	JobRunner.State.COUNTDOWN: &"job_countdown",
	JobRunner.State.LIVE: &"job_go",
	JobRunner.State.COMPLETE: &"job_complete",
	JobRunner.State.FAILED: &"job_fail",
}
const COUNTDOWN := &"job_countdown"
const GATE := &"job_gate"
const HOLD_TICK := &"job_hold_tick"
const HOLD_DONE := &"job_hold_done"
const WARNING := &"hazard_warning"
const STRIKE := &"hazard_strike"
## A hold ticks each time it crosses another of this many parts.
const HOLD_STEPS := 4

var runner: JobRunner
## Gates the flown drone passed this run: gate n plays the gate event's
## pitches[n mod size], the mantra's notes in turn (Story 16.9).
var gates := 0
## Countdown number last beeped.
var _count := 0
## HoldStation -> quarters of it already ticked (HOLD_STEPS when done).
var _held := {}

func _ready() -> void:
	runner = get_parent() as JobRunner
	if runner:
		runner.state_changed.connect(_on_state)

func _on_state(s: JobRunner.State, _previous: JobRunner.State) -> void:
	if s == JobRunner.State.BRIEFING:
		gates = 0
		_listen()
	if s == JobRunner.State.COUNTDOWN:
		_count = ceili(runner.job.countdown)
	if STATE_CUES.has(s):
		Sfx.play(STATE_CUES[s])
	if s == JobRunner.State.COMPLETE:
		Rumble.play(&"complete")
	elif s == JobRunner.State.FAILED:
		Rumble.play(&"failed")

## Hooks the scene's hazard zones and courses, once each.
func _listen() -> void:
	_held.clear()
	for z in runner.hazard_zones():
		if not z.warning_started.is_connected(_on_warning):
			z.warning_started.connect(_on_warning)
			z.struck.connect(_on_struck)
	var scope: Node = runner.owner if runner.owner else runner.get_parent()
	if scope == null:
		return
	for c in scope.find_children("*", "Course", true, false):
		if not c.gate_passed.is_connected(_on_gate):
			c.gate_passed.connect(_on_gate)

func _physics_process(_delta: float) -> void:
	if runner == null:
		return
	if runner.state == JobRunner.State.COUNTDOWN:
		var n := ceili(runner.job.countdown - runner.state_time)
		if n < _count and n > 0:
			Sfx.play(COUNTDOWN)
		_count = mini(_count, n)
	elif runner.state == JobRunner.State.LIVE:
		for o in runner.objectives():
			if o is HoldStation:
				_hold(o)

func _hold(h: HoldStation) -> void:
	var steps := HOLD_STEPS if h.is_done() else floori(h.progress() * HOLD_STEPS)
	var before: int = _held.get(h, 0)
	_held[h] = steps
	if steps <= before:
		return  # held, or slipped out and reset
	Sfx.play(HOLD_DONE if steps == HOLD_STEPS else HOLD_TICK)

## Gates count for the drone being flown, not AI racers.
func _on_gate(who: Node3D, _gate: int) -> void:
	if who == runner.drone or (runner.camera_rig and who == runner.camera_rig.target):
		Sfx.play(GATE, null, 0.0, gate_pitch(gates))
		Rumble.play(&"gate")
		gates += 1

## The pitch scale of the nth gate passed (0-based): the nth note of the hook
## in the key, wrapping round, so a clean run plays the mantra.
static func gate_pitch(n: int) -> float:
	var e := Sfx.bank.find(GATE) if Sfx.bank else null
	if e == null or e.pitches.is_empty():
		return 1.0
	return e.pitches[posmod(n, e.pitches.size())]

func _on_warning(_character: StringName) -> void:
	Sfx.play(WARNING)
	Rumble.play(&"warning")

func _on_struck(_character: StringName, _cause: StringName) -> void:
	Sfx.play(STRIKE)
	Rumble.play(&"strike")
