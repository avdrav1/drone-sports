extends RefCounted
# Story 17.12: the story crawl on the title says why you are playing, rolls up
# from PRESS START towards the logo, loops, and never gets in the way of Start.

const Sim = preload("res://tests/sim.gd")
const TITLE := "res://scenes/ui/title.tscn"

func _open() -> TitleScreen:
	Sim.tree().change_scene_to_file(TITLE)
	await Sim.process_frames(3)
	return Sim.tree().current_scene

func _close() -> void:
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)

func test_story_says_why_you_are_playing() -> bool:
	var c: Crawl = load(TitleScreen.CRAWL)
	var paras := c.text.split("\n\n", false)
	var t := c.text.to_lower()
	return paras.size() >= 5 and StoryCrawl.is_heading(paras[0].strip_edges()) \
		and paras[-1].strip_edges() == "THIS IS JAISALMER" \
		and t.contains("tryout") and t.contains("scout") and t.contains("crew") and c.speed > 0.0

func test_crawl_sits_between_logo_and_press_start() -> bool:
	var t := await _open()
	var crawl := t.crawl
	var ok := crawl != null and crawl.is_visible_in_tree() \
		and crawl.anchor_top >= t.title_mark.anchor_bottom - 0.05 \
		and crawl.anchor_bottom <= t.press_start.anchor_top + 0.001 \
		and crawl.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and crawl.paragraphs().size() == (load(TitleScreen.CRAWL) as Crawl).text.split("\n\n", false).size() \
		and crawl.text_height > crawl.size.y
	await _close()
	return ok

func test_crawl_rolls_up_and_loops() -> bool:
	var t := await _open()
	var crawl := t.crawl
	var before := crawl.scroll
	await Sim.process_frames(10)
	var rising := crawl.scroll > before
	crawl.scroll = crawl.end() - 0.01
	await Sim.process_frames(2)
	# Starts over below the bottom edge, after the pause.
	var looped := crawl.loops == 1 and crawl.scroll < 0.0
	await _close()
	return rising and looped

func test_start_works_mid_crawl() -> bool:
	var t := await _open()
	t._age = t.start_grace
	t.crawl.scroll = t.crawl.text_height * 0.5
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	t.get_viewport().push_input(ev)
	await Sim.process_frames(3)
	var ok := Sim.tree().current_scene is JobBoard
	await _close()
	return ok
