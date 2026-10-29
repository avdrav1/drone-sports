extends RefCounted
# Story 25.2: new ids, and saves that follow. The ids match the names, no data,
# code, test or tool file holds an old id (only SaveGame.RENAMED_IDS and this
# test), and a save made with the old ids loads with everything intact under
# the new ones (a dead character stays dead, rule 7), then saves back with new
# ids only.

const Sim = preload("res://tests/sim.gd")
const ROOTS := ["res://data", "res://scripts", "res://scenes", "res://tests", "res://tools"]
const KINDS := ["tres", "json", "gd", "py", "tscn"]
## The migration map, and this test, which holds an old save.
const ALLOWED := ["res://scripts/save_game.gd", "res://tests/test_new_ids.gd"]

func _files(dir: String, out: Array[String]) -> Array[String]:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in KINDS or f.get_extension() in ["wav", "ogg"]:
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_files(dir.path_join(d), out)
	return out

## The old ids in `line`'s id-shaped literals: quoted strings in lower case
## with no spaces, such as "pip", &"motif_bea", "res://data/dialogue/rin.json".
static func old_ids_in(line: String) -> Array[String]:
	var out: Array[String] = []
	var lit := RegEx.create_from_string("([\"'`])([a-z0-9_/.:%-]+)\\1")
	var word := RegEx.create_from_string("(?<![a-z0-9])(%s)(?![a-z0-9])" % "|".join(SaveGame.RENAMED_IDS.keys()))
	for m in lit.search_all(line):
		for w in word.search_all(m.get_string(2)):
			out.append(w.get_string(1))
	return out

## Every id is its name, in lower case, and its files are named for it.
func test_ids_match_the_names() -> bool:
	var ok := true
	var ids := []
	for path in ["res://data/characters/cast.tres", "res://data/characters/pilots.tres"]:
		for c in (load(path) as Cast).characters:
			ok = ok and String(c.id) == c.name.to_lower() and c.resource_path == "res://data/characters/%s.tres" % c.id \
				and c.lines == "res://data/dialogue/%s.json" % c.id and c.validate().is_empty()
			if not c.id in ids:
				ids.append(c.id)
	for id in SaveGame.RENAMED_IDS.values():
		ok = ok and StringName(id) in ids
	return ok and ids.size() == SaveGame.RENAMED_IDS.size() and PlayerProfile.DEFAULT_PILOT == &"arjuna"

func test_no_file_holds_an_old_id() -> bool:
	var bad := []
	for root in ROOTS:
		for path in _files(root, [] as Array[String]):
			if path in ALLOWED:
				continue
			# A file named for an old id: the name, split at "_" and ".".
			for part in path.get_file().get_basename().split("_"):
				if SaveGame.RENAMED_IDS.has(part):
					bad.append(path)
			if path.get_extension() in ["wav", "ogg"]:
				continue
			var lines := FileAccess.get_file_as_string(path).split("\n")
			for i in lines.size():
				for id in old_ids_in(lines[i]):
					bad.append("%s:%d %s" % [path, i + 1, id])
	if not bad.is_empty():
		print("        ", bad)
	return bad.is_empty()

## The scan finds old ids in literals and paths, and leaves words and math be.
func test_the_scan_finds_old_ids() -> bool:
	return old_ids_in("id = &\"marlo\"") == ["marlo"] \
		and old_ids_in("path=\"res://data/characters/pip.tres\" id=\"2_pip\"") == ["pip", "pip"] \
		and old_ids_in("MOTIFS = {'motif_bea': 'reed'}") == ["bea"] \
		and old_ids_in("| `generated/babble_tally.wav` |") == ["tally"] \
		and old_ids_in("var d := a.dot(b)  # a round dot").is_empty() \
		and old_ids_in("text = \"Rin calls it\"").is_empty() \
		and old_ids_in("id = &\"sanjaya\"").is_empty()

