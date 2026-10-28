class_name Snow
extends Node
# Snow that drifts and settles (Story 13.3). Flakes fall slowly in a box of CPU
# particles on the active camera, like rain's streaks, and are carried by the
# scene's wind sample. The `snow_cover` global shader uniform builds while it
# snows and melts after; the terrain, city, and street shaders whiten their
# upward-facing surfaces with it. Visual only. WeatherState adds one of these.

## Flakes at intensity 1.
@export var max_amount := 1600
## Seconds of heavy snow from bare to fully white; lighter snow builds slower.
@export var cover_time := 30.0
## Seconds from fully white back to bare once it stops.
@export var melt_time := 30.0
## Flakes' own fall speed in still air, m/s.
@export var fall_speed := 1.5
## Half-size of the falling box around the camera, m.
@export var extents := Vector3(14.0, 8.0, 14.0)

## 0 bare to 1 white; mirrored into the `snow_cover` global shader uniform.
var cover := 0.0
## The flakes, or null with no snow.
var particles: CPUParticles3D
var _time := 0.0

## Flakes for the weather in effect: max_amount scaled by intensity, 0 with no snow.
func amount() -> int:
	var w := _weather()
	if w == null or w.precipitation != Weather.Precipitation.SNOW:
		return 0
	return roundi(max_amount * w.intensity)

## A flake's velocity now: its fall plus the scene's wind sample.
func flake_velocity() -> Vector3:
	var w := _weather()
	var wind := w.wind.sample(_time) if w and w.wind else Vector3.ZERO
	return Vector3(0.0, -fall_speed, 0.0) + wind

func _weather() -> Weather:
	var state := get_parent() as WeatherState
	return state.weather if state else null

func _ready() -> void:
	_set_cover(0.0)

func _exit_tree() -> void:
	if is_instance_valid(particles):
		particles.queue_free()
	particles = null
	_set_cover(0.0)

func _process(delta: float) -> void:
	advance(delta)

## One step: flakes follow the camera and the wind, cover builds or melts.
func advance(delta: float) -> void:
	_time += delta
	var n := amount()
	if n > 0:
		cover = minf(cover + delta * _weather().intensity / cover_time, 1.0)
	elif cover > 0.0:
		cover = maxf(cover - delta / melt_time, 0.0)
	_set_cover(cover)
	_place_flakes(n)

func _set_cover(value: float) -> void:
	RenderingServer.global_shader_parameter_set(&"snow_cover", value)

func _place_flakes(n: int) -> void:
	if not is_instance_valid(particles):
		particles = null
	if n == 0:
		if particles:
			particles.queue_free()
			particles = null
		return
	if particles == null:
		particles = _make_flakes()
		particles.amount = n
	Rain.follow_camera(self, particles)
	# Small steps during a blend (Story 13.6) wait, since each change restarts
	# the emitter; once the blend lands the exact count goes on.
	var state := get_parent() as WeatherState
	var settled: bool = state == null or not state.blending
	if particles.amount != n and (settled or absi(particles.amount - n) * 16 > max_amount):
		particles.amount = n
	# Carried by the wind: the whole fall is the flake's own velocity, no gravity.
	var v := flake_velocity()
	particles.direction = v.normalized()
	particles.initial_velocity_min = v.length() * 0.85
	particles.initial_velocity_max = v.length() * 1.15

func _make_flakes() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "SnowFlakes"
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.spread = 12.0
	p.gravity = Vector3.ZERO
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.visibility_aabb = AABB(-extents * 4.0, extents * 8.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.96, 0.97, 1.0, 0.85)
	quad.material = mat
	p.mesh = quad
	return p
