class_name AnimalShell
extends RefCounted
# Story 29.1: the shell a BodyKit adds to the drone's body, one animal per
# pilot, from their epics. Arjuna's white horse (the epithet Svetavahana:
# "white steeds"), Hanuman's monkey, Abhimanyu's lion cub, Jatayu's vulture. Built
# from primitive meshes like the rest of DroneLook, under a "Kit" node: one
# group per part (Head, Ears, Mane, Tail, Wings, Beak, Ruff), so each animal
# reads from the chase camera by its outline as well as its colours.
# Story 29.2: a rounded body and legs, so it is the animal carrying the deck
# rather than a box wearing a head. DroneLook slims the hull to fit inside. The
# canopy and the battery sit on its back like a saddle, carrying the decal and
# the number. Each group is merged into one mesh per material, so a shell of
# hundreds of pieces costs a handful of draw calls.
#
# Meshes only, with no body: mass, shape and flight never change (rules 1 and
# 5). Every piece stays inside the drone's collision box, clear of the prop
# discs, the motors and the white front and red back heading lights. The
# coat follows the livery's body colour, so painting the drone paints the
# animal; the mane, details and trim are the kit's own.

const NAME := "Kit"
## Hanuman's crown and gada, and the tilak: from the portrait's look.
const GOLD := Color(0.96, 0.76, 0.3)
const TILAK := Color(0.78, 0.14, 0.08)
## Each animal's part groups, by name. Every one is built.
const PARTS := {
	&"horse": [&"Body", &"Head", &"Ears", &"Mane", &"Legs", &"Tail"],
	&"monkey": [&"Body", &"Head", &"Ears", &"Legs", &"Gada", &"Tail"],
	&"lion_cub": [&"Body", &"Head", &"Ears", &"Mane", &"Legs", &"Tail"],
	&"vulture": [&"Body", &"Head", &"Beak", &"Ruff", &"Wings", &"Legs", &"Tail"],
}

## The shell for `kit`, its coat in `l`'s body colour, on a hull of `hull`
## (x and z follow the frame, but never taller or longer than stock, so it stays
## in the box and behind the FPV camera).
static func build(kit: BodyKit, l: Livery, hull := Vector3.ONE) -> Node3D:
	var root := Node3D.new()
	root.name = NAME
	root.set_meta(&"animal", kit.animal)
	root.scale = Vector3(hull.x, minf(hull.y, 1.0), minf(hull.z, 1.0))
	var groups := {}
	for part in PARTS.get(kit.animal, []):
		var g := Node3D.new()
		g.name = part
		root.add_child(g)
		groups[part] = g
	var coat := _fur(l.body_color)
	var mane := _fur(kit.mane)
	var detail := _gloss(kit.detail)
	var trim := _fur(kit.trim)
	match kit.animal:
		&"horse":
			_horse(groups, coat, mane, detail, trim)
		&"monkey":
			_monkey(groups, coat, mane, detail, trim)
		&"lion_cub":
			_lion_cub(groups, coat, mane, _fur(kit.mane.darkened(0.3)), detail, trim)
		&"vulture":
			_vulture(groups, coat, _fur(l.body_color.lightened(0.3)), mane, detail, trim)
	for g in groups.values():
		_merge(g)
	return root

## Bakes everything under `group` into one mesh per material.
static func _merge(group: Node3D) -> void:
	var parts := {}
	for mi: MeshInstance3D in group.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != group:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		parts.get_or_add(mi.material_override, []).append([mi.mesh, t])
	for child in group.get_children():
		child.free()
	for mat in parts:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in parts[mat]:
			st.append_from(part[0], 0, part[1])
		_put(group, st.commit(), Vector3.ZERO, mat)

