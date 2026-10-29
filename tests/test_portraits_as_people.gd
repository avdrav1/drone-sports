extends RefCounted
# Story 20.4: portraits as people. Each portrait takes its skin, hair and shirt
# colours from the character's CrewLook; rendered under GL Compatibility those
# colours show and every crew member is told apart at 32, 64 and 128 px; the
# hair and caps keep clear of the brows; the dead stay shut-eyed and still.
# The existing portrait, motion, emote, distress and incoming-call tests run
# unchanged in their own files.

const Sim = preload("res://tests/sim.gd")
const PROBE := "res://tests/portrait_probe.gd"
const PROBE_TIMEOUT_MS := 90000
const CHARACTERS := ["arjuna", "sanjaya", "nala", "bhima", "sushena", "drona", "hanuman", "abhimanyu", "jatayu"]

static var _probe: Dictionary = {}

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

## Runs the render probe once and shares its result between tests.
func _probe_result() -> Dictionary:
	if not _probe.is_empty():
		return _probe
	var out := ProjectSettings.globalize_path("user://portrait_probe_%d.json" % OS.get_process_id())
	DirAccess.remove_absolute(out)
	var args := ["--path", ProjectSettings.globalize_path("res://"), "--rendering-method", "gl_compatibility",
		"--rendering-driver", "opengl3", "--resolution", "320x180", "-s", PROBE, "--", out]
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		print("        could not start the render probe")
		return {}
	var start := Time.get_ticks_msec()
	while OS.is_process_running(pid) and Time.get_ticks_msec() - start < PROBE_TIMEOUT_MS:
		await Sim.tree().process_frame
	if OS.is_process_running(pid):
		OS.kill(pid)
	var r = JSON.parse_string(FileAccess.get_file_as_string(out))
	DirAccess.remove_absolute(out)
	if not r is Dictionary:
		print("        the render probe wrote nothing (needs a display and OpenGL 3.3)")
		return {}
	_probe = r
	return _probe

func test_palette_is_the_crew_look() -> bool:
	var ok := true
	for id in CHARACTERS:
		var c: Character = load("res://data/characters/%s.tres" % id)
		var p := CharacterPortrait.palette(c)
		ok = ok and c.look != null and p.skin == c.look.skin and p.hair == c.look.hair and p.top == c.look.top
		ok = ok and p.accessory == c.look.accessory_color and p.detail == c.look.accessory_detail
		ok = ok and CharacterPortrait.hair_style(c) == c.look.body.hair_style
	return ok

func test_drawn_portraits_show_skin_hair_and_top_colours() -> bool:
	var r: Dictionary = await _probe_result()
	if r.is_empty():
		return false
	var ok: bool = (r.errors as Array).is_empty()
	for id in CHARACTERS:
		for px in [64, 128]:
			var n: Dictionary = r.counts["%s_%d" % [id, px]]
			var area := float(px * px)
			var shows: bool = n.skin > area * 0.05 and n.top > area * 0.03 and n.hair > area * 0.005
			if not shows:
				print("        %s at %d px: %s" % [id, px, n])
			ok = ok and shows
	return ok

func test_every_crew_member_is_told_apart_at_32_64_128() -> bool:
	var r: Dictionary = await _probe_result()
	if r.is_empty():
		return false
	var ok := true
	for px in ["32", "64", "128"]:
		# Even the two most alike faces differ in a tenth of their pixels.
		ok = ok and float(r.apart[px]) > 0.1
	if not ok:
		print("        %s" % r.apart)
	return ok

func test_front_hair_and_caps_stay_above_the_brows() -> bool:
	var ok := CharacterPortrait.CAP_BOTTOM <= -0.82
	var exprs := CharacterPortrait.EXPRESSIONS.duplicate()
	exprs.append(CharacterPortrait.DISTRESS)
	for e in exprs:
		for i in 40:
			var p := CharacterPortrait.pose(e, i * 0.25, i % 2 == 0, 5)
			ok = ok and CharacterPortrait.brow_top(p) - CharacterPortrait.CAP_BOTTOM >= 0.1
			# Across the brows' whole width, the hair ends above their top.
			var reach := 0.4 + CharacterPortrait.EYE.x * float(p.eye_scale) * 0.7 + CharacterPortrait.BROW_HALF
			for k in 11:
				ok = ok and CharacterPortrait.hairline(reach * k / 10.0) < CharacterPortrait.brow_top(p) - 0.02
	return ok

func test_every_look_draws_at_every_size() -> bool:
	_fresh()
	var faces: Array[CharacterPortrait] = []
	for id in CHARACTERS:
		for px in [32, 64, 128]:
			var p := CharacterPortrait.new()
			p.character = load("res://data/characters/%s.tres" % id)
			p.custom_minimum_size = Vector2(px, px)
			p.size = Vector2(px, px)
			p.talking = true
			Sim.add(p)
			p.pop_in()
			faces.append(p)
	await Sim.process_frames(3)
	var ok := faces.size() == CHARACTERS.size() * 3
	for p in faces:
		ok = ok and p.drawn()
		p.free()
	return ok

func test_the_dead_are_shut_eyed_and_still() -> bool:
	_fresh()
	var p := CharacterPortrait.new()
	p.character = Roster.character(&"sushena")
	p.expression = &"shocked"
	p.talking = true
	Sim.add(p)
	Roster.kill(&"sushena")
	p.hop()
	p.pop_in()
	await Sim.process_frames(3)
	var m := p.current_motion()
	var ok: bool = p.is_dead() and float(p.current_pose().lid) == 0.0 and not p.shows_shine()
	ok = ok and m.scale == Vector2.ONE and m.offset == Vector2.ZERO and float(m.eye_pop) == 1.0
	p.free()
	_fresh()
	return ok
