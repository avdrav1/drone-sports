extends RefCounted
# Story 27.5: the hangar. The board's GARAGE opens it; a colour, light, decal
# or part changes the turntable at once, and leaving without APPLY keeps the
# old livery; APPLY writes the slot; stat bars show a part's change before it
# is fitted; a locked item can be tried on but not applied until bought;
# every control is reached by pad and keys (focus moves) and by the mouse, and
# B or Esc backs out; nothing overlaps at 960x720 or 1920x1080, the board's
# radio included (it is hidden while the hangar is up). (The old
# shop's tests run against its UPGRADES tab: test_upgrades, test_pad_menus,
# test_job_board, test_ui_sounds, test_little_moments.)

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"
const SCREENS: Array[Vector2i] = [Vector2i(960, 720), Vector2i(1920, 1080)]
const INDIGO := Color(0.16, 0.2, 0.48, 1)
const AMBER := Color(0.95, 0.68, 0.12, 1)
const DIRECTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]

func _in_viewport(size: Vector2i) -> SubViewport:
	var sv := SubViewport.new()
	sv.size = size
	Sim.add(sv)
	return sv

## A board in a viewport of `size` with the hangar open; on a fleet slot, with
## the fleet flown, when `fleet` (so the slot picker and COPY TO ALL are on).
func _open(size := Vector2i(960, 720), fleet := false) -> HangarScreen:
	PlayerProfile.choose_pilot(&"arjuna")
	if fleet:
		StoryFlags.set_flag(Achievement.FLEET_FLAG)
	var sv := _in_viewport(size)
	var b: JobBoard = load(BOARD).instantiate()
	sv.add_child(b)
	await Sim.process_frames(2)
	b.menu_button(&"Garage").pressed.emit()
	await Sim.process_frames(2)
	if fleet:
		b.shop.pick_slot(1)
		await Sim.process_frames(1)
	return b.shop

func _close(h: HangarScreen) -> void:
	h.get_viewport().queue_free()
	await Sim.process_frames(1)
	Wallet.balance = 0

## The body's paint on the turntable's drone: the first box's material.
func _body(h: HangarScreen) -> Color:
	var mi: MeshInstance3D = h.turntable.look().find_children("*", "MeshInstance3D", true, false)[0]
	return (mi.material_override as StandardMaterial3D).albedo_color

func test_garage_opens_the_hangar_with_five_tabs() -> bool:
	var h := await _open()
	var ok: bool = h.visible and h.tab == &"paint" and h.turntable.drone != null
	for t in HangarScreen.TABS:
		ok = ok and h.tab_button(t) != null and h.pages[t] != null
	ok = ok and h.get_viewport().gui_get_focus_owner() == h.tab_button(&"paint")
	await _close(h)
	return ok

func test_changes_show_at_once_and_leaving_keeps_the_old() -> bool:
	for id in [&"indigo", &"lotus", &"glow"]:
		Hangar.unlocked.append(id)
	var before := Hangar.livery(0).to_dict()
	var h := await _open()
	var arms_before: float = h.turntable.drone.arm_length
	h.chip(&"indigo", &"body_color").pressed.emit()
	var ok: bool = _body(h).is_equal_approx(INDIGO)
	h.chip(&"indigo", &"light_color").pressed.emit()
	h.glow_toggle.button_pressed = true
	ok = ok and h.turntable.look().worn().light_color.is_equal_approx(INDIGO) and h.turntable.look().worn().glow
	h.chip(&"lotus").pressed.emit()
	ok = ok and h.turntable.look().worn().decal == &"lotus"
	h.number_slider.value = 12
	ok = ok and h.turntable.look().worn().race_number == 12
	# A part changes the display drone's arms and hull, not the slot's.
	Hangar.unlocked.append(&"heavy_hauler")
	h.chip(&"heavy_hauler", &"frame").pressed.emit()
	ok = ok and h.turntable.drone.arm_length > arms_before and h.turntable.look().hull != Vector3.ONE
	ok = ok and h.changed() and not h.apply_button.disabled
	h.leave()
	ok = ok and not h.visible and Hangar.livery(0).to_dict() == before and Hangar.part_id(0, &"frame") == &"stock_frame"
	# Open again: the draft is the slot as saved, worn in the pilot's body kit
	# (Story 29.1), whose paint stands in for a colour still at stock.
	h.open()
	ok = ok and h.draft.to_dict() == before and h.turntable.look().kit == Hangar.kit(0) \
		and _body(h).is_equal_approx(Hangar.kit(0).painted(Hangar.livery(0)).body_color)
	await _close(h)
	return ok