# The white horse at the gallop: a deep barrel between withers and croup, an
# arched neck, a long head carried low with a gold noseband, pricked ears, a
# mane falling to one side, legs reaching and gathered with dark hooves, and a
# long plume of a tail.
static func _horse(g: Dictionary, coat: Material, mane: Material, detail: Material, trim: Material) -> void:
	var body: Node3D = g[&"Body"]
	_ball(body, Vector3(0.066, 0.033, 0.118), Vector3(0, 0.01, 0), coat)
	_ball(body, Vector3(0.037, 0.03, 0.04), Vector3(0, 0.024, -0.095), coat)
	_ball(body, Vector3(0.037, 0.03, 0.045), Vector3(0, 0.018, 0.115), coat)
	var head: Node3D = g[&"Head"]
	_rod(head, Vector3(0, 0.02, -0.095), Vector3(0, 0.036, -0.118), 0.027, 0.017, coat)
	_ball(head, Vector3(0.016, 0.017, 0.02), Vector3(0, 0.036, -0.12), coat)
	# A deep jaw and a broad square muzzle on a head held nearly level.
	_ball(head, Vector3(0.018, 0.022, 0.024), Vector3(0, 0.029, -0.128), coat)
	_rod(head, Vector3(0, 0.032, -0.128), Vector3(0, 0.016, -0.158), 0.018, 0.0145, coat)
	_ball(head, Vector3(0.016, 0.0145, 0.016), Vector3(0, 0.014, -0.16), coat)
	_rod(head, Vector3(0, 0.0235, -0.144), Vector3(0, 0.0205, -0.15), 0.0167, 0.016, trim)
	# The forelock.
	_rod(g[&"Mane"], Vector3(0, 0.05, -0.122), Vector3(0, 0.036, -0.143), 0.006, 0.002, mane)
	for side in [-1.0, 1.0]:
		_ball(head, Vector3.ONE * 0.004, Vector3(side * 0.018, 0.034, -0.132), detail)
		_ball(head, Vector3.ONE * 0.003, Vector3(side * 0.0075, 0.014, -0.175), detail)
		_rod(g[&"Ears"], Vector3(side * 0.009, 0.045, -0.118), Vector3(side * 0.012, 0.0595, -0.121), 0.0065, 0.0012, coat)
		_ball(body, Vector3(0.026, 0.03, 0.03), Vector3(side * 0.042, 0.006, -0.065), coat)
		_ball(body, Vector3(0.032, 0.034, 0.038), Vector3(side * 0.042, 0.008, 0.066), coat)
	# A crest along the neck, its locks falling to one side.
	for i in 6:
		var t := i / 5.0
		var blade := _box(g[&"Mane"], Vector3(0.007, 0.015, 0.016), Vector3(0, lerpf(0.046, 0.044, t), lerpf(-0.122, -0.078, t)), mane)
		blade.rotation.x = -0.5
		_rod(g[&"Mane"], Vector3(0.008, lerpf(0.046, 0.044, t), lerpf(-0.122, -0.078, t)), Vector3(0.03, lerpf(0.02, 0.016, t), lerpf(-0.122, -0.07, t)), 0.007, 0.002, mane)
	# One foreleg reaching, one gathered; both hind legs driving back.
	_limb(g[&"Legs"], [Vector3(0.04, -0.008, -0.08), Vector3(0.044, -0.034, -0.11), Vector3(0.042, -0.049, -0.135)], 0.015, 0.0055, coat)
	_limb(g[&"Legs"], [Vector3(-0.04, -0.008, -0.08), Vector3(-0.044, -0.036, -0.1), Vector3(-0.042, -0.049, -0.075)], 0.015, 0.0055, coat)
	_ball(g[&"Legs"], Vector3(0.009, 0.008, 0.011), Vector3(0.042, -0.05, -0.138), detail)
	_ball(g[&"Legs"], Vector3(0.009, 0.008, 0.011), Vector3(-0.042, -0.05, -0.072), detail)
	for side in [-1.0, 1.0]:
		_limb(g[&"Legs"], [Vector3(side * 0.042, -0.012, 0.07), Vector3(side * 0.046, -0.036, 0.098), Vector3(side * 0.042, -0.049, 0.132)], 0.017, 0.0055, coat)
		_ball(g[&"Legs"], Vector3(0.009, 0.008, 0.011), Vector3(side * 0.042, -0.05, 0.136), detail)
	for k in 5:
		var side := (k - 2) / 2.0
		_tube(g[&"Tail"], [Vector3(side * 0.004, 0.03, 0.148), Vector3(side * 0.007, 0.036, 0.162),
			Vector3(side * 0.012, 0.018, 0.172), Vector3(side * 0.018, -0.015, 0.176), Vector3(side * 0.022, -0.052, 0.176)],
			0.0095, 0.0035, mane)

