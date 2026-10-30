class_name ControlsHelp
extends PanelContainer
# The controls, read from the InputMap so a rebound key shows as bound, named
# for the device the player last touched (InputPrompt, Story 23.2): on a pad,
# keyboard-only rows drop out. `toggle_help` shows and hides it; any flying key
# or stick hides it, so it never sits over a flight.
# On keys, flying comes first, drawn as key caps laid out as on the keyboard, so
# the arrow keys can't be missed.
# Every flight (each job, the boss, free flight) opens with the short version up:
# the flying keys and one line of the few others a new player needs. It never
# covers the drone: it takes the first spot beside the drone's screen rect that
# is clear of it and of the HUD (place), shrinking if none fits, and moves again
# when the window or the camera view changes. `toggle_help` brings up the whole
# list, centred, since the player asked for it.

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
## Screen px kept between the panel and the drone, the HUD and the screen edge.
const GAP := 12.0
## The drone's projected bounds grow by this share of their larger side, and by
## at least DRONE_PAD px, so its props and a little air around it stay in view.
const DRONE_GROW := 0.35
const DRONE_PAD := 48.0
## Scales the short panel tries, largest first, when no spot fits at full size.
## The smallest keeps its smallest text (12 px) near 10 px.
const SCALES: Array[float] = [1.0, 0.9, 0.8]
## Frames between checks that the panel is still clear.
const RECHECK_FRAMES := 15
## Extra px the panel is placed clear of the drone by, so the drone's rect
## shifting a little as its props turn does not move the panel.
const JITTER := 8.0

static var _font: Font

## The whole list is up (`toggle_help`), not the short version.
var full := false
## The short version, wide (the key clusters side by side) and tall (stacked),
## and the whole list.
var _wide: VBoxContainer
var _tall: VBoxContainer
var _full: VBoxContainer
## Frames left before placing: the camera settles after a size or view change.
var _place_in := -1
## What the panel was last placed clear of: 0 all the HUD, 1 what must stay
## readable, 2 the drone alone.
var _tier := 0

## The default UI font, with arrows. Labels that may show an arrow use it.
## A FontVariation, not a duplicate of the default font: a duplicated FontFile
## shares the original's glyph cache, and the two then overwrite each other's
## glyphs, garbling text drawn in either ("Ike" for "the").
static func font() -> Font:
	if _font == null:
		var f := FontVariation.new()
		f.base_font = ThemeDB.fallback_font
		f.fallbacks = [ARROW_FONT]
		_font = f
	return _font

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_build()
	InputPrompt.device_changed.connect(_on_device_changed)
	get_viewport().size_changed.connect(_replace)
	add_to_group(BarkBox.AVOID)
	open()

func _on_device_changed(_pad: bool) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_build()
	if full:
		show_full()
	else:
		open()

## Up with the short version, beside the drone.
func open() -> void:
	full = false
	_full.hide()
	_use(_wide)
	show()
	_replace()

## Up with the whole list, centred.
func show_full() -> void:
	full = true
	_wide.hide()
	_tall.hide()
	_full.show()
	scale = Vector2.ONE
	set_anchors_preset(PRESET_CENTER)
	show()
	recenter()

## Shrinks to the rebuilt rows and stays centred on its centre anchor, even
## when the device changes before the panel's first layout.
func recenter() -> void:
	var half := get_combined_minimum_size() / 2.0
	offset_left = -half.x
	offset_right = half.x
	offset_top = -half.y
	offset_bottom = half.y

## Places the short panel a couple of frames from now.
func _replace() -> void:
	_place_in = 2

## While the short panel is up it is placed after a size or view change, and
## again whenever what it keeps clear of grows into it: the briefing, the job
## panel and the radio fill in over the first frames.
func _process(_delta: float) -> void:
	if not visible or full:
		return
	if _place_in >= 0:
		_place_in -= 1
		if _place_in < 0:
			place()
	elif Engine.get_process_frames() % RECHECK_FRAMES == 0 and not clear():
		place()

func _on_view_changed(_view: int) -> void:
	_replace()

