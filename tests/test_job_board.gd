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
	Roster.injure(&"sanjaya")  # one job with Sushena fit (Story 19.6)
	Roster.kill(&"bhima")
	var b := _board()
	await Sim.process_frames(1)
	var sanjaya: String = (b.crew_rows[&"sanjaya"].get_node("Info/Status") as Label).text
	var bhima: String = (b.crew_rows[&"bhima"].get_node("Info/Status") as Label).text
	var ok: bool = b.crew_rows.size() == 6 and sanjaya.contains("Injured") and sanjaya.contains("1 more job") \
		and bhima.contains("Died.") and bhima.contains(Bark.memorial(&"bhima")) \
		and (b.crew_rows[&"bhima"].get_node("Face") as CharacterPortrait).greyed \
		and not (b.crew_rows[&"sanjaya"].get_node("Face") as CharacterPortrait).greyed \
		and (b.crew_rows[&"arjuna"].get_node("Info/Status") as Label).text.contains("Active")
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
	PlayerProfile.choose_pilot(&"arjuna")
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
	PlayerProfile.choose_pilot(&"arjuna")
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
	ok = ok and inspection.character.id == &"sanjaya"
	b.free()
	Roster.kill(&"sanjaya")
	b = _board()
	await Sim.process_frames(1)
	var stand_in: CharacterPortrait = b.job_rows[&"inspection"].get_child(0).get_node("Comms/Face")
	ok = ok and stand_in.character.id != &"sanjaya" and Roster.is_alive(stand_in.character.id)
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

# Story 17.5: menu and navigation.

func _act(b: JobBoard, action: StringName) -> Control:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	b.get_viewport().push_input(e)
	# Buttons fire on release.
	var up := e.duplicate()
	up.pressed = false
	b.get_viewport().push_input(up)
	await Sim.process_frames(1)
	return b.get_viewport().gui_get_focus_owner()

func test_every_old_footer_action_is_reachable_by_keyboard() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	Sim.tree().change_scene_to_file(BOARD)
	await Sim.process_frames(3)
	var b: JobBoard = Sim.tree().current_scene
	var f := b.get_viewport().gui_get_focus_owner()
	var ok: bool = f == b.menu_button(&"Fly") and b.page == &"jobs"
	# Left and right on FLY flip the cards; focus stays.
	f = await _act(b, &"ui_right")
	ok = ok and f == b.menu_button(&"Fly") and b.carousel.index == 1
	f = await _act(b, &"ui_left")
	ok = ok and b.carousel.index == 0
	f = await _act(b, &"ui_down")
	ok = ok and f == b.menu_button(&"FreeFlight")
	f = await _act(b, &"ui_down")
	ok = ok and f == b.menu_button(&"Garage")
	await _act(b, &"ui_accept")
	ok = ok and b.shop.visible
	b.shop.hide()
	b.menu_button(&"Garage").grab_focus()
	f = await _act(b, &"ui_down")
	ok = ok and f == b.menu_button(&"Pilot")
	await _act(b, &"ui_accept")
	ok = ok and b.pilot_select.visible
	b.pilot_select.hide()
	await Sim.process_frames(1)
	b.menu_button(&"Pilot").grab_focus()
	f = await _act(b, &"ui_down")
	ok = ok and f == b.menu_button(&"Crew")
	f = await _act(b, &"ui_accept")
	ok = ok and b.page == &"crew" and b.pages[&"crew"].visible and f == b.pages[&"crew"]
	f = await _act(b, &"ui_cancel")
	ok = ok and b.page == &"jobs" and f == b.menu_button(&"Crew")
	f = await _act(b, &"ui_down")
	ok = ok and f == b.menu_button(&"Options")
	f = await _act(b, &"ui_accept")
	ok = ok and b.page == &"options" and f.name == "Sound"
	await _act(b, &"ui_accept")
	ok = ok and b.sound.visible
	b.sound.hide()
	f.grab_focus()
	f = await _act(b, &"ui_down")
	ok = ok and f.name == "Quality"
	f = await _act(b, &"ui_down")
	ok = ok and f.name == "WatchIntro"
	f = await _act(b, &"ui_cancel")
	ok = ok and b.page == &"jobs" and f == b.menu_button(&"Options")
	# The menu wraps, and Esc from the menu is the title.
	f = await _act(b, &"ui_down")
	ok = ok and f == b.menu_button(&"Fly")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	b.get_viewport().push_input(esc)
	await Sim.process_frames(3)
	ok = ok and Sim.tree().current_scene is TitleScreen
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)
	return ok

