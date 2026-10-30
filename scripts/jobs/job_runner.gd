class_name JobRunner
extends Node
# Moves any job through Briefing, Countdown, Live, Complete, Failed.
# Holds no job-specific code: jobs are scenes that point a runner at a Job,
# a drone, and (optionally) a camera rig and a state label.

enum State { IDLE, BRIEFING, COUNTDOWN, LIVE, COMPLETE, FAILED }

## The leave dialog's warning, under any reason it was opened for.
const LEAVE_TEXT := "Leaving now counts as a failed job: no pay."
## The fail reason when the player leaves a job in flight (Story 28.1).
const LEFT := "left"

signal state_changed(state: State, previous: State)
## After Complete or Failed, once graded and paid.
signal finished(result: JobResult)
## A strike landed and the roster moved: `before` is the status it moved from.
signal crew_struck(character: StringName, before: Roster.Status)
## Launch held for a confirmation because injured crew are in the field.
signal launch_confirm_needed(injured: Array[StringName])
## The player backed out of a risky launch.
signal launch_declined
## The player left the job (Esc) for `back_scene`.
signal job_left

@export var job: Job
@export var drone: Drone
@export var camera_rig: CameraRig
## Optional text readout of the state.
@export var state_label: Label
## Start Briefing as soon as the scene is ready.
@export var auto_begin := true
## Pay out, move reputation, and hurt struck crew for good. Off for previews.
@export var pays_out := true
## Ask before launching with injured crew in the field.
@export var confirm_risk := true
## Where backing out of a launch or leaving the job goes. Empty stays put.
@export_file("*.tscn") var back_scene := "res://scenes/ui/job_board.tscn"
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
## Character id -> strikes this job, from the scene's HazardZones.
var strikes := {}
## Character id -> status after a strike this job, e.g. injured or dead.
var casualties := {}
## Crashes while Live (Story 27.3), from the scene's FlightWatchers on this
## runner's drone: a crash, or a recovery after one.
var crashes := 0
## Next of the job's weather_changes to start.
var _weather_step := 0
var launch_dialog: LaunchDialog
## Asks before leaving a job in flight.
var leave_dialog: ConfirmationDialog
## The job's sounds; an internal child, so objectives() never sees it.
var cues: JobCues

func _ready() -> void:
	cues = JobCues.new()
	cues.name = "Cues"
	add_child(cues, false, Node.INTERNAL_MODE_BACK)
	MusicDirector.watch(self)
	# Its launch and leave dialogs and the results screen click (Story 14.5).
	UiSounds.wire(self)
	# The briefing names the launch key or button for the device in hand.
	if not InputPrompt.device_changed.is_connected(_on_device_changed):
		InputPrompt.device_changed.connect(_on_device_changed)
	# A pad that goes away mid-job pauses it (Story 23.5).
	if not Input.joy_connection_changed.is_connected(_on_joy_connection):
		Input.joy_connection_changed.connect(_on_joy_connection)
	if auto_begin:
		begin.call_deferred()

## The route guidance the radar, map, and ribbon show: the job's own, raised
## a step per guidance perk among the fit crew (Story 19.6), none to next leg to
## full. The job's data is untouched.
func guidance() -> Job.Guidance:
	if job == null:
		return Job.Guidance.FULL
	return maxi(Job.Guidance.FULL, job.guidance - roundi(Perks.amount(&"guidance"))) as Job.Guidance

## Child Objective nodes, in order.
func objectives() -> Array[Objective]:
	var out: Array[Objective] = []
	for c in get_children():
		if c is Objective:
			out.append(c)
	return out

## Enter Briefing: apply the job's assists, the pilot's upgrades, weather, and
## camera view; hold the drone still.
func begin() -> void:
	for o in objectives():
		o.bind(self)
		if job.weights.has(String(o.name)):
			o.weight = job.weights[String(o.name)]
	if job.required_assists and drone and drone.assists:
		drone.assists.apply_stack(GameSettings.effective_stack(assists_for(job)))
	Garage.apply(drone)
	_apply_weather()
	_weather_step = 0
	_remove_dead_crew()
	_arm_hazard_zones()
	_watch_crashes()
	if camera_rig:
		camera_rig.default_view = job.default_view
		camera_rig.use_default_view()
	if drone:
		drone.freeze = true
	_set_state(State.BRIEFING)

