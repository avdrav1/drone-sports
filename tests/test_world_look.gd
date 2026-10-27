extends RefCounted
# Story 9.1: golden-hour sky and light, shared by every flying scene.

const Sim = preload("res://tests/sim.gd")
const WORLD := "res://scenes/world/golden_hour.tscn"
const SCENES := ["res://scenes/debug_flight.tscn", "res://scenes/jobs/sample_delivery.tscn"]

func test_scenes_use_the_shared_world() -> bool:
	for path in SCENES:
		var scene: Node = load(path).instantiate()
		var envs := scene.find_children("*", "WorldEnvironment", true, false)
		var world := scene.get_node_or_null("GoldenHour")
		var ok := envs.size() == 1 and world != null and world.scene_file_path == WORLD and world.is_ancestor_of(envs[0])
		scene.free()
		if not ok:
			push_warning("%s does not use the shared world" % path)
			return false
	return true

func test_sun_is_low_and_casts_shadows() -> bool:
	var world: Node = load(WORLD).instantiate()
	var sun: DirectionalLight3D = world.get_node("Sun")
	# The light shines along -Z; the sun sits along +Z.
	var elevation := rad_to_deg(asin(sun.transform.basis.z.normalized().y))
	var ok := elevation > 0.0 and elevation < 20.0 and sun.shadow_enabled
	world.free()
	return ok

func test_fog_and_glow_on() -> bool:
	var world: Node = load(WORLD).instantiate()
	var env: Environment = world.get_node("WorldEnvironment").environment
	var ok := env.fog_enabled and env.glow_enabled and env.sky != null
	world.free()
	return ok

func test_scenes_load_without_errors() -> bool:
	for path in SCENES:
		var scene: Node = Sim.add(load(path).instantiate())
		await Sim.process_frames(3)
		scene.free()
	return true
