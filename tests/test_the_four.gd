extends RefCounted
# Story 30.1: the Four are data in data/deities/, and a guard keeps them out of
# every system that could put them at risk or on sale (docs/DEITIES.md,
# "Respect"): the cast, the crew lists of jobs, hazard zones, the pilots, the
# emote and bark tables, perks, the shop and the boss. Nothing about them is in
# the save.

const LIST := "res://data/deities/deities.tres"
## id -> thread act, in thread order.
const THREADS := {&"brahma": 1, &"vishnu": 2, &"shiva": 4, &"krishna": 5}
## What a Character has and a Deity never does.
const CREW_ONLY := ["status", "portrait", "look", "shape", "lines", "babble_pitch", "babble_rate",
	"babble_vowels", "bounce", "chirp_pitch", "edge", "perk", "can_be_harmed", "death_consequence", "tags"]

## The save section of vows kept (Story 30.5), the only one a deity id may key.
const VOWS_SECTION := "vows"

func _list() -> DeityList:
	return load(LIST)

## Every id and name of the Four, lower case.
func _words() -> Array[String]:
	var out: Array[String] = []
	for d in _list().deities:
		out.append(String(d.id).to_lower())
		out.append(d.name.to_lower())
	return out

func _is_one(value) -> bool:
	return String(value).to_lower() in _words()

## True if none of `values` is a deity's id or name.
func _none_of(values) -> bool:
	for v in values:
		if _is_one(v):
			return false
	return true

## True if no key or exact string anywhere in `value` is a deity's id or name.
func _clean_data(value) -> bool:
	if value is Dictionary:
		for k in value:
			if _is_one(k) or not _clean_data(value[k]):
				return false
	elif value is Array:
		for v in value:
			if not _clean_data(v):
				return false
	elif value is String or value is StringName:
		return not _is_one(value)
	return true

## True if no file holds a deity's id or name as a whole quoted string (an id
## like &"shiva" or a field like name = "Shiva"). Prose that mentions one, as a
## later briefing may, is not a slot and does not count.
func _clean_text(paths: Array) -> bool:
	var re := RegEx.create_from_string("(?i)\"(%s)\"" % "|".join(_words()))
	for p in paths:
		if re.search(FileAccess.get_file_as_string(p)):
			return false
	return true

## Every file under `dir` ending in one of `exts`.
func _files(dir: String, exts: Array) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.get_extension() in exts:
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_files(dir.path_join(sub), exts))
	return out

func _jobs() -> Array[Job]:
	var out: Array[Job] = []
	for p in _files("res://data", ["tres"]):
		if FileAccess.get_file_as_string(p).contains("script_class=\"Job\""):
			out.append(load(p))
	return out

func test_the_four_load_from_the_list() -> bool:
	var list := _list()
	var ok: bool = list != null and list.deities.size() == 4 and list.ids() == THREADS.keys()
	for d in list.deities:
		ok = ok and d.thread_act == THREADS[d.id] and d.name.to_lower() == String(d.id) \
			and not d.principle.is_empty() and not d.symbols.is_empty() and d.colour.a == 1.0
		ok = ok and list.by_id(d.id) == d and load("res://data/deities/%s.tres" % d.id) == d
	return ok and list.by_id(&"nobody") == null

func test_a_deity_is_not_a_character() -> bool:
	var d: Resource = Deity.new()
	var props: Array = []
	for p in d.get_property_list():
		props.append(p.name)
	for name in CREW_ONLY:
		if name in props:
			return false
	return not d is Character

## The guard itself catches a planted id, name or key, so the tests below mean something.
func test_the_guard_catches_a_planted_one() -> bool:
	return not _none_of([&"nala", &"shiva"]) and not _none_of(["Krishna"]) \
		and not _clean_data({"roster": {"vishnu": {"status": "dead"}}}) \
		and not _clean_data([{"pilot": "brahma"}]) and _clean_data({"roster": {"bhima": {}}}) \
		and _none_of([&"sanjaya", &"arjuna"])

