class_name AnimalShell
extends RefCounted
# Story 29.1: the shell a BodyKit adds to the drone's body, one animal per
# pilot, from their epics. Arjuna's white horse (the epithet Svetavahana:
# "white steeds"), Hanuman's monkey, Abhimanyu's lion cub, Jatayu's vulture. Built
# from primitive meshes like the rest of DroneLook, under a "Kit" node: one
# group per part (Head, Ears, Mane, Tail, Wings, Beak, Ruff), so each animal
# reads from the chase camera by its outline as well as its colours.
#
# Meshes only, with no body: mass, shape and flight never change (rules 1 and
# 5). Every piece stays inside the drone's collision box, clear of the prop
# discs, the motors and the white front and red back heading lights. The
# coat follows the livery's body colour, so painting the drone paints the
# animal; the mane, details and trim are the kit's own.

const NAME := "Kit"
## Each animal's part groups, by name. Every one is built.
const PARTS := {
	&"horse": [&"Head", &"Ears", &"Mane", &"Tail"],
	&"monkey": [&"Head", &"Ears", &"Tail"],
	&"lion_cub": [&"Head", &"Ears", &"Mane", &"Tail"],
	&"vulture": [&"Head", &"Beak", &"Ruff", &"Wings", &"Tail"],
}

## The shell for `kit`, its coat in `l`'s body colour, on a hull of `hull`
## (x and z follow the frame; never taller than stock, so it stays in the box).
static func build(kit: BodyKit, l: Livery, hull := Vector3.ONE) -> Node3D:
	var root := Node3D.new()
	root.name = NAME
	root.set_meta(&"animal", kit.animal)
	root.scale = Vector3(hull.x, minf(hull.y, 1.0), hull.z)
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
	return root

# The white horse: a long head held out in front, the muzzle low, a gold band
# round it, pricked ears, a crest of mane down the neck and falling to one
# side, hindquarters behind and a long plume of a tail falling between them.
static func _horse(g: Dictionary, coat: Material, mane: Material, detail: Material, trim: Material) -> void:
	var head: Node3D = g[&"Head"]
	_rod(head, Vector3(0, 0.03, -0.072), Vector3(0, 0.006, -0.162), 0.025, 0.012, coat)
	_ball(head, Vector3(0.021, 0.02, 0.03), Vector3(0, 0.026, -0.104), coat)
	_ball(head, Vector3(0.013, 0.013, 0.018), Vector3(0, 0.005, -0.16), coat)
	_rod(head, Vector3(0, 0.0128, -0.134), Vector3(0, 0.0108, -0.141), 0.0185, 0.0178, trim)
	for side in [-1.0, 1.0]:
		_ball(head, Vector3.ONE * 0.003, Vector3(side * 0.006, 0.007, -0.177), detail)
		_ball(head, Vector3.ONE * 0.0045, Vector3(side * 0.019, 0.03, -0.112), detail)
		_rod(g[&"Ears"], Vector3(side * 0.011, 0.038, -0.096), Vector3(side * 0.015, 0.059, -0.1), 0.007, 0.0015, coat)
	# A crest down the neck, then the mane falls to one side of the canopy,
	# as a horse's does, clear of the decal on top.
	for i in 6:
		var t := i / 5.0
		var blade := _box(g[&"Mane"], Vector3(0.007, 0.018, 0.016), Vector3(0, lerpf(0.04, 0.047, t), lerpf(-0.124, -0.08, t)), mane)
		blade.rotation.x = -0.5
	for i in 8:
		var t := i / 7.0
		var lock := _box(g[&"Mane"], Vector3(0.005, 0.024 + 0.006 * (i % 2), 0.013), Vector3(0.041, 0.036, lerpf(-0.074, 0.012, t)), mane)
		lock.rotation = Vector3(-0.35, 0.0, -0.4)
	# The hindquarters either side of the battery, below its number and ahead
	# of the red back lights, with the tail between them.
	for side in [-1.0, 1.0]:
		_ball(g[&"Tail"], Vector3(0.024, 0.026, 0.032), Vector3(side * 0.036, 0.015, 0.07), coat)
	for k in 5:
		var side := (k - 2) / 2.0
		_tube(g[&"Tail"], [Vector3(side * 0.004, 0.03, 0.104), Vector3(side * 0.006, 0.036, 0.13),
			Vector3(side * 0.012, 0.022, 0.158), Vector3(side * 0.018, -0.006, 0.172), Vector3(side * 0.022, -0.034, 0.176)],
			0.0095, 0.0035, mane)

