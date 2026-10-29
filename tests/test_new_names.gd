extends RefCounted
# Story 25.1: new names on screen. Every character carries a name from the
# Ramayana or the Mahabharata; no player-facing text under data/, scripts/ or
# scenes/ holds an old name; and each one's "named for" line shows on their
# CREW row (or, for the pilots who have none, their pilot card) and fits at
# 960x720 and 1920x1080. Ids stay as they were (25.2 renames them).

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"

## Id -> the name the player sees.
const NAMES := {&"pip": "Arjuna", &"rin": "Drona", &"marlo": "Sanjaya", &"dot": "Nala", &"bea": "Bhima",
	&"ozzie": "Sushena", &"fen": "Abhimanyu", &"moss": "Jatayu", &"tally": "Hanuman"}
const OLD := ["pip", "rin", "marlo", "dot", "bea", "ozzie", "fen", "moss", "tally"]
const ROOTS := ["res://data", "res://scripts", "res://scenes"]
const KINDS := ["tres", "json", "gd", "tscn"]

## Every character file, the cast's and the pilots'.
func _characters() -> Array[Character]:
	var out: Array[Character] = []
	for id in NAMES:
		out.append(load("res://data/characters/%s.tres" % id))
	return out

func _files(dir: String, out: Array[String]) -> Array[String]:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in KINDS:
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_files(dir.path_join(d), out)
	return out

## The quoted strings of `line` a player could read: not StringNames (ids), not
## res:// paths, node names or NodePaths (internal), and not in a comment.
static func player_strings(line: String, kind: String) -> Array[String]:
	if kind == "tscn" and line.begins_with("[node "):
		return []
	var out: Array[String] = []
	var lit := RegEx.create_from_string("(&|\\^|NodePath\\(|ExtResource\\(|SubResource\\(|\\bid=)?\"((?:[^\"\\\\]|\\\\.)*)\"")
	var code := line
	if kind == "gd":
		# Cut a comment: the first # outside a string.
		var quoted := false
		for i in line.length():
			if line[i] == "\"" and (i == 0 or line[i - 1] != "\\"):
				quoted = not quoted
			elif line[i] == "#" and not quoted:
				code = line.substr(0, i)
				break
	for m in lit.search_all(code):
		var s := m.get_string(2)
		if m.get_string(1) != "" or s.begins_with("res://") or s.begins_with("uid://"):
			continue
		# A bare id as a key or value, e.g. "marlo" in a JSON list, is an id,
		# and so is anything id-shaped ("motif_ozzie", "70_babble_bea"): 25.2
		# renames those. A handle a player reads ("PIP_07") is not lower case.
		if s in OLD or RegEx.create_from_string("^[a-z0-9_]+$").search(s):
			continue
		out.append(s)
	return out

## True if `s` holds an old name. A name ends at anything but a letter or
## digit, so a handle joined by "_" ("PIP_07") counts and "dotted" does not.
static func has_old_name(s: String) -> bool:
	return RegEx.create_from_string("(?i)(?<![a-z0-9])(%s)(?![a-z0-9])" % "|".join(OLD)).search(s) != null

func test_no_old_name_in_player_text() -> bool:
	var bad := []
	for root in ROOTS:
		for path in _files(root, [] as Array[String]):
			var lines := FileAccess.get_file_as_string(path).split("\n")
			for i in lines.size():
				for s in player_strings(lines[i], path.get_extension()):
					if has_old_name(s):
						bad.append("%s:%d %s" % [path, i + 1, s])
	if not bad.is_empty():
		print("        ", bad)
	return bad.is_empty()

