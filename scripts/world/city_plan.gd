class_name CityPlan
extends RefCounted
# Turns a CityLayout into streets and lots: a grid of streets around a block on
# the origin, each block cut into lots set back from the kerb, and a height per lot
# that falls off from downtown to the edge. Pure data, no nodes. Deterministic
# per layout and cached, like DesertTerrain.

static var _cache := {}

## Street surfaces, kerb to kerb, in XZ (x, z), clipped to the core circle.
## Crossings overlap. Even entries run along z, odd entries along x.
var streets: Array[Rect2] = []
## Blocks between streets, kerb to kerb: sidewalk around the lots.
var blocks: Array[Rect2] = []
## Building footprints in XZ (x, z).
var lots: Array[Rect2] = []
## Height of each lot, same order as lots.
var heights := PackedFloat32Array()

static func build(layout: CityLayout) -> CityPlan:
	var key := layout.params()
	if not _cache.has(key):
		_cache[key] = _generate(layout)
	return _cache[key]

## True when a lot rectangle stays clear of every reserved clearing.
static func clear_of(layout: CityLayout, r: Rect2) -> bool:
	for c in layout.clearings:
		var near := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
		if near.distance_to(Vector2(c.x, c.y)) < c.z:
			return false
	return true

## True when all four corners of `r` lie within `radius` of the origin.
static func inside(r: Rect2, radius: float) -> bool:
	for p in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
		if p.length() > radius:
			return false
	return true

static func _generate(layout: CityLayout) -> CityPlan:
	var plan := CityPlan.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed
	var axis := _axis(layout)
	var r := layout.core_radius
	for s: Vector2 in axis[0]:
		var edge := maxf(absf(s.x), absf(s.y))
		if edge >= r:
			continue
		var half := sqrt(r * r - edge * edge)
		plan.streets.append(Rect2(s.x, -half, s.y - s.x, half * 2.0))
		plan.streets.append(Rect2(-half, s.x, half * 2.0, s.y - s.x))
	for bx: Vector2 in axis[1]:
		for bz: Vector2 in axis[1]:
			plan.blocks.append(Rect2(bx.x, bz.x, bx.y - bx.x, bz.y - bz.x))
			for cx in _split(layout, rng, bx):
				for cz in _split(layout, rng, bz):
					var lot := Rect2(cx.x, cz.x, cx.y - cx.x, cz.y - cz.x)
					var jitter := rng.randf_range(0.5, 1.0)
					if not inside(lot, r) or not clear_of(layout, lot):
						continue
					var d := clampf(lot.get_center().length() / r, 0.0, 1.0)
					var t := pow(1.0 - d, layout.height_falloff) * jitter
					plan.lots.append(lot)
					plan.heights.append(lerpf(layout.height_min, layout.height_max, t))
	return plan

## [streets, blocks] along one axis as (start, end) spans, mirrored about the
## origin. A block sits on the centre, so the spawn plaza is a square, not a
## crossing; street k counts out from it and every avenue_every-th is an avenue.
static func _axis(layout: CityLayout) -> Array:
	var streets: Array[Vector2] = []
	var blocks: Array[Vector2] = []
	var at := layout.block_size * 0.5
	blocks.append(Vector2(-at, at))
	var k := 1
	while at < layout.core_radius:
		var w := _width(layout, k)
		streets.append(Vector2(at, at + w))
		streets.append(Vector2(-at - w, -at))
		at += w
		blocks.append(Vector2(at, at + layout.block_size))
		blocks.append(Vector2(-at - layout.block_size, -at))
		at += layout.block_size
		k += 1
	return [streets, blocks]

static func _width(layout: CityLayout, k: int) -> float:
	return layout.avenue_width if layout.avenue_every > 0 and k % layout.avenue_every == 0 else layout.street_width

## Cuts a block span into lot spans inside the sidewalk, with an alley between.
static func _split(layout: CityLayout, rng: RandomNumberGenerator, span: Vector2) -> Array[Vector2]:
	var a := span.x + layout.sidewalk
	var length := span.y - layout.sidewalk - a
	var g := layout.lot_gap
	var fewest := maxi(1, ceili((length + g) / (layout.lot_max + g)))
	var most := maxi(fewest, floori((length + g) / (layout.lot_min + g)))
	var n := rng.randi_range(fewest, most)
	var weights: Array[float] = []
	var total := 0.0
	for i in n:
		weights.append(rng.randf_range(layout.lot_min, layout.lot_max))
		total += weights[i]
	var scale := (length - g * (n - 1)) / total
	var out: Array[Vector2] = []
	for w in weights:
		out.append(Vector2(a, a + w * scale))
		a += w * scale + g
	return out
