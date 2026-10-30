extends RefCounted
# Story 27.2: paint, lights and decals. A drone wears its slot's livery: each
# colour on its part, the heading lights in every livery, a decal and a race
# number on top; the default is the drone as it was; materials are shared.

const Sim = preload("res://tests/sim.gd")

## The drone's materials before the hangar (Story 9.3's look), in build order:
## [albedo, metallic, roughness, emission (or null), energy, transparency, shading].
const TODAY := [
	[Color(0.055, 0.06, 0.07), 0.35, 0.4, null, 1.0, 0, 1], # 0 carbon
	[Color(0.1, 0.1, 0.12), 0.1, 0.6, null, 1.0, 0, 1], # 1 battery
	[Color(0.95, 0.68, 0.12), 0.2, 0.5, null, 1.0, 0, 1], # 2 accent
	[Color(0.18, 0.18, 0.2), 0.85, 0.3, null, 1.0, 0, 1], # 3 metal
	[Color(0.2, 0.08, 0.04), 0.3, 0.4, Color(1.0, 0.45, 0.12), 0.0, 0, 1], # 4 motor ring
	[Color(0.08, 0.08, 0.09), 0.1, 0.5, null, 1.0, 1, 1], # 5 blade
	[Color(0.75, 0.75, 0.8, 0.0), 0.0, 0.3, null, 1.0, 1, 0], # 6 blur disc
	[Color(1, 0.95, 0.85), 0.0, 0.5, Color(1, 0.95, 0.85), 4.0, 0, 1], # 7 front light
	[Color(1, 0.08, 0.05), 0.0, 0.5, Color(1, 0.08, 0.05), 4.0, 0, 1], # 8 back light
]
## Which of TODAY each mesh wore, in build order.
const TODAY_MESHES := [0, 0, 1, 2, 3, 0, 2, 3, 4, 5, 6, 0, 2, 3, 4, 5, 6, 0, 2, 3, 4, 5, 6,
	0, 2, 3, 4, 5, 6, 7, 8, 7, 8]

func _livery(seed: int, decal: StringName = &"lotus") -> Livery:
	var l := Livery.new()
	l.body_color = Color.from_hsv(fposmod(seed * 0.13, 1.0), 0.7, 0.6)
	l.arm_color = Color.from_hsv(fposmod(seed * 0.13 + 0.3, 1.0), 0.6, 0.5)
	l.prop_color = Color.from_hsv(fposmod(seed * 0.13 + 0.5, 1.0), 0.5, 0.4)
	l.canopy_color = Color.from_hsv(fposmod(seed * 0.13 + 0.7, 1.0), 0.4, 0.3)
	l.light_color = Color.from_hsv(fposmod(seed * 0.13 + 0.1, 1.0), 0.9, 1.0)
	l.decal_color = Color.from_hsv(fposmod(seed * 0.13 + 0.2, 1.0), 0.8, 0.9)
	l.glow = true
	l.decal = decal
	l.race_number = 7 + seed
	return l

func _look(l: Livery) -> DroneLook:
	var look := DroneLook.new()
	look.wear(l)
	return look

func _meshes(look: DroneLook) -> Array:
	return look.find_children("*", "MeshInstance3D", true, false)

func _same(a: Color, b: Color) -> bool:
	return a.is_equal_approx(b)

## The materials a drone wears that follow only its livery (not a motor's thrust).
func _livery_mats(look: DroneLook) -> Array:
	var out := []
	var own: Array = look._rings + look._blades + look._discs
	for mi in _meshes(look):
		var m: Material = mi.material_override
		if not m in own and not m in out:
			out.append(m)
	return out

