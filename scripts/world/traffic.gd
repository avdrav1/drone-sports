class_name Traffic
extends Node3D
# Story 26.11: cars on the streets. A lane graph read from the plan's road
# pieces (Streets.road_pieces) and the lanes StreetClutter keeps clear: one lane
# each way on a street, two each way on an avenue wide enough for them (one
# each way otherwise), and one-way on old-town lanes too narrow for two, each
# kept off its stretch's parking strips. Lanes join through every patch where
# streets meet, at any angle, through the mouth of each T, and round every
# bend; a way through is kept only where a car's centre stays on lane ground
# and its body on the road, clear of parked cars. Only the largest part of
# the graph every edge of which reaches every other carries traffic, so dead
# ends (and T mouths parked across) are left alone.
#
# Each car is an AnimatableBody3D with one box, moved along its lane every
# physics tick at a seeded cruising speed, so the physics engine pushes a drone
# it meets (rule 1: the car moves, the drone's own physics answers). Bodies are
# drawn through one MultiMesh with the parked-car model and tints.
#
# Cars keep a gap to the car ahead. Ways through junctions are cut into short
# guarded pieces, and each piece knows the pieces a car on it would come near
# (car footprints along both meeting). A car waits short of a junction until it
# is given its whole way through: given only when no way already held comes
# near it (or the car will be clear of it before the holder could get there),
# no car long held up there wants a way across it, and the lane past it has
# room for the car even once every car on that lane has stopped. Lanes too
# short to wait on between two junctions go with them. So cars never overlap
# and never stop inside a junction. A car held up picks another way on, and
# a city mostly junction (a diagonal avenue's wide crossings) takes fewer.
# Sits under a Streets node after its Clutter; the graph is cached per layout,
# like the other street generators. Placed and driven from the layout's seed,
# so the same seed puts the same cars in the same places at the same time.

## Bumper-to-bumper gap kept to the car ahead.
@export var gap := 1.5
## How far short of a junction a car waits for it.
@export var stop_gap := 3.5
## m/s² a car speeds up and slows down at.
@export var accel := 4.0
@export var decel := 6.0
## How far ahead a car looks for the car in front, in metres.
@export var lookahead := 30.0
## Clearance either side of a car in its lane.
@export var lane_margin := 0.25

## Ways through a junction are held and let go in pieces about this long.
const PIECE := 4.0
## Seconds a car waits at a junction before it picks another way through.
const REROUTE := 3.0
## Seconds a car held up by a crossing way, or by no room past the junction,
## waits before newcomers may no longer take a way across its own.
const CLASH_WAIT := 2.0
const ROOM_WAIT := 6.0
## Below this share of ordinary lane in its graph, a city takes fewer cars.
const LANE_SHARE := 0.6
## Past this many metres of junctions in a row a route heads for the way out.
const MAX_RUN := 20.0

## key -> Graph.
static var _cache := {}

## One stretch of lane: a polyline driven from its first point to its last.
## `zone` is the junction it crosses (-1 on an ordinary lane), `link` true on a
## lane too short for a car to wait on between two junctions, `next` the edges
## that carry on from its end, and `spawn` true where a car may start.
class Edge extends RefCounted:
	var points := PackedVector2Array()
	var cum := PackedFloat32Array()
	var length := 0.0
	var zone := -1
	var next := PackedInt32Array()
	var from := -1
	var to := -1
	var link := false
	var spawn := false
	## A way round a bend, where a car's corners may cross more kerb.
	var bend := false

	## True for an edge a car takes only once it holds it: one through a
	## junction, or a lane too short to wait on between two.
	func guarded() -> bool:
		return zone >= 0 or link

	func finish() -> void:
		cum.resize(points.size())
		cum[0] = 0.0
		for i in range(1, points.size()):
			cum[i] = cum[i - 1] + points[i].distance_to(points[i - 1])
		length = cum[points.size() - 1]

	## The point `s` along the edge, clamped to its ends.
	func at(s: float) -> Vector2:
		if s <= 0.0:
			return points[0]
		for i in range(1, points.size()):
			if s <= cum[i] or i == points.size() - 1:
				var span := cum[i] - cum[i - 1]
				return points[i - 1].lerp(points[i], clampf((s - cum[i - 1]) / span, 0.0, 1.0) if span > 0.0 else 1.0)
		return points[points.size() - 1]

## The lane graph of one layout: its edges, and for each guarded edge the
## guarded edges a car on it would come too near (itself included). `slots`
## are where cars may start, as [edge, distance along it].
class Graph extends RefCounted:
	var edges: Array[Edge] = []
	var conflicts := {}
	var slots: Array = []
	## For each edge, the metres from its start to the nearest ordinary lane.
	var exit := PackedFloat32Array()
	## For each guarded edge, the ordinary lanes somewhere along which a car
	## would come near a car on it.
	var near_lane := {}

## A car: the edges it is on and will drive next (the first holds its rear),
## its centre `pos` along them from the first edge's start, its speed, and the
## guarded edges it holds (`claim`).
class Car extends RefCounted:
	var path := PackedInt32Array()
	var pos := 0.0
	var speed := 0.0
	var cruise := 0.0
	var waited := 0.0
	var claim := PackedInt32Array()
	var tint := Color(1, 1, 1)
	var body: AnimatableBody3D
	## `waited` when it last chose another way through the junction ahead.
	var rerouted := 0.0

var streets: Streets
var clutter: StreetClutter
var plan: CityPlan
var layout: CityLayout
var graph: Graph
var cars: Array[Car] = []
## The car's footprint: width and length, from the parked-car model.
var car_size := Vector2.ZERO
var _mesh: Mesh
var _box: AABB
var _rng := RandomNumberGenerator.new()
var _multimesh: MultiMesh

func _ready() -> void:
	streets = get_parent() as Streets
	if streets == null:
		return
	if not streets.is_node_ready():
		await streets.ready
	build()

func build() -> void:
	clutter = streets.get_node("Clutter") as StreetClutter
	plan = streets.plan
	layout = streets.layout
	_mesh = clutter._mesh(StreetClutter.Kind.CAR)
	_box = _mesh.get_aabb()
	car_size = Vector2(_box.size.x, _box.size.z)
	var key := layout.params() + [clutter.park_width, clutter.car_gap, clutter.car_chance, gap, stop_gap, lane_margin,
		clutter.pieces.size(), car_size]
	if not _cache.has(key):
		_cache[key] = _generate()
	graph = _cache[key]
	_spawn()

## Frees the cars, so the node can build again from a new layout.
func clear() -> void:
	for c in get_children():
		if c.owner == null:
			remove_child(c)
			c.queue_free()
	cars.clear()
	graph = null

## Drops cached builds of every layout but `keep`.
static func prune(keep: CityLayout) -> void:
	keep.prune(_cache)

func _physics_process(delta: float) -> void:
	if graph == null:
		return
	step(delta)
	_place()

## The cars' world transforms, same order as `cars` (the car model's frame:
## +z is its front).
func transforms() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for c in cars:
		out.append(_pose(c))
	return out

