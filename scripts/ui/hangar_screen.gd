class_name HangarScreen
extends Control
# Story 27.5: the hangar, opened by the board's GARAGE. A full-screen layer
# over the board: the slot's drone on a turntable on the left, its name under
# it, and on the right five tabs: PAINT, LIGHTS, DECALS, PARTS and UPGRADES.
# Every change is a draft worn on the turntable at once; APPLY writes it to the
# slot (Hangar.set_livery, Hangar.fit) and leaving without it keeps the old.
# Colours come from the palette only. A locked item can be tried on but not
# applied; picking it names how it opens, with BUY when it is for sale (27.3).
# Parts and upgrades show stat bars with the change lit before it is fitted
# or bought. UPGRADES is the old shop: same rows, prices and rules, and it
# still buys at once. Pad, keys and mouse all reach everything; B or Esc
# backs out, LB and RB flip the tabs.
# Story 27.6: a slot picker in the head (your drone, then Fleet 1, Fleet 2, …;
# the fleet's slots locked until the fleet is first flown) picks the drone
# being set up, and on a fleet slot COPY TO ALL applies the draft and sets
# every fleet slot's looks and parts from it, each keeping its name and number.

## Bought an upgrade or a hangar item.
signal purchased
## Closed, applied or not.
signal closed

const TABS: Array[StringName] = [&"paint", &"lights", &"decals", &"parts", &"upgrades"]
## Livery colour -> its row's name on PAINT.
const PAINT_ROWS := [[&"body_color", "BODY"], [&"arm_color", "ARMS"], [&"prop_color", "PROPS"],
	[&"canopy_color", "CANOPY"]]
## The stat bars: stat, name, unit, and the range a bar spans.
const STAT_ROWS := [
	[&"max_thrust", "THRUST", "N", 3.0, 7.0],
	[&"mass", "WEIGHT", "kg", 0.5, 1.6],
	[&"drag", "DRAG", "", 0.1, 0.4],
	[&"angular_drag", "TURN DRAG", "", 0.03, 0.14],
	[&"arm_length", "ARM LENGTH", "m", 0.1, 0.2],
	[&"yaw_torque_per_thrust", "YAW", "", 0.02, 0.08],
	[&"battery_flight_time", "FLIGHT TIME", "s", 120.0, 600.0],
]
const KIND_NAMES := {&"frame": "FRAME", &"props": "PROPS", &"battery": "BATTERY"}
const DIM := Color(1, 1, 1, 0.55)
const GOOD := Color(0.55, 0.9, 0.55)
const BAD := Color(1.0, 0.45, 0.35)
const NAME_LENGTH := 16
## Under this width the page is tight: smaller type and swatches.
const NARROW := 1200.0
## From this height up, the type grows.
const TALL := 1000.0

## The board's look; set before it is added.
var skin: FrontSkin
## The slot being set up: 0 is the player's drone.
var slot := 0
## What the turntable wears, not yet applied.
var draft: Livery
## Kind -> part id, not yet fitted.
var draft_parts := {}
var tab := &"paint"
var turntable: DroneTurntable
## Tab id -> its button, and its page.
var tab_buttons := {}
var pages := {}
## Upgrade id -> its row on UPGRADES.
var rows := {}
## Every item chip (swatches, decals, parts), to update in place.
var chips: Array[Chip] = []
var name_edit: LineEdit
var name_list: OptionButton
var number_slider: HSlider
var glow_toggle: CheckButton
var apply_button: Button
## Your drone, then each fleet slot (Story 27.6).
var slot_picker: OptionButton
var copy_button: Button
var back_button: Button
var buy_button_item: Button
## The item picked last, which the info line is about.
var picked := &""
var _wallet: Label
var _info: Label
var _status: Label
var _controls: Label
var _number_label: Label
var _part_bars: StatBars
var _upgrade_bars: StatBars
var _part_blurb: Label
var _upgrade_box: VBoxContainer
var _syncing := false

func _ready() -> void:
	if skin == null:
		skin = FrontSkin.current()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	draft = Hangar.livery(slot)
	draft_parts = Hangar.parts(slot)
	_build()
	Garage.bought.connect(_on_bought, CONNECT_DEFERRED)
	Hangar.opened.connect(_on_opened, CONNECT_DEFERRED)
	InputPrompt.device_changed.connect(func(_pad): _controls.text = controls_text())
	visibility_changed.connect(_trap_focus)
	resized.connect(_fit)
	_fit()
	show_tab(&"paint")

## While open, the board behind cannot take keyboard or pad focus, as with
## the pilot select.
func _trap_focus() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for c in parent.get_children():
		if c != self and c is Control:
			c.focus_behavior_recursive = FOCUS_BEHAVIOR_DISABLED if visible else FOCUS_BEHAVIOR_INHERITED

