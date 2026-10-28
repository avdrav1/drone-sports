class_name StreetClutter
extends StaticBody3D
# Story 15.9: the city at drone height. Parked cars in a parking strip along the
# kerb, bus shelters, benches, signs, and trees in pits on the pavements, and AC
# units and downpipes on building walls, all placed from the layout's seed and
# drawn through one MultiMesh per model. Anything taller than a bench collides
# with one box. Sits under a Streets node and reads its plan, kerbs, and lights;
# cached per layout, like Streets.
#
# Lanes: each street segment keeps a parking strip `park_width` wide against the
# kerb (both sides of an avenue, one side of a street), clear of crosswalks and
# lane arrows; the rest of the road, crossings included, is `lanes`, and nothing
# stands in it. Nothing stands in a clearing or on a rooftop pad either.

enum Kind { CAR, BENCH, SHELTER, SIGN, TREE, PIT, AC, PIPE }

## Glass and metal surfaces for the shelters, signs, and pipes, and the pit soil.
@export var car_model: PackedScene
@export var bench_model: PackedScene
@export var tree_model: PackedScene
@export var aircon_model: PackedScene
@export var metal: Material
@export var glass: Material
@export var sign_material: Material
@export var pit_material: Material
## Tarp colours for parked cars, and sign plate colours.
@export var car_tints: PackedColorArray = [Color(1, 1, 1), Color(0.62, 0.68, 0.85), Color(1.0, 0.9, 0.74),
	Color(0.55, 0.55, 0.56), Color(0.72, 0.8, 0.7)]
@export var sign_tints: PackedColorArray = [Color(0.12, 0.3, 0.7), Color(0.75, 0.12, 0.1), Color(0.9, 0.9, 0.88),
	Color(0.1, 0.45, 0.25)]
## Parking strip depth against the kerb, and gaps between parked cars.
@export var park_width := 2.3
@export var car_gap := Vector2(0.8, 2.5)
@export var car_chance := 0.75
## Trees stand this far apart along a kerb, each slot taken by chance.
@export var tree_spacing := 7.5
@export var tree_chance := 0.75
@export var bench_chance := 0.35
## Bus shelters go on pavements along avenues.
@export var shelter_chance := 0.5
@export var sign_chance := 0.45
## Chance a wall face gets AC units, and a stacked box a downpipe.
@export var ac_chance := 0.4
@export var pipe_chance := 0.5

## Pavement items keep this far from a block's corner (crosswalks are there).
const CORNER := 3.5
const SHELTER_SIZE := Vector3(3.8, 2.5, 1.5)
const SIGN_HEIGHT := 2.8
const SIGN_PLATE := Vector3(0.6, 0.6, 0.04)
const PIT_SIZE := 1.2
const PIPE_RADIUS := 0.06
## A pipe's centre stands this far off its wall, and this far in from the corner.
const PIPE_OUT := 0.1
const PIPE_IN := 0.4

## params -> [pieces, lanes, parking, multimeshes, shapes].
static var _cache := {}

var streets: Streets
var plan: CityPlan
var layout: CityLayout
## Each piece: {kind, xform (where its mesh is drawn), box (world AABB), lot
## (-1 on the street)}, every kind in turn.
var pieces: Array = []
## Road outside the parking strips, crossings included, as XZ rects.
var lanes: Array[Rect2] = []
## Parking strips along kerbs, as XZ rects.
var parking: Array[Rect2] = []

func _ready() -> void:
	streets = get_parent() as Streets
	if streets == null:
		return
	if not streets.is_node_ready():
		await streets.ready
	build()