# The monkey: a big round head out front, a calm pale face under a level
# brow (Hanuman is worshipped: dignified, never comic), round ears out to the
# sides, and a long tail that curls up behind in a spiral facing the chase
# camera.
static func _monkey(g: Dictionary, coat: Material, mane: Material, detail: Material, trim: Material) -> void:
	var head: Node3D = g[&"Head"]
	_ball(head, Vector3(0.042, 0.036, 0.04), Vector3(0, 0.02, -0.128), coat)
	_ball(head, Vector3(0.036, 0.02, 0.032), Vector3(0, 0.036, -0.122), mane)
	_ball(head, Vector3(0.03, 0.026, 0.016), Vector3(0, 0.014, -0.156), trim)
	_ball(head, Vector3(0.021, 0.011, 0.012), Vector3(0, 0.007, -0.163), trim)
	_rod(head, Vector3(-0.021, 0.0355, -0.162), Vector3(0.021, 0.0355, -0.162), 0.0035, 0.0035, mane)
	for side in [-1.0, 1.0]:
		_ball(head, Vector3.ONE * 0.0055, Vector3(side * 0.012, 0.024, -0.17), detail)
		# Round ears out to the sides, turned to face forward and out, so
		# they show either side of the head from behind as well.
		var ear := _disc(g[&"Ears"], 0.018, 0.007, Vector3(side * 0.044, 0.03, -0.118), coat)
		ear.rotation = Vector3(PI / 2.0, -side * 0.5, 0.0)
		var inner := _disc(g[&"Ears"], 0.0115, 0.002, Vector3(side * 0.046, 0.03, -0.1225), trim)
		inner.rotation = Vector3(PI / 2.0, -side * 0.5, 0.0)
	var pts := [Vector3(0, 0.004, 0.104), Vector3(0, 0.0, 0.135)]
	var centre := Vector3(0, 0.032, 0.158)
	for i in 25:
		var t := i / 24.0
		var a := -PI / 2.0 + t * 2.6 * PI
		var r := lerpf(0.026, 0.009, t)
		var up := r * sin(a)
		pts.append(centre + Vector3(r * cos(a), up, -0.3 * up))
	_tube(g[&"Tail"], pts, 0.0065, 0.004, mane)

# The lion cub: a round gold head out front with a pale muzzle and a dark
# nose, small round ears, and a shaggy collar of mane round the head that
# sweeps back past the canopy; a thin tail ending in a dark tuft.
static func _lion_cub(g: Dictionary, coat: Material, mane: Material, dark: Material, detail: Material, trim: Material) -> void:
	var head: Node3D = g[&"Head"]
	_ball(head, Vector3(0.032, 0.03, 0.028), Vector3(0, 0.022, -0.132), coat)
	_ball(head, Vector3(0.022, 0.014, 0.012), Vector3(0, 0.01, -0.156), trim)
	_ball(head, Vector3(0.008, 0.005, 0.005), Vector3(0, 0.02, -0.166), detail)
	for side in [-1.0, 1.0]:
		_ball(head, Vector3.ONE * 0.0045, Vector3(side * 0.013, 0.032, -0.155), detail)
		_ball(g[&"Ears"], Vector3(0.01, 0.009, 0.005), Vector3(side * 0.022, 0.048, -0.128), coat)
		_ball(g[&"Ears"], Vector3(0.006, 0.005, 0.002), Vector3(side * 0.022, 0.047, -0.133), detail)
	# The collar: tufts from the head's rim out and back, in two layers, over
	# the top and down each side to just above the front lights.
	var collar: Node3D = g[&"Mane"]
	var centre := Vector3(0, 0.023, -0.118)
	for layer in 2:
		var n := 15 - layer
		for i in n:
			var phi := deg_to_rad(lerpf(8.0, 172.0, (i + layer * 0.5) / 14.0))
			var c := cos(phi)
			var up := maxf(sin(phi), 0.0)
			var reach := 1.0 - layer * 0.22
			var inner := Vector3(c * 0.034, sin(phi) * 0.02, 0.004)
			var outer := Vector3(c * 0.1 * reach, up * 0.03, 0.035 + 0.02 * absf(c) + 0.012 * up)
			_rod(collar, centre + inner, centre + outer, 0.015 - layer * 0.003, 0.003, mane if (i + layer) % 2 == 0 else dark)
			if layer == 0:
				_ball(collar, Vector3.ONE * 0.012, centre + inner * 1.05 + Vector3(0, 0, 0.006), mane)
	_tube(g[&"Tail"], [Vector3(0, 0.004, 0.106), Vector3(0, 0.008, 0.132), Vector3(0, 0.02, 0.152), Vector3(0, 0.034, 0.16)], 0.006, 0.004, coat)
	_ball(g[&"Tail"], Vector3.ONE * 0.013, Vector3(0, 0.04, 0.164), dark)