## Opens on the slot as saved, focus on the open tab.
func open() -> void:
	if not Hangar.is_slot_open(slot):
		slot = 0
	_fill_slots()
	draft = Hangar.livery(slot)
	draft_parts = Hangar.parts(slot)
	picked = &""
	_status.text = ""
	refresh()
	show()
	(func():
		var b: Button = tab_buttons[tab]
		if b.is_visible_in_tree() and b.get_focus_mode_with_override() != FOCUS_NONE:
			b.grab_focus()).call_deferred()

## Sets up another slot, from it as saved; a draft not applied is dropped,
## as on leaving. False, and nothing changes, for a locked or unknown slot.
func pick_slot(n: int) -> bool:
	if not Hangar.is_slot_open(n):
		_fill_slots()
		return false
	slot = n
	draft = Hangar.livery(slot)
	draft_parts = Hangar.parts(slot)
	picked = &""
	_status.text = ""
	_fill_slots()
	refresh()
	return true

## Applies the draft to this fleet slot and copies its looks and parts to
## every other fleet slot; names and race numbers stay each slot's own.
func copy_to_all() -> bool:
	if slot == 0 or not locked_items().is_empty():
		return false
	if changed() and not apply():
		return false
	if not Hangar.copy_to_fleet(slot):
		return false
	_status.text = "Copied to every fleet drone."
	_sync()
	return true

## The picker's names: YOUR DRONE, then FLEET 1, FLEET 2, …, locked ones so.
static func slot_name(n: int) -> String:
	return "YOUR DRONE" if n == 0 else "FLEET %d" % n

func _fill_slots() -> void:
	if slot_picker == null:
		return
	slot_picker.clear()
	for n in Hangar.slot_count():
		var open := Hangar.is_slot_open(n)
		slot_picker.add_item(slot_name(n) + ("" if open else "  (locked)"), n)
		slot_picker.set_item_disabled(n, not open)
	slot_picker.select(slot)
	slot_picker.tooltip_text = "" if Hangar.slot_count() < 2 or Hangar.is_slot_open(1) else \
		"The fleet's drones open once the fleet is first flown."

## Leaves without applying: the slot keeps what it had.
func leave() -> void:
	if not visible:
		return
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		leave()
	elif event is InputEventJoypadButton and event.pressed and \
			event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		get_viewport().set_input_as_handled()
		var step := 1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1
		show_tab(TABS[posmod(TABS.find(tab) + step, TABS.size())])
		tab_buttons[tab].grab_focus()

func show_tab(t: StringName) -> void:
	# The info line and BUY are about the item picked on the tab it was picked
	# on: another tab starts with nothing picked.
	var moved := t != tab and picked != &""
	tab = t
	for k in pages:
		pages[k].visible = k == t
		tab_buttons[k].set_pressed_no_signal(k == t)
	if moved:
		_pick(&"")
	else:
		_wire_focus()

## The page's rows of focusable controls, top to bottom: a row is a control,
## or the controls in one row container (the upgrade rows count one each).
func _rows(page: Control) -> Array:
	var out := []
	for c in page.get_children():
		if c == _upgrade_box:
			for r in c.get_children():
				out.append([r.get_node("Buy")])
		elif c is Container:
			var row := c.get_children().filter(func(x): return x is Control and x.focus_mode != FOCUS_NONE)
			if not row.is_empty():
				out.append(row)
		elif c is Control and c.focus_mode != FOCUS_NONE:
			out.append([c])
	return out

## Up and down by rows, set by hand: the turntable is tall, and by distance
## alone a move up or down from the tabs or a page's top row lands on it.
## Up from a page's top row is its tab; down from a tab is its page; the info
## line and the foot go up into the page showing, and down from it is BUY,
## APPLY or BACK, whichever is on.
func _wire_focus() -> void:
	if pages.is_empty():
		return
	var rows := _rows(pages[tab])
	if rows.is_empty():
		return
	var tab_button: Button = tab_buttons[tab]
	var below: Control = buy_button_item if buy_button_item.visible and not buy_button_item.disabled \
		else (apply_button if not apply_button.disabled else back_button)
	for t in TABS:
		var first: Array = _rows(pages[t])[0]
		tab_buttons[t].focus_neighbor_bottom = tab_buttons[t].get_path_to(first[0])
		tab_buttons[t].focus_neighbor_top = tab_buttons[t].get_path_to(slot_picker)
	for c in [slot_picker, copy_button]:
		c.focus_neighbor_bottom = c.get_path_to(tab_button)
	# Along the head, not off down to the tabs by distance.
	slot_picker.focus_neighbor_right = slot_picker.get_path_to(copy_button if not copy_button.disabled else slot_picker)
	copy_button.focus_neighbor_left = copy_button.get_path_to(slot_picker)
	copy_button.focus_neighbor_right = copy_button.get_path_to(copy_button)
	for i in rows.size():
		for j in rows[i].size():
			var c: Control = rows[i][j]
			c.focus_neighbor_top = c.get_path_to(tab_button if i == 0 else _nearest(rows[i - 1], j, rows[i].size()))
			c.focus_neighbor_bottom = c.get_path_to(below if i == rows.size() - 1 else _nearest(rows[i + 1], j, rows[i].size()))
	var last: Control = rows[-1][0]
	buy_button_item.focus_neighbor_top = buy_button_item.get_path_to(last)
	for b in [apply_button, back_button]:
		b.focus_neighbor_top = b.get_path_to(buy_button_item if buy_button_item.visible and not buy_button_item.disabled else last)
	turntable.focus_neighbor_right = turntable.get_path_to(tab_button)
	turntable.focus_neighbor_top = turntable.get_path_to(turntable)

