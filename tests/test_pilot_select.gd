extends RefCounted
# Story 7.2: pilot select. Pip by default; the choice persists in the save; the
# race HUD and the flight HUD show the chosen portrait; switching pilots changes
# only that pilot's edge stats; only pilot-tagged characters are offered; a new
# game reaches the screen before the first job.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"
const INTRO := "res://scenes/story/intro.tscn"
const ACT1 := preload("res://data/assists/act1.tres")

func test_default_is_pip_and_every_pilot_validates() -> bool:
	var ok: bool = not PlayerProfile.has_pilot() and PlayerProfile.pilot().id == &"pip"
	var pilots := PlayerProfile.pilots()
	ok = ok and pilots.size() >= 4 and pilots[0].id == &"pip"
	for c in pilots:
		ok = ok and c.validate().is_empty() and not c.can_be_harmed and ResourceLoader.exists(c.lines)
		if c.id != &"pip":
			ok = ok and c.edge != null and Roster.character(c.id) == null  # the crew of six is unchanged
	return ok and Roster.ids().size() == 6

func test_choice_persists_across_load() -> bool:
	var ok := PlayerProfile.choose_pilot(&"fen") and not PlayerProfile.choose_pilot(&"marlo")
	SaveGame.load_all(Sim.tree())
	var profile: Dictionary = SaveGame.read_section("profile", {})
	return ok and PlayerProfile.has_pilot() and PlayerProfile.pilot().id == &"fen" and profile.pilot == "fen" \
		and PlayerProfile.handle() == PlayerProfile.DEFAULT_HANDLE

func test_screen_lists_only_pilots() -> bool:
	var s := PilotSelect.new()
	Sim.add(s)
	var ok: bool = s.ids() == [&"pip", &"tally", &"fen", &"moss"]
	for id in s.ids():
		ok = ok and &"pilot" in s.cards[id].find_child("Face", true, false).character.tags
	for id in Roster.ids():
		ok = ok and (id == &"pip") == s.cards.has(id)
	ok = ok and not s.find_child("Back", true, false).visible  # nothing chosen yet
	s.choose_button(&"moss").pressed.emit()
	ok = ok and PlayerProfile.pilot().id == &"moss" and not s.visible
	s.free()
	return ok

func test_race_hud_and_flight_hud_show_the_pilot() -> bool:
	PlayerProfile.choose_pilot(&"tally")
	var d := Sim.drone(Sim.intent(), Vector3(0, 20, 0))
	d.freeze = true
	var course := Course.new()
	course.data = load("res://data/courses/test_loop.tres")
	Sim.add(course)
	course.add_racer(d)
	var race := RaceHud.new()
	race.course = course
	race.racer = d
	Sim.add(race)
	var flight := FlightHud.new()
	flight.drone = d
	Sim.add(flight)
	await Sim.process_frames(2)
	var ok: bool = race.pilot_face.character.id == &"tally" and race.pilot_face.visible \
		and flight.pilot_face.character.id == &"tally" and flight.pilot_face.visible
	# In the race scene the race HUD owns the corner, so the flight HUD's stays hidden.
	var scene: Node = load("res://scenes/jobs/test_race.tscn").instantiate()
	ok = ok and scene.get_node("HUD/Flight").show_pilot == false and scene.get_node("HUD/Race") is RaceHud
	scene.free()
	race.free()
	flight.free()
	course.free()
	d.free()
	return ok

## Every exported number on the drone, its mass, and which assists are on.
func _fingerprint() -> Dictionary:
	var d := Sim.drone(Sim.intent(), Vector3(0, 20, 0), ACT1)
	Garage.apply(d)
	var out := {"mass": d.mass}
	for p in d.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_EDITOR \
				and p.type in [TYPE_FLOAT, TYPE_INT, TYPE_BOOL]:
			out[p.name] = d.get(p.name)
	for id in AssistStack.IDS:
		out["assist_" + String(id)] = d.assists.is_enabled(id) if id != &"single_drone_view" else true
	d.free()
	return out

func test_switching_pilot_changes_only_the_edge_stats() -> bool:
	var pip := PlayerProfile.pilot()
	var own := pip.edge
	pip.edge = null  # the drone with no edge at all
	var base := _fingerprint()
	pip.edge = own
	var ok := base.size() > 6
	for c in PlayerProfile.pilots():
		PlayerProfile.choose_pilot(c.id)
		var now := _fingerprint()
		var want := base.duplicate()
		for s in c.edge.stats if c.edge else []:
			want[String(s.stat)] += s.step
		for key in base:
			ok = ok and (is_equal_approx(now[key], want[key]) if now[key] is float else now[key] == want[key])
	return ok

func test_new_game_reaches_pilot_select() -> bool:
	Sim.tree().change_scene_to_file(INTRO)
	await Sim.process_frames(3)
	var p := Sim.tree().current_scene as CutscenePlayer
	p.finish()
	await Sim.process_frames(3)
	(Sim.tree().current_scene as TitleScreen).start()  # PRESS START (Story 17.3)
	await Sim.process_frames(3)
	var b := Sim.tree().current_scene as JobBoard
	var ok: bool = b != null and b.pilot_select.visible
	# Keyboard and pad focus cannot leave the screen for the board behind it.
	var ps := b.pilot_select
	var first := ps.choose_button(ps.ids()[0])
	var last := ps.choose_button(ps.ids()[-1])
	ok = ok and ps.is_ancestor_of(last.find_next_valid_focus())
	ok = ok and ps.is_ancestor_of(first.find_prev_valid_focus())
	b.pilot_select.choose(&"fen")
	ok = ok and not b.pilot_select.visible and b.menu_button(&"Pilot").text == "PILOT  ·  Fen"
	# Closed, the board's own buttons take focus again.
	ok = ok and b.menu_button(&"Pilot").focus_mode != Control.FOCUS_NONE
	ok = ok and b.menu_button(&"Pilot").get_focus_mode_with_override() == Control.FOCUS_ALL
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)
	# Once chosen, the board opens straight to the jobs, and the menu reopens the screen.
	var b2: JobBoard = load(BOARD).instantiate()
	Sim.add(b2)
	ok = ok and not b2.pilot_select.visible
	b2.menu_button(&"Pilot").pressed.emit()
	ok = ok and b2.pilot_select.visible and b2.pilot_select.find_child("Back", true, false).visible
	b2.free()
	return ok