func test_each_colour_on_its_part() -> bool:
	var l := _livery(3)
	var look := _look(l)
	var parts := look.get_children()
	var mat := func(i: int) -> StandardMaterial3D: return (parts[i] as MeshInstance3D).material_override
	var ok: bool = _same(mat.call(0).albedo_color, l.body_color) and _same(mat.call(1).albedo_color, l.canopy_color) \
		and _same(mat.call(3).albedo_color, l.light_color) and _same(mat.call(5).albedo_color, l.arm_color)
	for blade in look._blades:
		ok = ok and _same(Color(blade.albedo_color, 1.0), l.prop_color)
	# Lit: the under-glow and four arm strips glow in the light colour.
	var lit := 0
	var stickers := []
	for mi in _meshes(look):
		var m: StandardMaterial3D = mi.material_override
		if m.emission_enabled and _same(m.emission, l.light_color) and m.emission_energy_multiplier > 0.0:
			lit += 1
		if mi.mesh is QuadMesh:
			stickers.append(m)
	ok = ok and lit == 1 + Drone.MOTOR_COUNT and stickers.size() == 2
	for m in stickers:
		ok = ok and _same(m.albedo_color, l.decal_color) and m.albedo_texture != null
	ok = ok and stickers[0].albedo_texture == DecalArt.texture(&"lotus") \
		and stickers[1].albedo_texture == DecalArt.number_texture(l.race_number)
	look.free()
	# Unlit, no decal and no number: none of those parts, the strips still painted.
	l.glow = false
	l.decal = &""
	l.race_number = 0
	look = _look(l)
	for mi in _meshes(look):
		var m: StandardMaterial3D = mi.material_override
		ok = ok and not mi.mesh is QuadMesh and not (m.emission_enabled and _same(m.emission, l.light_color))
	ok = ok and _same(look.get_child(3).material_override.albedo_color, l.light_color)
	look.free()
	return ok

func test_heading_lights_in_every_livery() -> bool:
	var liveries: Array[Livery] = [null]
	for i in Hangar.catalog.decals.size():
		liveries.append(_livery(i, Hangar.catalog.decals[i]))
	# Even a livery lit white or red keeps its heading lights where they were.
	var white := _livery(1)
	white.light_color = DroneLook.FRONT_LIGHT
	var red := _livery(2)
	red.light_color = DroneLook.BACK_LIGHT
	liveries.append_array([white, red])
	var ok := true
	for l in liveries:
		var look := _look(l)
		var front := 0
		var back := 0
		for mi in _meshes(look):
			var m: StandardMaterial3D = mi.material_override
			if not (m.emission_enabled and m.emission_energy_multiplier == 4.0):
				continue
			if _same(m.emission, DroneLook.FRONT_LIGHT) and mi.position.z < -0.1:
				front += 1
			elif _same(m.emission, DroneLook.BACK_LIGHT) and mi.position.z > 0.1:
				back += 1
		ok = ok and front == 2 and back == 2
		look.free()
	return ok

func test_every_decal_draws_on_the_hull() -> bool:
	var ok := Hangar.catalog.decals.size() >= 8
	for id in [&"block_print", &"jharokha", &"chakra", &"lotus", &"peacock", &"sun", &"stripes", &"team"]:
		ok = ok and id in Hangar.catalog.decals
	for id in Hangar.catalog.decals:
		var tex := DecalArt.texture(id)
		var img := DecalArt.image(id)
		var inked := 0
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				if img.get_pixel(x, y).a > 0.5:
					inked += 1
		# Some of the square is drawn, and not all of it.
		ok = ok and tex != null and inked > 40 and inked < 1000
		var look := _look(_livery(0, id))
		var on_top := _meshes(look).filter(func(mi): return mi.mesh is QuadMesh and mi.material_override.albedo_texture == tex)
		# Above the canopy's top face, facing up.
		ok = ok and on_top.size() == 1 and on_top[0].position.y > 0.0475 \
			and on_top[0].basis.z.is_equal_approx(Vector3.UP)
		look.free()
	# The team emblem is in the team's colours, whatever the decal colour.
	var colors: Array[Color] = [Color8(204, 26, 51), Color8(242, 230, 77)]
	var emblem := DecalArt.image(&"team", colors)
	ok = ok and emblem.get_pixel(64, 40).is_equal_approx(colors[0]) and emblem.get_pixel(64, 2).a == 0.0
	var found_second := false
	for y in 128:
		found_second = found_second or emblem.get_pixel(64, y).is_equal_approx(colors[1])
	Career.team_id = &"halcyon_racing"
	var team_colors := DroneLook.team_colors()
	var look := _look(_livery(0, &"team"))
	var sticker = _meshes(look).filter(func(mi): return mi.mesh is QuadMesh)[0].material_override
	ok = ok and found_second and team_colors[0] == Career.team().colors[0] \
		and sticker.albedo_texture == DecalArt.texture(&"team", team_colors) and sticker.albedo_color == Color.WHITE
	look.free()
	Career.load_saved()
	# Numbers draw from 1 to 99; an unknown decal draws nothing.
	ok = ok and DecalArt.number_texture(1) != null and DecalArt.number_texture(99) != null \
		and DecalArt.texture(&"no_such_decal") == null
	return ok