## The control in `row` at the same place along it as `j` of `n`.
static func _nearest(row: Array, j: int, n: int) -> Control:
	return row[clampi(roundi(float(j) / maxf(n - 1, 1) * (row.size() - 1)), 0, row.size() - 1)]

## The draft differs from the slot as saved.
func changed() -> bool:
	return draft.to_dict() != Hangar.livery(slot).to_dict() or draft_parts != Hangar.parts(slot)

## The locked items the draft wears, livery and parts, by id.
func locked_items() -> Array[StringName]:
	var out := Hangar.locked_in(draft)
	for kind in draft_parts:
		if not Hangar.is_open(draft_parts[kind]):
			out.append(draft_parts[kind])
	return out

## Writes the draft to the slot. False, and nothing is written, while it wears
## a locked item.
func apply() -> bool:
	if not locked_items().is_empty():
		return false
	if not Hangar.set_livery(slot, draft):
		return false
	var saved := Hangar.parts(slot)
	for kind in draft_parts:
		if draft_parts[kind] != saved[kind]:
			Hangar.fit(slot, draft_parts[kind])
	_status.text = "Applied."
	_sync()
	return true

## Wears a palette colour on `key` (a Livery colour), in the draft only.
func paint(key: StringName, c: Color) -> void:
	draft.set(key, c)
	_pick(_swatch_id(c))

func set_glow(on: bool) -> void:
	draft.glow = on
	_pick(Hangar.GLOW if on else &"")

func set_decal(id: StringName) -> void:
	draft.decal = id
	_pick(id)

func set_number(n: int) -> void:
	draft.race_number = clampi(n, 0, 99)
	_pick(&"")

func set_drone_name(n: String) -> void:
	draft.drone_name = n.strip_edges().left(NAME_LENGTH)
	_pick(&"")

## Puts the part in the draft, in place of the one of its kind.
func try_part(id: StringName) -> void:
	var p := Hangar.part(id)
	if p:
		draft_parts[p.kind] = id
		_pick(id)

## Buys the item picked; true when it opened.
func buy_picked() -> bool:
	if picked == &"" or not Hangar.buy(picked):
		return false
	purchased.emit()
	refresh()
	return true

func buy_button(id: StringName) -> Button:
	return rows[id].get_node("Buy") if rows.has(id) else null

func tab_button(t: StringName) -> Button:
	return tab_buttons.get(t)

## The chip for `id` on page `t`; for colours, `row` is the Livery colour.
func chip(id: StringName, row: StringName = &"") -> Chip:
	for c in chips:
		if c.item == id and c.row == row:
			return c
	return null

func _swatch_id(c: Color) -> StringName:
	var s := Hangar.swatch_of(c)
	return s.id if s else &""

func _pick(id: StringName) -> void:
	picked = id
	_status.text = ""
	_sync()

func _on_bought(_u, _l) -> void:
	refresh()

func _on_opened(_id) -> void:
	_sync()

## Rebuilds the upgrade rows (as the old shop did) and brings everything else
## up to date.
func refresh() -> void:
	var had: Node = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var had_id := &""
	for id in rows:
		if had and rows[id].is_ancestor_of(had):
			had_id = id
	for c in _upgrade_box.get_children():
		c.free()
	rows.clear()
	for u in Garage.upgrades.upgrades:
		var row := HBoxContainer.new()
		row.name = String(u.id)
		row.add_theme_constant_override("separation", 14)
		var text := Label.new()
		text.name = "Text"
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.text = "%s   Lv %d/%d\n%s each" % [u.name, Garage.level(u.id), u.max_level(), u.effect_text()]
		text.add_theme_font_size_override("font_size", _font(17))
		row.add_child(text)
		var b := Button.new()
		b.name = "Buy"
		var p := Garage.price(u.id)
		b.text = "Buy  %d" % p if p >= 0 else "Maxed"
		b.disabled = not Garage.can_buy(u.id)
		b.custom_minimum_size.x = 150
		b.add_theme_font_size_override("font_size", _font(17))
		b.pressed.connect(func():
			if Garage.buy(u.id):
				purchased.emit())
		b.focus_entered.connect(_show_upgrade.bind(u))
		b.mouse_entered.connect(_show_upgrade.bind(u))
		row.add_child(b)
		rows[u.id] = row
		_upgrade_box.add_child(row)
	if had_id != &"" and is_visible_in_tree():
		var b := buy_button(had_id)
		if b.disabled:
			b = tab_buttons[&"upgrades"]
		b.grab_focus()
	_sync()

