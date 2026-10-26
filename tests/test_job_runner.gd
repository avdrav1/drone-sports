extends RefCounted
# Story 2.1: job resource and lifecycle.

const Sim = preload("res://tests/sim.gd")
const S := JobRunner.State

class Recorder extends RefCounted:
	var states: Array = []
	func on_change(s, _prev) -> void:
		states.append(s)

func _setup(job: Job) -> Node:
	return Sim.job_setup(job)

func _job(time_limit := 0.0, countdown := 0.5) -> Job:
	var j: Job = load("res://data/jobs/test_job.tres").duplicate()
	j.time_limit = time_limit
	j.countdown = countdown
	return j

func test_emits_on_every_transition() -> bool:
	var root := _setup(load("res://data/jobs/test_job.tres"))
	var runner: JobRunner = root.get_node("Runner")
	var rec := Recorder.new()
	runner.state_changed.connect(rec.on_change)
	runner.begin()
	runner.launch()
	await Sim.physics_frames(185) # 3 s countdown
	runner.complete()
	root.free()
	return rec.states == [S.BRIEFING, S.COUNTDOWN, S.LIVE, S.COMPLETE]

func test_time_limit_fails() -> bool:
	var root := _setup(_job(1.0))
	var runner: JobRunner = root.get_node("Runner")
	runner.begin()
	runner.launch()
	await Sim.physics_frames(80)
	var still_live := runner.state == S.LIVE
	await Sim.physics_frames(20)
	var ok := still_live and runner.state == S.FAILED and runner.fail_reason == "time"
	root.free()
	return ok

func test_job_without_objectives_completes_on_call() -> bool:
	var root := _setup(_job())
	var runner: JobRunner = root.get_node("Runner")
	runner.begin()
	runner.complete() # ignored: not live yet
	var early := runner.state == S.BRIEFING
	runner.launch()
	await Sim.physics_frames(40)
	runner.complete()
	var ok := early and runner.state == S.COMPLETE and runner.is_over()
	root.free()
	return ok

func test_required_assists_applied_on_briefing() -> bool:
	var root := _setup(_job())
	var runner: JobRunner = root.get_node("Runner")
	var guard_before: bool = root.get_node("Drone/Assists/CollisionGuard").enabled
	runner.begin()
	var guard_after: bool = root.get_node("Drone/Assists/CollisionGuard").enabled
	var alt_after: bool = root.get_node("Drone/Assists/AltitudeHold").enabled
	root.free()
	return guard_before and not guard_after and alt_after

func test_expert_still_overrides_job_assists() -> bool:
	var root := _setup(_job())
	GameSettings.expert_all_assists_off = true
	root.get_node("Runner").begin()
	GameSettings.expert_all_assists_off = false
	var alt: bool = root.get_node("Drone/Assists/AltitudeHold").enabled
	root.free()
	return not alt

func test_drone_held_until_live() -> bool:
	var root := _setup(_job())
	var runner: JobRunner = root.get_node("Runner")
	var d: Drone = root.get_node("Drone")
	runner.begin()
	runner.launch()
	await Sim.physics_frames(20)
	var held := d.freeze and absf(d.global_position.y - 5.0) < 0.001
	await Sim.physics_frames(20)
	var ok := held and not d.freeze and runner.state == S.LIVE
	root.free()
	return ok

func test_auto_begin_and_enter_launches() -> bool:
	var root := _setup(_job())
	var runner: JobRunner = root.get_node("Runner")
	runner.auto_begin = true
	runner._ready()
	await Sim.process_frames(2)
	var briefing := runner.state == S.BRIEFING
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	root.get_viewport().push_input(ev)
	var ok := briefing and runner.state == S.COUNTDOWN
	root.free()
	return ok

# Story 1.6 acceptance: job default view is honored on Briefing.
func test_job_default_camera_view_on_briefing() -> bool:
	var root := _setup(_job()) # test_job asks for FPV
	var rig: CameraRig = root.get_node("Rig")
	var before := rig.view
	root.get_node("Runner").begin()
	var ok := before == CameraRig.View.CHASE and rig.view == CameraRig.View.FPV
	root.free()
	return ok