# Hanuman's monkey in the leap, as in the portrait: a lean body, long arms
# reaching ahead and long legs trailing, a heart-shaped ruddy face with a level
# brow, a calm mouth and a tilak (worshipped: dignified, never comic), the gold
# crown, the gada in the left hand, and the long tail curled in a spiral behind.
static func _monkey(g: Dictionary, coat: Material, mane: Material, detail: Material, trim: Material) -> void:
	var gold := _gloss(GOLD)
	var red := _gloss(TILAK)
	var body: Node3D = g[&"Body"]
	_ball(body, Vector3(0.054, 0.03, 0.1), Vector3(0, 0.012, 0), coat)
	_ball(body, Vector3(0.037, 0.028, 0.034), Vector3(0, 0.012, -0.075), coat)
	_ball(body, Vector3(0.037, 0.026, 0.036), Vector3(0, 0.012, 0.095), coat)
	var head: Node3D = g[&"Head"]
	_ball(head, Vector3(0.04, 0.032, 0.036), Vector3(0, 0.016, -0.128), coat)
	_ball(head, Vector3(0.021, 0.015, 0.014), Vector3(0, 0.006, -0.16), trim)
	_rod(head, Vector3(-0.024, 0.034, -0.156), Vector3(0.024, 0.034, -0.156), 0.0035, 0.0035, mane)
	_rod(head, Vector3(0, 0.029, -0.163), Vector3(0, 0.037, -0.158), 0.002, 0.0015, red)
	_rod(head, Vector3(-0.012, 0.0045, -0.1725), Vector3(0, 0.0032, -0.1735), 0.0009, 0.0009, detail)
	_rod(head, Vector3(0, 0.0032, -0.1735), Vector3(0.012, 0.0045, -0.1725), 0.0009, 0.0009, detail)
	# The crown: a gold band on the head and five peaks, the middle one tallest.
	_disc(head, 0.024, 0.008, Vector3(0, 0.05, -0.128), gold)
	_rod(head, Vector3(0, 0.05, -0.128), Vector3(0, 0.0595, -0.128), 0.011, 0.001, gold)
	for side in [-1.0, 1.0]:
		_ball(head, Vector3(0.017, 0.015, 0.008), Vector3(side * 0.012, 0.024, -0.158), trim)
		_ball(head, Vector3.ONE * 0.0048, Vector3(side * 0.012, 0.025, -0.1655), detail)
		_ball(head, Vector3.ONE * 0.0016, Vector3(side * 0.0035, 0.011, -0.1735), detail)
		for z in [-0.146, -0.11]:
			_rod(head, Vector3(side * 0.018, 0.05, z), Vector3(side * 0.018, 0.057, z), 0.007, 0.001, gold)
		# Round ears at eye height, standing out from the sides of the head.
		var ear := _disc(g[&"Ears"], 0.017, 0.006, Vector3(side * 0.045, 0.027, -0.122), coat)
		ear.rotation = Vector3(PI / 2.0, -side * 0.5, 0.0)
		var inner := _disc(g[&"Ears"], 0.011, 0.002, Vector3(side * 0.047, 0.027, -0.1265), trim)
		inner.rotation = Vector3(PI / 2.0, -side * 0.5, 0.0)
		_limb(g[&"Legs"], [Vector3(side * 0.036, -0.002, 0.08), Vector3(side * 0.056, -0.032, 0.095), Vector3(side * 0.04, -0.048, 0.14)], 0.012, 0.006, coat)
		_ball(g[&"Legs"], Vector3(0.011, 0.008, 0.019), Vector3(side * 0.04, -0.05, 0.15), trim)
	_limb(g[&"Legs"], [Vector3(0.044, 0.0, -0.07), Vector3(0.058, -0.03, -0.095), Vector3(0.04, -0.043, -0.145)], 0.011, 0.0055, coat)
	_ball(g[&"Legs"], Vector3(0.011, 0.008, 0.015), Vector3(0.04, -0.044, -0.155), trim)
	_limb(g[&"Legs"], [Vector3(-0.044, 0.0, -0.07), Vector3(-0.058, -0.032, -0.085), Vector3(-0.046, -0.044, -0.12)], 0.011, 0.0055, coat)
	_ball(g[&"Legs"], Vector3(0.0095, 0.008, 0.011), Vector3(-0.046, -0.045, -0.124), trim)
	# The gada: a long gold mace, its round head ribbed where it meets the haft.
	_rod(g[&"Gada"], Vector3(-0.046, -0.05, -0.1), Vector3(-0.046, -0.04, -0.158), 0.0024, 0.0024, gold)
	_ball(g[&"Gada"], Vector3(0.013, 0.013, 0.015), Vector3(-0.046, -0.037, -0.163), gold)
	var pts := [Vector3(0, 0.012, 0.125), Vector3(0, 0.0, 0.148)]
	var centre := Vector3(0, 0.024, 0.165)
	for i in 25:
		var t := i / 24.0
		var a := -PI / 2.0 + t * 2.6 * PI
		var r := lerpf(0.03, 0.009, t)
		var up := r * sin(a)
		pts.append(centre + Vector3(r * cos(a), up, -0.3 * up))
	_tube(g[&"Tail"], pts, 0.0065, 0.004, mane)