## Brings the chips, controls, turntable, bars and text in line with the draft.
func _sync() -> void:
	if draft == null or _wallet == null:
		return
	_syncing = true
	_wallet.text = "Wallet  %d" % Wallet.balance
	copy_button.disabled = slot == 0 or not locked_items().is_empty()
	for c in chips:
		match c.page:
			&"paint", &"lights":
				c.chosen = draft.get(c.row).is_equal_approx(c.fill)
			&"decals":
				if c.row == &"decal_color":
					c.chosen = draft.decal_color.is_equal_approx(c.fill)
				else:
					c.chosen = draft.decal == c.item
					c.tint = Color.WHITE if c.item == &"team" else draft.decal_color
			&"parts":
				c.chosen = draft_parts.values().has(c.item)
		c.locked = c.item != &"" and not Hangar.is_open(c.item)
		c.tooltip_text = (c.label + ("\n" + Hangar.how(c.item) if c.locked else "")).strip_edges()
		c.queue_redraw()
	glow_toggle.set_pressed_no_signal(draft.glow)
	glow_toggle.text = "Lit lights" + ("  (locked)" if not Hangar.is_open(Hangar.GLOW) else "")
	number_slider.set_value_no_signal(draft.race_number)
	_number_label.text = "NUMBER  %s" % (str(draft.race_number) if draft.race_number > 0 else "none")
	if name_edit.text != draft.drone_name:
		name_edit.text = draft.drone_name
	turntable.show_drone(draft, draft_parts)
	_show_parts()
	_show_upgrade(null)
	# The info line: the item picked, and how it opens while it is locked.
	var u := Hangar.unlock_of(picked)
	var how := Hangar.how(picked)
	_info.text = ("%s:  %s" % [u.name, how]) if how else (u.name + "  ·  yours" if u else "")
	var price := Hangar.price(picked)
	buy_button_item.visible = how != "" and price >= 0
	buy_button_item.text = "BUY  %d" % price
	buy_button_item.disabled = not Hangar.can_buy(picked)
	var locked := locked_items()
	apply_button.disabled = not changed() or not locked.is_empty()
	if not locked.is_empty():
		var names: Array = locked.filter(func(id): return id != picked).map(func(id):
			var lu := Hangar.unlock_of(id)
			return lu.name if lu else String(id))
		# The item picked says so on the line above; only others are named here.
		_status.text = "" if names.is_empty() else "Locked: unlock %s to apply." % ", ".join(names)
	elif _status.text.begins_with("Locked"):
		_status.text = ""
	_syncing = false
	_wire_focus()

## PARTS: the bars from the slot as fitted to the draft.
func _show_parts(focus_id := &"") -> void:
	var after := draft_parts.duplicate()
	var shown := Hangar.part(focus_id if focus_id != &"" else picked)
	if shown and focus_id != &"":
		after[shown.kind] = shown.id
	_part_bars.show_change(Garage.stats_with(Hangar.parts(slot), null, slot), Garage.stats_with(after, null, slot))
	if shown == null:
		shown = Hangar.part(draft_parts.get(&"frame", &""))
	_part_blurb.text = "%s: %s" % [shown.name, shown.blurb] if shown else ""

## UPGRADES: the bars now, and with the next level of `u` when there is one.
## Upgrades are the player's drone's: on a fleet slot they change nothing.
func _show_upgrade(u: Upgrade) -> void:
	var now := Garage.stats_with(Hangar.parts(slot), null, slot)
	if u == null or Garage.price(u.id) < 0 or slot != 0:
		_upgrade_bars.show_change(now, now)
		return
	var next := Garage.levels.duplicate()
	next[u.id] = Garage.level(u.id) + 1
	_upgrade_bars.show_change(now, Garage.stats_with(Hangar.parts(slot), next))

## A font size: a step smaller on a narrow screen, bigger on a tall one.
func _font(base: int) -> int:
	if size.x == 0.0:
		return base
	return roundi(base * (0.86 if size.x < NARROW else (1.2 if size.y >= TALL else 1.0)))

