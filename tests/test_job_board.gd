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
	out.sort()
	return out

func test_reached_at_launch_and_jobs_come_back() -> bool:
	var runner := JobRunner.new()
	var results: Control = load("res://scenes/ui/results.tscn").instantiate()
	# The intro is the main scene and forwards here (Story 11.1).
	var intro: Cutscene = load("res://data/story/intro.tres")
	var ok: bool = intro.next_scene == BOARD and runner.back_scene == BOARD and results.continue_scene == BOARD
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
	var ok: bool = asked and b._header.text.contains("Skyline Juniors") and _flyable(b) == [&"test_race"]
	b.free()
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
