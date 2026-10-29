extends RefCounted
# Story 23.3: menus by pad alone. A pad walk goes from the title through every
# board page and dialog, a job's briefing, launch, the leave dialog, results,
# and back, with joypad events only; wherever a menu is up, focus is on
# something shown and enabled. B backs out of every page and dialog as Esc
# does, sliders move on the d-pad, the quality list opens, changes and closes
# by pad, and a held stick moves one item per tilt, then repeats.

const Sim = preload("res://tests/sim.gd")
const TITLE := "res://scenes/ui/title.tscn"
const DIRECTIONS_HELD := [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]
const BOARD := "res://scenes/ui/job_board.tscn"

## Steps where focus was missing, hidden, or disabled.
var _bad: Array[String] = []

func _parse(ev: InputEvent, frames := 2) -> void:
	Input.parse_input_event(ev)
	await Sim.process_frames(frames)

## A pad button pressed and let go (buttons fire on release).
func _pad(index: JoyButton, frames := 2) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = index
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	await _parse(up, frames)

func _key(code: Key, frames := 2) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	await _parse(up, frames)

func _stick(x: float, y: float) -> void:
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var ev := InputEventJoypadMotion.new()
		ev.device = 0
		ev.axis = axis
		ev.axis_value = x if axis == JOY_AXIS_LEFT_X else y
		Input.parse_input_event(ev)
	await Sim.process_frames(1)

## The focus owner in the topmost open dialog or popup, else on the screen.
static func focus() -> Control:
	var top: Window = null
	for w in Sim.tree().root.find_children("*", "Window", true, false):
		if w.visible:
			top = w
	return top.gui_get_focus_owner() if top else Sim.tree().root.gui_get_focus_owner()

## Focus is on something shown and enabled; notes the step if not.
func _focused(step: String) -> Control:
	var f := focus()
	if f == null or not f.is_visible_in_tree() or (f is BaseButton and f.disabled):
		_bad.append("%s: focus %s" % [step, f.get_path() if f else "null"])
	return f

func _expect(step: String, ok: bool) -> void:
	if not ok:
		_bad.append(step)

func _scene() -> Node:
	return Sim.tree().current_scene

## Past the title's and the intro's start grace.
func _wait_grace() -> void:
	await Sim.process_frames(40)

func _end() -> bool:
	Sim.tree().paused = false
	Sim.tree().unload_current_scene()
	await Sim.process_frames(2)
	InputPrompt.use_keys()
	if not _bad.is_empty():
		print("        ", "\n        ".join(_bad))
	var ok := _bad.is_empty()
	_bad.clear()
	return ok

