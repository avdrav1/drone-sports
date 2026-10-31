extends RefCounted
# Story 29.1: each pilot's drone, shaped like the pilot's animal. Every pilot
# has a body kit (Arjuna's white horse, Hanuman's monkey, Abhimanyu's lion cub,
# Jatayu's vulture); the kits differ in shape and colour; the player's drone
# wears the chosen pilot's, a fleet drone and a bare drone none; the kit is
# meshes only, inside the collision box, clear of the props, motors and
# heading lights, and stats and physics stay as they were; the livery still
# paints the drone and the coat, and its decal and number still show.

const Sim = preload("res://tests/sim.gd")
const ANIMALS := {&"arjuna": &"horse", &"hanuman": &"monkey", &"abhimanyu": &"lion_cub", &"jatayu": &"vulture"}
## The drone's collision box, half sizes.
const BOX := Vector3(0.2, 0.06, 0.2)
## The props' swept discs: radius round each motor, and the band of height
## they turn in; the motor bells' radius and height.
const PROP_RADIUS := 0.09
const PROP_BAND := Vector2(0.026, 0.046)
const MOTOR_RADIUS := 0.026
const MOTOR_TOP := 0.04

func _kit(pilot: StringName) -> BodyKit:
	for c in PlayerProfile.pilots():
		if c.id == pilot:
			return c.body_kit
	return null

func _livery(seed: int) -> Livery:
	var l := Livery.new()
	l.body_color = Color.from_hsv(fposmod(seed * 0.17, 1.0), 0.7, 0.6)
	l.arm_color = Color.from_hsv(fposmod(seed * 0.17 + 0.3, 1.0), 0.6, 0.5)
	l.prop_color = Color.from_hsv(fposmod(seed * 0.17 + 0.5, 1.0), 0.5, 0.4)
	l.canopy_color = Color.from_hsv(fposmod(seed * 0.17 + 0.7, 1.0), 0.4, 0.3)
	l.light_color = Color.from_hsv(fposmod(seed * 0.17 + 0.1, 1.0), 0.9, 1.0)
	l.decal_color = Color.from_hsv(fposmod(seed * 0.17 + 0.2, 1.0), 0.8, 0.9)
	l.glow = true
	l.decal = &"lotus"
	l.race_number = 29
	return l

## A look in `kit` and `l`, on a hull of `hull`.
func _look(kit: BodyKit, l: Livery = null, hull := Vector3.ONE) -> DroneLook:
	var look := DroneLook.new()
	look.wear(l, hull, kit)
	return look

## Every vertex of the kit's meshes, in the look's space.
func _points(look: DroneLook) -> PackedVector3Array:
	var out := PackedVector3Array()
	var shell := look.get_node_or_null(AnimalShell.NAME)
	if shell == null:
		return out
	for mi: MeshInstance3D in shell.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != look:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		for v in mi.mesh.get_faces():
			out.append(t * v)
	return out

func _meshes(node: Node) -> Array:
	return node.find_children("*", "MeshInstance3D", true, false)

func test_every_pilot_has_an_animal_kit() -> bool:
	var ok := PlayerProfile.pilots().size() == ANIMALS.size()
	for c in PlayerProfile.pilots():
		var kit := c.body_kit
		ok = ok and kit != null and kit.validate().is_empty() and c.validate().is_empty() \
			and kit.animal == ANIMALS.get(c.id) and kit.animal in AnimalShell.PARTS
	# The crew bring no kit: only pilots fly the player's drone.
	for c in Roster.characters.values():
		ok = ok and (c.body_kit == null or &"pilot" in c.tags)
	return ok

func test_the_kits_differ_in_shape_and_colour() -> bool:
	var ok := true
	var seen := []
	for a in ANIMALS:
		var ka := _kit(a)
		var la := _look(ka)
		var shell_a: Node3D = la.get_node(AnimalShell.NAME)
		var parts_a := shell_a.get_children().map(func(n): return n.name)
		var pa := _points(la)
		for b in seen:
			var kb := _kit(b)
			var lb := _look(kb)
			var parts_b: Array = lb.get_node(AnimalShell.NAME).get_children().map(func(n): return n.name)
			var pb := _points(lb)
			# A different outline: other parts, or as many parts made differently.
			ok = ok and ka.id != kb.id and ka.animal != kb.animal \
				and (parts_a != parts_b or pa.size() != pb.size())
			# Far apart in colour: body paint and mane.
			ok = ok and _far(ka.paint.body_color, kb.paint.body_color) and _far(ka.mane, kb.mane)
			lb.free()
		seen.append(a)
		la.free()
	return ok