## True while the panel keeps clear of what it was placed clear of.
func clear() -> bool:
	var hud := hud_rects()
	var keep: Array = drone_rects() + (hud.hard if _tier < 2 else []) + (hud.soft if _tier == 0 else [])
	var r := get_global_rect()
	return not keep.any(func(h: Rect2): return r.intersects(h.grow(GAP - 1.0)))

## Puts the short panel at the first spot clear of the drone and the HUD. It
## tries its wide layout, then a tall one, at each scale from full size down;
## then the same keeping clear only of what must stay readable (the job panel,
## the briefing, the radio), not the gauges and corners that mean little before
## launch; then clear of the drone alone, at its smallest.
func place() -> void:
	var s := get_viewport().get_visible_rect().size
	var drones := drone_rects().map(func(r: Rect2): return r.grow(JITTER))
	var hud := hud_rects()
	set_anchors_preset(PRESET_TOP_LEFT)
	var tiers := [hud.hard + hud.soft, hud.hard, []]
	for tier in tiers.size():
		for k in (SCALES if tier < 2 else [SCALES[-1]]):
			for layout in [_wide, _tall]:
				_use(layout)
				var at := spot(s, size * k, drones, tiers[tier])
				if at != Vector2.INF:
					scale = Vector2.ONE * k
					position = at
					_tier = tier
					return
	_use(_wide)
	scale = Vector2.ONE * SCALES[-1]
	position = Vector2(GAP, GAP)
	_tier = 2

## Shows one of the short layouts, sized to it.
func _use(layout: VBoxContainer) -> void:
	_wide.visible = layout == _wide
	_tall.visible = layout == _tall
	size = layout.get_combined_minimum_size() + get_theme_stylebox("panel").get_minimum_size()

## The first spot for a panel of size `p` on a screen of size `s` that keeps
## GAP clear of every rect in `drones` and in `hud`: beside the first drone,
## above it (under the briefing), left, right, then below, the spots along
## each side nearest it first; then anywhere, nearest it first.
## Vector2.INF if none.
static func spot(s: Vector2, p: Vector2, drones: Array, hud: Array) -> Vector2:
	var screen := Rect2(Vector2.ZERO, s).grow(-GAP)
	var d: Rect2 = drones[0].grow(GAP) if drones.size() else Rect2(s / 2.0, Vector2.ZERO)
	var c := d.get_center()
	var tries: Array[Vector2] = []
	# Each side: where the panel sits against the drone, and which way it slides.
	for side in [[Vector2(c.x - p.x / 2.0, d.position.y - p.y), Vector2.RIGHT],
			[Vector2(d.position.x - p.x, c.y - p.y / 2.0), Vector2.DOWN],
			[Vector2(d.end.x, c.y - p.y / 2.0), Vector2.DOWN],
			[Vector2(c.x - p.x / 2.0, d.end.y), Vector2.RIGHT]]:
		for t in [0.0, -0.25, 0.25, -0.5, 0.5, -0.75, 0.75, -1.0, 1.0]:
			tries.append(side[0] + side[1] * t * (p.x if side[1].x != 0.0 else p.y))
	# Then a grid over the screen, its last row and column flush with the edge.
	var xs: Array = range(int(GAP), int(s.x - p.x - GAP), 32) + [s.x - p.x - GAP]
	var ys: Array = range(int(GAP), int(s.y - p.y - GAP), 32) + [s.y - p.y - GAP]
	var grid: Array[Vector2] = []
	for y in ys:
		for x in xs:
			grid.append(Vector2(x, y))
	grid.sort_custom(func(u: Vector2, v: Vector2): return (u + p / 2.0).distance_squared_to(c) < (v + p / 2.0).distance_squared_to(c))
	tries.append_array(grid)
	var keep: Array[Rect2] = []
	for h: Rect2 in hud + drones:
		keep.append(h.grow(GAP))
	for at in tries:
		var r := Rect2(at, p)
		if not screen.encloses(r):
			continue
		var hit := false
		for h in keep:
			if r.intersects(h):
				hit = true
				break
		if not hit:
			return at
	return Vector2.INF