func test_pad_walk_from_the_title_to_a_job_and_back() -> bool:
	Sim.tree().change_scene_to_file(TITLE)
	await _wait_grace()
	await _pad(JOY_BUTTON_A, 4)
	# A new game picks a pilot first.
	var b: JobBoard = _scene()
	_expect("board after title", b is JobBoard and b.pilot_select.visible)
	_focused("pilot select, new game")
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_focused("pilot select, next card")
	await _pad(JOY_BUTTON_DPAD_LEFT)
	await _pad(JOY_BUTTON_A)
	_expect("pilot chosen", PlayerProfile.has_pilot() and not b.pilot_select.visible)
	_expect("focus on FLY", _focused("menu") == b.menu_button(&"Fly"))
	# FLY: the d-pad and the stick flip the cards.
	var card := b.carousel.index
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_expect("cards flip", b.carousel.index != card)
	await _stick(-0.9, 0.0)
	await _stick(0.0, 0.0)
	_expect("cards flip back", b.carousel.index == card)
	# GARAGE: the shop, a step inside it, and B out.
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect("on GARAGE", _focused("menu") == b.menu_button(&"Garage"))
	await _pad(JOY_BUTTON_A)
	_expect("shop open", b.shop.visible)
	_focused("shop")
	await _stick(0.0, -0.9)
	await _stick(0.0, 0.0)
	_focused("shop, up")
	await _pad(JOY_BUTTON_B)
	_expect("shop closed", not b.shop.visible)
	_expect("focus back on GARAGE", _focused("menu") == b.menu_button(&"Garage"))
	# PILOT: the cards, and B back to the menu item.
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	_expect("pilot select open", b.pilot_select.visible)
	_focused("pilot select")
	await _pad(JOY_BUTTON_B)
	_expect("pilot select closed", not b.pilot_select.visible)
	_expect("focus back on PILOT", _focused("menu") == b.menu_button(&"Pilot"))
	# CREW: the page scrolls on the d-pad; B goes back.
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	_expect("crew page", b.page == &"crew")
	_focused("crew")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_focused("crew, scrolled")
	await _pad(JOY_BUTTON_B)
	_expect("crew closed", b.page == &"jobs")
	_expect("focus back on CREW", _focused("menu") == b.menu_button(&"Crew"))
	# OPTIONS: Sound's mute box and sliders.
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	_expect("options page", b.page == &"options")
	var sound_button := _focused("options")
	await _pad(JOY_BUTTON_A)
	_expect("sound open", b.sound.visible)
	_expect("mute focused", _focused("sound") == b.sound.mute)
	var muted := GameSettings.muted
	await _pad(JOY_BUTTON_A)
	_expect("A ticks mute", GameSettings.muted != muted)
	await _pad(JOY_BUTTON_A)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var slider := _focused("sound, slider")
	_expect("on a slider", slider is HSlider)
	if slider is HSlider:
		var v: float = slider.value
		await _pad(JOY_BUTTON_DPAD_LEFT)
		_expect("d-pad left lowers it", slider.value < v)
		await _pad(JOY_BUTTON_DPAD_RIGHT)
		_expect("d-pad right raises it", is_equal_approx(slider.value, v))
		_expect("slider keeps focus", focus() == slider)
	await _pad(JOY_BUTTON_B)
	_expect("sound closed", not b.sound.visible)
	_expect("focus back on Sound", _focused("options") == sound_button)
	# Quality: the list opens on the current choice, changes, and closes.
	var quality: OptionButton = b.pages[&"options"].get_node("Box/Quality")
	if quality.visible:
		await _pad(JOY_BUTTON_DPAD_DOWN)
		_expect("on Quality", _focused("options") == quality)
		var was := GameSettings.quality
		await _pad(JOY_BUTTON_A)
		_expect("list open", quality.get_popup().visible)
		_focused("quality list")
		await _pad(JOY_BUTTON_B)
		_expect("B closes the list unchanged", not quality.get_popup().visible and GameSettings.quality == was)
		_expect("focus back on Quality", _focused("options") == quality)
		await _pad(JOY_BUTTON_A)
		await _pad(JOY_BUTTON_DPAD_DOWN)
		_focused("quality list, moved")
		await _pad(JOY_BUTTON_A)
		_expect("quality changed", not quality.get_popup().visible and GameSettings.quality != was)
		_expect("focus back on Quality after a choice", _focused("options") == quality)
		b.set_quality(was)
	await _pad(JOY_BUTTON_B)
	_expect("options closed", b.page == &"jobs")
	_expect("focus back on OPTIONS", _focused("menu") == b.menu_button(&"Options"))
	# Round to FLY, which flies the card showing.
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect("menu wraps to FLY", _focused("menu") == b.menu_button(&"Fly"))
	await _pad(JOY_BUTTON_A, 6)
	# The briefing and the flight have no menu up, so nothing holds focus there.
	var runner: JobRunner = _scene().find_child("JobRunner", true, false) if _scene() else null
	_expect("a job opened", runner != null and runner.state == JobRunner.State.BRIEFING)
	if runner == null:
		return await _end()
	runner.results_delay = 0.0
	await _pad(JOY_BUTTON_A)
	_expect("A launches", runner.state == JobRunner.State.COUNTDOWN)
	while runner.state == JobRunner.State.COUNTDOWN:
		await Sim.physics_frames(1)
	# Start pauses under the leave dialog, on stay; B is stay, as Esc is.
	await _pad(JOY_BUTTON_START)
	_expect("leave dialog", runner.leave_dialog != null and runner.leave_dialog.visible and Sim.tree().paused)
	if runner.leave_dialog:
		_expect("stay focused", _focused("leave dialog") == runner.leave_dialog.get_cancel_button())
		await _pad(JOY_BUTTON_DPAD_LEFT)
		_focused("leave dialog, moved")
		await _pad(JOY_BUTTON_B)
		_expect("B stays", not runner.leave_dialog.visible and not Sim.tree().paused and runner.state == JobRunner.State.LIVE)
	# The job ends (flying it is not the walk's business): results, then the board.
	runner.complete()
	await Sim.process_frames(4)
	_expect("results", runner.results_screen != null and runner.results_screen.is_visible_in_tree())
	if runner.results_screen == null:
		return await _end()
	_expect("Continue focused", _focused("results") == runner.results_screen.continue_button)
	await _pad(JOY_BUTTON_DPAD_LEFT)
	_focused("results, moved")
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	await _pad(JOY_BUTTON_A, 4)
	b = _scene()
	_expect("back on the board", b is JobBoard)
	if not b is JobBoard:
		return await _end()
	_expect("focus on FLY again", _focused("board again") == b.menu_button(&"Fly"))
	# OPTIONS > Watch intro, skipped with a button, lands on the title; A is the board again.
	await _pad(JOY_BUTTON_DPAD_UP)
	await _pad(JOY_BUTTON_A)
	for i in 2 if b.pages[&"options"].get_node("Box/Quality").visible else 1:
		await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect("on Watch intro", _focused("options") == b.pages[&"options"].get_node("Box/WatchIntro"))
	await _pad(JOY_BUTTON_A, 4)
	_expect("intro playing", _scene() is CutscenePlayer)
	await _wait_grace()
	await _pad(JOY_BUTTON_A, 4)
	_expect("skipped to the title", _scene() is TitleScreen)
	await _wait_grace()
	await _pad(JOY_BUTTON_A, 4)
	_expect("board from the title", _scene() is JobBoard)
	_focused("board from the title")
	# And B from the menu is the title, as Esc is.
	await _pad(JOY_BUTTON_B, 4)
	_expect("B to the title", _scene() is TitleScreen)
	return await _end()

