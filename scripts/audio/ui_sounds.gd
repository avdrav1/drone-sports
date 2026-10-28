class_name UiSounds
extends Node
# Interface sounds (Story 14.5). UiSounds.wire(screen) gives every button under
# that screen, its dialogs included, a click when pressed and a blip when
# keyboard or pad focus lands on it; a dialog's OK also plays a confirm. Buttons
# added later (rows rebuilt on refresh, dialogs opened on demand) are wired as
# they enter the tree, so new screens only need the one call.

const CLICK := &"ui_click"
const FOCUS := &"ui_focus"
const CONFIRM := &"ui_confirm"
## Marks a node already wired.
const META := &"ui_sounds"

## Adds a UiSounds to `root` (internal, so screens that count children never
## see it) and returns it. It wires root's subtree now and as it grows.
static func wire(root: Node) -> UiSounds:
	var u := UiSounds.new()
	u.name = "UiSounds"
	root.add_child(u, false, Node.INTERNAL_MODE_BACK)
	return u

func _enter_tree() -> void:
	get_tree().node_added.connect(_on_added)
	_wire_all(get_parent())

func _exit_tree() -> void:
	get_tree().node_added.disconnect(_on_added)

func _on_added(n: Node) -> void:
	if get_parent().is_ancestor_of(n):
		_wire(n)

func _wire_all(n: Node) -> void:
	_wire(n)
	for c in n.get_children(true):
		_wire_all(c)

## Whether `n` already makes its sounds (wired once, however many UiSounds see it).
static func wired(n: Node) -> bool:
	return n.has_meta(META)

func _wire(n: Node) -> void:
	if not (n is BaseButton or n is AcceptDialog) or wired(n):
		return
	n.set_meta(META, true)
	if n is BaseButton:
		n.pressed.connect(_click)
		n.focus_entered.connect(_focus)
	else:
		n.confirmed.connect(_confirm)

func _click() -> void:
	Sfx.play(CLICK)

## A click also moves focus; only keyboard and pad focus moves blip.
func _focus() -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Sfx.play(FOCUS)

func _confirm() -> void:
	Sfx.play(CONFIRM)