func build() -> void:
	plan = streets.plan
	layout = streets.layout
	var key := layout.params() + [streets.light_spacing, streets.light_inset, streets.kerb_height, streets.kerb_width,
		streets.chunk_length, park_width, car_gap, car_chance, tree_spacing, tree_chance, bench_chance,
		shelter_chance, sign_chance, ac_chance, pipe_chance]
	if not _cache.has(key):
		_cache[key] = _generate()
	var built: Array = _cache[key]
	pieces = built[0]
	lanes = built[1]
	parking = built[2]
	var mms: Array = built[3]
	for k in Kind.size():
		var mm := MultiMeshInstance3D.new()
		mm.name = String(Kind.keys()[k]).capitalize().replace(" ", "") + "s"
		mm.multimesh = mms[k]
		add_child(mm)
	for i in built[4].size():
		var box: AABB = built[4][i]
		var shape := BoxShape3D.new()
		shape.size = box.size
		var cs := CollisionShape3D.new()
		cs.name = "Piece%d" % i
		cs.shape = shape
		cs.position = box.get_center()
		add_child(cs)

## The height above which a piece collides: a bench's.
func bench_height() -> float:
	return _model_mesh(bench_model).get_aabb().size.y

## True when a piece with this box gets a collision box.
func collides(box: AABB) -> bool:
	return box.size.y > bench_height() + 0.001

func _generate() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed + 9
	var found := []
	var road := Streets.road_pieces(plan, layout)
	var shelters: Array[Rect2] = []
	for b in plan.blocks:
		if CityPlan.inside(b, layout.core_radius):
			for side in 4:
				_edge(rng, b, side, road, found, shelters)
	var strips := _parking(rng, road, found, shelters)
	for i in plan.lots.size():
		_walls(rng, i, found)
	found = found.filter(func(f): return _clear(f.box))
	var mms := []
	var shapes: Array[AABB] = []
	for k in Kind.size():
		var mine := found.filter(func(f): return f.kind == k)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = k == Kind.CAR or k == Kind.SIGN
		mm.mesh = _mesh(k)
		mm.instance_count = mine.size()
		for j in mine.size():
			mm.set_instance_transform(j, mine[j].xform)
			if mm.use_colors:
				mm.set_instance_color(j, mine[j].tint)
		mms.append(mm)
	var ordered := []
	for k in Kind.size():
		ordered.append_array(found.filter(func(f): return f.kind == k))
	for f in ordered:
		if collides(f.box):
			shapes.append(f.box)
	return [ordered, strips[0], strips[1], mms, shapes]

## True when a box stays inside the core and clear of every clearing.
func _clear(box: AABB) -> bool:
	var r := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	return CityPlan.inside(r, layout.core_radius) and CityPlan.clear_of(layout, r)

## A piece of `kind` drawn with `xform` (mesh space) and boxed by its mesh's AABB.
func _piece(kind: int, xform: Transform3D, lot := -1, tint := Color(1, 1, 1)) -> Dictionary:
	return {"kind": kind, "xform": xform, "box": xform * _mesh(kind).get_aabb(), "lot": lot, "tint": tint}

