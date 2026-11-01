extends RefCounted
# Story 30.8: four rooftop shrines in the city, one per god, placed by the plan
# clear of every course, gate, hazard and the spawn, in job cities (seed 7) and
# free-flight cities alike. Their lamps light with the vows kept, capped. They
# are seen only: no collision, nothing a job aims at, never on the radar's rim.

const Sim = preload("res://tests/sim.gd")
const Obstacles = preload("res://tests/test_obstacle_structures.gd")
const FreeFlight = preload("res://tests/test_free_flight_city.gd")
const LAYOUT := "res://data/city/sandbox_city.tres"
const VARIETY := "res://data/city/free_flight_variety.tres"
const SANDBOX := "res://scenes/debug_flight.tscn"
const SHRINE := "res://scenes/world/shrine.tscn"
const SUGGESTIONS := "res://data/radio/suggestions.tres"
## How far every course, gate, hazard, crew place and spawn keeps from a shrine,
## m, and how far from the boss's shell.
const CLEAR := 20.0
## Nodes of the shared world, which hold the shrines and nothing a job uses.
const WORLD := ["City", "Streets", "Rooftops", "Ground", "GoldenHour", "CameraRig", "CommandView", "FreeCamera"]

## The sandbox layout (seed 7) and 19 free-flight rolls of it.
static func _layouts() -> Array[CityLayout]:
	var base: CityLayout = load(LAYOUT)
	var variety: CityVariety = load(VARIETY)
	var out: Array[CityLayout] = [base]
	for i in 19:
		out.append(variety.roll(base, 1000 + i * 7919))
	return out

## Each seed: four shrines, one per quarter in thread order, on low roofs past
## every clearing (the spawn plaza and the jammer), and on no pad's roof.
func test_twenty_seeds_place_four_shrines_clear() -> bool:
	var ok := true
	var rooftops: Rooftops = load("res://scenes/world/rooftops.tscn").instantiate()
	for l in _layouts():
		var p := CityPlan._generate(l)
		var good := p.shrines.size() == 4 and p.shrine_lots.size() == 4
		for k in p.shrines.size():
			var at := Vector2(p.shrines[k].x, p.shrines[k].z)
			var lot := p.lots[p.shrine_lots[k]]
			good = good and signf(at.x) == CityPlan.SHRINE_QUARTERS[k].x and signf(at.y) == CityPlan.SHRINE_QUARTERS[k].y
			good = good and lot.has_point(at) and is_equal_approx(p.shrines[k].y, p.heights[p.shrine_lots[k]])
			for c in l.clearings:
				good = good and not CityPlan.touches(Vector3(c.x, c.y, c.z + CLEAR), lot)
		# The pads (rooftop landing targets) keep off the shrines' roofs.
		rooftops.layout = l
		rooftops.plan = p
		var pads: PackedVector3Array = rooftops._generate()[1]
		for pad in pads:
			for k in p.shrines.size():
				good = good and Vector2(pad.x - p.shrines[k].x, pad.z - p.shrines[k].z).length() > CLEAR
		if not good:
			print("        seed %d: %s" % [l.seed, p.shrines])
		ok = ok and good
	rooftops.free()
	return ok