## A save from before the rename: two of the crew struck (one dead, one
## injured), a pilot chosen, money, standing and a team, all under old ids.
const OLD_SAVE := {
	"roster": {"marlo": {"status": "dead", "jobs": 2}, "bea": {"status": "injured", "jobs": 1}},
	"profile": {"pilot": "tally"},
	"wallet": 4321,
	"best_pay": 900,
	"reputation": {"salvage": 40, "city": 7},
	"career": {"team": "harbor_couriers", "completed": {"test_race": 2}, "grades": {}, "last_job": "test_race",
		"offered": [], "pending": []},
}

func _write_old_save() -> void:
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string(JSON.stringify(OLD_SAVE, "\t"))
	f.close()

func test_an_old_id_save_loads_intact_under_the_new_ids() -> bool:
	_write_old_save()
	SaveGame.load_all(Sim.tree())
	var ok: bool = Roster.status(&"sanjaya") == Roster.Status.DEAD and Roster.jobs_since_death(&"sanjaya") == 2 \
		and Roster.status(&"bhima") == Roster.Status.INJURED and Roster.jobs_benched(&"bhima") == 1 \
		and Roster.status(&"sushena") == Roster.Status.ACTIVE \
		and PlayerProfile.has_pilot() and PlayerProfile.pilot().id == &"hanuman" \
		and Wallet.balance == 4321 and Wallet.best_pay == 900 \
		and Reputation.of(&"salvage") == 40 and Reputation.of(&"city") == 7 \
		and Career.team_id == &"harbor_couriers" and Career.times_completed(&"test_race") == 2
	# The strike carried over: Bhima, injured, dies on a second one.
	Roster.injure(&"bhima")
	ok = ok and Roster.status(&"bhima") == Roster.Status.DEAD
	# Dead stays dead: no way back, under either id (rule 7).
	Roster.job_done()
	SaveGame.load_all(Sim.tree())
	ok = ok and not Roster.is_alive(&"sanjaya") and not Roster.is_alive(&"bhima") and Roster.jobs_since_death(&"sanjaya") == 3
	Wallet.balance = 0
	Wallet.best_pay = 0
	Wallet.save()
	return ok

func test_an_old_id_save_is_migrated_once_and_saves_back_new_ids_only() -> bool:
	_write_old_save()
	# Loading it rewrites the file: the old ids are gone from it at once.
	var data := SaveGame.read()
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveGame.path))
	var ok: bool = data == on_disk and on_disk.roster.size() == 2 and on_disk.roster.has("sanjaya") and on_disk.roster.has("bhima") and on_disk.profile.pilot == "hanuman" \
		and on_disk.wallet == 4321.0 and on_disk.reputation == {"salvage": 40.0, "city": 7.0}
	# Once migrated, a read changes nothing more.
	ok = ok and not SaveGame.migrate_ids(on_disk)
	SaveGame.load_all(Sim.tree())
	Roster.save()
	Roster.job_done()
	var text := FileAccess.get_file_as_string(SaveGame.path)
	for line in text.split("\n"):
		ok = ok and old_ids_in(line).is_empty()
	ok = ok and "\"sanjaya\"" in text and "\"hanuman\"" in text
	Wallet.balance = 0
	Wallet.best_pay = 0
	Wallet.save()
	return ok

## A save with both, say from an old copy merged by hand: the new id's entry
## wins, and the old one is dropped.
func test_the_worse_status_wins_when_both_ids_are_kept() -> bool:
	var data := {"roster": {"ozzie": {"status": "dead", "jobs": 0}, "sushena": {"status": "injured", "jobs": 1},
		"bea": {"status": "active", "jobs": 2}, "bhima": {"status": "injured", "jobs": 3}},
		"profile": {"pilot": "arjuna"}}
	var changed := SaveGame.migrate_ids(data)
	return changed and data.roster == {"sushena": {"status": "dead", "jobs": 0}, "bhima": {"status": "injured", "jobs": 3}} \
		and data.profile.pilot == "arjuna" \
		and not SaveGame.migrate_ids({"roster": {}, "profile": {}}) and not SaveGame.migrate_ids({})
