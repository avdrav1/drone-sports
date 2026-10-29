class_name ControlsHelp
extends PanelContainer
# The controls, read from the InputMap so a rebound key shows as bound, named
# for the device the player last touched (InputPrompt, Story 23.2): on a pad,
# keyboard-only rows drop out. `toggle_help` shows and hides it; any flying key
# or stick hides it, so it never sits over a flight. The sandbox opens with it up.

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
		[[&"tag_unit"], "Lattice: send the selected drone to tag a unit"],
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
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var title := Label.new()
	title.text = "CONTROLS"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	# Two columns so every group fits a 720 px screen.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	box.add_child(columns)
	var column: VBoxContainer
	for i in GROUPS.size():
		var g: Array = GROUPS[i]
		var rows: Array = g[1].filter(func(row): return row[0].all(func(a): return InputPrompt.text(a) != ""))
		if i == 0 or i == LEFT_GROUPS:
			column = VBoxContainer.new()
			column.add_theme_constant_override("separation", 4)
			columns.add_child(column)
		var head := Label.new()
		head.text = g[0]
		head.add_theme_color_override("font_color", HEAD)
		head.add_theme_font_size_override("font_size", 13)
		head.visible = not rows.is_empty()
		column.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 0)
		column.add_child(grid)
		for row in rows:
			var k := Label.new()
			k.text = keys_text(row[0])
			k.add_theme_color_override("font_color", KEY)
			k.custom_minimum_size.x = 90
			k.add_theme_font_size_override("font_size", ROW_SIZE)
			grid.add_child(k)
			var what := Label.new()
			what.text = row[1]
			what.add_theme_font_size_override("font_size", ROW_SIZE)
			grid.add_child(what)
	var foot := Label.new()
	foot.text = "Any flying %s closes this.  %s brings it back." % ["stick" if InputPrompt.pad else "key",
		InputPrompt.text(&"toggle_help")]
	foot.modulate = Color(1, 1, 1, 0.6)
	foot.add_theme_font_size_override("font_size", 13)
	box.add_child(foot)
