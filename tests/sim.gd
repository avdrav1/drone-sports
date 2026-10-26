extends RefCounted
# Helpers for tests that need the scene tree. Use: const Sim = preload("res://tests/sim.gd")
# scripts/test.sh runs with --fixed-fps 60, so one process frame is one physics tick.

static func tree() -> SceneTree:
	return Engine.get_main_loop()

static func add(node: Node) -> Node:
	tree().root.add_child(node)
	return node

static func physics_frames(n: int) -> void:
	for i in n:
		await tree().physics_frame

## Note: process_frame fires before nodes' _process, so wait 2 to observe a _process update.
static func process_frames(n: int) -> void:
	for i in n:
		await tree().process_frame

const DRONE := preload("res://scenes/drone/drone.tscn")

## An IntentSource that returns a copy of `value` every frame.
class FixedSource extends IntentSource:
	var value := Intent.new()
	func read_intent() -> Intent:
		return value.copy()

static func intent(throttle := 0.0, pitch := 0.0, roll := 0.0, yaw := 0.0) -> Intent:
	var i := Intent.new()
	i.throttle = throttle
	i.pitch = pitch
	i.roll = roll
	i.yaw = yaw
	return i

static func all_off() -> AssistStack:
	return AssistStack.new().all_off()

## Spawns a drone in the tree driven by a FixedSource. Every assist starts off
## unless a stack is given. Change the intent via drone.intent_source.value.
static func drone(with_intent: Intent, position := Vector3(0, 20, 0), stack: AssistStack = null) -> Drone:
	var d: Drone = DRONE.instantiate()
	var src := FixedSource.new()
	src.value = with_intent
	d.add_child(src)
	d.intent_source = src
	add(d)
	d.assists.apply_stack(stack if stack else all_off())
	d.global_position = position
	return d

## A job rig: root Node3D with Drone, Rig (CameraRig), and Runner (JobRunner,
## auto_begin off). The drone starts at (0, 5, 0). Caller frees the root.
static func job_setup(job: Job, objectives: Array = []) -> Node:
	var root := Node3D.new()
	var d: Drone = DRONE.instantiate()
	d.name = "Drone"
	root.add_child(d)
	var rig: CameraRig = load("res://scenes/camera/camera_rig.tscn").instantiate()
	rig.name = "Rig"
	rig.target = d
	root.add_child(rig)
	var runner := JobRunner.new()
	runner.name = "Runner"
	runner.job = job
	runner.drone = d
	runner.camera_rig = rig
	runner.auto_begin = false
	for o in objectives:
		runner.add_child(o)
	root.add_child(runner)
	add(root)
	d.global_position = Vector3(0, 5, 0)
	return root

## Begin, launch, and wait out the countdown.
static func go_live(root: Node) -> void:
	var runner: JobRunner = root.get_node("Runner")
	runner.begin()
	runner.launch()
	while runner.state == JobRunner.State.COUNTDOWN:
		await tree().physics_frame