## The job's assists, with any the pilot's career has taken away also off.
static func assists_for(j: Job) -> AssistStack:
	return j.required_assists.intersect(Career.preset())

## Leave Briefing. The player confirms with ui_accept; tests call it directly.
## With injured crew in the field it asks first, unless `confirmed`.
func launch(confirmed := false) -> void:
	if state != State.BRIEFING:
		return
	var hurt := injured_in_field()
	if confirm_risk and not confirmed and not hurt.is_empty():
		_ask_launch(hurt)
		return
	_set_state(State.COUNTDOWN)

## Back out of a risky launch, to `back_scene`.
func decline_launch() -> void:
	if state != State.BRIEFING:
		return
	launch_declined.emit()
	if back_scene and is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(back_scene)

## The job's crew in the field who are still alive.
func crew_in_field() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in job.crew_in_field if job else []:
		if Roster.is_alive(id):
			out.append(id)
	return out

func injured_in_field() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in crew_in_field():
		if Roster.status(id) == Roster.Status.INJURED:
			out.append(id)
	return out

func _ask_launch(hurt: Array[StringName]) -> void:
	launch_confirm_needed.emit(hurt)
	if launch_dialog == null:
		launch_dialog = LaunchDialog.new()
		launch_dialog.confirmed.connect(launch.bind(true))
		launch_dialog.canceled.connect(decline_launch)
		add_child(launch_dialog)
	launch_dialog.ask(hurt, job.tags.has(&"lethal"))

## Esc. In the briefing it leaves at once; in flight it asks first, with the
## game paused, because leaving then fails the job. `why`, when set, heads the
## dialog's text, e.g. "Controller disconnected".
func request_leave(why := "") -> void:
	if state == State.BRIEFING:
		leave()
	elif state in [State.COUNTDOWN, State.LIVE]:
		if leave_dialog == null:
			leave_dialog = ConfirmationDialog.new()
			leave_dialog.title = "Leave job?"
			leave_dialog.ok_button_text = "Leave"
			leave_dialog.cancel_button_text = "Keep flying"
			leave_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
			leave_dialog.confirmed.connect(func(): _unpause(); leave())
			leave_dialog.canceled.connect(_unpause)
			add_child(leave_dialog)
		leave_dialog.dialog_text = (why + ".\n" if why else "") + LEAVE_TEXT
		get_tree().paused = true
		leave_dialog.popup_centered()
		leave_dialog.get_cancel_button().grab_focus()

## Go to `back_scene`. A job in flight fails first, without the results screen.
func leave() -> void:
	if state in [State.COUNTDOWN, State.LIVE]:
		results_scene = null
		fail(LEFT)
	elif state != State.BRIEFING:
		return
	job_left.emit()
	if back_scene and is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(back_scene)

func _unpause() -> void:
	if is_inside_tree():
		get_tree().paused = false

func complete() -> void:
	if state == State.LIVE:
		_set_state(State.COMPLETE)
		_finish()

func fail(reason := "") -> void:
	if state in [State.BRIEFING, State.COUNTDOWN, State.LIVE]:
		fail_reason = reason
		_set_state(State.FAILED)
		_finish()

## True when the job ended because the player left it, not by failing it.
func was_left() -> bool:
	return state == State.FAILED and fail_reason == LEFT

func is_over() -> bool:
	return state == State.COMPLETE or state == State.FAILED

func _unhandled_input(event: InputEvent) -> void:
	if (launch_dialog and launch_dialog.visible) or (leave_dialog and leave_dialog.visible):
		return
	if state == State.BRIEFING and event.is_action_pressed("ui_accept"):
		launch()
		# The pad's A is also drop_in: launching a fleet job must not drop in too.
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		request_leave()
	elif _is_pause(event):
		request_leave()

