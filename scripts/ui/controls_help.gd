class_name ControlsHelp
extends PanelContainer
# The keyboard controls, read from the InputMap so a rebound key shows as bound.
# `toggle_help` shows and hides it; any flying key hides it, so it never sits
# over a flight. The sandbox opens with it up.

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
	]],
	["FLEET (COMMAND VIEW)", [
		[[&"next_drone"], "Select the next drone (or click one)"],
		[[&"drop_in"], "Drop into the selected drone, or back out"],
		[[&"send_lap"], "Relay: send the selected drone round a lap"],
	]],
	["JOBS", [
		[[&"ui_accept"], "Launch from the briefing"],
		[[&"ui_cancel"], "Back to the job board"],
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
const ARROWS := {"Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "Slash": "?", "Escape": "Esc"}
const KEY := Color(1.0, 0.76, 0.25)
const HEAD := Color(0.35, 0.8, 0.95)
const ROW_SIZE := 15

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		visible = not visible
	elif visible and event.is_pressed() and not event.is_echo():
		for a in FLY_ACTIONS:
			if event.is_action(a):
				hide()
				return

## The first keyboard key bound to `action`, as shown to the player; empty when none.
static func key_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var code: Key = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
			var s := OS.get_keycode_string(code)
			return ARROWS.get(s, s)
	return ""

static func keys_text(actions: Array) -> String:
	return " / ".join(actions.map(func(a): return key_text(a)))

## The job keys, e.g. "J K L H U".
static func job_keys() -> String:
	var out: Array[String] = []
	for row in GROUPS[-1][1]:
		out.append(key_text(row[0][0]))
	return " ".join(out)

## Every action the panel lists.
static func listed_actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for g in GROUPS:
		for row in g[1]:
			out.append_array(row[0])
	return out

## One line for a job briefing: the flying keys, camera, map, leaving, and help.
static func hint_line() -> String:
	return "%s%s%s%s move   ·   %s height   ·   %s turn   ·   %s camera   ·   %s map   ·   %s leave   ·   %s all keys" % [
		key_text(&"pitch_forward"), key_text(&"pitch_back"), key_text(&"roll_left"), key_text(&"roll_right"),
		keys_text([&"throttle_up", &"throttle_down"]), keys_text([&"yaw_left", &"yaw_right"]),
		key_text(&"cycle_camera"), key_text(&"toggle_map"), key_text(&"ui_cancel"), key_text(&"toggle_help")]

func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var title := Label.new()
	title.text = "CONTROLS"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	for g in GROUPS:
		var head := Label.new()
		head.text = g[0]
		head.add_theme_color_override("font_color", HEAD)
		head.add_theme_font_size_override("font_size", 13)
		box.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 0)
		box.add_child(grid)
		for row in g[1]:
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
	foot.text = "Any flying key closes this.  %s brings it back." % key_text(&"toggle_help")
	foot.modulate = Color(1, 1, 1, 0.6)
	foot.add_theme_font_size_override("font_size", 13)
	box.add_child(foot)
