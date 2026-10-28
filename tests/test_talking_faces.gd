extends RefCounted
# Story 17.2: talking faces. A line is a string or {"text", "face"}; without a
# face it makes its event's default. The HUD line types out while the face
# talks, then holds the expression, and the results screen shows the face too.

const Sim = preload("res://tests/sim.gd")
const Results = preload("res://scripts/ui/results.gd")

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

func _bark(seed := 1) -> Bark:
	var b := Bark.new()
	b.seed = seed
	Sim.add(b)
	return b

func test_string_and_object_lines_load() -> bool:
	_fresh()
	var saved: Dictionary = Bark.lines_of(&"marlo")
	Bark._cache[&"marlo"] = JSON.parse_string('{"briefing": {"active": ["Plain line.", {"text": "Grim line.", "face": "worried"}, {"text": "Odd line.", "face": "smug"}]}}')
	var pool := Bark.pool(&"marlo", &"briefing")
	var b := _bark()
	var said := {}
	for i in 3:
		var l := b.say(&"briefing", &"marlo")
		said[l.get("text", "")] = l.get("face", &"")
	Bark._cache[&"marlo"] = saved
	b.free()
	return pool == ["Plain line.", "Grim line.", "Odd line."] \
		and said == {"Plain line.": &"determined", "Grim line.": &"worried", "Odd line.": &"determined"}

func test_default_face_per_event() -> bool:
	_fresh()
	var want := {&"briefing": &"determined", &"gate_passed": &"happy", &"warning": &"shocked",
		&"strike": &"sad", &"complete": &"happy", &"fail": &"sad"}
	var ok := true
	for e in want:
		var b := _bark()
		var l := b.say(e, &"marlo")
		ok = ok and l.get("face") == want[e] and Bark.face_of(&"marlo", e, l.text) == want[e]
		b.free()
	return ok

func test_box_talks_while_typing_then_holds() -> bool:
	_fresh()
	var b := _bark()
	var box := BarkBox.new()
	box.bark = b
	Sim.add(box)
	var text := "Forty characters of radio chatter, okay."
	b.spoke.emit(&"marlo", &"fail", text)
	await Sim.process_frames(2)
	var early: bool = box.typing() and box.portrait.talking and box.portrait.expression == &"sad" \
		and box.label.visible_characters >= 0 and box.label.visible_characters < box.label.text.length()
	# Typed out within 2 s of starting.
	var frames := 0
	while box.typing() and frames < 130:
		await Sim.process_frames(1)
		frames += 1
	await Sim.process_frames(2)
	var done: bool = frames <= 120 and not box.portrait.talking and box.portrait.expression == &"sad" \
		and box.label.visible_characters == -1 and box.showing()
	var mouth: float = box.portrait.current_pose().mouth_open
	await Sim.process_frames(10)
	var held: bool = box.portrait.current_pose().mouth_open == mouth
	box.free()
	b.free()
	return text.length() == 40 and early and done and held

func test_results_row_shows_face() -> bool:
	_fresh()
	var row := Results.bark_row({"id": &"marlo", "event": &"results", "text": "Fine.", "face": &"worried"})
	var face := row.get_child(0) as CharacterPortrait
	var ok: bool = face.expression == &"worried"
	row.free()
	return ok