## Pavement items on one side of a block (0 -z, 1 +z, 2 -x, 3 +x): a bus
## shelter on an avenue, signs near the corners, trees in pits, and a bench, each
## keeping off the street lights and the others along the kerb.
func _edge(rng: RandomNumberGenerator, b: Rect2, side: int, road: Array, found: Array, shelters: Array[Rect2]) -> void:
	var along := Vector2.RIGHT if side < 2 else Vector2.DOWN
	var out: Vector2 = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT][side]
	var start: Vector2 = [b.position, Vector2(b.position.x, b.end.y), b.position, Vector2(b.end.x, b.position.y)][side]
	var length := b.size.x if side < 2 else b.size.y
	var kind := -1
	var probe := start + along * length * 0.5 + out * 1.0
	for piece in road:
		if (piece[0] as Rect2).has_point(probe):
			kind = piece[3]
	if kind < 0:
		return
	var yaw := atan2(out.x, out.y)
	var turn := Basis(Vector3.UP, yaw)
	var top := streets.kerb_height
	var pave := layout.sidewalk - streets.kerb_width
	var used: Array[Vector2] = []
	for p in streets.lights:
		var q := Vector2(p.x, p.z) - start
		if absf(q.dot(-out) - streets.light_inset) < 0.01 and q.dot(along) >= 0.0 and q.dot(along) <= length:
			used.append(Vector2(q.dot(along) - 0.8, q.dot(along) + 0.8))
	# A point `t` along the kerb and `depth` in from the block's edge.
	var at := func(t: float, depth: float) -> Vector3:
		var p := start + along * t - out * depth
		return Vector3(p.x, top, p.y)
	if kind == 1 and rng.randf() < shelter_chance:
		var t := rng.randf_range(CORNER + 3.0, length - CORNER - 3.0)
		if _take(used, t, SHELTER_SIZE.x * 0.5 + 0.5):
			var f := _piece(Kind.SHELTER, Transform3D(turn, at.call(t, streets.kerb_width + 0.5 + SHELTER_SIZE.z * 0.5)))
			found.append(f)
			shelters.append(Rect2(f.box.position.x, f.box.position.z, f.box.size.x, f.box.size.z))
	for e in 2:
		if rng.randf() < sign_chance:
			var t := CORNER if e == 0 else length - CORNER
			if _take(used, t, 0.5):
				var tint := sign_tints[rng.randi() % sign_tints.size()]
				found.append(_piece(Kind.SIGN, Transform3D(turn, at.call(t, streets.kerb_width + 0.35)), -1, tint))
	if rng.randf() < bench_chance:
		var bt := rng.randf_range(CORNER + 1.5, length - CORNER - 1.5)
		var half_bench := _mesh(Kind.BENCH).get_aabb().size.x * 0.5 + 0.3
		if _take(used, bt, half_bench):
			found.append(_piece(Kind.BENCH, Transform3D(turn, at.call(bt, streets.kerb_width + pave * 0.75))))
	# Trees: the crown's long side runs along the kerb, so it stays over the pavement.
	var tree_aabb := _mesh(Kind.TREE).get_aabb()
	var tree_turn := Basis(Vector3.UP, yaw + PI * 0.5)
	# Slots midway between the lights (and the corners), more where gaps are long.
	var stops: Array[float] = [CORNER]
	for u in used:
		stops.append((u.x + u.y) * 0.5)
	stops.append(length - CORNER)
	stops.sort()
	var slots: Array[float] = []
	for k in stops.size() - 1:
		var n := maxi(1, floori((stops[k + 1] - stops[k]) / tree_spacing))
		for m in n:
			slots.append(lerpf(stops[k], stops[k + 1], (m + 1.0) / (n + 1.0)))
	for t in slots:
		if rng.randf() < tree_chance:
			var s := rng.randf_range(0.9, 1.15)
			var half := tree_aabb.size.z * 0.5 * s + 0.3
			if _take(used, t, half):
				var base: Vector3 = at.call(t, streets.kerb_width + pave * 0.5)
				var tree_xf := Transform3D(tree_turn.scaled_local(Vector3(s, s * rng.randf_range(1.3, 1.6), s)), base)
				var f := _piece(Kind.TREE, tree_xf)
				# Keep a crown that cannot fit the pavement off it.
				var pavement := b.grow(-streets.kerb_width)
				if pavement.encloses(Rect2(f.box.position.x, f.box.position.z, f.box.size.x, f.box.size.z)):
					found.append(f)
					found.append(_piece(Kind.PIT, Transform3D(Basis.from_scale(Vector3(PIT_SIZE, 0.02, PIT_SIZE)), base + Vector3.UP * 0.005)))
				else:
					used.pop_back()
## Claims [t - half, t + half] along a kerb when nothing holds any of it.
static func _take(used: Array[Vector2], t: float, half: float) -> bool:
	for u in used:
		if t + half > u.x and t - half < u.y:
			return false
	used.append(Vector2(t - half, t + half))
	return true

