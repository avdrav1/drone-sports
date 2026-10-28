extends SceneTree
# Story 15.7: run by test_street_detail.gd in its own Godot process with a real
# renderer (GL Compatibility), since the headless test run draws nothing.
# Renders a road segment, a pavement, and a kerb top dry, wet, and snowed, and
# writes the mean colour of each view's centre, and the errors the engine logged
# (shader compile errors among them), to the file named by the first user
# argument.

var _errors: Array = []

func _initialize() -> void:
	SaveGame.path = "user://probe_save.json"
	await process_frame
	var out_path: String = OS.get_cmdline_user_args()[0]
	if ClassDB.class_exists("Logger"):
		var logger = load("res://tests/error_logger.gd").new()
		logger.sink = _errors
		OS.call("add_logger", logger)
	var root := Node3D.new()
	get_root().add_child(root)
	root.add_child(load("res://scenes/world/golden_hour.tscn").instantiate())
	var streets: Streets = load("res://scenes/world/streets.tscn").instantiate()
	root.add_child(streets)
	var road := Vector2.ZERO
	for piece in Streets.road_pieces(streets.plan, streets.layout):
		if piece[3] == 0:
			road = (piece[0] as Rect2).get_center()
			break
	var block: Rect2 = streets.plan.blocks[0]
	for b in streets.plan.blocks:
		if CityPlan.inside(b, streets.layout.core_radius):
			block = b
			break
	var kerb := streets.kerbs[0].get_center()
	var cam := Camera3D.new()
	cam.fov = 20.0
	root.add_child(cam)
	cam.current = true
	# Each view straight down from a few metres up.
	var views := {
		"road": Vector3(road.x, 0.0, road.y),
		"walk": Vector3(block.get_center().x, streets.kerb_height, block.position.y + 1.5),
		"kerb": kerb + Vector3.UP * kerb.y,
	}
	var result := {}
	for view in views:
		var at: Vector3 = views[view]
		var high := 3.0 if view != "kerb" else 0.6
		cam.look_at_from_position(at + Vector3.UP * high, at, Vector3.FORWARD)
		for weather in [["dry", 0.0, 0.0], ["wet", 1.0, 0.0], ["snow", 0.0, 1.0]]:
			RenderingServer.global_shader_parameter_set(&"wetness", weather[1])
			RenderingServer.global_shader_parameter_set(&"snow_cover", weather[2])
			for i in 8:
				await process_frame
			result["%s_%s" % [view, weather[0]]] = _centre_luma(get_root().get_texture().get_image())
	RenderingServer.global_shader_parameter_set(&"wetness", 0.0)
	RenderingServer.global_shader_parameter_set(&"snow_cover", 0.0)
	result["errors"] = _errors
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(result))
	f.close()
	quit()

## Mean luminance of the middle third of the frame.
func _centre_luma(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var sum := 0.0
	var n := 0
	for y in range(int(h / 3.0), int(h * 2 / 3.0), 2):
		for x in range(int(w / 3.0), int(w * 2 / 3.0), 2):
			sum += img.get_pixel(x, y).get_luminance()
			n += 1
	return sum / maxi(n, 1)
