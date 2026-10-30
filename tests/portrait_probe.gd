extends SceneTree
# Story 20.4: run by test_portraits_as_people.gd in its own Godot process with a
# real renderer (GL Compatibility), since the headless test run draws nothing.
# Draws every crew portrait at 32, 64 and 128 px and writes, to the file named
# by the first user argument, how many pixels of each show the look's skin, hair
# and top colours, how different each pair of faces is, and any engine errors.
# Story 26.1: the faces are shaded, so a pixel shows a colour when it is that
# colour lit or in shadow (the same mix, brighter or darker); and four faces are
# also drawn at 256 px, where `spread` counts their distinct colours.
# Story 26.2: every face is drawn again at 48 px, and `outlines` gives the least
# share of pixels where two faces' silhouettes (what is not background) differ.

const IDS := ["arjuna", "sanjaya", "nala", "bhima", "sushena", "drona", "hanuman", "abhimanyu", "jatayu"]
const SIZES := [32, 64, 128]
## A pixel shows a colour when, scaled to the same brightness, its r, g and b
## differ from it by less than this in all, at LIT.x to LIT.y of its brightness:
## as dark as the painted shadow side (Paint.lit keeps about 0.4 of the colour,
## warmer) up to its highlights.
const MATCH := 0.1
const LIT := Vector2(0.38, 1.4)
## The big size, drawn in a row of its own, and how many faces get one.
const BIG := 256
const BIG_FACES := 4
## The silhouette size, and how far a pixel is from the background to be in one.
const SMALL := 48
const EDGE := 0.1
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
	vp.size = Vector2i(16 + 136 * IDS.size(), 16 + 136 * SIZES.size() + BIG + 8 + SMALL + 8)
	var big_y := 8 + 136 * SIZES.size()
	var small_y := big_y + BIG + 8
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
	for i in BIG_FACES:
		var p: Control = CP.new()
		p.character = load("res://data/characters/%s.tres" % IDS[i])
		p.size = Vector2.ONE * BIG
		p.position = Vector2(8 + (BIG + 8) * i, big_y)
		vp.add_child(p)
	for i in IDS.size():
		var p: Control = CP.new()
		p.character = load("res://data/characters/%s.tres" % IDS[i])
		p.size = Vector2.ONE * SMALL
		p.position = Vector2(8 + (SMALL + 8) * i, small_y)
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
						if shows(c, want):
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
	# Distinct colours (5 bits a channel) in each big face: a flat cartoon has a
	# few dozen, a painted face hundreds.
	var spread := {}
	for i in BIG_FACES:
		var crop := img.get_region(Rect2i(8 + (BIG + 8) * i, big_y, BIG, BIG))
		var seen := {}
		for y in BIG:
			for x in BIG:
				var c := crop.get_pixel(x, y)
				seen[(int(c.r * 31.0) << 10) | (int(c.g * 31.0) << 5) | int(c.b * 31.0)] = true
		spread[IDS[i]] = seen.size()
	var masks: Array[PackedByteArray] = []
	for i in IDS.size():
		var crop := img.get_region(Rect2i(8 + (SMALL + 8) * i, small_y, SMALL, SMALL))
		var m := PackedByteArray()
		for y in SMALL:
			for x in SMALL:
				var c := crop.get_pixel(x, y)
				m.append(1 if absf(c.r - bg.color.r) + absf(c.g - bg.color.g) + absf(c.b - bg.color.b) > EDGE else 0)
		masks.append(m)
	var outlines := 1.0
	var pair := ""
	for a in IDS.size():
		for b in range(a + 1, IDS.size()):
			var differ := 0
			for k in SMALL * SMALL:
				differ += 1 if masks[a][k] != masks[b][k] else 0
			var share := float(differ) / (SMALL * SMALL)
			if share < outlines:
				outlines = share
				pair = "%s/%s" % [IDS[a], IDS[b]]
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"counts": counts, "apart": apart, "spread": spread, "outlines": outlines, "closest": pair, "errors": _errors}))
	f.close()
	quit()

## True when pixel `c` is colour `want`, lit or in shadow.
static func shows(c: Color, want: Color) -> bool:
	var a := c.r + c.g + c.b
	var b := want.r + want.g + want.b
	if a <= 0.0 or b <= 0.0 or a < b * LIT.x or a > b * LIT.y:
		return false
	return absf(c.r / a - want.r / b) + absf(c.g / a - want.g / b) + absf(c.b / a - want.b / b) < MATCH
