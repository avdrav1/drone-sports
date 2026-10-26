extends RefCounted
# Story 1.3: assist pipeline.

const Sim = preload("res://tests/sim.gd")

class ZeroPitch extends Assist:
	func apply(intent: Intent, _drone: Drone, _delta: float) -> void:
		intent.pitch = 0.0

class SetPitch extends Assist:
	var value := 0.5
	func apply(intent: Intent, _drone: Drone, _delta: float) -> void:
		intent.pitch = value

class DoublePitch extends Assist:
	func apply(intent: Intent, _drone: Drone, _delta: float) -> void:
		intent.pitch *= 2.0

func test_enabled_assist_is_honored() -> bool:
	var d := Sim.drone(Sim.intent(0.0, 1.0))
	var stub := ZeroPitch.new()
	d.assists.add_child(stub)
	await Sim.physics_frames(1)
	var ok := d.intent.pitch == 0.0
	d.free()
	return ok

func test_disabled_assist_is_skipped() -> bool:
	var d := Sim.drone(Sim.intent(0.0, 1.0))
	var stub := ZeroPitch.new()
	stub.enabled = false
	d.assists.add_child(stub)
	await Sim.physics_frames(1)
	var ok := d.intent.pitch == 1.0
	d.free()
	return ok

func test_toggle_live() -> bool:
	var d := Sim.drone(Sim.intent(0.0, 1.0))
	var stub := ZeroPitch.new()
	d.assists.add_child(stub)
	await Sim.physics_frames(1)
	var on := d.intent.pitch == 0.0
	stub.enabled = false
	await Sim.physics_frames(1)
	var off := d.intent.pitch == 1.0
	d.free()
	return on and off

func test_runs_in_order_every_frame() -> bool:
	var d := Sim.drone(Sim.intent())
	var set := SetPitch.new()
	d.assists.add_child(set)
	d.assists.add_child(DoublePitch.new())
	var ok := true
	for i in 5:
		set.value = 0.1 * i
		await Sim.physics_frames(1)
		ok = ok and is_equal_approx(d.intent.pitch, 0.2 * i)
	d.assists.move_child(set, 1) # double first, then set: set wins
	await Sim.physics_frames(1)
	ok = ok and is_equal_approx(d.intent.pitch, set.value)
	d.free()
	return ok

func test_apply_stack_sets_enabled_by_id() -> bool:
	var pipeline := AssistPipeline.new()
	var a := ZeroPitch.new()
	a.assist_id = &"auto_level"
	var b := ZeroPitch.new()
	b.assist_id = &"collision_guard"
	pipeline.add_child(a)
	pipeline.add_child(b)
	var stack := AssistStack.new()
	stack.collision_guard = false
	pipeline.apply_stack(stack)
	var ok := a.enabled and not b.enabled
	pipeline.free()
	return ok

func test_readout_shows_stack() -> bool:
	var scene: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	var stub := ZeroPitch.new()
	stub.assist_id = &"stub_assist"
	scene.get_node("Drone/Assists").add_child(stub)
	await Sim.process_frames(2)
	var text: String = scene.get_node("HUD/Readout").text
	stub.enabled = false
	await Sim.process_frames(2)
	var text_off: String = scene.get_node("HUD/Readout").text
	scene.free()
	return text.contains("stub_assist ON") and text_off.contains("stub_assist off")