func test_apply_writes_the_slot() -> bool:
	for id in [&"indigo", &"lotus", &"speed_props"]:
		Hangar.unlocked.append(id)
	var h := await _open()
	h.paint(&"canopy_color", INDIGO)
	h.set_decal(&"lotus")
	h.set_drone_name("  Kestrel  ")
	h.try_part(&"speed_props")
	h.apply_button.pressed.emit()
	var l := Hangar.livery(0)
	var ok: bool = l.canopy_color.is_equal_approx(INDIGO) and l.decal == &"lotus" and l.drone_name == "Kestrel" \
		and Hangar.part_id(0, &"props") == &"speed_props" and not h.changed() and h.apply_button.disabled
	# Saved: a reload keeps it.
	Hangar.load_saved()
	ok = ok and Hangar.livery(0).decal == &"lotus" and Hangar.part_id(0, &"props") == &"speed_props"
	# A name picked from the list, as on a pad.
	h.name_list.select(2)
	h.name_list.item_selected.emit(2)
	ok = ok and h.draft.drone_name == Hangar.catalog.drone_names[1] and h.name_edit.text == h.draft.drone_name
	await _close(h)
	return ok

func test_stat_bars_show_a_part_before_it_is_fitted() -> bool:
	var h := await _open()
	h.show_tab(&"parts")
	var bars: HangarScreen.StatBars = h.pages[&"parts"].get_node("Bars")
	var ok := bars.changed().is_empty()
	# Focus alone shows it: the light racer is lighter, with shorter arms and battery.
	h.chip(&"light_racer", &"frame").focus_entered.emit()
	var shown := bars.changed()
	ok = ok and &"mass" in shown and &"battery_flight_time" in shown and &"arm_length" in shown
	ok = ok and Hangar.part_id(0, &"frame") == &"stock_frame"
	# Tried on (locked, so not fittable), the bars keep it, and so does the slot.
	h.try_part(&"light_racer")
	h.chip(&"light_racer", &"frame").focus_exited.emit()
	ok = ok and bars.changed() == shown and Hangar.part_id(0, &"frame") == &"stock_frame"
	# An upgrade's bar shows its next level.
	Wallet.balance = 5000
	h.show_tab(&"upgrades")
	var ubars: HangarScreen.StatBars = h.pages[&"upgrades"].get_node("Bars")
	h.buy_button(&"thrust").focus_entered.emit()
	ok = ok and ubars.changed().size() == 1 and ubars.changed()[0] == &"max_thrust"
	await _close(h)
	return ok

func test_a_locked_item_is_tried_on_but_bought_before_it_applies() -> bool:
	Wallet.balance = 1000
	var h := await _open()
	h.chip(&"lotus").pressed.emit()
	var ok: bool = h.turntable.look().worn().decal == &"lotus" and h.apply_button.disabled and not h.apply()
	ok = ok and h._info.text.contains("Lotus decal") and h._info.text.contains("Buy for %d" % Hangar.price(&"lotus"))
	ok = ok and h.buy_button_item.visible and not h.buy_button_item.disabled
	var price := Hangar.price(&"lotus")
	h.buy_button_item.pressed.emit()
	ok = ok and Hangar.is_unlocked(&"lotus") and Wallet.balance == 1000 - price and not h.apply_button.disabled
	ok = ok and not h.chip(&"lotus").locked and not h.buy_button_item.visible
	ok = ok and h.apply() and Hangar.livery(0).decal == &"lotus"
	# Unaffordable: shown, but BUY is off.
	h.chip(&"chakra").pressed.emit()
	ok = ok and h.buy_button_item.visible and h.buy_button_item.disabled and h.chip(&"chakra").tooltip_text.contains("Buy for")
	await _close(h)
	return ok

