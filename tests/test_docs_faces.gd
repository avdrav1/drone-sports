extends RefCounted
# Story 26.6: the docs show the faces. CHARACTERS.md's cast table has a
# "Drawn as" column, and every character's row names what their portrait
# draws (CrewLook: the head, the headwear, the beard, the held object, the
# marks). The respect line covers the faces. 25.4's docs tests still run.

const DOC := "res://docs/CHARACTERS.md"
## Every character with a portrait: the crew and the pilot avatars.
const CASTS := ["res://data/characters/cast.tres", "res://data/characters/pilots.tres"]
## A look's value -> the words a "Drawn as" entry may name it by (any one).
const WORDS := {
	&"vanara": ["vanara"], &"bird": ["bird", "vulture"],
	&"crown": ["crown"], &"helmet": ["helmet"], &"turban": ["turban"], &"band": ["band"], &"crest": ["crest"],
	&"long": ["long"], &"curls": ["curls"], &"jata": ["jata"],
	&"moustache": ["moustache"], &"beard": ["beard"],
	&"bow": ["bow"], &"gada": ["gada"], &"chakra": ["chakra"], &"stone": ["stone"], &"herb": ["herb"],
	&"tilak": ["tilak"], &"tripundra": ["tripundra"], &"glow": ["glow"], &"earrings": ["earrings", "kundala"],
	&"necklace": ["necklace"], &"beads": ["beads"], &"sacred_thread": ["sacred thread"], &"armour": ["armour"],
	&"sash": ["sash"], &"neck_ring": ["neck ring"],
}

func _characters() -> Array[Character]:
	var out: Array[Character] = []
	for path in CASTS:
		for c in (load(path) as Cast).characters:
			if not c in out:
				out.append(c)
	return out

## Id -> its "Drawn as" cell in the cast table.
func _drawn_as() -> Dictionary:
	var out := {}
	var column := -1
	for line in FileAccess.get_file_as_string(DOC).split("\n"):
		var cells: Array = Array(line.split("|")).map(func(c): return c.strip_edges())
		if line.begins_with("| Id |"):
			column = cells.find("Drawn as")
		elif column > 0 and line.begins_with("| `") and cells.size() > column:
			out[StringName(cells[1].trim_prefix("`").trim_suffix("`"))] = cells[column]
	return out

## The words a look must show up as: its head unless human, then every item.
static func wanted(look: CrewLook) -> Array[StringName]:
	var out: Array[StringName] = []
	if look.head != &"human":
		out.append(look.head)
	for item in [look.headwear, look.hair_cut, look.beard, look.held] + Array(look.marks):
		if item in WORDS:
			out.append(item)
	return out

func test_every_character_has_a_drawn_as_entry_matching_their_look() -> bool:
	var rows := _drawn_as()
	var bad := []
	for c in _characters():
		var entry: String = rows.get(c.id, "").to_lower()
		if entry == "":
			bad.append("%s: no Drawn as" % c.id)
			continue
		for item in wanted(c.look):
			if not WORDS[item].any(func(w): return w in entry):
				bad.append("%s: Drawn as misses %s" % [c.id, item])
		# A human is never called a vanara or a bird.
		if c.look.head == &"human" and (WORDS[&"vanara"] + WORDS[&"bird"]).any(func(w): return w in entry):
			bad.append("%s: drawn as human, called otherwise" % c.id)
	if not bad.is_empty():
		print("        ", bad)
	return bad.is_empty() and rows.size() >= _characters().size()

func test_the_respect_line_names_the_faces() -> bool:
	for line in FileAccess.get_file_as_string(DOC).split("\n"):
		if "treated with respect" in line:
			return "face" in line and "Hanuman" in line and "dignified" in line and "laughs" in line
	return false