## Each car's footprint in XZ, a quad, same order as `cars`.
func footprints() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for c in cars:
		var xf := _pose(c)
		out.append(_quad(Vector2(xf.origin.x, xf.origin.z), Vector2(xf.basis.z.x, xf.basis.z.z), 0.0))
	return out

## A car-sized quad centred on `at`, its length along `heading`, grown by `grow`.
func _quad(at: Vector2, heading: Vector2, grow: float) -> PackedVector2Array:
	var h := heading.normalized()
	var side := Vector2(-h.y, h.x)
	var c := at + h * (_box.get_center().z)
	var l := h * (car_size.y * 0.5 + grow)
	var w := side * (car_size.x * 0.5 + grow)
	return PackedVector2Array([c - l - w, c + l - w, c + l + w, c - l + w])

# --- Driving --------------------------------------------------------------------

## Moves every car on by `dt` seconds.
func step(dt: float) -> void:
	var edges := graph.edges
	var half := car_size.y * 0.5
	for c in cars:
		if c.claim.is_empty() and c.waited < c.rerouted:
			c.rerouted = 0.0
		if c.claim.is_empty() and c.waited - c.rerouted >= REROUTE:
			# Ways it should keep clear of: those held, and those wanted by
			# cars held up longer than it.
			var taken: Array[PackedInt32Array] = []
			for d in cars:
				if not d.claim.is_empty():
					taken.append(d.claim)
				elif d != c and d.waited > c.waited:
					var want := _guard_ahead(d)
					if not want.is_empty():
						taken.append(want[1])
			_reroute(c, taken)
		_extend(c)
	var occ := _occupancy()
	# Junctions: the longest waiting asks first. A way through is given when
	# it comes near no way already held, nor one a car long held up waits
	# for, and the lane after it has room for the whole car.
	var held: Array[PackedInt32Array] = []
	var holders: Array[int] = []
	for i in cars.size():
		if not cars[i].claim.is_empty():
			held.append(cars[i].claim)
			holders.append(i)
	var asks := []
	for i in cars.size():
		var c := cars[i]
		if not c.claim.is_empty():
			continue
		var ahead := _guard_ahead(c)
		if ahead.is_empty():
			continue
		if ahead[0] - (c.pos + half) <= stop_gap + c.speed * c.speed / (2.0 * decel) + 0.5:
			asks.append([c.waited, i, ahead[1]])
	asks.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var waiting: Array[PackedInt32Array] = []
	for ask in asks:
		var c := cars[ask[1]]
		var claim: PackedInt32Array = ask[2]
		# A car may follow one already crossing on its own route: the car
		# ahead holds the tail of what this one asks for.
		var leaders := {}
		for j in cars.size():
			if j != ask[1] and _tail_of(cars[j].claim, claim):
				leaders[j] = true
		if not _room_after(c, claim, occ, ask[1], leaders):
			# Long held up for room, it keeps its way through from being
			# crossed by newcomers too.
			if ask[0] > ROOM_WAIT:
				waiting.append(claim)
			continue
		var clash := false
		for h in held.size():
			if holders[h] != ask[1] and not _tail_of(held[h], claim) and _clash(claim, held[h]) \
					and (not leaders.is_empty() or not (_ordered(c, ask[1], claim, cars[holders[h]], holders[h], held[h], occ) \
						or _follows(c, claim, cars[holders[h]], holders[h], held[h], occ))):
				clash = true
				break
		for other in waiting:
			if clash:
				break
			clash = _clash(claim, other)
		if clash:
			if ask[0] > CLASH_WAIT:
				waiting.append(claim)
			continue
		c.claim = claim
		held.append(claim)
		holders.append(ask[1])
	for i in cars.size():
		var c := cars[i]
		var front := c.pos + half
		var off := 0.0
		for e in c.path:
			off += edges[e].length
		# Never past the end of the route it knows.
		var room := off - front
		off = 0.0
		for e in c.path:
			for v: Vector3 in occ.get(e, []):
				if int(v.z) != i and off + v.x >= front - 1e-3:
					room = minf(room, off + v.x - front - gap)
			if edges[e].guarded() and not c.claim.has(e) and off + 1e-3 >= c.pos - half:
				room = minf(room, off - front - stop_gap)
				break
			off += edges[e].length
			if off - front > lookahead:
				break
		room = maxf(room, 0.0)
		var v := minf(minf(c.speed + accel * dt, c.cruise), sqrt(2.0 * decel * room))
		var move := minf(v * dt, room)
		c.speed = move / dt if dt > 0.0 else 0.0
		c.pos += move
		c.waited = c.waited + dt if move < 1e-4 else 0.0
		# Edges held that the rear has left are let go.
		if not c.claim.is_empty():
			c.claim = _still_held(c.claim, c.path, edges, c.pos - half)
		while c.path.size() > 1 and c.pos - half > edges[c.path[0]].length:
			c.pos -= edges[c.path[0]].length
			c.path.remove_at(0)

## What is left of `claim` once a car on `path` has its rear `rear` metres
## along it: each held edge the rear has not yet left. A route through one
## edge twice holds it twice, and lets go of each in turn.
static func _still_held(claim: PackedInt32Array, path: PackedInt32Array, edges: Array[Edge], rear: float) -> PackedInt32Array:
	var keep := PackedInt32Array()
	var left := {}
	for e in claim:
		left[e] = left.get(e, 0) + 1
	var off := 0.0
	for e in path:
		off += edges[e].length
		if left.get(e, 0) > 0:
			left[e] -= 1
			if off >= rear:
				keep.append(e)
	return keep

## What each edge holds: edge -> [Vector3(from, to, car)], how far along it
## each car on it reaches.
func _occupancy() -> Dictionary:
	var edges := graph.edges
	var half := car_size.y * 0.5
	var occ := {}
	for i in cars.size():
		var c := cars[i]
		var off := 0.0
		for e in c.path:
			var lo := maxf(c.pos - half - off, 0.0)
			var hi := minf(c.pos + half - off, edges[e].length)
			if hi >= lo and c.pos + half > off:
				if not occ.has(e):
					occ[e] = []
				occ[e].append(Vector3(lo, hi, i))
			off += edges[e].length
			if off >= c.pos + half:
				break
	return occ

## True when `tail` is what is left of `claim` once its first edges are let go.
static func _tail_of(tail: PackedInt32Array, claim: PackedInt32Array) -> bool:
	if tail.is_empty() or tail.size() > claim.size():
		return false
	return claim.slice(claim.size() - tail.size()) == tail

## True when car `c` (index `i`, asking for `claim`) would be clear of every
## edge of it that comes near the way car `h` (index `j`) holds, `other`,
## a second before `h` could reach its own edge there at top speed. `c` is
## timed at its slowest: speeding up to its cruise, and stopping for the car
## ahead as if that car stood still, and for the next junction past its way.
## (Once given its way a car always gets through: the lane after it has room
## and no one else may enter it.)
func _ordered(c: Car, i: int, claim: PackedInt32Array, h: Car, j: int, other: PackedInt32Array, occ: Dictionary) -> bool:
	var mine := _timeline(c, i, claim, occ)
	var theirs := _timeline(h, j, other, occ)
	var half := car_size.y * 0.5
	for e in claim:
		var near: PackedInt32Array = graph.conflicts.get(e, PackedInt32Array([e]))
		for f in other:
			if not near.has(f):
				continue
			if not mine[0].has(e) or not theirs[0].has(f):
				return false
			var h_reach: float = theirs[0][f] - (h.pos + half)
			var c_clear := _time_to(mine[1][e] - (c.pos - half), c.speed, c.cruise, mine[2])
			if h_reach <= 0.0 or _time_to(h_reach, h.speed, h.cruise, INF) < c_clear + 1.0:
				return false
	return true

