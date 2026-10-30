extends RefCounted
# Story 24.6: the name lettered like Hindi. The title screen and the intro's
# title card draw it in the title font, hanging from one unbroken headline bar
# that touches every letter and runs past the word on both sides, fully on
# screen at 960x720 and 1920x1080; a changed name redraws; the font's licence
# is in the repo and listed. The look itself is the owner's call: Amita, the
# i-matra's loop over the letter after the I, saffron to gold edged in maroon.

const Sim = preload("res://tests/sim.gd")
const TITLE := "res://scenes/ui/title.tscn"
const INTRO := "res://scenes/story/intro.tscn"

## The bar spans the word, every letter reaches into it, and it all fits `area`.
func _hangs(m: TitleMark, area: Rect2) -> bool:
	var ink := m.letters()
	var b := m.bar()
	var word := m.word.replace(" ", "")
	if ink.size() != word.length() or b.size.x <= 0.0:
		return false
	var to_screen := m.get_global_transform()
	var ok := to_screen * b.position >= area.position and area.end >= to_screen * b.end
	for r in ink:
		ok = ok and b.position.x < r.position.x and r.end.x < b.end.x \
			and r.position.y <= b.end.y and r.end.y >= b.position.y \
			and area.has_point(to_screen * r.position) and area.has_point(to_screen * r.end)
	return ok

## The matra rises from the I, above the bar, over the next letter, on screen.
func _loops(m: TitleMark, area: Rect2) -> bool:
	var loop := m.matra_loop()
	var ink := m.letters()
	var at := m.word.replace(" ", "").find("I")
	if loop.size() < 2 or at < 0:
		return false
	var b := m.bar()
	var to_screen := m.get_global_transform()
	var top := INF
	for p in loop:
		top = minf(top, p.y)
		if not area.has_point(to_screen * p):
			return false
	return ink[at].has_point(Vector2(loop[0].x, ink[at].get_center().y)) \
		and loop[loop.size() - 1].x > ink[at + 1].get_center().x \
		and top < b.position.y - m.size_used * 0.3

## Opens `path` in a `size` window and returns its title mark, on the title card.
func _open(path: String, size: Vector2i) -> Array:
	var sv := SubViewport.new()
	sv.size = size
	Sim.add(sv)
	var scene: Node = load(path).instantiate()
	if scene is CutscenePlayer:
		scene.cutscene = scene.cutscene.duplicate()
		scene.cutscene.seen_flag = &""
		scene.cutscene.beats = scene.cutscene.beats.filter(func(b): return b.game_title)
	sv.add_child(scene)
	await Sim.process_frames(2)
	return [sv, scene.title_mark]

func test_both_screens_use_the_title_font() -> bool:
	var ok := TitleMark.FONT.resource_path.begins_with("res://data/ui/fonts/")
	for path in [TITLE, INTRO]:
		var opened := await _open(path, Vector2i(1280, 720))
		var m: TitleMark = opened[1]
		ok = ok and m.font == TitleMark.FONT and m.is_visible_in_tree() and m.word == "JAISALMER"
		opened[0].free()
	return ok

func test_bar_spans_the_word_on_both_screen_sizes() -> bool:
	var ok := true
	for size in [Vector2i(960, 720), Vector2i(1920, 1080)]:
		for path in [TITLE, INTRO]:
			var opened := await _open(path, size)
			var m: TitleMark = opened[1]
			if not _hangs(m, Rect2(Vector2.ZERO, size)):
				push_error("%s at %s: the bar does not hang the word on screen" % [path, size])
				ok = false
			if not _loops(m, Rect2(Vector2.ZERO, size)):
				push_error("%s at %s: the matra is not over the I and on screen" % [path, size])
				ok = false
			opened[0].free()
	return ok

func test_saffron_with_a_maroon_edge() -> bool:
	var opened := await _open(TITLE, Vector2i(1280, 720))
	var m: TitleMark = opened[1]
	var fill: Control = m.get_child(0, true)
	var mat := fill.material as ShaderMaterial
	var ok: bool = m.saffron and mat != null and mat.shader == TitleMark.GRADIENT \
		and mat.get_shader_parameter("top_color") == m.top_color \
		and mat.get_shader_parameter("bottom") > mat.get_shader_parameter("top") \
		and m.edge_color.r > m.edge_color.g * 4.0
	opened[0].free()
	return ok

func test_a_new_name_redraws() -> bool:
	var m := TitleMark.new()
	m.size = Vector2(1280, 180)
	Sim.add(m)
	var was = ProjectSettings.get_setting(GameName.SETTING)
	ProjectSettings.set_setting(GameName.SETTING, "Sand Castle")
	await Sim.process_frames(1)
	var renamed := m.word == "SAND CASTLE" and _hangs(m, Rect2(Vector2.ZERO, m.size))
	ProjectSettings.set_setting(GameName.SETTING, was)
	await Sim.process_frames(1)
	var back := m.word == "JAISALMER"
	m.free()
	return renamed and back

func test_the_font_is_licensed_and_listed() -> bool:
	var file := TitleMark.FONT.resource_path.get_file()
	var licence := "res://data/ui/fonts/%s.OFL.txt" % file.get_basename().get_slice("-", 0)
	return FileAccess.get_file_as_string(licence).contains("SIL Open Font License") \
		and FileAccess.get_file_as_string("res://data/ui/fonts/README.md").contains(file) \
		and FileAccess.get_file_as_string("res://data/LICENSES.md").contains("ui/fonts/" + file)
