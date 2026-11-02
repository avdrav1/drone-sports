extends RefCounted
# Story 31.1: every mission can be reached by playing. Reputation comes only from
# flying a faction's jobs, so a team that asks for reputation no flyable job earns
# locks its jobs for good. These tests earn everything as a player does, flying
# what is open at a C grade, rather than granting reputation.

const BOARD := preload("res://data/jobs/board.tres")
const GRADES := preload("res://data/jobs/grade_scale.tres")
const Board = preload("res://tests/test_job_board.gd")

func _flyable() -> Array[StringName]:
	var out: Array[StringName] = []
	for job: Job in BOARD.jobs:
		if Career.can_fly(job):
			out.append(job.id)
	return out

## Flies every open job once, as a player would.
func _fly_round() -> void:
	var gain: int = GRADES.reputation_change["C"]
	for job: Job in BOARD.jobs:
		if Career.can_fly(job):
			Reputation.add(job.faction, gain)
			Career.job_completed(job.id)
	Career.check_offers()

func _capture() -> Dictionary:
	return {"team": Career.team_id, "offered": Career.offered.duplicate(), "pending": Career.pending.duplicate(),
		"completed": Career.completed.duplicate(), "rep": Reputation.by_faction.duplicate()}

func _restore(s: Dictionary) -> void:
	Career.team_id = s.team
	Career.offered = s.offered.duplicate()
	Career.pending = s.pending.duplicate()
	Career.completed = s.completed.duplicate()
	Reputation.by_faction = s.rep.duplicate()

## Every job flown on some career, trying every accept and decline. Flies each
## position for ROUNDS, long enough for any threshold, then takes each choice.
const ROUNDS := 40

func _explore(reached: Dictionary, seen: Dictionary) -> void:
	for i in ROUNDS:
		for id in _flyable():
			reached[id] = true
		_fly_round()
	var key := "%s %s %s" % [Career.team_id, Career.offered, Career.pending]
	if seen.has(key):
		return
	seen[key] = true
	var here := _capture()
	for id: StringName in here.pending:
		Career.accept(id)
		_explore(reached, seen)
		_restore(here)
	if not here.pending.is_empty():
		for id: StringName in here.pending.duplicate():
			Career.decline(id)
		_explore(reached, seen)
		_restore(here)

func test_every_mission_can_be_reached_from_a_new_career() -> bool:
	StoryFlags.set_flag(&"scouted")
	var reached := {}
	_explore(reached, {})
	var ok := true
	for job: Job in BOARD.jobs:
		if not reached.has(job.id):
			print("        no career ever flies %s" % job.id)
			ok = false
	return ok

## Without the top-three scout, the race alone must not be the only way on.
## With every job's open tag off: the career route still works when a job is gated.
func test_a_new_pilot_has_two_missions_and_the_second_earns_city_reputation() -> bool:
	var gated := Board._gate()
	var open := _flyable()
	var ok := open.size() == 2 and &"test_race" in open and &"sample_delivery" in open
	for i in 4:
		_fly_round()
	Board._ungate(gated)
	return ok and Reputation.of(&"city") >= 10 and &"harbor_couriers" in Career.pending

## Joining the race team first must not close the city's route.
func test_the_city_stays_reachable_from_the_race_team() -> bool:
	StoryFlags.set_flag(&"scouted")
	Career.check_offers()
	Career.accept(&"skyline_juniors")
	var home_open := Career.can_fly(load("res://data/jobs/sample_delivery.tres"))
	var ok := home_open
	for i in ROUNDS:
		_fly_round()
		if &"city_rescue_air" in Career.pending:
			break
	Career.accept(&"city_rescue_air")
	var flying := _flyable()
	return ok and &"rescue" in flying and &"inspection" in flying and &"fleet_inspection" in flying

## Salvage notices a pilot by missions flown: nothing else earns its reputation.
func test_salvage_notices_after_enough_missions() -> bool:
	var cannery: Team = Career.teams.by_id(&"cannery_row")
	var demolition: Job = load("res://data/jobs/demolition.tres")
	var before := Career.wants(cannery)
	Career.completed = {&"test_race": cannery.noticed_after - 1}
	var one_short := Career.wants(cannery)
	Career.completed = {&"test_race": cannery.noticed_after - 2, &"sample_delivery": 2}
	var enough := Career.wants(cannery)
	Career.check_offers()
	Career.accept(&"cannery_row")
	return not before and not one_short and enough and Career.can_fly(demolition) \
		and Reputation.of(&"salvage") == 0

## Reputation still gets a team's notice with no missions behind it.
func test_reputation_alone_still_makes_an_offer() -> bool:
	Reputation.add(&"salvage", Career.teams.by_id(&"cannery_row").reputation_needed)
	return Career.wants(Career.teams.by_id(&"cannery_row"))
