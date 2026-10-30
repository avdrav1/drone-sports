class_name ControlsHelp
extends PanelContainer
# The controls, read from the InputMap so a rebound key shows as bound, named
# for the device the player last touched (InputPrompt, Story 23.2): on a pad,
# keyboard-only rows drop out. `toggle_help` shows and hides it; any flying key
# or stick hides it, so it never sits over a flight. The sandbox opens with it up.
# On keys, flying comes first, drawn as key caps laid out as on the keyboard, so
# the arrow keys can't be missed.

## Rows per group: [actions, what they do]. Pairs show as "A / B".
const GROUPS := [
	["FLY", [
		[[&"pitch_forward", &"pitch_back"], "Forward / back"],
		[[&"roll_left", &"roll_right"], "Left / right"],
		[[&"throttle_up", &"throttle_down"], "Climb / descend"],
		[[&"yaw_left", &"yaw_right"], "Turn left / right"],
	]],
	["VIEW AND TOOLS", [
		[[&"cycle_camera"], "Camera view"],
		[[&"toggle_map"], "Full map"],
		[[&"reset_drone"], "Reset the drone (free flight)"],
		[[&"toggle_help"], "Show or hide these controls"],
		[[&"toggle_readout"], "Debug readout"],
		[[&"cycle_preset"], "Cycle act assists (free flight)"],
		[[&"cycle_weather"], "Cycle weather (free flight)"],
		[[&"toggle_mute"], "Sound on or off"],
	]],
	["FLEET (COMMAND VIEW)", [
		[[&"next_drone"], "Select the next drone (or pick one with the mouse)"],
		[[&"prev_drone"], "Select the previous drone"],
		[[&"drop_in"], "Drop into the selected drone, or back out"],
		[[&"send_lap"], "Relay: send the selected drone along its leg"],
		[[&"tag_unit"], "Ravana: send the selected drone to tag one of his heads"],
	]],
	["JOBS", [
		[[&"ui_accept"], "Launch from the briefing"],
		[[&"ui_cancel"], "Back to the job board"],
		[[&"pause"], "Pause (leave or keep flying)"],
	]],
	["START A JOB (FROM FREE FLIGHT)", [
		[[&"start_sample_job"], "Delivery"],
		[[&"start_race_job"], "Race"],
		[[&"start_inspection_job"], "Tower inspection"],
		[[&"start_demolition_job"], "Demolition run"],
		[[&"start_rescue_job"], "Search and rescue"],
	]],
]
## Pressing any of these hides the panel.
const FLY_ACTIONS: Array[StringName] = [&"pitch_forward", &"pitch_back", &"roll_left", &"roll_right",
	&"throttle_up", &"throttle_down", &"yaw_left", &"yaw_right"]
const KEY := Color(1.0, 0.76, 0.25)
const HEAD := Color(0.35, 0.8, 0.95)
const ROW_SIZE := 15
## Groups in the left column; the rest go on the right.
const LEFT_GROUPS := 2
## The default font has no arrow glyphs and the web build has no system font to
## fall back on, so any text naming an arrow key or stick direction falls back
## to this one.
const ARROW_FONT := preload("res://data/ui/fonts/PressStart2P-Regular.ttf")

static var _font: Font

## The default UI font, with arrows. Labels that may show an arrow use it.
static func font() -> Font:
	if _font == null:
		var f: Font = ThemeDB.fallback_font.duplicate()
		f.fallbacks = [ARROW_FONT]
		_font = f
	return _font

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_build()
	InputPrompt.device_changed.connect(_on_device_changed)

func _on_device_changed(_pad: bool) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_build()
	recenter()

## Shrinks to the rebuilt rows and stays centred on its centre anchor, even
## when the device changes before the panel's first layout.
func recenter() -> void:
	var half := get_combined_minimum_size() / 2.0
	offset_left = -half.x
	offset_right = half.x
	offset_top = -half.y
	offset_bottom = half.y

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		visible = not visible
	elif visible and event.is_pressed() and not event.is_echo():
		for a in FLY_ACTIONS:
			if event.is_action(a):
				hide()
				return

## Several actions as one prompt, e.g. "W / S" or "L stick ↑↓".
static func keys_text(actions: Array) -> String:
	return InputPrompt.group_text(actions)

## The job keys, e.g. "J K L H U". Keyboard only, on any device.
static func job_keys() -> String:
	var out: Array[String] = []
	for row in GROUPS[-1][1]:
		out.append(InputPrompt.key_text(row[0][0]))
	return " ".join(out)