## On a resize, the swatches and type follow the width.
func _fit() -> void:
	var h := 44.0 if size.x >= NARROW else 32.0
	for c in chips:
		if c.page in [&"paint", &"lights"] or c.row == &"decal_color":
			c.custom_minimum_size.y = h
		elif c.page == &"decals":
			c.custom_minimum_size = Vector2.ONE * (72.0 if size.x >= NARROW else 44.0)
		elif c.page == &"parts":
			c.custom_minimum_size.y = 56.0 if size.x >= NARROW else 46.0
	for l: Label in find_children("*", "Label", true, false):
		if l.has_meta(&"base_size"):
			l.add_theme_font_size_override("font_size", _font(l.get_meta(&"base_size")))
	for t in tab_buttons:
		tab_buttons[t].add_theme_font_size_override("font_size", 18 if size.x >= NARROW else 13)
	_part_bars.compact = size.x < NARROW
	_upgrade_bars.compact = size.x < NARROW
	refresh()

## The footer of keys for the device in hand.
static func controls_text() -> String:
	var turn := "R STICK  TURN" if InputPrompt.pad else "DRAG / %s  TURN" % \
		InputPrompt.group_text([&"ui_left", &"ui_right"], "")
	var tabs := "      LB/RB  TABS" if InputPrompt.pad and InputPrompt.family == InputPrompt.Family.XBOX else \
		("      %s/%s  TABS" % [InputPrompt.button_name(JOY_BUTTON_LEFT_SHOULDER), InputPrompt.button_name(JOY_BUTTON_RIGHT_SHOULDER)] if InputPrompt.pad else "")
	return ("%s%s      %s  SELECT      %s  BACK" % [turn, tabs, InputPrompt.text(&"ui_accept"),
		InputPrompt.text(&"ui_cancel")]).to_upper()

# --- building ---

func _label(t: String, base: int, color := Color.WHITE, display := false) -> Label:
	var l := Label.new()
	l.text = t
	l.set_meta(&"base_size", base)
	l.add_theme_font_size_override("font_size", base)
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	if display:
		l.theme_type_variation = &"Display"
	return l

func _heading(t: String) -> Label:
	return _label(t, 15, skin.heading, true)

func _panel_style() -> StyleBoxFlat:
	var p := StyleBoxFlat.new()
	p.bg_color = skin.panel
	p.border_color = Color(skin.border, 0.6)
	p.set_border_width_all(2)
	p.set_corner_radius_all(skin.corner_radius)
	p.set_content_margin_all(16)
	return p

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = skin.background
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	page.add_child(head)
	var title := _label("HANGAR", 36, Color.WHITE, true)
	head.add_child(title)
	slot_picker = OptionButton.new()
	slot_picker.name = "Slot"
	slot_picker.fit_to_longest_item = true
	slot_picker.size_flags_vertical = SIZE_SHRINK_CENTER
	slot_picker.add_theme_color_override("font_color", skin.accent)
	slot_picker.item_selected.connect(func(i): pick_slot(slot_picker.get_item_id(i)))
	head.add_child(slot_picker)
	_fill_slots()
	copy_button = Button.new()
	copy_button.name = "CopyToAll"
	copy_button.text = "COPY TO ALL"
	copy_button.tooltip_text = "Applies this drone's look and parts to every fleet drone. Names and numbers stay."
	copy_button.size_flags_vertical = SIZE_SHRINK_CENTER
	copy_button.pressed.connect(copy_to_all)
	head.add_child(copy_button)
	var gap := Control.new()
	gap.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(gap)
	_wallet = _label("", 20)
	_wallet.name = "Wallet"
	_wallet.size_flags_vertical = SIZE_SHRINK_END
	head.add_child(_wallet)
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	page.add_child(body)
	_build_stand(body)
	_build_tabs(body)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	page.add_child(foot)
	_controls = _label(controls_text(), 12, DIM, true)
	_controls.name = "Controls"
	_controls.size_flags_horizontal = SIZE_EXPAND_FILL
	_controls.size_flags_vertical = SIZE_SHRINK_CENTER
	_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(_controls)
	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "BACK"
	back_button.custom_minimum_size.x = 130
	back_button.pressed.connect(leave)
	foot.add_child(back_button)
	apply_button = Button.new()
	apply_button.name = "Apply"
	apply_button.text = "APPLY"
	apply_button.custom_minimum_size.x = 160
	apply_button.pressed.connect(apply)
	foot.add_child(apply_button)

## The left column: the turntable, and the drone's name under it.
func _build_stand(body: HBoxContainer) -> void:
	var col := VBoxContainer.new()
	col.name = "Stand"
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 0.7
	col.add_theme_constant_override("separation", 10)
	body.add_child(col)
	var frame := PanelContainer.new()
	var style := _panel_style()
	style.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", style)
	frame.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(frame)
	turntable = DroneTurntable.new()
	turntable.name = "Turntable"
	turntable.accent = skin.accent
	turntable.custom_minimum_size = Vector2(240, 200)
	frame.add_child(turntable)
	col.add_child(_heading("NAME"))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	col.add_child(name_row)
	name_edit = LineEdit.new()
	name_edit.name = "Name"
	name_edit.max_length = NAME_LENGTH
	name_edit.placeholder_text = "No name"
	name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(t): if not _syncing: set_drone_name(t))
	name_row.add_child(name_edit)
	name_list = OptionButton.new()
	name_list.name = "Names"
	name_list.fit_to_longest_item = false
	name_list.custom_minimum_size.x = 110
	name_list.add_item("PICK")
	for n in Hangar.catalog.drone_names:
		name_list.add_item(n)
	name_list.add_item("No name")
	name_list.item_selected.connect(_on_name_listed)
	name_row.add_child(name_list)

