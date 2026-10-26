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
	var s := AssistStack.new()
	for id in AssistStack.IDS:
		s.set(id, false)
	return s

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