# The lion cub ready to pounce: a heavy body on thick legs and broad paws, a
# broad head with a square muzzle and a dark nose above a split lip, small round
# ears, and a mane all the way round the face; a thin tail held up, its tuft dark.
static func _lion_cub(g: Dictionary, coat: Material, mane: Material, dark: Material, detail: Material, trim: Material) -> void:
	var body: Node3D = g[&"Body"]
	_ball(body, Vector3(0.078, 0.034, 0.114), Vector3(0, 0.01, 0), coat)
	_ball(body, Vector3(0.037, 0.03, 0.03), Vector3(0, 0.008, -0.085), coat)
	_ball(body, Vector3(0.037, 0.028, 0.034), Vector3(0, 0.012, 0.105), coat)
	var head: Node3D = g[&"Head"]
	_ball(head, Vector3(0.036, 0.034, 0.03), Vector3(0, 0.016, -0.128), coat)
	_ball(head, Vector3(0.026, 0.012, 0.012), Vector3(0, 0.03, -0.148), coat)
	_rod(head, Vector3(0, 0.03, -0.152), Vector3(0, 0.014, -0.165), 0.011, 0.008, coat)
	_ball(head, Vector3(0.012, 0.008, 0.01), Vector3(0, -0.008, -0.151), trim)
	_ball(head, Vector3(0.0085, 0.005, 0.004), Vector3(0, 0.0125, -0.1695), detail)
	_rod(head, Vector3(0, 0.008, -0.168), Vector3(0, 0.001, -0.1668), 0.0012, 0.0012, detail)
	for side in [-1.0, 1.0]:
		_ball(head, Vector3(0.0135, 0.011, 0.012), Vector3(side * 0.0115, 0.002, -0.155), trim)
		_ball(head, Vector3.ONE * 0.0065, Vector3(side * 0.015, 0.027, -0.153), trim)
		_ball(head, Vector3.ONE * 0.0042, Vector3(side * 0.015, 0.027, -0.157), detail)
		_ball(g[&"Ears"], Vector3(0.011, 0.01, 0.005), Vector3(side * 0.027, 0.046, -0.124), coat)
		_ball(g[&"Ears"], Vector3(0.006, 0.0055, 0.002), Vector3(side * 0.027, 0.045, -0.1285), detail)
		_ball(body, Vector3(0.03, 0.032, 0.036), Vector3(side * 0.05, 0.006, -0.058), coat)
		_ball(body, Vector3(0.034, 0.034, 0.04), Vector3(side * 0.05, 0.008, 0.064), coat)
		_limb(g[&"Legs"], [Vector3(side * 0.05, -0.01, -0.06), Vector3(side * 0.054, -0.038, -0.075), Vector3(side * 0.05, -0.047, -0.1)], 0.018, 0.011, coat)
		_paw(g[&"Legs"], Vector3(side * 0.05, -0.049, -0.108), coat, trim)
		_limb(g[&"Legs"], [Vector3(side * 0.052, -0.012, 0.065), Vector3(side * 0.058, -0.038, 0.085), Vector3(side * 0.052, -0.047, 0.115)], 0.018, 0.011, coat)
		_paw(g[&"Legs"], Vector3(side * 0.052, -0.049, 0.107), coat, trim)
	# The mane: a solid back, then two rings of tufts all the way round the head,
	# sweeping back.
	var collar: Node3D = g[&"Mane"]
	var centre := Vector3(0, 0.012, -0.097)
	_ball(collar, Vector3(0.052, 0.042, 0.0075), centre, mane)
	for layer in 2:
		var n := 20 - layer * 2
		var reach := 1.0 - layer * 0.22
		for i in n:
			var phi := TAU * (i + layer * 0.5) / n
			var inner := Vector3(cos(phi) * 0.03, sin(phi) * 0.03, 0.0 - layer * 0.003)
			var outer := Vector3(cos(phi) * 0.068 * reach, sin(phi) * 0.043 * reach, 0.02 - layer * 0.008)
			_rod(collar, centre + inner, centre + outer, 0.016 - layer * 0.003, 0.003, mane if (i + layer) % 2 == 0 else dark)
	_tube(g[&"Tail"], [Vector3(0, 0.012, 0.13), Vector3(0, 0.008, 0.15), Vector3(0, 0.018, 0.168), Vector3(0, 0.036, 0.174)], 0.0065, 0.004, coat)
	_ball(g[&"Tail"], Vector3.ONE * 0.012, Vector3(0, 0.044, 0.176), dark)