func _far(a: Color, b: Color) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() > 0.2

func test_the_players_drone_wears_the_chosen_pilots_animal() -> bool:
	var ok := true
	for pilot in ANIMALS:
		ok = ok and PlayerProfile.choose_pilot(pilot)
		var d: Drone = Sim.drone(Sim.intent())
		Garage.apply(d)
		var look: DroneLook = d.get_node("Look")
		var shell := look.get_node_or_null(AnimalShell.NAME)
		ok = ok and look.kit == _kit(pilot) and shell != null and shell.get_meta(&"animal") == ANIMALS[pilot]
		for part in AnimalShell.PARTS[ANIMALS[pilot]]:
			ok = ok and shell != null and shell.has_node(String(part)) and not _meshes(shell.get_node(String(part))).is_empty()
		# Only one shell, and a re-dress builds it again rather than adding one.
		Hangar.dress(d)
		ok = ok and look.find_children(AnimalShell.NAME, "", false, false).size() == 1
		# Unpainted, the stock carbon wears the animal's own paint.
		var body: StandardMaterial3D = look.get_child(0).material_override
		ok = ok and body.albedo_color.is_equal_approx(_kit(pilot).paint.body_color)
		# The hangar's turntable shows the same animal on the player's slot.
		ok = ok and Hangar.kit(0) == _kit(pilot)
		d.free()
	return ok

func test_fleet_and_bare_drones_wear_no_animal() -> bool:
	PlayerProfile.choose_pilot(&"jatayu")
	var fleet: Drone = Sim.drone(Sim.intent())
	Garage.apply(fleet, 1)
	var bare: Drone = Sim.DRONE.instantiate()
	Sim.add(bare)
	var ok: bool = not fleet.get_node("Look").has_node(AnimalShell.NAME) and fleet.get_node("Look").kit == null \
		and not bare.get_node("Look").has_node(AnimalShell.NAME) and Hangar.kit(1) == null
	fleet.free()
	bare.free()
	# The Lattice's still drones (Story 8.2) are the stock body.
	var still := DroneLook.still_mesh()
	var stock := DroneLook.new()
	stock._build()
	ok = ok and still.get_surface_count() == 1 and not stock.has_node(AnimalShell.NAME)
	stock.free()
	return ok

func test_stats_mass_and_collision_are_unchanged() -> bool:
	var ok := true
	for pilot in ANIMALS:
		PlayerProfile.choose_pilot(pilot)
		var d: Drone = Sim.drone(Sim.intent())
		var assists := d.assists.assists().size()
		Garage.apply(d)
		var want := Garage.stats_with(Hangar.parts(0))
		for stat in Part.STATS:
			ok = ok and is_equal_approx(d.get(stat), want[stat])
		var shape: CollisionShape3D = d.get_node("Shape")
		ok = ok and d.mass == want[&"mass"] and shape.shape.size == Vector3(0.4, 0.12, 0.4) \
			and shape.transform == Transform3D.IDENTITY \
			and d.find_children("*", "CollisionShape3D", true, false).size() == 1 \
			and d.get_node("Look").find_children("*", "CollisionObject3D", true, false).is_empty() \
			and d.assists.assists().size() == assists
		# Props still spin under the kit.
		var look: DroneLook = d.get_node("Look")
		d.set_motor_thrusts(PackedFloat32Array([2.0, 2.0, 2.0, 2.0]))
		look.update_look(1.0 / 60.0)
		ok = ok and look._props.size() == Drone.MOTOR_COUNT and look.spin_rates[0] != 0.0
		d.free()
	return ok

## Every frame's hull: the shell stays in the collision box, off the prop
## discs and motors, and out of the heading lights' way.
func test_the_shell_stays_in_the_box_and_clear() -> bool:
	# Each frame's hull, and its arm length: stock 0.15 plus its step.
	var frames := {Vector3.ONE: 0.15}
	for p in Hangar.catalog.parts:
		if p.kind == &"frame":
			frames[p.hull] = 0.15
			for step in p.stats:
				if step.stat == &"arm_length":
					frames[p.hull] += step.step
	var out := []
	for pilot in ANIMALS:
		for hull in frames:
			var look := _look(_kit(pilot), null, hull)
			var pts := _points(look)
			if pts.is_empty():
				out.append("%s: no shell" % pilot)
			for v in pts:
				if absf(v.x) > BOX.x or absf(v.y) > BOX.y or absf(v.z) > BOX.z:
					out.append("%s %s: %s outside the box" % [pilot, hull, v])
					break
			out.append_array(_clear(pilot, hull, frames[hull], pts))
			look.free()
	for line in out.slice(0, 12):
		print("        ", line)
	return out.is_empty()