## Opens the board and backs out of each page and dialog with `back`, noting
## where it lands each time.
func _back_out(back: Callable) -> Array:
	PlayerProfile.choose_pilot(&"pip")
	Sim.tree().change_scene_to_file(BOARD)
	await Sim.process_frames(3)
	var b: JobBoard = _scene()
	var out := []
	var landed := func(): return [b.page, focus().name if focus() else &"", b.shop.visible, b.sound.visible, b.pilot_select.visible]
	b.menu_button(&"Garage").grab_focus()
	b.shop.open()
	await back.call()
	out.append(landed.call())
	b.menu_button(&"Pilot").grab_focus()
	b.pilot_select.open()
	await Sim.process_frames(1)
	await back.call()
	out.append(landed.call())
	b.open_crew()
	await back.call()
	out.append(landed.call())
	b.open_options()
	b.sound.open()
	await back.call()
	out.append(landed.call())
	await back.call()
	out.append(landed.call())
	await back.call()
	out.append([_scene() is TitleScreen])
	Sim.tree().unload_current_scene()
	await Sim.process_frames(2)
	return out

func test_b_backs_out_of_every_page_as_esc_does() -> bool:
	var esc := await _back_out(func(): await _key(KEY_ESCAPE, 4))
	var pad := await _back_out(func(): await _pad(JOY_BUTTON_B, 4))
	InputPrompt.use_keys()
	var expected := [[&"jobs", &"Garage", false, false, false], [&"jobs", &"Pilot", false, false, false],
		[&"jobs", &"Crew", false, false, false], [&"options", &"Sound", false, false, false],
		[&"jobs", &"Options", false, false, false], [true]]
	if pad != esc or esc != expected:
		print("        esc %s\n        pad %s" % [esc, pad])
	return pad == esc and esc == expected

## A job scene, its runner kept from paying out.
func _job(path: String) -> JobRunner:
	Sim.tree().change_scene_to_file(path)
	await Sim.process_frames(3)
	var runner: JobRunner = _scene().find_child("JobRunner", true, false)
	runner.pays_out = false
	return runner

func test_b_answers_the_crew_risk_and_leave_dialogs_as_esc_does() -> bool:
	Roster.injure(&"marlo")
	var ok := true
	for back in [func(): await _key(KEY_ESCAPE), func(): await _pad(JOY_BUTTON_B)]:
		# Crew at risk: backing out is focused, and B backs out to the board.
		var runner := await _job("res://scenes/jobs/inspection.tscn")
		await _pad(JOY_BUTTON_A)
		ok = ok and runner.launch_dialog != null and runner.launch_dialog.visible \
			and focus() == runner.launch_dialog.get_cancel_button()
		await back.call()
		await Sim.process_frames(3)
		ok = ok and _scene() is JobBoard
		# Leave dialog: B keeps flying, unpaused.
		runner = await _job("res://scenes/jobs/sample_delivery.tscn")
		runner.launch(true)
		while runner.state == JobRunner.State.COUNTDOWN:
			await Sim.physics_frames(1)
		runner.request_leave()
		await Sim.process_frames(1)
		ok = ok and focus() == runner.leave_dialog.get_cancel_button()
		await back.call()
		ok = ok and not runner.leave_dialog.visible and not Sim.tree().paused and runner.state == JobRunner.State.LIVE
	Sim.tree().paused = false
	Sim.tree().unload_current_scene()
	await Sim.process_frames(2)
	InputPrompt.use_keys()
	return ok

