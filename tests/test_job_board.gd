extends RefCounted
# Story 5.3: job board. The main scene; only the current team's jobs fly, the
# rest say who unlocks them; wallet, reputation, and the crew show; jobs come back here.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"

func _board() -> JobBoard:
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	return b

func _flyable(b: JobBoard) -> Array:
	var out := []
	for id in b.job_rows:
		if b.fly_button(id):
			out.append(id)
	out.sort_custom(func(a, b): return String(a) < String(b))  # StringName sort is by pointer, not text
	return out

func test_reached_at_launch_and_jobs_come_back() -> bool:
	var runner := JobRunner.new()
	var results: Control = load("res://scenes/ui/results.tscn").instantiate()
	# The intro is the main scene and forwards here (Story 11.1), by way of the title (Story 17.3).
	var intro: Cutscene = load("res://data/story/intro.tres")
	var ok: bool = intro.next_scene == JobBoard.TITLE and TitleScreen.BOARD == BOARD and runner.back_scene == BOARD and results.continue_scene == BOARD
	runner.free()
	results.free()
	return ok

func test_only_current_team_jobs_fly() -> bool:
	var b := _board()
	await Sim.process_frames(1)
	var home := _flyable(b)
	var race_lock: String = b.job_rows[&"sample_delivery"].get_node("Locked").text
	b.free()
	Career.team_id = &"harbor_couriers"
	b = _board()
	await Sim.process_frames(1)
	var couriers := _flyable(b)
	var race_lock_now: String = b.job_rows[&"test_race"].get_node("Locked").text
	var details: String = \
		(b.job_rows[&"sample_delivery"].get_child(0).get_node("Details") as Label).text
	b.free()
	Career.team_id = &""
	return home == [&"test_race"] and race_lock.contains("Harbor Couriers") \
		and couriers == [&"inspection", &"sample_delivery"] and race_lock_now.contains("Skyline Juniors") \
		and race_lock_now.contains("Halcyon Racing") and details.contains("Harbor Couriers") \
		and details.contains("pay 500") and details.contains("Act 2 assists")

func test_header_shows_wallet_reputation_and_team() -> bool:
	Wallet.balance = 1234
	Reputation.add(&"league", 7)
	var b := _board()
	await Sim.process_frames(1)
	var money := b.money_text()
	var header: String = b._header.text
	b.free()
	Wallet.balance = 0
	return money.contains("1234") and money.contains("League 7") and money.contains("Salvage 0") \
		and header.contains("Act 1")

func test_crew_shows_status_and_the_dead_greyed_with_memorial() -> bool:
	Roster.injure(&"marlo")
	Roster.kill(&"bea")
	var b := _board()
	await Sim.process_frames(1)
	var marlo: String = (b.crew_rows[&"marlo"].get_node("Status") as Label).text
	var bea: String = (b.crew_rows[&"bea"].get_node("Status") as Label).text
	var ok: bool = b.crew_rows.size() == 6 and marlo.contains("Injured") and marlo.contains("2 more jobs") \
		and bea.contains("Died.") and bea.contains(Bark.memorial(&"bea")) \
		and (b.crew_rows[&"bea"].get_node("Face") as CharacterPortrait).greyed \
		and not (b.crew_rows[&"marlo"].get_node("Face") as CharacterPortrait).greyed \
		and (b.crew_rows[&"pip"].get_node("Status") as Label).text.contains("Active")
	b.free()
	return ok

func test_offers_ask_on_the_board() -> bool:
	StoryFlags.set_flag(&"scouted")
	var b := _board()
	await Sim.process_frames(1)
	var asked: bool = b.offer_dialog.visible and b.offer_dialog.team.id == &"skyline_juniors"
	b.offer_dialog.confirmed.emit()
	await Sim.process_frames(1)
	var ok: bool = asked and b._header.text.contains("Skyline Juniors") and _flyable(b) == [&"spotter_drill", &"test_race"]
	b.free()
	await Sim.process_frames(1)
	Sim.tree().unload_current_scene()  # the recruitment scene (Story 11.2)
	await Sim.process_frames(1)
	return ok

func test_fly_opens_the_job_scene() -> bool:
	Sim.tree().change_scene_to_file(BOARD)
	await Sim.process_frames(3)
	var b: JobBoard = Sim.tree().current_scene
	b.fly_button(&"test_race").pressed.emit()
	await Sim.process_frames(3)
	var ok := Sim.tree().current_scene.scene_file_path == "res://scenes/jobs/test_race.tscn"
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)
	return ok

