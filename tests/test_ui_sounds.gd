extends RefCounted
# Story 14.5: interface. Every button on the board and its dialogs (shop, sound,
# offers, pilot select) clicks when pressed, rows rebuilt later included; focus
# blips and a dialog's OK confirms; any screen gets them with UiSounds.wire.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"

func _board() -> JobBoard:
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	return b

## Every button under `n`, internal children (a dialog's OK and Cancel) included.
func _buttons(n: Node, out: Array = []) -> Array:
	if n is BaseButton:
		out.append(n)
	for c in n.get_children(true):
		_buttons(c, out)
	return out

## Presses `b` with only its sounds connected, so nothing it does (fly, change
## scene, buy) happens, then puts its other connections back. Returns the clicks.
func _press_alone(b: BaseButton) -> int:
	var others := b.pressed.get_connections().filter(func(c): return not (c.callable.get_object() is UiSounds))
	for c in others:
		b.pressed.disconnect(c.callable)
	# The log keeps only its last entries; the hangar's many chips would fill it.
	Sfx.clear_log()
	var before := Sfx.count(UiSounds.CLICK)
	b.pressed.emit()
	var clicks := Sfx.count(UiSounds.CLICK) - before
	for c in others:
		b.pressed.connect(c.callable, c.flags)
	return clicks

## Names of the buttons under `root` that do not click exactly once.
func _silent(root: Node) -> Array:
	var out := []
	for b in _buttons(root):
		if _press_alone(b) != 1:
			out.append(str(root.get_path_to(b)))
	return out

func test_every_board_and_dialog_button_clicks() -> bool:
	var b := _board()
	await Sim.process_frames(1)
	# Dialogs build their buttons up front; only one may be open at a time.
	b.pilot_select.open()
	await Sim.process_frames(1)
	var buttons := _buttons(b)
	var silent := _silent(b)
	# Every screen the story names has buttons in the count.
	var found := {}
	for x in buttons:
		for part in [b.shop, b.sound, b.offer_dialog, b.pilot_select]:
			if part.is_ancestor_of(x):
				found[part.name] = true
	var ok: bool = silent.is_empty() and found.size() == 4 \
		and b.fly_button(&"test_race") in buttons
	if not ok:
		print("        silent: ", silent, " screens: ", found.keys(), " buttons: ", buttons.size())
	b.free()
	return ok

func test_rebuilt_rows_still_click() -> bool:
	var b := _board()
	await Sim.process_frames(1)
	b.refresh()
	b.shop.refresh()
	b.pilot_select.refresh()
	await Sim.process_frames(1)
	var silent := _silent(b)
	if not silent.is_empty():
		print("        silent after refresh: ", silent)
	b.free()
	return silent.is_empty()

func test_dialog_ok_confirms_and_focus_blips() -> bool:
	var b := _board()
	await Sim.process_frames(1)
	b.sound.open()
	await Sim.process_frames(1)
	Sfx.clear_log()
	b.sound.get_ok_button().pressed.emit()
	var confirm_ok: bool = Sfx.count(UiSounds.CLICK) == 1 and Sfx.count(UiSounds.CONFIRM) == 1 and not b.sound.visible
	# A new game's pilot select holds focus; with it closed the board takes it.
	b.pilot_select.hide()
	Sfx.clear_log()
	var free: Button = b.find_child("FreeFlight", true, false)
	free.grab_focus()
	var focus_ok: bool = Sfx.count(UiSounds.FOCUS) == 1 and Sfx.count(UiSounds.CLICK) == 0
	if not (confirm_ok and focus_ok):
		print("        confirm ", confirm_ok, " focus ", focus_ok, " log ", Sfx.log.map(func(l): return l.id))
	b.free()
	return confirm_ok and focus_ok

func test_any_screen_wires_with_one_call() -> bool:
	var root := Control.new()
	var early := Button.new()
	root.add_child(early)
	Sim.add(root)
	UiSounds.wire(root)
	var dialog := ConfirmationDialog.new()
	root.add_child(dialog)
	var late := Button.new()
	dialog.add_child(late)
	# Wiring twice never doubles a click.
	UiSounds.wire(root)
	var silent := _silent(root)
	var ok: bool = silent.is_empty() and _buttons(root).size() == 4
	# Buttons outside the wired screen stay quiet.
	var outside := Button.new()
	Sim.add(outside)
	ok = ok and _press_alone(outside) == 0
	outside.free()
	root.free()
	return ok