func test_default_livery_looks_as_before() -> bool:
	var ok := true
	for l in [null, Hangar.catalog.default_livery, Livery.new()]:
		var look := DroneLook.new()
		if l:
			look.wear(l)
		else:
			look._build()
		var meshes := _meshes(look)
		ok = ok and meshes.size() == TODAY_MESHES.size()
		for i in mini(meshes.size(), TODAY_MESHES.size()):
			var m: StandardMaterial3D = meshes[i].material_override
			var want: Array = TODAY[TODAY_MESHES[i]]
			ok = ok and m.albedo_color.is_equal_approx(want[0]) and is_equal_approx(m.metallic, want[1]) \
				and is_equal_approx(m.roughness, want[2]) and m.emission_enabled == (want[3] != null) \
				and (want[3] == null or (m.emission.is_equal_approx(want[3]) and is_equal_approx(m.emission_energy_multiplier, want[4]))) \
				and m.transparency == want[5] and m.shading_mode == want[6] and m.albedo_texture == null
		look.free()
	return ok

func test_ten_liveries_add_no_more_than_ten_sets() -> bool:
	# One drone's set: its livery materials plus its own per-motor ones.
	var one := _look(_livery(0))
	var set_size := _livery_mats(one).size()
	var own_size: int = one._rings.size() + one._blades.size() + one._discs.size()
	var before := {}
	for m in _livery_mats(one):
		before[m] = true
	one.free()
	var root := Node3D.new()
	Sim.add(root)
	var looks: Array[DroneLook] = []
	for i in 10:
		var d: Drone = Sim.DRONE.instantiate()
		d.freeze = true
		root.add_child(d)
		d.position = Vector3(i, 0, 0)
		var look: DroneLook = d.get_node("Look")
		look.wear(_livery(i))
		looks.append(look)
	var shared := {}
	var own := {}
	for look in looks:
		for m in _livery_mats(look):
			shared[m] = true
		for m in look._rings + look._blades + look._discs:
			own[m] = true
	var ok := shared.size() <= 10 * set_size and own.size() == 10 * own_size
	# A second drone in a livery already flying adds no livery materials.
	var again: Drone = Sim.DRONE.instantiate()
	root.add_child(again)
	again.get_node("Look").wear(_livery(4))
	for m in _livery_mats(again.get_node("Look")):
		ok = ok and shared.has(m)
	# The stock drones' carbon, metal and lights are one set between them all.
	var stock: Array[Material] = []
	for i in 3:
		var d: Drone = Sim.DRONE.instantiate()
		root.add_child(d)
		for m in _livery_mats(d.get_node("Look")):
			if not m in stock:
				stock.append(m)
	root.free()
	return ok and stock.size() <= 6 and before.size() == set_size

func test_the_players_drone_wears_slot_zero() -> bool:
	var l := _livery(5, &"chakra")
	Hangar.set_livery(0, l)
	var d: Drone = Sim.drone(Sim.intent())
	var look: DroneLook = d.get_node("Look")
	# A crew face, or anything else put under the look, stays through a re-dress.
	var face := Node3D.new()
	look.add_child(face)
	var mass := d.mass
	var arm := d.arm_length
	Garage.apply(d)
	var body: StandardMaterial3D = look.get_child(1).material_override if look.get_child(0) == face else look.get_child(0).material_override
	var ok := look.worn().to_dict() == l.to_dict() and is_instance_valid(face) and face.get_parent() == look \
		and _meshes(look).any(func(mi): return mi.material_override.albedo_texture == DecalArt.texture(&"chakra")) \
		and d.mass == mass and d.arm_length == arm and look._props.size() == Drone.MOTOR_COUNT
	ok = ok and _same(body.albedo_color, l.body_color)
	# Props still spin after the re-dress; looks never touch physics.
	d.set_motor_thrusts(PackedFloat32Array([2.0, 2.0, 2.0, 2.0]))
	look.update_look(1.0 / 60.0)
	ok = ok and look.spin_rates[0] != 0.0 and d.get_node("Shape").shape.size == Vector3(0.4, 0.12, 0.4)
	# A drone that is not slot 0's (a fleet's) keeps the default until set.
	var other: Drone = Sim.DRONE.instantiate()
	Sim.add(other)
	ok = ok and other.get_node("Look").worn() == Hangar.catalog.default_livery
	other.free()
	d.free()
	return ok
