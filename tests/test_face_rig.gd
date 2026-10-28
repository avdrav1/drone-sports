extends RefCounted
# Story 17.1: face rig. Six distinct expressions, seeded blinks, a mouth that
# moves while talking, a portrait texture still wins, every character draws at
# 32, 64 and 128 px, and the dead keep their eyes shut.

const Sim = preload("res://tests/sim.gd")
const CHARACTERS := ["pip", "marlo", "dot", "bea", "ozzie", "rin", "tally", "fen", "moss"]

func test_every_expression_is_distinct() -> bool:
	var ok := CharacterPortrait.EXPRESSIONS.size() == 6
	for a in CharacterPortrait.EXPRESSIONS:
		for b in CharacterPortrait.EXPRESSIONS:
			if a != b:
				ok = ok and CharacterPortrait.pose(a, 0.0) != CharacterPortrait.pose(b, 0.0)
	return ok

func test_happy_sad_shocked() -> bool:
	var happy := CharacterPortrait.pose(&"happy", 0.0)
	var sad := CharacterPortrait.pose(&"sad", 0.0)
	var shocked := CharacterPortrait.pose(&"shocked", 0.0)
	var ok: bool = happy.mouth_curve > 0.0 and sad.mouth_curve < 0.0 and shocked.mouth_open >= 0.6
	for e in CharacterPortrait.EXPRESSIONS:
		if e != &"shocked":
			ok = ok and CharacterPortrait.pose(e, 0.0).mouth_open < shocked.mouth_open
	return ok

func test_blinks_are_seeded_and_timed() -> bool:
	var ok := true
	for s in [0, 1, 7, 12345]:
		var b := CharacterPortrait.blinks(s, 300.0)
		ok = ok and b.size() >= 300.0 / 6.2 and b == CharacterPortrait.blinks(s, 300.0)
		var last_end := 0.0
		for blink in b:
			var gap: float = blink.x - last_end
			ok = ok and blink.y >= 0.1 and blink.y <= 0.2 and gap >= 2.0 and gap <= 6.0
			# Shut through the blink, open either side of it.
			ok = ok and CharacterPortrait.pose(&"neutral", blink.x + blink.y * 0.5, false, s).lid == 0.0
			ok = ok and CharacterPortrait.pose(&"neutral", blink.x - 0.05, false, s).lid > 0.0
			ok = ok and CharacterPortrait.pose(&"neutral", blink.x + blink.y + 0.05, false, s).lid > 0.0
			last_end = blink.x + blink.y
	return ok and CharacterPortrait.blinks(1, 300.0) != CharacterPortrait.blinks(2, 300.0)

func test_talking_moves_the_mouth() -> bool:
	var ok := true
	for e in CharacterPortrait.EXPRESSIONS:
		var held: float = CharacterPortrait.POSES[e].mouth_open
		var seen := {}
		for i in 30:
			var t := i * 0.07
			ok = ok and CharacterPortrait.pose(e, t, false).mouth_open == held
			seen[snappedf(CharacterPortrait.pose(e, t, true).mouth_open, 0.01)] = true
		ok = ok and seen.size() > 5
	return ok

func test_portrait_texture_overrides_face() -> bool:
	var c: Character = Roster.character(&"marlo").duplicate()
	var p := CharacterPortrait.new()
	p.character = c
	var drawn_before := p.drawn()
	c.portrait = PlaceholderTexture2D.new()
	var ok := drawn_before and not p.drawn()
	p.free()
	return ok

func test_every_character_draws_at_every_size() -> bool:
	var faces: Array[CharacterPortrait] = []
	for id in CHARACTERS:
		var c: Character = load("res://data/characters/%s.tres" % id)
		for px in [32, 64, 128]:
			for e in CharacterPortrait.EXPRESSIONS:
				var p := CharacterPortrait.new()
				p.character = c
				p.expression = e
				p.talking = e == &"happy"
				p.greyed = e == &"sad"
				p.size = Vector2(px, px)
				Sim.add(p)
				faces.append(p)
	for i in 3:
		await Engine.get_main_loop().process_frame
	var ok := faces.size() == CHARACTERS.size() * 3 * 6
	for p in faces:
		ok = ok and p.drawn()
		p.free()
	return ok

func test_the_dead_have_closed_lids() -> bool:
	var p := CharacterPortrait.new()
	p.character = Roster.character(&"marlo")
	p.expression = &"shocked"
	p.talking = true
	var open_alive: float = p.current_pose().lid
	Roster.kill(&"marlo")
	var dead := p.current_pose()
	var greyed := CharacterPortrait.new()
	greyed.character = Roster.character(&"dot")
	greyed.greyed = true
	var ok: bool = open_alive > 0.0 and dead.lid == 0.0 and p.is_dead() and greyed.current_pose().lid == 0.0
	p.free()
	greyed.free()
	return ok
