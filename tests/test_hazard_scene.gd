extends RefCounted
# Story 4.1: scripted hazard scene. Timeline events fire on time from Countdown,
# debris landing in a hazard zone is reported, and crew props never collide.

const Sim = preload("res://tests/sim.gd")

## A runner rig plus a HazardScene with events at 0.5 s (collapse) and 1.25 s (crane).
func _setup() -> Array:
	var job := Job.new()
	job.countdown = 3.0
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	var hz := HazardScene.new()
	var player := AnimationPlayer.new()
	player.name = "Timeline"
	var anim := Animation.new()
	anim.length = 2.0
	var t := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(t, NodePath("."))
	anim.track_insert_key(t, 0.5, {"method": &"fire_event", "args": [&"collapse"]})
	anim.track_insert_key(t, 1.25, {"method": &"fire_event", "args": [&"crane"]})
	var lib := AnimationLibrary.new()
	lib.add_animation(&"events", anim)
	player.add_animation_library(&"", lib)
	hz.add_child(player)
	player.root_node = NodePath("..")
	hz.runner = runner
	hz.timeline = player
	root.add_child(hz)
	return [root, runner, hz]

func test_events_fire_at_timeline_times() -> bool:
	var s := _setup()
	var runner: JobRunner = s[1]
	var hz: HazardScene = s[2]
	var log := []
	hz.event_fired.connect(func(e, _t): log.append([e, runner.state_time]))
	runner.begin()
	await Sim.physics_frames(30)
	var none_in_briefing := hz.fired.is_empty()
	runner.launch()
	await Sim.physics_frames(100)
	s[0].free()
	var frame := 1.0 / 60.0
	return none_in_briefing and log.size() == 2 and log[0][0] == &"collapse" and log[1][0] == &"crane" \
		and absf(log[0][1] - 0.5) <= frame * 1.5 and absf(log[1][1] - 1.25) <= frame * 1.5

func test_timeline_never_restarts() -> bool:
	var s := _setup()
	var runner: JobRunner = s[1]
	var hz: HazardScene = s[2]
	var count := [0]
	hz.event_fired.connect(func(_e, _t): count[0] += 1)
	runner.begin()
	runner.launch()
	await Sim.physics_frames(90)
	hz.start()
	runner.state_changed.emit(JobRunner.State.COUNTDOWN, JobRunner.State.BRIEFING)
	await Sim.physics_frames(90)
	s[0].free()
	return count[0] == 2

func test_debris_in_zone_emits() -> bool:
	var root: Node3D = Sim.add(Node3D.new())
	var hz := HazardScene.new()
	root.add_child(hz)
	var zone := HazardZone.new()
	zone.character = &"bea"
	var zs := CollisionShape3D.new()
	zs.shape = BoxShape3D.new()
	zs.shape.size = Vector3(4, 4, 4)
	zone.add_child(zs)
	hz.add_child(zone)
	zone.global_position = Vector3(0, 2, 0)
	var debris := Debris.new()
	debris.release_on = &"collapse"
	var ds := CollisionShape3D.new()
	ds.shape = BoxShape3D.new()
	ds.shape.size = Vector3(0.5, 0.5, 0.5)
	debris.add_child(ds)
	hz.add_child(debris)
	debris.global_position = Vector3(0, 8, 0)
	var hits := []
	zone.debris_in_zone.connect(func(d): hits.append(d))
	await Sim.physics_frames(30)
	var held := hits.is_empty() and debris.global_position.y > 7.9
	hz.fire_event(&"collapse")
	await Sim.physics_frames(90)
	root.free()
	return held and hits.size() == 1 and hits[0] == debris

func test_crew_props_do_not_collide() -> bool:
	var prop := CrewProp.new()
	Sim.add(prop)
	var colliders := prop.find_children("*", "CollisionObject3D", true, false) + prop.find_children("*", "CollisionShape3D", true, false)
	var meshes := prop.find_children("*", "MeshInstance3D", true, false)
	prop.free()
	return colliders.is_empty() and meshes.size() == 2

func test_base_scene_has_a_timeline() -> bool:
	var hz: HazardScene = Sim.add(load("res://scenes/hazard/hazard_scene.tscn").instantiate())
	var ok := hz.timeline != null and hz.timeline.has_animation(&"events") \
		and hz.timeline.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	hz.free()
	return ok
