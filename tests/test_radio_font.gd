extends RefCounted
# Story 18.12: radio font. The radio panel types its lines in a chunky monospaced
# pixel font and the name in its bold cut, in the HUD and under both front-end
# skins; every existing line fits the panel at 960x720 and 1920x1080; the font
# is CC0 and listed with its URL.

const Sim = preload("res://tests/sim.gd")
const LICENSES := "res://data/LICENSES.md"
const SIZES: Array[Vector2] = [Vector2(960, 720), Vector2(1920, 1080)]

## A radio panel on a host of `size`, themed by `skin` when given.
func _radio(size: Vector2, skin: FrontSkin = null) -> BarkBox:
	var host := Control.new()
	host.size = size
	if skin:
		host.theme = skin.theme()
	Sim.add(host)
	var box := BarkBox.new()
	host.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return box

func _free(box: BarkBox) -> void:
	box.get_parent().free()

func test_panel_and_names_use_the_radio_font() -> bool:
	var ok := true
	for skin: FrontSkin in [null, FrontSkin.for_act(1), FrontSkin.for_act(2)]:
		var box := _radio(Vector2(960, 720), skin)
		ok = ok and box.label.get_theme_font("font") == BarkBox.FONT \
			and box.name_label.get_theme_font("font") == BarkBox.NAME_FONT \
			and box.label.get_theme_font_size("font_size") == BarkBox.FONT_SIZE
		_free(box)
	return ok

func test_font_is_a_monospaced_pixel_font_with_a_bolder_name_cut() -> bool:
	var ok := true
	for f: Font in [BarkBox.FONT, BarkBox.NAME_FONT]:
		var file := f as FontFile
		# Every glyph the same width, and drawn crisp: no smoothing.
		ok = ok and file != null and file.antialiasing == TextServer.FONT_ANTIALIASING_NONE \
			and f.get_string_size("i", 0, -1, BarkBox.FONT_SIZE).x == f.get_string_size("W", 0, -1, BarkBox.FONT_SIZE).x
	# The name's cut is a heavier weight of the same family.
	return ok and BarkBox.NAME_FONT.get_font_weight() > BarkBox.FONT.get_font_weight() \
		and BarkBox.NAME_FONT.get_font_name() == BarkBox.FONT.get_font_name().trim_suffix(" HB")

## Every line the radio can show: each dialogue entry with {you} filled by the
## speaker's longest name for you, each memorial, and each free-flight suggestion.
func _all_lines() -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at("res://data/dialogue"):
		if file.get_extension() != "json":
			continue
		var c: Character = Roster.character(StringName(file.get_basename()))
		var you := "pilot"
		if c:
			for n in c.calls_you:
				if n.length() > you.length():
					you = n
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/" + file))
		_collect(data, you, out)
	var list: SuggestionList = load("res://data/radio/suggestions.tres")
	for s in list.suggestions:
		out.append(s.text)
	return out

func _collect(v: Variant, you: String, out: Array[String]) -> void:
	if v is String:
		out.append(v.replace("{you}", you))
	elif v is Array:
		for e in v:
			_collect(e, you, out)
	elif v is Dictionary:
		if v.has("text"):
			out.append(str(v.text).replace("{you}", you))
		else:
			for k in v:
				_collect(v[k], you, out)

func test_longest_line_fits_at_both_resolutions() -> bool:
	var lines := _all_lines()
	lines.sort_custom(func(a: String, b: String): return a.length() > b.length())
	var ok := lines.size() > 100
	for s in SIZES:
		var box := _radio(s)
		await Sim.process_frames(1)
		var panel := BarkBox.panel_rect(s)
		ok = ok and Rect2(Vector2.ZERO, s).encloses(panel) and panel.encloses(Rect2(box.label.position, box.label.size)) \
			and panel.encloses(Rect2(box.name_label.position, box.name_label.size))
		var height := BarkBox.FONT.get_height(BarkBox.FONT_SIZE)
		for text in lines:
			box.label.text = text
			# Every wrapped line is shown in full: none cut off below the panel.
			if box.label.get_line_count() > box.label.get_visible_line_count() \
					or box.label.get_line_count() * height > box.label.size.y:
				print("        clipped at %s: %s" % [s, text])
				ok = false
		for id in Roster.ids():
			var c: Character = Roster.character(id)
			var name := ("%s  ·  %s" % [c.name, c.role]).to_upper()
			if BarkBox.NAME_FONT.get_string_size(name, 0, -1, BarkBox.FONT_SIZE).x > box.name_label.size.x:
				print("        name too wide at %s: %s" % [s, name])
				ok = false
		_free(box)
	return ok

func test_font_is_cc0_with_url() -> bool:
	var listed := {}
	for line in FileAccess.get_file_as_string(LICENSES).split("\n"):
		var cells := line.split("|")
		if cells.size() >= 4:
			var file := cells[1].strip_edges().trim_prefix("`").trim_suffix("`")
			listed[file] = cells[2].contains("https://") and cells[3].strip_edges() == "CC0"
	var ok := true
	for f: Font in [BarkBox.FONT, BarkBox.NAME_FONT]:
		ok = ok and listed.get(f.resource_path.trim_prefix("res://data/"), false)
	return ok
