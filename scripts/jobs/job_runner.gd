class_name JobRunner
extends Node
# Moves any job through Briefing, Countdown, Live, Complete, Failed.
# Holds no job-specific code: jobs are scenes that point a runner at a Job,
# a drone, and (optionally) a camera rig and a state label.

enum State { IDLE, BRIEFING, COUNTDOWN, LIVE, COMPLETE, FAILED }

signal state_changed(state: State, previous: State)
## After Complete or Failed, once graded and paid.
signal finished(result: JobResult)

@export var job: Job
@export var drone: Drone
@export var camera_rig: CameraRig
## Optional text readout of the state.
@export var state_label: Label
## Start Briefing as soon as the scene is ready.
@export var auto_begin := true
## Pay out and move reputation when the job ends.
@export var pays_out := true
@export var grade_scale: GradeScale = preload("res://data/jobs/grade_scale.tres")
## Shown over the job when it ends. Null shows nothing.
@export var results_scene: PackedScene = preload("res://scenes/ui/results.tscn")
## Seconds between the end of the job and the results screen.
@export var results_delay := 0.5

var state := State.IDLE
## Seconds spent in the current state.
var state_time := 0.0
## Seconds spent Live.
var live_time := 0.0
var fail_reason := ""
var result: JobResult
var results_screen: Control

func _ready() -> void:
	if auto_begin:
		begin.call_deferred()

## Child Objective nodes, in order.
func objectives() -> Array[Objective]:
	var out: Array[Objective] = []
	for c in get_children():
		if c is Objective:
			out.append(c)
	return out

## Enter Briefing: apply the job's assists and camera view; hold the drone still.
func begin() -> void:
	for o in objectives():
		o.bind(self)
		if job.weights.has(String(o.name)):
			o.weight = job.weights[String(o.name)]
	if job.required_assists and drone and drone.assists:
		drone.assists.apply_stack(GameSettings.effective_stack(job.required_assists))
	if camera_rig:
		camera_rig.default_view = job.default_view
		camera_rig.use_default_view()
	if drone:
		drone.freeze = true
	_set_state(State.BRIEFING)

## Leave Briefing. The player confirms with ui_accept; tests call it directly.
func launch() -> void:
	if state == State.BRIEFING:
		_set_state(State.COUNTDOWN)

func complete() -> void:
	if state == State.LIVE:
		_set_state(State.COMPLETE)
		_finish()

func fail(reason := "") -> void:
	if state in [State.BRIEFING, State.COUNTDOWN, State.LIVE]:
		fail_reason = reason
		_set_state(State.FAILED)
		_finish()

func is_over() -> bool:
	return state == State.COMPLETE or state == State.FAILED

func _unhandled_input(event: InputEvent) -> void:
	if state == State.BRIEFING and event.is_action_pressed("ui_accept"):
		launch()

func _physics_process(delta: float) -> void:
	state_time += delta
	match state:
		State.COUNTDOWN:
			if state_time >= job.countdown:
				if drone:
					drone.freeze = false
				_set_state(State.LIVE)
		State.LIVE:
			live_time += delta
			if _finish_line_reached():
				complete()
			elif job.time_limit > 0.0 and live_time >= job.time_limit:
				fail("time")
	_update_label()

## Grade, pay, and announce. A failed job grades F whatever its objectives say.
func _finish() -> void:
	if drone:
		drone.freeze = true
	result = JobResult.new()
	result.job = job
	result.completed = state == State.COMPLETE
	result.fail_reason = fail_reason
	var objs := objectives()
	for o in objs:
		result.objectives.append({"label": o.label if o.label else String(o.name), "score": clampf(o.score(), 0.0, 1.0), "weight": o.weight})
	result.score = Grader.total(objs)
	result.letter = grade_scale.letter(result.score) if result.completed else "F"
	if pays_out:
		Payout.settle(result, grade_scale)
	finished.emit(result)
	if results_scene and is_inside_tree():
		get_tree().create_timer(results_delay, true, true).timeout.connect(_show_results)

func _show_results() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	results_screen = results_scene.instantiate()
	layer.add_child(results_screen)
	var scene_root := owner if owner else get_tree().current_scene
	results_screen.job_scene = scene_root.scene_file_path if scene_root else ""
	results_screen.show_result(result)

func _finish_line_reached() -> bool:
	var any := false
	for o in objectives():
		if o.ends_job:
			any = true
			if not o.is_done():
				return false
	return any

func _set_state(s: State) -> void:
	var previous := state
	state = s
	state_time = 0.0
	_update_label()
	state_changed.emit(s, previous)

func _update_label() -> void:
	if state_label == null:
		return
	match state:
		State.BRIEFING:
			state_label.text = "BRIEFING  %s  for %s  pay %d\npress Enter to launch" % [job.title, job.client, job.pay]
		State.COUNTDOWN:
			state_label.text = "COUNTDOWN  %d" % ceili(job.countdown - state_time)
		State.LIVE:
			state_label.text = "LIVE  %.1f s" % live_time + ("  /  %.0f s" % job.time_limit if job.time_limit > 0.0 else "")
		State.COMPLETE:
			state_label.text = "COMPLETE"
		State.FAILED:
			state_label.text = "FAILED" + ("  (%s)" % fail_reason if fail_reason else "")
		_:
			state_label.text = ""
