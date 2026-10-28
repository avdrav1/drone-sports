extends RefCounted
# Story 8.2: the shell. A sphere of captured drones with one trench in.

const Sim = preload("res://tests/sim.gd")
# Loaded per test, not preloaded: the 8.1 test proves a disabled boss leaves
# nothing under scenes/boss/ in the cache.
const SHELL := "res://scenes/boss/lattice.tscn"
## The drone's body is about 0.3 m from centre to prop tip; leave it some room.
const CLEARANCE := 0.6
## Instances the shipped shell may draw: well inside what a frame can afford.
const BUDGET := 6000

func _shell(tweak := {}) -> Lattice:
	var l: Lattice = load(SHELL).instantiate()
	var b: Boss = l.boss.duplicate()
	for k in tweak:
		b.set(k, tweak[k])
	l.boss = b
	l.position = Vector3(0, 150, 0)
	return Sim.add(l)

func test_unit_count_and_trench_width_are_data() -> bool:
	var big := _shell()
	var small := _shell({"unit_count": 800})
	var wide := _shell({"trench_width": 12.0})
	var narrow := _shell({"trench_width": 6.0})
	var mid := (big.tunnel_span().x + big.tunnel_span().y) * 0.5
	var p := Lattice.toward(deg_to_rad(40.0)) * mid + Vector3(0, 4.5, 0)
	var ok: bool = big.multimesh.instance_count == big.units.size() and big.units.size() <= BUDGET \
		and small.units.size() < big.units.size() * 0.5 and small.multimesh.instance_count == small.units.size() \
		and wide.in_tunnel(p) and not narrow.in_tunnel(p) \
		and big.multimesh.mesh.get_surface_count() > 0 and big.multimesh.mesh.surface_get_array_len(0) > 100
	for l in [big, small, wide, narrow]:
		l.free()
	return ok

func test_trench_is_the_one_way_in() -> bool:
	var l := _shell()
	var path := l.trench_path()
	var closed := l.sphere_cast(path[1], path[2], CLEARANCE) < 1.0
	l.entrance_open = true
	var ok := closed and path.size() > 10
	for i in path.size() - 1:
		if l.sphere_cast(path[i], path[i + 1], CLEARANCE) < 1.0:
			print("        blocked between %d and %d" % [i, i + 1])
			ok = false
	# Straight in anywhere else hits the shell.
	for deg in [180.0, 270.0, 60.0]:
		var dir := Lattice.toward(deg_to_rad(deg))
		ok = ok and l.sphere_cast(l.to_global(dir * (l.r_out() + 10.0)), l.to_global(dir * (l.boss.core_radius + 3.0)), CLEARANCE) < 1.0
	var top := l.to_global(Vector3.UP * (l.r_out() + 10.0))
	ok = ok and l.sphere_cast(top, l.to_global(Vector3.UP * 10.0), CLEARANCE) < 1.0
	l.free()
	return ok

# The headless renderer keeps no instance data to read back, so this checks the
# colour each instance is given.
func test_crew_units_carry_crew_colors() -> bool:
	var l := _shell()
	var ok := l.crew_units.size() == FleetCrew.tagged().size() and l.crew_units.size() >= 4
	for i in l.crew_units:
		var c: Character = Roster.character(l.crew_units[i])
		ok = ok and l.color_of(i) == c.colors[0] and not i in l.entrance_units
	var plain := l.units.size() - 1
	while l.crew_units.has(plain):
		plain -= 1
	ok = ok and l.color_of(plain) == l.unit_color
	if not ok:
		print("        crew units %s" % l.crew_units)
	l.free()
	return ok
