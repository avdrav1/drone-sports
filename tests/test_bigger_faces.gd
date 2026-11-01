extends RefCounted
# Story 26.3: bigger faces. Every place a face shows draws it at least twice
# its old size; at 960x720 and 1920x1080 no face overlaps text or another
# control, on the screens, in the HUDs, over the fleet and on the intro's
# cards; pad focus and mouse clicks still reach every control. (The radio
# panel's face is 26.4's, in test_radio_*.)

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"
const RESULTS := preload("res://scripts/ui/results.gd")
const SCREENS: Array[Vector2i] = [Vector2i(960, 720), Vector2i(1920, 1080)]

## Old size -> where it showed, before Story 26.3.
const OLD := {
	"comms": 64.0, "crew": 88.0, "pilot": 64.0, "results": 48.0, "warning": 72.0,
	"flight": 56.0, "race": 64.0, "fleet": 34.0, "intro": 160.0,
}

func _in_viewport(size: Vector2i) -> SubViewport:
	var sv := SubViewport.new()
	sv.size = size
	Sim.add(sv)
	return sv

## Where `c` shows: its rect cut to every ScrollContainer it sits in.
func _shown(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var p := c.get_parent()
	while p:
		if p is ScrollContainer:
			r = r.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	return r

## "face overlaps thing" for every visible face in `root` that overlaps text,
## a control, or another face, or leaves the screen. Containers a face sits in
## do not count.
func _overlaps(root: Node, size: Vector2i) -> Array:
	var out := []
	var screen := Rect2(Vector2.ZERO, Vector2(size)).grow(0.5)
	var faces: Array = root.find_children("*", "CharacterPortrait", true, false).filter(func(f): return f.is_visible_in_tree())
	var others: Array = root.find_children("*", "Control", true, false).filter(func(c): return c.is_visible_in_tree() \
		and (c is Label or c is RichTextLabel or c is BaseButton or c is Range or c is CharacterPortrait))
	for f in faces:
		var fr := _shown(f)
		if not fr.has_area():
			continue
		if not screen.encloses(f.get_global_rect()) and fr == f.get_global_rect():
			out.append("%s leaves the screen at %s" % [root.get_path_to(f), size])
		for o in others:
			if o == f or f.is_ancestor_of(o) or o.is_ancestor_of(f):
				continue
			var orr := _shown(o)
			if orr.has_area() and fr.grow(-1.0).intersects(orr.grow(-1.0)):
				out.append("%s overlaps %s at %s" % [root.get_path_to(f), root.get_path_to(o), size])
	return out

func _face_size(f: Control) -> float:
	return maxf(f.custom_minimum_size.x, f.size.x)

func _board(sv: Node, crew := false) -> JobBoard:
	var b: JobBoard = load(BOARD).instantiate()
	sv.add_child(b)
	await Sim.process_frames(2)
	if crew:
		b.open_crew()
		await Sim.process_frames(2)
	return b

func _pilot_select(sv: Node, act := 1) -> PilotSelect:
	var root := Control.new()
	root.theme = FrontSkin.for_act(act).theme()
	root.size = sv.size
	sv.add_child(root)
	var s := PilotSelect.new()
	root.add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await Sim.process_frames(3)
	return s

## A results screen with every kind of face row: an injury with its line, a
## death, the closing line; or with `farewell`, the final crew pass.
func _results(sv: Node, farewell := false) -> Control:
	var r := JobResult.new()
	r.job = load("res://data/jobs/demolition.tres")
	r.completed = true
	for l in ["Enter by the top", "Drop down the shaft", "Out the north window", "No contact", "Under 25 s", "Out before the roof"]:
		r.objectives.append({"label": l, "score": 0.5, "weight": 1})
	if farewell:
		for id in Roster.ids():
			r.epilogue.append({"id": id, "text": Bark.memorial(id) if id == &"bhima" else "Good flying. I mean it. Every call, you took it clean.", "alive": id != &"bhima"})
	else:
		r.strikes = {&"sanjaya": 1, &"bhima": 2}
		r.casualties = {&"sanjaya": Roster.Status.INJURED, &"bhima": Roster.Status.DEAD}
		r.casualty_lines = {&"sanjaya": "I can still see the board. Fly."}
		r.bark = {"id": &"nala", "text": "The bridge held. So did you.", "face": &"happy"}
	var screen: Control = load("res://scenes/ui/results.tscn").instantiate()
	sv.add_child(screen)
	screen.show_result(r)
	await Sim.process_frames(3)
	return screen

## A job scene that only shows: no pay, no results, no leaving.
func _job(path: String, sv: Node) -> Node:
	var s: Node = load(path).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	sv.add_child(s)
	await Sim.process_frames(3)
	return s

## The compass tape, its numbers and the heading under it.
func _tape(s: Vector2) -> Rect2:
	var w := minf(s.x * 0.42, 560.0)
	return Rect2(s.x * 0.5 - w * 0.5 - 30.0, 0.0, w + 60.0, 82.0)

## The ALT gauge at the right: its ladder and its readout.
func _alt_gauge(s: Vector2) -> Rect2:
	return Rect2(s.x - 242.0, s.y * 0.5 - 60.0, 188.0, 120.0)

## The job state line under the compass (the briefing, the clock), as drawn:
## its widest line, centred.
func _state_line(label: Label) -> Rect2:
	var font := label.get_theme_font("font")
	var fs := label.get_theme_font_size("font_size")
	var w := 0.0
	for line in label.text.split("\n"):
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var r := label.get_global_rect()
	return Rect2(r.get_center().x - w * 0.5, r.position.y, w, font.get_height(fs) * label.get_line_count())

func _clear(name: String, face: Rect2, things: Dictionary, size: Vector2i) -> Array:
	var out := []
	for t in things:
		if face.intersects(things[t]):
			out.append("%s face %s overlaps %s %s at %s" % [name, face, t, things[t], size])
	if not Rect2(Vector2.ZERO, Vector2(size)).encloses(face):
		out.append("%s face %s leaves the screen at %s" % [name, face, size])
	return out

func test_every_face_is_at_least_twice_its_old_size() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	var sizes := {}
	var sv := _in_viewport(SCREENS[0])
	var b := await _board(sv, true)
	sizes["comms"] = _face_size(b.carousel.current().find_child("Face", true, false))
	sizes["crew"] = Roster.ids().map(func(id): return _face_size(b.crew_rows[id].get_node("Face"))).min()
	b.free()
	var least_pilot := INF
	for size in SCREENS:
		sv.size = size
		var s := await _pilot_select(sv)
		least_pilot = minf(least_pilot, s.cards.values().map(func(c): return _face_size(c.find_child("Face", true, false))).min())
		s.get_parent().free()
	sizes["pilot"] = least_pilot
	sv.size = SCREENS[0]
	var screen := await _results(sv)
	var farewell := await _results(sv, true)
	sizes["results"] = (screen.find_children("*", "CharacterPortrait", true, false) + farewell.find_children("*", "CharacterPortrait", true, false)) \
		.map(func(f): return _face_size(f)).min()
	screen.free()
	farewell.free()
	var demolition := await _job("res://scenes/jobs/demolition.tscn", sv)
	sizes["warning"] = _face_size((demolition.find_children("*", "CrewWarning", true, false)[0] as CrewWarning).portrait)
	sizes["flight"] = _face_size((demolition.find_children("*", "FlightHud", true, false)[0] as FlightHud).pilot_face)
	demolition.free()
	var race := await _job("res://scenes/jobs/test_race.tscn", sv)
	sizes["race"] = _face_size((race.find_children("*", "RaceHud", true, false)[0] as RaceHud).pilot_face)
	race.free()
	var fleet := await _job("res://scenes/jobs/fleet_inspection.tscn", sv)
	var view: CommandView = fleet.get_node("CommandView")
	sizes["fleet"] = view.drones.map(func(d): return _face_size(view.portrait(d))).min()
	fleet.free()
	sizes["intro"] = CutscenePlayer.PORTRAIT
	sv.free()
	var ok := true
	for k in OLD:
		if not sizes.has(k) or sizes[k] < OLD[k] * 2.0:
			print("        %s face %s, was %s" % [k, sizes.get(k), OLD[k]])
			ok = false
	return ok

func test_no_face_overlaps_text_or_controls_on_the_screens() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	Roster.injure(&"sanjaya")
	Roster.kill(&"bhima")
	var bad := []
	for size in SCREENS:
		var sv := _in_viewport(size)
		var b := await _board(sv)
		for i in b.carousel.cards.size():
			b.carousel.go(i)
			await Sim.process_frames(2)
			bad.append_array(_overlaps(b, size))
		b.free()
		b = await _board(sv, true)
		# Down the CREW page, a screen at a time.
		var scroll: ScrollContainer = b.find_children("*", "ScrollContainer", true, false).filter(func(s): return s.is_visible_in_tree())[0]
		for step in 8:
			scroll.scroll_vertical = step * int(scroll.size.y * 0.5)
			await Sim.process_frames(2)
			bad.append_array(_overlaps(b, size))
		b.free()
		for act in [1, 2]:
			var s := await _pilot_select(sv, act)
			bad.append_array(_overlaps(s, size))
			s.get_parent().free()
		for farewell in [false, true]:
			var screen := await _results(sv, farewell)
			bad.append_array(_overlaps(screen, size))
			screen.free()
		sv.free()
	if not bad.is_empty():
		print("        ", bad)
	return bad.is_empty()

func test_no_face_overlaps_the_huds() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	var bad := []
	for size in SCREENS:
		var s := Vector2(size)
		var sv := _in_viewport(size)
		# The race: the pilot's face over their name, position and lap.
		var race := await _job("res://scenes/jobs/test_race.tscn", sv)
		var hud: RaceHud = race.find_children("*", "RaceHud", true, false)[0]
		var flight: FlightHud = race.find_children("*", "FlightHud", true, false)[0]
		var bezel: ArcadeBezel = race.find_children("*", "ArcadeBezel", true, false)[0]
		var board := Rect2(s.x - bezel.border - 400.0, 150.0, 240.0, 34.0 + bezel.leaderboard().size() * 22.0)
		var face := hud.pilot_face.get_global_rect()
		bad.append_array(_clear("race", face, {"readouts": hud.readouts_rect(), "tape": _tape(s), "leaderboard": board,
			"job panel": flight.panel_rect(), "ALT": _alt_gauge(s), "briefing": _state_line(race.get_node("HUD/State"))}, size))
		bad.append_array(_clear("race readouts", hud.readouts_rect(), {"leaderboard": board, "ALT": _alt_gauge(s)}, size))
		var ok_inside := hud.panel_rect().encloses(face) and hud.panel_rect().encloses(hud.readouts_rect())
		if not ok_inside:
			bad.append("race panel %s misses its face or readouts at %s" % [hud.panel_rect(), size])
		race.free()
		# A job with crew in the field: the pilot's face, and a warning.
		var demolition := await _job("res://scenes/jobs/demolition.tscn", sv)
		flight = demolition.find_children("*", "FlightHud", true, false)[0]
		var state: Label = demolition.get_node("HUD/State")
		face = flight.pilot_face.get_global_rect()
		bad.append_array(_clear("flight", face, {"job panel": flight.panel_rect(), "tape": _tape(s), "ALT": _alt_gauge(s),
			"briefing": _state_line(state)}, size))
		var warning: CrewWarning = demolition.find_children("*", "CrewWarning", true, false)[0]
		warning._struck_id = &"bhima"
		warning._struck_age = 0.0
		state.text = "LIVE  12.3 s  /  25 s"
		await Sim.process_frames(2)
		var disc := Rect2(warning.portrait.get_global_rect().get_center() - Vector2.ONE * CrewWarning.DISC, Vector2.ONE * CrewWarning.DISC * 2.0)
		bad.append_array(_clear("warning", disc, {"job panel": flight.panel_rect(), "tape": _tape(s), "clock": _state_line(state),
			"pilot": face, "line": warning.label.get_global_rect()}, size))
		demolition.free()
		sv.free()
	if not bad.is_empty():
		print("        ", bad)
	return bad.is_empty()

## Every button shown in `root` takes the mouse at its middle: no face covers it.
func _hoverable(root: Node, sv: SubViewport) -> bool:
	var ok := true
	for button in root.find_children("*", "BaseButton", true, false):
		if not button.is_visible_in_tree():
			continue
		var motion := InputEventMouseMotion.new()
		motion.position = button.get_global_rect().get_center()
		sv.push_input(motion)
		await Sim.process_frames(1)
		if not button.is_hovered():
			print("        %s takes no mouse at %s" % [root.get_path_to(button), sv.size])
			ok = false
	return ok

## Every button takes the mouse where it shows, and up and down still move.
func test_pad_focus_and_clicks_reach_every_control() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	var ok := true
	for size in SCREENS:
		var sv := _in_viewport(size)
		var b := await _board(sv)
		b.carousel.go(b.job_ids.find(b.start_here()))
		await Sim.process_frames(2)
		ok = ok and await _hoverable(b, sv)
		b.free()
		b = await _board(sv, true)
		ok = ok and await _hoverable(b, sv)
		b.free()
		var s := await _pilot_select(sv)
		ok = ok and await _hoverable(s, sv)
		# Up from a pilot is Back; down from Back, the pilot flying.
		s.choose_button(&"hanuman").grab_focus()
		var up := InputEventAction.new()
		up.action = "ui_up"
		up.pressed = true
		sv.push_input(up)
		await Sim.process_frames(1)
		ok = ok and sv.gui_get_focus_owner() == s.find_child("Back", true, false)
		var down := InputEventAction.new()
		down.action = "ui_down"
		down.pressed = true
		sv.push_input(down)
		await Sim.process_frames(1)
		ok = ok and sv.gui_get_focus_owner() == s.choose_button(&"arjuna")
		s.get_parent().free()
		# The results keep Continue focused; down scrolls the rows when they
		# outgrow the screen.
		for farewell in [false, true]:
			var shown := await _results(sv, farewell)
			ok = ok and await _hoverable(shown, sv)
			shown.free()
		var screen := await _results(sv, true)
		var scroll: ScrollContainer = screen.scroll
		var room := scroll.get_v_scroll_bar().max_value - scroll.size.y
		sv.push_input(down)
		await Sim.process_frames(2)
		ok = ok and sv.gui_get_focus_owner() == screen.continue_button and (room <= 1.0 or scroll.scroll_vertical > 0)
		screen.free()
		sv.free()
	return ok

## Over the fleet: at the opening frame the drones sit together, and their
## faces fan out clear of one another, of every ring and name, and of the HUD.
func test_no_face_overlaps_over_the_fleet() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	var bad := []
	for size in SCREENS:
		var sv := _in_viewport(size)
		var fleet := await _job("res://scenes/jobs/fleet_inspection.tscn", sv)
		var view: CommandView = fleet.get_node("CommandView")
		for pick in view.drones.size():
			view.select(view.drones[pick])
			await Sim.process_frames(2)
			var overlay = view.get_node("Overlay").get_child(0)
			var faces := []
			for d in view.drones:
				var f: CharacterPortrait = view.portrait(d)
				if f and f.visible:
					faces.append(f.get_global_rect())
			if faces.size() != view.drones.size():
				bad.append("%d of %d faces show at %s" % [faces.size(), view.drones.size(), size])
			var things := {}
			for i in overlay.marks().size():
				things["mark %d" % i] = overlay.marks()[i]
			var bark: BarkBox = fleet.find_children("*", "BarkBox", true, false)[0]
			var panel := BarkBox.panel_rect(bark.size)
			things["radio"] = Rect2(bark.get_global_rect().position + panel.position, panel.size)
			for i in faces.size():
				var others := things.duplicate()
				for j in faces.size():
					if j != i:
						others["face %d" % j] = faces[j]
				bad.append_array(_clear("fleet %d" % i, faces[i].grow(-1.0), others, size))
			bad.append_array(_overlaps(fleet, size))
		fleet.free()
		sv.free()
	if not bad.is_empty():
		print("        ", bad)
	return bad.is_empty()

## The intro and the recruiting cards: each portrait's card sits between the
## letterbox bars and clear of the caption and the skip line.
func test_no_face_overlaps_the_cutscene_cards() -> bool:
	var bad := []
	for path in ["res://scenes/story/intro.tscn", "res://scenes/story/recruited.tscn"]:
		for size in SCREENS:
			var sv := _in_viewport(size)
			CutscenePlayer.replay = true
			var p: CutscenePlayer = load(path).instantiate()
			sv.add_child(p)
			await Sim.process_frames(2)
			var cards := 0
			while not p.done and p.index < p.cutscene.beats.size():
				if p.card.visible:
					cards += 1
					await Sim.process_frames(2)
					var s := Vector2(size)
					var card := p.card.get_global_rect()
					var things := {"top bar": Rect2(0, 0, s.x, 84), "bottom bar": Rect2(0, s.y - 84, s.x, 84),
						"skip": (p.find_child("Skip", true, false) as Control).get_global_rect()}
					if p.caption.text != "":
						things["caption"] = p.caption.get_global_rect()
					bad.append_array(_clear("%s card %d" % [path.get_file(), p.index], card, things, size))
					if not card.encloses(p.portrait.get_global_rect()):
						bad.append("%s portrait leaves its card at %s" % [path.get_file(), size])
				p.advance()
			if cards == 0:
				bad.append("%s shows no card" % path.get_file())
			p.free()
			sv.free()
	CutscenePlayer.replay = false
	if not bad.is_empty():
		print("        ", bad)
	return bad.is_empty()