func test_focus_never_lands_on_hidden_or_disabled() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	Roster.kill(&"nala")
	var b := _board()
	await Sim.process_frames(1)
	var ok: bool = b.menu_button(&"Garage").disabled
	b.menu_button(&"Fly").grab_focus()
	for action in [&"ui_down", &"ui_down", &"ui_down", &"ui_down", &"ui_down", &"ui_down", &"ui_up", &"ui_up", &"ui_left", &"ui_right"]:
		var f := await _act(b, action)
		ok = ok and f != null and f.is_visible_in_tree() and not (f is BaseButton and f.disabled)
	b.open_options()
	for action in [&"ui_down", &"ui_down", &"ui_down", &"ui_up", &"ui_left"]:
		var f := await _act(b, action)
		ok = ok and f != null and f.is_visible_in_tree() and not (f is BaseButton and f.disabled)
	b.free()
	return ok

## Labels and buttons of the board at `size` that leave the screen or are
## squeezed under their own minimum size.
func _clipped(size: Vector2i, open_page: StringName) -> Array:
	var sv := SubViewport.new()
	sv.size = size
	Sim.add(sv)
	var b: JobBoard = load(BOARD).instantiate()
	sv.add_child(b)
	await Sim.process_frames(2)
	if open_page == &"options":
		b.open_options()
	await Sim.process_frames(2)
	var screen := Rect2(Vector2.ZERO, Vector2(size)).grow(1.0)
	var out := []
	for c in b.find_children("*", "Control", true, false):
		if not (c is Label or c is BaseButton) or not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		var squeezed: bool = c.size.x + 1.0 < c.get_combined_minimum_size().x or c.size.y + 1.0 < c.get_combined_minimum_size().y
		if not screen.encloses(r) or squeezed:
			out.append("%s %s" % [b.get_path_to(c), r])
	sv.free()
	return out

func test_nothing_clipped_at_960_and_1920() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	Roster.injure(&"sanjaya")
	Career.team_id = &"harbor_couriers"
	var bad := []
	for size in [Vector2i(960, 720), Vector2i(1920, 1080)]:
		for p in [&"jobs", &"options"]:
			bad.append_array(await _clipped(size, p))
	Career.team_id = &""
	if not bad.is_empty():
		print("        ", bad)
	return bad.is_empty()

func test_crew_page_shows_everyone_with_big_faces() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	Roster.kill(&"bhima")
	var b := _board()
	await Sim.process_frames(1)
	b.open_crew()
	var ok: bool = b.pages[&"crew"].visible and not b.carousel.visible and b.crew_rows.size() == Roster.ids().size() \
		and b.get_viewport().gui_get_focus_owner() == b.pages[&"crew"]
	for id in Roster.ids():
		var face: CharacterPortrait = b.crew_rows[id].get_node("Face")
		ok = ok and b.pages[&"crew"].is_ancestor_of(face) and face.custom_minimum_size.x >= 80
	ok = ok and (b.crew_rows[&"bhima"].get_node("Face") as CharacterPortrait).greyed \
		and (b.crew_rows[&"bhima"].get_node("Info/Status") as Label).text.contains(Bark.memorial(&"bhima"))
	b.free()
	return ok
