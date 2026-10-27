class_name HazardScene
extends Node3D
# Scripted events for a hazard job: a collapse, a storm front, a crane swing.
# An AnimationPlayer holds the timeline; it starts once when the runner enters
# Countdown, runs on physics time, and never restarts mid-job (retry reloads the
# scene). Method tracks call fire_event(name) to announce named events; value
# tracks move things directly. Debris bodies released by an event fall freely.

signal event_fired(event: StringName, time: float)

@export var runner: JobRunner
@export var timeline: AnimationPlayer
@export var animation := &"events"

## Event name -> timeline time it fired, s.
var fired := {}
var started := false

func _ready() -> void:
	if timeline:
		timeline.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		timeline.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	if runner:
		runner.state_changed.connect(_on_state_changed)

func _on_state_changed(state: JobRunner.State, _previous: JobRunner.State) -> void:
	if state == JobRunner.State.COUNTDOWN:
		start()

## Plays the timeline from zero, once.
func start() -> void:
	if started or timeline == null:
		return
	started = true
	timeline.play(animation)

## Seconds into the timeline.
func time() -> float:
	return timeline.current_animation_position if timeline and timeline.is_playing() else 0.0

## Called by method tracks. Releases debris waiting on this event.
func fire_event(event: StringName) -> void:
	if fired.has(event):
		return
	fired[event] = time()
	for d in find_children("*", "Debris", true, false):
		if d.release_on == event:
			d.release()
	event_fired.emit(event, fired[event])
