extends RefCounted
# Story 20.2: crew in the field. Each job's crew prop is that person's figure;
# it idles, waves once per close pass, flinches on the warning, cheers on
# completion, sits hurt after a strike and is gone at once after one that
# kills; it has no collision, never changes the drone, and a dead character's
# prop never spawns.

const Sim = preload("res://tests/sim.gd")
const JOBS := ["res://scenes/jobs/inspection.tscn", "res://scenes/jobs/rescue.tscn", "res://scenes/jobs/demolition.tscn"]
const ZONE_AT := Vector3(0, 0, -30)

## A job rig with Marlo standing in a zone, and the drone parked far off and
## frozen unless `fly` is set.
func _rig(fly := false, with_prop := true) -> Node:
	var job := Job.new()
	job.crew_in_field = [&"marlo"]
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	runner.results_scene = null
	runner.back_scene = ""
	var zone := HazardZone.new()
	zone.name = "Zone"
	zone.character = &"marlo"
	root.add_child(zone)
	zone.global_position = ZONE_AT
	if with_prop:
		var prop := CrewProp.new()
		prop.name = "Prop"
		prop.character = &"marlo"
		zone.add_child(prop)
	if not fly:
		var d: Drone = root.get_node("Drone")
		d.freeze = true
		d.global_position = Vector3(0, 5, 20)
	return root

func _prop(root: Node) -> CrewProp:
	return root.get_node("Zone/Prop")

func _place_drone(root: Node, at: Vector3) -> void:
	root.get_node("Drone").global_position = at

func test_each_job_prop_shows_the_right_person() -> bool:
	var ok := true
	for path in JOBS:
		var scene: Node = Sim.add(load(path).instantiate())
		await Sim.process_frames(2)
		var props := scene.find_children("*", "CrewProp", true, false)
		ok = ok and props.size() == 1
		for p: CrewProp in props:
			var c := Roster.character(p.character)
			var good: bool = c != null and p.figure != null and p.figure.look == c.look \
				and p.zone != null and p.zone.character == p.character and p.runner != null \
				and p.action() == &"idle"
			if not good:
				print("        %s: wrong person" % path)
				ok = false
		scene.free()
	return ok

func test_plain_figure_without_character() -> bool:
	var prop := CrewProp.new()
	Sim.add(prop)
	await Sim.process_frames(1)
	var ok := prop.figure == null and prop.find_children("*", "MeshInstance3D", true, false).size() == 2
	prop.free()
	return ok

func test_idle_by_default_and_waves_once_per_pass() -> bool:
	var root := _rig()
	await Sim.go_live(root)
	var prop := _prop(root)
	var idle := prop.action() == &"idle"
	var waves := [0]
	var watch := func() -> void:
		for i in 150:
			var was := prop.action()
			await Sim.process_frames(1)
			if prop.action() == &"wave" and was != &"wave":
				waves[0] += 1
	# First pass: in close and hover there for 2.5 s; one wave, then idle.
	_place_drone(root, ZONE_AT + Vector3(3, 4, 0))
	await watch.call()
	var first: bool = waves[0] == 1 and prop.action() == &"idle"
	# Out past the pass distance and back: a second wave.
	_place_drone(root, ZONE_AT + Vector3(0, 4, 20))
	await Sim.process_frames(5)
	_place_drone(root, ZONE_AT + Vector3(-3, 4, 1))
	await watch.call()
	var second: bool = waves[0] == 2
	root.free()
	return idle and first and second

func test_flinches_on_warning_then_settles() -> bool:
	var root := _rig()
	await Sim.go_live(root)
	var prop := _prop(root)
	var zone: HazardZone = root.get_node("Zone")
	for i in 10:
		zone.threaten()
		await Sim.physics_frames(1)
	var flinched := zone.warning() and prop.action() == &"flinch"
	await Sim.physics_frames(60)
	var settled := not zone.warning() and prop.action() == &"idle"
	root.free()
	return flinched and settled

func test_hurt_after_strike() -> bool:
	var root := _rig()
	await Sim.go_live(root)
	var prop := _prop(root)
	var zone: HazardZone = root.get_node("Zone")
	for i in 75:
		zone.threaten()
		await Sim.physics_frames(1)
	var struck := zone.strike(&"timer")
	var hurt := prop.action() == &"hurt"
	await Sim.physics_frames(60)
	var stays := prop.action() == &"hurt"
	root.free()
	return struck and hurt and stays

## A strike that kills leaves no figure: it never sits down and is gone from the job.
func _killing_strike(lethal: bool, injured_first: bool) -> bool:
	if injured_first:
		Roster.injure(&"marlo")
	var root := _rig()
	var runner: JobRunner = root.get_node("Runner")
	runner.confirm_risk = false
	if lethal:
		runner.job.tags.append(&"lethal")
	await Sim.go_live(root)
	var prop := _prop(root)
	var zone: HazardZone = root.get_node("Zone")
	var actions: Array[StringName] = []
	for i in 75:
		zone.threaten()
		await Sim.physics_frames(1)
	runner.crew_struck.connect(func(_id: StringName, _b: Roster.Status) -> void: actions.append(prop.action()))
	var struck := zone.strike(&"timer")
	var dead := not Roster.is_alive(&"marlo")
	var hidden := not prop.visible
	await Sim.physics_frames(30)
	var gone := not is_instance_valid(prop) and root.find_children("*", "CrewProp", true, false).is_empty()
	root.free()
	return struck and dead and hidden and gone and not actions.has(&"hurt")

func test_lethal_strike_removes_figure() -> bool:
	return await _killing_strike(true, false)

func test_second_strike_removes_figure() -> bool:
	return await _killing_strike(false, true)

func test_cheers_on_completion() -> bool:
	var root := _rig()
	await Sim.go_live(root)
	var prop := _prop(root)
	var before := prop.action() == &"idle"
	root.get_node("Runner").complete()
	await Sim.process_frames(2)
	var ok := before and prop.action() == &"cheer"
	root.free()
	return ok

func test_no_collision_shape() -> bool:
	var root := _rig()
	await Sim.process_frames(2)
	var prop := _prop(root)
	var colliders := prop.find_children("*", "CollisionObject3D", true, false) + prop.find_children("*", "CollisionShape3D", true, false)
	var ok := prop.figure != null and colliders.is_empty()
	root.free()
	return ok

## The drone falls past the figure close enough to make it wave and turn; it
## ends in the same state as with no figure there.
func _fall(with_prop: bool) -> Array:
	var root := _rig(true, with_prop)
	var d: Drone = root.get_node("Drone")
	await Sim.go_live(root)
	d.global_position = ZONE_AT + Vector3(2, 6, 0)
	d.linear_velocity = Vector3.ZERO
	d.angular_velocity = Vector3.ZERO
	var waved := false
	for i in 60:
		await Sim.physics_frames(1)
		waved = waved or (with_prop and _prop(root).action() == &"wave")
	var out := [d.global_transform, d.linear_velocity, d.angular_velocity, waved]
	root.free()
	return out

func test_never_changes_the_drone() -> bool:
	var without := await _fall(false)
	var with := await _fall(true)
	return with[3] and with[0].is_equal_approx(without[0]) and with[1].is_equal_approx(without[1]) \
		and with[2].is_equal_approx(without[2])

func test_dead_character_prop_never_spawns() -> bool:
	Roster.kill(&"marlo")
	var root := _rig()
	var runner: JobRunner = root.get_node("Runner")
	runner.begin()
	await Sim.process_frames(1)
	var ok := root.find_children("*", "CrewProp", true, false).is_empty() and root.get_node_or_null("Zone") == null
	root.free()
	return ok
