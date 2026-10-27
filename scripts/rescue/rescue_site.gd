class_name RescueSite
extends Node3D
# Places the lost crew member (this node, with its prop, zone, beacon, and hold
# point as children) at a seeded spot in `area`, at least `min_distance` from
# the start. Same seed, same spot.

@export var seed := 7
## Ground area to search: position is the (min x, min z) corner.
@export var area := Rect2(-80, -160, 160, 120)
@export var start := Vector3.ZERO
@export var min_distance := 50.0
## Optional: stands the spot on this ground.
@export var terrain: DesertTerrain

func _ready() -> void:
	global_position = spot()

func spot() -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in 64:
		var p := Vector3(rng.randf_range(area.position.x, area.end.x), 0.0, rng.randf_range(area.position.y, area.end.y))
		if p.distance_to(Vector3(start.x, 0.0, start.z)) >= min_distance:
			return _grounded(p)
	return _grounded(Vector3(area.get_center().x, 0.0, area.get_center().y))

func _grounded(p: Vector3) -> Vector3:
	if terrain:
		p.y = terrain.height_at(p.x, p.z)
	return p