## True when car `h` (index `j`), holding `other`, timed at its slowest, will
## be wholly past every edge of it that comes near `claim` a second before
## car `c`, timed at its fastest, could reach its own edge there, and nowhere
## `h` may stop on the lane after its way comes near `claim`: `c` may then
## cross behind it.
func _follows(c: Car, claim: PackedInt32Array, h: Car, j: int, other: PackedInt32Array, occ: Dictionary) -> bool:
	var edges := graph.edges
	var half := car_size.y * 0.5
	# Where `h` may stand once through: the lane after its way, up to the
	# next junction.
	var k := h.path.find(other[other.size() - 1])
	if k < 0:
		return false
	var stand := {}
	k += 1
	while k < h.path.size() and not edges[h.path[k]].guarded():
		stand[h.path[k]] = true
		k += 1
	for e in claim:
		for l in graph.near_lane.get(e, PackedInt32Array()):
			if stand.has(l):
				return false
	var mine := _timeline(c, -1, claim, {})
	var theirs := _timeline(h, j, other, occ)
	for e in claim:
		var near: PackedInt32Array = graph.conflicts.get(e, PackedInt32Array([e]))
		for f in other:
			if not near.has(f):
				continue
			if not mine[0].has(e) or not theirs[1].has(f):
				return false
			var c_reach: float = mine[0][e] - (c.pos + half)
			var h_clear := _time_to(theirs[1][f] - (h.pos - half), h.speed, h.cruise, theirs[2])
			if c_reach <= 0.0 or _time_to(c_reach, c.speed, c.cruise, INF) < h_clear + 1.0:
				return false
	return true

## Car `c`'s route ahead as [start of each edge, end of each edge (both along
## its path), and how far its front can go before it must stop for the car
## ahead or the next junction past `claim`].
func _timeline(c: Car, i: int, claim: PackedInt32Array, occ: Dictionary) -> Array:
	var edges := graph.edges
	var front := c.pos + car_size.y * 0.5
	var starts := {}
	var ends := {}
	var off := 0.0
	var limit := INF
	for e in c.path:
		for v: Vector3 in occ.get(e, []):
			if int(v.z) != i and off + v.x >= front - 1e-3:
				limit = minf(limit, off + v.x - front - gap)
		if edges[e].guarded() and not claim.has(e) and off >= front:
			limit = minf(limit, off - front - stop_gap)
			break
		starts[e] = off
		off += edges[e].length
		ends[e] = off
	return [starts, ends, maxf(limit, 0.0)]

## Seconds to drive `d` metres from speed `v0`, speeding up to `top` and
## slowing to stop `limit` metres on.
func _time_to(d: float, v0: float, top: float, limit: float) -> float:
	const STEPS := 24
	var t := 0.0
	for k in STEPS:
		var x := d * (k + 0.5) / STEPS
		var v := minf(minf(top, sqrt(v0 * v0 + 2.0 * accel * x)), sqrt(2.0 * decel * maxf(limit - x, 0.0)))
		if v < 0.05:
			return INF
		t += d / STEPS / v
	return t

