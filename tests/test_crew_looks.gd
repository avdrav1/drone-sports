extends RefCounted
# Story 20.1: crew looks. Every character has a CrewLook; any two differ in at
# least two of body, skin, hair and outfit colour; every crew model file is CC0
# with a URL and the set stays under 8 MB; each body names idle, wave, cheer,
# flinch and hurt clips its model has; a figure builds from each look with no
# collision shape, in the look's colours, wearing its accessory.

const CREW_MODELS := "res://data/models/crew"
const BODIES := "res://data/crew/bodies"
const LICENSES := "res://data/LICENSES.md"
const BUDGET := 8 * 1024 * 1024

func _characters() -> Array[Character]:
	var out: Array[Character] = []
	for f in DirAccess.get_files_at("res://data/characters"):
		var r = load("res://data/characters/" + f.trim_suffix(".remap"))
		if r is Character:
			out.append(r)
	return out

func _bodies() -> Array[CrewBody]:
	var out: Array[CrewBody] = []
	for f in DirAccess.get_files_at(BODIES):
		out.append(load(BODIES + "/" + f.trim_suffix(".remap")))
	return out

func test_every_character_has_a_valid_look() -> bool:
	var chars := _characters()
	var ok := chars.size() >= 9
	for c in chars:
		var good: bool = c.look != null and c.validate().is_empty() and c.look.accessory == c.shape \
			and c.look.hair_style() != &""
		if not good:
			print("        %s: %s" % [c.id, c.validate()])
			ok = false
	return ok

func test_any_two_characters_differ_in_two_ways() -> bool:
	var chars := _characters()
	var ok := true
	for i in chars.size():
		for j in range(i + 1, chars.size()):
			var a: CrewLook = chars[i].look
			var b: CrewLook = chars[j].look
			var diff := 0
			for d in [a.body != b.body, a.skin != b.skin, a.hair != b.hair, a.top != b.top]:
				diff += 1 if d else 0
			if diff < 2:
				print("        %s and %s look alike" % [chars[i].id, chars[j].id])
				ok = false
	return ok

func test_crew_models_are_cc0_with_url_and_under_8_mb() -> bool:
	var listed := {}
	for line in FileAccess.get_file_as_string(LICENSES).split("\n"):
		var cells := line.split("|")
		if cells.size() >= 4:
			var file := cells[1].strip_edges().trim_prefix("`").trim_suffix("`")
			listed[file] = cells[2].contains("https://") and cells[3].strip_edges() == "CC0"
	var total := 0
	var count := 0
	for f in DirAccess.get_files_at(CREW_MODELS):
		if f.get_extension() in ["glb", "gltf", "bin", "png", "jpg"]:
			count += 1
			total += FileAccess.get_file_as_bytes(CREW_MODELS + "/" + f).size()
			if not listed.get("models/crew/" + f, false):
				print("        unlisted or not CC0 with a URL: %s" % f)
				return false
	return count > 0 and total > 0 and total <= BUDGET

func test_every_body_has_its_action_clips() -> bool:
	var bodies := _bodies()
	var ok := bodies.size() >= 9
	for b in bodies:
		ok = ok and b.validate().is_empty()
		var model := b.model.instantiate()
		var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		for a in CrewBody.ACTIONS:
			if not player.has_animation(b.clips.get(a, &"")):
				print("        %s: no clip %s for %s" % [b.id, b.clips.get(a, &""), a])
				ok = false
		model.free()
	return ok

func test_a_figure_builds_from_every_look() -> bool:
	var root := (Engine.get_main_loop() as SceneTree).root
	var ok := true
	for c in _characters():
		var fig := CrewFigure.build(c.look, 1.75)
		root.add_child(fig)
		await (Engine.get_main_loop() as SceneTree).process_frame
		var meshes := fig.find_children("*", "MeshInstance3D", true, false)
		var head: Node = fig.skeleton.get_node_or_null("Head")
		var mat := (fig.skeleton.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).material_override as ShaderMaterial
		var colours := true
		for role in CrewLook.ROLES:
			colours = colours and mat.get_shader_parameter(role) == c.look.color(role)
		var worn := false
		for part in (head.get_children() if head else []):
			worn = worn or ((part as MeshInstance3D).material_override as StandardMaterial3D).albedo_color == c.look.accessory_color
		var good: bool = meshes.size() >= 3 and head != null and worn and colours \
			and fig.find_children("*", "CollisionObject3D", true, false).is_empty() \
			and fig.find_children("*", "CollisionShape3D", true, false).is_empty() \
			and fig.player.is_playing() and fig.player.current_animation == String(c.look.body.clips[&"idle"])
		for a in CrewBody.ACTIONS:
			fig.play(a)
			good = good and fig.action == a and fig.player.current_animation == String(c.look.body.clips[a])
		if not good:
			print("        %s: figure did not build right" % c.id)
			ok = false
		fig.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	return ok

func test_figure_stands_at_its_height() -> bool:
	var c: Character = load("res://data/characters/bea.tres")
	var a := CrewFigure.build(c.look, 1.75)
	var b := CrewFigure.build(c.look, 3.5)
	var ok: bool = is_equal_approx(b.get_node("Body").scale.x, a.get_node("Body").scale.x * 2.0) \
		and is_equal_approx(a.get_node("Body").scale.y * CrewFigure.MODEL_HEIGHT, 1.75)
	a.free()
	b.free()
	return ok
