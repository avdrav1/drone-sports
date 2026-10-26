extends RefCounted
# Story 0.3: debug flight scene.

const Sim = preload("res://tests/sim.gd")
const SCENE := "res://scenes/debug_flight.tscn"

func test_is_main_scene() -> bool:
	return ProjectSettings.get_setting("application/run/main_scene") == SCENE

func test_scene_loads_and_has_readout() -> bool:
	var scene: Node = load(SCENE).instantiate()
	Sim.add(scene)
	await Sim.process_frames(2)
	var ok: bool = scene.get_node_or_null("HUD/Readout") is Label
	scene.free()
	return ok

func test_readout_updates_every_frame() -> bool:
	var scene: Node = Sim.add(load(SCENE).instantiate())
	await Sim.process_frames(1)
	var readout = scene.get_node("HUD/Readout")
	var before: int = readout.frames_updated
	await Sim.process_frames(10)
	var ok: bool = readout.frames_updated - before == 10 and readout.text.contains("pos")
	scene.free()
	return ok

func test_f1_toggles_readout() -> bool:
	var scene: Node = Sim.add(load(SCENE).instantiate())
	await Sim.process_frames(1)
	var readout: Label = scene.get_node("HUD/Readout")
	var start := readout.visible
	_press_f1(scene)
	var toggled := readout.visible == not start
	_press_f1(scene)
	var restored := readout.visible == start
	scene.free()
	return toggled and restored

func _press_f1(scene: Node) -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_F1
	down.pressed = true
	scene.get_viewport().push_input(down)
	var up := down.duplicate()
	up.pressed = false
	scene.get_viewport().push_input(up)