func _on_name_listed(i: int) -> void:
	if i == 0:
		return
	set_drone_name("" if i == name_list.item_count - 1 else name_list.get_item_text(i))
	name_list.select(0)

## The right column: the tab row, the page, and the info line with BUY.
func _build_tabs(body: HBoxContainer) -> void:
	var col := VBoxContainer.new()
	col.name = "Tabs"
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	body.add_child(col)
	var row := HBoxContainer.new()
	row.name = "TabRow"
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Button.new()
		b.name = String(t).capitalize()
		b.text = String(t).to_upper()
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		# Wider for a longer name, so UPGRADES fits as well as PAINT.
		b.size_flags_stretch_ratio = b.text.length() + 4.0
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 15)
		# Slim tabs: five fit a narrow screen's column.
		for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
			var box := get_theme_stylebox(state, "Button").duplicate() as StyleBox
			if box:
				box.content_margin_left = 4
				box.content_margin_right = 4
				b.add_theme_stylebox_override(state, box)
		b.pressed.connect(show_tab.bind(t))
		# Moving along the tabs shows each page, so down goes into it.
		b.focus_entered.connect(show_tab.bind(t))
		row.add_child(b)
		tab_buttons[t] = b
	var stack := PanelContainer.new()
	stack.name = "Page"
	stack.size_flags_vertical = SIZE_EXPAND_FILL
	stack.add_theme_stylebox_override("panel", _panel_style())
	col.add_child(stack)
	pages[&"paint"] = _build_paint()
	pages[&"lights"] = _build_lights()
	pages[&"decals"] = _build_decals()
	pages[&"parts"] = _build_parts()
	pages[&"upgrades"] = _build_upgrades()
	for t in TABS:
		pages[t].name = String(t).capitalize()
		stack.add_child(pages[t])
	var info := HBoxContainer.new()
	info.name = "Info"
	info.add_theme_constant_override("separation", 12)
	info.custom_minimum_size.y = 44
	col.add_child(info)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = SIZE_EXPAND_FILL
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 0)
	info.add_child(lines)
	_info = _label("", 15)
	_info.name = "Item"
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(_info)
	_status = _label("", 14, skin.accent)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(_status)
	buy_button_item = Button.new()
	buy_button_item.name = "BuyItem"
	buy_button_item.custom_minimum_size.x = 150
	buy_button_item.size_flags_vertical = SIZE_SHRINK_CENTER
	buy_button_item.pressed.connect(buy_picked)
	info.add_child(buy_button_item)

func _page() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	return box

## A row of the palette's swatches for `key`, a Livery colour.
func _palette_row(box: VBoxContainer, page: StringName, key: StringName, title: String) -> void:
	box.add_child(_heading(title))
	var row := HBoxContainer.new()
	row.name = String(key)
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	for s in Hangar.catalog.palette:
		var c := _chip(page, s.id, key, s.name)
		c.fill = s.color
		c.size_flags_horizontal = SIZE_EXPAND_FILL
		c.custom_minimum_size = Vector2(20, 32)
		c.pressed.connect(paint.bind(key, s.color))
		row.add_child(c)

func _chip(page: StringName, id: StringName, row: StringName, label: String) -> Chip:
	var c := Chip.new()
	c.name = String(id) if id != &"" else "None"
	c.page = page
	c.item = id
	c.row = row
	c.label = label
	c.accent = skin.accent
	chips.append(c)
	return c

func _build_paint() -> VBoxContainer:
	var box := _page()
	for r in PAINT_ROWS:
		_palette_row(box, &"paint", r[0], r[1])
	return box

