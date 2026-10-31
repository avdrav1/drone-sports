class_name CityPlan
extends RefCounted
# Turns a CityLayout into streets and lots: a grid of streets around a block on
# the origin, each block cut into lots set back from the kerb, and a height per lot
# that falls off from downtown to the edge. Pure data, no nodes. Deterministic
# per layout and cached, like DesertTerrain. Each lot also gets a shape (Story
# 15.6): stacked boxes and trims, from their own seeded stream so lots and
# heights are as before. Story 26.3: segments of the grid may be dropped, merging
# the blocks either side into superblocks, and some blocks left as paved squares,
# each from its own stream so chances of 0 build the plan as before.

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
## Crossings overlap. Each grid line gives its runs along z, then its runs along
## x; with no dropped segments that is one of each, so even entries run along z
## and odd entries along x. `street_axis` says which for every entry.
var streets: Array[Rect2] = []
## 0 for a street running along z, 1 along x; same order as streets.
var street_axis := PackedInt32Array()
## Blocks between streets, kerb to kerb: sidewalk around the lots. A superblock
## (Story 26.3) is one rect over the blocks it merged and the streets between.
var blocks: Array[Rect2] = []
## Street segments left out (Story 26.3), kerb to kerb between the junctions
## either side; each lies inside a superblock in `blocks`.
var dropped: Array[Rect2] = []
## Blocks left as paved squares, with no lots (Story 26.3). Also in `blocks`.
var squares: Array[Rect2] = []
## Building footprints in XZ (x, z).
var lots: Array[Rect2] = []
## Lots left empty (Story 26.2): sand, no building, no shape. Never in `lots`.
var vacant: Array[Rect2] = []
## Height of each lot (its top box's roof), same order as lots.
var heights := PackedFloat32Array()
## Shape of each lot, same order as lots.
var shapes: Array[Shape] = []

static func build(layout: CityLayout) -> CityPlan:
	var key := layout.params()
	if not _cache.has(key):
		_cache[key] = _generate(layout)
	return _cache[key]

## Drops cached plans of every layout but `keep` (Story 26.1).
static func prune(keep: CityLayout) -> void:
	keep.prune(_cache)

## True when a lot rectangle stays clear of every reserved clearing.
static func clear_of(layout: CityLayout, r: Rect2) -> bool:
	for c in layout.clearings:
		var near := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
		if near.distance_to(Vector2(c.x, c.y)) < c.z:
			return false
	return true

## True when the clearing `c` (x, z, radius) reaches into `r`.
static func touches(c: Vector3, r: Rect2) -> bool:
	var near := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return near.distance_to(Vector2(c.x, c.y)) < c.z

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
	# Vacancy draws from its own stream, so the lots and heights are as before.
	var vacancy := RandomNumberGenerator.new()
	vacancy.seed = layout.seed + 5
	var lines: Array[Vector2] = []
	for s: Vector2 in axis[0]:
		if maxf(absf(s.x), absf(s.y)) < r:
			lines.append(s)
	var grid := _merge(layout, lines, axis[1])
	plan.dropped = grid.dropped
	var runs := _runs(layout, lines, axis[1], grid.of)
	plan.streets = runs[0]
	plan.street_axis = runs[1]
	var squaring := RandomNumberGenerator.new()
	squaring.seed = layout.seed + 19
	var sorted := _sorted(axis[1])
	var emitted := {}
	for bx: Vector2 in axis[1]:
		for bz: Vector2 in axis[1]:
			var g: int = grid.of[Vector2i(sorted.find(bx), sorted.find(bz))]
			if emitted.has(g):
				continue
			emitted[g] = true
			var cells: Rect2i = grid.groups[g]
			var sx := Vector2(sorted[cells.position.x].x, sorted[cells.end.x - 1].y)
			var sz := Vector2(sorted[cells.position.y].x, sorted[cells.end.y - 1].y)
			var block := Rect2(sx.x, sz.x, sx.y - sx.x, sz.y - sz.x)
			plan.blocks.append(block)
			if layout.square_chance > 0.0 and inside(block, r) and squaring.randf() < layout.square_chance:
				plan.squares.append(block)
				continue
			for cx in _split(layout, rng, sx):
				for cz in _split(layout, rng, sz):
					var lot := Rect2(cx.x, cz.x, cx.y - cx.x, cz.y - cz.x)
					var jitter := rng.randf_range(0.5, 1.0)
					if not inside(lot, r) or not clear_of(layout, lot):
						continue
					if layout.vacant_chance > 0.0 and vacancy.randf() < layout.vacant_chance:
						plan.vacant.append(lot)
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

## Superblocks never span more than this many blocks a side.
const MAX_MERGE := 3

