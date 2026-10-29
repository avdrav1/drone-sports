extends RefCounted
# Story 7.1: character roster. The six cast members load and validate; injury,
# death, and Drona's immunity follow the rules; status survives a save; no revive.

const CAST_IDS := [&"arjuna", &"sanjaya", &"nala", &"bhima", &"sushena", &"drona"]

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

func test_cast_loads_and_validates() -> bool:
	var ok: bool = Roster.ids().size() == 6
	for id in CAST_IDS:
		var c: Character = Roster.character(id)
		ok = ok and c != null and c.id == id and c.validate().is_empty()
	return ok

func test_injure_twice_kills() -> bool:
	_fresh()
	Roster.injure(&"bhima")
	# One job, not two: Sushena is fit (Story 19.6).
	var injured: bool = Roster.status(&"bhima") == Roster.Status.INJURED and Roster.jobs_benched(&"bhima") == 1
	Roster.injure(&"bhima")
	var ok := injured and Roster.status(&"bhima") == Roster.Status.DEAD and not Roster.is_alive(&"bhima")
	_fresh()
	return ok

func test_kill_and_drona_cannot_be_harmed() -> bool:
	_fresh()
	Roster.kill(&"sushena")
	Roster.injure(&"drona")
	Roster.injure(&"drona")
	Roster.kill(&"drona")
	var ok: bool = Roster.status(&"sushena") == Roster.Status.DEAD and Roster.status(&"drona") == Roster.Status.ACTIVE
	_fresh()
	return ok

## Sushena's own injury takes the full two jobs (Story 19.6).
func test_injury_heals_after_two_jobs() -> bool:
	_fresh()
	Roster.injure(&"sushena")
	Roster.job_done()
	var one: bool = Roster.status(&"sushena") == Roster.Status.INJURED and Roster.jobs_benched(&"sushena") == 1
	Roster.job_done()
	var ok := one and Roster.status(&"sushena") == Roster.Status.ACTIVE
	_fresh()
	return ok

func test_status_survives_save_and_load() -> bool:
	_fresh()
	Roster.injure(&"sanjaya")
	Roster.kill(&"bhima")
	Roster.load_saved()
	var ok: bool = Roster.status(&"sanjaya") == Roster.Status.INJURED and Roster.jobs_benched(&"sanjaya") == Roster.injury_jobs(&"sanjaya") \
		and Roster.status(&"bhima") == Roster.Status.DEAD and Roster.status(&"nala") == Roster.Status.ACTIVE \
		and SaveGame.read_section("roster", {}).has("bhima")
	_fresh()
	return ok

func test_death_is_permanent() -> bool:
	_fresh()
	Roster.kill(&"sanjaya")
	for i in 3:
		Roster.job_done()
	Roster.injure(&"sanjaya")
	var ok: bool = Roster.status(&"sanjaya") == Roster.Status.DEAD
	for m in Roster.get_method_list():
		var name := String(m.name)
		for banned in ["revive", "resurrect", "heal", "set_status", "restore"]:
			ok = ok and not name.contains(banned)
	_fresh()
	return ok

func test_portraits_draw_for_everyone() -> bool:
	var ok := true
	for id in CAST_IDS:
		var p := CharacterPortrait.new()
		p.character = Roster.character(id)
		Engine.get_main_loop().root.add_child(p)
		ok = ok and p.custom_minimum_size == Vector2(64, 64)
		p.free()
	return ok
