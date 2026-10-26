extends RefCounted
# Story 2.5: results screen.

const Sim = preload("res://tests/sim.gd")
const JOB_SCENE := "res://scenes/jobs/sample_delivery.tscn"

func _open_job() -> Node:
	Sim.tree().change_scene_to_file(JOB_SCENE)
	await Sim.process_frames(3)
	return Sim.tree().current_scene

func _runner(scene: Node) -> JobRunner:
	return scene.get_node("JobRunner")

# Flies the sample job's drone onto the pad.
func _finish(scene: Node) -> void:
	var runner := _runner(scene)
	runner.launch()
	while runner.state != JobRunner.State.LIVE:
		await Sim.tree().physics_frame
	var d: Drone = scene.get_node("Drone")
	d.global_position = scene.get_node("DropPad/Target").global_position
	await Sim.physics_frames(2)

func test_shows_within_1s_with_every_objective() -> bool:
	var scene: Node = await _open_job()
	await _finish(scene)
	var runner := _runner(scene)
	var ended := runner.state == JobRunner.State.COMPLETE
	await Sim.physics_frames(60)
	var screen: Control = runner.results_screen
	var ok: bool = ended and screen != null and screen.is_visible_in_tree()
	if ok:
		var rows: Array = screen.get_node("%Rows").get_children().map(func(l): return l.text)
		ok = rows.size() == 3 and rows[0].contains("Reach the drop pad") and rows[0].contains("100%") \
			and rows[1].contains("No contact") and rows[2].contains("Under 25 s") \
			and screen.get_node("%Grade").text.contains("Grade A") \
			and screen.get_node("%Money").text.contains("Pay 500") \
			and screen.get_node("%Money").text.contains("+10")
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)
	return ok

func test_retry_reloads_same_job() -> bool:
	var scene: Node = await _open_job()
	var first_id := scene.get_instance_id()
	await _finish(scene)
	await Sim.physics_frames(60)
	_runner(scene).results_screen.retry()
	await Sim.process_frames(3)
	var now := Sim.tree().current_scene
	var ok: bool = now != null and now.get_instance_id() != first_id \
		and now.scene_file_path == JOB_SCENE and _runner(now).state == JobRunner.State.BRIEFING
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)
	return ok

func test_continue_returns_to_debug_scene() -> bool:
	var scene: Node = await _open_job()
	await _finish(scene)
	await Sim.physics_frames(60)
	_runner(scene).results_screen.continue_on()
	await Sim.process_frames(3)
	var ok: bool = Sim.tree().current_scene.scene_file_path == "res://scenes/debug_flight.tscn"
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)
	return ok

func test_failed_job_shows_results_too() -> bool:
	var scene: Node = await _open_job()
	var runner := _runner(scene)
	runner.launch()
	while runner.state != JobRunner.State.LIVE:
		await Sim.tree().physics_frame
	runner.fail("test")
	await Sim.physics_frames(60)
	var screen: Control = runner.results_screen
	var ok: bool = screen != null and screen.get_node("%Title").text.contains("FAILED") \
		and screen.get_node("%Grade").text.contains("Grade F")
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)
	return ok