## Parking strips and the cars in them, and the lanes left over. Returns
## [lanes, strips].
func _parking(rng: RandomNumberGenerator, road: Array, found: Array, shelters: Array[Rect2]) -> Array:
	var out_lanes: Array[Rect2] = []
	var strips: Array[Rect2] = []
	var car_aabb := _mesh(Kind.CAR).get_aabb()
	# Keep clear of the crosswalk at a crossing, and of lane arrows.
	var end_margin := Streets.CROSSWALK_GAP + Streets.CROSSWALK_DEPTH + 0.5
	var arrows: Array[Rect2] = []
	for d in streets.decals:
		if d[0] == Streets.Mark.ARROW:
			arrows.append((d[1] as Rect2).grow(0.3))
	for piece in road:
		var r: Rect2 = piece[0]
		if piece[3] == 2:
			out_lanes.append(r)
			continue
		var ac: int = piece[1]
		var al := 1 - ac
		var a0 := r.position[al] + (end_margin if Streets.meets(road, piece, r.position[al]) else 1.0)
		var a1 := r.end[al] - (end_margin if Streets.meets(road, piece, r.end[al]) else 1.0)
		var sides: Array = [-1, 1] if piece[3] == 1 else [-1 if rng.randf() < 0.5 else 1]
		var lane := r
		if a1 - a0 < car_aabb.size.z + 1.0:
			sides = []
		for s in sides:
			var strip := r
			strip.position[al] = a0
			strip.size[al] = a1 - a0
			strip.size[ac] = park_width
			if s > 0:
				strip.position[ac] = r.end[ac] - park_width
			# An arrow in the strip's lane pushes that end of the strip back.
			for arrow in arrows:
				if arrow.intersects(strip):
					var lo := strip.position[al]
					var hi := strip.end[al]
					if arrow.get_center()[al] < strip.get_center()[al]:
						lo = arrow.end[al]
					else:
						hi = arrow.position[al]
					strip.position[al] = lo
					strip.size[al] = maxf(hi - lo, 0.0)
			if strip.size[al] < car_aabb.size.z + 1.0:
				continue
			strips.append(strip)
			# The road beside the strip's ends stays lane.
			for span in [Vector2(r.position[al], strip.position[al]), Vector2(strip.end[al], r.end[al])]:
				var bit := strip
				bit.position[al] = span.x
				bit.size[al] = span.y - span.x
				out_lanes.append(bit)
			if s < 0:
				lane.position[ac] += park_width
			lane.size[ac] -= park_width
			# Right-hand traffic: the lane at across sign -1 heads +along for streets along z.
			var heading: float = s * (-1.0 if ac == 0 else 1.0)
			var dir := Vector3.ZERO
			dir[al * 2] = heading
			var basis := Basis.looking_at(-dir, Vector3.UP)
			var at := strip.position[al] + rng.randf_range(car_gap.x, car_gap.y)
			while at + car_aabb.size.z <= strip.end[al]:
				var c := strip.get_center()
				c[al] = at + car_aabb.size.z * 0.5
				var f := _piece(Kind.CAR, Transform3D(basis, Vector3(c.x, Streets.ROAD_Y, c.y)), -1,
					car_tints[rng.randi() % car_tints.size()])
				var foot := Rect2(f.box.position.x, f.box.position.z, f.box.size.x, f.box.size.z)
				var free := rng.randf() < car_chance and strip.grow(0.01).encloses(foot)
				for sh in shelters:
					if sh.grow(3.0).intersects(foot):
						free = false
				if free:
					found.append(f)
				at += car_aabb.size.z + rng.randf_range(car_gap.x, car_gap.y)
		out_lanes.append(lane)
	return [out_lanes, strips]

