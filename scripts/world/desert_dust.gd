class_name DesertDust
extends Node
# Dust blowing with the wind (Story 15.8). Soft puffs of CPU particles rise from a
# box on the ground under the active camera, so they cost the same anywhere, and
# drift with the scene's Wind.sample, as snow's flakes do. Their count follows the
# wind's speed: none below lift_speed (still air included), all at full_speed.
# Visual only. DesertTerrain carries one; it reads the ground from its parent.

## Puffs at full_speed and above.
@export var max_amount := 400
## Wind speed where dust starts to lift, m/s.
@export var lift_speed := 3.0
## Wind speed where dust is at its thickest, m/s.
@export var full_speed := 14.0
## Half-size of the box puffs start in, around the ground under the camera, m.
@export var extents := Vector3(45.0, 2.0, 45.0)
## The wind to follow; null reads the scene's drone's.
@export var wind: Wind

## The puffs, or null in still air.
var particles: CPUParticles3D
var _time := 0.0
var _drone: Drone
var _look_again := 0.0

## Puffs for a wind speed, m/s: 0 up to lift_speed, max_amount from full_speed.
func amount_for(speed: float) -> int:
	return roundi(max_amount * clampf(inverse_lerp(lift_speed, full_speed, speed), 0.0, 1.0))

## The wind blowing the dust now, or null in still air.
func current_wind() -> Wind:
	if wind:
		return wind
	if not is_instance_valid(_drone):
		_drone = null
	if _drone == null and _look_again <= 0.0 and is_inside_tree():
		_look_again = 1.0
		var top: Node = self
		while top.get_parent() and top.get_parent() != get_tree().root:
			top = top.get_parent()
		for n in top.find_children("*", "RigidBody3D", true, false):
			if n is Drone:
				_drone = n
				break
	return _drone.wind if _drone else null

## The wind's velocity at `at` now; zero in still air.
func velocity(at: Vector3) -> Vector3:
	var w := current_wind()
	return w.sample(_time, at) if w else Vector3.ZERO

func _exit_tree() -> void:
	if is_instance_valid(particles):
		particles.queue_free()
	particles = null

func _process(delta: float) -> void:
	advance(delta)

## One step: puffs follow the ground under the camera, their count the wind.
func advance(delta: float) -> void:
	_time += delta
	_look_again -= delta
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var centre := camera.global_position if camera else Vector3.ZERO
	var ground := get_parent() as DesertTerrain
	centre.y = ground.height_at(centre.x, centre.z) if ground else 0.0
	var v := velocity(centre + Vector3.UP * 2.0)
	var n := amount_for(Vector2(v.x, v.z).length())
	if not is_instance_valid(particles):
		particles = null
	if n == 0:
		if particles:
			particles.queue_free()
			particles = null
		return
	if particles == null:
		particles = _make_puffs()
		particles.amount = n
		add_child(particles)
	# Each change restarts the emitter, so small ones wait.
	if particles.amount != n and absi(particles.amount - n) * 6 > max_amount:
		particles.amount = n
	# A jump (a camera cut, a respawn) refills the box at once rather than
	# leaving the puffs behind.
	var at := centre + Vector3.UP * (extents.y + 1.5)
	var jumped := particles.global_position.distance_to(at) > extents.x
	particles.global_position = at
	if jumped:
		particles.restart()
	particles.direction = v.normalized()
	particles.initial_velocity_min = v.length() * 0.7
	particles.initial_velocity_max = v.length() * 1.1

func _make_puffs() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "DustPuffs"
	# World space, so moving the box does not drag puffs already blowing.
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.spread = 15.0
	# Spread stays mostly level: dust skims the ground rather than climbing.
	p.flatness = 0.85
	p.gravity = Vector3.ZERO
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 10.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	p.visibility_aabb = AABB(-extents * 2.0 - Vector3(0, 10, 0), extents * 4.0 + Vector3(0, 20, 0))
	var quad := QuadMesh.new()
	# Wide and low: wisps skimming the ground, not balls.
	quad.size = Vector2(2.0, 0.7)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.roughness = 1.0
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.88, 0.7, 0.52, 0.45)
	mat.albedo_texture = _wisp()
	mat.disable_receive_shadows = true
	quad.material = mat
	p.mesh = quad
	return p

## A soft-edged streak of noise, wider than tall, white with the shape in alpha.
static func _wisp() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.05
	noise.fractal_octaves = 4
	var w := 128
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var d := Vector2((x + 0.5) / w * 2.0 - 1.0, (y + 0.5) / h * 2.0 - 1.0).length()
			var edge := pow(clampf(1.0 - d, 0.0, 1.0), 1.5)
			# Stretched along X so the wisp streaks with the wind.
			var n := noise.get_noise_2d(x * 0.5, y * 1.6) * 0.5 + 0.5
			img.set_pixel(x, y, Color(1, 1, 1, edge * smoothstep(0.25, 0.65, n)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
