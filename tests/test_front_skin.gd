extends RefCounted
# Story 17.6: cabinet and ops skins. Act 1 wears the arcade cabinet (scanlines,
# a coin chime on Start); from Act 2 the ops console in the team's colors, from
# the board right after the recruitment scene. Any added font is licensed.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"
const TITLE := "res://scenes/ui/title.tscn"
const RECRUITED := "res://scenes/story/recruited.tscn"
const FONTS := "res://data/ui/fonts"

func _open(path: String) -> Node:
	Sim.tree().change_scene_to_file(path)
	await Sim.process_frames(3)
	return Sim.tree().current_scene

func _close() -> void:
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)

## The screen is themed from `skin`: its panels carry the skin's border.
func _wears(theme: Theme, skin: FrontSkin) -> bool:
	var panel := theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	return panel != null and panel.border_color == skin.border and panel.bg_color == skin.panel

func test_act_picks_the_skin() -> bool:
	var team: Team = Career.teams.by_id(&"harbor_couriers")
	var home := FrontSkin.for_act(1)
	var ops := FrontSkin.for_act(2, team)
	var later := FrontSkin.for_act(4, Career.teams.by_id(&"city_rescue_air"))
	return home.id == &"cabinet" and home.scanlines and home.start_sound == &"coin_chime" \
		and ops.id == &"ops" and not ops.scanlines and ops.start_sound == &"" \
		and ops.accent == team.colors[0] and later.accent != ops.accent \
		and FrontSkin.current().id == &"cabinet"

func test_every_front_end_screen_wears_the_cabinet_in_act_1() -> bool:
	PlayerProfile.choose_pilot(&"pip")
	var b: JobBoard = await _open(BOARD)
	# The CREW page, unfocused, is a panel in the skin's colors.
	var crew: PanelContainer = b.pages[&"crew"]
	var ok: bool = Career.act() == 1 and b.skin.id == &"cabinet" and _wears(b.theme, b.skin) \
		and b.get_node_or_null("Scanlines") != null and b.get_node("Scanlines").size == b.size and b.menu.get_theme_font("font", "Button") == b.skin.display_font \
		and (crew.get_theme_stylebox("panel") as StyleBoxFlat).border_color == b.skin.border
	await _close()
	var t: TitleScreen = await _open(TITLE)
	ok = ok and t.skin.id == &"cabinet" and _wears(t.title_label.get_parent().theme, t.skin) \
		and t.find_child("Scanlines", true, false) != null
	var chimes := Sfx.count(&"coin_chime")
	t.start()
	ok = ok and Sfx.count(&"coin_chime") == chimes + 1
	await Sim.process_frames(3)
	await _close()
	return ok

func test_ops_skin_in_the_team_colors_from_act_2() -> bool:
	PlayerProfile.choose_pilot(&"pip")
	Career.team_id = &"harbor_couriers"
	var colors: PackedColorArray = Career.team().colors
	var b: JobBoard = await _open(BOARD)
	var ok: bool = b.skin.id == &"ops" and b.skin.accent == colors[0] and _wears(b.theme, b.skin) \
		and b.get_node_or_null("Scanlines") == null and b.carousel.accent == colors[0]
	await _close()
	var t: TitleScreen = await _open(TITLE)
	var chimes := Sfx.count(&"coin_chime")
	ok = ok and t.skin.id == &"ops" and t.title_label.get_theme_color("font_color") == colors[0] \
		and t.find_child("Scanlines", true, false) == null
	t.start()
	ok = ok and Sfx.count(&"coin_chime") == chimes
	await Sim.process_frames(3)
	await _close()
	Career.team_id = &""
	return ok

func test_board_after_the_recruitment_scene_wears_ops() -> bool:
	PlayerProfile.choose_pilot(&"pip")
	StoryFlags.set_flag(&"intro_seen")
	StoryFlags.set_flag(&"scouted")
	var before: JobBoard = await _open(BOARD)
	var cabinet: bool = before.skin.id == &"cabinet"
	before.offer_dialog.confirmed.emit()
	await Sim.process_frames(3)
	var p := Sim.tree().current_scene as CutscenePlayer
	var played: bool = p != null and p.scene_file_path == RECRUITED
	while is_instance_valid(p) and not p.done:
		p.t = p.beat.duration
		await Sim.process_frames(1)
	await Sim.process_frames(3)
	var b := Sim.tree().current_scene as JobBoard
	var ok: bool = cabinet and played and b != null and b.skin.id == &"ops" \
		and b.skin.accent == Career.team().colors[0] and _wears(b.theme, b.skin)
	await _close()
	return ok

func test_any_added_font_has_its_license_beside_it() -> bool:
	var dir := DirAccess.open(FONTS)
	if dir == null:
		return true  # no fonts added: the skins vary the engine's own
	var ok := true
	for f in dir.get_files():
		if f.get_extension() in ["ttf", "otf", "woff", "woff2"]:
			var base := f.get_basename()
			ok = ok and (dir.file_exists(base + ".LICENSE.txt") or dir.file_exists("OFL.txt") or dir.file_exists("LICENSE.txt"))
	return ok