func test_not_in_the_roster_or_any_cast() -> bool:
	var ok := _none_of(Roster.ids())
	for p in _files("res://data/characters", ["tres"]):
		ok = ok and not _is_one(p.get_file().get_basename())
		var r: Resource = load(p)
		if r is Character:
			ok = ok and _none_of([r.id, r.name]) and _none_of(r.speaks_on)
		elif r is Cast:
			for c in r.characters:
				ok = ok and _none_of([c.id, c.name])
	return ok and _clean_text(_files("res://data/characters", ["tres"]))

func test_not_a_pilot() -> bool:
	var ok := true
	for c in (load("res://data/characters/pilots.tres") as Cast).characters:
		ok = ok and _none_of([c.id, c.name])
	return ok

func test_never_crew_in_the_field_or_required_living() -> bool:
	var jobs := _jobs()
	var ok := jobs.size() >= 10
	for j in jobs:
		ok = ok and _none_of(j.crew_in_field) and _none_of(j.requires_living)
	return ok

func test_never_in_a_hazard_zone() -> bool:
	var scenes := _files("res://scenes", ["tscn"])
	var ok := false
	var re := RegEx.create_from_string("(?m)^character = &?\"([^\"]*)\"")
	for p in scenes:
		var text := FileAccess.get_file_as_string(p)
		if not text.contains("hazard_zone.gd"):
			continue
		for m in re.search_all(text):
			ok = true  # at least one zone was read, so the scan is not vacuous
			if _is_one(m.get_string(1)):
				return false
	return ok

func test_not_in_the_emote_or_bark_tables() -> bool:
	var table: EmoteTable = load("res://data/crew/emotes.tres")
	var ok := _none_of(table.quiet_events) and _none_of(table.quiet_job_types)
	for e in table.emotes:
		ok = ok and not _is_one(e.key)
	ok = ok and _none_of(Bark.EVENTS) and _none_of(Bark.MOMENTS) and _none_of(Bark.DEFAULT_FACES.keys())
	for p in _files("res://data/dialogue", ["json"]):
		ok = ok and not _is_one(p.get_file().get_basename()) and _clean_data(JSON.parse_string(FileAccess.get_file_as_string(p)))
	return ok

func test_never_a_perk() -> bool:
	var ok := true
	for id in _list().ids():
		ok = ok and Roster.character(id) == null
	for id in Roster.ids():
		var c: Character = Roster.character(id)
		if c.perk:
			ok = ok and _none_of([c.perk.kind, c.perk.name])
			ok = ok and _none_of(Perks.owners(c.perk.kind).map(func(o): return o.id))
	return ok

func test_not_in_the_shop() -> bool:
	var ups: UpgradeList = load("res://data/upgrades/upgrades.tres")
	var ok := ups.upgrades.size() > 0
	for u in ups.upgrades:
		ok = ok and _none_of([u.id, u.name])
	return ok and _clean_text(_files("res://data/upgrades", ["tres"])) and _clean_text(_files("res://data/garage", ["tres"]))

func test_not_in_the_boss_data() -> bool:
	var boss: Boss = load("res://data/boss/lattice.tres")
	var ok := _none_of(boss.required_characters) and _none_of(boss.job.crew_in_field) and _none_of(boss.job.requires_living)
	ok = ok and _clean_text(_files("res://data/boss", ["tres"]))
	return ok and _clean_data(JSON.parse_string(FileAccess.get_file_as_string(boss.chorus)))

func test_the_save_holds_no_deity_status() -> bool:
	for autoload in [Wallet, Reputation, Roster, Career, Garage, Hangar]:
		autoload.save()
	var data := SaveGame.read()
	# The one place a deity id may be saved: vows kept, per thread (Story 30.5).
	# Nothing else, in any section, names one.
	data.erase(VOWS_SECTION)
	var ok := not data.is_empty() and _clean_data(data)
	# Nothing of the Four reads or writes the save.
	for p in ["res://scripts/story/deity.gd", "res://scripts/story/deity_list.gd"]:
		var src := FileAccess.get_file_as_string(p)
		ok = ok and not src.contains("SaveGame") and not src.contains("save(")
	return ok
