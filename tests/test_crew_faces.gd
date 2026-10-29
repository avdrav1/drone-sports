extends RefCounted
# Story 20.3: faces on the figures. A crew figure wears its character's cartoon
# face, drawn from CharacterPortrait.pose(); it makes each of their radio
# lines' faces, talks while the line types out and returns to neutral after,
# blinks on its own rhythm, never shows for the dead, and is big enough to read
# from 3 m.

const Sim = preload("res://tests/sim.gd")
const JOBS := ["res://scenes/jobs/inspection.tscn", "res://scenes/jobs/rescue.tscn", "res://scenes/jobs/demolition.tscn"]
const ZONE_AT := Vector3(0, 0, -30)

## A job rig with Sanjaya standing in a zone, a Bark and a BarkBox radio.
func _rig() -> Node:
	var job := Job.new()
	job.crew_in_field = [&"sanjaya"]
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	runner.results_scene = null
	runner.back_scene = ""
	var d: Drone = root.get_node("Drone")
	d.freeze = true
	d.global_position = Vector3(0, 5, 20)
	var bark := Bark.new()
	bark.name = "Bark"
	bark.seed = 1
	root.add_child(bark)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	root.add_child(hud)
	var box := BarkBox.new()
	box.name = "BarkBox"
	box.bark = bark
	hud.add_child(box)
	var zone := HazardZone.new()
	zone.name = "Zone"
	zone.character = &"sanjaya"
	root.add_child(zone)
	zone.global_position = ZONE_AT
	var prop := CrewProp.new()
	prop.name = "Prop"
	prop.character = &"sanjaya"
	zone.add_child(prop)
	return root

## The pose the face's shader is drawing, read back from its uniforms.
func _drawn(face: CrewFace) -> Dictionary:
	var out := {}
	var mat := face.material_override as ShaderMaterial
	for f in CrewFace.FIELDS:
		out[f] = mat.get_shader_parameter(f)
	return out

func _matches(face: CrewFace, expr: StringName) -> bool:
	var want: Dictionary = CharacterPortrait.POSES[expr]
	var got := _drawn(face)
	return is_equal_approx(float(got.brow_angle), float(want.brow_angle)) \
		and is_equal_approx(float(got.mouth_curve), float(want.mouth_curve)) \
		and is_equal_approx(float(got.blush), float(want.blush))

func test_each_job_figure_wears_a_face_on_the_radio() -> bool:
	var ok := true
	for path in JOBS:
		var scene: Node = Sim.add(load(path).instantiate())
		await Sim.process_frames(2)
		for p: CrewProp in scene.find_children("*", "CrewProp", true, false):
			var f := p.face
			var good: bool = f != null and f == CrewFace.of(p.figure) and f.character == Roster.character(p.character) \
				and f.radio != null and f.visible and f.get_parent().name == "Head"
			if not good:
				print("        %s: no face on %s" % [path, p.character])
				ok = false
		scene.free()
	return ok

## Each line of Sanjaya's on the radio puts its face on the figure, which talks
## while the line types out and goes back to neutral once the line is done.
func test_face_follows_each_line_then_neutral() -> bool:
	var root := _rig()
	await Sim.process_frames(2)
	var face := (root.get_node("Zone/Prop") as CrewProp).face
	var bark: Bark = root.get_node("Bark")
	var box: BarkBox = root.get_node("HUD/BarkBox")
	var ok := face != null and face.radio == box and face.expression == CrewFace.REST
	for expr in CharacterPortrait.EXPRESSIONS:
		bark.announce_line({"id": &"sanjaya", "event": &"complete", "text": "Line with a face to make.", "face": expr})
		face.advance(0.0)
		var during := face.expression == expr and face.talking and _matches(face, expr)
		box.skip()
		face.advance(0.0)
		var held := face.expression == expr and not face.talking
		box._process(box.hold + 0.1)
		face.advance(0.0)
		var after := face.expression == CrewFace.REST and not face.talking
		if not (during and held and after):
			print("        %s: during %s held %s after %s" % [expr, during, held, after])
			ok = false
	# Someone else's line leaves Sanjaya's face alone.
	bark.announce_line({"id": &"bhima", "event": &"complete", "text": "Not Sanjaya.", "face": &"shocked"})
	face.advance(0.0)
	ok = ok and face.expression == CrewFace.REST and not face.talking
	root.free()
	return ok

## The figure blinks with the portrait's seed for the character, so each crew
## member blinks on their own rhythm; between blinks the eyes are open.
func test_blinks_on_its_own_rhythm() -> bool:
	var root := _rig()
	await Sim.process_frames(2)
	var face := (root.get_node("Zone/Prop") as CrewProp).face
	face.time = 0.0
	var shut := 0
	var open := 0
	var ok := true
	for i in 600:
		face.advance(0.05)
		var lid := float(_drawn(face).lid)
		var want := CharacterPortrait.blinking(hash(&"sanjaya"), face.time)
		ok = ok and (lid == 0.0) == want
		if lid == 0.0:
			shut += 1
		else:
			open += 1
	var own := CharacterPortrait.blinks(hash(&"sanjaya"), 30.0) != CharacterPortrait.blinks(hash(&"bhima"), 30.0)
	root.free()
	return ok and shut > 0 and open > shut and own

## The dead show no face: a dead character's prop does not spawn, no face goes
## on a figure for them, and a face already up goes when they die.
func test_dead_face_never_shows() -> bool:
	var root := _rig()
	await Sim.process_frames(2)
	var prop: CrewProp = root.get_node("Zone/Prop")
	var face := prop.face
	var alive_shown := face.visible
	Roster.kill(&"sanjaya")
	face.advance(0.0)
	var hidden := not face.visible
	var none := CrewFace.wear(prop.figure, Roster.character(&"sanjaya")) == null
	root.free()
	var again := _rig()
	(again.get_node("Runner") as JobRunner).begin()
	await Sim.process_frames(2)
	var no_prop := again.find_children("*", "CrewProp", true, false).is_empty() \
		and again.find_children("*", "CrewFace", true, false).is_empty()
	again.free()
	return alive_shown and hidden and none and no_prop

## From the chase camera 3 m away at 1280x720, the face faces the camera and
## spans enough pixels for its eyes and mouth to read.
func test_face_reads_at_three_metres() -> bool:
	var root := _rig()
	await Sim.process_frames(2)
	var prop: CrewProp = root.get_node("Zone/Prop")
	prop.set_process(false)
	prop.figure.rotation.y = 0.0
	await Sim.process_frames(2)
	var face := prop.face
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = (root.get_node("Rig") as CameraRig).base_fov
	vp.add_child(cam)
	var mid := face.global_position
	var forward := face.global_basis.z.normalized()
	cam.look_at_from_position(mid + forward * 3.0 + Vector3.UP * 0.5, mid)
	var up := face.global_basis.y * CrewFace.SIZE.y * 0.5
	var px := cam.unproject_position(mid + up).distance_to(cam.unproject_position(mid - up))
	var toward := forward.dot((cam.global_position - mid).normalized()) > 0.9
	# An eye is about a sixth of the face's height; it needs a few pixels.
	var ok := toward and px >= 40.0 and px / 6.0 >= 6.0
	if not ok:
		print("        face %.1f px tall, facing %s" % [px, toward])
	root.free()
	return ok