func test_the_info_line_stays_on_the_tab_it_was_picked_on() -> bool:
	Wallet.balance = 5000
	var h := await _open()
	h.show_tab(&"parts")
	h.try_part(&"light_racer")
	var ok: bool = h.picked == &"light_racer" and h._info.text != "" and h.buy_button_item.visible
	# Another tab: the part's line and BUY do not follow; the draft keeps the part.
	h.show_tab(&"upgrades")
	ok = ok and h.picked == &"" and h._info.text == "" and not h.buy_button_item.visible
	ok = ok and h.draft_parts[&"frame"] == &"light_racer"
	await _close(h)
	return ok

## Every control the hangar shows that takes focus, on any tab.
func _focusables(h: HangarScreen) -> Array[Control]:
	var out: Array[Control] = []
	for t in HangarScreen.TABS:
		h.show_tab(t)
		for c: Control in h.find_children("*", "Control", true, false):
			if c.is_visible_in_tree() and c.focus_mode != Control.FOCUS_NONE and not c in out \
					and not (c is BaseButton and c.disabled):
				out.append(c)
	return out

## The tab `c` shows on: its page's, or its own for a tab button; else the one open.
func _page_of(h: HangarScreen, c: Control) -> StringName:
	for t in h.pages:
		if h.pages[t].is_ancestor_of(c) or h.tab_button(t) == c:
			return t
	return h.tab

func test_every_control_is_reached_by_pad_keys_and_mouse() -> bool:
	Wallet.balance = 600
	# A fleet slot: the slot picker and COPY TO ALL (Story 27.6) on too.
	var h := await _open(Vector2i(960, 720), true)
	h.paint(&"body_color", INDIGO) # a change, so APPLY is on
	h.chip(&"lotus").pressed.emit() # a locked one, so BUY shows
	h.apply_button.disabled = false
	var sv := h.get_viewport()
	var all := _focusables(h)
	var seen: Array[Control] = [h.tab_button(&"paint")]
	var queue: Array[Control] = [h.tab_button(&"paint")]
	while not queue.is_empty():
		var c: Control = queue.pop_front()
		for dir in DIRECTIONS:
			if h.tab != _page_of(h, c) or not c.get_global_rect().has_area():
				h.show_tab(_page_of(h, c))
				# A pick lasts only on its tab: back on the lotus's, pick it again.
				if h.tab == _page_of(h, h.chip(&"lotus")):
					h.chip(&"lotus").pressed.emit()
				await Sim.process_frames(1) # laid out: focus moves by where things are
			c.grab_focus()
			var e := InputEventAction.new()
			e.action = dir
			e.pressed = true
			sv.push_input(e)
			var up := e.duplicate()
			up.pressed = false
			sv.push_input(up)
			var f := sv.gui_get_focus_owner()
			if f and h.is_ancestor_of(f) and not f in seen:
				seen.append(f)
				queue.append(f)
	var missed := all.filter(func(c): return not c in seen)
	var escaped := seen.filter(func(c): return not h.is_ancestor_of(c))
	# The mouse: each takes clicks and shows on its page.
	var deaf := []
	for t in HangarScreen.TABS:
		h.show_tab(t)
		await Sim.process_frames(1)
		deaf.append_array(all.filter(func(c): return _page_of(h, c) == t and h.pages[t].is_ancestor_of(c) \
			and (c.mouse_filter == Control.MOUSE_FILTER_IGNORE or not c.get_global_rect().has_area())))
	# COPY TO ALL is off while the draft wears locked items (indigo, lotus); on
	# the slot as saved it is on, and in the walk: right from the slot picker,
	# down to the tabs.
	h.open()
	await Sim.process_frames(1)
	var copy_on := not h.copy_button.disabled
	h.slot_picker.grab_focus()
	for dir in [&"ui_right", &"ui_down"]:
		var e := InputEventAction.new()
		e.action = dir
		e.pressed = true
		sv.push_input(e)
		var up := e.duplicate()
		up.pressed = false
		sv.push_input(up)
		seen.append(sv.gui_get_focus_owner())
	var ok := missed.is_empty() and escaped.is_empty() and deaf.is_empty() and all.size() > 100 \
		and h.slot_picker in seen and copy_on and seen[-2] == h.copy_button and seen[-1] == h.tab_button(h.tab)
	if not ok:
		print("        copy ", copy_on, " ", seen.slice(-2).map(func(c): return h.get_path_to(c)), " missed ", missed.map(func(c): return h.get_path_to(c)), " deaf ", deaf.map(func(c): return h.get_path_to(c)))
	await _close(h)
	return ok

