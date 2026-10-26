extends RefCounted
# Story 1.8: assist presets by act.

const Sim = preload("res://tests/sim.gd")

# The CLAUDE.md table: assist -> first act where it is off.
const OFF_FROM := {
	&"collision_guard": 2, &"altitude_hold": 3, &"auto_level": 3,
	&"speed_governor": 4, &"battery_wind": 4, &"single_drone_view": 5,
}

func test_five_presets_match_table() -> bool:
	for act in range(1, 6):
		var stack: AssistStack = load("res://data/assists/act%d.tres" % act)
		if stack == null or stack.label != "Act %d" % act:
			return false
		for id in OFF_FROM:
			if stack.is_on(id) != (act < OFF_FROM[id]):
				print("        act %d: %s wrong" % [act, id])
				return false
	return true

func test_expert_overrides_preset() -> bool:
	var act1: AssistStack = load("res://data/assists/act1.tres")
	GameSettings.expert_all_assists_off = true
	var eff := GameSettings.effective_stack(act1)
	GameSettings.expert_all_assists_off = false
	for id in AssistStack.IDS:
		if eff.is_on(id):
			return false
	return act1.collision_guard and GameSettings.effective_stack(act1) == act1

func _press(scene: Node, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.pressed = true
	scene.get_viewport().push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	scene.get_viewport().push_input(up)

func _on(scene: Node, node: String) -> bool:
	return scene.get_node("Drone/Assists/" + node).enabled

func test_f2_cycles_presets_in_debug_scene() -> bool:
	var scene: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	await Sim.process_frames(2)
	var readout: Label = scene.get_node("HUD/Readout")
	var ok: bool = readout.text.contains("Act 1") and _on(scene, "CollisionGuard")
	_press(scene, KEY_F2)
	await Sim.process_frames(2)
	ok = ok and readout.text.contains("Act 2") and not _on(scene, "CollisionGuard") and _on(scene, "AltitudeHold")
	_press(scene, KEY_F2)
	_press(scene, KEY_F2)
	_press(scene, KEY_F2)
	await Sim.process_frames(2)
	ok = ok and readout.text.contains("Act 5") and not _on(scene, "BatteryWind")
	_press(scene, KEY_F2)
	await Sim.process_frames(2)
	ok = ok and readout.text.contains("Act 1") and _on(scene, "CollisionGuard")
	scene.free()
	return ok

func test_expert_toggle_in_debug_scene() -> bool:
	var scene: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	await Sim.process_frames(2)
	scene.get_node("HUD/Expert").button_pressed = true
	await Sim.process_frames(2)
	var all_off := true
	for a in scene.get_node("Drone/Assists").get_children():
		all_off = all_off and not a.enabled
	var shown: bool = scene.get_node("HUD/Readout").text.contains("expert")
	scene.get_node("HUD/Expert").button_pressed = false
	var restored := _on(scene, "CollisionGuard")
	scene.free()
	GameSettings.expert_all_assists_off = false
	return all_off and shown and restored