# The vulture soaring: wings as wide as the drone, spread over its arms, with
# pale coverts and long dark flight feathers fingered at the ends; a pale ruff, a
# bare head high on a thin neck, a hooked beak, tucked talons and a wedge of a tail.
static func _vulture(g: Dictionary, coat: Material, pale: Material, ruff: Material, detail: Material, trim: Material) -> void:
	var body: Node3D = g[&"Body"]
	_ball(body, Vector3(0.06, 0.03, 0.1), Vector3(0, 0.012, 0), coat)
	_ball(body, Vector3(0.037, 0.026, 0.03), Vector3(0, 0.008, -0.082), coat)
	_ball(body, Vector3(0.037, 0.024, 0.032), Vector3(0, 0.012, 0.09), coat)
	var wings: Node3D = g[&"Wings"]
	for side in [-1.0, 1.0]:
		# Under the props' band all the way out, so they can reach past the discs.
		for i in 6:
			_plank(wings, Vector3(side * 0.085, 0.012, -0.035 + i * 0.02), side, deg_to_rad(-20.0 + i * 14.0), 0.072, 0.016, trim)
		for i in 5:
			_plank(wings, Vector3(side * (0.05 + i * 0.012), 0.014, 0.03), side, deg_to_rad(75.0), 0.07, 0.02, trim)
		for i in 5:
			_plank(wings, Vector3(side * 0.04, 0.018, -0.04 + i * 0.016), side, deg_to_rad(-6.0 + i * 12.0), lerpf(0.09, 0.06, i / 4.0), 0.028, pale)
		_rod(wings, Vector3(side * 0.045, 0.02, -0.045), Vector3(side * 0.13, 0.016, -0.05), 0.006, 0.003, pale)
		_limb(g[&"Legs"], [Vector3(side * 0.024, -0.012, 0.045), Vector3(side * 0.03, -0.035, 0.07)], 0.012, 0.007, coat)
		_rod(g[&"Legs"], Vector3(side * 0.03, -0.035, 0.07), Vector3(side * 0.024, -0.043, 0.098), 0.004, 0.0035, detail)
		for toe in [-1.0, 0.0, 1.0]:
			_rod(g[&"Legs"], Vector3(side * 0.024, -0.043, 0.098), Vector3(side * 0.024 + toe * 0.009, -0.053, 0.112), 0.003, 0.0008, trim)
	var head: Node3D = g[&"Head"]
	_rod(head, Vector3(0, 0.02, -0.09), Vector3(0, 0.036, -0.118), 0.014, 0.009, coat)
	_ball(head, Vector3(0.016, 0.015, 0.02), Vector3(0, 0.04, -0.132), pale)
	for side in [-1.0, 1.0]:
		_ball(head, Vector3.ONE * 0.0035, Vector3(side * 0.0135, 0.045, -0.138), trim)
	_rod(g[&"Beak"], Vector3(0, 0.04, -0.148), Vector3(0, 0.036, -0.165), 0.0075, 0.005, detail)
	_rod(g[&"Beak"], Vector3(0, 0.036, -0.165), Vector3(0, 0.02, -0.172), 0.005, 0.001, detail)
	var neck := Vector3(0, 0.022, -0.094)
	_ball(g[&"Ruff"], Vector3(0.026, 0.024, 0.016), neck, ruff)
	for i in 10:
		var phi := TAU * i / 10.0
		_ball(g[&"Ruff"], Vector3.ONE * 0.011, neck + Vector3(cos(phi) * 0.026, sin(phi) * 0.024, 0.002 * (i % 2)), ruff)
	for i in 7:
		var a := deg_to_rad(-30.0 + i * 10.0)
		var dir := Vector3(sin(a), 0, cos(a))
		var plank := _box(g[&"Tail"], Vector3(0.024, 0.003, 0.09), Vector3(0, 0.012 + 0.001 * (i % 2), 0.09) + dir * 0.045, trim)
		plank.rotation.y = a

