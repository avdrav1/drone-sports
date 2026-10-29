extends SceneTree
# Story 18.7: run by test_drone_faces.gd in its own Godot process with a real
# renderer (GL Compatibility), since the headless test run draws nothing.
# Renders a crew drone's face panel straight on and writes, to the file named by
# the first user argument, how many pixels show the pilot's body colour and the
# errors the engine logged (shader compile errors among them).

var _errors: Array = []

func _initialize() -> void:
	SaveGame.path = "user://probe_save.json"
	await process_frame
	var out_path: String = OS.get_cmdline_user_args()[0]
	if ClassDB.class_exists("Logger"):
		var logger = load("res://tests/error_logger.gd").new()
		logger.sink = _errors
		OS.call("add_logger", logger)
	var vp := SubViewport.new()
	vp.size = Vector2i(160, 160)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var d: RigidBody3D = load("res://scenes/drone/drone.tscn").instantiate()
	d.freeze = true
	vp.add_child(d)
	var pilot: Resource = load("res://data/characters/pip.tres")
	var face = load("res://scripts/drone/drone_face.gd").wear(d, pilot)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.current = true
	var at: Vector3 = face.global_position
	cam.look_at_from_position(at + face.global_basis.z * 0.3, at, Vector3.UP)
	for i in 8:
		await process_frame
	var img := vp.get_texture().get_image()
	var body: Color = pilot.colors[0]
	var hits := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if absf(c.r - body.r) + absf(c.g - body.g) + absf(c.b - body.b) < 0.15:
				hits += 1
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"body_pixels": hits, "pixels": img.get_width() * img.get_height(), "errors": _errors}))
	f.close()
	quit()