## Start (or P) pauses a job in flight under the leave dialog. In the briefing
## it does nothing, so a player pressing Start to begin is not sent home.
func _is_pause(event: InputEvent) -> bool:
	return state in [State.COUNTDOWN, State.LIVE] and event.is_action_pressed("pause")

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
			_run_weather_changes()
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
	result.strikes = strikes.duplicate()
	result.casualties = casualties.duplicate()
	var objs := objectives()
	for o in objs:
		result.objectives.append({"label": o.label if o.label else String(o.name), "score": clampf(o.score(), 0.0, 1.0), "weight": o.weight})
	result.score = Grader.total(objs)
	result.letter = grade_scale.letter(result.score) if result.completed else "F"
	result.time = live_time
	result.crashes = crashes
	if pays_out:
		Payout.settle(result, grade_scale)
		Roster.job_done(casualties.keys())
		var best := Career.best_grade(job.id)
		result.new_best = result.completed and best != "" and result.letter < best
		Career.job_flown(job.id, result.letter)
		if result.completed:
			Career.job_completed(job.id)
		# After the pay and the career are saved, so a best payout or a job
		# finished for the first time counts on this very job.
		result.unlocks = Hangar.earn(result)
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

## Every HazardZone in the scene reports to this runner. Zones only strike on a
## live job whose crew_in_field lists their character.
func hazard_zones() -> Array[HazardZone]:
	var out: Array[HazardZone] = []
	var scope: Node = owner if owner else get_parent()
	if scope == null:
		return out
	for z in scope.find_children("*", "HazardZone", true, false):
		out.append(z)
	return out

## Counts the crashes of the runner's drone (a watcher with no drone of its
## own follows it), from the scene's FlightWatchers.
func _watch_crashes() -> void:
	crashes = 0
	var scope: Node = owner if owner else get_parent()
	if scope == null:
		return
	for w: FlightWatcher in scope.find_children("*", "FlightWatcher", true, false):
		if w.runner == self and w.drone == null and not w.flight_event.is_connected(_on_flight_event):
			w.flight_event.connect(_on_flight_event)

func _on_flight_event(event: StringName) -> void:
	if state == State.LIVE and event in [&"crash", &"reset"]:
		crashes += 1

## A dead character's zone and figure never spawn: they are taken out of the scene.
func _remove_dead_crew() -> void:
	var scope: Node = owner if owner else get_parent()
	if scope == null:
		return
	for n in scope.find_children("*", "HazardZone", true, false) + scope.find_children("*", "CrewProp", true, false):
		if Roster.character(n.character) and not Roster.is_alive(n.character):
			n.get_parent().remove_child(n)
			n.queue_free()

func _arm_hazard_zones() -> void:
	strikes.clear()
	casualties.clear()
	for z in hazard_zones():
		z.runner = self
		if not z.struck.is_connected(_on_struck):
			z.struck.connect(_on_struck)

## Count the strike; on a real run it injures, or kills on a job tagged lethal.
func _on_struck(character: StringName, _cause: StringName) -> void:
	strikes[character] = strikes.get(character, 0) + 1
	var before := Roster.status(character)
	if pays_out:
		if job.tags.has(&"lethal"):
			Roster.kill(character)
		else:
			Roster.injure(character)
		if Roster.status(character) != before:
			casualties[character] = Roster.status(character)
	crew_struck.emit(character, before)

## The job's weather on the drone and the scene; none is clear and still.
func _apply_weather() -> void:
	Weather.apply(job.weather, drone, owner if owner else get_parent())

## Starts each of the job's weather changes once live time reaches it.
func _run_weather_changes() -> void:
	while _weather_step < job.weather_changes.size() and live_time >= job.weather_changes[_weather_step].at:
		var change := job.weather_changes[_weather_step]
		var scope: Node = owner if owner else get_parent()
		WeatherState.of(scope).blend_to(change.weather, change.blend_time, drone, scope)
		_weather_step += 1

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

## Story 23.5: the pad in hand going away in flight pauses the job under the
## leave dialog, so the drone never flies on with the last stick input. Any pad
## coming back gets a toast and nothing else: the player chooses to resume.
func _on_joy_connection(id: int, connected: bool) -> void:
	if not is_inside_tree():
		return
	if connected:
		Toast.show_line(self, "Controller connected")
	elif InputPrompt.pad and InputPrompt.device == id and state in [State.COUNTDOWN, State.LIVE]:
		request_leave("Controller disconnected")

func _on_device_changed(_pad: bool) -> void:
	_update_label()

func _update_label() -> void:
	if state_label == null:
		return
	match state:
		State.BRIEFING:
			state_label.text = "BRIEFING  %s  for %s  pay %d\npress %s to launch" % [job.title, job.client, job.pay,
				InputPrompt.text(&"ui_accept")]
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
