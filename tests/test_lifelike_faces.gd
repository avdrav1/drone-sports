extends RefCounted
# Story 26.1: a lifelike face rig. Every expression is still its own pose; a
# face at 256 px paints a nose, irises, lids and shading, and no outline or
# cartoon shine dots; rendered, it has hundreds of colours; human, vanara and
# bird heads all paint; every character draws at 48, 128 and 256 px; the dead
# are grey, shut-eyed and still; talking moves the mouth and jaw; and the
# cartoon motion is kept subtle.

const Sim = preload("res://tests/sim.gd")
const Rig = preload("res://tests/test_face_rig.gd")
const People = preload("res://tests/test_portraits_as_people.gd")
const CHARACTERS := ["arjuna", "sanjaya", "nala", "bhima", "sushena", "drona", "hanuman", "abhimanyu", "jatayu"]

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

func _with_head(id: String, kind: StringName) -> Character:
	var c: Character = load("res://data/characters/%s.tres" % id).duplicate()
	c.look = c.look.duplicate()
	c.look.head = kind
	return c

func test_every_expression_is_still_its_own_pose() -> bool:
	var rig := Rig.new()
	return rig.test_every_expression_is_distinct() and rig.test_happy_sad_shocked()

func test_a_256_px_face_has_a_nose_irises_lids_and_shading() -> bool:
	var ok := true
	for id in CHARACTERS:
		for kind in CharacterPortrait.HEADS:
			var parts := CharacterPortrait.paint_parts(_with_head(id, kind), 256.0)
			for want in ["nose", "iris", "lids", "brows", "lips", "shading", "shoulders"]:
				if not want in parts:
					print("        %s as %s: no %s" % [id, kind, want])
					ok = false
	return ok

func test_no_cartoon_outline_or_shine_dots() -> bool:
	var ok := true
	for id in CHARACTERS:
		var parts := CharacterPortrait.paint_parts(load("res://data/characters/%s.tres" % id), 256.0)
		# One small catchlight an eye at most, never the two cartoon dots.
		ok = ok and not "outline" in parts and not "shine" in parts and parts.count("catchlight") <= 2
	return ok

func test_each_head_kind_paints_its_own_features() -> bool:
	var human := CharacterPortrait.paint_parts(_with_head("arjuna", &"human"), 128.0)
	var vanara := CharacterPortrait.paint_parts(_with_head("arjuna", &"vanara"), 128.0)
	var bird := CharacterPortrait.paint_parts(_with_head("arjuna", &"bird"), 128.0)
	return "ears" in human and "muzzle" in vanara and "fur" in vanara and "beak" in bird and "feathers" in bird \
		and not "beak" in human and not "muzzle" in bird

func test_rendered_faces_are_shaded_not_flat() -> bool:
	var r: Dictionary = await People.new()._probe_result()
	if r.is_empty():
		return false
	var ok: bool = (r.errors as Array).is_empty() and (r.spread as Dictionary).size() >= 4
	for id in r.spread:
		if float(r.spread[id]) < 400.0:
			print("        %s at 256 px has only %d colours" % [id, r.spread[id]])
			ok = false
	return ok

func test_every_character_draws_at_48_128_256() -> bool:
	_fresh()
	var faces: Array[CharacterPortrait] = []
	for id in CHARACTERS:
		for px in [48, 128, 256]:
			for e in [&"neutral", &"happy", &"shocked", CharacterPortrait.DISTRESS]:
				var p := CharacterPortrait.new()
				p.character = load("res://data/characters/%s.tres" % id)
				p.expression = e
				p.talking = e == &"happy"
				p.greyed = e == &"shocked" and px == 48
				p.size = Vector2(px, px)
				Sim.add(p)
				faces.append(p)
	await Sim.process_frames(3)
	var ok := faces.size() == CHARACTERS.size() * 12
	for p in faces:
		ok = ok and p.drawn()
		p.free()
	return ok

func test_the_dead_are_grey_shut_eyed_and_still() -> bool:
	_fresh()
	var p := CharacterPortrait.new()
	p.character = Roster.character(&"bhima")
	p.expression = &"happy"
	p.talking = true
	Sim.add(p)
	Roster.kill(&"bhima")
	p.hop()
	p.pop_in()
	var ok: bool = p.is_dead() and float(p.current_pose().lid) == 0.0 and CharacterPortrait.jaw(p.current_pose()) == 0.0
	var first := p.painted_motion()
	for i in 20:
		p.time += 0.07
		ok = ok and p.painted_motion() == first and CharacterPortrait.jaw(p.current_pose()) == 0.0
	ok = ok and first.scale == Vector2.ONE and first.offset == Vector2.ZERO and float(first.tilt) == 0.0
	# Every colour the dead face paints is a grey.
	var layers := CharacterPortrait.paint(p.character, 128.0, true)
	for k in [&"back", &"body", &"head", &"jaw", &"front"]:
		var mesh: ArrayMesh = layers[k]
		if mesh.get_surface_count() == 0:
			continue
		for c: Color in mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
			ok = ok and is_equal_approx(c.r, c.g) and is_equal_approx(c.g, c.b)
	p.free()
	_fresh()
	return ok

func test_talking_moves_the_mouth_and_jaw() -> bool:
	var seen := {}
	for i in 30:
		var p := CharacterPortrait.pose(&"neutral", i * 0.07, true)
		seen[snappedf(CharacterPortrait.jaw(p), 0.002)] = true
	return seen.size() > 5 and CharacterPortrait.jaw(CharacterPortrait.pose(&"neutral", 1.0)) == 0.0 \
		and Rig.new().test_talking_moves_the_mouth()

func test_motion_is_subtle() -> bool:
	_fresh()
	var f := CharacterPortrait.new()
	f.character = load("res://data/characters/nala.tres")
	f.talking = true
	var ok := true
	var tilts := {}
	for e in [&"neutral", &"sad", &"shocked", CharacterPortrait.DISTRESS]:
		f.expression = e
		f.hop()
		for i in 60:
			f.time += 0.033
			var m := f.painted_motion()
			var sc: Vector2 = m.scale
			# A breath and a lean, not a squash: within 8% and 4.5% of the face, even talking mid-hop.
			ok = ok and absf(sc.x - 1.0) <= 0.08 and absf(sc.y - 1.0) <= 0.08
			ok = ok and (m.offset as Vector2).length() <= 0.045 and absf(float(m.tilt)) <= 0.1
			tilts[snappedf(float(m.tilt), 0.001)] = true
	f.free()
	return ok and tilts.size() > 10
