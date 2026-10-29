extends SceneTree
# Story 20.4: run by test_portraits_as_people.gd in its own Godot process with a
# real renderer (GL Compatibility), since the headless test run draws nothing.
# Draws every crew portrait at 32, 64 and 128 px and writes, to the file named
# by the first user argument, how many pixels of each show the look's skin, hair
# and top colours, how different each pair of faces is, and any engine errors.

const IDS := ["pip", "marlo", "dot", "bea", "ozzie", "rin", "tally", "fen", "moss"]
const SIZES := [32, 64, 128]
## A pixel shows a colour when its r, g and b differ from it by this much in all.
const MATCH := 0.03
## Two pixels differ when their r, g and b differ by more than this in all.
const DIFFER := 0.2

var _errors: Array = []

func _initialize() -> void:
	SaveGame.path = "user://portrait_probe_save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path))
	await process_frame
	root.get_node("Roster").load_saved()
	var out_path: String = OS.get_cmdline_user_args()[0]
	if ClassDB.class_exists("Logger"):
		var logger = load("res://tests/error_logger.gd").new()
		logger.sink = _errors
		OS.call("add_logger", logger)
	var vp := SubViewport.new()
	vp.size = Vector2i(16 + 136 * IDS.size(), 16 + 136 * SIZES.size())
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.14, 0.2)
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var CP = load("res://scripts/ui/character_portrait.gd")
	for j in SIZES.size():
		for i in IDS.size():
			var p: Control = CP.new()
			p.character = load("res://data/characters/%s.tres" % IDS[i])
			p.custom_minimum_size = Vector2.ONE * SIZES[j]
			p.size = Vector2.ONE * SIZES[j]
			p.position = Vector2(8 + 136 * i, 8 + 136 * j)
			vp.add_child(p)
	for i in 8:
		await process_frame
	var img := vp.get_texture().get_image()
	var counts := {}
	var apart := {}
	for j in SIZES.size():
		var px: int = SIZES[j]
		var crops: Array[Image] = []
		for i in IDS.size():
			var crop := img.get_region(Rect2i(8 + 136 * i, 8 + 136 * j, px, px))
			crops.append(crop)
			var look: Resource = load("res://data/characters/%s.tres" % IDS[i]).look
			var n := {"skin": 0, "hair": 0, "top": 0}
			for y in px:
				for x in px:
					var c := crop.get_pixel(x, y)
					for role in n:
						var want: Color = look.get(role)
						if absf(c.r - want.r) + absf(c.g - want.g) + absf(c.b - want.b) < MATCH:
							n[role] += 1
			counts["%s_%d" % [IDS[i], px]] = n
		# The share of pixels that differ, for the closest pair of faces at this size.
		var closest := 1.0
		for a in IDS.size():
			for b in range(a + 1, IDS.size()):
				var differ := 0
				for y in px:
					for x in px:
						var u := crops[a].get_pixel(x, y)
						var v := crops[b].get_pixel(x, y)
						if absf(u.r - v.r) + absf(u.g - v.g) + absf(u.b - v.b) > DIFFER:
							differ += 1
				closest = minf(closest, float(differ) / (px * px))
		apart[str(px)] = closest
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"counts": counts, "apart": apart, "errors": _errors}))
	f.close()
	quit()
