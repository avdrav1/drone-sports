extends RefCounted
# Story 19.4: crew perks are data. Each support crew member carries a perk that
# is on while they are active, off while benched, and gone once dead. Perks sums
# a kind over the fit crew, and no system names a character to get one.

## The epic table: id -> [kind, amount].
const TABLE := {
	&"rin": [&"reputation", 0.25],
	&"marlo": [&"guidance", 1.0],
	&"dot": [&"price", 0.2],
	&"bea": [&"pay", 0.15],
	&"ozzie": [&"recovery", 1.0],
}

func test_perks_round_trip_from_data() -> bool:
	var ok := true
	for id in Roster.ids():
		var c: Character = load("res://data/characters/%s.tres" % id)
		if TABLE.has(id):
			ok = ok and c.perk != null and c.perk.kind == TABLE[id][0] \
				and is_equal_approx(c.perk.amount, TABLE[id][1]) and c.validate().is_empty()
		else:
			ok = ok and c.perk == null
	for c in (load("res://data/characters/pilots.tres") as Cast).characters:
		ok = ok and c.perk == null
	return ok

func test_on_while_active_off_while_benched_gone_once_dead() -> bool:
	var active := is_equal_approx(Perks.amount(&"pay"), 0.15)
	Roster.injure(&"bea")
	var benched := Perks.amount(&"pay") == 0.0
	Roster.job_done()
	Roster.job_done()
	var back := is_equal_approx(Perks.amount(&"pay"), 0.15)
	Roster.kill(&"bea")
	var dead := Perks.amount(&"pay") == 0.0
	Roster.job_done()
	Roster.job_done()
	Roster.job_done()
	var still_dead := Perks.amount(&"pay") == 0.0 and Perks.owners(&"pay").is_empty()
	# The others are untouched.
	var others := is_equal_approx(Perks.amount(&"price"), 0.2) and is_equal_approx(Perks.amount(&"reputation"), 0.25)
	return active and benched and back and dead and still_dead and others

func test_same_kind_adds_up() -> bool:
	var dot: Character = Roster.character(&"dot")
	var own := dot.perk
	var stand_in := CrewPerk.new()
	stand_in.kind = &"pay"
	stand_in.amount = 0.1
	dot.perk = stand_in
	var both := is_equal_approx(Perks.amount(&"pay"), 0.25) and Perks.owners(&"pay").size() == 2
	Roster.injure(&"bea")
	var one := is_equal_approx(Perks.amount(&"pay"), 0.1)
	dot.perk = own
	return both and one and Perks.amount(&"unknown") == 0.0

func test_bad_perk_fails_validation() -> bool:
	var c: Character = Roster.character(&"bea").duplicate()
	var p := CrewPerk.new()
	p.kind = &"luck"
	p.amount = 0.5
	c.perk = p
	var unknown := not c.validate().is_empty()
	p.kind = &"pay"
	p.amount = 0.0
	return unknown and not c.validate().is_empty()

## Perks itself, and every script that asks it, asks by kind: none names a
## cast member.
func test_no_system_names_a_character_for_a_perk() -> bool:
	var ids: Array = Roster.ids()
	for c in (load("res://data/characters/pilots.tres") as Cast).characters:
		ids.append(c.id)
	var askers := _scripts("res://scripts").filter(func(p):
		return p.get_file() == "perks.gd" or FileAccess.get_file_as_string(p).contains("Perks."))
	var ok := askers.size() >= 1
	for p in askers:
		var src := FileAccess.get_file_as_string(p)
		for id in ids:
			if src.contains("&\"%s\"" % id) or src.contains("\"%s\"" % id):
				ok = false
				print("        %s names %s" % [p, id])
	return ok

func _scripts(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	return out
