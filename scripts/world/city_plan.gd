class_name CityPlan
extends RefCounted
# Turns a CityLayout into streets and lots: a grid of streets around a block on
# the origin, each block cut into lots set back from the kerb, and a height per lot
# that falls off from downtown to the edge. Pure data, no nodes. Deterministic
# per layout and cached, like DesertTerrain. Each lot also gets a shape (Story
# 15.6): stacked boxes and trims, from their own seeded stream so lots and
# heights are as before. Story 26.3: segments of the grid may be dropped, merging
# the blocks either side into superblocks, and some blocks left as paved squares,
# each from its own stream so chances of 0 build the plan as before. Story
# 26.4: the plan also gives the general form beside the rectangles: streets as
# centrelines with a width and a kind, junctions joining them, and blocks as
# polygons that the lots are cut from, so later patterns can run at any angle.
# Story 26.6: the DIAGONAL pattern lays the grid, then one or two avenues across
# it at a seeded angle, splitting the blocks they cross into wedges along their
# kerbs; a wedge's lots are trimmed to fit it, or left out. Story 26.7: the
# RADIAL pattern rings the spawn plaza with ring roads, drawn as short straight
# segments, crossed by spokes out from the plaza; blocks are the ring sectors
# between them, with lots trimmed to fit as in a wedge. Story 26.8: the
# OLD_TOWN pattern grows narrow winding lanes from a loop round the plaza by
# seeded random walks; blocks are whatever the lanes enclose.

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

## What a street is: an ordinary street or an avenue.
enum Kind { STREET, AVENUE }

## A street in the general form (Story 26.4): a polyline centreline, with a
## point at each end and at each junction along it, and its kerb-to-kerb width.
## The ground it covers is the centreline swept `width / 2` either side, cut
## square at its ends.
class Street extends RefCounted:
	var points := PackedVector2Array()
	var width := 0.0
	var kind: int = Kind.STREET

## Where streets meet (Story 26.4): the middle of the ground they share. Each
## of their centrelines has a point nearest it among its points; where two
## streets cross, that point is the junction itself (two edge streets clipped
## by the core can share only a corner, and there it is not). `streets` index
## `paths`.
class Junction extends RefCounted:
	var at := Vector2.ZERO
	var streets := PackedInt32Array()

static var _cache := {}

## The rect form below (streets, street_axis, blocks, dropped, squares) is the
## grid generator's own working data: its drops and connectivity are worked out
## on it. Since Story 26.5 nothing builds from it; Streets, StreetClutter and the
## rest read the general form (paths, junctions, block_polygons) and the lots.
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
## The general form (Story 26.4). One path per street, same order as streets;
## diagonal avenues (Story 26.6), which have no rect, come after them.
var paths: Array[Street] = []
## The diagonal avenues (Story 26.6): their indices in `paths`, and each one's
## angle in degrees from +x towards +z, same order.
var diagonals := PackedInt32Array()
var diagonal_angles := PackedFloat32Array()
## A radial city (Story 26.7): each spoke's index in `paths`, and each ring's
## segments in order round it (counterclockwise from +x toward +z), the
## plaza's ring first. The spokes all point out from the plaza's centre, the
## origin, and start where they meet the plaza ring.
var spokes := PackedInt32Array()
var rings: Array[PackedInt32Array] = []
## An old town (Story 26.8): each lane's legs in `paths`, in order along it,
## one straight path a leg: the plaza loop's first (round it, counterclockwise),
## then the through streets, then the lanes.
var lanes: Array[PackedInt32Array] = []
## Every place two or more paths meet.
var junctions: Array[Junction] = []
## Each block's outline, same order as blocks: a closed polygon (last point
## joins the first) wound like the rect's corners, position first. A wedge a
## diagonal avenue cut (Story 26.6) is wound the same way; its entry in
## `blocks` is its bounds.
var block_polygons: Array[PackedVector2Array] = []
## The block each lot (and each vacant lot) was cut from, indexing blocks.
var lot_block := PackedInt32Array()
var vacant_block := PackedInt32Array()
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
	if layout.pattern == CityLayout.Pattern.RADIAL or layout.pattern == CityLayout.Pattern.OLD_TOWN:
		if layout.pattern == CityLayout.Pattern.RADIAL:
			_radial(layout, plan, rng, vacancy)
		else:
			_old_town(layout, plan, rng, vacancy)
		var shaping := RandomNumberGenerator.new()
		shaping.seed = layout.seed + 3
		for i in plan.lots.size():
			plan.shapes.append(_shape(layout, shaping, plan.lots[i], plan.heights[i]))
		return plan
	var lines: Array[Vector2] = []
	for s: Vector2 in axis[0]:
		if maxf(absf(s.x), absf(s.y)) < r:
			lines.append(s)
	var grid := _merge(layout, lines, axis[1])
	plan.dropped = grid.dropped
	var runs := _runs(layout, lines, axis[1], grid.of)
	plan.streets = runs[0]
	plan.street_axis = runs[1]
	_paths(plan, axis[2])
	# Diagonal avenues (Story 26.6) and the strips they cut from the blocks.
	var cutters: Array[PackedVector2Array] = []
	if layout.pattern == CityLayout.Pattern.DIAGONAL:
		cutters = _diagonals(layout, plan)
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
			var square := layout.square_chance > 0.0 and inside(block, r) and squaring.randf() < layout.square_chance
			for outline in _wedges(polygon(block), cutters):
				var b := plan.blocks.size()
				plan.blocks.append(_bounds(outline))
				plan.block_polygons.append(outline)
				if square:
					plan.squares.append(_bounds(outline))
					continue
				_cut_lots(layout, plan, rng, vacancy, b, outline != polygon(block))
	var shape_rng := RandomNumberGenerator.new()
	shape_rng.seed = layout.seed + 3
	for i in plan.lots.size():
		plan.shapes.append(_shape(layout, shape_rng, plan.lots[i], plan.heights[i]))
	return plan

## Cuts block `b`'s lots: spans along its bounds, each kept only if it fits
## inside. A rectangle's bounds are the rectangle, so a grid cuts the lots it
## always did. In a wedge (Story 26.6) a lot must also keep the sidewalk from
## the avenue's kerb: one that does not is trimmed to fit, and left out if that
## leaves it narrower than lot_min either way.
static func _cut_lots(layout: CityLayout, plan: CityPlan, rng: RandomNumberGenerator, vacancy: RandomNumberGenerator,
		b: int, wedge: bool) -> void:
	var r := layout.core_radius
	var outline := plan.block_polygons[b]
	var inner := outline
	if wedge:
		var grown := Geometry2D.offset_polygon(outline, -layout.sidewalk, Geometry2D.JOIN_MITER)
		if grown.size() != 1:
			return
		inner = grown[0]
	var bounds := _bounds(outline)
	var sx := Vector2(bounds.position.x, bounds.end.x)
	var sz := Vector2(bounds.position.y, bounds.end.y)
	for cx in _split(layout, rng, sx):
		for cz in _split(layout, rng, sz):
			var lot := Rect2(cx.x, cz.x, cx.y - cx.x, cz.y - cz.x)
			var jitter := rng.randf_range(0.5, 1.0)
			if wedge:
				lot = _trimmed(lot, inner, layout.lot_min)
				if not lot.has_area():
					continue
			if not inside(lot, r) or not clear_of(layout, lot) or not fits(lot, outline):
				continue
			if layout.vacant_chance > 0.0 and vacancy.randf() < layout.vacant_chance:
				plan.vacant.append(lot)
				plan.vacant_block.append(b)
				continue
			var d := clampf(lot.get_center().length() / r, 0.0, 1.0)
			var t := pow(1.0 - d, layout.height_falloff) * jitter
			plan.lots.append(lot)
			plan.lot_block.append(b)
			plan.heights.append(lerpf(layout.height_min, layout.height_max, t))

