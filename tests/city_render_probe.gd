extends SceneTree
# Story 15.4: run by test_building_surfaces.gd in its own Godot process with a
# real renderer (GL Compatibility), since the headless test run draws nothing.
# Renders one tower's wall and roof dry, wet, and snowed, and writes the mean
# colour of each view's centre to the file named by the first user argument.

func _initialize() -> void:
	SaveGame.path = "user://probe_save.json"
	await process_frame
	var out_path: String = OS.get_cmdline_user_args()[0]
	var root := Node3D.new()
	get_root().add_child(root)
	root.add_child(load("res://scenes/world/golden_hour.tscn").instantiate())
	var city: City = load("res://scenes/world/city.tscn").instantiate()
	root.add_child(city)
	var lot := city.plan.lots[0]
	var h := city.plan.heights[0]
	var c := lot.get_center()
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.current = true
	var views := {
		# The south wall's solid ground floor, square on from 4 m out.
		"wall": [Vector3(c.x, 2.5, lot.end.y + 4.0), Vector3(c.x, 2.5, lot.end.y), Vector3.UP],
		# The roof, straight down from 6 m above.
		"roof": [Vector3(c.x, h + 6.0, c.y), Vector3(c.x, h, c.y), Vector3.FORWARD],
	}
	var result := {}
	for view in views:
		var v: Array = views[view]
		cam.look_at_from_position(v[0], v[1], v[2])
		for weather in [["dry", 0.0, 0.0], ["wet", 1.0, 0.0], ["snow", 0.0, 1.0]]:
			RenderingServer.global_shader_parameter_set(&"wetness", weather[1])
			RenderingServer.global_shader_parameter_set(&"snow_cover", weather[2])
			for i in 8:
				await process_frame
			result["%s_%s" % [view, weather[0]]] = _centre_luma(get_root().get_texture().get_image())
	RenderingServer.global_shader_parameter_set(&"wetness", 0.0)
	RenderingServer.global_shader_parameter_set(&"snow_cover", 0.0)
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
