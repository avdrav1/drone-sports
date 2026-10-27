extends RefCounted
# Story 5.2: recruitment. A top-three Act 1 race gets Coach Rin's offer; joining
# moves the pilot to Act 2 and the HUD shows it; offers are one-shot.

const Sim = preload("res://tests/sim.gd")
const Framing = preload("res://tests/test_act1_framing.gd")
const RESULTS := preload("res://scenes/ui/results.tscn")

func _results_with_offers() -> Control:
	var screen: Control = RESULTS.instantiate()
	Sim.add(screen)
	var r := JobResult.new()
	r.job = load("res://data/jobs/test_race.tres")
	r.completed = true
	r.letter = "A"
	screen.show_result(r)
	return screen

func test_top_three_race_brings_the_first_offer() -> bool:
	var none_before := Career.check_offers().is_empty()
	var outside: bool = await Framing.new()._run(3)  # fourth: no scout, no offer
	var still_none := Career.check_offers().is_empty()
	await Framing.new()._run(2)  # third, whatever the grade
	var screen := _results_with_offers()
	var dialog: OfferDialog = screen.offer_dialog
	var ok: bool = none_before and not outside and still_none and dialog.visible \
		and dialog.team.id == &"skyline_juniors" and dialog.dialog_text.contains("Act 2") \
		and dialog.dialog_text.contains("GUARD")
	screen.free()
	return ok

func test_accepting_moves_to_act_2_and_hud_shows_it() -> bool:
	StoryFlags.set_flag(&"scouted")
	var d := Sim.drone(Sim.intent())
	var hud := FlightHud.new()
	hud.drone = d
	Sim.add(hud)
	var before := hud.assists_header()
	var screen := _results_with_offers()
	screen.offer_dialog.confirmed.emit()
	var after := hud.assists_header()
	# A job asking for Act 1 assists now flies with the Act 2 set.
	var race: Job = load("res://data/jobs/test_race.tres")
	var flown := JobRunner.assists_for(race)
	var ok: bool = before.contains("ACT 1") and after.contains("ACT 2") and after.contains("SKYLINE JUNIORS") \
		and Career.team_id == &"skyline_juniors" and not flown.collision_guard and flown.altitude_hold \
		and SaveGame.read_section("career", {}).get("team") == "skyline_juniors"
	screen.free()
	hud.free()
	d.free()
	return ok

func test_declined_offer_never_returns() -> bool:
	StoryFlags.set_flag(&"scouted")
	var first := Career.check_offers()
	Career.decline(&"skyline_juniors")
	Reputation.add(&"league", 5)
	var again := Career.check_offers()
	Reputation.add(&"league", -5)
	Career.load_saved()  # and not after a reload either
	return first.size() == 1 and first[0].id == &"skyline_juniors" and again.is_empty() \
		and Career.check_offers().is_empty() and Career.team_id == &""

func test_reputation_threshold_gates_offers() -> bool:
	# Harbor Couriers wants 10 city reputation; at 9 nothing, at 10 the offer.
	Reputation.add(&"city", 9)
	var at_nine := Career.check_offers().map(func(t): return t.id)
	Reputation.add(&"city", 1)
	var at_ten := Career.check_offers().map(func(t): return t.id)
	Reputation.add(&"city", -10)
	return not &"harbor_couriers" in at_nine and &"harbor_couriers" in at_ten
