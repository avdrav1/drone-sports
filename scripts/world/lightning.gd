class_name Lightning
extends Node
# Lightning in storms (Story 13.5). Strikes come at the weather's rate per minute,
# seeded by its storm_seed, so the same seed repeats the same storm. Each strike
# is an event with a time and a place (thunder, Story 14.7, listens to `struck`):
# it flashes the sky and ambient light of the scene's weather Environment for a
# moment and draws a short-lived bolt in the distance. Atmosphere only: nothing
# is hit or harmed. WeatherState adds one of these; it reads the weather from
# its parent and centres strikes on the scene that holds the WeatherState.

## Emitted as each strike lands.
signal struck(strike: Strike)

## One strike: seconds since the storm began, and where it lands (world space).
class Strike extends RefCounted:
	var time := 0.0
	var position := Vector3.ZERO

## Seconds from full flash back to the scene's own light.
@export var flash_time := 0.35
## Ambient light at the peak of a flash, as a multiple of the scene's.
@export var flash_ambient := 2.5
## Sky brightness at the peak of a flash, as a multiple of the scene's.
@export var flash_sky := 2.5
## Seconds a bolt stays on screen.
@export var bolt_time := 0.2
## Height a bolt falls from, m.
@export var bolt_height := 450.0
## Width of a bolt's ribbon, m; wide enough to read at a distance.
@export var bolt_width := 4.0

## 1 at a strike, falling to 0 over flash_time.
var flash := 0.0
## The next strike, or null with no storm.
var next_strike: Strike
## The bolt on screen, or null.
var bolt: MeshInstance3D
var _time := 0.0
var _bolt_left := 0.0
var _rng := RandomNumberGenerator.new()
var _storm_seed := -1

## Strikes in the first `seconds` of a storm of `w`, centred on `centre`:
## the same schedule a Lightning node plays, for tests and previews.
static func plan(w: Weather, seconds: float, centre := Vector3.ZERO) -> Array[Strike]:
	var out: Array[Strike] = []
	if w == null or w.lightning_per_minute <= 0.0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = w.storm_seed
	var s := roll(rng, w, 0.0, centre)
	while s.time <= seconds:
		out.append(s)
		s = roll(rng, w, s.time, centre)
	return out

## The strike after `after`: a random wait averaging 60 / rate seconds, at a
## random bearing and a distance inside the weather's strike range.
static func roll(rng: RandomNumberGenerator, w: Weather, after: float, centre: Vector3) -> Strike:
	var s := Strike.new()
	var mean := 60.0 / w.lightning_per_minute
	s.time = after + maxf(-log(1.0 - rng.randf() * 0.999) * mean, 0.25)
	var bearing := rng.randf() * TAU
	var distance := rng.randf_range(w.strike_distance.x, w.strike_distance.y)
	s.position = centre + Vector3(cos(bearing), 0.0, sin(bearing)) * distance
	return s

func _weather() -> Weather:
	var state := get_parent() as WeatherState
	return state.weather if state else null

func _scope() -> Node:
	var state := get_parent()
	return state.get_parent() if state else null

func _centre() -> Vector3:
	var scope := _scope() as Node3D
	return scope.global_position if scope and scope.is_inside_tree() else Vector3.ZERO

func _exit_tree() -> void:
	flash = 0.0
	_light()

func _process(delta: float) -> void:
	advance(delta)

## One step: lands any strikes now due, fades the flash, and clears old bolts.
func advance(delta: float) -> void:
	_time += delta
	var w := _weather()
	var storming: bool = w != null and w.lightning_per_minute > 0.0
	if not storming:
		next_strike = null
		_storm_seed = -1
	elif next_strike == null or w.storm_seed != _storm_seed:
		# A new storm starts its seeded schedule from now.
		_storm_seed = w.storm_seed
		_rng.seed = w.storm_seed
		_time = 0.0
		next_strike = roll(_rng, w, 0.0, _centre())
	if flash > 0.0:
		flash = maxf(flash - delta / flash_time, 0.0)
	while next_strike and next_strike.time <= _time:
		var s := next_strike
		next_strike = roll(_rng, w, s.time, _centre())
		strike(s)
	_light()
	if bolt:
		_bolt_left -= delta
		if _bolt_left <= 0.0:
			bolt.queue_free()
			bolt = null

## Lands `s` now: full flash, a bolt at its place, and `struck`.
func strike(s: Strike) -> void:
	flash = 1.0
	_light()
	if bolt:
		bolt.queue_free()
	bolt = _make_bolt(s.position)
	add_child(bolt)
	_bolt_left = bolt_time
	struck.emit(s)

## The scene's ambient and sky light, raised by the flash. Only the per-scene
## copy that Weather.apply made is touched; the shared Environment never is.
func _light() -> void:
	var scope := _scope()
	if scope == null:
		return
	for env_node in scope.find_children("*", "WorldEnvironment", true, false):
		var clear: Environment = env_node.get_meta(&"clear_environment", null)
		var env: Environment = env_node.environment
		if clear == null or env == null or env == clear:
			continue
		env.ambient_light_energy = clear.ambient_light_energy * lerpf(1.0, flash_ambient, flash)
		env.background_energy_multiplier = clear.background_energy_multiplier * lerpf(1.0, flash_sky, flash)

## A jagged ribbon from the cloud base down to `at`, turned to face the camera.
func _make_bolt(at: Vector3) -> MeshInstance3D:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var to_eye := (camera.global_position - at) if camera else Vector3.BACK
	to_eye.y = 0.0
	var side := Vector3.UP.cross(to_eye).normalized() if to_eye.length() > 0.01 else Vector3.RIGHT
	var shape := RandomNumberGenerator.new()
	shape.seed = hash(at)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var steps := 14
	for i in steps + 1:
		var t := float(i) / steps
		var p := at + Vector3.UP * bolt_height * (1.0 - t)
		if i > 0 and i < steps:
			p += side * shape.randf_range(-25.0, 25.0) + Vector3(0.0, shape.randf_range(-8.0, 8.0), 0.0)
		var w := bolt_width * lerpf(1.0, 0.5, t)
		mesh.surface_add_vertex(p - side * w)
		mesh.surface_add_vertex(p + side * w)
	mesh.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	mat.albedo_color = Color(0.92, 0.95, 1.0)
	var mi := MeshInstance3D.new()
	mi.name = "Bolt"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