## True when two claims come near each other.
func _clash(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	for e in a:
		var near: PackedInt32Array = graph.conflicts.get(e, PackedInt32Array([e]))
		for f in b:
			if near.has(f):
				return true
	return false

## The first junction ahead of car `c`: [distance of its entry from the path's
## start, the guarded edges its route takes through it (on through any
## junction too near the first to wait between)]; empty if none in sight.
func _guard_ahead(c: Car) -> Array:
	var edges := graph.edges
	var off := 0.0
	var half := car_size.y * 0.5
	for k in c.path.size():
		var e := c.path[k]
		if edges[e].guarded() and not c.claim.has(e) and off + 1e-3 >= c.pos - half:
			var claim := PackedInt32Array()
			var m := k
			while m < c.path.size() and edges[c.path[m]].guarded() and not c.claim.has(c.path[m]):
				claim.append(c.path[m])
				m += 1
			return [off, claim]
		off += edges[e].length
		if off - c.pos > lookahead + half:
			break
	return []

## True when the lane after `claim` on car `i`'s path has room for it and for
## the `leaders` crossing ahead of it on the same route, even once every car
## already on that lane has stopped to wait at the junction after it.
func _room_after(c: Car, claim: PackedInt32Array, occ: Dictionary, i: int, leaders := {}) -> bool:
	var edges := graph.edges
	var off := 0.0
	var k := 0
	while k < c.path.size() and c.path[k] != claim[claim.size() - 1]:
		off += edges[c.path[k]].length
		k += 1
	if k >= c.path.size():
		return false
	off += edges[c.path[k]].length
	var exit := off
	var slot := car_size.y + gap
	var queued := {}
	var free_to := INF
	k += 1
	while k < c.path.size():
		var e := c.path[k]
		if edges[e].guarded():
			free_to = off - stop_gap
			break
		for v: Vector3 in occ.get(e, []):
			var j := int(v.z)
			if j != i and not leaders.has(j):
				queued[j] = true
				# The car nearest the exit must not already be in the way.
				if off + v.x - exit < slot * (leaders.size() + 1):
					return false
		off += edges[e].length
		k += 1
	if is_inf(free_to):
		free_to = off
	return free_to - exit - slot * queued.size() >= slot * (leaders.size() + 1)

## Makes sure car `c` knows its route far enough ahead: past its look-ahead,
## through any junction in it, and a car's length and gap beyond.
func _extend(c: Car) -> void:
	var edges := graph.edges
	var total := 0.0
	for e in c.path:
		total += edges[e].length
	# How far the route has run through guarded edges so far, and along
	# ordinary lane since the last of them.
	var run := 0.0
	var open := 0.0
	for e in c.path:
		run = run + edges[e].length if edges[e].guarded() else 0.0
		open = 0.0 if edges[e].guarded() else open + edges[e].length
	while c.path.size() < 64:
		var last := edges[c.path[c.path.size() - 1]]
		if not last.guarded() and total - c.pos > lookahead + car_size.y * 2.0 + gap \
				and open > (car_size.y + gap) * 3.0 + stop_gap:
			break
		if last.next.is_empty():
			break
		# Never back onto an edge the route already takes (a held edge must
		# be the one place the car will be on it), unless there is no other.
		var fresh: Array[int] = []
		for f in last.next:
			if not c.path.has(f):
				fresh.append(f)
		var pick: int = fresh[_rng.randi() % fresh.size()] if not fresh.is_empty() \
			else last.next[_rng.randi() % last.next.size()]
		# A route that has run long through junctions takes the shortest way
		# out, so it never circles inside a ring of them.
		if run > MAX_RUN:
			for f in (fresh if not fresh.is_empty() else Array(last.next)):
				if graph.exit[f] < graph.exit[pick]:
					pick = f
		c.path.append(pick)
		total += edges[pick].length
		run = run + edges[pick].length if edges[pick].guarded() else 0.0
		open = 0.0 if edges[pick].guarded() else open + edges[pick].length

## Car `c`, held up at the junction ahead, picks another way on from the end
## of its lane (a different one, when there is one), and its route on from it:
## one whose way through comes near none of `taken`, when there is one.
func _reroute(c: Car, taken: Array[PackedInt32Array] = []) -> void:
	c.rerouted = c.waited
	var edges := graph.edges
	var off := 0.0
	var half := car_size.y * 0.5
	for k in range(1, c.path.size()):
		off += edges[c.path[k - 1]].length
		if edges[c.path[k]].guarded() and off + 1e-3 >= c.pos - half:
			var from := edges[c.path[k - 1]]
			var was := c.path[k]
			if from.next.size() < 2:
				return
			var base := c.path.slice(0, k)
			var options: Array[int] = []
			for f in from.next:
				if f != was:
					options.append(f)
			for m in range(options.size() - 1, 0, -1):
				var n := _rng.randi_range(0, m)
				var t := options[m]
				options[m] = options[n]
				options[n] = t
			for f in options:
				c.path = base.duplicate()
				c.path.append(f)
				_extend(c)
				var ahead := _guard_ahead(c)
				if ahead.is_empty() or not taken.any(func(other): return _clash(ahead[1], other)):
					return
			c.path = base
			c.path.append(options[0])
			return

## The point `s` along car `c`'s path.
func _point(c: Car, s: float) -> Vector2:
	var edges := graph.edges
	var off := 0.0
	for e in c.path:
		if s <= off + edges[e].length:
			return edges[e].at(s - off)
		off += edges[e].length
	var last := edges[c.path[c.path.size() - 1]]
	return last.at(last.length)

## Car `c`'s transform: its centre on its lane, facing from its rear wheels to
## its front ones.
func _pose(c: Car) -> Transform3D:
	var at := _point(c, c.pos)
	var axle := car_size.y * 0.3
	var dir := _point(c, c.pos + axle) - _point(c, c.pos - axle)
	if dir.length_squared() < 1e-8:
		dir = Vector2(0, 1)
	var d3 := Vector3(dir.x, 0.0, dir.y).normalized()
	var basis := Basis.looking_at(-d3, Vector3.UP)
	return Transform3D(basis, Vector3(at.x, Streets.ROAD_Y, at.y) - d3 * _box.get_center().z)

func _place() -> void:
	for i in cars.size():
		var xf := _pose(cars[i])
		cars[i].body.transform = xf
		_multimesh.set_instance_transform(i, xf)

# --- Building ---------------------------------------------------------------

func _spawn() -> void:
	cars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed + 61
	_rng.seed = layout.seed + 67
	var slots := graph.slots.duplicate()
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = slots[i]
		slots[i] = slots[j]
		slots[j] = t
	var tints := clutter.car_tints
	for k in mini(count(), slots.size()):
		var c := Car.new()
		c.path = PackedInt32Array([slots[k][0]])
		c.pos = slots[k][1]
		c.cruise = rng.randf_range(layout.car_speed.x, layout.car_speed.y)
		c.speed = c.cruise * 0.5
		c.tint = tints[rng.randi() % tints.size()]
		cars.append(c)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = _mesh
	_multimesh.instance_count = cars.size()
	var mm := MultiMeshInstance3D.new()
	mm.name = "Cars"
	mm.multimesh = _multimesh
	add_child(mm)
	var shape := BoxShape3D.new()
	shape.size = _box.size
	for i in cars.size():
		var body := AnimatableBody3D.new()
		body.name = "Car%d" % i
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = _box.get_center()
		body.add_child(cs)
		cars[i].body = body
		_multimesh.set_instance_color(i, cars[i].tint)
		add_child(body)
	for c in cars:
		_extend(c)
	_place()

## How many cars this city takes: the layout's `car_count`, fewer where much
## of the way is through junctions (a diagonal avenue's wide crossings), where
## cars spend their time waiting their turn: in proportion to the share of the
## graph that is ordinary lane, below LANE_SHARE of it, down to half.
func count() -> int:
	var lane := 0.0
	var all := 0.0
	for ed in graph.edges:
		all += ed.length
		if not ed.guarded():
			lane += ed.length
	var share := lane / all if all > 0.0 else 1.0
	return roundi(layout.car_count * clampf(share / LANE_SHARE, 0.5, 1.0))

## A stretch's lanes: [across offset, travel sign along d, rank from the
## centre out within its direction, nodes as [along, node] in travel order].
class _Lane extends RefCounted:
	var stretch := -1
	var v := 0.0
	var sign := 1
	var rank := 0
	var nodes: Array = []

	func node_at(along: float) -> int:
		for n in nodes:
			if absf(n[0] - along) < 0.06:
				return n[1]
		return -1

func _generate() -> Graph:
	var g := Graph.new()
	var road := Streets.road_pieces(plan, layout)
	var room := car_size.x + lane_margin * 2.0
	var park := clutter.park_width
	var stretches: Array[int] = []
	var index := {}
	for i in road.size():
		if road[i].kind != 2:
			index[i] = stretches.size()
			stretches.append(i)
	# Each stretch's lane ground across it, clear of its parking strips.
	var regions: Array[Vector2] = []
	for i in stretches:
		var piece: Streets.Piece = road[i]
		var span := piece.span()
		var lo := span.position.y
		var hi := span.end.y
		for strip in clutter.parking:
			if not Streets.bounds(strip).intersects(piece.bounds()):
				continue
			var r := StreetClutter._local_bounds(piece, strip)
			if span.grow(0.05).encloses(r):
				if r.get_center().y > piece.c:
					hi = minf(hi, r.position.y)
				else:
					lo = maxf(lo, r.end.y)
		regions.append(Vector2(lo, hi))
	# Lanes each way on each path: 2 on an avenue that has room, else 1, and
	# 0 (one-way) on a street too narrow for two.
	var each := {}
	for i in stretches:
		var piece: Streets.Piece = road[i]
		if each.has(piece.street):
			continue
		var w := plan.paths[piece.street].width
		var avail := w - park * (2.0 if piece.kind == 1 else 1.0)
		if piece.kind == 1 and avail >= room * 4.0:
			each[piece.street] = 2
		elif avail >= room * 2.0:
			each[piece.street] = 1
		elif avail >= room:
			each[piece.street] = 0
		else:
			each[piece.street] = -1
	# What each stretch end meets: [0, patch] a patch, [1, stretch] another
	# stretch's side or end, [-1] nothing.
	var ends := []
	for si in stretches.size():
		var piece: Streets.Piece = road[stretches[si]]
		var pair := []
		for e in 2:
			var a := piece.a1 if e == 1 else piece.a0
			var q := piece.world(Vector2(a + (0.05 if e == 1 else -0.05), piece.c))
			var meet := [-1]
			for j in road.size():
				if j != stretches[si] and road[j].bounds().grow(0.01).has_point(q) and road[j].has_point(q):
					meet = [0, j] if road[j].kind == 2 else [1, index[j]]
					if road[j].kind == 2:
						break
			pair.append(meet)
		ends.append(pair)
	# Which stretch ends touch each patch.
	var touching := {}
	for si in stretches.size():
		for e in 2:
			if ends[si][e][0] == 0:
				if not touching.has(ends[si][e][1]):
					touching[ends[si][e][1]] = []
				touching[ends[si][e][1]].append([si, e])
	# A patch only one end touches is the corner of a T: the street it leads
	# to runs on uncut past it, so the end meets that street's side.
	for p in touching.keys():
		if touching[p].size() != 1:
			continue
		var si: int = touching[p][0][0]
		var e: int = touching[p][0][1]
		var A: Streets.Piece = road[stretches[si]]
		var tip := A.world(Vector2(A.a1 if e == 1 else A.a0, A.c))
		var out := A.d * (1.0 if e == 1 else -1.0)
		var t := 0.3
		while t < A.width and ends[si][e][0] == 0:
			var q := tip + out * t
			for j in road.size():
				if road[j].kind != 2 and j != stretches[si] and road[j].has_point(q):
					ends[si][e] = [1, index[j]]
					break
			t += 0.3
		if ends[si][e][0] == 1:
			touching.erase(p)
	# One-way stretches drive the same way along a street, through a bend or a
	# crossing, and on into the next leg of an old-town lane.
	var leg_of := {}
	for li in plan.lanes.size():
		for k in plan.lanes[li].size():
			leg_of[plan.lanes[li][k]] = Vector2i(li, k)
	var travel := {}
	var links := {}
	var link := func(a: Array, b: Array) -> void:
		for x in [[a, b], [b, a]]:
			if not links.has(x[0][0]):
				links[x[0][0]] = []
			links[x[0][0]].append([x[0][1], x[1][0], x[1][1]])
	for p in touching:
		var at: Array = touching[p]
		for x in at.size():
			for y in range(x + 1, at.size()):
				var A: Streets.Piece = road[stretches[at[x][0]]]
				var B: Streets.Piece = road[stretches[at[y][0]]]
				if each[A.street] != 0 or each[B.street] != 0:
					continue
				var same: bool = A.street == B.street or (leg_of.has(A.street) and leg_of.has(B.street)
					and leg_of[A.street].x == leg_of[B.street].x and absi(leg_of[A.street].y - leg_of[B.street].y) == 1)
				if (road[p].joint and at.size() == 2) or (same and absf(A.d.dot(B.d)) > 0.99) or (same and road[p].joint):
					link.call(at[x], at[y])
	for si in stretches.size():
		for e in 2:
			if ends[si][e][0] == 1:
				var sj: int = ends[si][e][1]
				var A: Streets.Piece = road[stretches[si]]
				var B: Streets.Piece = road[stretches[sj]]
				if absf(A.d.dot(B.d)) > 0.99 and each[A.street] == 0 and each[B.street] == 0:
					var tip := A.world(Vector2(A.a1 if e == 1 else A.a0, A.c))
					var eb := 0 if absf(B.local(tip).x - B.a0) < absf(B.local(tip).x - B.a1) else 1
					link.call([si, e], [sj, eb])
	var one := RandomNumberGenerator.new()
	one.seed = layout.seed + 59
	for si in stretches.size():
		if each[road[stretches[si]].street] != 0 or travel.has(si):
			continue
		travel[si] = 1 if one.randf() < 0.5 else -1
		var queue := [si]
		while not queue.is_empty():
			var a: int = queue.pop_front()
			for l in links.get(a, []):
				if travel.has(l[1]):
					continue
				# Into the meeting at end l[0] means out of it at end l[2].
				var into: bool = (travel[a] > 0) == (l[0] == 1)
				travel[l[1]] = 1 if (not into) == (l[2] == 1) else -1
				queue.append(l[1])
	# Lanes and their nodes.
	var node_pos: Array[Vector2] = []
	var node_dir: Array[Vector2] = []
	var lanes: Array = []
	var lanes_of := []
	for si in stretches.size():
		var piece: Streets.Piece = road[stretches[si]]
		var mine := []
		var n_each: int = each[piece.street]
		var reg := regions[si]
		var count := n_each * 2 if n_each > 0 else (1 if n_each == 0 else 0)
		if reg.y - reg.x < room * count - 1e-3:
			count = 0
		# The lanes, a lane's room apart, as near the street's middle as the
		# parking leaves them, so they shift as little as may be from one
		# stretch to the next.
		var mid := clampf(piece.c, reg.x + room * count * 0.5, reg.y - room * count * 0.5)
		for k in count:
			var L := _Lane.new()
			L.stretch = si
			L.v = mid + (k + 0.5 - count * 0.5) * room
			if count == 1:
				L.sign = travel.get(si, 1)
				L.rank = 0
			else:
				L.sign = int(piece.lane()) if L.v > mid else -int(piece.lane())
				L.rank = int(absf(L.v - mid) / room)
			mine.append(L)
			lanes.append(L)
		lanes_of.append(mine)
	# T mouths: where a stretch ends on another's side, that stretch's lanes are
	# a junction over the width the end takes, and a little either side.
	var zones := 0
	var mouths := {}
	for si in stretches.size():
		for e in 2:
			if ends[si][e][0] != 1:
				continue
			var sj: int = ends[si][e][1]
			var A: Streets.Piece = road[stretches[si]]
			var B: Streets.Piece = road[stretches[sj]]
			if absf(A.d.dot(B.d)) > 0.99:
				continue
			var tip := A.world(Vector2(A.a1 if e == 1 else A.a0, A.c))
			var u := B.local(tip).x
			var sin_t := maxf(absf(A.d.cross(B.d)), 0.3)
			var reach := A.width * 0.5 / sin_t + 1.5
			var m := Vector2(maxf(u - reach, B.a0), minf(u + reach, B.a1))
			if m.x < B.a0 + 0.05:
				m.x = B.a0
			if m.y > B.a1 - 0.05:
				m.y = B.a1
			if not mouths.has(sj):
				mouths[sj] = []
			mouths[sj].append([m, zones, si, e])
			zones += 1
	for L: _Lane in lanes:
		var piece: Streets.Piece = road[stretches[L.stretch]]
		var cuts := [piece.a0, piece.a1]
		for mo in mouths.get(L.stretch, []):
			for a in [mo[0].x, mo[0].y]:
				if not cuts.any(func(x): return absf(x - a) < 0.06):
					cuts.append(a)
		cuts.sort()
		if L.sign < 0:
			cuts.reverse()
		for a in cuts:
			L.nodes.append([a, node_pos.size()])
			node_pos.append(piece.world(Vector2(a, L.v)))
			node_dir.append(piece.d * L.sign)
	var make := func(points: PackedVector2Array, from: int, to: int, zone: int) -> Edge:
		var ed := Edge.new()
		ed.points = points
		ed.from = from
		ed.to = to
		ed.zone = zone
		ed.finish()
		return ed
	var edges: Array[Edge] = []
	for L: _Lane in lanes:
		for k in L.nodes.size() - 1:
			var a: float = L.nodes[k][0]
			var b: float = L.nodes[k + 1][0]
			var zone := -1
			for mo in mouths.get(L.stretch, []):
				if minf(a, b) >= mo[0].x - 0.06 and maxf(a, b) <= mo[0].y + 0.06:
					zone = mo[1]
			var ed: Edge = make.call(PackedVector2Array([node_pos[L.nodes[k][1]], node_pos[L.nodes[k + 1][1]]]),
				L.nodes[k][1], L.nodes[k + 1][1], zone)
			ed.spawn = zone < 0
			edges.append(ed)
	# A lane's node at stretch end `e`: where it ends (into) or starts (out).
	var end_node := func(L: _Lane, e: int) -> int:
		var piece: Streets.Piece = road[stretches[L.stretch]]
		return L.node_at(piece.a1 if e == 1 else piece.a0)
	var heading_in := func(L: _Lane, e: int) -> bool:
		return (L.sign > 0) == (e == 1)
	var curve := func(from: int, to: int, zone: int) -> Edge:
		if from < 0 or to < 0:
			return null
		var p0 := node_pos[from]
		var p1 := node_pos[to]
		var h := p0.distance_to(p1) * 0.4
		var c0 := p0 + node_dir[from] * h
		var c1 := p1 - node_dir[to] * h
		var pts := PackedVector2Array()
		var n := maxi(4, ceili(p0.distance_to(p1) / 0.75))
		for k in n + 1:
			var t := float(k) / n
			var s := 1.0 - t
			pts.append(p0 * s * s * s + c0 * 3.0 * s * s * t + c1 * 3.0 * s * t * t + p1 * t * t * t)
		return make.call(pts, from, to, zone)
	var connectors := []
	for p in touching:
		var at: Array = touching[p]
		var flow := false
		if road[p].joint and at.size() == 2:
			# A bend: lanes carry on, rank to rank, when both sides have as
			# many and none steps across (where the parking changes sides,
			# a bend is a junction, so cars swerving past each other there
			# take turns).
			flow = true
			for d in 2:
				var a: Array = at[d]
				var b: Array = at[1 - d]
				var ins: Array = lanes_of[a[0]].filter(func(L): return heading_in.call(L, a[1]))
				var outs: Array = lanes_of[b[0]].filter(func(L): return not heading_in.call(L, b[1]))
				if ins.size() != outs.size():
					flow = false
				for Li: _Lane in ins:
					for Lo: _Lane in outs:
						if Lo.rank == Li.rank:
							var n0: int = end_node.call(Li, a[1])
							var n1: int = end_node.call(Lo, b[1])
							if absf(node_dir[n0].cross(node_pos[n1] - node_pos[n0])) > 0.3:
								flow = false
		var zone := -1
		if not flow:
			zone = zones
			zones += 1
		# Where several crossings share one patch, a way joins only streets
		# that meet at one of them (or a street to itself), so no way sweeps
		# the length of the patch from one crossing's street to another's.
		var near_here := Streets.bounds(road[p].poly).grow(2.0)
		for a in at:
			for b in at:
				# Never from a stretch's one end round to its other.
				if a[0] == b[0]:
					continue
				var sa: int = road[stretches[a[0]]].street
				var sb: int = road[stretches[b[0]]].street
				if not flow and sa != sb:
					# Both ends within reach of a junction where their streets meet.
					var A: Streets.Piece = road[stretches[a[0]]]
					var B: Streets.Piece = road[stretches[b[0]]]
					var ta := A.world(Vector2(A.a1 if a[1] == 1 else A.a0, A.c))
					var tb := B.world(Vector2(B.a1 if b[1] == 1 else B.a0, B.c))
					if not _meet_near(sa, sb, near_here, ta, tb, A.width + B.width):
						continue
				for Li: _Lane in lanes_of[a[0]]:
					if not heading_in.call(Li, a[1]):
						continue
					for Lo: _Lane in lanes_of[b[0]]:
						if heading_in.call(Lo, b[1]):
							continue
						var n0: int = end_node.call(Li, a[1])
						var n1: int = end_node.call(Lo, b[1])
						var turn := node_dir[n0].dot(node_dir[n1])
						if turn < -0.7:
							continue
						if (flow or turn > 0.85) and Li.rank != Lo.rank \
								and lanes_of[a[0]].size() == lanes_of[b[0]].size():
							continue
						var way: Edge = curve.call(n0, n1, zone)
						if way != null:
							way.bend = road[p].joint
						connectors.append(way)
	# Into and out of each T mouth, and straight on where a stretch runs on
	# into another end to end.
	for sj in mouths:
		for mo in mouths[sj]:
			var si: int = mo[2]
			var e: int = mo[3]
			for Ls: _Lane in lanes_of[si]:
				var stem_node: int = end_node.call(Ls, e)
				for Lb: _Lane in lanes_of[sj]:
					var up: float = mo[0].x if Lb.sign > 0 else mo[0].y
					var down: float = mo[0].y if Lb.sign > 0 else mo[0].x
					if heading_in.call(Ls, e):
						connectors.append(curve.call(stem_node, Lb.node_at(down), mo[1]))
					else:
						connectors.append(curve.call(Lb.node_at(up), stem_node, mo[1]))
	for si in stretches.size():
		for e in 2:
			if ends[si][e][0] != 1:
				continue
			var sj: int = ends[si][e][1]
			var A: Streets.Piece = road[stretches[si]]
			var B: Streets.Piece = road[stretches[sj]]
			if absf(A.d.dot(B.d)) <= 0.99:
				continue
			var tip := A.world(Vector2(A.a1 if e == 1 else A.a0, A.c))
			var eb := 0 if absf(B.local(tip).x - B.a0) < absf(B.local(tip).x - B.a1) else 1
			for Li: _Lane in lanes_of[si]:
				if not heading_in.call(Li, e):
					continue
				for Lo: _Lane in lanes_of[sj]:
					if not heading_in.call(Lo, eb) and Lo.rank == Li.rank:
						connectors.append(curve.call(end_node.call(Li, e), end_node.call(Lo, eb), -1))
	# Keep only connectors a car can drive: its centre on lane ground, its body
	# on the road and off every parked car.
	var checker := _Checker.new(road, clutter, self)
	for ed in connectors:
		if ed != null and ed.length > 0.05 and checker.drivable(ed):
			edges.append(ed)
	# Ways through a junction are cut into short pieces, so a car lets go of
	# each as its tail leaves it and the next car can cross behind it while it
	# is still in a wide junction.
	var nodes := node_pos.size()
	var pieces: Array[Edge] = []
	for ed in edges:
		if ed.zone < 0 or ed.length <= PIECE * 1.5:
			pieces.append(ed)
			continue
		var n := ceili(ed.length / PIECE)
		var from := ed.from
		for k in n:
			var a := ed.length * k / n
			var b := ed.length * (k + 1) / n
			var pts := PackedVector2Array([ed.at(a)])
			for j in ed.points.size():
				if ed.cum[j] > a + 1e-4 and ed.cum[j] < b - 1e-4:
					pts.append(ed.points[j])
			pts.append(ed.at(b))
			var to := ed.to if k == n - 1 else nodes
			if k < n - 1:
				nodes += 1
			var piece: Edge = make.call(pts, from, to, ed.zone)
			piece.bend = ed.bend
			pieces.append(piece)
			from = to
	edges = pieces
	# Successors, then the largest part every edge of which reaches every other.
	var out_of := {}
	for i in edges.size():
		if not out_of.has(edges[i].from):
			out_of[edges[i].from] = PackedInt32Array()
		out_of[edges[i].from].append(i)
	for ed in edges:
		ed.next = out_of.get(ed.to, PackedInt32Array())
	var keep := _largest_scc(edges)
	var remap := {}
	for i in edges.size():
		if keep.has(i):
			remap[i] = g.edges.size()
			g.edges.append(edges[i])
	for ed in g.edges:
		var nx := PackedInt32Array()
		for j in ed.next:
			if remap.has(j):
				nx.append(remap[j])
		ed.next = nx
	_find_conflicts(g)
	_free_runs(g)
	_mark_links(g)
	_find_conflicts(g)
	_find_lane_near(g)
	_find_exits(g)
	# Where cars may start: along ordinary lanes, a car and two gaps apart.
	var half := car_size.y * 0.5
	for i in g.edges.size():
		var ed := g.edges[i]
		if not ed.spawn or ed.guarded():
			continue
		var s := half + gap
		while s <= ed.length - half - gap - stop_gap:
			g.slots.append([i, s])
			s += car_size.y + gap * 2.0 + 2.0
	return g

## True when paths `a` and `b` meet at a junction of the plan inside `area`
## that lies within `reach` of both `ta` and `tb`.
func _meet_near(a: int, b: int, area: Rect2, ta: Vector2, tb: Vector2, reach: float) -> bool:
	for j in plan.junctions:
		if area.has_point(j.at) and j.streets.has(a) and j.streets.has(b) \
				and j.at.distance_to(ta) <= reach and j.at.distance_to(tb) <= reach:
			return true
	return false

## Indices of the edges in the graph's largest strongly connected part.
static func _largest_scc(edges: Array[Edge]) -> Dictionary:
	var n := edges.size()
	var idx := PackedInt32Array()
	idx.resize(n)
	idx.fill(-1)
	var low := PackedInt32Array()
	low.resize(n)
	var on := PackedByteArray()
	on.resize(n)
	var stack := PackedInt32Array()
	var counter := 0
	var best := []
	for root in n:
		if idx[root] >= 0:
			continue
		# Iterative Tarjan: [node, next successor to look at].
		var work := [[root, 0]]
		idx[root] = counter
		low[root] = counter
		counter += 1
		stack.append(root)
		on[root] = 1
		while not work.is_empty():
			var top: Array = work[work.size() - 1]
			var v: int = top[0]
			var nx := edges[v].next
			if top[1] < nx.size():
				var w := nx[top[1]]
				top[1] += 1
				if idx[w] < 0:
					idx[w] = counter
					low[w] = counter
					counter += 1
					stack.append(w)
					on[w] = 1
					work.append([w, 0])
				elif on[w] == 1:
					low[v] = mini(low[v], idx[w])
			else:
				work.pop_back()
				if not work.is_empty():
					var u: int = work[work.size() - 1][0]
					low[u] = mini(low[u], low[v])
				if low[v] == idx[v]:
					var part := []
					while true:
						var w := stack[stack.size() - 1]
						stack.remove_at(stack.size() - 1)
						on[w] = 0
						part.append(w)
						if w == v:
							break
					if part.size() > best.size():
						best = part
	var out := {}
	for i in best:
		out[i] = true
	return out

## A lane too short for a car to wait on between two junctions (shorter than
## a car, a gap, and the wait short of the next) is a link: a car takes it
## only together with the junctions either side, so none stops with its tail
## in a junction.
func _mark_links(g: Graph) -> void:
	var reach := car_size.y + gap + stop_gap + 1.0
	for ed in g.edges:
		if not ed.guarded():
			continue
		for f in ed.next:
			if g.edges[f].guarded():
				continue
			# Walk on along ordinary lanes while they stay short.
			var walk := [[f, 0.0, [f]]]
			while not walk.is_empty():
				var w: Array = walk.pop_back()
				var e2: Edge = g.edges[w[0]]
				var run: float = w[1] + e2.length
				if run >= reach:
					continue
				for h in e2.next:
					if g.edges[h].guarded():
						for e in w[2]:
							g.edges[e].link = true
							g.edges[e].spawn = false
					elif not w[2].has(h):
						walk.append([h, run, w[2] + [h]])

## Each edge's distance to the nearest ordinary lane, along the graph.
static func _find_exits(g: Graph) -> void:
	var n := g.edges.size()
	g.exit.resize(n)
	g.exit.fill(INF)
	var into := []
	for i in n:
		into.append([])
	for i in n:
		for j in g.edges[i].next:
			into[j].append(i)
	var queue := []
	for i in n:
		if not g.edges[i].guarded():
			g.exit[i] = 0.0
			queue.append(i)
	# Few edges each way and short runs: a plain relaxation is enough.
	while not queue.is_empty():
		var j: int = queue.pop_front()
		for i: int in into[j]:
			var d := g.exit[j] + g.edges[i].length
			if g.edges[i].guarded() and d < g.exit[i]:
				g.exit[i] = d
				queue.append(i)

## A piece of a way through a junction that comes near nothing but the pieces
## before and after it on the one way it lies on (along an avenue through a
## wide junction, between the streets crossing it) is ordinary lane: a car
## may wait on it, so it need not hold the whole junction to cross it.
func _free_runs(g: Graph) -> void:
	var into := {}
	var prev := {}
	for i in g.edges.size():
		for j in g.edges[i].next:
			into[j] = into.get(j, 0) + 1
			prev[j] = i
	var free: Array[int] = []
	for i in g.conflicts:
		if g.edges[i].zone < 0:
			continue
		# The pieces either side of it along its own unbranching way.
		var chain := {i: true}
		var k: int = i
		for step in 3:
			if into.get(k, 0) != 1 or g.edges[prev[k]].next.size() != 1:
				break
			k = prev[k]
			chain[k] = true
		k = i
		for step in 3:
			if g.edges[k].next.size() != 1 or into.get(g.edges[k].next[0], 0) != 1:
				break
			k = g.edges[k].next[0]
			chain[k] = true
		var ok := true
		for j in g.conflicts[i]:
			if not chain.has(j):
				ok = false
				break
		if ok:
			free.append(i)
	for i in free:
		g.edges[i].zone = -1
		g.edges[i].link = false
	g.conflicts.clear()

## For each guarded edge, the guarded edges a car on it would come near
## (itself included): the footprints of a car centred anywhere along the one
## (a metre apart, turned with it, and grown by a margin) meet those along the
## other, or the two share an end.
func _find_conflicts(g: Graph) -> void:
	const CELL := 16.0
	const MARGIN := 0.2
	var list := []
	var boxes := []
	var feet := []
	var grid := {}
	for i in g.edges.size():
		var ed := g.edges[i]
		if not ed.guarded():
			continue
		var quads := []
		var n := maxi(1, ceili(ed.length / 1.0))
		var r := Rect2()
		for k in n + 1:
			var s := ed.length * k / n
			var dir := ed.at(minf(s + 0.5, ed.length)) - ed.at(maxf(s - 0.5, 0.0))
			var q := _quad(ed.at(s), dir, MARGIN)
			quads.append(q)
			r = Streets.bounds(q) if k == 0 else r.merge(Streets.bounds(q))
		var k2 := list.size()
		list.append(i)
		boxes.append(r)
		feet.append(quads)
		g.conflicts[i] = PackedInt32Array([i])
		for x in range(floori(r.position.x / CELL), floori(r.end.x / CELL) + 1):
			for y in range(floori(r.position.y / CELL), floori(r.end.y / CELL) + 1):
				var cell := Vector2i(x, y)
				if not grid.has(cell):
					grid[cell] = []
				grid[cell].append(k2)
	var seen := {}
	var reach := car_size.length() + MARGIN * 2.0
	for cell in grid:
		var here: Array = grid[cell]
		for p in here.size():
			for q in range(p + 1, here.size()):
				var x: int = mini(here[p], here[q])
				var y: int = maxi(here[p], here[q])
				var pair := Vector2i(x, y)
				if seen.has(pair):
					continue
				seen[pair] = true
				if not boxes[x].intersects(boxes[y]):
					continue
				var a := g.edges[list[x]]
				var b := g.edges[list[y]]
				var hit := a.from == b.from or a.to == b.to or a.to == b.from or a.from == b.to
				if not hit:
					hit = _feet_meet(feet[x], feet[y], reach)
				if hit:
					g.conflicts[list[x]].append(list[y])
					g.conflicts[list[y]].append(list[x])

## Fills `g.near_lane`: for each guarded edge, the ordinary lanes along which
## a car's footprint (grown by the same margin) somewhere meets that of a car
## anywhere along the edge.
func _find_lane_near(g: Graph) -> void:
	const CELL := 16.0
	const MARGIN := 0.2
	var grid := {}
	var feet := {}
	for i in g.edges.size():
		var ed := g.edges[i]
		if not ed.guarded():
			continue
		var quads := []
		var n := maxi(1, ceili(ed.length / 1.0))
		for k in n + 1:
			var s := ed.length * k / n
			var dir := ed.at(minf(s + 0.5, ed.length)) - ed.at(maxf(s - 0.5, 0.0))
			quads.append(_quad(ed.at(s), dir, MARGIN))
		feet[i] = quads
		var r := Streets.bounds(quads[0])
		for q in quads:
			r = r.merge(Streets.bounds(q))
		for x in range(floori(r.position.x / CELL), floori(r.end.x / CELL) + 1):
			for y in range(floori(r.position.y / CELL), floori(r.end.y / CELL) + 1):
				var cell := Vector2i(x, y)
				if not grid.has(cell):
					grid[cell] = []
				grid[cell].append(i)
	var reach := car_size.length() + MARGIN * 2.0
	for l in g.edges.size():
		var ed := g.edges[l]
		if ed.guarded():
			continue
		var n := maxi(1, ceili(ed.length / 0.5))
		var hits := {}
		for k in n + 1:
			var s := ed.length * k / n
			var dir := ed.at(minf(s + 0.5, ed.length)) - ed.at(maxf(s - 0.5, 0.0))
			var q := _quad(ed.at(s), dir, MARGIN)
			var cq := (q[0] + q[2]) * 0.5
			var cell := Vector2i((cq / CELL).floor())
			for x in range(cell.x - 1, cell.x + 2):
				for y in range(cell.y - 1, cell.y + 2):
					for i: int in grid.get(Vector2i(x, y), []):
						if not hits.has(i) and _feet_meet([q], feet[i], reach):
							hits[i] = true
		for i in hits:
			if not g.near_lane.has(i):
				g.near_lane[i] = PackedInt32Array()
			g.near_lane[i].append(l)

## True when some quad of `a` overlaps some quad of `b` (centres nearer than
## `reach` are tested).
static func _feet_meet(a: Array, b: Array, reach: float) -> bool:
	for qa: PackedVector2Array in a:
		var ca := (qa[0] + qa[2]) * 0.5
		for qb: PackedVector2Array in b:
			if ca.distance_squared_to((qb[0] + qb[2]) * 0.5) < reach * reach and _quads_meet(qa, qb):
				return true
	return false

## Separating-axis test for two convex quads.
static func _quads_meet(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for poly in [a, b]:
		for k in 2:
			var e: Vector2 = poly[k + 1] - poly[k]
			var axis := Vector2(-e.y, e.x)
			var a0 := INF
			var a1 := -INF
			for p in a:
				var d := p.dot(axis)
				a0 = minf(a0, d)
				a1 = maxf(a1, d)
			var b0 := INF
			var b1 := -INF
			for p in b:
				var d := p.dot(axis)
				b0 = minf(b0, d)
				b1 = maxf(b1, d)
			if a1 <= b0 or b1 <= a0:
				return false
	return true

## Looks up lane ground, road and parked cars near a point, for checking that
## a connector is drivable.
class _Checker extends RefCounted:
	const CELL := 8.0
	## A bumper may overhang the kerb by this much, toward the car's centre.
	const TRIM := 0.4
	## More round a bend, where the lanes can step across as the parking
	## changes sides.
	const BEND_TRIM := 0.9
	var lanes := {}
	var road := {}
	var parked := {}
	var traffic: Traffic

	func _init(pieces: Array, clutter: StreetClutter, t: Traffic) -> void:
		traffic = t
		for poly in clutter.lanes:
			_add(lanes, poly)
		for p: Streets.Piece in pieces:
			_add(road, p.poly)
		for f in clutter.pieces:
			if f.kind == StreetClutter.Kind.CAR:
				_add(parked, clutter._corners(f))

	func _add(grid: Dictionary, poly: PackedVector2Array) -> void:
		var r := Streets.bounds(poly)
		for x in range(floori(r.position.x / CELL), floori(r.end.x / CELL) + 1):
			for y in range(floori(r.position.y / CELL), floori(r.end.y / CELL) + 1):
				var k := Vector2i(x, y)
				if not grid.has(k):
					grid[k] = []
				grid[k].append(poly)

	func _in(grid: Dictionary, p: Vector2) -> bool:
		for poly in grid.get(Vector2i(floori(p.x / CELL), floori(p.y / CELL)), []):
			if Geometry2D.is_point_in_polygon(p, poly):
				return true
		return false

	func drivable(ed: Edge) -> bool:
		var s := 0.3
		while s < ed.length - 0.29:
			var at := ed.at(s)
			var h := ed.at(s + 0.3) - ed.at(s - 0.3)
			if not _in(lanes, at):
				return false
			var quad := traffic._quad(at, h, 0.0)
			var centre := at
			for q in quad:
				if not _in(road, q + (centre - q).normalized() * (BEND_TRIM if ed.bend else TRIM)):
					return false
			for q in quad:
				for poly in parked.get(Vector2i(floori(q.x / CELL), floori(q.y / CELL)), []):
					if Streets.overlaps(poly, quad):
						return false
			s += 0.6
		return true
