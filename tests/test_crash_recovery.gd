extends RefCounted
# Story 1.13: crash recovery. A drone pinned to a wall by its own thrust, or
# turned over on the ground, is put back upright at its last level spot after
# 1.5 s and flies away; the battery is untouched; healthy flying never triggers it.

const Sim = preload("res://tests/sim.gd")

## A ground, a 4 m box ahead of the drone, and a drone flying at it under `stack`.
func _rig(stack: AssistStack, start: Vector3, i: Intent) -> Array:
	var root := Node3D.new()
	root.add_child(load("res://scenes/world/desert.tscn").instantiate())
	var box := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(4, 4, 4)
	shape.shape = b
	box.add_child(shape)
	root.add_child(box)
	box.position = Vector3(0, 2, -10)
	Sim.add(root)
	return [root, Sim.drone(i, start, stack)]

func test_pinned_to_a_wall_recovers_and_flies_away() -> bool:
	# Act 2: no collision guard, so a full-speed hit pins the drone nose up.
	var r := _rig(load("res://data/assists/act2.tres"), Vector3(0, 2, 0), Sim.intent(0, 1))
	var d: Drone = r[1]
	var recovery: CrashRecovery = d.get_node("Recovery")
	var heard := [0]
	d.recovered.connect(func(): heard[0] += 1)
	await Sim.physics_frames(60)
	d.battery = 0.6
	await Sim.physics_frames(120)
	var pinned := FlightControl.tilt(d) > deg_to_rad(60.0) or recovery.count > 0
	await Sim.physics_frames(90)
	var upright := FlightControl.tilt(d) < deg_to_rad(30.0)
	var battery_kept := d.battery > 0.55 and d.battery <= 0.6
	d.intent_source.value = Sim.intent(0, 0, 1)
	var at := d.global_position
	await Sim.physics_frames(120)
	var moved := (d.global_position - at).length()
	r[0].free()
	print("        pinned %s, recoveries %d, then moved %.1f m in 2 s" % [pinned, recovery.count, moved])
	return pinned and recovery.count == 1 and heard[0] == 1 and upright and battery_kept and moved > 4.0

func test_turned_over_on_the_ground_recovers() -> bool:
	var r := _rig(load("res://data/assists/act1.tres"), Vector3(20, 0.3, 0), Sim.intent())
	var d: Drone = r[1]
	d.rotate_x(PI)
	await Sim.physics_frames(150)
	var recovery: CrashRecovery = d.get_node("Recovery")
	var ok := recovery.count == 1 and FlightControl.tilt(d) < deg_to_rad(30.0) and d.global_position.y > 0.5
	r[0].free()
	return ok

func test_level_flight_and_flips_never_recover() -> bool:
	# Hover, cruise, and an Act 5 full-stick flip: tipped, but never still.
	var d := Sim.drone(Sim.intent(0, 0.5), Vector3(0, 30, 0), load("res://data/assists/act1.tres"))
	await Sim.physics_frames(240)
	var cruise: int = d.get_node("Recovery").count
	d.free()
	d = Sim.drone(Sim.intent(0.2, 1.0), Vector3(0, 40, 0))
	await Sim.physics_frames(90)
	var flip: int = d.get_node("Recovery").count
	d.free()
	return cruise == 0 and flip == 0

func test_frozen_drone_is_left_alone_and_hud_says_recovered() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 0.3, 0))
	d.rotate_x(PI)
	d.freeze = true
	await Sim.physics_frames(150)
	var frozen_ok: bool = d.get_node("Recovery").count == 0
	var hud := FlightHud.new()
	hud.drone = d
	Sim.add(hud)
	d.get_node("Recovery").recover()
	var shown := hud.recovered_age < FlightHud.RECOVERED_HOLD
	hud.free()
	d.free()
	return frozen_ok and shown
