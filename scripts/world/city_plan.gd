class_name CityPlan
extends RefCounted
# Turns a CityLayout into streets and lots: a grid of streets around a block on
# the origin, each block cut into lots set back from the kerb, and a height per lot
# that falls off from downtown to the edge. Pure data, no nodes. Deterministic
# per layout and cached, like DesertTerrain. Each lot also gets a shape (Story
# 15.6): stacked boxes and trims, from their own seeded stream so lots and
# heights are as before.

## Trim kinds: a low wall round a roof, a slab round a wall at a storey line, a
## plant room on the top roof.
enum Trim { PARAPET, LEDGE, PLANT }

## How far a ledge stands out from its wall, and how thick trims are.
const LEDGE_OUT := 0.3
const LEDGE_THICK := 0.3
const PARAPET_THICK := 0.3
## No box above a podium or setback is narrower than this.
const MIN_SIDE := 8.0
## Plant rooms keep this far from the roof's edge.
const PLANT_MARGIN := 1.5

## A building's shape, all within its lot. `boxes` stack from the street up: a
## podium when there is one, then the tower and each setback; the last box's
## top is the lot's height. Trims stand round them, each an AABB with its kind.
class Shape extends RefCounted:
	var boxes: Array[AABB] = []
	var trims: Array[AABB] = []
	var trim_kinds := PackedInt32Array()
	## The top roof clear of the plant room, in XZ.
	var roof_clear: Rect2

	func top() -> AABB:
		return boxes[boxes.size() - 1]

	func add_trim(kind: int, box: AABB) -> void:
		trims.append(box)
		trim_kinds.append(kind)

static var _cache := {}

## Street surfaces, kerb to kerb, in XZ (x, z), clipped to the core circle.
## Crossings overlap. Even entries run along z, odd entries along x.
var streets: Array[Rect2] = []
## Blocks between streets, kerb to kerb: sidewalk around the lots.
var blocks: Array[Rect2] = []
## Building footprints in XZ (x, z).
var lots: Array[Rect2] = []
## Height of each lot (its top box's roof), same order as lots.
var heights := PackedFloat32Array()
## Shape of each lot, same order as lots.
var shapes: Array[Shape] = []

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
	var shape_rng := RandomNumberGenerator.new()
	shape_rng.seed = layout.seed + 3
	for i in plan.lots.size():
		plan.shapes.append(_shape(layout, shape_rng, plan.lots[i], plan.heights[i]))
	return plan

## Stacks a building on `lot` up to `h`: maybe a podium filling the lot with the
## tower stood back on it, setbacks at storey lines, ledges every few storeys,
## parapets on every roof, and maybe a plant room on top.
static func _shape(layout: CityLayout, rng: RandomNumberGenerator, lot: Rect2, h: float) -> Shape:
	var s := Shape.new()
	var gf := layout.ground_floor
	var st := layout.storey
	# Walls above the podium (every wall, without one) stand in from the lot so
	# ledges stay on it.
	var foot := lot.grow(-LEDGE_OUT)
	var base := 0.0
	var podium := false
	if h >= gf + st * 4.0 and rng.randf() < 0.7:
		var tower := _inset(rng, foot, 1.5, 0.22, 0.75)
		if tower.has_area():
			base = gf + st * rng.randi_range(0, 2)
			s.boxes.append(_box(lot, 0.0, base))
			foot = tower
			podium = true
	# Setbacks, on one side or more: each part keeps at least two storeys.
	for k in rng.randi_range(0, 2):
		var lo := ceili((base + st * 2.0 - gf) / st - 0.001)
		var hi := floori((h - st * 2.0 - gf) / st + 0.001)
		var next := _inset(rng, foot, 1.5, 0.25, 0.35)
		if lo > hi or not next.has_area():
			break
		var cut := gf + st * rng.randi_range(lo, hi)
		s.boxes.append(_box(foot, base, cut))
		base = cut
		foot = next
	s.boxes.append(_box(foot, base, h))
	var every := rng.randi_range(3, 5)
	var ledges := rng.randf() < 0.75
	var parapet := rng.randf_range(0.8, 1.3)
	for j in s.boxes.size():
		var b := s.boxes[j]
		var top := b.end.y
		var out := b.grow(LEDGE_OUT)
		if ledges and not (podium and j == 0):
			# A cornice under the roof, and a ledge at every few storey lines. The
			# cornice rings the walls instead of spanning the roof, so its top
			# never shares the roof's plane (that z-fights).
			for strip in _ring(b, out, top - LEDGE_THICK, LEDGE_THICK):
				s.add_trim(Trim.LEDGE, strip)
			var n := ceili((b.position.y + st - gf) / st)
			while gf + st * n < top - st:
				if n % every == 0:
					s.add_trim(Trim.LEDGE, AABB(Vector3(out.position.x, gf + st * n - LEDGE_THICK * 0.5, out.position.z),
						Vector3(out.size.x, LEDGE_THICK, out.size.z)))
				n += 1
		# Parapets round the roof, except along a wall the box above stands flush on.
		var t := PARAPET_THICK
		var above := s.boxes[j + 1] if j + 1 < s.boxes.size() else AABB()
		for side in 4:
			var wall := _parapet(b, side, t)
			for piece in _uncovered(wall, above, side):
				s.add_trim(Trim.PARAPET, AABB(Vector3(piece.position.x, top, piece.position.y),
					Vector3(piece.size.x, parapet, piece.size.y)))
	# A plant room at one end of the top roof, leaving at least MIN_SIDE of it
	# clear (pads need the room).
	var roof := Rect2(foot.position, foot.size)
	s.roof_clear = roof
	var x_long := roof.size.x >= roof.size.y
	var long := maxf(roof.size.x, roof.size.y)
	var short := minf(roof.size.x, roof.size.y)
	var length := minf(long * rng.randf_range(0.22, 0.32), long - MIN_SIDE - PLANT_MARGIN - 0.5)
	if length >= 2.5 and rng.randf() < 0.8:
		var width := minf(short * rng.randf_range(0.4, 0.7), short - PLANT_MARGIN * 2.0)
		var across := rng.randf_range(PLANT_MARGIN, short - width - PLANT_MARGIN)
		var far_end := rng.randf() < 0.5
		var along := long - PLANT_MARGIN - length if far_end else PLANT_MARGIN
		var clear_from := 0.0 if far_end else along + length + 0.5
		var clear_len := along - 0.5 if far_end else long - clear_from
		var plant: Rect2
		if x_long:
			plant = Rect2(roof.position + Vector2(along, across), Vector2(length, width))
			s.roof_clear = Rect2(roof.position + Vector2(clear_from, 0.0), Vector2(clear_len, short))
		else:
			plant = Rect2(roof.position + Vector2(across, along), Vector2(width, length))
			s.roof_clear = Rect2(roof.position + Vector2(0.0, clear_from), Vector2(short, clear_len))
		s.add_trim(Trim.PLANT, _box(plant, h, h + rng.randf_range(2.6, 3.2)))
	return s