## AC units and downpipes on lot `i`'s walls, clear of its trims and other parts.
func _walls(rng: RandomNumberGenerator, i: int, found: Array) -> void:
	var shape := plan.shapes[i]
	var room := plan.lots[i].grow(layout.lot_gap * 0.5)
	var ac_aabb := _mesh(Kind.AC).get_aabb()
	var gf := layout.ground_floor
	var st := layout.storey
	var mine: Array[AABB] = []
	for j in shape.boxes.size():
		var b := shape.boxes[j]
		var others: Array[AABB] = shape.trims.duplicate()
		for k in shape.boxes.size():
			if k != j:
				others.append(shape.boxes[k])
		var fits := func(box: AABB) -> bool:
			var flat := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			if not room.encloses(flat):
				return false
			for o in others + mine:
				if o.intersects(box):
					return false
			return true
		# Faces: +x, -x, +z, -z as [outward normal, centre on the wall, width].
		var faces := []
		for f in 4:
			var n := [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][f] as Vector3
			var c := b.get_center() + n * (b.size.x if f < 2 else b.size.z) * 0.5
			faces.append([n, Vector3(c.x, 0.0, c.z), b.size.z if f < 2 else b.size.x])
		if rng.randf() < pipe_chance:
			var face: Array = faces[rng.randi() % 4]
			var n: Vector3 = face[0]
			var tangent := n.cross(Vector3.UP)
			var edge: float = (face[2] * 0.5 - PIPE_IN) * (1.0 if rng.randf() < 0.5 else -1.0)
			var p: Vector3 = face[1] + n * PIPE_OUT + tangent * edge
			var run := _pipe(p, b.position.y, b.end.y, shape)
			if not run.is_empty() and run.all(func(seg): return fits.call(seg)):
				for seg in run:
					found.append(_piece(Kind.PIPE, Transform3D(Basis.from_scale(seg.size), seg.get_center()), i))
					mine.append(seg)
		for face in faces:
			if rng.randf() >= ac_chance:
				continue
			var n: Vector3 = face[0]
			var cols := floori(face[2] / 3.0 + 0.001)
			var first := ceili((maxf(b.position.y, gf) + 0.3 - gf) / st - 0.001)
			var last := floori((b.end.y - 0.6 - ac_aabb.size.y - gf) / st + 0.001)
			if cols < 1 or last < first:
				continue
			var basis := Basis.looking_at(-n, Vector3.UP)
			for k in rng.randi_range(1, 3):
				var col := rng.randi_range(0, cols - 1)
				var row := rng.randi_range(first, last)
				var tangent := n.cross(Vector3.UP)
				var p: Vector3 = face[1] + n * 0.01 + tangent * (col - (cols - 1) * 0.5) * 3.0
				p.y = gf + st * row + 0.15
				var f := _piece(Kind.AC, Transform3D(basis, p), i)
				if fits.call(f.box):
					found.append(f)
					mine.append(f.box)

## A downpipe's segments at `p` from y0 to y1, cut round every ledge it meets.
func _pipe(p: Vector3, y0: float, y1: float, shape: CityPlan.Shape) -> Array[AABB]:
	var r := PIPE_RADIUS
	var column := AABB(Vector3(p.x - r, y0, p.z - r), Vector3(r * 2.0, y1 - y0, r * 2.0))
	var cuts: Array[Vector2] = []
	for k in shape.trims.size():
		var t := shape.trims[k]
		if shape.trim_kinds[k] == CityPlan.Trim.LEDGE and t.intersects(column):
			cuts.append(Vector2(t.position.y, t.end.y))
	cuts.sort_custom(func(a, c): return a.x < c.x)
	var out: Array[AABB] = []
	var at := y0 + 0.005
	# A hair's gap at each ledge, so a segment never shares the ledge's face.
	for c in cuts + [Vector2(y1, y1)]:
		if c.x - at > 0.2:
			out.append(AABB(Vector3(p.x - r, at, p.z - r), Vector3(r * 2.0, c.x - 0.005 - at, r * 2.0)))
		at = maxf(at, c.y + 0.005)
	return out

