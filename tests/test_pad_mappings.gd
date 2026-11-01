extends RefCounted
# Story 23.9: pads the browser gives no standard mapping. Each line in
# data/ui/pad_mappings.json maps the d-pad, triggers, face and shoulder buttons;
# the GameSir's line is added when the game starts; PAD CHECK shows an axis
# above 5 and names a pad Godot does not know.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"
const NEEDED := ["a", "b", "x", "y", "leftshoulder", "rightshoulder", "lefttrigger", "righttrigger",
	"dpup", "dpdown", "dpleft", "dpright"]
## Far above any pad a test or a real machine connects.
const DEVICE := 14

func _fields(line: String) -> Dictionary:
	var out := {}
	for part in line.split(",").slice(2):
		var kv := part.split(":")
		if kv.size() == 2:
			out[kv[0]] = kv[1]
	return out

func test_every_line_maps_dpad_triggers_and_buttons() -> bool:
	var all := PadMappings.lines()
	var ok := not all.is_empty()
	for l in all:
		var f := _fields(l)
		ok = ok and l.split(",")[0] != "" and f.get("platform") == "Web"
		for k in NEEDED:
			ok = ok and f.has(k)
	# The GameSir's d-pad is its hat on axes 6 and 7, its triggers buttons 8 and 9.
	var gamesir := _fields(all[0]) if ok else {}
	return ok and all[0].begins_with("Linux0079181c,") and gamesir["dpup"] == "-a7" \
		and gamesir["dpright"] == "+a6" and gamesir["lefttrigger"] == "b8" and gamesir["righttrigger"] == "b9"

func test_the_gamesir_is_added_at_start() -> bool:
	# InputPrompt adds the lines when the game starts; a test cannot connect a
	# pad, so this reads what was added.
	return PadMappings.added.has("Linux0079181c")

func test_pad_check_shows_high_axes_and_unknown_pads() -> bool:
	PlayerProfile.choose_pilot(&"arjuna")
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	await Sim.process_frames(1)
	b.open_options()
	b.open_pad_check()
	var page: PadCheck = b.pages[&"pad_check"]
	# No pad is connected on DEVICE, so Godot knows no mapping for it.
	var ev := InputEventJoypadMotion.new()
	ev.device = DEVICE
	ev.axis = 7 as JoyAxis
	ev.axis_value = -1.0
	Input.parse_input_event(ev)
	await Sim.process_frames(2)
	var ok: bool = page._raw.text.contains("7: -1.00") and page._name.text.contains("unknown pad")
	ev.axis_value = 0.0
	Input.parse_input_event(ev)
	b.free()
	InputPrompt.use_keys()
	return ok