func test_offer_dialog_takes_the_pad() -> bool:
	PlayerProfile.choose_pilot(&"pip")
	var team: Team = Career.teams.teams[0]
	var ok := true
	# A answers Join on the focused button; B declines, as Esc does.
	for answer in [[JOY_BUTTON_A, true], [JOY_BUTTON_B, false]]:
		Career.team_id = &""
		Career.pending.assign([team.id])
		var b: JobBoard = (load(BOARD) as PackedScene).instantiate()
		var answered := []
		Sim.add(b)
		await Sim.process_frames(2)
		b.offer_dialog.answered.connect(func(_t, a): answered.append(a))
		ok = ok and b.offer_dialog.visible and focus() != null and focus().is_visible_in_tree()
		# The joining scene is not the test's business.
		var scene := team.joining_scene
		team.joining_scene = ""
		await _pad(answer[0], 3)
		team.joining_scene = scene
		ok = ok and answered == [answer[1]] and not b.offer_dialog.visible
		b.free()
	Career.team_id = &""
	Career.pending.clear()
	InputPrompt.use_keys()
	return ok

## Waits until a direction has been held `seconds`.
func _held(seconds: float) -> void:
	while PadMenus.held != &"" and PadMenus._held_for < seconds:
		await Sim.process_frames(1)
	await Sim.process_frames(1)

func test_held_stick_moves_one_item_then_repeats() -> bool:
	PlayerProfile.choose_pilot(&"pip")
	var b: JobBoard = (load(BOARD) as PackedScene).instantiate()
	Sim.add(b)
	await Sim.process_frames(2)
	var items: Array = b.menu.get_children().filter(func(c): return c is Button and c.focus_mode != Control.FOCUS_NONE)
	var at := func(): return items.find(focus())
	b.menu_button(&"Fly").grab_focus()
	# A real stick sends a stream of motion as it tilts: still one step.
	for y in [0.3, 0.55, 0.7, 0.85, 1.0, 0.95, 1.0]:
		await _stick(0.0, y)
	var one: bool = at.call() == 1
	# Held past the delay, it repeats, one item per beat.
	await _held(PadMenus.REPEAT_DELAY + PadMenus.REPEAT_EVERY * 1.5)
	var repeated: bool = at.call() == 3
	# Let go, then tilt again: one more.
	await _stick(0.0, 0.1)
	await Sim.process_frames(30)
	var stopped: bool = at.call() == 3
	await _stick(0.0, 0.9)
	await _stick(0.0, 0.0)
	var again: bool = at.call() == 4
	# A held d-pad repeats the same way.
	var down := InputEventJoypadButton.new()
	down.device = 0
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	await _parse(down, 1)
	var dpad_once: bool = at.call() == 5
	await _held(PadMenus.REPEAT_DELAY + PadMenus.REPEAT_EVERY * 0.5)
	var dpad_repeat: bool = at.call() == 0
	var up := down.duplicate()
	up.pressed = false
	await _parse(up, 30)
	var dpad_stopped: bool = at.call() == 0
	# Let go means let go: nothing is left held, so the next press is a press.
	var released: bool = DIRECTIONS_HELD.all(func(d): return not Input.is_action_pressed(d))
	b.free()
	InputPrompt.use_keys()
	var ok := one and repeated and stopped and again and dpad_once and dpad_repeat and dpad_stopped and released
	if not ok:
		print("        one %s repeated %s stopped %s again %s dpad %s %s %s released %s" % [one, repeated, stopped, again, dpad_once, dpad_repeat, dpad_stopped, released])
	return ok

func test_the_stick_is_off_the_raw_ui_actions() -> bool:
	# One press per tilt comes from PadMenus; the raw axis would move focus on every event.
	for a in PadMenus.DIRECTIONS:
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadMotion:
				return false
	return PadMenus.direction(Vector2(0.2, 0.6), &"") == &"ui_down" \
		and PadMenus.direction(Vector2(-0.7, 0.3), &"") == &"ui_left" \
		and PadMenus.direction(Vector2(0.0, -0.4), &"") == &"" \
		and PadMenus.direction(Vector2(0.0, -0.4), &"ui_up") == &"ui_up"