func _build_lights() -> VBoxContainer:
	var box := _page()
	_palette_row(box, &"lights", &"light_color", "LIGHT COLOUR")
	glow_toggle = CheckButton.new()
	glow_toggle.name = "Glow"
	glow_toggle.text = "Lit lights"
	glow_toggle.size_flags_horizontal = SIZE_SHRINK_BEGIN
	glow_toggle.toggled.connect(func(on): if not _syncing: set_glow(on))
	box.add_child(glow_toggle)
	var note := _label("Lit, the arm strips and an under-glow shine in the light colour. The front lights stay white and the back lights red in every livery, so you can always tell which way it faces.", 15, DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	return box

func _build_decals() -> VBoxContainer:
	var box := _page()
	box.add_child(_heading("DECAL"))
	var grid := HFlowContainer.new()
	grid.name = "Decals"
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var none := _chip(&"decals", &"", &"", "No decal")
	none.caption = "NONE"
	none.pressed.connect(set_decal.bind(&""))
	grid.add_child(none)
	for id in Hangar.catalog.decals:
		var u := Hangar.unlock_of(id)
		var c := _chip(&"decals", id, &"", u.name if u else String(id).capitalize())
		c.art = DecalArt.texture(id, DroneLook.team_colors())
		c.pressed.connect(set_decal.bind(id))
		grid.add_child(c)
	_palette_row(box, &"decals", &"decal_color", "DECAL AND NUMBER COLOUR")
	_number_label = _heading("NUMBER")
	box.add_child(_number_label)
	number_slider = HSlider.new()
	number_slider.name = "Number"
	number_slider.min_value = 0
	number_slider.max_value = 99
	number_slider.step = 1
	number_slider.custom_minimum_size.y = 28
	# A track that reads on the dark page, filled in the accent to the number.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(3)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var filled: StyleBoxFlat = track.duplicate()
	filled.bg_color = skin.accent
	number_slider.add_theme_stylebox_override("slider", track)
	number_slider.add_theme_stylebox_override("grabber_area", filled)
	number_slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	number_slider.value_changed.connect(func(v): if not _syncing: set_number(int(v)))
	box.add_child(number_slider)
	return box

func _build_parts() -> VBoxContainer:
	var box := _page()
	for kind in Part.KINDS:
		box.add_child(_heading(KIND_NAMES[kind]))
		var row := HBoxContainer.new()
		row.name = String(kind)
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var parts := Hangar.catalog.parts.filter(func(p): return p.kind == kind)
		for p in parts:
			var c := _chip(&"parts", p.id, kind, p.name)
			c.caption = p.name
			c.size_flags_horizontal = SIZE_EXPAND_FILL
			c.custom_minimum_size.y = 46
			c.pressed.connect(try_part.bind(p.id))
			c.focus_entered.connect(_show_parts.bind(p.id))
			c.mouse_entered.connect(_show_parts.bind(p.id))
			c.focus_exited.connect(_show_parts)
			c.mouse_exited.connect(_show_parts)
			row.add_child(c)
	_part_blurb = _label("", 15, DIM)
	_part_blurb.name = "Blurb"
	_part_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_part_blurb)
	_part_bars = StatBars.new()
	_part_bars.name = "Bars"
	_part_bars.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(_part_bars)
	return box

func _build_upgrades() -> VBoxContainer:
	var box := _page()
	box.add_child(_heading("UPGRADES"))
	_upgrade_box = VBoxContainer.new()
	_upgrade_box.name = "Rows"
	_upgrade_box.add_theme_constant_override("separation", 10)
	box.add_child(_upgrade_box)
	_upgrade_bars = StatBars.new()
	_upgrade_bars.name = "Bars"
	_upgrade_bars.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(_upgrade_bars)
	return box

## An item to pick: a palette swatch, a decal, or a part. Drawn in code: its
## colour, decal or name; a ring when worn; a padlock when locked.
class Chip extends Button:
	## The tab it is on, the item (swatch, decal or part id), and its row (the
	## Livery colour for a swatch, the kind for a part).
	var page: StringName
	var item: StringName
	var row: StringName
	var label := ""
	var fill := Color(0, 0, 0, 0)
	var art: Texture2D
	var tint := Color.WHITE
	var caption := ""
	var chosen := false
	var locked := false
	var accent := Color(1.0, 0.76, 0.25)

	func _ready() -> void:
		var empty := StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			add_theme_stylebox_override(s, empty)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		if custom_minimum_size == Vector2.ZERO:
			custom_minimum_size = Vector2(50, 50)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(5)
		box.bg_color = fill if fill.a > 0.0 else Color(1, 1, 1, 0.07 if not is_hovered() else 0.12)
		if fill.a > 0.0 and is_hovered():
			box.bg_color = fill.lightened(0.1)
		box.border_color = Color(1, 1, 1, 0.18)
		box.set_border_width_all(1)
		draw_style_box(box, r.grow(-2))
		if art:
			var side := minf(size.x, size.y) - 12.0
			draw_texture_rect(art, Rect2((size - Vector2.ONE * side) * 0.5, Vector2.ONE * side), false, tint)
		if caption != "":
			var font := get_theme_font("font", "Label")
			var fs := 18 if size.y >= 52.0 else 14
			# Clear of the padlock, and shrunk until the longest word fits.
			var w := size.x - 12.0 - (2.0 * clampf(minf(size.x, size.y) * 0.42, 10.0, 18.0) if locked else 0.0)
			while fs > 10 and font.get_string_size(caption.split(" ")[0] if caption.length() > 8 else caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
				fs -= 1
			var lines := font.get_multiline_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, w, fs)
			var top := (size.y - lines.y) * 0.5 + font.get_ascent(fs)
			draw_multiline_string(font, Vector2((size.x - w) * 0.5, top), caption, HORIZONTAL_ALIGNMENT_CENTER, w, fs, -1,
				accent if chosen else Color(1, 1, 1, 0.55 if locked else 0.95))
		if locked:
			# A padlock in the corner, on a dark tab so it reads on any colour.
			var s := clampf(minf(size.x, size.y) * 0.42, 10.0, 18.0)
			var at := Vector2(size.x - s - 3.0, 3.0)
			draw_rect(Rect2(at, Vector2.ONE * s), Color(0, 0, 0, 0.6))
			var c := at + Vector2.ONE * s * 0.5
			var q := s * 0.42
			draw_arc(c - Vector2(0, q * 0.15), q * 0.42, PI, TAU, 10, Color.WHITE, maxf(q * 0.14, 1.2), true)
			draw_rect(Rect2(c + Vector2(-q * 0.7, -q * 0.12), Vector2(q * 1.4, q * 0.95)), Color.WHITE)
		if chosen:
			var ring := StyleBoxFlat.new()
			ring.draw_center = false
			ring.border_color = Color.WHITE if caption == "" else accent
			ring.set_border_width_all(3)
			ring.set_corner_radius_all(6)
			draw_style_box(ring, r)
		if has_focus():
			var f := StyleBoxFlat.new()
			f.draw_center = false
			f.border_color = accent
			f.set_border_width_all(3)
			f.set_corner_radius_all(7)
			f.set_expand_margin_all(3)
			draw_style_box(f, r)