func test_b_and_esc_back_out_without_applying() -> bool:
	Hangar.unlocked.append(&"indigo")
	var before := Hangar.livery(0).to_dict()
	var ok := true
	for back in [InputEventKey, InputEventJoypadButton]:
		var h := await _open()
		h.paint(&"body_color", INDIGO)
		var e: InputEvent
		if back == InputEventKey:
			e = InputEventKey.new()
			e.keycode = KEY_ESCAPE
			e.physical_keycode = KEY_ESCAPE
		else:
			e = InputEventJoypadButton.new()
			e.button_index = JOY_BUTTON_B
		e.pressed = true
		h.get_viewport().push_input(e)
		await Sim.process_frames(1)
		var b: JobBoard = h.get_parent()
		ok = ok and not h.visible and b.page == &"jobs" and Hangar.livery(0).to_dict() == before \
			and h.get_viewport().gui_get_focus_owner() == b.menu_button(&"Garage")
		await _close(h)
	return ok

## Shown text and controls on the hangar that overlap one another or leave
## the screen.
func _overlaps(h: HangarScreen, size: Vector2i) -> Array:
	var out := []
	var screen := Rect2(Vector2.ZERO, Vector2(size)).grow(0.5)
	var items: Array = h.find_children("*", "Control", true, false).filter(func(c): return c.is_visible_in_tree() \
		and ((c is Label and c.text != "") or c is BaseButton or c is Range or c is LineEdit \
		or c is DroneTurntable or c is HangarScreen.StatBars))
	for i in items.size():
		var a: Control = items[i]
		var ar := a.get_global_rect()
		if not screen.encloses(ar):
			out.append("%s leaves the screen at %s" % [h.get_path_to(a), size])
		for j in range(i + 1, items.size()):
			var b: Control = items[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			if ar.grow(-1.0).intersects(b.get_global_rect().grow(-1.0)):
				out.append("%s overlaps %s at %s" % [h.get_path_to(a), h.get_path_to(b), size])
	return out

func test_nothing_overlaps_at_either_size() -> bool:
	Wallet.balance = 600
	var out := []
	for size in SCREENS:
		var h := await _open(size, true)
		# The fullest state: a change pending, and on DECALS and PARTS a locked
		# item picked (info and BUY). A pick lasts only on its own tab.
		h.set_drone_name("Aandhi")
		h.set_decal(&"chakra")
		for t in HangarScreen.TABS:
			h.show_tab(t)
			if t == &"decals":
				h.chip(&"lotus").pressed.emit()
			elif t == &"parts":
				h.try_part(&"heavy_hauler")
			await Sim.process_frames(2)
			if t in [&"decals", &"parts"] and h.picked == &"":
				out.append("nothing picked on %s at %s" % [t, size])
			out.append_array(_overlaps(h, size))
		# The board's radio (its own layer) stays off the hangar: a hello
		# and a purchase's cheer while it is open do not show over it.
		var board: JobBoard = h.get_parent()
		board.bark.say(&"hello")
		h.purchased.emit()
		await Sim.process_frames(2)
		if board.radio.get_canvas_layer_node().visible and board.radio.visible:
			out.append("the radio covers the hangar at %s" % size)
		h.leave()
		await Sim.process_frames(2)
		if not board.radio.get_canvas_layer_node().visible:
			out.append("the radio stays hidden after the hangar at %s" % size)
		await _close(h)
	if not out.is_empty():
		print("        ", "\n        ".join(out.slice(0, 12)))
	return out.is_empty()
