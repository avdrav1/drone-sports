extends RefCounted
# Story 17.11: the board explains itself in arcade type: what it is for, what
# each job asks, what the focused menu item does, and the controls.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"

func _board() -> JobBoard:
	PlayerProfile.choose_pilot(PlayerProfile.pilots()[0].id)
	return Sim.add(load(BOARD).instantiate())

func test_every_board_job_says_what_you_do() -> bool:
	var jobs: JobList = load(JobBoard.JOBS)
	for job in jobs.jobs:
		if job.summary.strip_edges().length() < 20:
			return false
	return true

func test_cards_show_the_summary() -> bool:
	var b := _board()
	await Sim.process_frames(1)
	var ok := true
	for id in b.job_rows:
		var job: Job = null
		for j in b.jobs.jobs:
			if j.id == id:
				job = j
		if job == null:
			continue  # the Lattice keeps its own text
		var s := b.job_rows[id].get_child(0).get_node_or_null("Summary") as Label
		ok = ok and s != null and s.text == job.summary
	b.free()
	return ok

func test_how_to_and_controls_are_on_screen() -> bool:
	var b := _board()
	await Sim.process_frames(1)
	var how := b.find_child("HowTo", true, false) as Label
	var keys := b.find_child("Controls", true, false) as Label
	var ok := how != null and how.is_visible_in_tree() and how.text.contains("job") \
		and keys != null and keys.is_visible_in_tree() and keys.text.contains("ENTER") and keys.text.contains("ESC")
	b.free()
	return ok

func test_menu_hint_follows_focus() -> bool:
	var b := _board()
	await Sim.process_frames(1)
	var ok := b.menu_hint.text == JobBoard.MENU_HINTS[&"Fly"]
	for item in [&"FreeFlight", &"Crew", &"Options"]:
		b.menu_button(item).grab_focus()
		ok = ok and b.menu_hint.text == JobBoard.MENU_HINTS[item]
	# Every menu button has a hint, and the hint is not a stop for up and down.
	for c in b.menu.get_children():
		if c is Button:
			ok = ok and JobBoard.MENU_HINTS.has(StringName(c.name))
	ok = ok and b.menu_hint.focus_mode == Control.FOCUS_NONE
	b.free()
	return ok

func test_counter_tracks_the_card() -> bool:
	var b := _board()
	await Sim.process_frames(1)
	var n := b.carousel.cards.size()
	b.carousel.go(0)
	var first := b.carousel.counter.text
	b.carousel.prev()
	var last := b.carousel.counter.text
	b.free()
	return first == "JOB 1 OF %d" % n and last == "JOB %d OF %d" % [n, n]

func test_cabinet_uses_the_arcade_font_with_its_licence() -> bool:
	var cab: FrontSkin = load(FrontSkin.CABINET)
	var f := cab.display_font as FontVariation
	var file := f.base_font if f else null
	return file != null and file.resource_path == "res://data/ui/fonts/PressStart2P-Regular.ttf" \
		and FileAccess.file_exists("res://data/ui/fonts/OFL.txt") \
		and FileAccess.get_file_as_string("res://data/ui/fonts/README.md").contains("PressStart2P-Regular.ttf")