## Each kind's mesh: a model's, or one built here. Unit pit and pipe, scaled per
## piece.
func _mesh(kind: int) -> Mesh:
	match kind:
		Kind.CAR:
			return _tinted(_model_mesh(car_model))
		Kind.BENCH:
			return _model_mesh(bench_model)
		Kind.TREE:
			return _model_mesh(tree_model)
		Kind.AC:
			return _model_mesh(aircon_model)
		Kind.SHELTER:
			return _shelter()
		Kind.SIGN:
			return _sign()
		Kind.PIT:
			var pit := BoxMesh.new()
			pit.material = pit_material
			return pit
		_:
			var pipe := CylinderMesh.new()
			pipe.top_radius = 0.5
			pipe.bottom_radius = 0.5
			pipe.height = 1.0
			pipe.radial_segments = 8
			pipe.rings = 1
			pipe.material = metal
			return pipe

static var _meshes := {}

## The first mesh in a model scene, loaded once.
static func _model_mesh(scene: PackedScene) -> Mesh:
	if not _meshes.has(scene):
		var root := scene.instantiate()
		var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
		_meshes[scene] = mi.mesh
		root.free()
	return _meshes[scene]

## A copy of `mesh` whose materials take the instance colour as a tint.
static func _tinted(mesh: Mesh) -> Mesh:
	if not _meshes.has(mesh):
		var copy: Mesh = mesh.duplicate()
		for s in copy.get_surface_count():
			var m: BaseMaterial3D = copy.surface_get_material(s).duplicate()
			m.vertex_color_use_as_albedo = true
			copy.surface_set_material(s, m)
		_meshes[mesh] = copy
	return _meshes[mesh]

## A bus shelter, front (open side) toward +z, standing on y = 0: posts, roof,
## and seat in metal, back and side panes in glass.
func _shelter() -> Mesh:
	if _meshes.has(&"shelter"):
		return _meshes[&"shelter"]
	var s := SHELTER_SIZE
	var hx := s.x * 0.5
	var hz := s.z * 0.5
	var frame := [
		AABB(Vector3(-hx, s.y - 0.12, -hz), Vector3(s.x, 0.12, s.z)),
		AABB(Vector3(-hx + 0.3, 0.42, -hz + 0.1), Vector3(s.x - 0.6, 0.05, 0.35)),
	]
	for x in [-hx, hx - 0.08]:
		for z in [-hz, hz - 0.08]:
			frame.append(AABB(Vector3(x, 0.0, z), Vector3(0.08, s.y - 0.12, 0.08)))
	var panes := [
		AABB(Vector3(-hx + 0.08, 0.15, -hz + 0.03), Vector3(s.x - 0.16, s.y - 0.4, 0.02)),
		AABB(Vector3(-hx + 0.03, 0.15, -hz + 0.08), Vector3(0.02, s.y - 0.4, s.z * 0.6)),
		AABB(Vector3(hx - 0.05, 0.15, -hz + 0.08), Vector3(0.02, s.y - 0.4, s.z * 0.6)),
	]
	var mesh := _boxes(null, frame, metal)
	_meshes[&"shelter"] = _boxes(mesh, panes, glass)
	return _meshes[&"shelter"]

## A sign: a pole and a plate facing +z, standing on y = 0.
func _sign() -> Mesh:
	if _meshes.has(&"sign"):
		return _meshes[&"sign"]
	var p := SIGN_PLATE
	var mesh := _boxes(null, [AABB(Vector3(-0.035, 0.0, -0.035), Vector3(0.07, SIGN_HEIGHT, 0.07))], metal)
	_meshes[&"sign"] = _boxes(mesh, [AABB(Vector3(-p.x * 0.5, SIGN_HEIGHT - p.y - 0.05, 0.035), p)], sign_material)
	return _meshes[&"sign"]

## Adds one surface of boxes in `mat` to `mesh` (a new one when null).
static func _boxes(mesh: ArrayMesh, boxes: Array, mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var unit := BoxMesh.new()
	for b: AABB in boxes:
		st.append_from(unit, 0, Transform3D(Basis.from_scale(b.size), b.get_center()))
	st.set_material(mat)
	return st.commit(mesh if mesh else ArrayMesh.new())