static func _sorted(spans: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.assign(spans)
	out.sort_custom(func(a, b): return a.x < b.x)
	return out

## Story 26.3: drops grid street segments. Blocks are cells (column, row) in
## sorted order; each belongs to a group, a rectangle of cells (Rect2i, end
## exclusive) that becomes one block. In a fixed order, each segment between two
## junctions, with built blocks either side, is dropped by chance when the two
## groups it parts share a whole side (so the merged block stays a rectangle),
## the result is no more than MAX_MERGE a side, every street stays reachable from
## every other, and every clearing still touches a street. Returns {groups, of
## (cell -> group), dropped (rects)}.
static func _merge(layout: CityLayout, lines: Array[Vector2], spans: Array) -> Dictionary:
	var cells := _sorted(spans)
	var n := cells.size()
	var groups: Array[Rect2i] = []
	var of := {}
	for i in n:
		for j in n:
			of[Vector2i(i, j)] = groups.size()
			groups.append(Rect2i(i, j, 1, 1))
	var dropped: Array[Rect2] = []
	var out := {"groups": groups, "of": of, "dropped": dropped}
	if layout.drop_chance <= 0.0:
		return out
	# The line after cell k (between k and k + 1), or a zero span for none.
	var after: Array[Vector2] = []
	for k in n:
		var line := Vector2.ZERO
		for l in lines:
			if k + 1 < n and is_equal_approx(l.x, cells[k].y) and is_equal_approx(l.y, cells[k + 1].x):
				line = l
		after.append(line)
	var r := layout.core_radius
	var touched := _touching(layout, _runs(layout, lines, spans, of)[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed + 17
	# A segment: [axis the street runs along (0 z, 1 x), line index k, cell along].
	for ax in 2:
		for k in n - 1:
			for m in range(1, n - 1):
				if after[k] == Vector2.ZERO or after[m - 1] == Vector2.ZERO or after[m] == Vector2.ZERO:
					continue
				var a := Vector2i(k, m) if ax == 0 else Vector2i(m, k)
				var b := a + (Vector2i(1, 0) if ax == 0 else Vector2i(0, 1))
				if rng.randf() >= layout.drop_chance:
					continue
				var ga: int = of[a]
				var gb: int = of[b]
				var ra := groups[ga]
				var rb := groups[gb]
				if ga == gb or ra.position[1 - ax] != rb.position[1 - ax] or ra.size[1 - ax] != rb.size[1 - ax]:
					continue
				var u := ra.merge(rb)
				if u.size.x > MAX_MERGE or u.size.y > MAX_MERGE:
					continue
				var block := Rect2(cells[u.position.x].x, cells[u.position.y].x,
					cells[u.end.x - 1].y - cells[u.position.x].x, cells[u.end.y - 1].y - cells[u.position.y].x)
				if not inside(block, r):
					continue
				# The segments between the two groups, all along line k.
				var gone: Array[Rect2] = []
				for c in range(u.position[1 - ax], u.end[1 - ax]):
					var along := cells[c]
					var line := after[k]
					gone.append(Rect2(line.x, along.x, line.y - line.x, along.y - along.x) if ax == 0 \
						else Rect2(along.x, line.x, along.y - along.x, line.y - line.x))
				var trial := {}
				for key in of:
					trial[key] = gb if of[key] == ga else of[key]
				var streets: Array[Rect2] = _runs(layout, lines, spans, trial)[0]
				if not connected(streets) or _touching(layout, streets) < touched:
					continue
				for key in trial:
					of[key] = trial[key]
				groups[gb] = u
				dropped.append_array(gone)
	return out

## How many clearings touch at least one street.
static func _touching(layout: CityLayout, streets: Array[Rect2]) -> int:
	var n := 0
	for c in layout.clearings:
		if streets.any(func(s): return touches(c, s)):
			n += 1
	return n

## True when every street can be reached from every other through crossings.
static func connected(streets: Array[Rect2]) -> bool:
	if streets.is_empty():
		return true
	var seen := {0: true}
	var todo := [0]
	while not todo.is_empty():
		var i: int = todo.pop_back()
		for j in streets.size():
			if not seen.has(j) and streets[i].intersects(streets[j]):
				seen[j] = true
				todo.append(j)
	return seen.size() == streets.size()

## [streets, axes]: each grid line clipped to the core, cut where its segments
## were dropped. A junction stays in a line's run while either of the line's
## segments beside it is there; between two dropped ones it goes too.
static func _runs(layout: CityLayout, lines: Array[Vector2], spans: Array, of: Dictionary) -> Array:
	var cells := _sorted(spans)
	var n := cells.size()
	var r := layout.core_radius
	var streets: Array[Rect2] = []
	var axes := PackedInt32Array()
	for s in lines:
		var edge := maxf(absf(s.x), absf(s.y))
		var half := sqrt(r * r - edge * edge)
		# The cell before this line, if the line parts two cells.
		var k := -1
		for c in n - 1:
			if is_equal_approx(cells[c].y, s.x) and is_equal_approx(cells[c + 1].x, s.y):
				k = c
		for ax in 2:
			# Dropped spans along this line: cells whose two sides share a group.
			var gaps: Array[Vector2] = []
			if k >= 0:
				for m in n:
					var a := Vector2i(k, m) if ax == 0 else Vector2i(m, k)
					var b := a + (Vector2i(1, 0) if ax == 0 else Vector2i(0, 1))
					if of[a] == of[b]:
						if not gaps.is_empty() and m > 0 and is_equal_approx(gaps[-1].y, cells[m - 1].y):
							gaps[-1] = Vector2(gaps[-1].x, cells[m].y)
						else:
							gaps.append(cells[m])
			var at := -half
			for g in gaps + [Vector2(half, half)]:
				var lo := at
				var hi := minf(g.x, half)
				if hi > lo + 0.001:
					streets.append(Rect2(s.x, lo, s.y - s.x, hi - lo) if ax == 0 else Rect2(lo, s.x, hi - lo, s.y - s.x))
					axes.append(ax)
				at = maxf(at, g.y)
	return [streets, axes]

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