## Story 26.6: `outline` less every strip in `cutters`, as the pieces left,
## each wound like a rect's polygon. Slivers under a square metre are dropped
## (sand between the kerbs). With no cutters, the outline itself.
static func _wedges(outline: PackedVector2Array, cutters: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [outline]
	for cutter in cutters:
		var next: Array[PackedVector2Array] = []
		for piece in pieces:
			if Geometry2D.intersect_polygons(piece, cutter).is_empty():
				next.append(piece)
				continue
			for part in Geometry2D.clip_polygons(piece, cutter):
				if area(part) < 0.0:
					part.reverse()
				if area(part) > 1.0:
					next.append(part)
		pieces = next
	return pieces

## `lot` trimmed on one side, as little as fits it inside `inner`, keeping both
## sides at least `least`; the trim that keeps the most area wins. An empty
## rect when none does.
static func _trimmed(lot: Rect2, inner: PackedVector2Array, least: float) -> Rect2:
	if lot.size.x < least - 0.001 or lot.size.y < least - 0.001:
		return Rect2()
	if fits(lot, inner):
		return lot
	var best := Rect2()
	for side in 4:
		var ax := side / 2
		var spare := lot.size[ax] - least
		if spare <= 0.0 or not fits(_shrunk(lot, side, spare), inner):
			continue
		# Shrinking a rect inside a convex outline keeps it inside: search for
		# the least trim that fits, to a quarter metre.
		var lo := 0.0
		var hi := spare
		while hi - lo > 0.25:
			var mid := (lo + hi) * 0.5
			if fits(_shrunk(lot, side, mid), inner):
				hi = mid
			else:
				lo = mid
		var trimmed := _shrunk(lot, side, hi)
		if trimmed.get_area() > best.get_area():
			best = trimmed
	return best

## `r` with `by` cut off side `side` (-x, +x, -z, +z).
static func _shrunk(r: Rect2, side: int, by: float) -> Rect2:
	var out := Rect2(r)
	var ax := side / 2
	out.size[ax] -= by
	if side % 2 == 0:
		out.position[ax] += by
	return out

## Spoke angles stray from even spacing by up to this share of the gap.
const SPOKE_JITTER := 0.15

## Story 26.7: a ring-and-spoke city. Spokes at seeded angles (their own
## stream, seed + 31: evenly spaced from a seeded start, each jittered) run from
## the plaza ring out to the core's edge; rings are concentric round the plaza,
## each a closed run of straight segments, one centred square across each spoke
## and the arcs between cut into segments of at most ring_step degrees. If a
## clearing would touch no street, the spokes turn together until the nearest
## one points at it. Blocks are the plaza inside the first ring and the sectors
## between rings and spokes, bounded by their kerbs; the band past the last ring
## runs on beyond the core, like a grid's edge blocks.
static func _radial(layout: CityLayout, plan: CityPlan, rng: RandomNumberGenerator, vacancy: RandomNumberGenerator) -> void:
	var spin := RandomNumberGenerator.new()
	spin.seed = layout.seed + 31
	var r := layout.core_radius
	var n := maxi(3, layout.spokes)
	var gap := TAU / n
	var start := spin.randf() * TAU
	var angles: Array[float] = []
	for i in n:
		angles.append(start + gap * (i + spin.randf_range(-SPOKE_JITTER, SPOKE_JITTER)))
	var radii: Array[float] = []
	var widths: Array[float] = []
	for k in maxi(1, layout.rings):
		var at := layout.hub_radius + layout.ring_spacing * k
		var w := layout.street_width if k == 0 else _width(layout, k)
		if k > 0 and at + w * 0.5 + layout.sidewalk * 2.0 > r:
			break
		radii.append(at)
		widths.append(w)
	var vertices := _radial_streets(layout, plan, angles, radii, widths)
	for c in layout.clearings:
		var at := Vector2(c.x, c.y)
		if at.length() < 0.01 or plan.paths.any(func(p): return _reaches(c, strip(p))):
			continue
		var turn := INF
		for a in angles:
			var d := angle_difference(a, at.angle())
			if absf(d) < absf(turn):
				turn = d
		for i in n:
			angles[i] += turn
		vertices = _radial_streets(layout, plan, angles, radii, widths)
		break
	# Each ring's kerbs, mitred at its corners: the inner one, then the outer.
	var kerbs := []
	for k in radii.size():
		kerbs.append([_offset(vertices[k], -widths[k] * 0.5), _offset(vertices[k], widths[k] * 0.5)])
	var beyond := PackedVector2Array()
	var steps := ceili(360.0 / layout.ring_step)
	for j in steps:
		beyond.append(Vector2.from_angle(TAU * j / steps) * (r + layout.ring_spacing))
	var outlines: Array[PackedVector2Array] = [kerbs[0][0]]
	var half := layout.street_width * 0.5
	for k in radii.size():
		var inner: PackedVector2Array = kerbs[k][1]
		var outer: PackedVector2Array = kerbs[k + 1][0] if k + 1 < radii.size() else beyond
		for i in n:
			var a := Vector2.from_angle(angles[i])
			var b := Vector2.from_angle(angles[(i + 1) % n])
			outlines.append(_sector(inner, outer, a.orthogonal() * -half, a, b.orthogonal() * half, b))
	var squaring := RandomNumberGenerator.new()
	squaring.seed = layout.seed + 19
	for outline in outlines:
		var b := plan.blocks.size()
		plan.blocks.append(_bounds(outline))
		plan.block_polygons.append(outline)
		var whole := Array(outline).all(func(q): return q.length() <= r)
		if layout.square_chance > 0.0 and whole and squaring.randf() < layout.square_chance:
			plan.squares.append(_bounds(outline))
			continue
		_cut_sector(layout, plan, rng, vacancy, b)

## Row depth past lot_min in a radial block (Story 26.7).
const ROW_SPARE := 1.0

## Cuts the lots of block `b`, an outline of any shape (Story 26.7), inside it
## stood in by the sidewalk: rows lot_min (and a little) deep across it, each
## cut into lots along the stretches the whole row fits inside. Rows run along
## z or along x, starting flush with the block's edge or half a row on,
## whichever of the four keeps the most ground; the odd corners left over are
## courtyards.
## An old town's block (Story 26.8) may stand in to more than one piece where
## it narrows; each piece is cut on its own, and its lots stand `tall` (least,
## most) high rather than height_min to height_max.
static func _cut_sector(layout: CityLayout, plan: CityPlan, rng: RandomNumberGenerator, vacancy: RandomNumberGenerator,
		b: int, tall := Vector2(-1.0, -1.0)) -> void:
	var r := layout.core_radius
	var outline := plan.block_polygons[b]
	var grown := Geometry2D.offset_polygon(outline, -layout.sidewalk, Geometry2D.JOIN_MITER)
	if grown.size() != 1 and layout.pattern != CityLayout.Pattern.OLD_TOWN:
		return
	var low := layout.height_min if tall.x < 0.0 else tall.x
	var high := layout.height_max if tall.x < 0.0 else tall.y
	var best: Array[Rect2] = []
	for inner: PackedVector2Array in grown:
		var mine: Array[Rect2] = []
		var most := 0.0
		for flip in [false, true]:
			for phase in [0.0, 0.5]:
				var kept: Array[Rect2] = []
				var ground := 0.0
				for lot in _fit_lots(layout, rng, inner, flip, phase):
					if not inside(lot, r) or not clear_of(layout, lot) or not fits(lot, inner) or not fits(lot, outline):
						continue
					kept.append(lot)
					ground += lot.get_area()
				if ground > most + 0.001:
					mine = kept
					most = ground
		best.append_array(mine)
	for lot in best:
		var jitter := rng.randf_range(0.5, 1.0)
		if layout.vacant_chance > 0.0 and vacancy.randf() < layout.vacant_chance:
			plan.vacant.append(lot)
			plan.vacant_block.append(b)
			continue
		var d := clampf(lot.get_center().length() / r, 0.0, 1.0)
		var t := pow(1.0 - d, layout.height_falloff) * jitter
		plan.lots.append(lot)
		plan.lot_block.append(b)
		plan.heights.append(lerpf(low, high, t))

## Lots across `poly` in rows along z (along x when `flip`), the first `phase`
## of a row in from its edge; each row is cut along the stretches its whole
## depth lies inside `poly` into a seeded count of equal lots, lot_min to
## lot_max wide, with lot_gap between.
static func _fit_lots(layout: CityLayout, rng: RandomNumberGenerator, poly: PackedVector2Array, flip: bool,
		phase: float) -> Array[Rect2]:
	var shape := poly
	if flip:
		shape = PackedVector2Array()
		for q in poly:
			shape.append(Vector2(q.y, q.x))
	var box := _bounds(shape)
	var g := layout.lot_gap
	var deep := layout.lot_min + ROW_SPARE
	var out: Array[Rect2] = []
	var z := box.position.y + (deep + g) * phase
	while z + deep <= box.end.y:
		for span in _spans(shape, z, z + deep):
			var length := span.y - span.x
			if length < layout.lot_min:
				continue
			# Where no count fits lots between lot_min and lot_max, the lots are
			# lot_max wide and the ground left over is a yard either side.
			var most := floori((length + g) / (layout.lot_min + g))
			var n := rng.randi_range(mini(most, ceili((length + g) / (layout.lot_max + g))), most)
			var wide := minf((length - g * (n - 1)) / n, layout.lot_max)
			var from := span.x + (length - wide * n - g * (n - 1)) * 0.5
			for k in n:
				var lot := Rect2(from + (wide + g) * k, z, wide, deep)
				out.append(Rect2(lot.position.y, lot.position.x, lot.size.y, lot.size.x) if flip else lot)
		z += deep + g
	return out

## The x spans over which the band of `poly` between z0 and z1 lies wholly
## inside it: the spans inside it at both edges of the band and just either
## side of each corner within it (between those its edges run straight).
static func _spans(poly: PackedVector2Array, z0: float, z1: float) -> Array[Vector2]:
	var heights := [z0 + 1e-4, z1 - 1e-4]
	for q in poly:
		if q.y > z0 and q.y < z1:
			heights.append(q.y - 1e-4)
			heights.append(q.y + 1e-4)
	var out: Array[Vector2] = [Vector2(-INF, INF)]
	for z: float in heights:
		var xs: Array[float] = []
		for i in poly.size():
			var p := poly[i]
			var q := poly[(i + 1) % poly.size()]
			if (p.y - z) * (q.y - z) < 0.0:
				xs.append(p.x + (q.x - p.x) * (z - p.y) / (q.y - p.y))
		xs.sort()
		var next: Array[Vector2] = []
		for o in out:
			for k in range(0, xs.size() - 1, 2):
				var lo := maxf(o.x, xs[k])
				var hi := minf(o.y, xs[k + 1])
				if hi > lo:
					next.append(Vector2(lo, hi))
		out = next
	return out

## Lays a radial city's streets for spokes at `angles` (radians) and rings at
## `radii` with `widths`, replacing any already laid: each ring's segments,
## then the spokes, with a junction wherever two meet. Returns each ring's
## centreline corners, counterclockwise.
static func _radial_streets(layout: CityLayout, plan: CityPlan, angles: Array[float], radii: Array[float],
		widths: Array[float]) -> Array[PackedVector2Array]:
	plan.paths.clear()
	plan.junctions.clear()
	plan.spokes = PackedInt32Array()
	plan.rings.clear()
	var n := angles.size()
	var ws := layout.street_width
	var step := deg_to_rad(layout.ring_step)
	var out: Array[PackedVector2Array] = []
	# Where each spoke crosses each ring: [ring, segment, point].
	var crossings := []
	for k in radii.size():
		var big := radii[k]
		var wr := widths[k]
		# The segment across a spoke reaches past its kerbs by the ring's half
		# width and more, so the corners either side stay clear of the crossing.
		var half := minf(asin(minf(0.95, (ws * 0.5 + wr * 0.5 + 1.5) / big)), TAU / n * 0.4)
		var corners: Array[float] = []
		var across := PackedInt32Array()
		for i in n:
			var a := angles[i]
			var b := angles[(i + 1) % n] + (TAU if i == n - 1 else 0.0)
			var from := a + minf(half, (b - a) * 0.4)
			var to := b - minf(half, (b - a) * 0.4)
			var m := maxi(1, ceili((to - from) / step - 0.001))
			for j in m:
				corners.append(from + (to - from) * j / m)
			# The next corner, `to`, starts the segment across spoke i + 1.
			corners.append(to)
			across.append(corners.size() - 1)
		var points := PackedVector2Array()
		for t in corners:
			points.append(Vector2.from_angle(t) * big)
		out.append(points)
		var ring := PackedInt32Array()
		var first := plan.paths.size()
		for j in points.size():
			var path := Street.new()
			path.width = wr
			path.kind = Kind.AVENUE if wr > ws else Kind.STREET
			path.points = PackedVector2Array([points[j], points[(j + 1) % points.size()]])
			ring.append(plan.paths.size())
			plan.paths.append(path)
		for j in points.size():
			var joint := Junction.new()
			joint.at = points[(j + 1) % points.size()]
			joint.streets = PackedInt32Array([first + j, first + (j + 1) % points.size()])
			plan.junctions.append(joint)
		plan.rings.append(ring)
		for i in n:
			var seg := first + across[i]
			var p := plan.paths[seg]
			crossings.append([k, (i + 1) % n, seg, (p.points[0] + p.points[1]) * 0.5])
	for i in n:
		var dir := Vector2.from_angle(angles[i])
		var path := Street.new()
		path.width = ws
		path.kind = Kind.STREET
		var hub := Vector2.ZERO
		for c in crossings:
			if c[0] == 0 and c[1] == i:
				hub = c[3]
		path.points = PackedVector2Array([hub, dir * layout.core_radius])
		plan.spokes.append(plan.paths.size())
		plan.paths.append(path)
		for c in crossings:
			if c[1] == i:
				var junction := Junction.new()
				junction.at = c[3]
				junction.streets = PackedInt32Array([c[2], plan.paths.size() - 1])
				plan.junctions.append(junction)
	_insert_points(plan)
	return out

## A closed counterclockwise polygon moved out by `by` (in, when negative)
## along its edges' normals, mitred at each corner.
static func _offset(poly: PackedVector2Array, by: float) -> PackedVector2Array:
	var count := poly.size()
	var out := PackedVector2Array()
	for i in count:
		var prev := (poly[i] - poly[(i - 1 + count) % count]).normalized()
		var next := (poly[(i + 1) % count] - poly[i]).normalized()
		var m0 := Vector2(prev.y, -prev.x)
		var m1 := Vector2(next.y, -next.x)
		out.append(poly[i] + (m0 + m1) * (by / (1.0 + m0.dot(m1))))
	return out

## The block between two closed convex counterclockwise outlines round the
## origin, `inner` inside `outer`, and between two kerb lines out from it: one
## through `a0` along `a`, the other, counterclockwise of it, through `b0` along
## `b`. Wound like a rect's polygon.
static func _sector(inner: PackedVector2Array, outer: PackedVector2Array, a0: Vector2, a: Vector2, b0: Vector2,
		b: Vector2) -> PackedVector2Array:
	var ia := _exit(inner, a0, a)
	var ib := _exit(inner, b0, b)
	var oa := _exit(outer, a0, a)
	var ob := _exit(outer, b0, b)
	var poly := PackedVector2Array([ia[0]])
	var j: int = (ia[1] + 1) % inner.size()
	while j != (ib[1] + 1) % inner.size():
		poly.append(inner[j])
		j = (j + 1) % inner.size()
	poly.append(ib[0])
	poly.append(ob[0])
	j = ob[1]
	while j != oa[1]:
		poly.append(outer[j])
		j = (j - 1 + outer.size()) % outer.size()
	poly.append(oa[0])
	var out := PackedVector2Array()
	for q in poly:
		if out.is_empty() or out[-1].distance_to(q) > 1e-4:
			out.append(q)
	if out[-1].distance_to(out[0]) <= 1e-4:
		out.remove_at(out.size() - 1)
	if area(out) < 0.0:
		out.reverse()
	return out

## [point, edge] where the ray from `from` (inside `poly`) along `dir` leaves
## the closed polygon `poly`; edge i runs from corner i to corner i + 1.
static func _exit(poly: PackedVector2Array, from: Vector2, dir: Vector2) -> Array:
	for i in poly.size():
		var hit = Geometry2D.segment_intersects_segment(from, from + dir * 10000.0, poly[i], poly[(i + 1) % poly.size()])
		if hit != null:
			return [hit, i]
	return [from, 0]

## True when the circle `c` (x, z, radius) reaches into the polygon.
static func _reaches(c: Vector3, poly: PackedVector2Array) -> bool:
	var at := Vector2(c.x, c.y)
	if Geometry2D.is_point_in_polygon(at, poly):
		return true
	for i in poly.size():
		if Geometry2D.get_closest_point_to_segment(at, poly[i], poly[(i + 1) % poly.size()]).distance_to(at) < c.z:
			return true
	return false

## Story 26.8: the plaza loop of an old town has this many corners.
const TOWN_CORNERS := 7
## An old town's edge blocks run this far past the core's edge.
const TOWN_BEYOND := 20.0
## Lanes that do not meet stay at least this far apart, kerb to kerb, even
## near the corners where they draw together (lane_gap everywhere else).
const TOWN_CLEAR := 1.5
## A lane meets another at no less than this many degrees.
const TOWN_MEET := 50.0
## A lane leaves the core's edge within this many degrees of straight out; a
## through street keeps within TOWN_OUT of straight out all along.
const TOWN_EXIT := 50.0
const TOWN_OUT := 35.0
## No old town has more legs than this.
const TOWN_LEGS := 700

## An old town while it grows (Story 26.8): each leg's ends and width, the legs
## near each cell of a coarse grid, and where other legs meet each one.
class _Town extends RefCounted:
	const CELL := 24.0
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	var w := PackedFloat32Array()
	var grid := {}
	## Per leg: [point, width] of each lane that starts or ends on it.
	var tees := []
	## [leg, next leg] where a lane bends; [stem, leg, point] where it meets one.
	var joints := []
	var stems := []

	func add(p: Vector2, q: Vector2, width: float) -> int:
		var i := a.size()
		a.append(p)
		b.append(q)
		w.append(width)
		tees.append([])
		for c in cells(p, q, width * 0.5):
			if not grid.has(c):
				grid[c] = []
			grid[c].append(i)
		return i

	## Takes back the last leg added and every meeting it made.
	func pop() -> void:
		var i := a.size() - 1
		for c in cells(a[i], b[i], w[i] * 0.5):
			grid[c].erase(i)
		joints = joints.filter(func(j): return j[0] != i and j[1] != i)
		for s in stems.filter(func(s): return s[0] == i):
			tees[s[1]] = tees[s[1]].filter(func(t): return t[0] != s[2])
		stems = stems.filter(func(s): return s[0] != i)
		a.resize(i)
		b.resize(i)
		w.resize(i)
		tees.resize(i)

	## Leg `stem` starts or ends at `at` on leg `leg`.
	func tee(stem: int, leg: int, at: Vector2) -> void:
		stems.append([stem, leg, at])
		tees[leg].append([at, w[stem]])

	func cells(p: Vector2, q: Vector2, by: float) -> Array[Vector2i]:
		var lo := p.min(q) - Vector2(by, by)
		var hi := p.max(q) + Vector2(by, by)
		var out: Array[Vector2i] = []
		for x in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
			for z in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
				out.append(Vector2i(x, z))
		return out

	## Every leg within about `by` of the segment from p to q.
	func near(p: Vector2, q: Vector2, by: float) -> PackedInt32Array:
		var seen := {}
		for c in cells(p, q, by):
			for i in grid.get(c, []):
				seen[i] = true
		var out := PackedInt32Array(seen.keys())
		out.sort()
		return out

## Story 26.8: a winding old town. A loop of streets round the spawn plaza
## (TOWN_CORNERS straight sides, each at least hub_radius out); through
## streets, street_width wide, winding out from it to the core's edge (the
## first aimed at a clearing the loop leaves untouched); then lanes, each a
## seeded random walk from a point on a street or lane already laid: legs of
## lane_length, bending up to lane_bend, branching by chance, ending in a
## T where they run into another lane or at the core's edge, or as a dead end
## where no leg fits. All from their own stream (seed + 37). Each leg is its
## own straight path; a bend is two legs' ends meeting (a joint) and a lane
## that meets another ends on its centreline (a T), so every crossing has a
## junction. Blocks are the ground the roads leave, the edge ones run on
## TOWN_BEYOND past the core like a grid's; lots are cut as in a radial block.
static func _old_town(layout: CityLayout, plan: CityPlan, rng: RandomNumberGenerator,
		vacancy: RandomNumberGenerator) -> void:
	var grow := RandomNumberGenerator.new()
	grow.seed = layout.seed + 37
	var r := layout.core_radius
	var ws := layout.street_width
	var t := _Town.new()
	# The plaza loop: each corner far enough out that the sides beside it pass
	# hub_radius out.
	var n := TOWN_CORNERS
	var spin := grow.randf() * TAU
	var angles: Array[float] = []
	for i in n:
		angles.append(spin + TAU * (i + grow.randf_range(-0.15, 0.15)) / n)
	var loop := PackedInt32Array()
	var corners := PackedVector2Array()
	for i in n:
		var before := angles[i] - angles[(i - 1 + n) % n] + (TAU if i == 0 else 0.0)
		var after := angles[(i + 1) % n] + (TAU if i == n - 1 else 0.0) - angles[i]
		var out := layout.hub_radius / cos(maxf(before, after) * 0.5) * grow.randf_range(1.0, 1.1)
		corners.append(Vector2.from_angle(angles[i]) * out)
	for i in n:
		loop.append(t.add(corners[i], corners[(i + 1) % n], ws))
	for i in n:
		t.joints.append([loop[i], loop[(i + 1) % n]])
	plan.lanes.append(loop)
	var queue := []
	# Through streets, evenly round from a seeded start, the first at a clearing
	# no street touches yet.
	var aims: Array[float] = []
	var turn := grow.randf() * TAU
	var count := maxi(1, layout.through_streets)
	for k in count:
		aims.append(turn + TAU * (k + grow.randf_range(-0.2, 0.2)) / count)
	for c in layout.clearings:
		var at := Vector2(c.x, c.y)
		if at.length() > 0.01 and not range(n).any(func(i): return _reaches(c, _leg_strip(t, i))):
			aims[0] = at.angle()
			break
	var bend := deg_to_rad(layout.lane_bend)
	for aim in aims:
		# The loop's side the aim crosses first, then the others nearest it: on
		# each, where the aim crosses it or, failing that, its middle.
		var sides := range(n)
		var mids: Array[float] = []
		for i in n:
			mids.append(absf(angle_difference(aim, ((t.a[loop[i]] + t.b[loop[i]]) * 0.5).angle())))
		sides.sort_custom(func(x, y): return mids[x] < mids[y] or (mids[x] == mids[y] and x < y))
		var laid := false
		for i: int in sides:
			var dir := Vector2.from_angle(aim)
			var hit = Geometry2D.segment_intersects_segment(Vector2.ZERO, dir * r, t.a[loop[i]], t.b[loop[i]])
			var from = null if hit == null else _tee_at(layout, t, loop[i], hit, ws, dir)
			if from == null:
				var mid := (t.a[loop[i]] + t.b[loop[i]]) * 0.5
				dir = mid.normalized()
				from = _tee_at(layout, t, loop[i], mid, ws, dir)
			if from == null:
				continue
			for attempt in 4:
				var lane := _walk(layout, t, grow, from, loop[i], dir, ws, true,
					maxf(deg_to_rad(2.0), bend * 0.5 * (1.0 - attempt / 3.0)), queue)
				if not lane.is_empty():
					plan.lanes.append(lane)
					laid = true
					break
			if laid:
				break
	# Lanes: out from each side of the loop, then from every branch queued.
	for i in n:
		queue.append([loop[i], -1.0])
	var head := 0
	while head < queue.size() and t.a.size() < TOWN_LEGS:
		var task: Array = queue[head]
		head += 1
		var leg: int = task[0]
		var u := (t.b[leg] - t.a[leg]).normalized()
		var w := clampf(snappedf(grow.randf_range(layout.lane_width.x, layout.lane_width.y), 0.5), layout.lane_width.x,
			layout.lane_width.y)
		for attempt in 6:
			var dir := u.rotated(task[1] * grow.randf_range(deg_to_rad(65.0), deg_to_rad(115.0)))
			var at := t.a[leg].lerp(t.b[leg], grow.randf_range(0.2, 0.8))
			var from = _tee_at(layout, t, leg, at, w, dir)
			if from == null:
				continue
			var lane := _walk(layout, t, grow, from, leg, dir, w, false, bend, queue)
			if not lane.is_empty():
				plan.lanes.append(lane)
				break
	# The streets, one path a leg, and their junctions.
	for i in t.a.size():
		var path := Street.new()
		path.width = t.w[i]
		path.kind = Kind.STREET
		path.points = PackedVector2Array([t.a[i], t.b[i]])
		plan.paths.append(path)
	for j in t.joints:
		var joint := Junction.new()
		joint.at = t.b[j[0]]
		joint.streets = PackedInt32Array([j[0], j[1]])
		plan.junctions.append(joint)
	for s in t.stems:
		var junction := Junction.new()
		junction.at = s[2]
		junction.streets = PackedInt32Array([s[1], s[0]])
		plan.junctions.append(junction)
	_insert_points(plan)
	for outline in _town_blocks(layout, t):
		plan.blocks.append(_bounds(outline))
		plan.block_polygons.append(outline)
	var squaring := RandomNumberGenerator.new()
	squaring.seed = layout.seed + 19
	var low := clampf(layout.old_town_height.x, layout.height_min, layout.height_max)
	var tall := Vector2(low, clampf(layout.old_town_height.y, low, layout.height_max))
	for b in plan.block_polygons.size():
		var outline := plan.block_polygons[b]
		var whole := Array(outline).all(func(q): return q.length() <= r)
		if layout.square_chance > 0.0 and whole and squaring.randf() < layout.square_chance:
			plan.squares.append(plan.blocks[b])
			continue
		_cut_sector(layout, plan, rng, vacancy, b, tall)

## The ground leg `i` of a growing old town covers.
static func _leg_strip(t: _Town, i: int) -> PackedVector2Array:
	var path := Street.new()
	path.points = PackedVector2Array([t.a[i], t.b[i]])
	path.width = t.w[i]
	return strip(path)

## Where a lane `w` wide heading `dir` may meet leg `leg` near `at`: on its
## centreline, at no less than TOWN_MEET to it, its square end inside the leg's
## kerbs, clear of the leg's ends and of every other lane on it. Null if not.
static func _tee_at(layout: CityLayout, t: _Town, leg: int, at: Vector2, w: float, dir: Vector2) -> Variant:
	var along := t.b[leg] - t.a[leg]
	var length := along.length()
	var u := along / length
	var s := (at - t.a[leg]).dot(u)
	var big := t.w[leg]
	if absf(u.cross(dir)) < sin(deg_to_rad(TOWN_MEET)) or w * 0.5 * absf(u.dot(dir)) > big * 0.5 - 0.5:
		return null
	# How far along the leg a lane's end reaches either side of its centreline.
	var foot := 0.5 / sin(deg_to_rad(TOWN_MEET))
	var keep := big * 0.5 + w * foot + 1.0
	if s < keep or s > length - keep:
		return null
	var p := t.a[leg] + u * s
	for other in t.tees[leg]:
		if (other[0] as Vector2).distance_to(p) < (w + other[1]) * foot + TOWN_CLEAR * 2.0:
			return null
	return p

## Walks one lane (a through street when `through`) from `from` on leg
## `parent` heading `dir`, `w` wide, each leg turning up to `bend` radians,
## queueing branches as it goes. Returns its legs; empty when it laid none,
## or for a through street that did not reach the core's edge (whose legs are
## taken back).
static func _walk(layout: CityLayout, t: _Town, grow: RandomNumberGenerator, from: Vector2, parent: int, dir: Vector2,
		w: float, through: bool, bend: float, queue: Array) -> PackedInt32Array:
	var made := PackedInt32Array()
	var pos := from
	var heading := dir
	var prev := parent
	var out_of := deg_to_rad(TOWN_OUT)
	var reached := false
	for step in 40:
		var found := {}
		var d := heading
		for attempt in 12:
			d = heading
			if step > 0 or attempt > 0:
				# Never straight on: a bend is a joint the road builder mitres.
				var turn := grow.randf_range(-bend, bend)
				d = heading.rotated(signf(turn + 1e-9) * maxf(absf(turn), deg_to_rad(1.0)))
			var away := pos.normalized()
			if through and absf(away.angle_to(d)) > out_of:
				d = away.rotated(signf(away.angle_to(d)) * out_of)
			elif not through and d.dot(away) < -0.3:
				continue
			if step == 0 and absf((t.b[parent] - t.a[parent]).normalized().cross(d)) < sin(deg_to_rad(TOWN_MEET)):
				continue
			found = _town_leg(layout, t, pos, d, grow.randf_range(layout.lane_length.x, layout.lane_length.y), w,
				prev, step == 0, through)
			if not found.is_empty():
				break
		if found.is_empty():
			break
		var i := t.add(pos, found.end, w)
		made.append(i)
		if step == 0:
			t.tee(i, parent, pos)
		else:
			t.joints.append([prev, i])
		if found.target >= 0:
			t.tee(i, found.target, found.end)
		prev = i
		pos = found.end
		heading = d
		if found.exit:
			reached = true
		if found.exit or found.target >= 0:
			break
		if through:
			queue.append([i, 1.0])
			queue.append([i, -1.0])
		else:
			for side in [1.0, -1.0]:
				if grow.randf() < layout.lane_branch:
					queue.append([i, side])
	if through and not reached:
		for k in made.size():
			t.pop()
		queue.assign(queue.filter(func(q): return q[0] < t.a.size()))
		return PackedInt32Array()
	return made

## The next leg of a lane `w` wide from `pos` along `d`, `length` long: cut
## short where it leaves the core (only near straight out) or runs into
## another leg (a T there, unless `through`), and kept only while it stays
## clear of every leg it does not meet: TOWN_CLEAR apart at least, lane_gap
## apart away from its ends. `prev` is the leg it carries on from or, when
## `first`, starts on. {end, exit, target} or empty.
static func _town_leg(layout: CityLayout, t: _Town, pos: Vector2, d: Vector2, length: float, w: float, prev: int,
		first: bool, through: bool) -> Dictionary:
	var r := layout.core_radius
	var end := pos + d * length
	var exit := false
	if end.length() > r:
		var f := Geometry2D.segment_intersects_circle(pos, end, Vector2.ZERO, r)
		if f < 0.0:

			return {}
		end = pos + d * length * f
		exit = true
		if d.dot(end.normalized()) < cos(deg_to_rad(TOWN_EXIT)):

			return {}
	var reach := w * 0.5 + layout.lane_gap + layout.street_width
	var target := -1
	var best := INF
	for e in t.near(pos, end, reach):
		if e == prev:
			continue
		var hit = Geometry2D.segment_intersects_segment(pos, end, t.a[e], t.b[e])
		if hit != null and pos.distance_to(hit) < best:
			best = pos.distance_to(hit)
			target = e
	if target >= 0:
		if through:

			return {}
		var at = _tee_at(layout, t, target, pos + d * best, w, d)
		if at == null:

			return {}
		end = at
		exit = false
	var long := pos.distance_to(end)
	var least := w + 2.0 + (t.w[prev] * 0.5 if first else 0.0) + (t.w[target] * 0.5 if target >= 0 else 0.0)
	if long < maxf(least, layout.lane_length.x * 0.5):

		return {}
	for e in t.near(pos, end, reach):
		if e == prev or e == target:
			continue
		var room := (w + t.w[e]) * 0.5
		var pair := Geometry2D.get_closest_points_between_segments(pos, end, t.a[e], t.b[e])
		var dist := pair[0].distance_to(pair[1])
		if dist < room + TOWN_CLEAR:

			return {}
		if dist >= room + layout.lane_gap:
			continue
		# The gap may close toward the leg's ends, as at a block's corner.
		var steps := ceili(long)
		for k in steps + 1:
			var s := long * k / steps
			var p := pos + d * s
			var need := room + minf(layout.lane_gap, TOWN_CLEAR + 0.6 * minf(s, long - s))
			if Geometry2D.get_closest_point_to_segment(p, t.a[e], t.b[e]).distance_to(p) < need - 1e-4:

				return {}
	return {"end": end, "exit": exit, "target": target}

## An old town's blocks: a disc TOWN_BEYOND past the core less every leg's
## ground, mitred at each bend, with the legs that leave the core run on past
## the disc. Legs are taken away outward from those, each touching ground
## already cut, so no cut leaves a hole. Each block wound counterclockwise.
static func _town_blocks(layout: CityLayout, t: _Town) -> Array[PackedVector2Array]:
	var r := layout.core_radius
	var far := r + TOWN_BEYOND
	var disc := PackedVector2Array()
	var steps := ceili(360.0 / layout.ring_step)
	for j in steps:
		disc.append(Vector2.from_angle(TAU * j / steps) * far)
	var next := []
	var bends := []
	for i in t.a.size():
		next.append([])
		bends.append([])
	for j in t.joints:
		next[j[0]].append(j[1])
		next[j[1]].append(j[0])
		bends[j[0]].append(j)
		bends[j[1]].append(j)
	for s in t.stems:
		next[s[0]].append(s[1])
		next[s[1]].append(s[0])
	var cutters: Array[PackedVector2Array] = []
	var cut := {}
	var done := {}
	var todo := []
	for i in t.a.size():
		if t.b[i].length() > r - 0.01:
			todo.append(i)
			done[i] = true
	var head := 0
	while head < todo.size():
		var i: int = todo[head]
		head += 1
		var path := Street.new()
		path.width = t.w[i]
		path.points = PackedVector2Array([t.a[i], t.b[i]])
		if t.b[i].length() > r - 0.01:
			path.points[1] = t.b[i] + (t.b[i] - t.a[i]).normalized() * (far - r + 10.0) * 2.0
		cutters.append(strip(path))
		cut[i] = true
		# A bend's mitre, once both its legs are cut.
		for j in bends[i]:
			if not cut.has(j[1] if j[0] == i else j[0]):
				continue
			var q := t.b[j[0]]
			var line := PackedVector2Array([q - (q - t.a[j[0]]).normalized(), q, q + (t.b[j[1]] - q).normalized()])
			cutters.append_array(Geometry2D.offset_polyline(line, t.w[i] * 0.5, Geometry2D.JOIN_MITER, Geometry2D.END_BUTT))
		for o in next[i]:
			if not done.has(o):
				done[o] = true
				todo.append(o)
	var pieces: Array[PackedVector2Array] = [disc]
	for cutter in cutters:
		var box := _bounds(cutter)
		var kept: Array[PackedVector2Array] = []
		for piece in pieces:
			if not _bounds(piece).intersects(box) or Geometry2D.intersect_polygons(piece, cutter).is_empty():
				kept.append(piece)
				continue
			for part in Geometry2D.clip_polygons(piece, cutter):
				if area(part) < 0.0:
					part.reverse()
				if area(part) > 1.0:
					kept.append(part)
		pieces = kept
	# No corner twice (an edge of no length has no direction to kerb along).
	var out: Array[PackedVector2Array] = []
	for piece in pieces:
		var clean := PackedVector2Array()
		for q in piece:
			if clean.is_empty() or clean[-1].distance_to(q) > 1e-3:
				clean.append(q)
		if clean.size() > 1 and clean[-1].distance_to(clean[0]) <= 1e-3:
			clean.remove_at(clean.size() - 1)
		out.append(clean)
	return out

## Story 26.6: lays the diagonal avenues as paths after the grid's, from their
## own stream (seed + 29): `diagonals` of them, the first at a seeded angle to
## the grid in either sense, the second the other way so the two cross; each
## passes within `diagonal_offset` of the centre and runs across the core from
## edge to edge. Near the edge a grid street's square end can stick partly into
## an avenue, which no road could cover cleanly; such an end is moved into the
## avenue, a T-junction, and each avenue runs on past the core's edge, if need
## be, until it has wholly crossed every grid street it meets, but never more
## than `diagonal_run_on` (a T that would need more is a dead end short of the
## avenue instead). The grid's junctions are then found again from the moved
## streets. Joins each avenue
## to every street it shares ground with. Returns the strips the avenues cut
## from the blocks, run on far past the core so no block is left notched.
static func _diagonals(layout: CityLayout, plan: CityPlan) -> Array[PackedVector2Array]:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed + 29
	var r := layout.core_radius
	var w := layout.avenue_width
	var grid := plan.paths.size()
	var count := rng.randi_range(layout.diagonals.x, layout.diagonals.y)
	var sense := 1.0 if rng.randf() < 0.5 else -1.0
	var cutters: Array[PackedVector2Array] = []
	var lines := []
	for k in count:
		var deg := clampf(snappedf(rng.randf_range(layout.diagonal_angle.x, layout.diagonal_angle.y), 0.5),
			layout.diagonal_angle.x, layout.diagonal_angle.y)
		deg *= sense * (1.0 if k % 2 == 0 else -1.0)
		var dir := Vector2.from_angle(deg_to_rad(deg))
		var across := dir.orthogonal()
		var off := snappedf(rng.randf_range(-layout.diagonal_offset, layout.diagonal_offset), 0.5)
		var mid := across * off
		var a := mid - dir * r * 3.0
		var e := mid + dir * r * 3.0
		var o := across * w * 0.5
		cutters.append(PackedVector2Array([a - o, e - o, e + o, a + o]))
		lines.append([deg, dir, mid, sqrt(r * r - off * off)])
	var reach := r + layout.diagonal_run_on
	var before := []
	for i in grid:
		before.append(plan.paths[i].points.duplicate())
	for i in grid:
		for k in count:
			_end_in(plan, i, grid, cutters[k], lines[k][1], lines[k][2], w, reach)
	# A moved end can part two grid streets that met there, or bring two
	# together: the grid's junctions are found again from the moved streets.
	for i in grid:
		if plan.paths[i].points != before[i]:
			_rejoin(plan, grid)
			break
	for k in count:
		var dir: Vector2 = lines[k][1]
		var mid: Vector2 = lines[k][2]
		var lo: float = -lines[k][3]
		var hi: float = lines[k][3]
		for i in grid:
			for part in Geometry2D.intersect_polygons(strip(plan.paths[i]), cutters[k]):
				for q in part:
					lo = minf(lo, (q - mid).dot(dir))
					hi = maxf(hi, (q - mid).dot(dir))
		var path := Street.new()
		path.width = w
		path.kind = Kind.AVENUE
		path.points = PackedVector2Array([mid + dir * lo, mid + dir * hi])
		plan.diagonals.append(plan.paths.size())
		plan.diagonal_angles.append(lines[k][0])
		plan.paths.append(path)
	for d in plan.diagonals:
		for i in plan.paths.size():
			if i != d and not (plan.diagonals.has(i) and i < d):
				_join(plan, d, i)
	_insert_points(plan)
	return cutters

## Story 26.6: the junctions of the first `grid` paths found again from their
## ground, as `_paths` finds them from the rects (each grid path is straight and
## axis-aligned, so its strip is its rect), and each path's points put back to
## its ends and its junctions.
static func _rejoin(plan: CityPlan, grid: int) -> void:
	plan.junctions.clear()
	var rects: Array[Rect2] = []
	for i in grid:
		var path := plan.paths[i]
		path.points = PackedVector2Array([path.points[0], path.points[-1]])
		rects.append(_bounds(strip(path)))
	for i in grid:
		for j in range(i + 1, grid):
			if not rects[i].intersects(rects[j]):
				continue
			var at := rects[i].intersection(rects[j]).get_center()
			var junction: Junction = null
			for k in plan.junctions:
				if k.at.distance_to(at) < 0.01:
					junction = k
			if junction == null:
				junction = Junction.new()
				junction.at = at
				plan.junctions.append(junction)
			for n in [i, j]:
				if not junction.streets.has(n):
					junction.streets.append(n)
	_insert_points(plan)

## Moves an end of grid path `i` whose square end sticks partly or wholly into
## the avenue `cutter` (centreline through `mid` along `dir`, `w` wide) to a
## T-junction inside it: past the near kerb across the street's whole width and
## short of the far one. Where the avenue would have to run on more than `reach`
## from `mid` to cross that T whole, the end is pulled back to just short of the
## near kerb instead (a dead end), so no road leaves the flat ground. An end
## inside another grid street (a T of the grid's own) is left as it is.
static func _end_in(plan: CityPlan, i: int, grid: int, cutter: PackedVector2Array, dir: Vector2, mid: Vector2, w: float,
		reach: float) -> void:
	var path := plan.paths[i]
	var across := dir.orthogonal()
	for last in [false, true]:
		var e := path.points[-1] if last else path.points[0]
		var u := (e - (path.points[0] if last else path.points[-1])).normalized()
		var o := u.orthogonal() * path.width * 0.5
		var sides := [e - o, e + o]
		var touched := Geometry2D.is_point_in_polygon(sides[0], cutter) or Geometry2D.is_point_in_polygon(sides[1], cutter)
		for c in 4:
			touched = touched or Geometry2D.segment_intersects_segment(sides[0], sides[1], cutter[c], cutter[(c + 1) % 4]) != null
		if not touched or absf(u.dot(across)) < 1e-6:
			continue
		var inside_grid := false
		for j in grid:
			if j != i and Geometry2D.is_point_in_polygon(sides[0], strip(plan.paths[j])) \
					and Geometry2D.is_point_in_polygon(sides[1], strip(plan.paths[j])):
				inside_grid = true
		if inside_grid:
			continue
		# Along u from the end, where each side of the street meets each kerb.
		var near := -INF
		var far := INF
		for q: Vector2 in sides:
			var t0 := (w * 0.5 - (q - mid).dot(across)) / u.dot(across)
			var t1 := (-w * 0.5 - (q - mid).dot(across)) / u.dot(across)
			near = maxf(near, minf(t0, t1))
			far = minf(far, maxf(t0, t1))
		if near >= far:
			continue
		var to := e + u * (near + far) * 0.5
		var start := path.points[-1] if not last else path.points[0]
		# A T the avenue would have to run on past `reach` to cross whole is
		# pulled back instead, to a dead end just short of the near kerb.
		if _reach(PackedVector2Array([start, to]), path.width, cutter, dir, mid) > reach:
			var enter := INF
			for q: Vector2 in sides:
				var t0 := (w * 0.5 - (q - mid).dot(across)) / u.dot(across)
				var t1 := (-w * 0.5 - (q - mid).dot(across)) / u.dot(across)
				enter = minf(enter, minf(t0, t1))
			var back := e + u * (enter - 0.05)
			if (back - start).dot(u) > path.width:
				to = back
		var kept := PackedVector2Array()
		var length := (to - start).length()
		for q in path.points:
			if q != e and (q - start).length() < length - 0.001:
				kept.append(q)
		if last:
			kept.append(to)
		else:
			kept.reverse()
			kept.append(to)
			kept.reverse()
		path.points = kept

## How far along `dir` from `mid` the ground a straight centreline `points`,
## `width` wide, shares with `cutter` reaches, either way; 0 when none.
static func _reach(points: PackedVector2Array, width: float, cutter: PackedVector2Array, dir: Vector2, mid: Vector2) -> float:
	var path := Street.new()
	path.points = points
	path.width = width
	var most := 0.0
	for part in Geometry2D.intersect_polygons(strip(path), cutter):
		for q in part:
			most = maxf(most, absf((q - mid).dot(dir)))
	return most

## The ground a straight path covers: its centreline swept half its width
## either side, cut square at its ends.
static func strip(path: Street) -> PackedVector2Array:
	var a := path.points[0]
	var e := path.points[path.points.size() - 1]
	var o := (e - a).normalized().orthogonal() * path.width * 0.5
	return PackedVector2Array([a - o, e - o, e + o, a + o])

## Adds a junction between paths `x` and `y` if they share ground: where their
## centrelines cross, or the middle of the ground they share when they do not.
## A junction already there (within a centimetre) takes them both.
static func _join(plan: CityPlan, x: int, y: int) -> void:
	var px := plan.paths[x]
	var py := plan.paths[y]
	var big := PackedVector2Array()
	for part in Geometry2D.intersect_polygons(strip(px), strip(py)):
		if absf(area(part)) > 0.01 and (big.is_empty() or absf(area(part)) > absf(area(big))):
			big = part
	if big.is_empty():
		return
	var at = Geometry2D.segment_intersects_segment(px.points[0], px.points[-1], py.points[0], py.points[-1])
	if at == null:
		at = _bounds(big).get_center()
	var junction: Junction = null
	for k in plan.junctions:
		if k.at.distance_to(at) < 0.01:
			junction = k
	if junction == null:
		junction = Junction.new()
		junction.at = at
		plan.junctions.append(junction)
	for n in [x, y]:
		if not junction.streets.has(n):
			junction.streets.append(n)

## A rect's outline as a polygon: position, then on round its corners.
static func polygon(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

## The axis-aligned bounds of a polygon.
static func _bounds(poly: PackedVector2Array) -> Rect2:
	var out := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		out = out.expand(p)
	return out

## True when `lot` lies inside the polygon `poly`: nothing of it is left once
## the polygon is clipped away.
static func fits(lot: Rect2, poly: PackedVector2Array) -> bool:
	for part in Geometry2D.clip_polygons(polygon(lot), poly):
		if absf(area(part)) > 0.01:
			return false
	return true

## A polygon's signed area (shoelace).
static func area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a * 0.5

## Story 26.4: the general form of the streets. Each street rect becomes a
## centreline down its middle, along its axis, with its width and kind (an
## avenue when its grid line is one of `avenues`). Wherever two street rects
## share ground a junction sits at the middle of that ground, and the point on
## each centreline nearest it joins that centreline's points, in order.
static func _paths(plan: CityPlan, avenues: Array) -> void:
	for i in plan.streets.size():
		var s := plan.streets[i]
		var ax := plan.street_axis[i]
		var path := Street.new()
		var c := s.get_center()
		path.width = s.size.x if ax == 0 else s.size.y
		var line := Vector2(s.position.x, s.end.x) if ax == 0 else Vector2(s.position.y, s.end.y)
		for a: Vector2 in avenues:
			if a.is_equal_approx(line):
				path.kind = Kind.AVENUE
		path.points = PackedVector2Array([Vector2(c.x, s.position.y), Vector2(c.x, s.end.y)]) if ax == 0 \
			else PackedVector2Array([Vector2(s.position.x, c.y), Vector2(s.end.x, c.y)])
		plan.paths.append(path)
	for i in plan.streets.size():
		for j in range(i + 1, plan.streets.size()):
			if not plan.streets[i].intersects(plan.streets[j]):
				continue
			var at := plan.streets[i].intersection(plan.streets[j]).get_center()
			var junction: Junction = null
			for k in plan.junctions:
				if k.at.distance_to(at) < 0.01:
					junction = k
			if junction == null:
				junction = Junction.new()
				junction.at = at
				plan.junctions.append(junction)
			for n in [i, j]:
				if not junction.streets.has(n):
					junction.streets.append(n)
	_insert_points(plan)

## Puts on each junction's streets the point of their (straight) centreline
## nearest it, in order along it, unless a point is already there.
static func _insert_points(plan: CityPlan) -> void:
	for junction in plan.junctions:
		for n in junction.streets:
			var path := plan.paths[n]
			var a := path.points[0]
			var e := path.points[path.points.size() - 1]
			var p := Geometry2D.get_closest_point_to_segment(junction.at, a, e)
			var t := (p - a).length()
			var k := 1
			while k < path.points.size() - 1 and (path.points[k] - a).length() < t:
				k += 1
			if p.distance_to(path.points[k]) > 0.001 and p.distance_to(path.points[k - 1]) > 0.001:
				path.points.insert(k, p)

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

## [streets, blocks, avenues] along one axis as (start, end) spans, mirrored
## about the origin; avenues are the streets that are avenues. A block sits on the centre, so the spawn plaza is a square, not a
## crossing; street k counts out from it and every avenue_every-th is an avenue.
static func _axis(layout: CityLayout) -> Array:
	var streets: Array[Vector2] = []
	var blocks: Array[Vector2] = []
	var avenues: Array[Vector2] = []
	var at := layout.block_size * 0.5
	blocks.append(Vector2(-at, at))
	var k := 1
	while at < layout.core_radius:
		var w := _width(layout, k)
		streets.append(Vector2(at, at + w))
		streets.append(Vector2(-at - w, -at))
		if layout.avenue_every > 0 and k % layout.avenue_every == 0:
			avenues.append(streets[-2])
			avenues.append(streets[-1])
		at += w
		blocks.append(Vector2(at, at + layout.block_size))
		blocks.append(Vector2(-at - layout.block_size, -at))
		at += layout.block_size
		k += 1
	return [streets, blocks, avenues]

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