## Every node in `scene` a job or the sandbox places outside the shared world:
## gates, stations, hazard zones, crew slots, markers, the drones' spawns.
static func _placed(scene: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in scene.find_children("*", "Node3D", true, false):
		var top: Node = n
		while top.get_parent() != scene:
			top = top.get_parent()
		if not String(top.name) in WORLD:
			out.append(n)
	return out

## Every scene that shows the city: the free-flight sandbox and the jobs.
static func _city_scenes() -> Array[String]:
	var out: Array[String] = [SANDBOX]
	out.append_array(FreeFlight._city_scenes())
	return out

static func _shrines(scene: Node) -> Array[Shrine]:
	var out: Array[Shrine] = []
	for n in scene.find_children("Shrine*", "Node3D", true, false):
		if n is Shrine:
			out.append(n)
	return out

## In each city scene the four shrines stand, one per god, and every course,
## gate, hazard, crew place and spawn is CLEAR away (the boss's shell too).
func test_city_scenes_keep_shrines_clear_of_jobs() -> bool:
	var ok := true
	var four: DeityList = load("res://data/deities/deities.tres")
	for path in _city_scenes():
		var scene: Node = Sim.add(load(path).instantiate())
		await Sim.process_frames(2)
		var shrines := _shrines(scene)
		var good := shrines.size() == 4
		for k in shrines.size():
			good = good and shrines[k].deity == four.deities[k]
			var at := shrines[k].global_position
			for n in _placed(scene):
				var d := Vector2(n.global_position.x - at.x, n.global_position.z - at.z).length()
				if n is Lattice:
					d = n.global_position.distance_to(at) - (n as Lattice).boss.radius
				if d < CLEAR:
					print("        %s: %s is %.1f m from %s" % [path, scene.get_path_to(n), d, shrines[k].deity.id])
					good = false
		if not good:
			print("        %s: %d shrines" % [path, shrines.size()])
		ok = ok and good
		scene.free()
	return ok

## Lamps lit match the vows kept on each thread, capped at the shrine's lamps.
func test_lamps_match_the_saved_vows() -> bool:
	SaveGame.write_section(Vows.SECTION, {"brahma": 3, "vishnu": 40, "krishna": 1})
	var four: DeityList = load("res://data/deities/deities.tres")
	var ok := true
	for d in four.deities:
		var s: Shrine = load(SHRINE).instantiate()
		s.deity = d
		Sim.add(s)
		var want := mini(Vows.kept(d.id), s.lamps)
		var lit := 0
		var flames := 0
		for i in s.lamps:
			var lamp := s.get_node("Lamp%d" % i)
			lit += 1 if lamp.get_meta(&"lit") else 0
			flames += 1 if lamp.has_node("Flame") else 0
		ok = ok and s.lit == want and lit == want and flames == want
		s.free()
	ok = ok and Vows.kept(&"shiva") == 0 and Vows.kept(&"vishnu") > 8
	# A vow kept now shows on the next build.
	Vows.record_kept(&"shiva")
	var again: Shrine = load(SHRINE).instantiate()
	again.deity = four.by_id(&"shiva")
	Sim.add(again)
	ok = ok and again.lit == 1
	again.free()
	return ok

## Box shapes in `scene` outside the drones, as world AABBs.
static func _solid_boxes(scene: Node) -> Array[AABB]:
	var out: Array[AABB] = []
	for c in scene.find_children("*", "CollisionShape3D", true, false):
		var shape := c as CollisionShape3D
		if shape.shape is BoxShape3D and not _in_drone(shape):
			var size: Vector3 = shape.shape.size
			out.append(shape.global_transform * AABB(-size * 0.5, size))
	return out

static func _in_drone(n: Node) -> bool:
	while n:
		if n is Drone:
			return true
		n = n.get_parent()
	return false

## A shrine has no body, area or shape of its own, so nothing on a drone's
## layer, and no collider (roof clutter, plant room, parapet) stands in it.
func test_no_shrine_collides() -> bool:
	var ok := true
	for path in _city_scenes():
		var scene: Node = Sim.add(load(path).instantiate())
		await Sim.process_frames(2)
		var boxes := _solid_boxes(scene)
		for s in _shrines(scene):
			ok = ok and s.find_children("*", "CollisionObject3D", true, false).is_empty() \
				and s.find_children("*", "CollisionShape3D", true, false).is_empty() \
				and s.find_children("*", "CollisionPolygon3D", true, false).is_empty()
			# Its extent, lifted just off the roof it stands on.
			var room := s.global_transform * s.extent()
			room.position.y += 0.05
			room.size.y -= 0.05
			for b in boxes:
				if b.intersects(room):
					print("        %s: a collider stands in %s's shrine" % [path, s.deity.id])
					ok = false
		scene.free()
	return ok

## True when `v` is, or holds, a shrine or a node inside one.
static func _is_shrine(v) -> bool:
	if v is Array:
		return v.any(func(x): return _is_shrine(x))
	if not v is Node or not is_instance_valid(v):
		return false
	var n: Node = v
	while n:
		if n is Shrine:
			return true
		n = n.get_parent()
	return false

## No job objective, runner, route or radio line points at a shrine, and its
## mark never lights or sits on the radar's rim: seen, not a destination.
func test_nothing_aims_at_a_shrine() -> bool:
	var ok := true
	for path in _city_scenes():
		var scene: Node = Sim.add(load(path).instantiate())
		await Sim.process_frames(2)
		var shrines := _shrines(scene)
		for n in scene.find_children("*", "Node", true, false):
			# The shrines' own builder (Rooftops) holds them; nothing else may.
			if _is_shrine(n) or shrines.any(func(s): return n.is_ancestor_of(s)):
				continue
			for prop in n.get_property_list():
				if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and _is_shrine(n.get(prop.name)):
					print("        %s: %s.%s" % [path, scene.get_path_to(n), prop.name])
					ok = false
		for s in shrines:
			var m: MapMarker = s.get_node("Marker")
			ok = ok and m.kind == Shrine.MARKER_KIND and not m.on_rim and not m.highlighted and m.label == "" \
				and m.symbol != null
		scene.free()
	for sug in (load(SUGGESTIONS) as Resource).get("suggestions"):
		ok = ok and sug.kind != Shrine.MARKER_KIND and not sug.landmark.to_lower().contains("shrine")
	return ok

## In free flight the radar shows a shrine as its symbol when near and leaves it
## off the rim when far; the map shows all four as symbols.
func test_radar_and_map_show_the_symbol() -> bool:
	var scene: Node = Sim.add(load(SANDBOX).instantiate())
	await Sim.process_frames(2)
	var radar: Radar = scene.get_node("HUD/Radar")
	var drone: Drone = scene.get_node("Drone")
	var shrines := _shrines(scene)
	var near := shrines[0].global_position + Vector3(10, 20, 10)
	drone.reset(Transform3D(Basis(), near))
	drone.freeze = true
	await Sim.process_frames(2)
	var marks := radar.blips().filter(func(b): return b.marker.kind == Shrine.MARKER_KIND)
	var ok: bool = marks.any(func(b): return b.marker == shrines[0].get_node("Marker") and not b.on_rim)
	ok = ok and marks.all(func(b): return not b.on_rim)
	drone.reset(Transform3D(Basis(), Vector3(0, 20, 400)))
	drone.freeze = true
	await Sim.process_frames(2)
	ok = ok and radar.blips().filter(func(b): return b.marker.kind == Shrine.MARKER_KIND).is_empty()
	var mapped := MapMarker.collect(scene).filter(func(m): return m.kind == Shrine.MARKER_KIND and m.symbol != null)
	ok = ok and mapped.size() == 4
	scene.free()
	return ok

## The obstacles of every seed-7 job scene are as fingerprinted.
func test_job_fingerprints_unchanged() -> bool:
	var ok := true
	for path in Obstacles.scenes():
		var scene: Node = Sim.add(load(path).instantiate())
		var md5 := Obstacles.fingerprint(scene).md5_text()
		scene.free()
		if Obstacles.FINGERPRINTS.get(path, "") != md5:
			print("        %s: %s" % [path, md5])
			ok = false
	return ok