## Four boxes from `y` up `thick` filling `out` around `b`'s walls: the x sides
## run the full depth of `out`, the z sides only between them, so none overlap.
static func _ring(b: AABB, out: AABB, y: float, thick: float) -> Array[AABB]:
	var bx := b.position.x
	var ex := b.end.x
	return [
		AABB(Vector3(out.position.x, y, out.position.z), Vector3(bx - out.position.x, thick, out.size.z)),
		AABB(Vector3(ex, y, out.position.z), Vector3(out.end.x - ex, thick, out.size.z)),
		AABB(Vector3(bx, y, out.position.z), Vector3(b.size.x, thick, b.position.z - out.position.z)),
		AABB(Vector3(bx, y, b.end.z), Vector3(b.size.x, thick, out.end.z - b.end.z)),
	]

## The strip `t` wide along side `side` (-x, +x, -z, +z) of `b`'s roof, in XZ.
## The x sides run between the z sides so corners do not overlap.
static func _parapet(b: AABB, side: int, t: float) -> Rect2:
	match side:
		0:
			return Rect2(b.position.x, b.position.z + t, t, b.size.z - t * 2.0)
		1:
			return Rect2(b.end.x - t, b.position.z + t, t, b.size.z - t * 2.0)
		2:
			return Rect2(b.position.x, b.position.z, b.size.x, t)
		_:
			return Rect2(b.position.x, b.end.z - t, b.size.x, t)

## The parts of a parapet strip on `side` not inside a box `above` standing flush
## on that side (an empty `above` covers nothing).
static func _uncovered(strip: Rect2, above: AABB, side: int) -> Array[Rect2]:
	var flat := Rect2(above.position.x, above.position.z, above.size.x, above.size.z)
	var out: Array[Rect2] = []
	var flush: bool = above.has_volume() and [absf(flat.position.x - strip.position.x), absf(flat.end.x - strip.end.x),
		absf(flat.position.y - strip.position.y), absf(flat.end.y - strip.end.y)][side] < 0.01
	if not flush:
		out.append(strip)
		return out
	# Cut the covered span out along the strip's length.
	var a := 1 if side < 2 else 0
	var lo := Rect2(strip)
	lo.size[a] = flat.position[a] - strip.position[a]
	var hi := Rect2(strip)
	hi.position[a] = flat.end[a]
	hi.size[a] = strip.end[a] - flat.end[a]
	for piece in [lo, hi]:
		if piece.size[a] > 0.05:
			out.append(piece)
	return out

## A box over `r` from `y0` up to `y1`.
static func _box(r: Rect2, y0: float, y1: float) -> AABB:
	return AABB(Vector3(r.position.x, y0, r.position.y), Vector3(r.size.x, y1 - y0, r.size.y))

## `r` stood in on some sides (each with chance `chance`, at least one) by
## `least` metres up to `most` of its side, keeping sides of MIN_SIDE; an axis
## too narrow for that stays as it is, and an empty rect means no side could move.
static func _inset(rng: RandomNumberGenerator, r: Rect2, least: float, most: float, chance: float) -> Rect2:
	var d: Array[float] = []
	var first := rng.randi() % 4
	for k in 4:
		var amount := rng.randf_range(least, maxf(least, most * r.size[k / 2]))
		d.append(amount if k == first or rng.randf() < chance else 0.0)
	for k in 2:
		var spare := r.size[k] - MIN_SIDE
		var used := d[k * 2] + d[k * 2 + 1]
		if used > spare:
			# Shrink this axis's insets to fit, or drop them below `least`.
			var f := maxf(spare, 0.0) / used
			for j in [k * 2, k * 2 + 1]:
				d[j] = d[j] * f if d[j] * f >= least else 0.0
	if d.max() <= 0.0:
		return Rect2()
	return Rect2(r.position.x + d[0], r.position.y + d[2], r.size.x - d[0] - d[1], r.size.y - d[2] - d[3])

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