## The scan sees through the cases it must and skips the ids it must.
func test_the_scan_catches_names_and_skips_ids() -> bool:
	return player_strings("text = \"Marlo here.\"", "tres") == ["Marlo here."] \
		and player_strings("\t\"memorial\": \"Dot, mechanic.\",", "json") == ["Dot, mechanic."] \
		and player_strings("id = &\"marlo\"", "tres").is_empty() \
		and player_strings("[node name=\"Ozzie\" type=\"Node3D\" parent=\".\"]", "tscn").is_empty() \
		and player_strings("zone = NodePath(\"../Ozzie/Zone\")", "tscn").is_empty() \
		and player_strings("var x := 1  # \"Bea's site rates\"", "gd").is_empty() \
		and player_strings("var s := \"%s #%d\" % [\"Fen\", 2]", "gd") == ["%s #%d", "Fen"] \
		and player_strings("[ext_resource type=\"Resource\" path=\"res://x.tres\" id=\"2_pip\"]", "tres") == ["Resource"] \
		and player_strings("cast = [ExtResource(\"3_marlo\"), SubResource(\"babble_bea\")]", "tres").is_empty() \
		and player_strings("\t\"motif_ozzie\": \"voice\",", "json").is_empty() \
		and has_old_name("PLAYER  PIP_07") and has_old_name("rin-2") and not has_old_name("dotted pipe")

func test_every_character_has_their_new_name_and_namesake() -> bool:
	var ok := true
	for c in _characters():
		ok = ok and c.name == NAMES[c.id] and c.named_for.begins_with("Named for ") \
			and c.named_for.length() <= 70 and c.validate().is_empty()
	# Ids stay for now, so the roster and the pilots still find everyone.
	for id in Roster.ids():
		ok = ok and Roster.character(id).name == NAMES[id]
	for c in PlayerProfile.pilots():
		ok = ok and c.name == NAMES[c.id]
	return ok and PlayerProfile.pilot().name == "Arjuna"

func test_crew_rows_and_pilot_cards_show_named_for() -> bool:
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	await Sim.process_frames(1)
	var ok := true
	for id in Roster.ids():
		var l: Label = b.crew_rows[id].get_node_or_null("Info/NamedFor")
		ok = ok and l != null and l.text == Roster.character(id).named_for
		ok = ok and (b.crew_rows[id].get_node("Info/Status") as Label).text.begins_with(NAMES[id] + "  ·  ")
	b.free()
	var s := PilotSelect.new()
	Sim.add(s)
	# A pilot with no CREW row carries the line on their card instead.
	for c in PlayerProfile.pilots():
		var l: Label = s.cards[c.id].find_child("NamedFor", true, false)
		if Roster.character(c.id):
			ok = ok and l == null
		else:
			ok = ok and l != null and l.text == c.named_for
	s.free()
	return ok

## The CREW page at `size`: each row's name and namesake lines inside the page
## and never squeezed under their own size.
func _crew_fits(size: Vector2i) -> Array:
	var sv := SubViewport.new()
	sv.size = size
	Sim.add(sv)
	var b: JobBoard = load(BOARD).instantiate()
	sv.add_child(b)
	await Sim.process_frames(2)
	b.open_crew()
	await Sim.process_frames(2)
	var page: Rect2 = (b.pages[&"crew"] as Control).get_global_rect().grow(1.0)
	var out := []
	for id in b.crew_rows:
		for n in ["Info/Status", "Info/NamedFor"]:
			var l: Label = b.crew_rows[id].get_node(n)
			var r := l.get_global_rect()
			var squeezed := l.size.x + 1.0 < l.get_combined_minimum_size().x or l.size.y + 1.0 < l.get_combined_minimum_size().y
			if r.position.x < page.position.x or r.end.x > page.end.x or squeezed or l.get_line_count() > 2:
				out.append("%s %s at %s: %s" % [id, n, size, r])
	sv.free()
	return out

func test_named_for_fits_its_row_at_960_and_1080() -> bool:
	var bad := []
	for size in [Vector2i(960, 720), Vector2i(1920, 1080)]:
		bad.append_array(await _crew_fits(size))
	if not bad.is_empty():
		print("        ", bad)
	return bad.is_empty()
