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

static func process_frames(n: int) -> void:
	for i in n:
		await tree().process_frame
