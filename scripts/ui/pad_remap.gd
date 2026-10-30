class_name PadRemap
extends RefCounted
# Story 28.5: a pad whose driver or browser reports its buttons in the wrong
# order, fixed from PAD CHECK. A remap is, per pad name (Input.get_joy_name,
# lowercased), the physical button index the pad reports for each logical
# button: {JOY_BUTTON_A: 1, JOY_BUTTON_B: 0, ...}. Godot sets action state from
# the InputMap before any node sees an event, so the remap is written onto the
# InputMap's pad button bindings, from the project's own bindings kept here, and
# every raw button_index check goes through logical(). D-pad and sticks are not
# remapped. Saved by GameSettings in the "settings" section.

## The buttons the walk asks for, in order: the face buttons, shoulders, middle.
const STEPS: Array[JoyButton] = [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y,
	JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_BACK, JOY_BUTTON_START]
## Where each step's button sits on the pad, in plain words.
const WHERE := {JOY_BUTTON_A: "the bottom face button", JOY_BUTTON_B: "the right face button",
	JOY_BUTTON_X: "the left face button", JOY_BUTTON_Y: "the top face button",
	JOY_BUTTON_LEFT_SHOULDER: "the left shoulder", JOY_BUTTON_RIGHT_SHOULDER: "the right shoulder",
	JOY_BUTTON_BACK: "the left middle button", JOY_BUTTON_START: "the right middle button"}

## Pad name -> {logical JoyButton: physical index}.
static var remaps := {}
## The pad name the InputMap follows now; its remap is on when it has one.
static var active := ""
## Action -> its pad button bindings as the project has them, in order, as
## [device, button_index]. Plain data: a static var holding events crashes Godot
## at exit.
static var _originals := {}
## Physical index -> logical, for the active remap.
static var _logical := {}

## The logical button a raw `index` from the pad stands for; JOY_BUTTON_INVALID
## for a physical button the remap took away and gave nothing in its place.
static func logical(index: int) -> int:
	if not remaps.has(active):
		return index
	if _logical.has(index):
		return _logical[index]
	return JOY_BUTTON_INVALID if remaps[active].has(index) else index

## The physical index the pad reports for logical button `b` under `map`.
static func physical(map: Dictionary, b: int) -> int:
	if map.has(b):
		return map[b]
	return JOY_BUTTON_INVALID if map.values().has(b) else b

static func key(joy_name: String) -> String:
	return joy_name.to_lower()

static func has_remap(joy_name: String) -> bool:
	return remaps.has(key(joy_name))

## Keeps `map` for pad `joy_name`, puts it on the InputMap and saves it.
static func set_remap(joy_name: String, map: Dictionary) -> void:
	remaps[key(joy_name)] = map.duplicate()
	apply(joy_name)
	GameSettings.save()

## Forgets pad `joy_name`'s remap; the InputMap is the project's again.
static func reset(joy_name: String) -> void:
	remaps.erase(key(joy_name))
	if active == key(joy_name):
		apply(joy_name)
	GameSettings.save()

## Puts pad `joy_name`'s remap on the InputMap, or the project's bindings when
## it has none.
static func apply(joy_name: String) -> void:
	_keep_originals()
	active = key(joy_name)
	var map: Dictionary = remaps.get(active, {})
	_logical = {}
	for b in map:
		_logical[map[b]] = b
	for action in _originals:
		var events := InputMap.action_get_events(action)
		InputMap.action_erase_events(action)
		var i := 0
		for e in events:
			if not e is InputEventJoypadButton:
				InputMap.action_add_event(action, e)
				continue
			var e2 := InputEventJoypadButton.new()
			e2.device = _originals[action][i][0]
			e2.button_index = _originals[action][i][1]
			i += 1
			# A button the remap took away stays bound to no button, so the
			# bindings keep their places for the next apply.
			e2.button_index = physical(map, e2.button_index) as JoyButton
			InputMap.action_add_event(action, e2)

## Picks the remap for the pads connected now (the first that has one). With
## no pad connected, the remap on now stays.
static func refresh(pads: Array = []) -> void:
	var names := pads.duplicate()
	if names.is_empty():
		for d in Input.get_connected_joypads():
			names.append(Input.get_joy_name(d))
	if names.is_empty():
		apply(active)
		return
	for n in names:
		if has_remap(n):
			apply(n)
			return
	apply(names[0])

## For the save: {name: {"0": 1, ...}}.
static func to_save() -> Dictionary:
	var out := {}
	for n in remaps:
		var m := {}
		for b in remaps[n]:
			m[str(b)] = remaps[n][b]
		out[n] = m
	return out

## From the save; a remap that is not a full, one-to-one walk is dropped.
static func from_save(saved) -> void:
	remaps = {}
	if not saved is Dictionary:
		return
	for n in saved:
		var m = saved[n]
		if not m is Dictionary:
			continue
		var map := {}
		for k in m:
			map[int(k)] = int(m[k])
		var whole := STEPS.all(func(b): return map.has(b)) and map.size() == STEPS.size()
		var seen := {}
		for v in map.values():
			seen[v] = true
		if whole and seen.size() == map.size():
			remaps[key(String(n))] = map

## The project's pad button bindings, taken once before any remap is applied.
static func _keep_originals() -> void:
	if not _originals.is_empty():
		return
	for action in InputMap.get_actions():
		var kept := []
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton:
				kept.append([e.device, e.button_index])
		if not kept.is_empty():
			_originals[action] = kept
