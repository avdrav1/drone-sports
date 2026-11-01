extends RefCounted
# Story 26.2: looks from the epics. Every crew look names its head and the
# iconography in the table of Epic 26, and the portrait paints it; Nala,
# Sushena and Hanuman are vanaras, Jatayu a bird, the rest human; no two share
# both headwear and held object; headwear stays clear of the brows; and at
# 48 px every face's silhouette differs from every other's.

const People = preload("res://tests/test_portraits_as_people.gd")

## Epic 26's "Drawn as" table: each one's head, and what of their iconography
## the look names and the portrait paints.
const TABLE := {
	&"arjuna": [&"human", [&"crown", &"bow", &"hair"]],
	&"abhimanyu": [&"human", [&"helmet", &"armour", &"chakra"]],
	&"bhima": [&"human", [&"moustache", &"gada"]],
	&"drona": [&"human", [&"beard", &"tilak", &"beads", &"bow"]],
	&"sanjaya": [&"human", [&"turban", &"glow"]],
	&"nala": [&"vanara", [&"stone", &"sash"]],
	&"sushena": [&"vanara", [&"herb"]],
	&"jatayu": [&"bird", [&"beak", &"crest", &"neck_ring"]],
	&"hanuman": [&"vanara", [&"crown", &"gada"]],
}

func _look_names(l: CrewLook) -> Array:
	var out: Array = [l.headwear, l.held, l.beard, l.hair_cut]
	for m in l.marks:
		# The tripundra is Drona's tilak.
		out.append(&"tilak" if m == &"tripundra" else m)
	if l.hair_cut != &"":
		out.append(&"hair")
	return out

func test_every_look_matches_the_table_and_is_painted() -> bool:
	var ok := true
	for id in TABLE:
		var c: Character = load("res://data/characters/%s.tres" % id)
		var head: StringName = TABLE[id][0]
		var parts := CharacterPortrait.paint_parts(c, 256.0)
		ok = ok and c.look.head == head and c.validate().is_empty()
		for item: StringName in TABLE[id][1]:
			var named := item in _look_names(c.look) or (item == &"beak" and head == &"bird")
			if not named or not String(item) in parts:
				print("        %s: %s named %s, painted %s" % [id, item, named, String(item) in parts])
				ok = false
	return ok

func test_vanaras_a_bird_and_humans() -> bool:
	var ok := true
	for id in TABLE:
		var c: Character = load("res://data/characters/%s.tres" % id)
		var want := &"vanara" if id in [&"nala", &"sushena", &"hanuman"] else (&"bird" if id == &"jatayu" else &"human")
		ok = ok and c.look.head == want and CharacterPortrait.head_kind(c) == want
	return ok

func test_no_two_share_headwear_and_held_object() -> bool:
	var seen := {}
	for id in TABLE:
		var l: CrewLook = load("res://data/characters/%s.tres" % id).look
		var key := "%s|%s" % [l.headwear, l.held]
		if seen.has(key):
			print("        %s and %s both wear and hold %s" % [seen[key], id, key])
			return false
		seen[key] = id
	return seen.size() == TABLE.size()

func test_headwear_stays_clear_of_the_brows() -> bool:
	var ok := CharacterPortrait.HEADWEAR_BOTTOM.size() == CrewLook.HEADWEAR.size() - 1
	var exprs := CharacterPortrait.EXPRESSIONS.duplicate()
	exprs.append(CharacterPortrait.DISTRESS)
	for hw in CharacterPortrait.HEADWEAR_BOTTOM:
		for e in exprs:
			for i in 40:
				var p := CharacterPortrait.pose(e, i * 0.25, i % 2 == 0, 5)
				ok = ok and CharacterPortrait.brow_top(p) - float(CharacterPortrait.HEADWEAR_BOTTOM[hw]) >= 0.1
	return ok

func test_named_for_lines_stay() -> bool:
	var ok := true
	for id in TABLE:
		ok = ok and not (load("res://data/characters/%s.tres" % id) as Character).named_for.is_empty()
	return ok

func test_every_silhouette_differs_at_48_px() -> bool:
	var r: Dictionary = await People.new()._probe_result()
	if r.is_empty():
		return false
	# The two most alike faces still differ in outline over a tenth of the square.
	if float(r.outlines) <= 0.1:
		print("        closest outlines %s: %s" % [r.closest, r.outlines])
		return false
	return (r.errors as Array).is_empty()
