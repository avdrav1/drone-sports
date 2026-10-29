extends Node
# Autoload PadMenus: menus by pad alone (Story 23.3). Three things Godot's own
# ui_* bindings leave out:
# - The left stick moves focus one item per tilt, then repeats while held. A
#   real stick sends a stream of motion events, and each one past the deadzone
#   would move focus again, so the stick comes off the ui_* actions and this
#   sends one ui_* press per tilt instead. A held d-pad repeats the same way,
#   as a held arrow key does.
# - B closes a dialog exactly as Esc does: Godot's dialogs only close on the key.
# - A list (an OptionButton's) opens with focus on its current item.
# A dialog that closes hands focus back to the control that opened it on its
# own: an open dialog never takes the screen's focus away.

## Seconds a direction is held before it repeats, then seconds between repeats.
const REPEAT_DELAY := 0.4
const REPEAT_EVERY := 0.12
## A stick tilt counts past PRESS and lets go under RELEASE, so a stick
## resting on the line does not chatter.
const PRESS := 0.5
const RELEASE := 0.35
const DIRECTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]
const DPAD := {JOY_BUTTON_DPAD_UP: &"ui_up", JOY_BUTTON_DPAD_DOWN: &"ui_down",
	JOY_BUTTON_DPAD_LEFT: &"ui_left", JOY_BUTTON_DPAD_RIGHT: &"ui_right"}
## Marks a window already watched.
const META := &"pad_menus"

## The ui_* direction held now (stick or d-pad), or empty.
var held := &""
## Left stick position, from its motion events.
var stick := Vector2.ZERO

var _from_stick := false
var _held_for := 0.0
var _next_repeat := 0.0

func _ready() -> void:
	# The leave dialog is opened over a paused tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in DIRECTIONS:
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadMotion:
				InputMap.action_erase_event(action, e)
	# The window hears every event first, including those forwarded to dialogs.
	get_tree().root.window_input.connect(seen)
	get_tree().node_added.connect(_watch)

## Tracks the left stick and the d-pad from `event`.
func seen(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if event.axis == JOY_AXIS_LEFT_X:
			stick.x = event.axis_value
		else:
			stick.y = event.axis_value
		_on_stick()
	elif event is InputEventJoypadButton and DPAD.has(event.button_index):
		var action: StringName = DPAD[event.button_index]
		if event.pressed:
			# The button itself already moved focus once; only the repeats are ours.
			_hold(action, false)
		elif held == action and not _from_stick:
			held = &""

## The stick's direction: its bigger axis, once past PRESS.
static func direction(at: Vector2, current: StringName) -> StringName:
	var letting_go := RELEASE if current != &"" else PRESS
	if at.length() < letting_go:
		return &""
	if absf(at.x) > absf(at.y):
		return &"ui_right" if at.x > 0.0 else &"ui_left"
	return &"ui_down" if at.y > 0.0 else &"ui_up"

func _on_stick() -> void:
	var now := direction(stick, held if _from_stick else &"")
	if _from_stick and now == held:
		return
	if now == &"":
		if _from_stick:
			_send(held, false)
			held = &""
		return
	if _from_stick:
		_send(held, false)
	_send(now, true)
	_hold(now, true)

func _hold(action: StringName, from_stick: bool) -> void:
	held = action
	_from_stick = from_stick
	_held_for = 0.0
	_next_repeat = REPEAT_DELAY

func _process(delta: float) -> void:
	if held == &"":
		return
	_held_for += delta
	while _held_for >= _next_repeat:
		_next_repeat += REPEAT_EVERY
		# A tap, not a hold: a press left down would keep the action held in
		# Input after the d-pad lets go, and swallow the next real press.
		_send(held, true)
		_send(held, false)

## One ui_* press or release, routed like any other input (dialogs included).
func _send(action: StringName, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)

## Dialogs close on B, and lists open on their current item.
func _watch(n: Node) -> void:
	if not (n is AcceptDialog or n is PopupMenu) or n.has_meta(META):
		return
	n.set_meta(META, true)
	if n is AcceptDialog:
		n.window_input.connect(_on_dialog_input.bind(n))
	if n is PopupMenu:
		n.about_to_popup.connect(_focus_item.bind(n))

## A list opens on its current item (an OptionButton's choice), so a pad press
## of A without moving keeps it, and up or down moves from there.
func _focus_item(menu: PopupMenu) -> void:
	var at := 0
	if menu.get_parent() is OptionButton:
		at = maxi(menu.get_parent().selected, 0)
	(func():
		if not menu.visible or menu.item_count <= at:
			return
		# The list's own control takes focus as the stick would give it.
		var items := _focusable(menu)
		if items:
			items.grab_focus()
		menu.set_focused_item(at)).call_deferred()

## The first shown control under `n` (internal ones too) that can take focus.
static func _focusable(n: Node) -> Control:
	for c in n.get_children(true):
		if c is Control and c.focus_mode != Control.FOCUS_NONE and c.is_visible_in_tree():
			return c
		var deeper := _focusable(c)
		if deeper:
			return deeper
	return null

## B (or any ui_cancel but the key, which Godot already handles) cancels the dialog.
func _on_dialog_input(event: InputEvent, dialog: AcceptDialog) -> void:
	if event is InputEventKey or not dialog.visible or not dialog.dialog_close_on_escape:
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	# At once, as Godot does for Esc: deferred, it can land mid-frame as the tree unpauses.
	_cancel(dialog)

## As Esc: hidden, and `canceled`.
func _cancel(dialog: AcceptDialog) -> void:
	if not dialog.visible:
		return
	dialog.hide()
	dialog.canceled.emit()
