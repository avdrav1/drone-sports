extends RefCounted
# Story 18.2: squash and stretch. Idle motion stays within 6% of the face and
# repeats in each character's own phase; talking squashes and stretches but
# keeps the area within 5%; hop() is back at rest within 0.6 s; pupils follow
# a point and never leave the eye; the dead do not move. Pilot select and the
# board hop a face on a pick and the board's faces follow the cursor.

const Sim = preload("res://tests/sim.gd")

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

func _crew() -> Array[Character]:
	var out: Array[Character] = []
	for id in [&"pip", &"marlo", &"dot", &"bea", &"ozzie", &"rin", &"fen", &"moss", &"tally"]:
		out.append(load("res://data/characters/%s.tres" % id))
	return out

func _same(a: Dictionary, b: Dictionary) -> bool:
	return (a.scale as Vector2).is_equal_approx(b.scale) and (a.offset as Vector2).is_equal_approx(b.offset) \
		and is_equal_approx(float(a.eye_pop), float(b.eye_pop))

func _face(c: Character) -> CharacterPortrait:
	var f := CharacterPortrait.new()
	f.character = c
	f.size = Vector2(64, 64)
	return f

func test_idle_motion_within_six_percent() -> bool:
	var ok := true
	var moved := 0.0
	for c in _crew():
		ok = ok and c.validate().is_empty()
		for e in CharacterPortrait.EXPRESSIONS:
			for i in 300:
				var t := i * 0.037
				# Idle at any time since the expression was set, the shocked pop included.
				var m := CharacterPortrait.motion(e, t, false, c.bounce, INF, fmod(t, 1.0))
				var sc: Vector2 = m.scale
				var off: Vector2 = m.offset
				ok = ok and off.length() <= 0.06 and absf(sc.x - 1.0) <= 0.06 and absf(sc.y - 1.0) <= 0.06
				moved = maxf(moved, off.length())
	return ok and moved > 0.01

func test_idle_repeats_in_each_characters_own_phase() -> bool:
	var ok := true
	var crew := _crew()
	var bounces := {}
	for c in crew:
		bounces[c.bounce] = true
		for e in CharacterPortrait.EXPRESSIONS:
			for i in 20:
				var t := i * 0.29
				var a := CharacterPortrait.motion(e, t, false, c.bounce)
				ok = ok and _same(a, CharacterPortrait.motion(e, t + 1.0 / c.bounce.x, false, c.bounce))
				ok = ok and _same(a, CharacterPortrait.motion(e, t + 3.0 / c.bounce.x, false, c.bounce))
	# No two share a rhythm, so the crew never bob in unison.
	ok = ok and bounces.size() == crew.size()
	var a0 := CharacterPortrait.motion(&"neutral", 1.3, false, crew[0].bounce)
	var a1 := CharacterPortrait.motion(&"neutral", 1.3, false, crew[1].bounce)
	# A live face moves in its character's rhythm.
	_fresh()
	var f := _face(crew[1])
	f.time = 2.6
	ok = ok and _same(f.current_motion(), CharacterPortrait.motion(&"neutral", 2.6, false, crew[1].bounce))
	f.free()
	return ok and not _same(a0, a1)

func test_talking_squashes_and_stretches_keeping_area() -> bool:
	var ok := true
	var lo := 9.0
	var hi := 0.0
	for e in CharacterPortrait.EXPRESSIONS:
		for i in 400:
			var m := CharacterPortrait.motion(e, i * 0.021, true, Vector2(0.8, 0.3))
			var sc: Vector2 = m.scale
			ok = ok and absf(sc.x * sc.y - 1.0) <= 0.05
			lo = minf(lo, sc.y)
			hi = maxf(hi, sc.y)
	# It visibly squashes and stretches, more than idle breathing.
	return ok and hi - lo > 0.08 and hi > 1.04 and lo < 0.96

func test_hop_returns_to_rest_within_0_6_s() -> bool:
	var b := Vector2(0.7, 0.2)
	var ok := true
	var top := 0.0
	for i in 61:
		var age := i * 0.01
		var m := CharacterPortrait.motion(&"neutral", 5.0 + age, false, b, age)
		top = minf(top, (m.offset as Vector2).y)
		ok = ok and absf((m.scale as Vector2).x * (m.scale as Vector2).y - 1.0) <= 0.05
	for age in [0.6, 0.75, 2.0]:
		ok = ok and _same(CharacterPortrait.motion(&"neutral", 5.0 + age, false, b, age), CharacterPortrait.motion(&"neutral", 5.0 + age, false, b))
	# A live face hops off the ground, then is back on its idle bob by 0.6 s.
	_fresh()
	var c: Character = load("res://data/characters/dot.tres")
	var f := _face(c)
	f.time = 3.0
	f.hop()
	f.time += 0.2
	var mid := f.current_motion()
	f.time += 0.4
	ok = ok and _same(f.current_motion(), CharacterPortrait.motion(&"neutral", f.time, false, c.bounce))
	ok = ok and (mid.offset as Vector2).y < -0.06
	f.free()
	return ok and top < -0.08

