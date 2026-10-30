extends RefCounted
# Story 28.5: remap buttons in PAD CHECK. A pad that reports its buttons in the
# wrong order is fixed by a walk through A, B, X, Y, LB, RB, Back and Start;
# the remap goes onto the InputMap (so actions follow), is saved per pad name,
# and RESET puts the project's bindings back exactly.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"
const SCREENS: Array[Vector2i] = [Vector2i(960, 720), Vector2i(1920, 1080)]
## The raw buttons a walk gives that swaps A and B and keeps the rest.
const SWAP: Array[int] = [JOY_BUTTON_B, JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y,
	JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_BACK, JOY_BUTTON_START]

func _clean() -> void:
	PadRemap.remaps = {}
	PadRemap.apply("")
	GameSettings.save()

## Every action's events, as text, in order.
func _bindings() -> Dictionary:
	var out := {}
	for action in InputMap.get_actions():
		out[action] = InputMap.action_get_events(action).map(func(e): return "%s@%d" % [e.as_text(), e.device])
	return out

func _swap_map() -> Dictionary:
	var m := {}
	for i in PadRemap.STEPS.size():
		m[PadRemap.STEPS[i]] = SWAP[i]
	return m

func _raw(index: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = index as JoyButton
	ev.pressed = true
	return ev

func _button(index: int, pressed := true) -> void:
	var ev := _raw(index)
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await Sim.process_frames(2)

func _press(index: int) -> void:
	await _button(index)
	await _button(index, false)

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await Sim.process_frames(2)

func _page() -> Array:
	PlayerProfile.choose_pilot(&"arjuna")
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	await Sim.process_frames(1)
	b.open_options()
	b.open_pad_check()
	return [b, b.pages[&"pad_check"]]

func _text(node: Node) -> String:
	var out := ""
	for l in node.find_children("*", "Label", true, false):
		if l.is_visible_in_tree():
			out += l.text + "\n"
	return out

## A walk that gives B's button for A and A's for B swaps them everywhere:
## ui_accept, ui_cancel, a flight action on A, the names on the page and in
## prompts.
func test_walk_swaps_a_and_b() -> bool:
	_clean()
	var before := _bindings()
	var made: Array = await _page()
	var b: JobBoard = made[0]
	var page: PadCheck = made[1]
	await _key(KEY_R)
	var ok := page.walking() and _text(page).contains("REMAP 1 of 8: press A, the bottom face button")
	for i in SWAP.size():
		await _press(SWAP[i])
		ok = ok and b.page == &"pad_check"
	ok = ok and not page.walking() and PadRemap.has_remap(Input.get_joy_name(0))
	ok = ok and _raw(JOY_BUTTON_B).is_action(&"ui_accept") and not _raw(JOY_BUTTON_B).is_action(&"ui_cancel") \
		and _raw(JOY_BUTTON_A).is_action(&"ui_cancel") and not _raw(JOY_BUTTON_A).is_action(&"ui_accept")
	ok = ok and _raw(JOY_BUTTON_B).is_action(&"drop_in") and not _raw(JOY_BUTTON_A).is_action(&"drop_in") \
		and _raw(JOY_BUTTON_Y).is_action(&"cycle_camera")
	ok = ok and PadRemap.logical(JOY_BUTTON_B) == JOY_BUTTON_A and PadRemap.logical(JOY_BUTTON_DPAD_UP) == JOY_BUTTON_DPAD_UP
	# Input's own action state follows the raw press too.
	Input.parse_input_event(_raw(JOY_BUTTON_B))
	await Sim.process_frames(2)
	ok = ok and Input.is_action_pressed(&"ui_accept") and not Input.is_action_pressed(&"ui_cancel")
	# The page names the raw B press as A, and stays; the raw A press leaves.
	ok = ok and page.last_button == JOY_BUTTON_A and _text(page).contains("Pressed: A  (button 1)") and b.page == &"pad_check"
	await _button(JOY_BUTTON_B, false)
	InputPrompt.use_pad(0, "Xbox Wireless Controller")
	ok = ok and InputPrompt.pad_text(&"ui_accept") == "A" and InputPrompt.pad_text(&"ui_cancel") == "B" \
		and PadCheck.leave_names(InputPrompt.Family.XBOX) == ["B", "Esc"]
	await _press(JOY_BUTTON_A)
	ok = ok and b.page == &"options"
	b.free()
	InputPrompt.use_keys()
	_clean()
	return ok and _bindings() == before

## The remap is saved under the pad's name and comes back on load; another pad
## keeps the project's bindings.
func test_survives_a_reload_for_that_pad_only() -> bool:
	_clean()
	var before := _bindings()
	PadRemap.set_remap("GameSir-G7 USB", _swap_map())
	PadRemap.remaps = {}
	PadRemap.apply("")
	var ok := _bindings() == before
	GameSettings.load_saved()
	PadRemap.refresh(["GameSir-G7 USB"])
	ok = ok and PadRemap.has_remap("gamesir-g7 usb") and PadRemap.remaps["gamesir-g7 usb"] == _swap_map()
	ok = ok and _raw(JOY_BUTTON_B).is_action(&"ui_accept") and _raw(JOY_BUTTON_A).is_action(&"ui_cancel")
	PadRemap.refresh(["Xbox Wireless Controller"])
	ok = ok and _bindings() == before and PadRemap.logical(JOY_BUTTON_B) == JOY_BUTTON_B
	PadRemap.refresh(["Xbox Wireless Controller", "GameSir-G7 USB"])
	ok = ok and _raw(JOY_BUTTON_B).is_action(&"ui_accept")
	_clean()
	return ok and _bindings() == before

## RESET restores the InputMap exactly, even after a remap that put A on a
## d-pad button (which leaves the d-pad up binding off).
func test_reset_restores_the_project_bindings() -> bool:
	_clean()
	var before := _bindings()
	var odd := _swap_map()
	odd[JOY_BUTTON_A] = JOY_BUTTON_DPAD_UP
	PadRemap.set_remap("Odd Pad", odd)
	var ok := _bindings() != before and _raw(JOY_BUTTON_DPAD_UP).is_action(&"ui_accept") \
		and PadRemap.logical(JOY_BUTTON_DPAD_UP) == JOY_BUTTON_A and PadRemap.logical(JOY_BUTTON_B) == JOY_BUTTON_INVALID
	PadRemap.reset("Odd Pad")
	ok = ok and _bindings() == before and not PadRemap.has_remap("odd pad") \
		and PadRemap.logical(JOY_BUTTON_DPAD_UP) == JOY_BUTTON_DPAD_UP
	_clean()
	return ok

## Esc mid-walk leaves the old remap on; a button already given is refused.
func test_esc_cancels_and_a_repeat_is_refused() -> bool:
	_clean()
	PadRemap.set_remap(Input.get_joy_name(0), _swap_map())
	var mid := _bindings()
	var made: Array = await _page()
	var b: JobBoard = made[0]
	var page: PadCheck = made[1]
	page.start_remap()
	await _press(JOY_BUTTON_X)
	var ok := page.walk_step == 1
	await _press(JOY_BUTTON_X)
	ok = ok and page.walk_step == 1 and page.walk_note != "" and _text(page).contains("already A") \
		and _text(page).contains("REMAP 2 of 8")
	# B and Start answer steps rather than leave or open anything.
	await _press(JOY_BUTTON_A)
	ok = ok and page.walk_step == 2 and b.page == &"pad_check"
	await _key(KEY_ESCAPE)
	ok = ok and not page.walking() and b.page == &"pad_check" and _bindings() == mid \
		and PadRemap.remaps[PadRemap.key(Input.get_joy_name(0))] == _swap_map()
	b.free()
	InputPrompt.use_keys()
	_clean()
	return ok

## REMAP by holding Start or pressing R; RESET by holding Back or pressing
## Backspace, shown only while the pad has a remap.
func test_remap_and_reset_by_pad_and_keys() -> bool:
	_clean()
	var before := _bindings()
	var made: Array = await _page()
	var b: JobBoard = made[0]
	var page: PadCheck = made[1]
	var ok := page.remap_button.visible and not page.reset_button.visible
	await _press(JOY_BUTTON_START)
	ok = ok and not page.walking()
	await _button(JOY_BUTTON_START)
	await Sim.tree().create_timer(PadCheck.HOLD + 0.2).timeout
	ok = ok and page.walking() and not page.remap_button.visible
	await _button(JOY_BUTTON_START, false)
	for i in SWAP.size():
		await _press(SWAP[i])
	ok = ok and not page.walking() and page.reset_button.visible and _bindings() != before
	# Back is Back on this remap; held, it resets.
	await _button(JOY_BUTTON_BACK)
	await Sim.tree().create_timer(PadCheck.HOLD + 0.2).timeout
	await _button(JOY_BUTTON_BACK, false)
	ok = ok and _bindings() == before and not page.reset_button.visible
	# The keys.
	await _key(KEY_R)
	for i in SWAP.size():
		await _press(SWAP[i])
	ok = ok and page.reset_button.visible and _bindings() != before
	await _key(KEY_BACKSPACE)
	ok = ok and _bindings() == before and not page.reset_button.visible and b.page == &"pad_check"
	b.free()
	InputPrompt.use_keys()
	_clean()
	return ok

## Mid-walk, with a refused button's note, nothing on the page overlaps or
## leaves the screen at 960x720 and 1920x1080.
func test_walk_fits_on_screen() -> bool:
	_clean()
	PlayerProfile.choose_pilot(&"arjuna")
	var bad := []
	for size in SCREENS:
		var sv := SubViewport.new()
		sv.size = size
		Sim.add(sv)
		var b: JobBoard = load(BOARD).instantiate()
		sv.add_child(b)
		await Sim.process_frames(2)
		b.open_options()
		b.open_pad_check()
		var page: PadCheck = b.pages[&"pad_check"]
		page.start_remap()
		page.take(0, JOY_BUTTON_A)
		page.take(0, JOY_BUTTON_A)
		await Sim.process_frames(3)
		bad.append_array(_overlaps(page, size))
		page.cancel_remap()
		PadRemap.set_remap(Input.get_joy_name(0), _swap_map())
		page.reset()
		bad.append_array([] if page.reset_button.is_visible_in_tree() else ["RESET hidden at %s" % size])
		await Sim.process_frames(3)
		bad.append_array(_overlaps(page, size))
		_clean()
		sv.free()
	if not bad.is_empty():
		print("        ", bad)
	return bad.is_empty()

func _overlaps(root: Control, size: Vector2i) -> Array:
	var out := []
	var screen := Rect2(Vector2.ZERO, Vector2(size)).grow(0.5)
	var shown: Array = root.find_children("*", "Control", true, false).filter(func(c): return c.is_visible_in_tree() \
		and (c is Label or c is BaseButton or c is PadCheck.StickView or c is PadCheck.TriggerView))
	for c in shown:
		var r: Rect2 = c.get_global_rect()
		if not screen.encloses(r):
			out.append("%s leaves the screen at %s" % [c.name, size])
		for o in shown:
			if o != c and o.get_instance_id() > c.get_instance_id() and r.grow(-1.0).intersects(o.get_global_rect().grow(-1.0)):
				out.append("%s overlaps %s at %s" % [c.name, o.name, size])
	return out
