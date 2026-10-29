extends RefCounted
# Story 24.1: the game is called Jaisalmer, and the name lives in one place:
# `application/config/name`. The title logo and the intro's title card read it,
# the crawl ends on THIS IS JAISALMER, and no text under scripts/, scenes/ or
# data/ still calls the game Drone Sports.

const Sim = preload("res://tests/sim.gd")
const TITLE := "res://scenes/ui/title.tscn"
const INTRO := "res://scenes/story/intro.tscn"
const SCANNED := ["res://scripts", "res://scenes", "res://data"]
const TEXT_FILES := ["gd", "tres", "tscn", "json", "txt", "md", "cfg", "csv", "gdshader"]
## Lower-case "drone sports" is the sport in the fiction, and may stay in lines
## and dialogue: file path -> how many times it says so. Nothing does yet.
const ALLOWED := {}

func _close() -> void:
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)

## Opens `path` with the name set to `name`, and returns the title text it shows.
## The name goes back at once: on desktop it also names the user:// folder.
func _shown_with(path: String, name: String) -> String:
	var was = ProjectSettings.get_setting(GameName.SETTING)
	ProjectSettings.set_setting(GameName.SETTING, name)
	var scene: Node = load(path).instantiate()
	if scene is CutscenePlayer:
		scene.cutscene = scene.cutscene.duplicate()
		scene.cutscene.seen_flag = &""
		scene.cutscene.beats = scene.cutscene.beats.filter(func(b): return b.game_title)
	Sim.tree().root.add_child(scene)
	Sim.tree().current_scene = scene
	var text: String = scene.title_label.text
	ProjectSettings.set_setting(GameName.SETTING, was)
	await _close()
	return text

func test_the_name_is_jaisalmer() -> bool:
	return ProjectSettings.get_setting(GameName.SETTING) == "Jaisalmer" and GameName.title() == "JAISALMER"

func test_title_screen_reads_the_setting() -> bool:
	var shown := await _shown_with(TITLE, "Jaisalmer")
	var renamed := await _shown_with(TITLE, "Sand Castle")
	return shown == "JAISALMER" and renamed == "SAND CASTLE"

func test_intro_title_card_reads_the_setting() -> bool:
	var c: Cutscene = load("res://data/story/intro.tres")
	var cards := c.beats.filter(func(b): return b.game_title)
	var shown := await _shown_with(INTRO, "Jaisalmer")
	var renamed := await _shown_with(INTRO, "Sand Castle")
	return cards.size() == 1 and cards[0].title == "" and shown == "JAISALMER" and renamed == "SAND CASTLE"

func test_crawl_ends_on_the_name() -> bool:
	var c: Crawl = load(TitleScreen.CRAWL)
	return c.text.strip_edges().ends_with("THIS IS JAISALMER")

func test_no_text_calls_the_game_drone_sports() -> bool:
	var found := {}
	for dir in SCANNED:
		_scan(dir, found)
	var ok := true
	for file in found:
		var hits: Array = found[file]
		var sport_only := hits.all(func(h): return h == "drone sports")
		if not (sport_only and ALLOWED.get(file, 0) == hits.size()):
			push_error("%s calls the game %s" % [file, hits])
			ok = false
	return ok

## Every "drone sports", any case, in the text files under `dir`, by file.
func _scan(dir: String, found: Dictionary) -> void:
	var re := RegEx.create_from_string("(?i)drone sports")
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(sub), found)
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() not in TEXT_FILES:
			continue
		var path := dir.path_join(file)
		var hits := re.search_all(FileAccess.get_file_as_string(path)).map(func(m): return m.get_string())
		if not hits.is_empty():
			found[path] = hits