# Story 17.4: job carousel.

func _press(b: JobBoard, action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	b.carousel.grab_focus()
	b.get_viewport().push_input(e)

func test_carousel_flips_and_wraps_with_dots() -> bool:
	PlayerProfile.choose_pilot(&"pip")
	var b := _board()
	await Sim.process_frames(1)
	var c := b.carousel
	var n := c.cards.size()
	var ok: bool = n == b.job_ids.size() and n == c.dots.count and c.index == 0
	_press(b, &"ui_right")
	await Sim.process_frames(1)
	ok = ok and c.index == 1 and c.dots.current == 1 and c.cards[1].visible and not c.cards[0].visible
	c.go(n - 1)
	_press(b, &"ui_right")
	await Sim.process_frames(1)
	ok = ok and c.index == 0 and c.dots.current == 0
	_press(b, &"ui_left")
	await Sim.process_frames(1)
	ok = ok and c.index == n - 1 and c.dots.current == n - 1 and c.current().visible
	c.next_button.pressed.emit()
	ok = ok and c.index == 0
	c.prev_button.pressed.emit()
	ok = ok and c.index == n - 1
	b.free()
	return ok

func test_enter_flies_an_unlocked_card_and_shakes_a_locked_one() -> bool:
	PlayerProfile.choose_pilot(&"pip")
	Sim.tree().change_scene_to_file(BOARD)
	await Sim.process_frames(3)
	var b: JobBoard = Sim.tree().current_scene
	b.carousel.go(b.job_ids.find(&"sample_delivery"))
	_press(b, &"ui_accept")
	await Sim.process_frames(3)
	var stayed: bool = Sim.tree().current_scene == b and b.carousel.shakes == 1
	var locked: Label = b.job_rows[&"sample_delivery"].get_node("Locked")
	var short: bool = locked.text == "Join Harbor Couriers" and locked.tooltip_text.contains("Harbor Couriers") \
		and b.job_rows[&"sample_delivery"].get_child(0).find_child("Padlock", true, false) != null \
		and b.job_rows[&"test_race"].get_child(0).find_child("Padlock", true, false) == null
	b.carousel.go(b.job_ids.find(&"test_race"))
	_press(b, &"ui_accept")
	await Sim.process_frames(3)
	var flew := Sim.tree().current_scene.scene_file_path == "res://scenes/jobs/test_race.tscn"
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)
	return stayed and short and flew

func test_comms_face_is_living_crew_on_that_job() -> bool:
	Career.team_id = &"harbor_couriers"
	var b := _board()
	await Sim.process_frames(1)
	var ok := true
	for id in b.job_ids:
		var job: Job = b.jobs.by_id(id)
		var comms: Node = b.job_rows[id].get_child(0).get_node_or_null("Comms")
		if job == null or comms == null:
			continue
		var face: CharacterPortrait = comms.get_node("Face")
		var who := face.character.id
		var briefs := &"briefing" in face.character.speaks_on
		ok = ok and Roster.is_alive(who) and (who in job.crew_in_field or who in job.requires_living or briefs) \
			and face.expression in CharacterPortrait.EXPRESSIONS \
			and (comms.find_child("Pitch", true, false) as Label).text.contains(Bark.pitch(who, id).text)
	var inspection: CharacterPortrait = b.job_rows[&"inspection"].get_child(0).get_node("Comms/Face")
	ok = ok and inspection.character.id == &"marlo"
	b.free()
	Roster.kill(&"marlo")
	b = _board()
	await Sim.process_frames(1)
	var stand_in: CharacterPortrait = b.job_rows[&"inspection"].get_child(0).get_node("Comms/Face")
	ok = ok and stand_in.character.id != &"marlo" and Roster.is_alive(stand_in.character.id)
	b.free()
	Career.team_id = &""
	return ok

func test_opens_on_start_here_then_the_last_job_flown() -> bool:
	var b := _board()
	await Sim.process_frames(1)
	var fresh: bool = b.job_ids[b.carousel.index] == &"test_race" \
		and b.carousel.current().find_child("StartHere", true, false) != null
	b.free()
	Career.team_id = &"harbor_couriers"
	Career.job_flown(&"inspection", "B")
	Career.job_flown(&"inspection", "C")
	Career.load_saved()
	b = _board()
	await Sim.process_frames(1)
	var last: bool = b.job_ids[b.carousel.index] == &"inspection" \
		and (b.job_rows[&"inspection"].get_child(0).get_node("Grade") as Label).text.ends_with("B")
	b.free()
	Career.team_id = &""
	return fresh and last