func _clear(pilot: StringName, hull: Vector3, arm: float, pts: PackedVector3Array) -> Array:
	var out := []
	for v in pts:
		for i in Drone.MOTOR_COUNT:
			var m := Drone.motor_offset(i, arm)
			var flat := Vector2(v.x - m.x, v.z - m.z).length()
			if flat < PROP_RADIUS and v.y > PROP_BAND.x and v.y < PROP_BAND.y:
				return ["%s %s: %s in prop %d's disc" % [pilot, hull, v, i]]
			if flat < MOTOR_RADIUS and v.y < MOTOR_TOP:
				return ["%s %s: %s in motor %d" % [pilot, hull, v, i]]
		# Nothing in front of a white light or behind a red one (each 12 mm
		# wide and 10 mm tall, at the hull's corners).
		for side in [-1.0, 1.0]:
			var lx: float = side * 0.045 * hull.x
			if absf(v.x - lx) < 0.006 and absf(v.y) < 0.006 and absf(v.z) > 0.105 * hull.z:
				return ["%s %s: %s over a heading light" % [pilot, hull, v]]
	return []

func test_the_livery_paints_over_the_animal() -> bool:
	var ok := true
	for pilot in ANIMALS:
		var kit := _kit(pilot)
		var l := _livery(ANIMALS.keys().find(pilot))
		var look := _look(kit, l)
		var mats := _meshes(look).map(func(mi): return mi.material_override)
		var body: StandardMaterial3D = look.get_child(0).material_override
		var canopy: StandardMaterial3D = look.get_child(1).material_override
		var head: MeshInstance3D = _meshes(look.get_node(AnimalShell.NAME + "/Head"))[0]
		# The livery's own colours win over the kit's paint, and the coat follows the body.
		ok = ok and look.worn() == l and body.albedo_color.is_equal_approx(l.body_color) \
			and canopy.albedo_color.is_equal_approx(l.canopy_color) \
			and (head.material_override as StandardMaterial3D).albedo_color.is_equal_approx(l.body_color)
		for blade in look._blades:
			ok = ok and Color(blade.albedo_color, 1.0).is_equal_approx(l.prop_color)
		# Decal and number on top, the lit strips, and the heading lights.
		var stickers := _meshes(look).filter(func(mi): return mi.mesh is QuadMesh)
		ok = ok and stickers.size() == 2 and stickers[0].material_override.albedo_texture == DecalArt.texture(&"lotus") \
			and stickers[1].material_override.albedo_texture == DecalArt.number_texture(29)
		var lit := 0
		var front := 0
		var back := 0
		for m: StandardMaterial3D in mats:
			if m.emission_enabled and m.emission.is_equal_approx(l.light_color) and m.emission_energy_multiplier > 0.0:
				lit += 1
			if m.emission_enabled and m.emission.is_equal_approx(DroneLook.FRONT_LIGHT):
				front += 1
			if m.emission_enabled and m.emission.is_equal_approx(DroneLook.BACK_LIGHT):
				back += 1
		ok = ok and lit == 1 + Drone.MOTOR_COUNT and front == 2 and back == 2
		# Nothing of the shell sits on the decal or the number.
		for v in _points(look):
			var on_decal := absf(v.x) < DroneLook.DECAL_SIZE / 2.0 and absf(v.z - DroneLook.DECAL_AT.z) < DroneLook.DECAL_SIZE / 2.0 and v.y > DroneLook.DECAL_AT.y - 0.002
			var on_number := absf(v.x) < DroneLook.NUMBER_SIZE.x / 2.0 and absf(v.z - DroneLook.NUMBER_AT.z) < DroneLook.NUMBER_SIZE.y / 2.0 and v.y > DroneLook.NUMBER_AT.y - 0.002
			if on_decal or on_number:
				ok = false
				break
		look.free()
		# The stock livery wears the kit's own paint, decal and number as they are.
		var stock := _look(kit)
		var painted := stock.painted()
		ok = ok and stock.worn() == DroneLook.DEFAULT_LIVERY and painted.body_color == kit.paint.body_color \
			and painted.decal == DroneLook.DEFAULT_LIVERY.decal and painted.race_number == 0 \
			and (stock.get_child(0).material_override as StandardMaterial3D).albedo_color.is_equal_approx(kit.paint.body_color)
		stock.free()
	return ok