# The vulture: broad wings over the arms, raised a little at the tips, with
# coverts a shade paler than the coat and long dark flight feathers fanned
# out at the ends; a pale ruff round the neck, a bare head and a hooked beak
# out front, and a fan of tail feathers behind.
static func _vulture(g: Dictionary, coat: Material, pale: Material, ruff: Material, detail: Material, trim: Material) -> void:
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.05, 0.009, 0)
		wing.rotation.z = side * 0.24
		g[&"Wings"].add_child(wing)
		for i in 5:
			var a := deg_to_rad(8.0 + i * 11.0)
			var length := minf([0.112, 0.11, 0.1, 0.085, 0.07][i], 0.104 / cos(a))
			_plank(wing, Vector3(0, -0.001, -0.035 + i * 0.016), side, a, length, 0.02, trim)
		for i in 4:
			var a := deg_to_rad(5.0 + i * 12.0)
			_plank(wing, Vector3(0, 0.002, -0.04 + i * 0.02), side, a, 0.066, 0.03, pale)
		_rod(wing, Vector3(0, 0.003, -0.042), Vector3(side * 0.1, 0.001, -0.03), 0.006, 0.004, pale)
	var head: Node3D = g[&"Head"]
	_rod(head, Vector3(0, 0.026, -0.085), Vector3(0, 0.024, -0.12), 0.012, 0.011, coat)
	_ball(head, Vector3(0.017, 0.016, 0.02), Vector3(0, 0.024, -0.128), pale)
	for side in [-1.0, 1.0]:
		_ball(head, Vector3.ONE * 0.004, Vector3(side * 0.014, 0.03, -0.136), trim)
	_rod(g[&"Beak"], Vector3(0, 0.026, -0.144), Vector3(0, 0.022, -0.168), 0.008, 0.005, detail)
	_rod(g[&"Beak"], Vector3(0, 0.022, -0.168), Vector3(0, 0.008, -0.176), 0.005, 0.0012, detail)
	var neck := Vector3(0, 0.026, -0.094)
	_ball(g[&"Ruff"], Vector3(0.02, 0.018, 0.012), neck, ruff)
	for i in 10:
		var phi := TAU * i / 10.0
		_ball(g[&"Ruff"], Vector3.ONE * 0.0105, neck + Vector3(cos(phi) * 0.022, sin(phi) * 0.02, 0.002 * (i % 2)), ruff)
	for i in 5:
		var a := deg_to_rad(-20.0 + i * 10.0)
		var dir := Vector3(sin(a), 0, cos(a))
		var plank := _box(g[&"Tail"], Vector3(0.018, 0.003, 0.075), Vector3(0, 0.02 + 0.001 * (i % 2), 0.095) + dir * 0.0375, trim)
		plank.rotation.y = a

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
