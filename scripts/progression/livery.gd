class_name Livery
extends Resource
# Story 27.1: a drone's looks and its name, one per hangar slot. Visual only:
# nothing here reaches physics (rule 1) or is graded (rule 8). The defaults are
# the drone as it looked before the hangar (DroneLook's carbon and amber).

@export var body_color := Color(0.055, 0.06, 0.07)
@export var arm_color := Color(0.055, 0.06, 0.07)
@export var prop_color := Color(0.08, 0.08, 0.09)
@export var canopy_color := Color(0.055, 0.06, 0.07)
## Under-glow and arm strips (Story 27.2); the heading lights stay white and red.
@export var light_color := Color(0.95, 0.68, 0.12)
## Lights the under-glow and arm strips (Story 27.2). Off on the stock drone,
## whose strips are unlit paint in the light colour.
@export var glow := false
## A decal id from the hangar's catalog; empty wears none.
@export var decal: StringName = &""
@export var decal_color := Color(0.95, 0.68, 0.12)
## 0 shows no number.
@export var race_number := 0
## The drone's name; empty has none.
@export var drone_name := ""

const COLORS: Array[StringName] = [&"body_color", &"arm_color", &"prop_color", &"canopy_color",
	&"light_color", &"decal_color"]

## As the save keeps it: colours as hex.
func to_dict() -> Dictionary:
	var out := {"decal": String(decal), "race_number": race_number, "name": drone_name, "glow": glow}
	for key in COLORS:
		out[String(key)] = (get(key) as Color).to_html()
	return out

## A copy of `fallback` with every field `saved` holds that reads cleanly. A
## field that is missing or garbled keeps the fallback's value.
static func from_dict(saved, fallback: Livery) -> Livery:
	var out: Livery = fallback.duplicate()
	if not saved is Dictionary:
		return out
	for key in COLORS:
		var v = saved.get(String(key))
		if v is String and Color.html_is_valid(v):
			out.set(key, Color.html(v))
	if saved.get("decal") is String:
		out.decal = StringName(saved["decal"])
	if saved.get("race_number") is float or saved.get("race_number") is int:
		out.race_number = clampi(int(saved["race_number"]), 0, 99)
	if saved.get("glow") is bool:
		out.glow = saved["glow"]
	if saved.get("name") is String:
		out.drone_name = saved["name"]
	return out