## Stat bars: each stat's value now, with the change to `after` lit, green
## where it is better for the pilot and red where worse (Part.BETTER).
class StatBars extends Control:
	var before := {}
	var after := {}
	## Smaller type and rows, on a narrow screen.
	var compact := false:
		set(v):
			compact = v
			update_minimum_size()
			queue_redraw()

	func show_change(from: Dictionary, to: Dictionary) -> void:
		before = from
		after = to
		queue_redraw()

	## Stats whose value changes, by name.
	func changed() -> Array[StringName]:
		var out: Array[StringName] = []
		for r in STAT_ROWS:
			if not is_equal_approx(before.get(r[0], 0.0), after.get(r[0], 0.0)):
				out.append(r[0])
		return out

	func _row() -> float:
		return 20.0 if compact else 30.0

	func _get_minimum_size() -> Vector2:
		return Vector2(200, _row() * STAT_ROWS.size())

	func _draw() -> void:
		var font := get_theme_font("font", "Label")
		var fs := 13 if compact else 18
		var name_w := 108.0 if compact else 160.0
		var value_w := 130.0 if compact else 210.0
		var bar_w := maxf(size.x - name_w - value_w - 16.0, 40.0)
		var h := _row()
		for i in STAT_ROWS.size():
			var r: Array = STAT_ROWS[i]
			var y := i * h
			var mid := y + h * 0.5
			draw_string(font, Vector2(0, mid + fs * 0.35), r[1], HORIZONTAL_ALIGNMENT_LEFT, name_w, fs, DIM)
			var a: float = before.get(r[0], 0.0)
			var b: float = after.get(r[0], a)
			var fa := clampf(inverse_lerp(r[3], r[4], a), 0.03, 1.0)
			var fb := clampf(inverse_lerp(r[3], r[4], b), 0.03, 1.0)
			var x0 := name_w
			var bar_h := h * 0.42
			var top := mid - bar_h * 0.5
			draw_rect(Rect2(x0, top, bar_w, bar_h), Color(1, 1, 1, 0.08))
			draw_rect(Rect2(x0, top, bar_w * minf(fa, fb), bar_h), Color(1, 1, 1, 0.7))
			var color := Color(1, 1, 1, 0.7)
			if not is_equal_approx(a, b):
				var better: int = Part.BETTER.get(r[0], 1)
				color = GOOD if signf(b - a) * better > 0.0 else BAD
				var lo := minf(fa, fb)
				var hi := maxf(fa, fb)
				var seg := Rect2(x0 + bar_w * lo, top, bar_w * (hi - lo), bar_h)
				if fb > fa:
					draw_rect(seg, color)
				else:
					draw_rect(seg, Color(color, 0.25))
					draw_rect(seg, color, false, 1.5)
			var text := _number(a, r[2])
			if not is_equal_approx(a, b):
				text += "  →  " + _number(b, r[2])
			draw_string(font, Vector2(x0 + bar_w + 12.0, mid + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT,
				value_w, fs, color if not is_equal_approx(a, b) else Color(1, 1, 1, 0.85))

	static func _number(x: float, unit: String) -> String:
		var n := str(roundi(x)) if absf(x) >= 10.0 else "%.2f" % x
		return n + (" " + unit if unit else "")
