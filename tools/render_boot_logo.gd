extends SceneTree
# Draws the opening screen's logo from the real TitleMark, so the two cannot
# drift apart. Needs a real renderer, so not --headless. Run it again after a
# change to the name or the mark:
#   godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s tools/render_boot_logo.gd

const OUT := "res://data/ui/boot_logo.png"
## 16:9 with room around the mark: the engine fits the whole image to the window.
const CANVAS := Vector2i(1600, 900)
const FONT_SIZE := 170
## The title screen's edge at this size (14 at its 128 px).
const OUTLINE := 18
const MARK_WIDTH := 0.62

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	var view := SubViewport.new()
	view.size = CANVAS
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var mark := TitleMark.new()
	mark.font_size = FONT_SIZE
	mark.max_width = MARK_WIDTH
	mark.add_theme_constant_override("outline_size", OUTLINE)
	view.add_child(mark)
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A glyph's ink is only known once drawn, so the mark settles over a few frames.
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	var err := image.save_png(ProjectSettings.globalize_path(OUT))
	print("%s: %s" % [OUT, error_string(err)])
	quit(err)