## Where the drones the player is watching show on screen, padded, the one
## the camera follows first: the camera rig's target, or with none (a fleet's
## command view) the middle of the screen, which that view frames, then every
## drone in the scene. In FPV, the middle of the screen, where the flying is.
## Drones off screen give no rect.
func drone_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return out
	var s := get_viewport().get_visible_rect().size
	var rig := cam.get_parent() as CameraRig
	if rig and not rig.view_changed.is_connected(_on_view_changed):
		rig.view_changed.connect(_on_view_changed)
	var middle := Rect2(s * 0.3, s * 0.4)
	var drones: Array = [rig.target] if rig and rig.target else _scene().find_children("*", "Drone", true, false)
	if not (rig and rig.target):
		out.append(middle)
	for drone: Node3D in drones:
		var r := Rect2()
		var first := true
		for m: GeometryInstance3D in drone.find_children("*", "GeometryInstance3D", true, false):
			if m is CPUParticles3D or m is GPUParticles3D or not m.is_visible_in_tree():
				continue
			var box := m.global_transform * m.get_aabb()
			if box.grow(0.3).has_point(cam.global_position):
				return [middle]
			for i in 8:
				var at := box.get_endpoint(i)
				if cam.is_position_behind(at):
					continue
				r = Rect2(cam.unproject_position(at), Vector2.ZERO) if first else r.expand(cam.unproject_position(at))
				first = false
		if first:
			continue
		r = r.grow(maxf(DRONE_PAD, maxf(r.size.x, r.size.y) * DRONE_GROW))
		if r.intersects(Rect2(Vector2.ZERO, s)):
			out.append(r)
	return out

## What the panel keeps off, as {hard, soft}. Hard: the job panel, the radio's
## bar and face, and any label or button showing (the briefing among them).
## Soft: the gauges, compass, pilot's face and foot of the flight HUD, the race
## readouts and leaderboard, the radar. The radio's chat column stacks clear of
## the panel instead (it is in BarkBox.AVOID while up).
func hud_rects() -> Dictionary:
	var s := get_viewport().get_visible_rect().size
	var hard: Array[Rect2] = []
	var soft: Array[Rect2] = []
	for n: Control in _scene().find_children("*", "Control", true, false):
		# The radio pops up with each line, so its place is kept even while it is down.
		if n is BarkBox:
			hard.append_array([BarkBox.panel_rect(s, n.at_top), BarkBox.face_rect(s, n.at_top)])
		if n == self or is_ancestor_of(n) or not n.is_visible_in_tree():
			continue
		if n is FlightHud:
			hard.append(n.panel_rect())
			soft.append_array(n.drawn_rects())
		elif n is RaceHud:
			soft.append_array([n.panel_rect(), n.readouts_rect()])
		elif n is ArcadeBezel:
			soft.append(n.leaderboard_rect())
		elif n is Radar:
			soft.append(n.rect())
		elif n is ChorusBox:
			soft.append(ChorusBox.label_rect(s))
		elif (n is Label or n is Button) and n.text != "" and not (n is ControlsHint) and not _passing(n):
			hard.append(n.get_global_rect())
	return {"hard": hard, "soft": soft.filter(func(r: Rect2): return r.has_area())}

## True for a label that moves out of the panel's way (the radio's chat rows
## stack clear of it) or fades on its own (a toast).
static func _passing(n: Node) -> bool:
	var up := n.get_parent()
	while up:
		if up is BarkBox or up is Toast:
			return true
		up = up.get_parent()
	return false

func _scene() -> Node:
	return owner if owner else get_parent()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		if visible and full:
			hide()
		else:
			show_full()
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
	_wide = _build_brief(false)
	_wide.name = "Brief"
	add_child(_wide)
	_tall = _build_brief(true)
	_tall.name = "BriefTall"
	add_child(_tall)
	_full = _build_full()
	_full.name = "Full"
	add_child(_full)
	_wide.visible = not full
	_tall.visible = false
	_full.visible = full

## The short version: the flying keys (on keys, as key caps), then the few
## others a new player needs, on one line or, `tall`, one per row.
func _build_brief(tall: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_label("CONTROLS", 16))
	if InputPrompt.pad:
		box.add_child(_rows(GROUPS[0][1]))
	else:
		box.add_child(_fly(tall))
	var items := [[&"cycle_camera", "camera"], [&"toggle_map", "map"]]
	if _in_job():
		items.append([&"ui_accept", "launch"])
	items.append_array([[&"ui_cancel", "leave"], [&"toggle_help", "all controls"]])
	var keys: Container
	if tall:
		keys = GridContainer.new()
		keys.columns = 2
		keys.add_theme_constant_override("h_separation", 12)
		keys.add_theme_constant_override("v_separation", 0)
	else:
		keys = HBoxContainer.new()
		keys.add_theme_constant_override("separation", 6)
		keys.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in items.size():
		if i > 0 and not tall:
			keys.add_child(_label("·", ROW_SIZE, Color(1, 1, 1, 0.5)))
		keys.add_child(_label(InputPrompt.text(items[i][0]), ROW_SIZE, KEY))
		keys.add_child(_label(items[i][1], ROW_SIZE))
	box.add_child(keys)
	box.add_child(_foot(false))
	return box

## True in a job (it has a briefing to launch from), false in free flight.
func _in_job() -> bool:
	return _scene() != null and _scene().find_children("*", "JobRunner", true, false).size() > 0

## The whole list: every group, in two columns.
func _build_full() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
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
		if i == first or i == first + LEFT_GROUPS:
			column = VBoxContainer.new()
			column.add_theme_constant_override("separation", 4)
			columns.add_child(column)
		var head := _label(g[0], 13, HEAD)
		var grid := _rows(g[1])
		head.visible = grid.get_child_count() > 0
		column.add_child(head)
		column.add_child(grid)
	box.add_child(_foot(true))
	return box

## A group's rows that have a prompt on this device: keys, then what they do.
func _rows(group: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 0)
	for row in group.filter(func(row): return row[0].all(func(a): return InputPrompt.text(a) != "") and boss_row_shows(row)):
		var k := _label(keys_text(row[0]), ROW_SIZE, KEY)
		k.custom_minimum_size.x = 90
		grid.add_child(k)
		grid.add_child(_label(row[1], ROW_SIZE))
	return grid

func _foot(back: bool) -> Label:
	var foot := _label("Any flying %s closes this." % ("stick" if InputPrompt.pad else "key"), 13)
	if back:
		foot.text += "  %s brings it back." % InputPrompt.text(&"toggle_help")
	foot.modulate = Color(1, 1, 1, 0.6)
	return foot

## The flying keys as two key clusters, each key captioned with what it does:
## the arrows move, the letters climb and turn.
## `stacked` puts the letters under the arrows.
func _fly(stacked := false) -> BoxContainer:
	var row: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	row.add_theme_constant_override("separation", 10 if stacked else 48)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var fly: Array = GROUPS[0][1]
	var move := "ARROW KEYS: MOVE" if InputPrompt.key_text(fly[0][0][0]) == "↑" else "MOVE"
	row.add_child(_cluster(move, [fly[0][0][0], fly[1][0][0], fly[0][0][1], fly[1][0][1]],
		["forward", "left", "back", "right"], stacked))
	row.add_child(_cluster("HEIGHT AND TURN", [fly[2][0][0], fly[3][0][0], fly[2][0][1], fly[3][0][1]],
		["climb", "turn left", "descend", "turn right"], stacked))
	return row

## A key cluster laid out as on the keyboard: one key on top, three below.
## `actions` and `words` run top, left, middle, right.
## `narrow` packs the keys closer, for the tall layout.
func _cluster(caption: String, actions: Array, words: Array, narrow := false) -> VBoxContainer:
	var out := VBoxContainer.new()
	out.add_theme_constant_override("separation", 2)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 0)
	var at := {1: 0, 3: 1, 4: 2, 5: 3}
	for cell in 6:
		var slot := VBoxContainer.new()
		slot.custom_minimum_size.x = 58 if narrow else 70
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