## A leg or arm through `pts`, thick at the top.
static func _limb(parent: Node3D, pts: Array, r0: float, r1: float, mat: Material) -> void:
	_ball(parent, Vector3.ONE * r0, pts[0], mat)
	_tube(parent, pts, r0, r1, mat)

## A big soft paw at `at`, three pale toes at its front.
static func _paw(parent: Node3D, at: Vector3, coat: Material, trim: Material) -> void:
	_ball(parent, Vector3(0.017, 0.01, 0.021), at, coat)
	for toe in [-1.0, 0.0, 1.0]:
		_ball(parent, Vector3.ONE * 0.005, at + Vector3(toe * 0.009, -0.002, -0.019), trim)

## A flat feather from `root`, out to `side` (1 right, -1 left) and swept back
## by `a` radians.
static func _plank(parent: Node3D, root: Vector3, side: float, a: float, length: float, width: float, mat: Material) -> MeshInstance3D:
	var dir := Vector3(side * cos(a), 0, sin(a))
	var plank := _box(parent, Vector3(length, 0.003, width), root + dir * length * 0.5, mat)
	plank.rotation.y = -side * a
	return plank

## Matte fur or paint, shared by colour.
static func _fur(color: Color) -> Material:
	return DroneLook._shared("kit:" + color.to_html(), func():
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.8
		return m)

## Eyes, a nose, a beak: a little shine.
static func _gloss(color: Color) -> Material:
	return DroneLook._shared("kit_gloss:" + color.to_html(), func():
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.25
		m.metallic = 0.1
		return m)

static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _put(parent, mesh, at, mat)

## An ellipsoid with these radii.
static func _ball(parent: Node3D, radii: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mi := _put(parent, mesh, at, mat)
	mi.scale = radii * 2.0
	return mi

## A flat round, its axis up.
static func _disc(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	return _put(parent, mesh, at, mat)

## A tapered rod from `from` (radius `r_from`) to `to` (radius `r_to`).
static func _rod(parent: Node3D, from: Vector3, to: Vector3, r_from: float, r_to: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r_from
	mesh.top_radius = r_to
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 12
	mesh.rings = 1
	var mi := _put(parent, mesh, (from + to) * 0.5, mat)
	var y := (to - from).normalized()
	var x := y.cross(Vector3.FORWARD) if absf(y.dot(Vector3.FORWARD)) < 0.99 else y.cross(Vector3.RIGHT)
	x = x.normalized()
	mi.basis = Basis(x, y, x.cross(y))
	return mi

## A bending tail through `pts`, tapering from `r0` to `r1`, round at each joint.
static func _tube(parent: Node3D, pts: Array, r0: float, r1: float, mat: Material) -> void:
	var n := pts.size() - 1
	for i in n:
		var ra := lerpf(r0, r1, float(i) / n)
		var rb := lerpf(r0, r1, float(i + 1) / n)
		_rod(parent, pts[i], pts[i + 1], ra, rb, mat)
		_ball(parent, Vector3.ONE * rb, pts[i + 1], mat)

static func _put(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi
