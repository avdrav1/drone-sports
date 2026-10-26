extends RefCounted
# Story 2.3: ReachPoint, AvoidContact, FinishUnderTime.

const Sim = preload("res://tests/sim.gd")
const S := JobRunner.State

func _job(time_limit := 0.0) -> Job:
	var j: Job = load("res://data/jobs/test_job.tres").duplicate()
	j.time_limit = time_limit
	j.countdown = 0.1
	return j

func _reach(at: Vector3) -> ReachPoint:
	var marker := Marker3D.new()
	marker.position = at
	var r := ReachPoint.new()
	r.ends_job = true
	r.add_child(marker)
	r.target = marker
	return r

func test_reach_point_pass_completes_job() -> bool:
	var reach := _reach(Vector3(10, 5, 0))
	var root := Sim.job_setup(_job(5.0), [reach])
	await Sim.go_live(root)
	var d: Drone = root.get_node("Drone")
	await Sim.physics_frames(10)
	var early := reach.score() == 0.0
	d.global_position = Vector3(9, 5, 0) # within 2 m
	await Sim.physics_frames(3)
	var runner: JobRunner = root.get_node("Runner")
	var ok := early and reach.score() == 1.0 and runner.state == S.COMPLETE
	root.free()
	return ok

func test_reach_point_fail() -> bool:
	var reach := _reach(Vector3(50, 5, 0))
	var root := Sim.job_setup(_job(1.0), [reach])
	await Sim.go_live(root)
	await Sim.physics_frames(70)
	var runner: JobRunner = root.get_node("Runner")
	var ok := reach.score() == 0.0 and runner.state == S.FAILED
	root.free()
	return ok

func test_reach_ignored_before_live() -> bool:
	var reach := _reach(Vector3(0, 5, 0)) # drone starts on it
	var root := Sim.job_setup(_job(), [reach])
	root.get_node("Runner").begin()
	await Sim.physics_frames(5)
	var ok := not reach.reached
	root.free()
	return ok

func _floor_box(root: Node) -> void:
	var box := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(20, 1, 20)
	box.add_child(shape)
	root.add_child(box)
	box.global_position = Vector3(0, -0.5, 0)

func test_avoid_contact_pass() -> bool:
	var avoid := AvoidContact.new()
	var root := Sim.job_setup(_job(), [avoid])
	_floor_box(root)
	await Sim.go_live(root)
	await Sim.physics_frames(60) # hovering with Act 2 assists, well clear of the floor
	var ok := avoid.contacts == 0 and avoid.score() == 1.0
	root.free()
	return ok

func test_avoid_contact_fail_on_crash() -> bool:
	var avoid := AvoidContact.new()
	var root := Sim.job_setup(_job(), [avoid])
	_floor_box(root)
	await Sim.go_live(root)
	var d: Drone = root.get_node("Drone")
	d.assists.apply_stack(AssistStack.new().all_off())
	d.intent_source = null
	d.set_motor_thrusts(PackedFloat32Array([0, 0, 0, 0])) # drop it
	await Sim.physics_frames(90)
	var ok := avoid.contacts >= 1 and avoid.score() < 1.0
	root.free()
	return ok

func test_avoid_contact_deducts_per_hit_and_floors() -> bool:
	var avoid := AvoidContact.new()
	var root := Sim.job_setup(_job(), [avoid])
	await Sim.go_live(root)
	var scores := []
	for i in 6:
		avoid._on_body_entered(null)
		scores.append(avoid.score())
	root.free()
	return scores == [0.75, 0.5, 0.25, 0.0, 0.0, 0.0]

func test_finish_under_time_pass_and_fail() -> bool:
	var fast := FinishUnderTime.new()
	fast.target_time = 1.0
	var root := Sim.job_setup(_job(), [fast])
	await Sim.go_live(root)
	await Sim.physics_frames(30)
	root.get_node("Runner").complete()
	var pass_score := fast.score()
	root.free()
	var slow := FinishUnderTime.new()
	slow.target_time = 1.0
	root = Sim.job_setup(_job(), [slow])
	await Sim.go_live(root)
	await Sim.physics_frames(90)
	root.get_node("Runner").complete()
	var fail_score := slow.score()
	root.free()
	return pass_score == 1.0 and fail_score == 0.0

func test_finish_under_time_zero_on_failed_job() -> bool:
	var t := FinishUnderTime.new()
	var root := Sim.job_setup(_job(0.5), [t])
	await Sim.go_live(root)
	await Sim.physics_frames(40)
	var ok: bool = root.get_node("Runner").state == S.FAILED and t.score() == 0.0
	root.free()
	return ok
