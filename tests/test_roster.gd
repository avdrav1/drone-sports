extends RefCounted
# Story 7.1: character roster. The six cast members load and validate; injury,
# death, and Rin's immunity follow the rules; status survives a save; no revive.

const CAST_IDS := [&"pip", &"marlo", &"dot", &"bea", &"ozzie", &"rin"]

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
	Roster.injure(&"bea")
	# One job, not two: Ozzie is fit (Story 19.6).
	var injured: bool = Roster.status(&"bea") == Roster.Status.INJURED and Roster.jobs_benched(&"bea") == 1
	Roster.injure(&"bea")
	var ok := injured and Roster.status(&"bea") == Roster.Status.DEAD and not Roster.is_alive(&"bea")
	_fresh()
	return ok

func test_kill_and_rin_cannot_be_harmed() -> bool:
	_fresh()
	Roster.kill(&"ozzie")
	Roster.injure(&"rin")
	Roster.injure(&"rin")
	Roster.kill(&"rin")
	var ok: bool = Roster.status(&"ozzie") == Roster.Status.DEAD and Roster.status(&"rin") == Roster.Status.ACTIVE
	_fresh()
	return ok

## Ozzie's own injury takes the full two jobs (Story 19.6).
func test_injury_heals_after_two_jobs() -> bool:
	_fresh()
	Roster.injure(&"ozzie")
	Roster.job_done()
	var one: bool = Roster.status(&"ozzie") == Roster.Status.INJURED and Roster.jobs_benched(&"ozzie") == 1
	Roster.job_done()
	var ok := one and Roster.status(&"ozzie") == Roster.Status.ACTIVE
	_fresh()
	return ok

func test_status_survives_save_and_load() -> bool:
	_fresh()
	Roster.injure(&"marlo")
	Roster.kill(&"bea")
	Roster.load_saved()
	var ok: bool = Roster.status(&"marlo") == Roster.Status.INJURED and Roster.jobs_benched(&"marlo") == Roster.injury_jobs(&"marlo") \
		and Roster.status(&"bea") == Roster.Status.DEAD and Roster.status(&"dot") == Roster.Status.ACTIVE \
		and SaveGame.read_section("roster", {}).has("bea")
	_fresh()
	return ok

func test_death_is_permanent() -> bool:
	_fresh()
	Roster.kill(&"marlo")
	for i in 3:
		Roster.job_done()
	Roster.injure(&"marlo")
	var ok: bool = Roster.status(&"marlo") == Roster.Status.DEAD
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
