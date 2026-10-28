class_name Rain
extends Node
# Rain that reads as rain (Story 13.2). Streaks fall in a box of CPU particles
# parented to the active camera, so they cost the same anywhere; their count
# follows intensity. The `wetness` global shader uniform ramps up while it rains
# and dries after, and the terrain, city, and street shaders darken and gloss
# with it. In FPV, drops bead on the lens as a screen overlay. Visual only.
# WeatherState adds one of these; it reads the weather from its parent.

const LENS_SHADER := preload("res://scenes/world/lens_drops.gdshader")

## Streaks at intensity 1.
@export var max_amount := 2400
## Seconds of rain from dry to soaked.
@export var wet_time := 10.0
## Seconds from soaked back to dry once it stops.
@export var dry_time := 20.0
## Half-size of the falling box around the camera, m.
@export var extents := Vector3(14.0, 8.0, 14.0)

## 0 dry to 1 soaked; mirrored into the `wetness` global shader uniform.
var wetness := 0.0
## The streaks, or null with no rain.
var particles: CPUParticles3D
var _lens: CanvasLayer
var _lens_material: ShaderMaterial

## Streaks for the weather in effect: max_amount scaled by intensity, 0 with no rain.
func amount() -> int:
	var w := _weather()
	if w == null or w.precipitation != Weather.Precipitation.RAIN:
		return 0
	return roundi(max_amount * w.intensity)

func _weather() -> Weather:
	var state := get_parent() as WeatherState
	return state.weather if state else null

func _ready() -> void:
	_set_wetness(0.0)

func _exit_tree() -> void:
	if is_instance_valid(particles):
		particles.queue_free()
	particles = null
	_set_wetness(0.0)

func _process(delta: float) -> void:
	advance(delta)

## One step: streaks follow the active camera, wetness ramps, lens drops show in FPV.
func advance(delta: float) -> void:
	var n := amount()
	if n > 0:
		wetness = minf(wetness + delta / wet_time, 1.0)
	elif wetness > 0.0:
		wetness = maxf(wetness - delta / dry_time, 0.0)
	_set_wetness(wetness)
	_place_streaks(n)
	_place_lens(n)

func _set_wetness(value: float) -> void:
	RenderingServer.global_shader_parameter_set(&"wetness", value)

func _place_streaks(n: int) -> void:
	if not is_instance_valid(particles):
		particles = null
	if n == 0:
		if particles:
			particles.queue_free()
			particles = null
		return
	if particles == null:
		particles = _make_streaks()
	follow_camera(self, particles)
	if particles.amount != n:
		particles.amount = n

## Parents `p` to the active camera, or to `owner_node` with none; snow shares it.
static func follow_camera(owner_node: Node, p: Node) -> void:
	var camera := owner_node.get_viewport().get_camera_3d() if owner_node.is_inside_tree() else null
	var host: Node = camera if camera else owner_node
	if p.get_parent() != host:
		if p.get_parent():
			p.get_parent().remove_child(p)
		host.add_child(p)

func _make_streaks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "RainStreaks"
	# World space, so turning the camera does not swing the rain.
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.DOWN
	p.spread = 2.0
	p.gravity = Vector3(0.0, -4.0, 0.0)
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 15.0
	p.lifetime = 1.2
	p.preprocess = 1.2
	p.visibility_aabb = AABB(-extents * 2.0, extents * 4.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.015, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.albedo_color = Color(0.75, 0.8, 0.88, 0.35)
	quad.material = mat
	p.mesh = quad
	return p

func _place_lens(n: int) -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var rig := camera.get_parent() as CameraRig if camera else null
	var show: bool = n > 0 and rig != null and rig.view == CameraRig.View.FPV
	if show and _lens == null:
		_lens = CanvasLayer.new()
		_lens.name = "LensDrops"
		_lens.layer = -1
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lens_material = ShaderMaterial.new()
		_lens_material.shader = LENS_SHADER
		rect.material = _lens_material
		_lens.add_child(rect)
		add_child(_lens)
	if _lens:
		_lens.visible = show
		_lens_material.set_shader_parameter(&"amount", 0.25 + 0.5 * float(n) / max_amount)

## True while drops show on the lens.
func lens_showing() -> bool:
	return _lens != null and _lens.visible
