extends RefCounted
# The opening screen shows the game's own logo on its own colours, not the engine's.

const LOGO := "res://data/ui/boot_logo.png"

func _logo() -> Image:
	var image := Image.new()
	image.load_png_from_buffer(FileAccess.get_file_as_bytes(LOGO))
	return image

func test_the_opening_screen_is_set_to_the_logo() -> bool:
	return ProjectSettings.get_setting("application/boot_splash/image") == LOGO \
		and ProjectSettings.get_setting("application/boot_splash/show_image", true) == true \
		and not _logo().is_empty()

func test_the_logo_sits_in_the_middle_with_room_around_it() -> bool:
	var image := _logo()
	var used := image.get_used_rect()
	var middle := Vector2(image.get_size()) * 0.5
	var off := absf(used.get_center().x - middle.x) / image.get_width()
	var wide := float(used.size.x) / image.get_width()
	return used.has_point(Vector2i(middle)) and off < 0.05 and wide > 0.4 and wide < 0.8 \
		and image.get_pixel(0, 0).a == 0.0

func test_the_background_is_darker_than_the_logos_edge() -> bool:
	# Otherwise the mark's maroon edge disappears into it.
	var bg: Color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	var mark := TitleMark.new()
	var edge: Color = mark.edge_color
	mark.free()
	return bg.a == 1.0 and bg.get_luminance() < edge.get_luminance() and bg.r > bg.g and bg.r > bg.b

func test_the_web_loaders_bar_is_saffron() -> bool:
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	var head: String = presets.get_value("preset.0.options", "html/head_include", "")
	return head.contains("#status-progress") and head.contains("accent-color: #fa7314")
