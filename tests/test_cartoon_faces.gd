extends RefCounted
# Story 18.1: cartoon faces. Six distinct poses with eye_scale, squint and
# blush; brows only drop their inner ends when determined; big eyes; a soft
# smile at rest; 17.1's blinks, talking and sizes still hold; brows never
# cross the headwear; the dead have shut lids, a flat mouth, no blush and no
# shine.

const Rig = preload("res://tests/test_face_rig.gd")

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

func test_every_expression_is_distinct_with_new_fields() -> bool:
	var ok := CharacterPortrait.EXPRESSIONS.size() == 6
	for e in CharacterPortrait.EXPRESSIONS:
		var p := CharacterPortrait.pose(e, 0.0)
		ok = ok and p.has("eye_scale") and p.has("squint") and p.has("blush")
		for f in ["brow_angle", "brow_height", "lid", "pupil", "mouth_width", "mouth_curve", "mouth_open"]:
			ok = ok and p.has(f)
	return ok and Rig.new().test_every_expression_is_distinct()

func test_happy_up_sad_down_shocked_open() -> bool:
	return Rig.new().test_happy_sad_shocked()

func test_brows_inner_ends_not_lower_except_determined() -> bool:
	var ok := true
	for e in CharacterPortrait.EXPRESSIONS:
		if e != &"determined":
			# Positive brow_angle pulls the inner ends down.
			ok = ok and float(CharacterPortrait.pose(e, 0.0).brow_angle) <= 0.0
	return ok

func test_eyes_are_big_whenever_open() -> bool:
	var ok := true
	var checked := 0
	for e in CharacterPortrait.EXPRESSIONS:
		for i in 400:
			var p := CharacterPortrait.pose(e, i * 0.05, i % 2 == 0, 3)
			if float(p.lid) > 0.0:
				checked += 1
				ok = ok and CharacterPortrait.eye_height(p) >= 0.22
	return ok and checked > 6 * 300

func test_neutral_smiles() -> bool:
	var p := CharacterPortrait.pose(&"neutral", 0.0)
	return float(p.mouth_curve) > 0.0 and float(p.blush) > 0.0

func test_brows_stay_below_headwear() -> bool:
	# Headwear's ink outline is half of 0.1 r; leave a clear gap past it.
	var ok := CharacterPortrait.HEADWEAR_BOTTOM.size() == 4
	for shape in CharacterPortrait.HEADWEAR_BOTTOM:
		var bottom: float = CharacterPortrait.HEADWEAR_BOTTOM[shape]
		for e in CharacterPortrait.EXPRESSIONS:
			for i in 40:
				var p := CharacterPortrait.pose(e, i * 0.25, i % 2 == 0, 5)
				ok = ok and CharacterPortrait.brow_top(p) - bottom >= 0.1
	return ok

func test_blinks_and_talking_as_before() -> bool:
	var rig := Rig.new()
	return rig.test_blinks_are_seeded_and_timed() and rig.test_talking_moves_the_mouth()

func test_every_character_draws_at_32_64_128() -> bool:
	return await Rig.new().test_every_character_draws_at_every_size()

func test_dead_face_shut_no_blush_no_shine() -> bool:
	_fresh()
	var p := CharacterPortrait.new()
	p.character = Roster.character(&"marlo")
	p.expression = &"happy"
	var alive: bool = p.shows_shine() and float(p.current_pose().blush) > 0.0
	Roster.kill(&"marlo")
	var dead := p.current_pose()
	var ok: bool = alive and p.is_dead() and float(dead.lid) == 0.0 and float(dead.blush) == 0.0 and not p.shows_shine()
	ok = ok and float(dead.mouth_curve) == 0.0 and float(dead.mouth_open) == 0.0
	var greyed := CharacterPortrait.new()
	greyed.character = Roster.character(&"dot")
	greyed.greyed = true
	for e in CharacterPortrait.EXPRESSIONS:
		# The dead never emote: whatever the expression, a shut, flat face.
		greyed.expression = e
		var g := greyed.current_pose()
		ok = ok and float(g.lid) == 0.0 and float(g.blush) == 0.0 and float(g.mouth_curve) == 0.0 and float(g.mouth_open) == 0.0 and float(g.brow_angle) == 0.0 and not greyed.shows_shine()
	p.free()
	greyed.free()
	_fresh()
	return ok
