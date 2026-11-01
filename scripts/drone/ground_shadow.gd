class_name GroundShadow
extends MeshInstance3D
# A soft shadow on whatever is straight below the drone, so a pilot can judge
# height and where they will touch down. The golden-hour sun is too low to do
# that: it throws the real shadow far off to one side. A mesh and not a Decal,
# which the web's GL Compatibility renderer does not draw. Visual only: reads the
# parent Drone and casts a ray down; never touches physics.

## No shadow above this height over the ground, m. It fades out on the way up.
@export var max_height := 40.0
## Width on the ground when the drone is down, and at `max_height`, m.
@export var near_size := 0.9
@export var far_size := 3.0
## Darkness when the drone is down, 0 to 1.
@export var near_alpha := 0.7
## Lift off the surface so the two do not fight, m.
@export var lift := 0.03

static var _texture: GradientTexture2D

var drone: Drone
## Height over the ground this tick, m; meaningless while hidden.
var height := 0.0

var _material: StandardMaterial3D

func _ready() -> void:
	drone = get_parent() as Drone
	top_level = true
	visible = false
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	mesh = plane
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_texture = _falloff()
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED

func _physics_process(_delta: float) -> void:
	if drone == null:
		return
	var from := drone.global_position
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * max_height)
	ray.exclude = [drone.get_rid()]
	var hit := drone.get_world_3d().direct_space_state.intersect_ray(ray)
	# A ray that starts touching a shape reports no normal, and no ground either.
	visible = not hit.is_empty() and hit.normal != Vector3.ZERO
	if not visible:
		return
	height = from.y - hit.position.y
	var t := clampf(height / max_height, 0.0, 1.0)
	_material.albedo_color = Color(0, 0, 0, lerpf(near_alpha, 0.0, t))
	# Lies on the surface, so it follows a slope or a ramp.
	var basis_on_surface := Basis(Quaternion(Vector3.UP, hit.normal))
	global_transform = Transform3D(
		basis_on_surface.scaled(Vector3.ONE * lerpf(near_size, far_size, t)),
		hit.position + hit.normal * lift
	)

## Dark in the middle, easing out with no edge, which would read as a hole in the
## ground. Shared: every drone's looks the same.
static func _falloff() -> GradientTexture2D:
	if _texture:
		return _texture
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	ramp.colors = PackedColorArray([
		Color.WHITE, Color(1, 1, 1, 0.82), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.13), Color(1, 1, 1, 0),
	])
	_texture = GradientTexture2D.new()
	_texture.gradient = ramp
	_texture.width = 64
	_texture.height = 64
	_texture.fill = GradientTexture2D.FILL_RADIAL
	_texture.fill_from = Vector2(0.5, 0.5)
	_texture.fill_to = Vector2(0.5, 0.0)
	return _texture
