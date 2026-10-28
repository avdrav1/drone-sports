extends RefCounted
# Story 14.6: the world. Every flying scene has an ambience loop playing on the
# World bus; debris impacts play one sound each.

const Sim = preload("res://tests/sim.gd")
const RIG := "res://scenes/camera/camera_rig.tscn"

## Every scene under scenes/ with a camera rig, or built on one that has it.
func _flying_scenes() -> Array[String]:
	var all: Array[String] = []
	_scan("res://scenes", all)
	var flying: Array[String] = []
	for p in all:
		if FileAccess.get_file_as_string(p).contains(RIG):
			flying.append(p)
	for p in all:
		var text := FileAccess.get_file_as_string(p)
		if not flying.has(p) and flying.any(func(f): return text.contains('path="%s"' % f)):
			flying.append(p)
	return flying

func _scan(dir: String, out: Array[String]) -> void:
	for d in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))

func _playing_ambience(root: Node) -> Array:
	return root.find_children("*", "Ambience", true, false).filter(func(a: Ambience) -> bool:
		return a.playing and a.stream != null and a.bus == &"World")

func test_every_flying_scene_has_an_ambience_playing() -> bool:
	var scenes := _flying_scenes()
	var ok := scenes.size() >= 9
	for path in scenes:
		var scene: Node = Sim.add(load(path).instantiate())
		await Sim.process_frames(2)
		var found := _playing_ambience(scene)
		if found.is_empty():
			print("        no ambience playing in %s" % path)
			ok = false
		scene.free()
	return ok

func test_places_have_their_own_loops() -> bool:
	var desert: Node = Sim.add(load("res://scenes/world/desert.tscn").instantiate())
	var city: Node = Sim.add(load("res://scenes/world/city.tscn").instantiate())
	var board: Node = Sim.add(load("res://scenes/ui/job_board.tscn").instantiate())
	await Sim.process_frames(1)
	var ids := []
	for n in [desert, city, board]:
		var a: Array = _playing_ambience(n)
		ids.append(a[0].event if a.size() == 1 else &"")
		n.free()
	return ids == [&"desert_wind", &"city_hum", &"room_tone"]

func _floor() -> StaticBody3D:
	var f := StaticBody3D.new()
	var s := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	s.shape = box
	f.add_child(s)
	Sim.add(f)
	f.global_position = Vector3(0, -0.5, 0)
	return f

func _debris(at: Vector3, release_on := &"") -> Debris:
	var d := Debris.new()
	d.release_on = release_on
	var s := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 1, 1)
	s.shape = box
	d.add_child(s)
	Sim.add(d)
	d.global_position = at
	return d

func test_debris_impacts_play_one_sound_each() -> bool:
	var f := _floor()
	var low := _debris(Vector3(-5, 2.0, 0))
	var high := _debris(Vector3(5, 8.0, 0))
	var resting := _debris(Vector3(0, 0.5, 0))
	var onto := _debris(Vector3(0, 6.0, 0))
	Sfx.clear_log()
	await Sim.physics_frames(150)
	var gains := Sfx.log.filter(func(l): return l.id == &"debris_impact").map(func(l): return l.gain_db)
	# One per landing; the piece dropped on the resting one is one impact between them.
	var ok: bool = low.impacts == 1 and high.impacts == 1 \
		and resting.impacts + onto.impacts == 1 and Sfx.count(&"debris_impact") == 3 \
		and high.last_impact_speed > low.last_impact_speed and gains.size() == 3 \
		and gains.max() > gains.min()
	if not ok:
		print("        impacts %d/%d/%d/%d count %d" % [low.impacts, high.impacts, resting.impacts,
			onto.impacts, Sfx.count(&"debris_impact")])
	for n in [low, high, resting, onto, f]:
		n.free()
	return ok

func test_held_debris_is_silent_and_drone_contacts_are_the_drones() -> bool:
	var f := _floor()
	var held := _debris(Vector3(0, 0.5, 0), &"later")
	var d: Drone = Sim.DRONE.instantiate()
	Sim.add(d)
	d.global_position = Vector3(5, 0.5, 0)
	Sfx.clear_log()
	held._on_body_entered(f)
	var loose := _debris(Vector3(5, 4.0, 0))
	await Sim.physics_frames(90)
	var ok: bool = held.impacts == 0 and loose.impacts == 0 and Sfx.count(&"debris_impact") == 0
	if not ok:
		print("        held %d loose %d count %d" % [held.impacts, loose.impacts, Sfx.count(&"debris_impact")])
	for n in [held, loose, d, f]:
		n.free()
	return ok

func test_demolition_debris_sounds_match_impacts() -> bool:
	var scene: Node = Sim.add(load("res://scenes/jobs/demolition.tscn").instantiate())
	await Sim.process_frames(2)
	var hazard: HazardScene = scene.find_children("*", "HazardScene", true, false)[0]
	Sfx.clear_log()
	hazard.fire_event(&"roof")
	await Sim.physics_frames(180)
	var total := 0
	for d in Sim.tree().get_nodes_in_group(Debris.GROUP):
		total += d.impacts
	var ok: bool = total > 0 and Sfx.count(&"debris_impact") == total
	if not ok:
		print("        impacts %d sounds %d" % [total, Sfx.count(&"debris_impact")])
	scene.free()
	return ok