func test_shocked_pops_and_sad_droops() -> bool:
	var b := Vector2(0.7, 0.0)
	var pop := CharacterPortrait.motion(&"shocked", 0.0, false, b, INF, 0.0)
	var settled := CharacterPortrait.motion(&"shocked", 0.0, false, b, INF, 1.0)
	var ok: bool = float(pop.eye_pop) > 1.1 and is_equal_approx(float(settled.eye_pop), 1.0)
	var sad := 0.0
	var neutral := 0.0
	for i in 50:
		sad += (CharacterPortrait.motion(&"sad", i * 0.1, false, b).offset as Vector2).y
		neutral += (CharacterPortrait.motion(&"neutral", i * 0.1, false, b).offset as Vector2).y
	return ok and sad > neutral + 0.5

func test_pupils_follow_a_point_and_never_leave_the_eye() -> bool:
	_fresh()
	var c: Character = load("res://data/characters/bea.tres")
	var f := _face(c)
	f.position = Vector2(100, 100)
	var mid := f.position + Vector2(32, 32 + 64 * 0.08)
	var ok := true
	f.look_at(mid + Vector2(500, 0))
	ok = ok and float((f.current_pose().pupil as Vector2).x) > 0.3
	f.look_at(mid + Vector2(-500, 0))
	ok = ok and float((f.current_pose().pupil as Vector2).x) < -0.3
	f.look_at(mid + Vector2(0, -500))
	ok = ok and float((f.current_pose().pupil as Vector2).y) < -0.3
	# Anywhere it looks, in any expression, the pupil's centre stays well inside the eye.
	var half := CharacterPortrait.EYE * 20.0
	for e in CharacterPortrait.EXPRESSIONS:
		f.expression = e
		for a in 16:
			for dist in [0.0, 10.0, 80.0, 5000.0]:
				f.look_at(mid + Vector2.RIGHT.rotated(TAU * a / 16.0) * dist)
				var p := f.current_pose()
				var h := half * float(p.eye_scale)
				var d := CharacterPortrait.pupil_center(Vector2.ZERO, h, p.pupil)
				ok = ok and (d.x / h.x) * (d.x / h.x) + (d.y / h.y) * (d.y / h.y) <= 0.25
	# Even a pupil pushed past its reach is clamped.
	var far := CharacterPortrait.pupil_center(Vector2.ZERO, half, Vector2(10, 10))
	ok = ok and (far.x / half.x) * (far.x / half.x) + (far.y / half.y) * (far.y / half.y) <= 0.25
	f.free()
	return ok

func test_dead_face_does_not_move() -> bool:
	_fresh()
	var c: Character = load("res://data/characters/ozzie.tres")
	var f := _face(c)
	f.greyed = true
	f.talking = true
	f.expression = &"shocked"
	f.hop()
	var ok := true
	for i in 40:
		f.time = i * 0.05
		ok = ok and _same(f.current_motion(), CharacterPortrait.still())
	f.look_at(Vector2(900, 0))
	ok = ok and float(f.current_pose().lid) == 0.0
	f.free()
	# Killed mid-hop, a face stops dead: no hop, no bob, no talking.
	var g := _face(c)
	g.talking = true
	g.hop()
	g.time = 0.2
	ok = ok and not _same(g.current_motion(), CharacterPortrait.still())
	Roster.kill(&"ozzie")
	ok = ok and _same(g.current_motion(), CharacterPortrait.still())
	g.free()
	_fresh()
	return ok

func test_pilot_select_and_board_hop_on_a_pick() -> bool:
	_fresh()
	var s := PilotSelect.new()
	Sim.add(s)
	var face: CharacterPortrait = s.cards[&"fen"].find_child("Face", true, false)
	face.time = 4.0
	s.choose_button(&"fen").focus_entered.emit()
	face.time += 0.2
	var ok: bool = face.follow_mouse and (face.current_motion().offset as Vector2).y < -0.06
	s.free()
	var board: Node = load("res://scenes/ui/job_board.tscn").instantiate()
	Sim.add(board)
	board.pilot_select.hide()
	var hopped := false
	for i in board.job_ids.size():
		board.carousel.go(i)
		var f: CharacterPortrait = board.carousel.current().find_child("Face", true, false)
		if f:
			ok = ok and f.follow_mouse
			f.time += 0.2
			hopped = hopped or (f.current_motion().offset as Vector2).y < -0.06
	for id in board.crew_rows:
		ok = ok and board.crew_rows[id].find_child("Face", true, false).follow_mouse
	board.free()
	return ok and hopped
