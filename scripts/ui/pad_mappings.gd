class_name PadMappings
extends RefCounted
# Story 23.9: pads the browser gives no standard mapping. Godot's web build
# then names a pad by OS, vendor and product (e.g. "Linux0079181c") and, with no
# mapping for that, passes its raw numbers through: a d-pad on a hat axis, the
# triggers on buttons. data/ui/pad_mappings.json holds SDL-style lines for such
# pads; InputPrompt adds them at start, before any pad is touched.

const DATA := "res://data/ui/pad_mappings.json"

## The GUIDs added so far, in order.
static var added: Array[String] = []

## The mapping lines in `path`.
static func lines(path := DATA) -> Array[String]:
	var out: Array[String] = []
	var res: JSON = load(path) if ResourceLoader.exists(path) else null
	if res and res.data is Dictionary:
		for l in res.data.get("mappings", []):
			out.append(str(l))
	return out

## Adds every line to Godot's mappings, updating pads already connected.
static func add_all(path := DATA) -> int:
	var all := lines(path)
	for l in all:
		Input.add_joy_mapping(l, true)
		added.append(l.get_slice(",", 0))
	return all.size()