## Every action the panel lists.
static func listed_actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for g in GROUPS:
		for row in g[1]:
			out.append_array(row[0])
	return out

## The boss's row names Ravana, so it shows only while the boss is on (rule 9).
static func boss_row_shows(row: Array) -> bool:
	return not &"tag_unit" in row[0] or BossGate.listed()

## One line for a job briefing: the flying keys, camera, map, leaving, and help.
## On a pad whose one stick climbs and turns, that stick is named once.
static func hint_line() -> String:
	var climb_turn := InputPrompt.stick_text([&"throttle_up", &"throttle_down", &"yaw_left", &"yaw_right"])
	var height_turn := "%s height and turn" % climb_turn if climb_turn != "" else "%s height  ·  %s turn" % [
		keys_text([&"throttle_up", &"throttle_down"]), keys_text([&"yaw_left", &"yaw_right"])]
	return "%s move  ·  %s  ·  %s camera  ·  %s map  ·  %s leave  ·  %s all controls" % [
		InputPrompt.group_text([&"pitch_forward", &"pitch_back", &"roll_left", &"roll_right"], ""), height_turn,
		InputPrompt.text(&"cycle_camera"), InputPrompt.text(&"toggle_map"), InputPrompt.text(&"ui_cancel"),
		InputPrompt.text(&"toggle_help")]

func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	box.add_child(_label("CONTROLS", 18))
	# On keys, flying is the key diagram; on a pad, its rows like the rest.
	var first := 0
	if not InputPrompt.pad:
		first = 1
		box.add_child(_label(GROUPS[0][0], 13, HEAD))
		box.add_child(_fly())
	# Two columns so every group fits a 720 px screen.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	box.add_child(columns)
	var column: VBoxContainer
	for i in range(first, GROUPS.size()):
		var g: Array = GROUPS[i]
		var rows: Array = g[1].filter(func(row): return row[0].all(func(a): return InputPrompt.text(a) != "") and boss_row_shows(row))
		if i == first or i == first + LEFT_GROUPS:
			column = VBoxContainer.new()
			column.add_theme_constant_override("separation", 4)
			columns.add_child(column)
		var head := _label(g[0], 13, HEAD)
		head.visible = not rows.is_empty()
		column.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 0)
		column.add_child(grid)
		for row in rows:
			var k := _label(keys_text(row[0]), ROW_SIZE, KEY)
			k.custom_minimum_size.x = 90
			grid.add_child(k)
			grid.add_child(_label(row[1], ROW_SIZE))
	var foot := _label("Any flying %s closes this.  %s brings it back." % ["stick" if InputPrompt.pad else "key",
		InputPrompt.text(&"toggle_help")], 13)
	foot.modulate = Color(1, 1, 1, 0.6)
	box.add_child(foot)

## The flying keys as two key clusters, each key captioned with what it does:
## the arrows move, the letters climb and turn.
func _fly() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var fly: Array = GROUPS[0][1]
	var move := "ARROW KEYS: MOVE" if InputPrompt.key_text(fly[0][0][0]) == "↑" else "MOVE"
	row.add_child(_cluster(move, [fly[0][0][0], fly[1][0][0], fly[0][0][1], fly[1][0][1]],
		["forward", "left", "back", "right"]))
	row.add_child(_cluster("HEIGHT AND TURN", [fly[2][0][0], fly[3][0][0], fly[2][0][1], fly[3][0][1]],
		["climb", "turn left", "descend", "turn right"]))
	return row

## A key cluster laid out as on the keyboard: one key on top, three below.
## `actions` and `words` run top, left, middle, right.
func _cluster(caption: String, actions: Array, words: Array) -> VBoxContainer:
	var out := VBoxContainer.new()
	out.add_theme_constant_override("separation", 2)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 0)
	var at := {1: 0, 3: 1, 4: 2, 5: 3}
	for cell in 6:
		var slot := VBoxContainer.new()
		slot.custom_minimum_size.x = 70
		slot.add_theme_constant_override("separation", 0)
		if at.has(cell):
			var n: int = at[cell]
			var cap := KeyCap.new(InputPrompt.key_text(actions[n]), KEY)
			cap.name = "Key_%s" % actions[n]
			cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			slot.add_child(cap)
			var word := _label(words[n], 12)
			word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot.add_child(word)
		grid.add_child(slot)
	out.add_child(grid)
	var name_label := _label(caption, 14, HEAD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	out.add_child(name_label)
	return out

func _label(text: String, size: int, tint := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	if tint != Color.WHITE:
		l.add_theme_color_override("font_color", tint)
	return l
