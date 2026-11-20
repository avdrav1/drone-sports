extends RefCounted
# Story 31.1: every mission can be reached by playing. Reputation comes only from
# flying a faction's jobs, so a team that asks for reputation no flyable job earns
# locks its jobs for good. These tests earn everything as a player does, flying
# what is open at a C grade, rather than granting reputation.
# Story 31.2 extends them to sideways offers and honest locked cards.

const BOARD := preload("res://data/jobs/board.tres")
const GRADES := preload("res://data/jobs/grade_scale.tres")

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

## Cleared when a locked card names a team that cannot ask. Judged here from the
## career's state, not by Career.may_unlock, which the card itself relies on.
var _honest := true

func _can_ask(t: Team) -> bool:
	if t.id == Career.team_id or Consequences.faction_locked(t.faction):
		return false
	if t.id in Career.pending:
		return true
	var theirs := int(t.preset.label.trim_prefix("Act "))
	var sideways := theirs == Career.act() and Career.team() != null and t.faction != Career.team().faction
	return not t.id in Career.offered and (theirs > Career.act() or sideways)

func _check_cards() -> void:
	for job: Job in BOARD.jobs:
		if Career.can_fly(job) or not Consequences.listed(job):
			continue
		var card: String = JobBoard.lock_reason(job)[0]
		var some_team_can_ask := false
		for t: Team in Career.teams.teams:
			if job.job_type in t.job_types and _can_ask(t):
				some_team_can_ask = true
			if card.begins_with(t.name) and not (job.job_type in t.job_types and _can_ask(t)):
				print("        %s on %s: %s" % [job.id, Career.team_id, card])
				_honest = false
		if not some_team_can_ask and card != "No team will ask now" and not card.begins_with("Needs"):
			print("        %s on %s: %s, but no team can ask" % [job.id, Career.team_id, card])
			_honest = false

func _explore(reached: Dictionary, seen: Dictionary) -> void:
	for i in ROUNDS:
		for id in _flyable():
			reached[id] = true
		_check_cards()
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
func test_a_new_pilot_has_two_missions_and_the_second_earns_city_reputation() -> bool:
	var open := _flyable()
	var ok := open.size() == 2 and &"test_race" in open and &"sample_delivery" in open
	for i in 4:
		_fly_round()
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

# Story 31.2: a first team closes no faction's route, and the card tells the truth.

func _on_the_juniors() -> void:
	StoryFlags.set_flag(&"scouted")
	Career.check_offers()
	Career.accept(&"skyline_juniors")

func test_the_race_team_can_still_move_to_the_couriers() -> bool:
	_on_the_juniors()
	var parcel: Job = load("res://data/jobs/sample_delivery.tres")
	var gain: int = GRADES.reputation_change["C"]
	var runs := 0
	while not &"harbor_couriers" in Career.pending and runs < 10:
		Reputation.add(parcel.faction, gain)
		Career.job_completed(parcel.id)
		Career.check_offers()
		runs += 1
	var assists := Career.preset()
	Career.accept(&"harbor_couriers")
	return runs == 4 and Career.team_id == &"harbor_couriers" and Career.preset() != null \
		and Career.preset().label == assists.label and Career.can_fly(load("res://data/jobs/inspection.tres"))

func test_a_sideways_offer_says_what_it_changes() -> bool:
	_on_the_juniors()
	var text := OfferDialog.offer_text(Career.teams.by_id(&"harbor_couriers"))
	return text.contains("keep flying Act 2") and text.contains("leave Skyline Juniors")

func test_only_another_factions_team_asks_at_the_same_act() -> bool:
	_on_the_juniors()
	var harbor: Team = Career.teams.by_id(&"harbor_couriers")
	var same_faction: Team = harbor.duplicate()
	same_faction.faction = &"league"
	var sideways := Career.recruits_at_this_act(harbor)
	var own_faction := Career.recruits_at_this_act(same_faction)
	Career.team_id = &"city_rescue_air"
	var from_later_act := Career.recruits_at_this_act(harbor)
	return sideways and not own_faction and not from_later_act

func test_joining_one_team_keeps_another_factions_offer_waiting() -> bool:
	StoryFlags.set_flag(&"scouted")
	Reputation.add(&"city", 10)
	Career.check_offers()
	var both := &"skyline_juniors" in Career.pending and &"harbor_couriers" in Career.pending
	Career.accept(&"skyline_juniors")
	return both and &"harbor_couriers" in Career.pending

func test_card_shows_reputation_earned_toward_the_offer() -> bool:
	_on_the_juniors()
	var inspection: Job = load("res://data/jobs/inspection.tres")
	var empty := JobBoard.lock_reason(inspection)
	Reputation.add(&"city", 4)
	var some := JobBoard.lock_reason(inspection)
	return empty[0] == "Harbor Couriers: City reputation 0 of 10" and some[0] == "Harbor Couriers: City reputation 4 of 10" \
		and some[1].contains("asks at 10 City reputation") and some[1].contains("You have 4") \
		and some[1].contains("City Rescue Air")

func test_card_shows_missions_for_a_team_that_notices_them() -> bool:
	var demolition: Job = load("res://data/jobs/demolition.tres")
	Career.completed = {&"test_race": 2}
	var card := JobBoard.lock_reason(demolition)
	return card[0] == "Cannery Row Salvage: 2 of 5 missions" and card[1].contains("after 5 completed missions")

func test_card_says_how_to_raise_a_flag_and_when_an_offer_waits() -> bool:
	var drill: Job = load("res://data/jobs/spotter_drill.tres")
	var first := JobBoard.lock_reason(drill)
	StoryFlags.set_flag(&"scouted")
	Career.check_offers()
	var waiting := JobBoard.lock_reason(drill)
	return first[0] == "Skyline Juniors: finish the race in the top three" and waiting[0] == "Skyline Juniors: offer waiting"

func test_card_never_names_a_team_that_cannot_ask() -> bool:
	var inspection: Job = load("res://data/jobs/inspection.tres")
	Reputation.add(&"city", 10)
	Career.check_offers()
	Career.decline(&"harbor_couriers")
	var declined := JobBoard.lock_reason(inspection)
	var rescue: Job = load("res://data/jobs/rescue.tres")
	Career.offered.append(&"city_rescue_air")
	var nobody := JobBoard.lock_reason(rescue)
	return not (declined[0] + declined[1]).contains("Harbor Couriers") and nobody[0] == "No team will ask now"

## Everywhere a career can go, a locked card names only teams that can still ask.
func test_cards_are_honest_on_every_career() -> bool:
	StoryFlags.set_flag(&"scouted")
	_honest = true
	_explore({}, {})
	return _honest
